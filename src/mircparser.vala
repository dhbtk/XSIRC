using Gee;
namespace XSIRC {
	public class MIRCParser : Object {
		private struct AttrChar {
			public char    contents;
			public bool    bold;
			public bool    italic;
			public bool    underlined;
			public string? foreground;
			public string? background;
		}
		private HashMap<int,string> mirc_colors = new HashMap<int,string>();
		private char[] data;
		
		public MIRCParser(string str) {
			// I kinda miss Ruby
			mirc_colors[0]  = "white";
			mirc_colors[1]  = "black";
			mirc_colors[2]  = "dark blue";
			mirc_colors[3]  = "green";
			mirc_colors[4]  = "red";
			mirc_colors[5]  = "dark red";
			mirc_colors[6]  = "purple";
			mirc_colors[7]  = "brown";
			mirc_colors[8]  = "yellow";
			mirc_colors[9]  = "light green";
			mirc_colors[10] = "cyan";
			mirc_colors[11] = "light cyan";
			mirc_colors[12] = "blue";
			mirc_colors[13] = "pink";
			mirc_colors[14] = "grey";
			mirc_colors[15] = "dark grey";
			data = (char[])str.data;
		}
		
		public void insert(Gtk.TextView textview) {
			
		}
		
		private AttrChar[] parse() {
			AttrChar[] parsed_string = {};
			bool bold = false;
			bool italic = false;
			bool underlined = false;
			string? foreground = null;
			string? background = null;
			bool parsing_color = false;
			bool got_foreground = false;
			foreach(char c in data) {
				switch(c) {
					case 2: // Bold
						bold = !bold;
						break;
					case 22: // Italics / reversed
						italic = !italic;
						break;
					case 31: // Underline
						underlined = !underlined;
						break;
					case 15: // Original
						bold = false;
						italic = false;
						underlined = false;
						foreground = null;
						background = null;
						parsing_color = false;
						break;
					case 3: // Color
						parsing_color = !parsing_color;
						got_foreground = false;
						break;
					default:
						if(parsing_color && (c.isdigit() || c == ',')) {
							if(c.isdigit()) {
								if(!got_foreground) {
									if(foreground == null) {
										foreground = c.to_string();
									} else {
										foreground = foreground + c.to_string();
									}
									got_foreground = true;
								} else {
									if(background == null) {
										background = c.to_string();
									} else {
										background = background + c.to_string();
									}
								}
							} else if(c == ',') {
								got_foreground = true;
							}
						} else {
							if(parsing_color && !(c.isdigit() || c == ',')) {
								parsing_color = false;
								got_foreground = false;
							}
							AttrChar parsed_char = {c,bold,italic,underlined,(foreground != null ? mirc_colors[foreground.to_int()%16] : null),(background != null ? "back "+mirc_colors[background.to_int()%16] : null)};
							parsed_string += parsed_char;
						}
						break;
				}
			}
			return parsed_string;
		}
	}
}
