// Enclave Shell — "image://icon/<name-or-path>[?color=#rrggbb]".
// Resolves freedesktop icon names through the Enclave icon theme; symbolic
// icons can be recoloured so they follow the Ember light/dark palette.
#pragma once
#include <QIcon>
#include <QPainter>
#include <QQuickImageProvider>
#include <QUrlQuery>

class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override
    {
        QString name = id;
        QColor tint;
        const int q = id.indexOf('?');
        if (q >= 0) {
            name = id.left(q);
            const QUrlQuery query(id.mid(q + 1));
            if (query.hasQueryItem("color"))
                tint = QColor(query.queryItemValue("color", QUrl::FullyDecoded));
        }
        const int edge = requested.isValid() ? qMax(requested.width(), requested.height()) : 48;

        QIcon icon;
        if (name.startsWith('/'))
            icon = QIcon(name);
        else if (!name.isEmpty())
            icon = QIcon::fromTheme(name);
        if (icon.isNull())
            icon = QIcon::fromTheme("application-x-executable");
        QPixmap pm = icon.pixmap(QSize(edge, edge));
        if (pm.isNull()) {
            pm = QPixmap(edge, edge);
            pm.fill(Qt::transparent);
        }
        if (tint.isValid()) {
            QPainter p(&pm);
            p.setCompositionMode(QPainter::CompositionMode_SourceIn);
            p.fillRect(pm.rect(), tint);
        }
        if (size)
            *size = pm.size();
        return pm;
    }
};
