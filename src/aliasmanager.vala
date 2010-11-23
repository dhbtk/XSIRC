using Gee;
namespace XSIRC {
	public class AliasManager : Object {
		public struct Alias {
			public string regex;
			public string result;
		}
		private LinkedList<Alias?> aliases = new LinkedList<Alias?>();
		private KeyFile aliases_file;
		private const Alias[] default_aliases = {
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
		
		public AliasManager() {
			load_aliases();
		}
		
		private void load_aliases() {
			aliases_file = new KeyFile();
			try {
				aliases_file.load_from_file(Environment.get_user_config_dir()+"/xsirc/aliases.conf",0);
			} catch(KeyFileError e) {
				Gtk.MessageDialog d = new Gtk.MessageDialog(Main.gui.main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,Gtk.ButtonsType.CLOSE,"Could not parse the aliases file. Loading default aliases.");
				d.response.connect((id) => {
					d.destroy();
				});
				d.run();
				load_default_aliases();
				return;
			} catch(FileError e) {
				stderr.printf("Could not open aliases.conf: %s\n",e.message);
				load_default_aliases();
				return;
			}
			string k;
			string v;
			try {
				for(int i = 0; aliases_file.has_key("aliases","regex%d".printf(i)) && aliases_file.has_key("aliases","result%d".printf(i)); i++) {
					k = "regex%d".printf(i);
					v = "result%d".printf(i);
					Alias alias = Alias();
					try {
						// Testing if it compiles
						Regex test =  new Regex(k);
						alias.regex = k;
					} catch(RegexError e) {
						continue;
					}
					alias.result = v;
					aliases.add(alias);
				}
			} catch(KeyFileError e) {
				
			}
		}
		
		private void load_default_aliases() {
			foreach(Alias alias in default_aliases) {
				aliases.add(alias);
			}
		}
		
		public string? parse_string(string testee) {
			return null; // TODO
		}
	}
}
