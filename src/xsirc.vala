using Gee;
namespace XSIRC {
	public bool irc_user_is_privileged(string user) {
		return /^(&|@|%|\+|~)/.match(user);
	}
	namespace Main {
		public static GUI gui;
		public static ConfigManager config_manager;
		public static ConfigManager.ConfigAccessor config;
		public static unowned KeyFile config_file;
		public static ServerManager server_manager;
		public static MacroManager macro_manager;
		public static PluginManager plugin_manager;
	}
}
