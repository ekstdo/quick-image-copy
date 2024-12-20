private const string GIPHY_ICON = "https://giphy.com/static/img/favicon.png";

public errordomain EmojiConfigError {
    UNKNOWN_LOCALE,
    INVALID_FORMAT
}

public abstract class SearchPage {
    public int selected_index = -1;
    public bool searching = false;
    public abstract async void initialize();
    public abstract void search(Gtk.Editable t);
}

public class ImagePage: SearchPage {
    public MainUI main_window;
    private File data_folder;
    Gdk.Clipboard clipboard;
    public Gee.TreeMap<string, ObservableArrayList<ImageEntry>> data;
    public Gee.TreeMap<string, Gtk.FlowBox> category_flowboxes;
    Gee.TreeMap<string, int> score_map;
    ListStore search_results;
    public string? selected_category = null;
    int show_first_n_results = 100;

    public ImagePage(MainUI main_window, Gdk.Clipboard clipboard){
        this.main_window = main_window;
        this.clipboard = clipboard;
        this.search_results = new ListStore(typeof(ImageEntry));
    }

    async void load_images_folder (File file) {
        var file_path = file.get_path ();

        if (file_path == null) {
            warning ("Error: file has no path\n");
            return;
        }
        data = load_image_entries(file_path + "/imgs");
        data_folder = File.new_for_path(file_path);
        main_window.images.path.buffer.set_text (file_path.data);

        remove_children(main_window.images.categories);
        foreach (var entries in data) {
            category_flowboxes[entries.key] = new Gtk.FlowBox() {
                max_children_per_line = 10
            };
            category_flowboxes[entries.key].bind_model(entries.value, create_button);
            var copy_index = entries.key;
            category_flowboxes[copy_index].child_activated.connect((child) => select(child.get_index(), copy_index));

            var expander = new Gtk.Expander(entries.key) {
                expanded = true,
                child = category_flowboxes[entries.key]
            };

            main_window.images.categories.append(expander);
        }

        main_window.images.results.bind_model(search_results, create_button);
        main_window.images.results.child_activated.connect((child) => select(child.get_index(), null));
    }

    public Gtk.Widget create_button(Object image){
        ImageEntry entry = (ImageEntry) image;
        var child = new Gtk.FlowBoxChild();
        var texture = Gdk.Texture.for_pixbuf(entry.image);
        Gtk.Image images_widget = new Gtk.Image.from_paintable(texture);
        child.child = images_widget;

        var entry_controller = new Gtk.EventControllerMotion();
        entry_controller.enter.connect((x, y) => hover(entry));
        child.add_controller(entry_controller);
        var gesture_click = new Gtk.GestureClick();
        gesture_click.released.connect((n, x, y) => {
            if (n > 1) {
                clipboard.set_texture(texture);
            }
        });

        var keyboard_controller = new Gtk.EventControllerKey();
        keyboard_controller.key_pressed.connect((k, c, s) => {
            stdout.printf("%d %d\n", (int) k, (int) c);
            if (c == 36) { // Enter
                clipboard.set_texture(texture);
                return true;
            } else if (k >= 48 && k < 122) {
                main_window.search_bar.grab_focus_without_selecting ();
                var string_builder = new StringBuilder();
                string_builder.append_c((char) k);
                main_window.search_bar.buffer.insert_text(main_window.search_bar.buffer.get_length(), string_builder.str.data);
                main_window.search_bar.set_position(-1);
                return true;
            } else if (c == 9) {
                deselect();
                return true;
            }
            return false;
            });
        child.add_controller(gesture_click);
        child.add_controller(keyboard_controller);

        return child;
    }

    public Gtk.FlowBox selected_flowbox(string? category_name) {
        if (category_name == null) {
            return main_window.images.results;
        }
        return category_flowboxes[category_name];
    }

    public void deselect() {
        if (selected_index == -1) return;
        var flowbox = selected_flowbox(selected_category);
        flowbox.selected_foreach((box, child) => box.unselect_child(child));
        selected_index = -1;
    }

