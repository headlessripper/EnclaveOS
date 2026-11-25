#include "toplevels.h"
#include "system.h"

#include <cstring>
#include <wayland-client.h>
#include "wlr-foreign-toplevel-client.h"

namespace {

void hTitle(void *data, zwlr_foreign_toplevel_handle_v1 *h, const char *title)
{
    if (Toplevel *t = static_cast<ToplevelModel *>(data)->find(h))
        t->pTitle = QString::fromUtf8(title);
}
void hAppId(void *data, zwlr_foreign_toplevel_handle_v1 *h, const char *appId)
{
    if (Toplevel *t = static_cast<ToplevelModel *>(data)->find(h))
        t->pAppId = QString::fromUtf8(appId);
}
void hOutputEnter(void *, zwlr_foreign_toplevel_handle_v1 *, wl_output *) {}
void hOutputLeave(void *, zwlr_foreign_toplevel_handle_v1 *, wl_output *) {}
void hState(void *data, zwlr_foreign_toplevel_handle_v1 *h, wl_array *state)
{
    Toplevel *t = static_cast<ToplevelModel *>(data)->find(h);
    if (!t)
        return;
    t->pActivated = t->pMinimized = t->pMaximized = t->pFullscreen = false;
    // wl_array_for_each relies on C's implicit void* conversion; iterate by hand.
    const auto *begin = static_cast<const uint32_t *>(state->data);
    const auto *end = begin + state->size / sizeof(uint32_t);
    for (const uint32_t *s = begin; s < end; ++s) {
        switch (*s) {
        case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED: t->pMaximized = true; break;
        case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED: t->pMinimized = true; break;
        case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED: t->pActivated = true; break;
        case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_FULLSCREEN: t->pFullscreen = true; break;
        }
    }
}
void hDone(void *data, zwlr_foreign_toplevel_handle_v1 *h)
{
    static_cast<ToplevelModel *>(data)->onDone(h);
}
void hClosed(void *data, zwlr_foreign_toplevel_handle_v1 *h)
{
    static_cast<ToplevelModel *>(data)->onClosed(h);
}
void hParent(void *, zwlr_foreign_toplevel_handle_v1 *, zwlr_foreign_toplevel_handle_v1 *) {}

const zwlr_foreign_toplevel_handle_v1_listener kHandleListener = {
    hTitle, hAppId, hOutputEnter, hOutputLeave, hState, hDone, hClosed, hParent};

void mToplevel(void *data, zwlr_foreign_toplevel_manager_v1 *, zwlr_foreign_toplevel_handle_v1 *h)
{
    static_cast<ToplevelModel *>(data)->onToplevel(h);
}
void mFinished(void *data, zwlr_foreign_toplevel_manager_v1 *)
{
    static_cast<ToplevelModel *>(data)->onFinished();
}
const zwlr_foreign_toplevel_manager_v1_listener kManagerListener = {mToplevel, mFinished};

void rGlobal(void *data, wl_registry *reg, uint32_t name, const char *iface, uint32_t version)
{
    static_cast<ToplevelModel *>(data)->onGlobal(reg, name, iface, version);
}
void rGlobalRemove(void *, wl_registry *, uint32_t) {}
const wl_registry_listener kRegistryListener = {rGlobal, rGlobalRemove};

} // namespace

ToplevelModel::ToplevelModel(QObject *parent) : QAbstractListModel(parent)
{
    m_display = wl_display_connect(nullptr);
    if (!m_display) {
        qWarning("enclave-shell: no Wayland display; window list disabled");
        return;
    }
    m_registry = wl_display_get_registry(m_display);
    wl_registry_add_listener(m_registry, &kRegistryListener, this);
    wl_display_roundtrip(m_display);   // globals
    wl_display_roundtrip(m_display);   // initial toplevels
    if (!m_manager)
        qWarning("enclave-shell: compositor lacks wlr-foreign-toplevel-management");

    m_notifier = std::make_unique<QSocketNotifier>(wl_display_get_fd(m_display),
                                                   QSocketNotifier::Read);
    connect(m_notifier.get(), &QSocketNotifier::activated, this, &ToplevelModel::dispatch);
}

