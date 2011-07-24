/*
 * mircparser.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class MIRCParser : Object {
		public static const unichar CTCP_CHAR = 1;
		public static const unichar BOLD      = 2;
		public static const unichar ITALIC    = 0x16;
		public static const unichar UNDERLINE = 0x1F;
		public static const unichar DEFAULT   = 15;
		public static const unichar COLOR     = 3;
		public static const unichar HEX_COLOR = 4;
		public struct AttrChar {
			public unichar contents;
			public bool    bold;
			public bool    italic;
			public bool    underlined;
			public string? foreground;
			public string? background;
			public string? hex_color;
		}
		private HashMap<int,string> mirc_colors = new HashMap<int,string>();
		private unichar[] data;
		
		public MIRCParser(string str) {
			// I kinda miss Ruby
			// Palette totally stolen from XChat
			mirc_colors[0]  = "#cccccccccccc"; // white
			mirc_colors[1]  = "black"; // black
			mirc_colors[2]  = "#35c235c2b332"; // dark blue
			mirc_colors[3]  = "#2a3d8ccc2a3d"; // green
			mirc_colors[4]  = "#c3c33b3b3b3b"; // red
			mirc_colors[5]  = "#c7c732323232"; // light red
			mirc_colors[6]  = "#800026667fff"; // purple
			mirc_colors[7]  = "#666636361f1f"; // orange
			mirc_colors[8]  = "#d999a6d34147"; // yellow
			mirc_colors[9]  = "#3d70cccc3d70"; // light green
			mirc_colors[10] = "#199a55555555"; // aqua
			mirc_colors[11] = "#2eef8ccc74df"; // light aqua
			mirc_colors[12] = "#451e451ee666"; // blue
			mirc_colors[13] = "#b0b03737b0b0"; // light purple
			mirc_colors[14] = "#4c4c4c4c4c4c"; // grey
			mirc_colors[15] = "#959595959595"; // light grey
			unichar c;
			int i = 0;
			while(str.get_next_char(ref i,out c)) {
				data += c;
			}
		}
		
		public void insert(Gtk.TextView textview) {
			AttrChar[] parsed = parse();
			foreach(AttrChar c in parsed) {
				//stdout.printf("Tags: %s\n".printf(string.joinv(", ",tags)));
				insert_with_tag_array(textview,c.contents,c);
			}
		}
		
		private void insert_with_tag_array(Gtk.TextView textview,unichar what,AttrChar c) {
			Gtk.TextIter start_iter;
			textview.buffer.get_end_iter(out start_iter);
			//stdout.printf("start_iter offset: %d\n",start_iter.get_offset());
			string added = (new StringBuilder().append_unichar(what)).str;
			if(c.foreground == null && c.background == null && !c.bold && !c.italic &&
			   !c.underlined && c.hex_color == null) {
				textview.buffer.insert(start_iter,added,(int)added.length);
			} else {
				string tag_name = "%s%s%s%s%s%s".printf(c.foreground,
				                                       c.background,
				                                       c.bold ? "bold" : "normal",
				                                       c.underlined ? "underlined" : "normal",
				                                       c.italic ? "italic" : "normal",
				                                       c.hex_color);
				Gtk.TextTag tag;
				if((tag = textview.buffer.tag_table.lookup(tag_name)) == null) {
					tag = textview.buffer.create_tag(tag_name,
						                             "foreground",c.hex_color != null ? c.hex_color : c.foreground,
						                             "background",c.background,
						                             "weight",c.bold ? Pango.Weight.BOLD : Pango.Weight.NORMAL,
						                             "underline",c.underlined ? Pango.Underline.SINGLE : Pango.Underline.NONE,
						                             "style",c.italic ? Pango.Style.ITALIC : Pango.Style.NORMAL,null);
				}
				textview.buffer.insert_with_tags(start_iter,added,(int)added.length,tag,null);
			}
			//stdout.printf("end_iter offset: %d\n",end_iter.get_offset());
		}
		
		public AttrChar[] parse() {
			AttrChar[] parsed_string = {};
			bool bold              = false;
			bool italic            = false;
			bool underlined        = false;
			string? foreground     = null;
			string? background     = null;
			string? hex_color      = null;
			bool parsing_color     = false;
			bool got_foreground    = false;
			bool parsing_hex_color = false;
			foreach(unichar c in data) {
				switch(c) {
					case BOLD:
						bold = !bold;
						break;
					case ITALIC:
						italic = !italic;
						break;
					case UNDERLINE:
						underlined = !underlined;
						break;
					case DEFAULT:
						bold = false;
						italic = false;
						underlined = false;
						foreground = null;
						background = null;
						hex_color = null;
						parsing_color = false;
						break;
					case COLOR:
						parsing_color = !parsing_color;
						if(foreground != null || background != null) {
							foreground = null;
							background = null;
						}
						got_foreground = false;
						break;
					case HEX_COLOR:
						parsing_hex_color = !parsing_hex_color;
						if(hex_color != null) {
							hex_color = null;
						}
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
									//got_foreground = true;
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
						} else if(parsing_hex_color && c == '#' && hex_color == null) {
							hex_color = "#";
						} else if(parsing_hex_color && (c.isdigit() || (c >= 'A' && c <= 'F')) && hex_color != null && hex_color.length < 7) {
							hex_color = hex_color + c.to_string();
						} else {
							if(parsing_color && !(c.isdigit() || c == ',')) {
								parsing_color = false;
								got_foreground = false;
							}
							if(parsing_hex_color && (!(c >= 'A' && c <= 'F'))) {
								parsing_hex_color = false;
								if(hex_color != null && hex_color.length < 7) {
									hex_color = null;
								}
							}
							
							AttrChar parsed_char = {c,bold,italic,underlined,(foreground != null ? mirc_colors[int.parse(foreground)%16] : null),(background != null ? mirc_colors[int.parse(background)%16] : null),hex_color};
							parsed_string += parsed_char;
						}
						break;
				}
			}
			return parsed_string;
		}
	}
}
