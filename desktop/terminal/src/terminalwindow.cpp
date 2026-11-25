#include "terminalwindow.h"

#include <QAction>
#include <QApplication>
#include <QCloseEvent>
#include <QDir>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QHBoxLayout>
#include <QKeySequence>
#include <QMenu>
#include <QMessageBox>
#include <QPushButton>
#include <QMouseEvent>
#include <QProcess>
#include <QProcessEnvironment>
#include <QSettings>
#include <QShortcut>
#include <QStackedWidget>
#include <QStandardPaths>
#include <QStyleHints>
#include <QTabBar>
#include <QToolButton>
#include <QVBoxLayout>
#include <QWindow>

#include <qtermwidget.h>

namespace {

// Ember, as in desktop/design-system/tokens/ember.json
struct Palette {
    const char *ground, *strip, *tab, *tabHover, *text, *muted, *border, *menu;
};
constexpr Palette kDark  { "#101114", "#1A1C21", "#101114", "#272A31", "#F5F3EF", "#A7A39B", "#2A2C31", "#272A31" };
constexpr Palette kLight { "#F7F6F3", "#EAE8E2", "#F7F6F3", "#DEDBD3", "#202124", "#6B6860", "#D6D3CB", "#FFFFFF" };
constexpr const char *kEmber = "#FF7A1A";

QString shellConf()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + "/enclave/shell.conf";
}

QString schemesDir()
{
    for (const QString &d : {QString(ENCLAVE_SCHEMES_DIR), QString(ENCLAVE_SOURCE_SCHEMES_DIR)})
        if (QFileInfo::exists(d + "/Enclave-Dark.colorscheme"))
            return d;
    return QString(ENCLAVE_SCHEMES_DIR);
}

} // namespace

TerminalWindow::TerminalWindow(const LaunchOptions &first, QWidget *parent) : QWidget(parent)
{
    setWindowTitle("Terminal");
    resize(880, 560);
    setMinimumSize(420, 260);
    QTermWidget::addCustomColorSchemeDir(schemesDir());

    auto *outer = new QVBoxLayout(this);
    outer->setContentsMargins(0, 0, 0, 0);
    outer->setSpacing(0);

    // ---- the strip: tabs + new-tab button; doubles as the title bar ----
    m_strip = new QWidget(this);
    m_strip->setObjectName("strip");
    m_strip->setFixedHeight(46);
    m_strip->installEventFilter(this);
    auto *row = new QHBoxLayout(m_strip);
    row->setContentsMargins(10, 0, 10, 0);
    row->setSpacing(4);

    m_tabs = new QTabBar(m_strip);
    m_tabs->setDocumentMode(true);
    m_tabs->setTabsClosable(true);
    m_tabs->setMovable(true);
    m_tabs->setExpanding(false);
    m_tabs->setDrawBase(false);
    m_tabs->setElideMode(Qt::ElideMiddle);
    m_tabs->setUsesScrollButtons(true);
    m_tabs->setFocusPolicy(Qt::NoFocus);
    m_tabs->installEventFilter(this);
    row->addWidget(m_tabs, 0, Qt::AlignVCenter);

    m_plus = new QToolButton(m_strip);
    m_plus->setObjectName("plus");
    m_plus->setText("+");
    m_plus->setToolTip("New tab (Ctrl+Shift+T)");
    m_plus->setFocusPolicy(Qt::NoFocus);
    m_plus->setFixedSize(30, 30);
    row->addWidget(m_plus, 0, Qt::AlignVCenter);
    row->addStretch(1);
    outer->addWidget(m_strip);

    m_stack = new QStackedWidget(this);
    outer->addWidget(m_stack, 1);

    connect(m_plus, &QToolButton::clicked, this, [this] {
        LaunchOptions o;
        if (auto *t = current()) o.workingDirectory = t->workingDirectory();
        addTab(o);
    });
    connect(m_tabs, &QTabBar::currentChanged, this, [this](int i) {
        if (i < 0 || i >= m_terms.size()) return;
        m_stack->setCurrentWidget(m_terms[i]);
        m_terms[i]->setFocus();
        setWindowTitle(m_tabs->tabText(i));
    });
    connect(m_tabs, &QTabBar::tabCloseRequested, this, &TerminalWindow::closeTab);
    connect(m_tabs, &QTabBar::tabMoved, this, [this](int from, int to) { m_terms.move(from, to); });

    // follow Enclave's light / dark choice as it changes
    m_watcher = new QFileSystemWatcher(this);
    m_watcher->addPath(QFileInfo(shellConf()).absolutePath());
    if (QFileInfo::exists(shellConf())) m_watcher->addPath(shellConf());
    auto recheck = [this] {
        if (QFileInfo::exists(shellConf()) && !m_watcher->files().contains(shellConf()))
            m_watcher->addPath(shellConf());
        if (darkMode() != m_dark) applyTheme();
    };
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, recheck);
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, recheck);
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this, recheck);

    setupShortcuts();
    applyTheme();
    addTab(first);
}

