private const string GIPHY_ICON = "https://giphy.com/static/img/favicon.png";

public errordomain EmojiConfigError {
    UNKNOWN_LOCALE,
    INVALID_FORMAT
}

public abstract class SearchPage {
    public int selected_index = -1;
    public int selected_category = -1;
    public bool searching = false;
    public abstract async void initialize();
    public abstract void search(Gtk.Editable t);
    public Gtk.Widget sidebar;
    public Gdk.Clipboard clipboard;
    public abstract void on_enter();
}

public abstract class CategorizedSearchPage<T> : SearchPage {
    public ObservableArrayList<T>[] data;

    public ListStore filter_categories;
    public string[] category_names;
    public Gtk.FlowBox[] category_flowboxes;

    public ListStore search_results;
    public Gtk.FlowBox search_flowbox;

    public int show_first_n_results = 100;
    public abstract void hover(T entry, bool overwrite = false);

    // UI Method, selects the index and category in the UI
    // deselects all previously selected elements
    // assuming only one element can be selected at a time
    public void select(int index, int category) {
        if (category != selected_category) {
            deselect();
        }
        selected_index = index;
        selected_category = category;
        hover_by_index();
    }

    // get the currently selected flowbox, but also 
    // searching flowbox if a search is happening
    public Gtk.FlowBox selected_flowbox(int index) {
        if (index == -1) {
            return search_flowbox;
        }
        return category_flowboxes[index];
    }

    public void deselect() {
        if (selected_index == -1) return;
        var flowbox = selected_flowbox(selected_category);
        flowbox.selected_foreach((box, child) => box.unselect_child(child));
        selected_index = -1;
    }

    // obtains the data entry, which is currently selected
    public T? selected_entry() {
        // stdout.printf("IND: %d %d\n", selected_category, selected_index);
        if (selected_category == -1) {
            return (T?) search_results.get_item(selected_index);
        } else {
            return data[selected_category].get(selected_index);
        }
    }

    // selects the first element, which is currently displayed (either 
    // searching or not), if no previous selection was made
    public void default_select() {
        int to_be_selected_index = selected_index;
        int to_be_selected_category = selected_category;
        if (selected_index == -1) {
            to_be_selected_index = 0;
        }
        if (selected_category == -1 && !searching) {
            to_be_selected_category = 0;
        }
        select(to_be_selected_index, to_be_selected_category);
    }

    public void hover_by_index(){
        if (selected_index == -1) {
            return;
        }
        if (selected_category == -1) {
            hover((T) search_results.get_item(selected_index), true);
        } else {
            hover((T) data[selected_category].get_item(selected_index), true);
        }
    }
}

public class ImagePage: CategorizedSearchPage<ImageEntry> {
    public MainUI main_window;
    private File data_folder;
    Gee.TreeMap<string, int> score_map;
    public Gtk.ListBox sidebar_elem;

    public ImagePage(MainUI main_window, Gdk.Clipboard clipboard){
        this.main_window = main_window;
        this.clipboard = clipboard;
        this.search_results = new ListStore(typeof(ImageEntry));
        this.sidebar_elem = new Gtk.ListBox();
        this.sidebar = this.sidebar_elem;
        this.filter_categories = new ListStore(typeof(IndexedT<bool>));
        this.search_flowbox = main_window.images.results;
    }

    void decompose(Gee.TreeMap<string, ObservableArrayList<ImageEntry>> data) {
        category_names = new string[data.size];
        category_flowboxes = new Gtk.FlowBox[data.size];
        this.data = new ObservableArrayList<ImageEntry>[data.size];
        int index = 0;
        foreach (var entries in data) {
            category_names[index] = entries.key;
            this.data[index] = entries.value;
            index += 1;
        }
    }

    async void load_images_folder (File file) {
        var file_path = file.get_path ();

        if (file_path == null) {
            warning ("Error: file has no path\n");
            return;
        }
        decompose(load_image_entries(file_path + "/imgs"));
        data_folder = File.new_for_path(file_path);
        main_window.images.path.buffer.set_text (file_path.data);

        remove_children(main_window.images.categories);
        filter_categories.remove_all();
        for (var i = 0; i < data.length; i++) {
            category_flowboxes[i] = new Gtk.FlowBox() {
                max_children_per_line = 10
            };
            category_flowboxes[i].bind_model(data[i], create_button);
            var copy_index = i;
            category_flowboxes[i].child_activated.connect((child) => select(child.get_index(), copy_index));

            var expander = new Gtk.Expander(category_names[i]) {
                expanded = true,
                child = category_flowboxes[i]
            };

            main_window.images.categories.append(expander);
            filter_categories.append(new IndexedT<bool>(i, true));
        }

        sidebar_elem.bind_model(filter_categories, (obj) => {
            var entry = (IndexedT<bool>) obj;
            var switch_filter = new Adw.SwitchRow();
            switch_filter.active = true;
            switch_filter.notify["active"].connect(() => {
                entry.data = switch_filter.get_active();
                category_flowboxes[entry.index].visible = switch_filter.get_active();
                if (searching) {
                    search(main_window.search_bar);
                }
            });
            switch_filter.title = category_names[entry.index];
            return switch_filter;
        });

        main_window.images.results.bind_model(search_results, create_button);
        main_window.images.results.child_activated.connect((child) => select(child.get_index(), -1));
    }

