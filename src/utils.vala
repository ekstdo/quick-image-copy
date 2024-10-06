public errordomain MessageError {
    FAILED
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


public class ObservableArrayList<T> : ListModel, Gee.ArrayList<T> {
    public Object? get_item(uint position){
        if((int)position > size){
            return null;
        }

        return (Object?) this.get((int)position);
    }

    public Type get_item_type(){
        return element_type;
    }

    public uint get_n_items(){
        return (uint)size;
    }

    public new Object? get_object(uint position){
        if((int)position > size){
            return null;
        }
        return (Object) this.get((int)position);
    }
    
    public override bool add (T item) {
        var current_size = size;
        var result = base.add(item);
        if (result) {
            items_changed (current_size, 0, 1);
        }
        return result;
    }

    public override void insert (int index, T item) {
        base.insert(index, item);
    }

    public bool add_all_signal (Gee.Collection<T> collection) {
        var current_size = size;
        var result = base.add_all(collection);
        if (result) {
            items_changed (current_size, 0, collection.size);
        }
        return result;
    }

    public override T remove_at (int index) {
        var result = base.remove_at(index);
        items_changed (index, 1, 0);
        return result;
    }

    public override void clear () {
        var current_size = size;
        base.clear();
        items_changed(0, size, 0);
    }

    // todo: remove
}