bool TerminalWindow::darkMode() const
{
    const QString mode = QSettings(shellConf(), QSettings::IniFormat).value("appearance/mode", "dark").toString();
    if (mode == "system")
        return QGuiApplication::styleHints()->colorScheme() != Qt::ColorScheme::Light;
    return mode != "light";
}

QFont TerminalWindow::terminalFont()
{
    const QStringList families = QFontDatabase::families();
    for (const QString &f : {QStringLiteral("JetBrains Mono"), QStringLiteral("Cascadia Code"),
                             QStringLiteral("Fira Code"), QStringLiteral("DejaVu Sans Mono")})
        if (families.contains(f)) {
            QFont font(f, 11);
            font.setStyleHint(QFont::Monospace);
            return font;
        }
    QFont font = QFontDatabase::systemFont(QFontDatabase::FixedFont);
    font.setPointSize(11);
    return font;
}

QTermWidget *TerminalWindow::current() const
{
    const int i = m_tabs->currentIndex();
    return i >= 0 && i < m_terms.size() ? m_terms[i] : nullptr;
}

QTermWidget *TerminalWindow::addTab(const LaunchOptions &opts)
{
    auto *term = new QTermWidget(0, m_stack);
    term->setColorScheme(m_dark ? "Enclave-Dark" : "Enclave-Light");
    term->setTerminalFont(terminalFont());
    term->setMargin(14);
    term->setScrollBarPosition(QTermWidget::ScrollBarRight);
    term->setHistorySize(20000);
    term->setKeyboardCursorShape(QTermWidget::KeyboardCursorShape::IBeamCursor);
    term->setBlinkingCursor(true);
    term->setConfirmMultilinePaste(true);
    term->setTrimPastedTrailingNewlines(true);
    term->setOsc8HyperlinksEnabled(true);
    term->setBoldIntense(true);
    term->setAutoClose(!opts.hold);
    if (m_zoom > 0) for (int i = 0; i < m_zoom; ++i) term->zoomIn();
    if (m_zoom < 0) for (int i = 0; i > m_zoom; --i) term->zoomOut();

    QString dir = opts.workingDirectory;
    if (dir.isEmpty() || !QFileInfo(dir).isDir())
        dir = QDir::homePath();
    term->setWorkingDirectory(dir);
    if (!opts.program.isEmpty()) {
        term->setShellProgram(opts.program);
        term->setArgs(opts.args);
    } else {
        term->setShellProgram(qEnvironmentVariable("SHELL", "/bin/bash"));
    }
    QStringList env = QProcessEnvironment::systemEnvironment().toStringList();
    env << "TERM=xterm-256color" << "COLORTERM=truecolor" << "TERM_PROGRAM=enclave-terminal";
    term->setEnvironment(env);
    term->setContextMenuPolicy(Qt::CustomContextMenu);
    term->setProperty("fixedTitle", opts.title);

    m_stack->addWidget(term);
    m_terms << term;
    const int index = m_tabs->addTab(opts.title.isEmpty() ? QStringLiteral("Terminal") : opts.title);
    m_tabs->setCurrentIndex(index);

    connect(term, &QTermWidget::titleChanged, this, [this, term] { retitle(term); });
    connect(term, &QTermWidget::currentDirectoryChanged, this, [this, term] { retitle(term); });
    connect(term, &QTermWidget::finished, this, [this, term] {
        if (!term->property("hold").toBool())
            closeTab(m_terms.indexOf(term));
    });
    term->setProperty("hold", opts.hold);
    connect(term, &QWidget::customContextMenuRequested, this, [this, term](const QPoint &p) { showContextMenu(term, p); });
    connect(term, &QTermWidget::urlActivated, this, [](const QUrl &url, bool) {
        QProcess::startDetached("xdg-open", {url.toString()});
    });

    term->startShellProgram();
    term->setFocus();
    retitle(term);
    return term;
}

