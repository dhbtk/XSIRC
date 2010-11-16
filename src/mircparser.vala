/*
 * gui.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class MIRCParser : Object {
		public static const string CTCP_CHAR = "";
		public static const string BOLD      = "";
		public static const string ITALIC    = "";
		public static const string UNDERLINE = "";
		public static const string COLOR     = "";
		public class AttrChar {
			public char    contents;
			public bool    bold;
			public bool    italic;
			public bool    underlined;
			public string? foreground;
			public string? background;
		public AttrChar(char c, bool b, bool i, bool u, string? fg, string? bg) {
			contents = c;
			bold = b;
			italic = i;
			underlined = u;
			foreground = fg;
			background = bg;
		}
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
			string s = convert(str,(ssize_t)str.size(),"ISO-8859-1","UTF-8");
			data = (char[])s.data;
		}
		
		public void insert(Gtk.TextView textview) {
			AttrChar[] parsed = parse();
			foreach(AttrChar c in parsed) {
				string[] tags = {};
				if(c.bold) {
					tags += "bold";
				}
				if(c.italic) {
					tags += "italic";
				}
				if(c.underlined) {
					tags += "underlined";
				}
				if(c.background != null) {
					tags += c.background;
				}
				if(c.foreground != null) {
					tags += c.foreground;
				}
				//stdout.printf("Tags: %s\n".printf(string.joinv(", ",tags)));
				insert_with_tag_array(textview,c.contents,tags);
			}
		}
		
		private void insert_with_tag_array(Gtk.TextView textview,char what,string[] tags) {
			Gtk.TextIter start_iter;
			Gtk.TextIter end_iter;
			textview.buffer.get_end_iter(out start_iter);
			//stdout.printf("start_iter offset: %d\n",start_iter.get_offset());
			string added = convert(what.to_string(),(ssize_t)1,"UTF-8","ISO-8859-1");
			textview.buffer.insert(start_iter,added,(int)added.size());
			end_iter = start_iter;
			end_iter.forward_char();
			//stdout.printf("end_iter offset: %d\n",end_iter.get_offset());
			foreach(string tag in tags) {
				assert(textview.buffer.tag_table.lookup(tag) != null);
				//stdout.printf("Applying tag %s\n",tag);
				textview.buffer.apply_tag_by_name(tag,start_iter,end_iter);
			}
		}
		
		public AttrChar[] parse() {
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
							AttrChar parsed_char = new AttrChar(c,bold,italic,underlined,(foreground != null ? mirc_colors[foreground.to_int()%16] : null),(background != null ? "back "+mirc_colors[background.to_int()%16] : null));
							parsed_string += parsed_char;
						}
						break;
				}
			}
			return parsed_string;
		}
	}
}
