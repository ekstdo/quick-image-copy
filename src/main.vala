private const string GIPHY_ICON = "https://giphy.com/static/img/favicon.png";



public errordomain EmojiConfigError {
    UNKNOWN_LOCALE,
    INVALID_FORMAT
}

public class EmojiPage {
    Gdk.Clipboard clipboard;
    ObservableArrayList<EmojiEntry>[] emoji_entries;
    ListStore search_results;
    private string _locale;
    public string locale {
        get { return _locale; }
        set {
            _locale = value;
            emoji_entries = load_emoji_entries(value);
            search_results = new ListStore(typeof(EmojiEntry));
        }
    }
    string[] group_labels = { "smileys-emotion", "people-body", "component", "animals-nature", "food-drink", "travel-places", "activities", "objects", "symbols", "flags" };
    public MainUI main_window;
    public Gtk.FlowBox[] category_flowboxes;

    public EmojiPage(MainUI main_window, Gdk.Clipboard clipboard, string locale) {
        this.main_window = main_window;
        this.clipboard = clipboard;
        this.locale = locale;
    }


    public void initialize() {
        category_flowboxes = new Gtk.FlowBox[group_labels.length];
        for (var index = 0; index < group_labels.length; index++) {
            var grouped_emojis = emoji_entries[index];
            var expander = new Gtk.Expander(group_labels[index]);
            expander.expanded = true;

            category_flowboxes[index] = new Gtk.FlowBox() {
                max_children_per_line = 10
            };
            category_flowboxes[index].bind_model(grouped_emojis, (emoji) => {
                var label = ((EmojiEntry) emoji).unicode;
                var button = new Gtk.Button.with_label(label);
                button.clicked.connect(() => clipboard.set_text(label) );
                return button;
            });
            expander.child = category_flowboxes[index];
            main_window.emoji_stuff.append(expander);
        }

        main_window.emoji_results.bind_model(search_results, (emoji) => {
            var label = ((EmojiEntry) emoji).unicode;
            var button = new Gtk.Button.with_label(label);
            button.clicked.connect(() => clipboard.set_text(label) );
            return button;
        });

    }


    public void search(Gtk.Editable t) {
        string search = t.get_text();
        if (((Gtk.Entry) t).buffer.length > 0) {
            main_window.emoji_stuff.visible = false;
            main_window.emoji_results.visible = true;
            search_results.remove_all();
            foreach(var list in emoji_entries){
                foreach(var item in list){
                    if (item.match(search))
                        search_results.append(item);
                }
            }
            var score_map = new Gee.TreeMap<string, int>((a, b) => strcmp(a, b));
            search_results.sort((a, b) => {

                EmojiEntry a_ = (EmojiEntry) a;
                int score_a;
                if (score_map.has_key(a_.unicode)) {
                    score_a = score_map[a_.unicode];
                } else {
                    score_a = a_.score(search);
                    score_map[a_.unicode] = score_a;
                }
                EmojiEntry b_ = (EmojiEntry) b;
                int score_b;
                if (score_map.has_key(b_.unicode)) {
                    score_b = score_map[b_.unicode];
                } else {
                    score_b = b_.score(search);
                    score_map[b_.unicode] = score_b;
                }
                // stdout.printf("comparing %s with %s\n", a_.unicode, b_.unicode);
                return (score_a < score_b) ? -1 : (score_a == score_b) ? 0 : 1;
            });
            stdout.printf("oi\n");
        } else {
            main_window.emoji_stuff.visible = true;
            main_window.emoji_results.visible = false;
            search_results.remove_all();
        }
    }
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

        var gdk_display = Gdk.Display.get_default();
        var clipboard = gdk_display.get_clipboard();
        var emoji_page = new EmojiPage(main_window, clipboard, "de");


        /*
        var list1 = new ObservableArrayList<IntObj>();
        list1.add(new IntObj(4));
        list1.add(new IntObj(7));
        var list2 = new ObservableArrayList<IntObj>();
        list2.add(new IntObj(2));
        list2.add(new IntObj(3));
        var containers = new Gee.ArrayList<ObservableArrayList<IntObj>>();
        containers.add(list1);
        containers.add(list2);
        var test_collection = new ListModelCollection(containers);
        stdout.printf("yay: %d\n", ((IntObj) test_collection.get_item(3)).a);
        */

        emoji_page.initialize();
        main_window.search_bar.changed.connect((t) => emoji_page.search(t));
        load_giphy_icon.begin ();
    }



    public static int main(string[] args) {
        var app = QuickCopy.instance;
        return app.run(args);
    }
}


