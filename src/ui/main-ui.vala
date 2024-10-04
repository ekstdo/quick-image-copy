[GtkTemplate (ui = "/com/ekstdo/quick-copy/ui/main.ui")]
public class MainUI : Adw.Window {
    [GtkChild]
    public unowned Gtk.Entry search_bar;

    [GtkChild]
    public unowned Gtk.Picture giphy_icon;

    public MainUI(Gtk.Application app) {
        Object(application: app);
    }
}
