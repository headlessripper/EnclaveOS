// Enclave Shell — entry point.
//
//   enclave-shell                 run the desktop shell (one per session)
//   enclave-shell --toggle-start  open/close Start in the running shell
//   enclave-shell --command NAME  send any shell command (start, show-desktop,
//                                 toggle-appearance, quit)
//   enclave-shell --settings [--page NAME]
//                                 Enclave Settings, as an ordinary app window
//                                 (what /usr/bin/enclave-settings runs). One
//                                 instance: a second call just turns the page.
#include <QCommandLineParser>
#include <QDir>
#include <QLocalServer>
#include <QLocalSocket>
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

static void prepareEnvironment()
{
    // Layer-shell surfaces need the native Wayland platform.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "wayland");
    // Ember styles the controls itself; Basic is the fully customisable style.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    // Software rendering keeps the shell working in VMs without 3D.
    if (qEnvironmentVariableIsSet("ENCLAVE_SOFTWARE_RENDERING"))
        QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
}

static QString settingsSocket()
{
    QString dir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (dir.isEmpty())
        dir = QDir::tempPath();
    return dir + "/enclave-settings-" + qEnvironmentVariable("WAYLAND_DISPLAY", "wayland-0") + ".sock";
}

// Enclave Settings: the same theme, registry and services as the shell, in an
// ordinary (xdg-toplevel) window whose app id is enclave-settings.
static int runSettings(int argc, char *argv[])
{
    QString page;
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == "--page" && i + 1 < argc)
            page = QString::fromLocal8Bit(argv[++i]);
        else if (a.startsWith("--page="))
            page = a.mid(7);
    }
    {   // already open? turn its page and stop
        QLocalSocket s;
        s.connectToServer(settingsSocket());
        if (s.waitForConnected(300)) {
            s.write((page.isEmpty() ? QStringLiteral("raise") : page).toUtf8());
            s.waitForBytesWritten(300);
            return 0;
        }
    }

    prepareEnvironment();
    QGuiApplication app(argc, argv);
    app.setApplicationName("enclave-settings");
    app.setApplicationDisplayName("Settings");
    app.setOrganizationName("Enclave");
    app.setDesktopFileName("enclave-settings");

    Theme theme;
    QFont font(theme.fontFamily());
    font.setPointSizeF(10);
    app.setFont(font);
    AppRegistry apps;
    System system;

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon", new IconProvider);
    qmlRegisterSingletonInstance("Enclave", 1, 0, "Theme", &theme);
    qmlRegisterSingletonInstance("Enclave", 1, 0, "Apps", &apps);
    qmlRegisterSingletonInstance("Enclave", 1, 0, "System", &system);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.setInitialProperties({{"page", page.isEmpty() ? QStringLiteral("network") : page}});
    engine.loadFromModule("Enclave.Shell", "Settings");
    if (engine.rootObjects().isEmpty())
        return 1;
    QObject *root = engine.rootObjects().constFirst();

    QLocalServer server;
    QLocalServer::removeServer(settingsSocket());
    server.setSocketOptions(QLocalServer::UserAccessOption);
    server.listen(settingsSocket());
    QObject::connect(&server, &QLocalServer::newConnection, &app, [&server, root] {
        while (QLocalSocket *c = server.nextPendingConnection()) {
            QObject::connect(c, &QLocalSocket::readyRead, c, [c, root] {
                const QString msg = QString::fromUtf8(c->readAll()).trimmed();
                if (!msg.isEmpty() && msg != "raise")
                    root->setProperty("page", msg);
                if (auto *w = qobject_cast<QWindow *>(root)) {
                    w->show();
                    w->raise();
                    w->requestActivate();
                }
            });
            QObject::connect(c, &QLocalSocket::disconnected, c, &QObject::deleteLater);
        }
    });
    return app.exec();
}

int main(int argc, char *argv[])
{
    for (int i = 1; i < argc; ++i) {
        const QByteArray a(argv[i]);
        if (a == "--toggle-start" || a == "--command" || a.startsWith("--command="))
            return runClient(argc, argv);
        if (a == "--settings")
            return runSettings(argc, argv);
    }

    prepareEnvironment();
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
    cli.addOption({"settings", "Open Enclave Settings (with --page NAME)."});
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
