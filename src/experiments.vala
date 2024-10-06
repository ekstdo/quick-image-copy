private File DEFAULT_DATA_DIR;

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

    image_path_select = (Gtk.Button) builder.get_object ("image-path-select");
    image_path_select.clicked.connect (() => select_image_folder ());

    image_path_entry = (Gtk.Entry) builder.get_object ("image-path");
    image_path_entry.buffer.set_text (save_folder.data);

    var emoji_lists = load_emoji_entries ("de");


    /* button_overview.clicked.connect (() => overview.open = true); */
}