    public void select(int index, string? category) {
        if (category != selected_category) {
            deselect();
        }
        selected_index = index;
        selected_category = category;
        hover_by_index();
    }

    async void select_images_folder () throws Error {
        var file_dialog = new Gtk.FileDialog ();
        var file = yield file_dialog.select_folder (main_window, null);

        load_images_folder.begin (file);
    }

    public override async void initialize() {
        data_folder = File.new_for_path (Environment.get_user_data_dir () + "/quick-copy");
        category_flowboxes = new Gee.TreeMap<string, Gtk.FlowBox>();
        load_images_folder.begin(data_folder);
        main_window.images.path_select.clicked.connect (() => select_images_folder ());
        main_window.images.path.buffer.set_text (data_folder.get_path().data);

        main_window.images.width.text = "100";
        main_window.images.height.text = "100";


    }


    public override void search(Gtk.Editable t) {
        string search_string = t.get_text();
        if (((Gtk.Entry) t).buffer.length > 0) {
            main_window.images.categories.visible = false;
            main_window.images.results.visible = true;

            main_window.images.results.bind_model(new ListStore(typeof(ImageEntry)), create_button);
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
            search_results.splice(show_first_n_results, search_results.n_items - show_first_n_results, new ImageEntry[0]);
            main_window.images.results.bind_model(search_results, create_button);
            searching = true;
        } else {
            main_window.images.categories.visible = true;
            main_window.images.results.visible = false;
            search_results.remove_all();
            searching = false;
        }
    }

    public void hover_by_index(){
        if (selected_index == -1) {
            return;
        }
        if (selected_category == null) {
            hover((ImageEntry) search_results.get_item(selected_index), true);
        } else {
            hover((ImageEntry) data[selected_category].get_item(selected_index), true);
        }
    }

    public void hover(ImageEntry entry, bool overwrite = false) {
        if (selected_index != -1 && !overwrite) {
            return;
        }
        main_window.images.label.set_text(entry.label);
        remove_children(main_window.images.tags);
        if (entry.tags != null) 
        foreach (var tag in entry.tags) {
            var tag_label = new Gtk.Label(tag);
            main_window.images.tags.append(tag_label);
        }
        if (searching)
          main_window.images.score.set_text(score_map[entry.path].to_string());
        else
          main_window.images.score.set_text("");
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
    public int selected_category = -1;
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
            category_flowboxes[index].bind_model(grouped_emojis, (obj) => create_button(obj, index));
            var copy_index = index;
            category_flowboxes[index].child_activated.connect((child) => select(child.get_index(), copy_index));
            expander.child = category_flowboxes[index];
            main_window.emojis.display.append(expander);
        }

