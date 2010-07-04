using Gee;
namespace XSIRC {
	public class ConfigParser : Object {
		public static HashMap<string,HashMap<string,string>> parse_file(string fname,HashMap<string,HashMap<string,string>>? existing_hash = null) {
			string raw_file;
			FileUtils.get_contents(fname,out raw_file,null);
			string[] split_file = raw_file.split("\n");
			string section = "core"; // A default so things don't choke
			HashMap<string,HashMap<string,string>> result;
			if(existing_hash != null) {
				result = existing_hash;
			} else {
				result = new HashMap<string,HashMap<string,string>>();
				result["core"] = new HashMap<string,string>();
			}
			
			foreach(string raw_pair in split_file) {
				if(Regex.match_simple("^\\[[a-zA-Z]+\\]$",raw_pair)) {
					section = raw_pair[1:raw_pair.len()-2];
					if(!(section in result))
						result[section] = new HashMap<string,string>();
				} else if(!raw_pair.has_prefix(";") && Regex.match_simple("^.+=.+$",raw_pair)) { // Simple comments, INI-style
					string key;
					string val;
					key = raw_pair.split("=")[0];
					val = raw_pair.substring(key.len()+1).strip();
					key = key.strip();
					result[section][key] = val;
				}
			}
			return result;
		}
	}
	
	public class ConfigManager : Object {
		public HashMap<string,HashMap<string,string>> config = new HashMap<string,HashMap<string,string>>();
		
		public ConfigManager() {
			config["core"] = new HashMap<string,string>();
			// Some default config options
			config["core"]["nickname"]    = Environment.get_user_name();
			config["core"]["username"]    = Environment.get_user_name();
			config["core"]["realname"]    = Environment.get_user_name();
			config["core"]["quit_msg"]    = "Leaving";
			config["core"]["web_browser"] = "firefox %s";
			config["core"]["font"]        = "Monospace 10";
			config["core"]["timestamp_format"] = "[%H:%M:%S]";
			
			if(FileUtils.test(Environment.get_home_dir()+"/.xsirc/xsirc.conf",FileTest.EXISTS)) {
				ConfigParser.parse_file(Environment.get_home_dir()+"/.xsirc/xsirc.conf",config);
			}
		}
	}
}
