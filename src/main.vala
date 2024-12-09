private const string GIPHY_ICON = "https://giphy.com/static/img/favicon.png";



public errordomain EmojiConfigError {
    UNKNOWN_LOCALE,
    INVALID_FORMAT
}

public abstract class SearchPage {
    public abstract async void initialize();
    public abstract void search(Gtk.Editable t);
}

public class ImagePage: SearchPage {
    public MainUI main_window;
    private File data_folder;
    Gdk.Clipboard clipboard;
    public Gee.TreeMap<string, ObservableArrayList<ImageEntry>> data;
    public Gtk.FlowBox[] category_flowboxes;
    Gee.TreeMap<string, int> score_map;
    ListStore search_results;
    int show_first_n_results = 100;

    public ImagePage(MainUI main_window, Gdk.Clipboard clipboard){
        this.main_window = main_window;
        this.clipboard = clipboard;
        this.search_results = new ListStore(typeof(ImageEntry));
    }


    async void load_image_folder (File file) {
        var file_path = file.get_path ();

        if (file_path == null) {
            warning ("Error: file has no path\n");
            return;
        }
        data = load_image_entries(file_path + "/imgs");
        category_flowboxes = new Gtk.FlowBox[data.size];
        data_folder = File.new_for_path(file_path);
        main_window.image_path.buffer.set_text (file_path.data);

        remove_children(main_window.image_categories);
        int index = 0;
        foreach (var entries in data) {
            category_flowboxes[index] = new Gtk.FlowBox() {
                max_children_per_line = 10
            };
            category_flowboxes[index].bind_model(entries.value, create_button);

            var expander = new Gtk.Expander(entries.key) {
                expanded = true,
                child = category_flowboxes[index]
            };

            main_window.image_categories.append(expander);
            index += 1;
        }

        main_window.image_results.bind_model(search_results, create_button);
    }

    public Gtk.Button create_button(Object image){
        ImageEntry entry = (ImageEntry) image;
        var button = new Gtk.Button();
        var texture = Gdk.Texture.for_pixbuf(entry.image);
        Gtk.Image image_widget = new Gtk.Image.from_paintable(texture);
        button.set_child(image_widget);
        button.clicked.connect(() => clipboard.set_texture(texture) );

        return button;
    }

    async void select_image_folder () throws Error {
        var file_dialog = new Gtk.FileDialog ();
        var file = yield file_dialog.select_folder (main_window, null);

        load_image_folder.begin (file);
    }

    public override async void initialize() {
        data_folder = File.new_for_path (Environment.get_user_data_dir () + "/quick-copy");
        load_image_folder(data_folder);
        main_window.image_path_select.clicked.connect (() => select_image_folder ());
        main_window.image_path.buffer.set_text (data_folder.get_path().data);
    }


    public override void search(Gtk.Editable t) {
        string search_string = t.get_text();
        if (((Gtk.Entry) t).buffer.length > 0) {
            main_window.image_categories.visible = false;
            main_window.image_results.visible = true;

            main_window.image_results.bind_model(new ListStore(typeof(ImageEntry)), create_button);
            search_results.remove_all();
            string deduped = dedup(search_string);
            foreach(var entry in data){
                foreach(var item in entry.value){
                    if (item.match(deduped))
                        search_results.append(item);
                }
            }
            score_map = new Gee.TreeMap<string, int>((a, b) => strcmp(a, b));
            search_results.sort((a, b) => {
                ImageEntry a_ = (ImageEntry) a;
                int score_a;
                if (score_map.has_key(a_.path)) {
                    score_a = score_map[a_.path];
                } else {
                    score_a = a_.score(search_string);
                    score_map[a_.path] = score_a;
                }
                ImageEntry b_ = (ImageEntry) b;
                int score_b;
                if (score_map.has_key(b_.path)) {
                    score_b = score_map[b_.path];
                } else {
                    score_b = b_.score(search_string);
                    score_map[b_.path] = score_b;
                }
                return (score_a > score_b) ? -1 : (score_a == score_b) ? 0 : 1;
            });
            search_results.splice(show_first_n_results, search_results.n_items - show_first_n_results, new EmojiEntry[0]);
            main_window.image_results.bind_model(search_results, create_button);
        } else {
            main_window.image_categories.visible = true;
            main_window.image_results.visible = false;
            search_results.remove_all();
        }
    }
}

