private const string GIPHY_ICON = "https://giphy.com/static/img/favicon.png";



public errordomain EmojiConfigError {
    UNKNOWN_LOCALE,
    INVALID_FORMAT
}



public class QuickCopy : Adw.Application {
    public MainUI main_window;
    private File data_folder;
    
    private static QuickCopy _instance;
    public static QuickCopy instance {
        get {
            if (_instance == null)
                _instance = new QuickCopy();
            return _instance;
        }
    }

    construct {
        application_id = "com.ekstdo.quick-copy";
        flags = ApplicationFlags.DEFAULT_FLAGS;
        data_folder = File.new_for_path (Environment.get_user_data_dir () + "/quick-copy");
    }
    

    public async void load_giphy_icon() {
        try {
            Bytes image_bytes = yield get_image_bytes (GIPHY_ICON);
            main_window.giphy_icon.paintable = Gdk.Texture.from_bytes (image_bytes);
        } catch (Error e) {
            critical (e.message);
            // removes the giphy page, when not avaialable
            main_window.tabs.remove_page(2);
        }
    }

    async void load_image_folder (File file) {
        var file_path = file.get_path ();

        if (file_path == null) {
            warning ("Error: file has no path\n");
            return;
        }
        data_folder = File.new_for_path(file_path);
        main_window.image_path.buffer.set_text (file_path.data);
    }

    async void select_image_folder () throws Error {
        var file_dialog = new Gtk.FileDialog ();
        var file = yield file_dialog.select_folder (main_window, null);

        load_image_folder (file);
    }

    public override void activate() {
        if (main_window != null) {
            main_window.present();
            return;
        }
        
        main_window = new MainUI(this);
        
        main_window.present ();

        main_window.search_bar.grab_focus_without_selecting ();

        load_image_folder (data_folder);

        main_window.image_path_select.clicked.connect (() => select_image_folder ());

        main_window.image_path.buffer.set_text (data_folder.get_path().data);

        var emoji_entries = load_emoji_entries("de");
        var gdk_display = Gdk.Display.get_default();
        var clipboard = gdk_display.get_clipboard();

        string[] group_labels = { "smileys-emotion", "people-body", "component", "animals-nature", "food-drink", "travel-places", "activities", "objects", "symbols", "flags" };
        for (var index = 0; index < group_labels.length; index++) {
            var grouped_emojis = emoji_entries[index];
            var expander = new Gtk.Expander(group_labels[index]);
            expander.expanded = true;

            var flowbox = new Gtk.FlowBox() {
                max_children_per_line = 10
            };
            flowbox.bind_model(grouped_emojis, (emoji) => {
                var label = ((EmojiEntry)emoji).unicode;
                var button = new Gtk.Button.with_label(label);
                button.clicked.connect(() => clipboard.set_text(label) );
                return button;
              }
            );
            expander.child = flowbox;
            main_window.emoji_stuff.append(expander);
        }
        load_giphy_icon.begin ();
    }
    
    public static int main(string[] args) {
        var app = QuickCopy.instance;
        return app.run(args);
    }
}
