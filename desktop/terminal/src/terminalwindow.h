// Enclave Terminal — one window: an Ember tab strip that is also the title
// bar (drag it to move the window, double-click to maximise), and a stack of
// QTermWidget sessions under it.
#pragma once
#include <QStringList>
#include <QWidget>

class QStackedWidget;
class QTabBar;
class QTermWidget;
class QToolButton;
class QFileSystemWatcher;

struct LaunchOptions {
    QString workingDirectory;
    QString program;          // empty = the user's shell
    QStringList args;
    QString title;
    bool hold = false;        // keep the tab open after the program ends
};

class TerminalWindow : public QWidget {
    Q_OBJECT
public:
    explicit TerminalWindow(const LaunchOptions &first, QWidget *parent = nullptr);

    QTermWidget *addTab(const LaunchOptions &opts);
    QTermWidget *current() const;

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
    void closeEvent(QCloseEvent *event) override;

private:
    void closeTab(int index);
    void retitle(QTermWidget *term);
    void applyTheme();
    void showContextMenu(QTermWidget *term, const QPoint &pos);
    bool darkMode() const;
    static QFont terminalFont();
    void setupShortcuts();

    QWidget *m_strip = nullptr;
    QTabBar *m_tabs = nullptr;
    QToolButton *m_plus = nullptr;
    QStackedWidget *m_stack = nullptr;
    QFileSystemWatcher *m_watcher = nullptr;
    QList<QTermWidget *> m_terms;   // in tab order
    bool m_dark = true;
    int m_zoom = 0;
};
