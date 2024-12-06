public class EmojiEntry: Object {
    public char group { get; set; }
    public string hexcode { get; set; }
    public string label { get; set; }
    public uint32 order { get; set; }
    public string[] tags { get; set; }
    public string unicode { get; set; }

    public bool match(string search) {
        foreach (var tag in tags) {
            if (tag.contains(search)) {
                return true;
            }
        }
        return false;
    }

    public int score(string search) {
        var result = 0;
        foreach (var tag in tags) {
            // stdout.printf("tag cmp %s with %s\n", tag, search);
            var temp = needleman_wunsch_score(search, tag);
            if (temp[temp.length - 1] > result) {
                result = temp[temp.length - 1];
            }
        }
        return result;
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
        lists[obj.group].add(obj);
    }

    return lists;
}


