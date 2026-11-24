// Enclave Shell — the Ember theme engine.
// Loads desktop/design-system/tokens/ember.json (installed to
// /usr/share/enclave/design-system/ember.json) and exposes the palette for the
// current appearance to every QML surface. No surface hard-codes a colour.
#pragma once
#include <QObject>
#include <QVariantMap>
#include <QJsonObject>

class Theme : public QObject {
    Q_OBJECT
    // "light", "dark" or "system"; persisted in ~/.config/enclave/shell.conf
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY changed)
    Q_PROPERTY(bool dark READ dark NOTIFY changed)
    Q_PROPERTY(QVariantMap c READ palette NOTIFY changed)        // role -> colour
    Q_PROPERTY(QVariantMap brand READ brand CONSTANT)
    Q_PROPERTY(QVariantMap status READ status CONSTANT)
    Q_PROPERTY(QVariantMap radius READ radius CONSTANT)
    Q_PROPERTY(QVariantMap motion READ motion NOTIFY changed)
    Q_PROPERTY(QString fontFamily READ fontFamily CONSTANT)
    Q_PROPERTY(int taskbarHeight READ taskbarHeight CONSTANT)
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY changed)
    Q_PROPERTY(QString iconTheme READ iconTheme NOTIFY changed)
    Q_PROPERTY(QString source READ source CONSTANT)

public:
    explicit Theme(QObject *parent = nullptr);

    QString mode() const { return m_mode; }
    void setMode(const QString &mode);
    bool dark() const;
    QVariantMap palette() const;
    QVariantMap brand() const { return m_brand; }
    QVariantMap status() const { return m_status; }
    QVariantMap radius() const { return m_radius; }
    QVariantMap motion() const;
    QString fontFamily() const { return m_font; }
    int taskbarHeight() const { return m_taskbarHeight; }
    bool reducedMotion() const { return m_reducedMotion; }
    void setReducedMotion(bool on);
    QString iconTheme() const;
    QString source() const { return m_source; }

    Q_INVOKABLE void toggleDark() { setMode(dark() ? "light" : "dark"); }

signals:
    void changed();

private:
    void load();
    void save() const;

    QString m_source;
    QString m_mode = "light";
    QVariantMap m_light, m_dark, m_brand, m_status, m_radius, m_motion;
    QString m_font = "Inter";
    int m_taskbarHeight = 52;
    bool m_reducedMotion = false;
};
