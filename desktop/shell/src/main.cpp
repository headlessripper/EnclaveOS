// Enclave Shell — entry point.
//
//   enclave-shell                 run the desktop shell (one per session)
//   enclave-shell --toggle-start  open/close Start in the running shell
//   enclave-shell --command NAME  send any shell command (start, show-desktop,
//                                 toggle-appearance, quit)
#include <QCommandLineParser>
#include <QFont>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>

#include "appregistry.h"
#include "iconprovider.h"
#include "system.h"
#include "theme.h"
#include "toplevels.h"

// Client mode (Super key, scripts): no GUI, so it never needs a display.
static int runClient(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCommandLineParser cli;
    QCommandLineOption toggleStart("toggle-start");
    QCommandLineOption command("command", "", "name");
    cli.addOptions({toggleStart, command});
    cli.process(app);
    const QString name = cli.isSet(command) ? cli.value(command) : QStringLiteral("start");
    if (System::sendCommand(name))
        return 0;
    qWarning("enclave-shell: no running shell to send '%s' to", qPrintable(name));
    return 1;
}

int main(int argc, char *argv[])
{
    for (int i = 1; i < argc; ++i) {
        const QByteArray a(argv[i]);
        if (a == "--toggle-start" || a == "--command" || a.startsWith("--command="))
            return runClient(argc, argv);
    }

    // Layer-shell surfaces need the native Wayland platform.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "wayland");
    // Ember styles the controls itself; Basic is the fully customisable style.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    // Software rendering keeps the shell working in VMs without 3D.
    if (qEnvironmentVariableIsSet("ENCLAVE_SOFTWARE_RENDERING"))
        QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);

    QGuiApplication app(argc, argv);
    app.setApplicationName("enclave-shell");
    app.setOrganizationName("Enclave");
    app.setDesktopFileName("enclave-shell");

    QCommandLineParser cli;
    cli.setApplicationDescription("Enclave Shell — the Enclave OS desktop");
    cli.addHelpOption();
    // (documented here for --help; handled by runClient above)
    cli.addOption({"toggle-start", "Open or close Start in the running shell."});
    cli.addOption({"command", "Send a command (start, show-desktop, toggle-appearance, quit).", "name"});
    cli.process(app);

    Theme theme;
    QFont font(theme.fontFamily());
    font.setPointSizeF(10);
    app.setFont(font);

    AppRegistry apps;
    ToplevelModel windows;
    System system;
    if (!system.listen())
        qWarning("enclave-shell: could not open %s", qPrintable(System::socketPath()));

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon", new IconProvider);
    qmlRegisterSingletonInstance("Enclave", 1, 0, "Theme", &theme);
    qmlRegisterSingletonInstance("Enclave", 1, 0, "Apps", &apps);
    qmlRegisterSingletonInstance("Enclave", 1, 0, "Windows", &windows);
    qmlRegisterSingletonInstance("Enclave", 1, 0, "System", &system);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Enclave.Shell", "Main");
    return app.exec();
}
