/*
 * entrygoodies.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class TabCompleter : Object {
		private bool completing = false;
		private ArrayList<string> matches = new ArrayList<string>();
		private int match_index = 0;
		
		public void reset() {
			completing = false;
			matches.clear();
			match_index = 0;
		}
		
		public void complete(Server server,GUI.View view,Gtk.Entry entry) {
			if(completing) {
				if((matches.size - 1) >= match_index) {
					string curr_text = entry.text;
					string[] curr_text_words = curr_text.split(" ");
					string last_word = curr_text_words[0] != null ? curr_text_words[curr_text_words.length-1] : "";
					int last_word_offset = (int)(curr_text.length-last_word.length);
					entry.buffer.delete_text(last_word_offset,-1);
					entry.buffer.insert_text(last_word_offset,matches[match_index],-1);
					entry.move_cursor(Gtk.MovementStep.VISUAL_POSITIONS,(int)matches[match_index].length,false);
					match_index++;
				}
			} else {
				matches.clear();
				match_index = 0;
				string curr_text = entry.text;
				string[] curr_text_words = curr_text.split(" ");
				string last_word = curr_text_words[0] != null ? curr_text_words[curr_text_words.length-1] : "";
				if(view.name.has_prefix("#")) {
					foreach(string user in server.find_channel(view.name).raw_users) {
						string tested = user;
						if(/^(&|@|%|\+)/.match(user)) {
							tested = user.substring(1);
						}
						if(last_word.length == 0 || tested.down().has_prefix(last_word.down())) {
							matches.add(tested);
						}
					}
				} else {
					matches.add(view.name);
				}
				completing = true;
				complete(server,view,entry);
			}
		}
	}
	
	public class CommandHistory : Object {
		
	}
}
