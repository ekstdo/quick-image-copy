public class Entry : Object {
}

public class EmojiEntry: Object {
    public char group { get; set; }
    public string hexcode { get; set; }
    public string label { get; set; }
    public uint32 order { get; set; }
    public string[] tags { get; set; }
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

            // if (tag.contains(search)) {
            //     return true;
            // }
        }
        return false;
    }

    public int score(string search) {
        var label_score_row = needleman_wunsch_score(search, label);
        var label_score = label_score_row[label_score_row.length - 1];
        var result = label_score;
        foreach (var tag in tags) {
            // stdout.printf("tag cmp %s with %s\n", tag, search);
            var temp = needleman_wunsch_score(search, tag);
            if (temp[temp.length - 1] + label_score > result) {
                result = temp[temp.length - 1] + label_score;
            }
        }
        return result + label_score;
    }
}


// {"group":9,"hexcode":"1F1F9-1F1EC","label":"Togo","order":4997,"tags":["TG"],"unicode":"🇹🇬"}

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