void TerminalWindow::retitle(QTermWidget *term)
{
    const int i = m_terms.indexOf(term);
    if (i < 0) return;
    QString t = term->property("fixedTitle").toString();
    const QString full = term->title().trimmed();
    if (t.isEmpty()) {
        t = full;
        // shells announce "user@host:path" — the tab only needs the folder
        const int colon = t.indexOf(':');
        if (colon > 0 && t.left(colon).contains('@')) {
            QString path = t.mid(colon + 1).trimmed();
            if (path == "~" || path == QDir::homePath()) t = "~";
            else if (path == "/") t = "/";
            else t = path.section('/', -1, -1, QString::SectionSkipEmpty);
        }
    }
    if (t.isEmpty()) {
        QString dir = term->workingDirectory();
        if (dir == QDir::homePath()) t = "~";
        else if (!dir.isEmpty()) t = QFileInfo(dir).fileName();
    }
    if (t.isEmpty()) t = "Terminal";
    m_tabs->setTabText(i, t);
    m_tabs->setTabToolTip(i, full.isEmpty() ? t : full);
    if (i == m_tabs->currentIndex()) setWindowTitle(t);
}

void TerminalWindow::closeTab(int index)
{
    if (index < 0 || index >= m_terms.size()) return;
    QTermWidget *term = m_terms.takeAt(index);
    m_tabs->removeTab(index);
    m_stack->removeWidget(term);
    term->deleteLater();
    if (m_terms.isEmpty()) close();
    else if (auto *t = current()) t->setFocus();
}

void TerminalWindow::closeEvent(QCloseEvent *event)
{
    // ask before ending something that's still running in a tab
    int busy = 0;
    for (QTermWidget *t : m_terms) {
        const int fg = t->getForegroundProcessId(), sh = t->getShellPID();
        if (fg > 0 && sh > 0 && fg != sh) ++busy;
    }
    if (busy > 0) {
        QMessageBox box(this);
        box.setWindowTitle("Close Terminal?");
        box.setText(busy == 1 ? "A program is still running in this window."
                              : QString("Programs are still running in %1 tabs.").arg(busy));
        box.setInformativeText("Closing the window ends them.");
        box.setStandardButtons(QMessageBox::Cancel);
        auto *closeBtn = box.addButton("Close", QMessageBox::DestructiveRole);
        box.exec();
        if (box.clickedButton() != static_cast<QAbstractButton *>(closeBtn)) { event->ignore(); return; }
    }
    event->accept();
}

void TerminalWindow::showContextMenu(QTermWidget *term, const QPoint &pos)
{
    QMenu menu(this);
    const QList<QAction *> links = term->filterActions(pos);
    for (QAction *a : links) menu.addAction(a);
    if (!links.isEmpty()) menu.addSeparator();
    menu.addAction("Copy", QKeySequence("Ctrl+Shift+C"), term, &QTermWidget::copyClipboard);
    menu.addAction("Paste", QKeySequence("Ctrl+Shift+V"), term, &QTermWidget::pasteClipboard);
    menu.addSeparator();
    menu.addAction("Find…", QKeySequence("Ctrl+Shift+F"), term, &QTermWidget::toggleShowSearchBar);
    menu.addAction("Clear", QKeySequence("Ctrl+Shift+K"), term, &QTermWidget::clear);
    menu.addSeparator();
    menu.addAction("New Tab", QKeySequence("Ctrl+Shift+T"), this, [this, term] {
        LaunchOptions o; o.workingDirectory = term->workingDirectory(); addTab(o);
    });
    menu.addAction("Open Folder in Files", this, [term] {
        QProcess::startDetached("thunar", {term->workingDirectory()});
    });
    menu.exec(term->mapToGlobal(pos));
}

void TerminalWindow::setupShortcuts()
{
    auto bind = [this](const QString &keys, auto fn) {
        auto *s = new QShortcut(QKeySequence(keys), this);
        s->setContext(Qt::WindowShortcut);
        connect(s, &QShortcut::activated, this, fn);
    };
    bind("Ctrl+Shift+T", [this] {
        LaunchOptions o; if (auto *t = current()) o.workingDirectory = t->workingDirectory(); addTab(o);
    });
    bind("Ctrl+Shift+W", [this] { closeTab(m_tabs->currentIndex()); });
    bind("Ctrl+Shift+N", [] { QProcess::startDetached(QCoreApplication::applicationFilePath(), {}); });
    bind("Ctrl+Shift+C", [this] { if (auto *t = current()) t->copyClipboard(); });
    bind("Ctrl+Shift+V", [this] { if (auto *t = current()) t->pasteClipboard(); });
    bind("Ctrl+Shift+F", [this] { if (auto *t = current()) t->toggleShowSearchBar(); });
    bind("Ctrl+Shift+K", [this] { if (auto *t = current()) t->clear(); });
    bind("Ctrl+PgDown", [this] { if (m_tabs->count()) m_tabs->setCurrentIndex((m_tabs->currentIndex() + 1) % m_tabs->count()); });
    bind("Ctrl+PgUp", [this] { if (m_tabs->count()) m_tabs->setCurrentIndex((m_tabs->currentIndex() - 1 + m_tabs->count()) % m_tabs->count()); });
    bind("Ctrl+=", [this] { ++m_zoom; for (auto *t : m_terms) t->zoomIn(); });
    bind("Ctrl++", [this] { ++m_zoom; for (auto *t : m_terms) t->zoomIn(); });
    bind("Ctrl+-", [this] { --m_zoom; for (auto *t : m_terms) t->zoomOut(); });
    for (int n = 1; n <= 9; ++n)
        bind(QString("Alt+%1").arg(n), [this, n] { if (n - 1 < m_tabs->count()) m_tabs->setCurrentIndex(n - 1); });
}

