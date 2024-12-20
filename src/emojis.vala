public int needleman_with_back(int[] arr) {
    var val = arr[arr.length - 1];
    var back_cost = 0;
    for (var i = arr.length - 2; i > 0; i--) {
        back_cost -= 3;
        if (back_cost + arr[i] > val) {
            val = arr[i] + back_cost;
        }
    }
    return val;
}

public class Entry : Object {
    public string label { get; set; }
    public string[] tags { get; set; }

    public bool match(string search) {
        int n = search.length;
        int minimum = n / 3;
        if (match_strs(label, search, minimum)) {
            return true;
        }
        foreach (var tag in tags) {
            if (match_strs(tag, search, minimum)) {
                return true;
            }
        }
        return false;
    }

    public int score(string search) {
        var label_score = needleman_with_back(needleman_wunsch_score(search, label));
        var result = label_score;
        foreach (var tag in tags) {
            // stdout.printf("tag cmp %s with %s\n", tag, search);
            var temp = needleman_with_back(needleman_wunsch_score(tag, search));
            if (temp > result) {
                result = temp;
            }
        }
        return result;
    }
}

public class ImageEntry: Entry {
    public string path { get; set; }
    public Gdk.Pixbuf image { get; set; }

    public ImageEntry(string path, Gdk.Pixbuf image, string[] tags, string label){
        this.path = path;
        this.image = image;
        this.tags = tags;
        this.label = label;
    }
}

public class EmojiEntry: Entry {
    public char group { get; set; }
    public string hexcode { get; set; }
    public uint32 order { get; set; }
    public string unicode { get; set; }
    public EmojiEntry[]? skins { get; set; }

    public void parse_skins(Json.Node node) {
        Json.Object obj = node.get_object();
        if (!obj.has_member("skins")) return;
        Json.Array array = obj.get_member("skins").get_array();
        skins = new EmojiEntry[array.get_length()];
        int i = 0;
        foreach (unowned Json.Node item in array.get_elements ()) {
            EmojiEntry res_obj = Json.gobject_deserialize (typeof (EmojiEntry), item) as EmojiEntry;
            skins[i] = res_obj;
            i++;
        }
    }

}


// {"group":9,"hexcode":"1F1F9-1F1EC","label":"Togo","order":4997,"tags":["TG"],"unicode":"🇹🇬"}

public Gee.TreeMap<string, ObservableArrayList<ImageEntry>> load_image_entries(string parent_path) {
    var result = new Gee.TreeMap<string, ObservableArrayList<ImageEntry>>();
    Dir parent_folder = Dir.open(parent_path);
    string? name = null;

    while((name = parent_folder.read_name()) != null) {
        string path = Path.build_filename(parent_path, name);

        if (!FileUtils.test (path, FileTest.IS_DIR)) {
            continue;
        }

        Dir folder = Dir.open(path);
        string? sub_name = null;
        var arr_list = new ObservableArrayList<ImageEntry>();
        var folder_name = Path.get_basename(path);

        while((sub_name = folder.read_name()) != null) {
            Gdk.Pixbuf pixbuf;
            string sub_path = Path.build_filename(path, sub_name);
            try {
                pixbuf = new Gdk.Pixbuf.from_file(sub_path);
            } catch (FileError e) {
                continue;
            } catch (Error e) {
                continue;
            }

            int dot = sub_name.last_index_of_char('.');
            string label = sub_name.substring(0, dot);

            ImageEntry entry = new ImageEntry(sub_name, pixbuf, new string[0], label);;
            arr_list.add(entry);
        }

        result[folder_name] = arr_list;
    }

    return result;

}

public ObservableArrayList<EmojiEntry>[] load_emoji_entries (string locale) throws Error {
    Json.Parser parser = new Json.Parser ();
    var emojibase_resource = File.new_for_uri(@"resource:///emojibase/locales/$locale.json");
    parser.load_from_stream (emojibase_resource.read());
    Json.Node node = parser.get_root ();

    if (node.get_node_type () != Json.NodeType.ARRAY) {
        throw new EmojiConfigError.INVALID_FORMAT ("Unexpected element type %s", node.type_name ());
    }
    unowned Json.Array array = node.get_array ();


    ObservableArrayList<EmojiEntry>[] lists = {
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
        new ObservableArrayList<EmojiEntry> (),
    };

    foreach (unowned Json.Node item in array.get_elements ()) {
        EmojiEntry obj = Json.gobject_deserialize (typeof (EmojiEntry), item) as EmojiEntry;
        obj.parse_skins(item);
    
        lists[obj.group].add(obj);
    }

    return lists;
}


