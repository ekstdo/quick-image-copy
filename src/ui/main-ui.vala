[GtkTemplate (ui = "/com/ekstdo/quick-copy/ui/images.ui")]
public class ImageTab : Gtk.Box {
    [GtkChild]
    public unowned Gtk.Button path_select;

    [GtkChild]
    public unowned Gtk.Entry path;

    [GtkChild]
    public unowned Gtk.Box categories;

    [GtkChild]
    public unowned Gtk.FlowBox results;

    [GtkChild]
    public unowned Gtk.SpinButton width;

    [GtkChild]
    public unowned Gtk.SpinButton height;

    [GtkChild]
    public unowned Gtk.DropDown aspect_ratio;

    [GtkChild]
    public unowned Gtk.DropDown interpolation;

    [GtkChild]
    public unowned Gtk.Label label;

    [GtkChild]
    public unowned Gtk.Box tags;

    [GtkChild]
    public unowned Gtk.Box info;

    [GtkChild]
    public unowned Gtk.Label score;

    [GtkChild]
    public unowned Gtk.Image preview;


}

[GtkTemplate (ui = "/com/ekstdo/quick-copy/ui/emojis.ui")]
public class EmojiTab : Gtk.Box {
    [GtkChild]
    public unowned Gtk.Box display;

    [GtkChild]
    public unowned Gtk.FlowBox results;

    [GtkChild]
    public unowned Gtk.Label label;

    [GtkChild]
    public unowned Gtk.Label score;

    [GtkChild]
    public unowned Gtk.Box tags;

    [GtkChild]
    public unowned Gtk.FlowBox variants;
}

[GtkTemplate (ui = "/com/ekstdo/quick-copy/ui/main.ui")]
public class MainUI : Adw.Window {
    [GtkChild]
    public unowned Gtk.Entry search_bar;

    [GtkChild]
    public unowned Gtk.Picture giphy_icon;

    [GtkChild]
    public unowned Gtk.Notebook tabs;

    [GtkChild]
    public unowned EmojiTab emojis;

    [GtkChild]
    public unowned ImageTab images;

    public MainUI(Gtk.Application app) {
        Object(application: app);
    }
}
