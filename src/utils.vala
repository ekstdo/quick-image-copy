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

public class IntObj: Object {
    public int a;
    public IntObj(int a){
        this.a = a;
    }
}

// binary search trees would ensure O(log n) modifications and O(log n) access, but would require O(n) new list insertions
// however n is < 100 here, so there is no need to optimize modifications
public class ListModelCollection: ListModel, Object {
    // a unified collection of ListModels
    Gee.ArrayList<ListModel> containers;
    Gee.ArrayList<uint> partial_sums;
    Type item_type;
    uint total = 0;
    uint virt_removed = 0;

    public ListModelCollection(Gee.ArrayList<ListModel> containers) {
        this.containers = containers;
        this.partial_sums = new Gee.ArrayList<int>();
        this.item_type = containers[0].get_item_type();
        var index = 0;

        foreach (var i in containers) {
            stdout.printf("construction: %d\n", index);
            var length = i.get_n_items();
            i.items_changed.connect((position, removed, added) => {
                var diff = added - removed;
                if (diff != 0) {
                    for (int partial_update = index + 1; partial_update < this.partial_sums.size; partial_update ++)
                        this.partial_sums[partial_update] += diff;
                }
                this.items_changed(this.partial_sums[index] + position, removed, added);
            });
            this.partial_sums.add(total);
            total += length;
            index ++;
        }
    }

    public ListModelCollection.from_array(ListModel[] containers) {
        this.containers = new Gee.ArrayList<ListModel>.wrap(containers);
        this.partial_sums = new Gee.ArrayList<int>();
        this.item_type = containers[0].get_item_type();
        var index = 0;

        foreach (var i in containers) {
            stdout.printf("construction: %d\n", index);
            var length = i.get_n_items();
            i.items_changed.connect((position, removed, added) => {
                var diff = added - removed;
                if (diff != 0) {
                    for (int partial_update = index + 1; partial_update < this.partial_sums.size; partial_update ++)
                        this.partial_sums[partial_update] += diff;
                }
                this.items_changed(this.partial_sums[index] + position, removed, added);
            });
            this.partial_sums.add(total);
            total += length;
            index ++;
        }
    }

    public uint get_n_items () {
        return total;
    }

    public Type get_item_type() {
        return this.item_type;
    }

    public Object? get_item(uint position){
        int partial_index = this.partial_sums.size / 2;
        int max_index = this.partial_sums.size; // exclusive
        int min_index = 0; // inclusive

        while (max_index > min_index) {
            uint partial_position = this.partial_sums[partial_index];
            if (partial_position > position)
                max_index = partial_index;
            if (partial_position < position)
                min_index = partial_index;
            if (partial_position == position) {
                min_index = partial_index;
                break;
            }
            partial_index = (min_index + max_index) / 2;
            if (partial_index == min_index) {
                break;
            }
        }
        // stdout.printf("current min-index: %d\n", min_index);
        uint partial_position = this.partial_sums[min_index];
        // stdout.printf("current partial_pos: %u\n", partial_position);
        ListModel container = this.containers[min_index];
        // stdout.printf("found container\n");
        return container.get_item(position - partial_position);
    }
    public void filter(){
    }
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

    // todo: implement `remove` method
}

public string dedup(string inp){
    Gee.TreeSet<unichar> unicode_cmp = new Gee.TreeSet<unichar>();

    unichar cx;
    int ic = 0;
    for (int i = 0; inp.get_next_char (ref ic, out cx); i++) {
        unicode_cmp.add(cx);
    }

    var builder = new StringBuilder ();
    foreach (var i in unicode_cmp) {
        builder.append_unichar(i);
    }

    return builder.str;
}

public bool match_strs(string a, string b, int minimum) {
    var counter = 0;
    unichar cx;
    int ic = 0;
    for (int i = 0; a.get_next_char (ref ic, out cx); i++) {

        unichar cy;
        int jc = 0;
        for (int j = 0; b.get_next_char (ref jc, out cy); j++) {
            if (cx == cy) {
                counter++;
                if (counter > minimum) 
                    return true;
            }
        }
    }
    return false;
}

public int max3(int i, int j, int k) {
    return i > j? (i > k? i: k): (j > k? j: k);
}

public int[] needleman_wunsch_score(owned string x, owned string y, int insert_cost = -1, int delete_cost = -1, int edit_cost = -2, int match_cost = 1) {
    
    var y_len = y.char_count ();
    var score = new int[y_len + 1];
    var accum = 0;
    for (var i = 0; i <= y_len; i++) {
        score[i] = accum;
        accum += insert_cost;
    }
    unichar cx;
    int ic = 0;
    for (int i = 0; x.get_next_char (ref ic, out cx); i++) {
        var prev = score[0];
        score[0] += delete_cost;
        var temp = score[0];

        unichar cy;
        int jc = 0;

    /* if (y.contains("„akzeptieren“")){
        stdout.printf("; %s\t\t\t", x);
        foreach (var i_ in score) {
            stdout.printf("%d,", i_);
        }
        stdout.printf("\n");
    }*/
        for (int j = 1; y.get_next_char (ref jc, out cy); j++) {
            bool same = cx == cy;
            temp = max3(
                temp + insert_cost,
                score[j] + delete_cost,
                prev + (same ? match_cost : edit_cost));
            prev = score[j];
            score[j] = temp;

            if (j > y.char_count()) {
                stdout.printf("ERROR: %s / %s \n", x, y);
            }
        }
    }

    /*if (y.contains("„akzeptieren“")){
        stdout.printf("%s: \t\t\t", y);
        foreach (var i in score) {
            stdout.printf("%d,", i);
        }
        stdout.printf("\n");
    }*/

    return score;
}
/*
string[] hirschberg_matching(string x, string y) {
    if (x.length == 0) {
        return new string[2]{ string.nfill(y.length, '-'), y };
    }
    if (y.length == 0) {
        return new string[2]{ x, string.nfill(x.length, '-') };
    }
    var z = new StringBuilder();
    var w = new StringBuilder();

    if (x.length == 1) {
        var index = y.index_of(x);
        if (index == -1) {
            z.append( x );
            z.append( string.nfill(y.length, '-') );
            w.append_c( '-' );
            w.append(y);
        } else {
            z.append( string.nfill(index, '-') );
            z.append( x );
            z.append( string.nfill(y.length - index) );
            w.append( string. );
        }
    } else if (y.length == 1) {
        var index = x.index_of(y);
        if (index == -1) {
            z.append( x );
            z.append( string.nfill(y.length, '-') );
            w.append_c( '-' );
            w.append(y);
        }
    }
}

function Hirschberg(X, Y)
    Z = ""
    W = ""
    if length(X) == 0
        for i = 1 to length(Y)
            Z = Z + '-'
            W = W + Yi
        end
    else if length(Y) == 0
        for i = 1 to length(X)
            Z = Z + Xi
            W = W + '-'
        end
    else if length(X) == 1 or length(Y) == 1
        (Z, W) = NeedlemanWunsch(X, Y)
    else
        xlen = length(X)
        xmid = length(X) / 2
        ylen = length(Y)

        ScoreL = NWScore(X1:xmid, Y)
        ScoreR = NWScore(rev(Xxmid+1:xlen), rev(Y))
        ymid = arg max ScoreL + rev(ScoreR)

        (Z,W) = Hirschberg(X1:xmid, y1:ymid) + Hirschberg(Xxmid+1:xlen, Yymid+1:ylen)
    end
    return (Z, W)

*/
