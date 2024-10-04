private const string GIPHY_ICON = "https://giphy.com/static/img/favicon.png";

public errordomain MessageError {
    FAILED
}

public errordomain EmojiConfigError {
    UNKNOWN_LOCALE,
    INVALID_FORMAT
}



public class QuickCopy : Adw.Application {
    public MainUI main_window;
    
    private static Example _instance;
    public static Example instance {
        get {
            if (_instance == null)
                _instance = new Example();
            
            return _instance;
        }
    }
    
    construct {
        application_id = "com.ekstdo.quick-copy";
        flags = ApplicationFlags.DEFAULT_FLAGS;
    }
    
    public override void activate() {
        if (main_window != null) {
            main_window.present();
            return;
        }
        
        main_window = new MainUI(this);
        
        main_window.present();
    }
    
    public static int main(string[] args) {
        var app = Example.instance;
        return app.run(args);
    }
}