ToplevelModel::~ToplevelModel()
{
    m_notifier.reset();
    for (Toplevel *t : m_items + m_pending) {
        zwlr_foreign_toplevel_handle_v1_destroy(t->handle);
        delete t;
    }
    if (m_manager)
        zwlr_foreign_toplevel_manager_v1_stop(m_manager);
    if (m_display) {
        wl_display_flush(m_display);
        wl_display_disconnect(m_display);
    }
}

void ToplevelModel::dispatch()
{
    if (wl_display_dispatch(m_display) < 0) {
        qWarning("enclave-shell: lost the Wayland connection");
        m_notifier->setEnabled(false);
    }
}

void ToplevelModel::flush()
{
    if (m_display)
        wl_display_flush(m_display);
}

void ToplevelModel::onGlobal(wl_registry *reg, uint32_t name, const char *iface, uint32_t version)
{
    if (std::strcmp(iface, zwlr_foreign_toplevel_manager_v1_interface.name) == 0 && !m_manager) {
        m_manager = static_cast<zwlr_foreign_toplevel_manager_v1 *>(wl_registry_bind(
            reg, name, &zwlr_foreign_toplevel_manager_v1_interface, qMin(version, 3u)));
        zwlr_foreign_toplevel_manager_v1_add_listener(m_manager, &kManagerListener, this);
        emit availableChanged();
    } else if (std::strcmp(iface, wl_seat_interface.name) == 0 && !m_seat) {
        m_seat = static_cast<wl_seat *>(wl_registry_bind(reg, name, &wl_seat_interface, 1));
    }
}

void ToplevelModel::onToplevel(zwlr_foreign_toplevel_handle_v1 *handle)
{
    auto *t = new Toplevel;
    t->handle = handle;
    m_pending << t;
    zwlr_foreign_toplevel_handle_v1_add_listener(handle, &kHandleListener, this);
}

Toplevel *ToplevelModel::find(zwlr_foreign_toplevel_handle_v1 *handle)
{
    for (Toplevel *t : m_items + m_pending)
        if (t->handle == handle)
            return t;
    return nullptr;
}

void ToplevelModel::onDone(zwlr_foreign_toplevel_handle_v1 *handle)
{
    Toplevel *t = find(handle);
    if (!t)
        return;
    t->title = t->pTitle;
    t->appId = t->pAppId;
    t->activated = t->pActivated;
    t->minimized = t->pMinimized;
    t->maximized = t->pMaximized;
    t->fullscreen = t->pFullscreen;
    if (!t->ready) {
        t->ready = true;
        m_pending.removeAll(t);
        beginInsertRows({}, m_items.size(), m_items.size());
        m_items << t;
        endInsertRows();
    } else {
        const int row = m_items.indexOf(t);
        emit dataChanged(index(row), index(row));
    }
    emit windowsChanged();
}

void ToplevelModel::onClosed(zwlr_foreign_toplevel_handle_v1 *handle)
{
    Toplevel *t = find(handle);
    if (!t)
        return;
    const int row = m_items.indexOf(t);
    if (row >= 0) {
        beginRemoveRows({}, row, row);
        m_items.removeAt(row);
        endRemoveRows();
    }
    m_pending.removeAll(t);
    zwlr_foreign_toplevel_handle_v1_destroy(handle);
    delete t;
    emit windowsChanged();
}

void ToplevelModel::onFinished()
{
    zwlr_foreign_toplevel_manager_v1_destroy(m_manager);
    m_manager = nullptr;
    emit availableChanged();
}

int ToplevelModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant ToplevelModel::data(const QModelIndex &idx, int role) const
{
    if (!idx.isValid() || !valid(idx.row()))
        return {};
    const Toplevel *t = m_items.at(idx.row());
    switch (role) {
    case TitleRole: return t->title;
    case AppIdRole: return t->appId;
    case ActivatedRole: return t->activated;
    case MinimizedRole: return t->minimized;
    case MaximizedRole: return t->maximized;
    case FullscreenRole: return t->fullscreen;
    }
    return {};
}

