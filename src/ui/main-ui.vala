[GtkTemplate (ui = "/com/ekstdo/quick-copy/ui/main.ui")]
public class MainUI : Adw.Window {
    [GtkChild]
    public unowned Gtk.Entry search_bar;

    [GtkChild]
    public unowned Gtk.Picture giphy_icon;

    [GtkChild]
    public unowned Gtk.Notebook tabs;

    [GtkChild]
    public unowned Gtk.Button image_path_select;

    [GtkChild]
    public unowned Gtk.Entry image_path;

    [GtkChild]
    public unowned Gtk.Box emoji_stuff;

    public MainUI(Gtk.Application app) {
        Object(application: app);
    }
}