public class EmojiPage: SearchPage {
    Gdk.Clipboard clipboard;
    ObservableArrayList<EmojiEntry>[] emoji_entries;
    ListStore search_results;
    ListStore variants;
    uint show_first_n_results = 200;
    private Gee.TreeMap<string, int> score_map;
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
        this.score_map = new Gee.TreeMap<string, int>((a, b) => strcmp(a, b));
        this.variants = new ListStore(typeof(EmojiEntry));
    }


    public override async void initialize() {
        category_flowboxes = new Gtk.FlowBox[group_labels.length];
        for (var index = 0; index < group_labels.length; index++) {
            var grouped_emojis = emoji_entries[index];
            var expander = new Gtk.Expander(group_labels[index]);
            expander.expanded = true;

            category_flowboxes[index] = new Gtk.FlowBox() {
                max_children_per_line = 10
            };
            category_flowboxes[index].bind_model(grouped_emojis, create_button);
            expander.child = category_flowboxes[index];
            main_window.emoji_stuff.append(expander);
        }

        this.result_bind_model(search_results);
        main_window.emoji_variants.bind_model(variants, create_variant);
    }
    
    public Gtk.Button create_variant(Object emoji){
        EmojiEntry entry = (EmojiEntry) emoji;
        var label = entry.unicode;
        var button = new Gtk.Button.with_label(label);

        button.clicked.connect(() => clipboard.set_text(label) );
        return button;
    }

    public void select(EmojiEntry entry) {
        main_window.emoji_label.set_text(entry.label);
        remove_children(main_window.emoji_tags);
        foreach (var tag in entry.tags) {
            var tag_label = new Gtk.Label(tag);
            main_window.emoji_tags.append(tag_label);
        }
        main_window.emoji_score.set_text(score_map[entry.unicode].to_string());
        variants.remove_all();
        if (entry.skins != null) {
            foreach (var skin in entry.skins)
                variants.append(skin);
        }
    }

    public Gtk.Button create_button(Object emoji){
        EmojiEntry entry = (EmojiEntry) emoji;
        var label = entry.unicode;
        var button = new Gtk.Button.with_label(label);

        var entry_controller = new Gtk.EventControllerMotion();
        entry_controller.enter.connect((x, y) => select(entry));
        button.add_controller(entry_controller);
        button.clicked.connect(() => clipboard.set_text(label) );
        return button;
    }

    public void result_bind_model(ListModel list_model) {
        main_window.emoji_results.bind_model(list_model, create_button);
    }

    public override void search(Gtk.Editable t) {
        string search_string = t.get_text();
        if (((Gtk.Entry) t).buffer.length > 0) {
            main_window.emoji_stuff.visible = false;
            main_window.emoji_results.visible = true;

            this.result_bind_model(new ListStore(typeof(EmojiEntry)));
            search_results.remove_all();
            string deduped = dedup(search_string);
            foreach(var list in emoji_entries){
                foreach(var item in list){
                    if (item.match(deduped))
                        search_results.append(item);
                }
            }
            score_map = new Gee.TreeMap<string, int>((a, b) => strcmp(a, b));
            search_results.sort((a, b) => {

                EmojiEntry a_ = (EmojiEntry) a;
                int score_a;
                if (score_map.has_key(a_.unicode)) {
                    score_a = score_map[a_.unicode];
                } else {
                    score_a = a_.score(search_string);
                    score_map[a_.unicode] = score_a;
                }
                EmojiEntry b_ = (EmojiEntry) b;
                int score_b;
                if (score_map.has_key(b_.unicode)) {
                    score_b = score_map[b_.unicode];
                } else {
                    score_b = b_.score(search_string);
                    score_map[b_.unicode] = score_b;
                }
                return (score_a > score_b) ? -1 : (score_a == score_b) ? 0 : 1;
            });
            search_results.splice(show_first_n_results, search_results.n_items - show_first_n_results, new EmojiEntry[0]);
            this.result_bind_model(search_results);
        } else {
            main_window.emoji_stuff.visible = true;
            main_window.emoji_results.visible = false;
            search_results.remove_all();
        }
    }
}


public class QuickCopy : Adw.Application {
    public MainUI main_window;
    public SearchPage[] pages;
    public uint current_page;
    
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

    


    public override void activate() {
        if (main_window != null) {
            main_window.present();
            return;
        }
        
        main_window = new MainUI(this);
        main_window.present ();


        main_window.search_bar.grab_focus_without_selecting ();

        var gdk_display = Gdk.Display.get_default();
        var clipboard = gdk_display.get_clipboard();

        pages = new SearchPage[2] {
            new EmojiPage(main_window, clipboard, "de"),
            new ImagePage(main_window, clipboard)
        };
        current_page = 0;
        foreach(var page in pages){
            page.initialize.begin();
        }
        main_window.search_bar.changed.connect((t) => pages[current_page].search(t));
        main_window.tabs.switch_page.connect((p, i) => {
            if (i < 2)
                current_page = i;
        });

        load_giphy_icon.begin ();
    }



    public static int main(string[] args) {
        var app = QuickCopy.instance;
        return app.run(args);
    }
}


