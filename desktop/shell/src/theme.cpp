#include "theme.h"

#include <QColor>
#include <QFile>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonDocument>
#include <QSettings>
#include <QStandardPaths>
#include <QStyleHints>

namespace {
QVariantMap colours(const QJsonObject &o)
{
    QVariantMap m;
    for (auto it = o.begin(); it != o.end(); ++it) {
        // Tokens are #RRGGBB or #RRGGBBAA (CSS order); QColor wants #AARRGGBB.
        QString v = it.value().toString();
        if (v.size() == 9)
            v = "#" + v.mid(7, 2) + v.mid(1, 6);
        m.insert(it.key(), QColor(v));
    }
    return m;
}

QVariantMap numbers(const QJsonObject &o)
{
    QVariantMap m;
    for (auto it = o.begin(); it != o.end(); ++it)
        m.insert(it.key(), it.value().toDouble());
    return m;
}

QString settingsPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + "/enclave/shell.conf";
}
} // namespace

Theme::Theme(QObject *parent) : QObject(parent)
{
    load();
    QSettings s(settingsPath(), QSettings::IniFormat);
    m_mode = s.value("appearance/mode", "dark").toString();
    m_reducedMotion = s.value("appearance/reducedMotion", false).toBool();
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this, [this] {
        if (m_mode == "system")
            emit changed();
    });
    // Last resort for symbolic UI icons no theme in the chain has.
    QIcon::setFallbackThemeName("Adwaita");
    QIcon::setThemeName(iconTheme());
    connect(this, &Theme::changed, this, [this] { QIcon::setThemeName(iconTheme()); });
}

void Theme::load()
{
    const QStringList candidates = {
        qEnvironmentVariable("ENCLAVE_TOKENS"),
        "/usr/share/enclave/design-system/ember.json",
        QStringLiteral(ENCLAVE_SOURCE_TOKENS),
    };
    for (const QString &path : candidates) {
        if (path.isEmpty() || !QFile::exists(path))
            continue;
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly))
            continue;
        const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
        if (root.isEmpty())
            continue;
        m_source = path;
        m_brand = colours(root["brand"].toObject());
        m_status = colours(root["status"].toObject());
        m_light = colours(root["light"].toObject());
        m_dark = colours(root["dark"].toObject());
        m_radius = numbers(root["radius"].toObject());
        m_motion = numbers(root["motion"].toObject());
        m_font = root["type"].toObject()["family"].toString("Inter");
        m_taskbarHeight = root["taskbar"].toObject()["height"].toInt(76);
        return;
    }
    qWarning("enclave-shell: Ember tokens not found; using built-in fallback");
    m_source = "builtin";
    m_brand = {{"ember", QColor("#FF7A1A")}, {"solar", QColor("#FFAC55")},
               {"burnt", QColor("#E95B16")}, {"glow", QColor("#FFD0A6")}};
    m_light = {{"background", QColor("#F7F6F3")}, {"surface", QColor("#FFFFFF")},
               {"elevated", QColor("#EAE8E2")}, {"text", QColor("#202124")},
               {"textSecondary", QColor("#6B6860")}, {"accent", QColor("#E95B16")}};
    m_dark = {{"background", QColor("#101114")}, {"surface", QColor("#1A1C21")},
              {"elevated", QColor("#272A31")}, {"text", QColor("#F5F3EF")},
              {"textSecondary", QColor("#A7A39B")}, {"accent", QColor("#FF7A1A")}};
    m_radius = {{"small", 6}, {"medium", 12}, {"large", 20}, {"floating", 24}};
    m_motion = {{"fast", 150}, {"standard", 200}, {"slow", 250}};
}

bool Theme::dark() const
{
    if (m_mode == "system")
        return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    return m_mode == "dark";
}

QVariantMap Theme::palette() const { return dark() ? m_dark : m_light; }

QVariantMap Theme::motion() const
{
    if (!m_reducedMotion)
        return m_motion;
    QVariantMap none;
    for (auto it = m_motion.begin(); it != m_motion.end(); ++it)
        none.insert(it.key(), 0);
    return none;
}

QString Theme::iconTheme() const
{
    // Enclave Icons first; Papirus (their base) if they are missing, then the
    // GTK/freedesktop defaults.
    const QStringList wanted = dark() ? QStringList{"Enclave-dark", "Papirus-Dark", "Adwaita"}
                                      : QStringList{"Enclave", "Papirus", "Adwaita"};
    const QStringList roots = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, "icons",
                                                        QStandardPaths::LocateDirectory);
    for (const QString &name : wanted)
        for (const QString &dir : roots)
            if (QFile::exists(dir + "/" + name + "/index.theme"))
                return name;
    return "hicolor";
}

void Theme::setMode(const QString &mode)
{
    if (mode == m_mode || !QStringList{"light", "dark", "system"}.contains(mode))
        return;
    m_mode = mode;
    save();
    emit changed();
}

void Theme::setReducedMotion(bool on)
{
    if (on == m_reducedMotion)
        return;
    m_reducedMotion = on;
    save();
    emit changed();
}

void Theme::reload()
{
    QSettings s(settingsPath(), QSettings::IniFormat);
    m_mode = s.value("appearance/mode", "dark").toString();
    m_reducedMotion = s.value("appearance/reducedMotion", false).toBool();
    emit changed();
}

void Theme::save() const
{
    QSettings s(settingsPath(), QSettings::IniFormat);
    s.setValue("appearance/mode", m_mode);
    s.setValue("appearance/reducedMotion", m_reducedMotion);
}
