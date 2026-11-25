// Enclave Terminal — entry point.
//
//   enclave-terminal                          a new window, your shell, in ~
//   enclave-terminal --working-directory DIR  start in DIR (also -w DIR)
//   enclave-terminal -e "COMMAND"             run COMMAND (a shell line)
//   enclave-terminal -x PROGRAM ARGS...       run PROGRAM with ARGS (the rest)
//   enclave-terminal --title TEXT             a fixed tab title
//   enclave-terminal --hold                   keep the tab after it finishes
// The -e / -x / --working-directory forms match what Thunar, the Start menu
// and other desktops' launchers already pass to a terminal.
#include <QApplication>
#include <QDir>
#include <QFont>
#include <QUrl>

#include "terminalwindow.h"

int main(int argc, char *argv[])
{
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "wayland;xcb");
    QApplication app(argc, argv);
    app.setApplicationName("enclave-terminal");
    app.setApplicationDisplayName("Terminal");
    app.setOrganizationName("Enclave");
    app.setDesktopFileName("enclave-terminal");
    app.setStyle("Fusion");
    QFont ui("Inter");
    ui.setPointSizeF(9.5);
    app.setFont(ui);

    LaunchOptions o;
    const QStringList a = app.arguments();
    for (int i = 1; i < a.size(); ++i) {
        const QString &s = a[i];
        auto next = [&]() { return i + 1 < a.size() ? a[++i] : QString(); };
        if (s == "--working-directory" || s == "-w" || s == "--workdir") o.workingDirectory = next();
        else if (s.startsWith("--working-directory=")) o.workingDirectory = s.mid(20);
        else if (s == "--title" || s == "-T") o.title = next();
        else if (s.startsWith("--title=")) o.title = s.mid(8);
        else if (s == "--hold" || s == "-H") o.hold = true;
        else if (s == "-e" || s == "--command") {
            o.program = "/bin/sh";
            o.args = {"-c", next()};
        } else if (s.startsWith("--command=")) {
            o.program = "/bin/sh";
            o.args = {"-c", s.mid(10)};
        } else if (s == "-x" || s == "--execute") {
            if (i + 1 < a.size()) {
                o.program = a[i + 1];
                o.args = a.mid(i + 2);
            }
            break;
        } else if (s == "--help" || s == "-h") {
            fputs("enclave-terminal [--working-directory DIR] [--title T] [--hold] [-e \"CMD\" | -x PROG ARGS...]\n", stdout);
            return 0;
        }
    }
    if (o.workingDirectory.startsWith("file://"))
        o.workingDirectory = QUrl(o.workingDirectory).toLocalFile();
    if (o.workingDirectory.startsWith("~"))
        o.workingDirectory = QDir::homePath() + o.workingDirectory.mid(1);

    TerminalWindow w(o);
    w.show();
    return app.exec();
}
