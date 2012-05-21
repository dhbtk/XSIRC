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

		public abstract class ColorRep {
			protected string str = "";
			public void add(unichar c) {
				str += c.to_string();
			}
			public bool empty {
				get {
					return (str == "");
				}
			}
			public abstract string serialize();
			public abstract string? get_color();
			public abstract bool accept_end();
			public abstract bool accept(unichar c);
			public abstract ColorRep create();
		}

		public class DecColorRep : ColorRep {
			private int getValue() {
				return int.parse(str) % 16;
			}
			public override string serialize() {
				return (empty ? "-" : string.nfill(1, (char)('g' + getValue())));
			}
			public override string? get_color() {
				return (empty ? null : mirc_colors[getValue()]);
			}
			public override bool accept_end() {
				return true;
			}
			public override bool accept(unichar c) {
				return (str.length < 2 && c.isdigit());
			}
			public override ColorRep create() {
				return new DecColorRep();
			}
		}

		public class HexColorRep : ColorRep {
			private bool valid() {
				return (str.length == 6);
			}
			public override string serialize() {
				return (valid() ? str : "-");
			}
			public override string? get_color() {
				return (valid() ? "#" + str : null);
			}
			public override bool accept_end() {
				return valid();
			}
			public override bool accept(unichar c) {
				return (str.length < 6 && (c.isdigit() || ('A' <= c && c <= 'F')));
			}
			public override ColorRep create() {
				return new HexColorRep();
			}
		}

		public struct AttrChar {
			public unichar  contents;
			public bool     bold;
			public bool     italic;
			public bool     underlined;
			public ColorRep foreground;
			public ColorRep background;
		}
		public static HashMap<int,string> mirc_colors;
		private unichar[] data;
		
		public MIRCParser(string str) {
			unichar c;
			int i = 0;
			while(str.get_next_char(ref i,out c)) {
				data += c;
			}
		}
		
		public void insert(Gtk.TextView textview) {
			AttrChar[] parsed = parse();
			foreach(AttrChar c in parsed) {
				insert_with_tag_array(textview, c);
			}
		}
		
		private void insert_with_tag_array(Gtk.TextView textview, AttrChar c) {
			unichar what = c.contents;

			Gtk.TextIter start_iter;
			textview.buffer.get_end_iter(out start_iter);

			string added = (new StringBuilder().append_unichar(what)).str;

			if(c.foreground.empty && c.background.empty &&
			   !c.bold && !c.italic && !c.underlined) {
				textview.buffer.insert(ref start_iter,added,(int)added.length);
			} else {
				string tag_name = "%s%s%c".printf(c.foreground.serialize(),
				                                  c.background.serialize(),
				                                  (c.bold?1:0) + (c.underlined?2:0) + (c.italic?4:0) + 'a');
				Gtk.TextTag tag;
				if((tag = textview.buffer.tag_table.lookup(tag_name)) == null) {
					tag = textview.buffer.create_tag(tag_name,
						                             "foreground", c.foreground.get_color(),
						                             "background", c.background.get_color(),
						                             "weight", (c.bold ? Pango.Weight.BOLD : Pango.Weight.NORMAL),
						                             "underline", (c.underlined ? Pango.Underline.SINGLE : Pango.Underline.NONE),
						                             "style", (c.italic ? Pango.Style.ITALIC : Pango.Style.NORMAL),
													 null);
				}
				textview.buffer.insert_with_tags(start_iter,added,(int)added.length,tag,null);
			}
		}
		
		public AttrChar[] parse() {
			AttrChar[] parsed_string = {};
			bool bold           = false;
			bool italic         = false;
			bool underlined     = false;
			bool parsing_color  = false;
			bool got_foreground = false;
			ColorRep foreground = new DecColorRep();
			ColorRep background = new DecColorRep();
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
						foreground = new DecColorRep();
						background = new DecColorRep();
						parsing_color = false;
						break;

					case COLOR: case HEX_COLOR:
						if (parsing_color && !got_foreground && foreground.empty) {
							// Two consecutive color markers, clear colors.
							background = new DecColorRep();
						}
						parsing_color = true;
						if (c == HEX_COLOR) {
							foreground = new HexColorRep();
						} else {
							foreground = new DecColorRep();
						}
						got_foreground = false;
						break;

					default:
						if (parsing_color) {
							if (got_foreground) {
								if (background.accept(c)) {
									background.add(c);
								} else {
									parsing_color = false;
								}
							} else {
								if (c == ',' && foreground.accept_end()) {
									got_foreground = true;
									background = foreground.create();
								} else if (foreground.accept(c)) {
									foreground.add(c);
								} else {
									parsing_color = false;
									if (foreground.empty) {
										// A single ^C without digits after; clear colors.
										background = new DecColorRep();
									}
								}
							}
						}

						if (!parsing_color) {
							AttrChar parsed_char = {
								c, bold, italic, underlined, foreground, background
							};
							parsed_string += parsed_char;
						}
						break;
				}
			}
			return parsed_string;
		}
	}
}
