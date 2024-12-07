public void remove_children(Gtk.Box w) {
    var first_child = w.get_first_child();
    while (first_child != null){
        w.remove(first_child);
        first_child = w.get_first_child();
    }
}