    public bool on_keypress(uint k, uint c, Gdk.ModifierType s) {
        stdout.printf("%d %d\n", (int) k, (int) c);
        var entry = selected_entry();
        if (c == 36) { // Enter
            clipboard.set_texture(Gdk.Texture.for_pixbuf(rescale(entry.image)));
            return true;
        } else if (k >= 48 && k < 122) {
            main_window.search_bar.grab_focus_without_selecting ();
            var string_builder = new StringBuilder();
            string_builder.append_c((char) k);
            main_window.search_bar.buffer.insert_text(main_window.search_bar.buffer.get_length(), string_builder.str.data);
            main_window.search_bar.set_position(-1);
            return true;
        } else if (c == 9) { // escape
            deselect();
            return true;
        }
        return false;
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
                clipboard.set_texture(Gdk.Texture.for_pixbuf(rescale(entry.image)));
            }
        });


        child.add_controller(gesture_click);

        return child;
    }

    async void select_images_folder () throws Error {
        var file_dialog = new Gtk.FileDialog ();
        var file = yield file_dialog.select_folder (main_window, null);

        load_images_folder.begin (file);
    }

    public override async void initialize() {
        data_folder = File.new_for_path (Environment.get_user_data_dir () + "/quick-copy");
        load_images_folder.begin(data_folder);
        main_window.images.path_select.clicked.connect (() => select_images_folder ());
        main_window.images.path.buffer.set_text (data_folder.get_path().data);

        main_window.images.width.value = 50;
        main_window.images.width.value_changed.connect(() => {
            hover_by_index();
        });
        main_window.images.height.value = 50;
        main_window.images.height.value_changed.connect(() => {
            hover_by_index();
        });
        main_window.images.aspect_ratio.set_selected(2);
        main_window.images.preview.icon_size = Gtk.IconSize.LARGE;

        var keyboard_controller = new Gtk.EventControllerKey();
        keyboard_controller.key_pressed.connect(on_keypress);
        main_window.images.add_controller(keyboard_controller);

    }


    public override void search(Gtk.Editable t) {
        string search_string = t.get_text();
        if (((Gtk.Entry) t).buffer.length > 0) {
            main_window.images.categories.visible = false;
            main_window.images.results.visible = true;

            main_window.images.results.bind_model(new ListStore(typeof(ImageEntry)), create_button);
            search_results.remove_all();
            string deduped = dedup(search_string);
            int index = 0;
            foreach(var entry in data){
                IndexedT<bool> do_filter = (IndexedT<bool>) filter_categories.get_item(index);
                index += 1;
                if (!do_filter.data) {
                    continue;
                }

                foreach(var item in entry){
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
            var show_n_entries = search_results.n_items < show_first_n_results ? search_results.n_items : show_first_n_results;
            search_results.splice(show_n_entries, search_results.n_items - show_n_entries, new ImageEntry[0]);
            main_window.images.results.bind_model(search_results, create_button);
            searching = true;
        } else {
            main_window.images.categories.visible = true;
            main_window.images.results.visible = false;
            search_results.remove_all();
            searching = false;
        }
    }



    public override void on_enter() {
        default_select();
        var selected = this.selected_entry();
        if (selected == null)
            return;
        clipboard.set_texture(Gdk.Texture.for_pixbuf(rescale(selected.image)));
    }

    public Gdk.Pixbuf rescale(Gdk.Pixbuf input) {
        int width, height;
        Gdk.InterpType interp_type;
        string selected_aspect_ratio = (string) main_window.images.aspect_ratio.get_selected_item();
        string interpolation = (string) main_window.images.interpolation.get_selected_item();
        if (selected_aspect_ratio == "no"){
            width = (int) main_window.images.width.value;
            height = (int) main_window.images.height.value;
        } else {
            double ratio = ((double) input.width) / ((double) input.height);
            if(selected_aspect_ratio == "keep width") {
                width = (int) main_window.images.width.value;
                height = (int) (main_window.images.width.value / ratio);
            } else {
                width = (int) (main_window.images.height.value * ratio);
                height = (int) main_window.images.height.value;
            }
        } 
        if (interpolation == "nearest") {
            interp_type = Gdk.InterpType.NEAREST;
        } else {
            interp_type = Gdk.InterpType.BILINEAR;
        }

        return input.scale_simple(width, height, interp_type);
    }

    public override void hover(ImageEntry entry, bool overwrite = false) {
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

        Gdk.Pixbuf rescaled = rescale(entry.image);
        Gdk.Texture texture = Gdk.Texture.for_pixbuf(rescaled);
        main_window.images.preview.set_from_paintable(texture);
        main_window.images.preview.pixel_size = rescaled.height;
        main_window.images.info.height_request = rescaled.height;
    }
}

class IndexedT<T>: Object {
    public uint index;
    public T data;

    public IndexedT(uint index, T data) {
        this.index = index;
        this.data = data;
    }
}

public class EmojiPage: CategorizedSearchPage<EmojiEntry> {
    ListStore variants;
    private Gee.TreeMap<string, int> score_map;
    private string _locale;
    public string locale {
        get { return _locale; }
        set {
            _locale = value;
            data = load_emoji_entries(value);
            search_results = new ListStore(typeof(EmojiEntry));
        }
    }
    string[] group_labels = { "smileys-emotion", "people-body", "component", "animals-nature", "food-drink", "travel-places", "activities", "objects", "symbols", "flags" };
    public MainUI main_window;
    Gtk.ListBox sidebar_elem;

    public EmojiPage(MainUI main_window, Gdk.Clipboard clipboard, string locale) {
        this.main_window = main_window;
        this.clipboard = clipboard;
        this.locale = locale;
        this.score_map = new Gee.TreeMap<string, int>((a, b) => strcmp(a, b));
        this.variants = new ListStore(typeof(EmojiEntry));
        this.sidebar_elem = new Gtk.ListBox();
        this.sidebar = this.sidebar_elem;
        this.show_first_n_results = 200;
    }

    public override async void initialize() {
        category_flowboxes = new Gtk.FlowBox[group_labels.length];
        filter_categories = new ListStore(typeof(IndexedT<bool>));
        for (var index = 0; index < group_labels.length; index++) {
            var grouped_emojis = data[index];
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

            filter_categories.append(new IndexedT<bool>(index, true));
        }

        sidebar_elem.bind_model(filter_categories, (obj) => {
            var entry = (IndexedT<bool>) obj;
            var switch_filter = new Adw.SwitchRow();
            switch_filter.active = true;
            switch_filter.notify["active"].connect(() => {
                entry.data = switch_filter.get_active();
                category_flowboxes[entry.index].visible = switch_filter.get_active();
                if (searching) {
                    search(main_window.search_bar);
                }
            });
            switch_filter.title = group_labels[entry.index];
            return switch_filter;
        });
        this.result_bind_model(search_results);
        main_window.emojis.results.child_activated.connect((child) => select(child.get_index(), -1));
        main_window.emojis.variants.bind_model(variants, create_variant);


        var keyboard_controller = new Gtk.EventControllerKey();
        keyboard_controller.key_pressed.connect((k, c, s) => {
            stdout.printf("%d %d\n", (int) k, (int) c);
            if (c == 36) { // Enter
                clipboard.set_text(selected_entry().unicode);
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
        main_window.emojis.add_controller(keyboard_controller);
    }

    public override void on_enter() {
        default_select();
        var selected = this.selected_entry();
        if (selected == null) {
            return;
        }
        clipboard.set_text(selected.unicode);
    }

    public override void hover(EmojiEntry entry, bool overwrite = false) {
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

        child.add_controller(gesture_click);
        return child;
    }

    public Gtk.Widget create_variant(Object emoji){
        EmojiEntry entry = (EmojiEntry) emoji;
        var label = entry.unicode;
        var child = new Gtk.FlowBoxChild();
        child.child = new Gtk.Label(label);

        var gesture_click = new Gtk.GestureClick();
        gesture_click.released.connect((n, x, y) => {
            clipboard.set_text(label);
        });
        child.add_controller(gesture_click);

        return child;
    }

    public void result_bind_model(ListModel list_model) {
        main_window.emojis.results.bind_model(list_model, (obj) => create_button(obj, -1));
    }

    public void calc_search_results(string search_string){
        search_results.remove_all();
        string deduped = dedup(search_string);
        int index = 0;
        foreach(var list in data){
            IndexedT<bool> do_filter = (IndexedT<bool>) filter_categories.get_item(index);
            index += 1;
            if (!do_filter.data) {
                continue;
            }
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
        var show_n_results = search_results.n_items < show_first_n_results ? search_results.n_items : show_first_n_results ;
        search_results.splice(show_n_results, search_results.n_items - show_n_results, new EmojiEntry[0]);
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
        main_window.split_view.sidebar = pages[current_page].sidebar;
        main_window.search_bar.activate.connect(() => {
            pages[current_page].on_enter();
        });
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
            if (i < 2) {
                current_page = i;
                main_window.split_view.sidebar = pages[current_page].sidebar;
            }
        });
        load_giphy_icon.begin ();
    }

    public static int main(string[] args) {
        var app = QuickCopy.instance;
        return app.run(args);
    }
}


