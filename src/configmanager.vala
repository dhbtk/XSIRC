/* configmanager.vala
 * 
 * Copyright (c) 2011 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class ConfigManager : Object {
		// This is just some syntatic sugar, saves some typing
		public class ConfigAcessor : Object {
			public class Bool : Object {
				// No error checking, double-check the code
				public new bool @get(string key) {
					bool result;
					try {
						result = Main.config_file.get_boolean("XSIRC",key);
					} catch(Error e) {
						
					}
					return result;
				}
				
				public new void @set(string key,bool val) {
					Main.config_file.set_boolean("XSIRC",key,val);
				}
			}
			public class Int : Object {
				// Once again, no error checking
				public new int @get(string key) {
					int result;
					try {
						result = Main.config_file.get_integer("XSIRC",key);
					} catch(Error e) {
						
					}
					return result;
				}
				
				public new void @set(string key,int val) {
					Main.config_file.set_integer("XSIRC",key,val);
				}
			}
			public class String : Object {
				// Returns null if not found
				public new string? @get(string key) {
					try {
						if(!Main.config_file.has_key("XSIRC",key)) {
							return null;
						}
					} catch(Error e) {
						return null;
					}
					string result;
					try {
						result = Main.config_file.get_string("XSIRC",key);
					} catch(Error e) {
						return null;
					}
					return result;
				}
				
				public new void @set(string key,string val) {
					Main.config_file.set_string("XSIRC",key,val);
				}
			}
			public Bool @bool;
			public Int @int;
			public String @string;
			public ConfigAcessor() {
				@bool = new Bool();
				@int = new Int();
				@string = new String();
			}
		}
		public KeyFile config = new KeyFile();
		public bool loaded_config = false;
		
		public ConfigManager() {
			if(FileUtils.test(Environment.get_user_config_dir()+"/xsirc/xsirc.conf",FileTest.EXISTS)) {
				try {
					config.load_from_file(Environment.get_user_config_dir()+"/xsirc/xsirc.conf",KeyFileFlags.KEEP_COMMENTS);
					loaded_config = true;
				} catch(KeyFileError e) {
					stderr.printf("Could not parse config file, using defaults\n");
				} catch(FileError e) {
					stderr.printf("Could not open config file\n");
				}
			}
			// Setting some default values for string settings
			HashMap<string,string> string_defaults = new HashMap<string,string>();
			string_defaults["nickname"] = Environment.get_user_name();
			string_defaults["sec_nickname"] = string_defaults["nickname"]+"_";
			string_defaults["ter_nickname"] = string_defaults["sec_nickname"]+"__";
			string_defaults["username"] = Environment.get_user_name();
			string_defaults["realname"] = Environment.get_user_name();
			string_defaults["away_msg"] = _("Away");
			string_defaults["quit_msg"] = _("Leaving.");
			string_defaults["log_file_name"] = "%F";
			string_defaults["log_folder"] = Environment.get_home_dir()+"/irclogs";
			string_defaults["timestamp_format"] = "%H:%M";
			string_defaults["web_browser"] = "xdg-open %s";
			string_defaults["completion_suffix"] = ": ";
			string_defaults["font"] = "Monospace 10";
			string_defaults["tab_pos"] = "bottom";
			string_defaults["userlist_pos"] = "left";
			// ints (currently just one)
			HashMap<string,int> int_defaults = new HashMap<string,int>();
			int_defaults["away_mins"] = 15;
			// bools
			HashMap<string,bool> bool_defaults = new HashMap<string,bool>();
			bool_defaults["logging_enabled"] = true;
			bool_defaults["show_user_list"] = true;
			bool_defaults["show_topic_bar"] = true;
			bool_defaults["show_status_bar"] = true;
			bool_defaults["show_timestamps"] = true;
			bool_defaults["tab_completion_enabled"] = true;
			
			foreach(string key in string_defaults.keys) {
				bool load_default = false;
				try {
					if(config.has_key("XSIRC",key)) {
						try {
							config.get_string("XSIRC",key);
						} catch(Error e) {
							load_default = true; // Wrong type, etc
						}
					} else {
						load_default = true;
					}
					if(load_default) {
						config.set_string("XSIRC",key,string_defaults[key]);
					}
				} catch(Error e) {}
			}
			foreach(string key in int_defaults.keys) {
				bool load_default = false;
				try {
					if(config.has_key("XSIRC",key)) {
						try {
							config.get_integer("XSIRC",key);
						} catch(Error e) {
							load_default = true;
						}
					} else {
						load_default = true;
					}
					if(load_default) {
						config.set_integer("XSIRC",key,int_defaults[key]);
					}
				} catch(Error e) {}
			}
			foreach(string key in bool_defaults.keys) {
				bool load_default = false;
				try {
					if(config.has_key("XSIRC",key)) {
						try {
							config.get_boolean("XSIRC",key);
						} catch(Error e) {
							load_default = true;
						}
					} else {
						load_default = true;
					}
					if(load_default) {
						config.set_boolean("XSIRC",key,bool_defaults[key]);
					}
				} catch(Error e) {}
			}
			try {
				IRCLogger.logging_enabled = config.get_boolean("XSIRC","logging_enabled");
			} catch(Error e) {
				
			}
		}
		
		public void save_settings() {
			try {
				FileUtils.set_contents(Environment.get_user_config_dir()+"/xsirc/xsirc.conf",config.to_data());
			} catch(Error e) {
				stderr.printf("Error saving settings: %s\n",e.message);
			}
		}
	}
}
