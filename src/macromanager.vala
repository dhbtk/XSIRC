using Gee;
namespace XSIRC {
	public class MacroManager : Object {
		public struct Macro {
			public string regex;
			public string result;
		}
		private LinkedList<Macro?> macros = new LinkedList<Macro?>();
		private KeyFile macros_file;
		private const Macro[] default_macros = {
			{"^me (.+)$","PRIVMSG $CURR_VIEW :ACTION $1"},
			{"^ctcp ([^ ]+) ([^ ]+) (.+)$","PRIVMSG $1 :$2 $3"},
			{"^ctcp ([^ ]+) ([^ ]+)$","PRIVMSG $1 :$2"},
			{"^msg ([^ ]+) (.+)$","PRIVMSG $1 :$2"},
			{"^notice ([^ ]+) (.+)$","NOTICE $1 :$2"},
			{"^part$","PART $CURR_VIEW"},
			{"^part (#[^ ]+)$","PART $1"},
			{"^part (#[^ ]+) (.+)$","PART $1 :$2"},
			{"^kick ([^ ]+)$","KICK $CURR_VIEW $1"},
			{"^kick ([^ ]+) (.+)$","KICK $CURR_VIEW $1 :$2"},
			{"^quit (.+)$","QUIT :$1"},
			{"^topic$","TOPIC $CURR_VIEW"},
			{"^topic (.+)$","TOPIC $CURR_VIEW :$1"},
			{"^mode$","MODE $CURR_VIEW"}
		};
		
		public MacroManager() {
			load_macros();
		}
		
		private void load_macros() {
			macros_file = new KeyFile();
			try {
				macros_file.load_from_file(Environment.get_user_config_dir()+"/xsirc/macros.conf",0);
			} catch(KeyFileError e) {
				Gtk.MessageDialog d = new Gtk.MessageDialog(Main.gui.main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,Gtk.ButtonsType.CLOSE,"Could not parse the macros file. Loading default macros.");
				d.response.connect((id) => {
					d.destroy();
				});
				d.run();
				load_default_macros();
				return;
			} catch(FileError e) {
				stderr.printf("Could not open macros.conf: %s\n",e.message);
				load_default_macros();
				return;
			}
			string k;
			string v;
			try {
				for(int i = 0; macros_file.has_key("macros","regex%d".printf(i)) && macros_file.has_key("macros","result%d".printf(i)); i++) {
					k = "regex%d".printf(i);
					v = "result%d".printf(i);
					Macro macro = Macro();
					try {
						// Testing if it compiles
						Regex test =  new Regex(k);
						macro.regex = k;
					} catch(RegexError e) {
						continue;
					}
					macro.result = v;
					macros.add(macro);
				}
			} catch(KeyFileError e) {
				
			}
		}
		
		private void load_default_macros() {
			foreach(Macro macro in default_macros) {
				macros.add(macro);
			}
		}
		
		public string? parse_string(string testee) {
			foreach(Macro macro in macros) {
				try {
					Regex regex = new Regex(macro.regex);
					MatchInfo info;
					if(regex.match(testee,0,out info)) {
						string result = macro.result;
						for(int i = 1; i <= 9 && i <= info.get_match_count(); i++) {
							if(info.fetch(i) != null) {
								result = (result.replace("$%d".printf(i),info.fetch(i)) ?? result);
							}
						}
						if(Main.gui.current_server() != null && Main.gui.current_server().current_view() != null) {
							result = (result.replace("$CURR_VIEW",Main.gui.current_server().current_view().name) ?? result);
						}
						return result;
					}
				} catch(RegexError e) {
					
				}
			}
			return null;
		}
	}
}