QHash<int, QByteArray> ToplevelModel::roleNames() const
{
    return {{TitleRole, "title"}, {AppIdRole, "appId"}, {ActivatedRole, "activated"},
            {MinimizedRole, "minimized"}, {MaximizedRole, "maximized"},
            {FullscreenRole, "fullscreen"}};
}

QVariantList ToplevelModel::windows() const
{
    QVariantList out;
    for (int i = 0; i < m_items.size(); ++i) {
        const Toplevel *t = m_items.at(i);
        out << QVariantMap{{"index", i}, {"title", t->title}, {"appId", t->appId},
                           {"activated", t->activated}, {"minimized", t->minimized},
                           {"maximized", t->maximized}, {"fullscreen", t->fullscreen}};
    }
    return out;
}

int ToplevelModel::activeIndex() const
{
    for (int i = 0; i < m_items.size(); ++i)
        if (m_items.at(i)->activated && !m_items.at(i)->minimized)
            return i;
    return -1;
}

QString ToplevelModel::activeTitle() const
{
    const int i = activeIndex();
    return i < 0 ? QString() : m_items.at(i)->title;
}
QString ToplevelModel::activeAppId() const
{
    const int i = activeIndex();
    return i < 0 ? QString() : m_items.at(i)->appId;
}
bool ToplevelModel::activeMaximized() const
{
    const int i = activeIndex();
    return i >= 0 && m_items.at(i)->maximized;
}
bool ToplevelModel::activeFullscreen() const
{
    const int i = activeIndex();
    return i >= 0 && m_items.at(i)->fullscreen;
}

void ToplevelModel::activate(int index)
{
    if (!valid(index) || !m_seat)
        return;
    Toplevel *t = m_items.at(index);
    if (t->minimized)
        zwlr_foreign_toplevel_handle_v1_unset_minimized(t->handle);
    zwlr_foreign_toplevel_handle_v1_activate(t->handle, m_seat);
    flush();
}

void ToplevelModel::minimize(int index)
{
    if (!valid(index))
        return;
    // Hyprland keeps minimised windows on a hidden workspace (hyprland.lua);
    // the request below reaches it as a "window.minimize" event, and for the
    // window in front we also ask directly.
    zwlr_foreign_toplevel_handle_v1_set_minimized(m_items.at(index)->handle);
    flush();
    if (System::compositor() == "hyprland" && index == activeIndex())
        System::runHypr("enclave.minimize()");
}

void ToplevelModel::toggleMaximize(int index)
{
    if (!valid(index))
        return;
    Toplevel *t = m_items.at(index);
    if (t->maximized)
        zwlr_foreign_toplevel_handle_v1_unset_maximized(t->handle);
    else
        zwlr_foreign_toplevel_handle_v1_set_maximized(t->handle);
    flush();
}

void ToplevelModel::close(int index)
{
    if (!valid(index))
        return;
    zwlr_foreign_toplevel_handle_v1_close(m_items.at(index)->handle);
    flush();
}

void ToplevelModel::toggleMinimize(int index)
{
    if (!valid(index))
        return;
    if (index == activeIndex())
        minimize(index);
    else
        activate(index);
}

void ToplevelModel::minimizeAll()
{
    if (System::compositor() == "hyprland") {
        System::runHypr("enclave.show_desktop()");
        return;
    }
    bool any = false;
    for (Toplevel *t : std::as_const(m_items))
        if (!t->minimized) {
            zwlr_foreign_toplevel_handle_v1_set_minimized(t->handle);
            any = true;
        }
    if (!any)   // second click on "show desktop" brings everything back
        for (Toplevel *t : std::as_const(m_items))
            zwlr_foreign_toplevel_handle_v1_unset_minimized(t->handle);
    flush();
}
