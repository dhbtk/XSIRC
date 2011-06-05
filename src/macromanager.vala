/*
 * macromanager.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class MacroManager : Object {
		private struct DefaultMacro {
			public string regex;
			public string result;
		}
		public class Macro {
			public string regex;
			public string result;
			public Macro(string a,string b) {
				regex = a;
				result = b;
			}
		}
		public LinkedList<Macro> macros = new LinkedList<Macro>();
		private KeyFile macros_file;
		private const DefaultMacro[] default_macros = {
			{"^me (.+)$","PRIVMSG $CURR_VIEW :ACTION $1"},
			{"^ctcp ([^ ]+) PING","PRIVMSG $1 :PING $TIME"},
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
				Gtk.MessageDialog d = new Gtk.MessageDialog(Main.gui.main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,Gtk.ButtonsType.CLOSE,"%s",_("Could not parse the macros file. Loading default macros."));
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
					k = macros_file.get_string("macros","regex%d".printf(i));
					v = macros_file.get_string("macros","result%d".printf(i));
					Macro macro = new Macro("regex","result");
					try {
						// Testing if it compiles
						Regex test =  new Regex(k);
						test.match("test",0,null);
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
			foreach(DefaultMacro macro in default_macros) {
				macros.add(new Macro(macro.regex,macro.result));
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
								result = result.replace("$%d".printf(i),info.fetch(i)) ?? result;
							}
						}
						if(Main.gui.current_server() != null && Main.gui.current_server().current_view() != null) {
							result = result.replace("$CURR_VIEW",Main.gui.current_server().current_view().name) ?? result;
						}
						Posix.timeval tv = Posix.timeval();
						tv.get_time_of_day();
						result = result.replace("$TIME",((long)tv.tv_sec).to_string()+"."+tv.tv_usec.to_string()) ?? result;
						return result;
					}
				} catch(RegexError e) {
					
				}
			}
			return null;
		}
		
		public void save_macros() {
			macros_file = new KeyFile();
			int i = 0;
			foreach(Macro macro in macros) {
				macros_file.set_string("macros","regex%d".printf(i),macro.regex);
				macros_file.set_string("macros","result%d".printf(i),macro.result);
				i++;
			}
			try {
				FileUtils.set_contents(Environment.get_user_config_dir()+"/xsirc/macros.conf",macros_file.to_data());
			} catch(Error e) {
				stderr.printf("Could not save macros file.\n");
			}
		}
	}
}
