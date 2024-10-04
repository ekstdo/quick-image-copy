private File DEFAULT_DATA_DIR;

private string save_folder;
Gtk.Button image_path_select;
Gtk.Entry image_path_entry;
Adw.Window window;

// Setup functions
public async void setup_data_folder() {
    if (!DEFAULT_DATA_DIR.query_exists ()) {
        DEFAULT_DATA_DIR.make_directory_with_parents ();
    }

    var imgs_folder = DEFAULT_DATA_DIR.get_child ("imgs");
    if (!imgs_folder.query_exists ()) {
        imgs_folder.make_directory();
    }

    var text_folder = DEFAULT_DATA_DIR.get_child ("text");
    if (!text_folder.query_exists ()) {
        text_folder.make_directory();
    }


    /*var emoji_folder = DEFAULT_DATA_DIR.get_child ("emojibase-data");
    if (!emoji_folder.query_exists ()) {
        var tar_file = DEFAULT_DATA_DIR.get_child("emojibase-data.tgz");
        download_file(EMOJIBASE_URL, tar_file);
        var path = tar_file.get_path();
        Process.spawn_command_line_sync(@"tar zxvf $path");
        tar_file.delete();
        DEFAULT_DATA_DIR.get_child("package").move(emoji_folder, FileCopyFlags.NONE);
    }*/
}

public Gee.ArrayList<EmojiEntry?> load_emoji_entries (string locale) {
    Json.Parser parser = new Json.Parser ();
    parser.load_from_file (@"/node_modules/emojibase-data/$locale/compact.json");
    Json.Node node = parser.get_root ();


    if (node.get_node_type () != Json.NodeType.ARRAY) {
        throw new EmojiConfigError.INVALID_FORMAT ("Unexpected element type %s", node.type_name ());
    }

    var list = new Gee.ArrayList<EmojiEntry?> ();

    return list;
}

public struct EmojiEntry {
    public char group;
    public string hexcode;
    public string label;
    public uint order;
    public string[] tags;
    public string unicode;
}

async void load_image_folder (File file) {
    var file_path = file.get_path ();

    if (file_path == null) {
        warning ("Error: file has no path\n");
        return;
    }
    save_folder = file_path;
    image_path_entry.buffer.set_text (file_path.data);
}

async void select_image_folder () throws Error {
    var file_dialog = new Gtk.FileDialog ();
    var file = yield file_dialog.select_folder (window, null);

    load_image_folder (file);
}


// network utility funcitons
private async void download_file (string url, File file) throws Error {
    var file_from_http = File.new_for_uri (url);
    file_from_http.copy(file, FileCopyFlags.OVERWRITE);
}

private async Bytes ? get_image_bytes (string url) throws Error {
    var session = new Soup.Session ();
    var message = new Soup.Message.from_uri ("GET", Uri.parse (url, NONE));

    Bytes image_bytes = yield session.send_and_read_async (message, Priority.DEFAULT, null);

    Soup.Status status = message.get_status ();
    string reason = message.reason_phrase;

    if (status != Soup.Status.OK) {
        throw new MessageError.FAILED (@"Got $status: $reason");
    }

    return image_bytes;
}

async void list_dir (File dir) {
    try {
        var e = yield dir.enumerate_children_async (FileAttribute.STANDARD_NAME, 0, Priority.DEFAULT, null);

        while (true) {
            var files = yield e.next_files_async (10, Priority.DEFAULT, null);

            if (files == null) {
                break;
            }
            foreach (var info in files) {
                print ("- %s\n", info.get_name ());
            }
            print ("hi");
        }
    } catch (Error err) {
        warning ("Error: %s\n", err.message);
    }
}

public async void main () {
    DEFAULT_DATA_DIR = File.new_for_path (Environment.get_user_data_dir () + "/quick-copy");
    setup_data_folder();

    print("setup done\n");


    var builder = new Gtk.Builder();
    builder.add_from_resource ("/com/ekstdo/quick-copy/ui/main.ui");
    print("builder done\n");

    window = (Adw.Window) builder.get_object ("window");
    try {
        var picture = (Gtk.Picture) builder.get_object ("giphy-icon");
        Bytes image_bytes = yield get_image_bytes (GIPHY_ICON);

        picture.paintable = Gdk.Texture.from_bytes (image_bytes);
    } catch (Error e) {
        critical (e.message);
    }

    var searchBar = (Gtk.Entry) builder.get_object ("search-bar");
    searchBar.grab_focus_without_selecting ();

    load_image_folder ((DEFAULT_DATA_DIR));

    image_path_select = (Gtk.Button) builder.get_object ("image-path-select");
    image_path_select.clicked.connect (() => select_image_folder ());

    image_path_entry = (Gtk.Entry) builder.get_object ("image-path");
    image_path_entry.buffer.set_text (save_folder.data);

    load_emoji_entries ("de");

    /* button_overview.clicked.connect (() => overview.open = true); */
}