bool TerminalWindow::eventFilter(QObject *watched, QEvent *event)
{
    // the strip (and the empty part of the tab bar) is the title bar
    if (watched == m_strip || (watched == m_tabs && event->type() != QEvent::Paint)) {
        if (event->type() == QEvent::MouseButtonPress || event->type() == QEvent::MouseButtonDblClick) {
            auto *me = static_cast<QMouseEvent *>(event);
            const bool onTab = watched == m_tabs && m_tabs->tabAt(me->position().toPoint()) >= 0;
            if (onTab || me->button() != Qt::LeftButton)
                return false;
            if (event->type() == QEvent::MouseButtonDblClick) {
                isMaximized() ? showNormal() : showMaximized();
                return true;
            }
            if (windowHandle()) windowHandle()->startSystemMove();
            return true;
        }
        if (watched == m_tabs && event->type() == QEvent::MouseButtonRelease) {
            auto *me = static_cast<QMouseEvent *>(event);
            if (me->button() == Qt::MiddleButton) {   // middle-click a tab to close it
                const int i = m_tabs->tabAt(me->position().toPoint());
                if (i >= 0) { closeTab(i); return true; }
            }
        }
    }
    return QWidget::eventFilter(watched, event);
}

void TerminalWindow::applyTheme()
{
    m_dark = darkMode();
    const Palette &p = m_dark ? kDark : kLight;
    QGuiApplication::styleHints()->setColorScheme(m_dark ? Qt::ColorScheme::Dark : Qt::ColorScheme::Light);
    setStyleSheet(QString(R"(
        TerminalWindow { background: %1; }
        #strip { background: %2; border-bottom: 1px solid %7; }
        QTabBar { background: transparent; }
        QTabBar::tab {
            background: transparent; color: %6;
            padding: 6px 10px 6px 14px; margin: 8px 2px 8px 0;
            border-radius: 9px; min-width: 110px; max-width: 230px;
            font-size: 9.5pt;
        }
        QTabBar::tab:hover { background: %4; color: %5; }
        QTabBar::tab:selected {
            background: %3; color: %5; font-weight: 600;
            border: 1px solid %7; border-bottom: 2px solid %9;
        }
        QTabBar::close-button { image: url(:/icons/close.svg); subcontrol-position: right; margin: 2px; border-radius: 4px; }
        QTabBar::close-button:hover { background: %4; }
        QTabBar QToolButton { background: %2; color: %5; border: none; }
        #plus {
            background: transparent; color: %6; border: none; border-radius: 8px;
            font-size: 15pt; font-weight: 300; padding-bottom: 2px;
        }
        #plus:hover { background: %4; color: %9; }
        QMenu { background: %8; color: %5; border: 1px solid %7; border-radius: 12px; padding: 6px; }
        QMenu::item { padding: 7px 26px 7px 14px; border-radius: 7px; }
        QMenu::item:selected { background: %4; }
        QMenu::item:disabled { color: %6; }
        QMenu::separator { height: 1px; background: %7; margin: 5px 8px; }
        QScrollBar:vertical { background: transparent; width: 10px; margin: 4px 2px; }
        QScrollBar::handle:vertical { background: %4; border-radius: 3px; min-height: 30px; }
        QScrollBar::handle:vertical:hover { background: %6; }
        QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page { background: none; height: 0; }
        QLineEdit { background: %8; color: %5; border: 1px solid %7; border-radius: 8px; padding: 4px 8px; selection-background-color: %9; }
        QMessageBox { background: %2; } QMessageBox QLabel { color: %5; }
        QPushButton { background: %8; color: %5; border: 1px solid %7; border-radius: 8px; padding: 6px 16px; }
        QPushButton:hover { background: %4; }
    )").arg(p.ground, p.strip, p.tab, p.tabHover, p.text, p.muted, p.border, p.menu, kEmber));
    for (QTermWidget *t : m_terms)
        t->setColorScheme(m_dark ? "Enclave-Dark" : "Enclave-Light");
}
