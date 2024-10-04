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
