using Gee;
namespace XSIRC {
	public class TabCompleter : Object {
		private bool completing = false;
		private Gtk.TextIter match_iter;
		private ArrayList<string> matches = new ArrayList<string>();
		private int match_index = 0;
		
		public void reset() {
			completing = false;
			matches.clear();
			match_index = 0;
		}
		
		public void complete(Server server,GUI.View view,Gtk.TextBuffer buffer) {
			if(completing) {
				if((matches.size - 1) >= match_index) {
					Gtk.TextIter start;
					buffer.get_iter_at_offset(out start,0);
					Gtk.TextIter end;
					buffer.get_end_iter(out end);
					string curr_text = buffer.get_text(start,end,false);
					string[] curr_text_words = curr_text.split(" ");
					string last_word = curr_text_words[0] != null ? curr_text_words[curr_text_words.length-1] : "";
					int last_word_offset = curr_text_words[0] != null ? (int)(buffer.cursor_position-last_word.length) : 0;
					buffer.get_iter_at_offset(out match_iter,last_word_offset);
					buffer.delete(match_iter,end);
					buffer.insert(match_iter,matches[match_index],(int)matches[match_index].length);
					match_index++;
				}
			} else {
				matches.clear();
				match_index = 0;
				Gtk.TextIter start;
				Gtk.TextIter end;
				buffer.get_iter_at_offset(out start,0);
				buffer.get_end_iter(out end);
				string curr_text = buffer.get_text(start,end,false);
				string[] curr_text_words = curr_text.split(" ");
				string last_word = curr_text_words[0] != null ? curr_text_words[curr_text_words.length-1] : "";
				int last_word_offset = curr_text_words[0] != null ? (int)(buffer.cursor_position-last_word.length) : 0;
				buffer.get_iter_at_offset(out match_iter,last_word_offset);
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
				complete(server,view,buffer);
			}
		}
	}
}
