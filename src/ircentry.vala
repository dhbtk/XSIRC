/*
 * ircentry.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;

namespace XSIRC {
	public class IRCEntry : Gtk.Entry {
		private bool completing = false;
		private ArrayList<string> matches = new ArrayList<string>();
		private int match_index = 0;
		private LinkedList<string> command_history = new LinkedList<string>();
		private int command_history_index = 0;
		
		public IRCEntry() {
			command_history.add("");
			// Setting up signals, mostly
			activate.connect(() => {
				command_history.insert(0,this.text);
				command_history_index = 0;
				foreach(string text in this.text.split("\n")) {
					Main.gui.parse_text(text);
				}
				this.text = "";
			});
			
			key_press_event.connect((key) => {
				command_history[0] = this.text;
				if(key.keyval == Gdk.keyval_from_name("Up")) {
					if(command_history.size > (command_history_index + 1)) {
						command_history_index++;
						this.text = command_history[command_history_index];
					}
					return true;
				} else if(key.keyval == Gdk.keyval_from_name("Down")) {
					if((command_history_index - 1) >= 0) {
						command_history_index--;
						this.text = command_history[command_history_index];
					}
					return true;
				} else if(Main.config.bool["tab_completion_enabled"] && key.keyval == Gdk.keyval_from_name("Tab")) {
					if(Main.gui.current_server() != null && Main.gui.current_server().current_view() != null) {
						complete(Main.gui.current_server(),Main.gui.current_server().current_view());
					}
					return true;
				} else if(Main.config.bool["tab_completion_enabled"] && key.keyval == Gdk.keyval_from_name("ISO_Left_Tab")) {
					if(Main.gui.current_server() != null && Main.gui.current_server().current_view() != null) {
						complete(Main.gui.current_server(),Main.gui.current_server().current_view(),true);
					}
					return true;
				} else {
					if(!/^Shift|Control|Meta|Alt|Super|Hyper|Caps/.match(Gdk.keyval_name(key.keyval))) {
						completion_reset();
					}
					return false;
				}
			});
		}
		
		private void completion_reset() {
			completing = false;
			matches.clear();
			match_index = 0;
		}
		
		private void complete(Server server,GUI.View view,bool reverse = false) {
			if(completing) {
				if((matches.size - 1) < match_index) {
					// We've reached the end of the list, wrapping around
					match_index = 0;
				} else if(match_index < 0) {
					// Wrapping around again
					match_index = matches.size - 1;
				}
				if((matches.size - 1) >= match_index) { // Prevents segfaults and the like
					string curr_text = this.text;
					string[] curr_text_words = curr_text.split(" ");
					string last_word = curr_text_words[0] != null ? curr_text_words[curr_text_words.length-1] : "";
					int last_word_offset;
					if(match_index <= 0) {
						last_word_offset = (int)(curr_text.length-last_word.length);
					} else {
						last_word_offset = (int)(curr_text.length-matches[match_index-1].length);
					}
					this.buffer.delete_text(last_word_offset,-1);
					this.buffer.insert_text(last_word_offset,(uint8[])matches[match_index]);
					this.move_cursor(Gtk.MovementStep.VISUAL_POSITIONS,(int)matches[match_index].length,false);
					match_index++;
				}
			} else {
				matches.clear();
				match_index = 0;
				string curr_text = this.text;
				string[] curr_text_words = curr_text.split(" ");
				string last_word = curr_text_words[0] != null ? curr_text_words[curr_text_words.length-1] : "";
				bool suffixable = curr_text.length-last_word.length == 0;
				if(view.name.has_prefix("#")) {
					foreach(string user in server.find_channel(view.name).raw_users) {
						string tested = user;
						if(irc_user_is_privileged(user)) {
							tested = user.substring(1);
						}
						if(last_word.length == 0 || tested.down().has_prefix(last_word.down())) {
							if(suffixable) {
								matches.add(tested+Main.config.string["completion_suffix"]);
							} else {
								matches.add(tested);
							}
						}
					}
				} else {
					matches.add(view.name);
				}
				completing = true;
				matches.sort((CompareDataFunc)strcasecmp);
				complete(server,view,reverse);
			}
		}
		
		public void insert_bold() {
			this.buffer.insert_text(this.cursor_position,(uint8[])"");
			this.move_cursor(Gtk.MovementStep.VISUAL_POSITIONS,1,false);
		}
		
		public void insert_italic() {
			this.buffer.insert_text(this.cursor_position,(uint8[])"");
			this.move_cursor(Gtk.MovementStep.VISUAL_POSITIONS,1,false);
		}
		
		public void insert_underlined() {
			this.buffer.insert_text(this.cursor_position,(uint8[])"");
			this.move_cursor(Gtk.MovementStep.VISUAL_POSITIONS,1,false);
		}
		
		public void insert_color() {
			this.buffer.insert_text(this.cursor_position,(uint8[])"");
			this.move_cursor(Gtk.MovementStep.VISUAL_POSITIONS,1,false);
		}
		
		public void insert_remove() {
			this.buffer.insert_text(this.cursor_position,(uint8[])"");
			this.move_cursor(Gtk.MovementStep.VISUAL_POSITIONS,1,false);
		}
	}
}
