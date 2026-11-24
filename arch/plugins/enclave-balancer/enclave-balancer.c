/*
 * Enclave OS — "balancer" panel plugin: true screen-centring for the taskbar.
 *
 * xfce4-panel lays plugins out in a single row and shares spare space equally
 * between expanding plugins. The taskbar is
 *
 *   [balancer][spacer][Start][apps][spacer][tray · volume · bell · clock · ▏]
 *
 * Two equal spacers alone would centre Start+apps in the space LEFT OF the tray
 * cluster, i.e. off-centre by half the tray's width. This invisible plugin
 * always sizes itself to exactly the width of everything after the last
 * expanding separator, so both sides carry the same fixed weight and the
 * middle group lands on the true centre of the screen — and it follows the
 * tray as icons appear or disappear.
 *
 * Works in vertical panels too (it balances heights instead).
 */
#include <gtk/gtk.h>
#include <libxfce4panel/libxfce4panel.h>

typedef struct
{
  XfcePanelPlugin *plugin;
  GtkWidget       *area;
  GtkWidget       *watched_parent;
  gint             size;
  guint            idle_id;
} Balancer;

/* Size (along the panel) of every plugin after the last expanding separator. */
static gint
balancer_trailing_size (Balancer *b)
{
  GtkWidget *self = GTK_WIDGET (b->plugin);
  GtkWidget *parent = gtk_widget_get_parent (self);
  GtkWidget *first_trailing = NULL;
  GList     *children, *l;
  gboolean   horizontal;
  gint       x = 0, y = 0, size = 0;
  GtkAllocation pa;

  if (!GTK_IS_CONTAINER (parent) || !gtk_widget_get_realized (parent))
    return 0;

  children = gtk_container_get_children (GTK_CONTAINER (parent));
  for (l = children; l != NULL; l = l->next)
    {
      GtkWidget *w = l->data;
      if (XFCE_IS_PANEL_PLUGIN (w)
          && xfce_panel_plugin_get_expand (XFCE_PANEL_PLUGIN (w))
          && g_strcmp0 (xfce_panel_plugin_get_name (XFCE_PANEL_PLUGIN (w)), "separator") == 0)
        first_trailing = (l->next != NULL) ? l->next->data : NULL;
    }

  horizontal = xfce_panel_plugin_get_orientation (b->plugin) == GTK_ORIENTATION_HORIZONTAL;

  if (first_trailing != NULL
      && gtk_widget_get_visible (first_trailing)
      && gtk_widget_get_realized (first_trailing)
      && gtk_widget_translate_coordinates (first_trailing, parent, 0, 0, &x, &y))
    {
      gtk_widget_get_allocation (parent, &pa);
      size = horizontal ? (pa.width - x) : (pa.height - y);
    }

  g_list_free (children);
  return MAX (size, 0);
}

static gboolean
balancer_update (gpointer data)
{
  Balancer *b = data;
  gint      size = balancer_trailing_size (b);

  b->idle_id = 0;
  if (size != b->size)
    {
      b->size = size;
      if (xfce_panel_plugin_get_orientation (b->plugin) == GTK_ORIENTATION_HORIZONTAL)
        gtk_widget_set_size_request (b->area, size, -1);
      else
        gtk_widget_set_size_request (b->area, -1, size);
    }
  return G_SOURCE_REMOVE;
}

static void
balancer_queue_update (Balancer *b)
{
  if (b->idle_id == 0)
    b->idle_id = g_idle_add (balancer_update, b);
}

static void
balancer_parent_allocated (GtkWidget *parent, GdkRectangle *alloc, gpointer data)
{
  balancer_queue_update (data);
}

static void
balancer_hierarchy_changed (GtkWidget *self, GtkWidget *previous, gpointer data)
{
  Balancer  *b = data;
  GtkWidget *parent = gtk_widget_get_parent (self);

  if (b->watched_parent == parent)
    return;
  if (b->watched_parent != NULL)
    g_signal_handlers_disconnect_by_func (b->watched_parent, balancer_parent_allocated, b);
  b->watched_parent = parent;
  if (parent != NULL)
    g_signal_connect (parent, "size-allocate", G_CALLBACK (balancer_parent_allocated), b);
  balancer_queue_update (b);
}

static void
balancer_orientation_changed (XfcePanelPlugin *plugin, GtkOrientation orientation, Balancer *b)
{
  b->size = -1;
  gtk_widget_set_size_request (b->area, -1, -1);
  balancer_queue_update (b);
}

static void
balancer_free (XfcePanelPlugin *plugin, Balancer *b)
{
  if (b->idle_id != 0)
    g_source_remove (b->idle_id);
  if (b->watched_parent != NULL)
    g_signal_handlers_disconnect_by_func (b->watched_parent, balancer_parent_allocated, b);
  g_slice_free (Balancer, b);
}

static void
balancer_construct (XfcePanelPlugin *plugin)
{
  Balancer *b = g_slice_new0 (Balancer);

  b->plugin = plugin;
  b->size = -1;

  /* Invisible: an empty area that only takes up space. */
  b->area = gtk_event_box_new ();
  gtk_event_box_set_visible_window (GTK_EVENT_BOX (b->area), FALSE);
  gtk_container_add (GTK_CONTAINER (plugin), b->area);
  gtk_widget_show (b->area);

  xfce_panel_plugin_set_expand (plugin, FALSE);
  xfce_panel_plugin_set_shrink (plugin, TRUE);

  g_signal_connect (plugin, "hierarchy-changed", G_CALLBACK (balancer_hierarchy_changed), b);
  g_signal_connect (plugin, "orientation-changed", G_CALLBACK (balancer_orientation_changed), b);
  g_signal_connect (plugin, "free-data", G_CALLBACK (balancer_free), b);

  balancer_hierarchy_changed (GTK_WIDGET (plugin), NULL, b);
}

XFCE_PANEL_PLUGIN_REGISTER (balancer_construct);
