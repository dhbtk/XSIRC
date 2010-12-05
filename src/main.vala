using Gee;
namespace XSIRC {
	public static class Main {
		public static GUI gui;
		public static ConfigManager config_manager;
		public static HashMap<string,HashMap<string,string>> config;
		public static ServerManager server_manager;
		public static MacroManager macro_manager;
		public static PluginManager plugin_manager;
	}
	
	void main_loop() {
		while(!Main.gui.destroyed) {
			Main.gui.iterate();
			Main.server_manager.iterate();
			Posix.usleep(10);
		}
	}
	int main(string[] args) {
		Gtk.init(ref args);
		try {
			Gtk.Window.set_default_icon(new Gdk.Pixbuf.from_file(PREFIX+"/share/pixmaps/xsirc.png"));
		} catch(Error e) {
			
		}
		// Setting up some folder structure for stuff
		if(!FileUtils.test(Environment.get_user_config_dir()+"/xsirc",FileTest.EXISTS)) {
			DirUtils.create(Environment.get_user_config_dir()+"/xsirc",0755);
			DirUtils.create(Environment.get_user_config_dir()+"/xsirc/plugins",0755);
			DirUtils.create(Environment.get_user_config_dir()+"/xsirc/irclogs",0755);
		}
		// Starting up!
		Main.config_manager = new ConfigManager();
		Main.config = Main.config_manager.config;
		Main.server_manager = new ServerManager();
		Main.gui = new XSIRC.GUI();
		Main.macro_manager = new MacroManager();
		Main.server_manager.startup();
		Main.plugin_manager = new PluginManager();
		Main.plugin_manager.startup();

		main_loop();
		Main.server_manager.shutdown();
		return 0;
	}
}
