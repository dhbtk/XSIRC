using Gee;
namespace XSIRC {
	public static class Main {
		public static GUI gui;
		public static ConfigManager config_manager;
		public static HashMap<string,HashMap<string,string>> config;
	}
	
	int main(string[] args) {
		Gtk.init(ref args);
		// Setting up some folder structure for stuff
		if(!FileUtils.test(Environment.get_home_dir()+"/.xsirc",FileTest.EXISTS)) {
			DirUtils.create(Environment.get_home_dir()+"/.xsirc",0755);
			DirUtils.create(Environment.get_home_dir()+"/.xsirc/plugins",0755);
			DirUtils.create(Environment.get_home_dir()+"/.xsirc/irclogs",0755);
		}
		// Starting up!
		Main.config_manager = new ConfigManager();
		Main.config = Main.config_manager.config;
		Main.gui = new XSIRC.GUI();

		// Daebug
		Main.gui.open_server("naos.foonetic.net");
		Main.gui.main_loop();
		return 0;
	}
}