        this.result_bind_model(search_results);
        main_window.emojis.results.child_activated.connect((child) => select(child.get_index(), -1));
        main_window.emojis.variants.bind_model(variants, create_variant);
    }

    public Gtk.FlowBox selected_flowbox(int index) {
        if (index == -1) {
            return main_window.emojis.results;
        }
        return category_flowboxes[index];
    }

    public void deselect() {
        if (selected_index == -1) return;
        var flowbox = selected_flowbox(selected_category);
        flowbox.selected_foreach((box, child) => box.unselect_child(child));
        selected_index = -1;
    }

    public void select(int index, int category) {
        if (category != selected_category) {
            deselect();
        }
        selected_index = index;
        selected_category = category;
        hover_by_index();
    }

    public void hover_by_index(){
        if (selected_index == -1) {
            return;
        }
        if (selected_category == -1) {
            hover((EmojiEntry) search_results.get_item(selected_index), true);
        } else {
            hover((EmojiEntry) emoji_entries[selected_category].get_item(selected_index), true);
        }
    }

    public void hover(EmojiEntry entry, bool overwrite = false) {
        if (selected_index != -1 && !overwrite) {
            return;
        }
        main_window.emojis.label.set_text(entry.label);
        remove_children(main_window.emojis.tags);
        foreach (var tag in entry.tags) {
            var tag_label = new Gtk.Label(tag);
            main_window.emojis.tags.append(tag_label);
        }
        main_window.emojis.score.set_text(score_map[entry.unicode].to_string());
        variants.remove_all();
        if (entry.skins != null) {
            foreach (var skin in entry.skins)
                variants.append(skin);
        }
    }

    public Gtk.Widget create_button(Object emoji, int category = -1){
        EmojiEntry entry = (EmojiEntry) emoji;
        var label_text = entry.unicode;
        // var button = new Gtk.Button.with_label(label);
        var label = new Gtk.Label(label_text);
        var child = new Gtk.FlowBoxChild();
        child.child = label;

        var entry_controller = new Gtk.EventControllerMotion();
        entry_controller.enter.connect((x, y) => hover(entry));
        child.add_controller(entry_controller);
        var gesture_click = new Gtk.GestureClick();
        gesture_click.released.connect((n, x, y) => {
            if (n > 1) {
                clipboard.set_text(label_text);
            }
        });

        var keyboard_controller = new Gtk.EventControllerKey();
        keyboard_controller.key_pressed.connect((k, c, s) => {
            stdout.printf("%d %d\n", (int) k, (int) c);
            if (c == 36) { // Enter
                clipboard.set_text(label_text);
                return true;
            } else if (k >= 48 && k < 122) {
                main_window.search_bar.grab_focus_without_selecting ();
                var string_builder = new StringBuilder();
                string_builder.append_c((char) k);
                main_window.search_bar.buffer.insert_text(main_window.search_bar.buffer.get_length(), string_builder.str.data);
                main_window.search_bar.set_position(-1);
                return true;
            } else if (c == 9) {
                deselect();
                return true;
            }
            return false;
            });
        child.add_controller(gesture_click);
        child.add_controller(keyboard_controller);
        return child;
    }

    public Gtk.Button create_variant(Object emoji){
        EmojiEntry entry = (EmojiEntry) emoji;
        var label = entry.unicode;
        var button = new Gtk.Button.with_label(label);

        button.clicked.connect(() => {
            clipboard.set_text(label);
        });
        return button;
    }

    public void result_bind_model(ListModel list_model) {
        main_window.emojis.results.bind_model(list_model, (obj) => create_button(obj, -1));
    }

    public void calc_search_results(string search_string){
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
    }

    public override void search(Gtk.Editable t) {
        string search_string = t.get_text();
        deselect();
        if (((Gtk.Entry) t).buffer.length > 0) {
            searching = true;
            main_window.emojis.display.visible = false;
            main_window.emojis.results.visible = true;

            this.result_bind_model(new ListStore(typeof(EmojiEntry)));
            calc_search_results(search_string);
            this.result_bind_model(search_results);
        } else {
            searching = false;
            main_window.emojis.display.visible = true;
            main_window.emojis.results.visible = false;
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
            Bytes images_bytes = yield get_image_bytes (GIPHY_ICON);
            main_window.giphy_icon.paintable = Gdk.Texture.from_bytes (images_bytes);
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
            new EmojiPage(main_window, clipboard, "en"),
            new ImagePage(main_window, clipboard)
        };
        current_page = 0;
        foreach(var page in pages){
            page.initialize.begin();
        }
        main_window.search_bar.changed.connect((t) => {
            string search_string = t.get_text();
            int ind = search_string.index_of_char('>');
            if (ind != -1) {
                string before = search_string.substring(0, ind);
                string after = search_string.substring(ind + 1);
                int n = 1;
                int parsed_before = int.parse(before);
                if (parsed_before != 0) {
                    n = parsed_before;
                }

                for (var i = 0; i < n; i++) {
                    main_window.tabs.next_page();
                }
                t.set_text(after);
            }

            ind = search_string.index_of_char('<');
            if (ind != -1) {
                string before = search_string.substring(0, ind);
                string after = search_string.substring(ind + 1);
                int n = 1;
                int parsed_before = int.parse(before);
                if (parsed_before != 0) {
                    n = parsed_before;
                }

                for (var i = 0; i < n; i++) {
                    main_window.tabs.prev_page();
                }
                t.set_text(after);
            }
            pages[current_page].search(t);
        });
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


