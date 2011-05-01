/*
 * prefdialog.vala
 *
 * Copyright (c) 2011 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class PrefDialog : Object {
		public Gtk.Dialog dialog;
		private Gtk.Builder builder;
		
		private Gtk.TreeView macro_tree;
		private Gtk.ListStore macro_model;
		private Gtk.TreeViewColumn regex_col;
		private Gtk.TreeViewColumn result_col;
		private enum MacroColumns {
			REGEX,
			RESULT,
			N_COLUMNS
		}
		
		public PrefDialog() {
			builder = new Gtk.Builder();
			try {
				builder.add_from_file(PREFIX+"/share/xsirc/preferences.ui");
			} catch(Error e) {
				Posix.exit(Posix.EXIT_FAILURE);
			}
			dialog = builder.get_object("dialog1") as Gtk.Dialog;
			
			// Saving some major typing
			
			// String things
			string[] strings = {"nickname","sec_nickname","ter_nickname","username",
			                    "realname","away_msg","quit_msg","log_file_name","log_folder",
			                    "timestamp_format","web_browser","completion_suffix"};
			foreach(string str in strings) {
				((Gtk.Entry)builder.get_object(str)).text = Main.config.string[str];
			}
			((Gtk.FontButton)builder.get_object("font")).font_name = Main.config.string["font"];
			switch(Main.config.string["tab_pos"]) {
				case "top":
					((Gtk.RadioButton)builder.get_object("tabs_top")).active = true;
					break;
				case "left":
					((Gtk.RadioButton)builder.get_object("tabs_left")).active = true;
					break;
				case "right":
					((Gtk.RadioButton)builder.get_object("tabs_right")).active = true;
					break;
				default: // Bottom, and whatever else
					((Gtk.RadioButton)builder.get_object("tabs_bottom")).active = true;
					break;
			}
			
			if(Main.config.string["userlist_pos"] == "left") {
				((Gtk.RadioButton)builder.get_object("userlist_left")).active = true;
			} else { // If it's set to "right", and also a catchall
				((Gtk.RadioButton)builder.get_object("userlist_right")).active = true;
			}
			
			// Booleans
			string[] bools = {"logging_enabled","show_user_list","show_topic_bar",
			                  "show_status_bar","show_timestamps","tab_completion_enabled"};
			foreach(string b in bools) {
				((Gtk.CheckButton)builder.get_object(b)).active = Main.config.bool[b];
			}
			
			// The lone integer value
			((Gtk.SpinButton)builder.get_object("away_mins")).value = Main.config.integer["away_mins"];
			
			// Macros
			
			macro_model = new Gtk.ListStore(MacroColumns.N_COLUMNS,typeof(string),typeof(string));
			macro_tree = builder.get_object("macro_tree") as Gtk.TreeView;
			macro_tree.model = macro_model;
			
			Gtk.CellRendererText regex_renderer = new Gtk.CellRendererText();
			regex_renderer.editable = true;
			regex_renderer.edited.connect(regex_edited);
			regex_col = new Gtk.TreeViewColumn.with_attributes(_("Regex"),regex_renderer,"text",MacroColumns.REGEX,null);
			macro_tree.append_column(regex_col);
			
			Gtk.CellRendererText result_renderer = new Gtk.CellRendererText();
			result_renderer.editable = true;
			result_renderer.edited.connect(result_edited);
			result_col = new Gtk.TreeViewColumn.with_attributes(_("Result"),result_renderer,"text",MacroColumns.RESULT,null);
			macro_tree.append_column(result_col);
			
			((Gtk.Button)builder.get_object("add_macro")).clicked.connect(add_macro);
			((Gtk.Button)builder.get_object("remove_macro")).clicked.connect(remove_macro);
			
			load_macros();
			
			// Plugins; TODO
			dialog.response.connect(() => {
				save_settings();
				save_macros();
				dialog.destroy();
				Main.gui.destroy_prefs_dialog();
			});
			dialog.show_all();
		}
		
		private void save_settings() {
			// This is essentially the same as the init function, only reversed
			string[] strings = {"nickname","sec_nickname","ter_nickname","username",
			                    "realname","away_msg","quit_msg","log_file_name","log_folder",
			                    "timestamp_format","web_browser","completion_suffix"};
			foreach(string str in strings) {
				Main.config.string[str] = ((Gtk.Entry)builder.get_object(str)).text;
			}
			Main.config.string["font"] = ((Gtk.FontButton)builder.get_object("font")).font_name;
			string[] tab_positions = {"top","left","right","bottom"};
			foreach(string tab_pos in tab_positions) {
				if(((Gtk.RadioButton)builder.get_object("tabs_"+tab_pos)).active) {
					Main.config.string["tab_pos"] = tab_pos;
					break;
				}
			}
			if(((Gtk.RadioButton)builder.get_object("userlist_left")).active) {
				Main.config.string["userlist_pos"] = "left";
			} else {
				Main.config.string["userlist_pos"] = "right";
			}
			// TODO: apply these settings
			
			// Booleans
			string[] bools = {"logging_enabled","show_user_list","show_topic_bar",
			                  "show_status_bar","show_timestamps","tab_completion_enabled"};
			foreach(string b in bools) {
				Main.config.bool[b] = ((Gtk.CheckButton)builder.get_object(b)).active;
			}
			
			// The lone integer value
			Main.config.integer["away_mins"] = (int)((Gtk.SpinButton)builder.get_object("away_mins")).value;
			
			Main.gui.apply_settings();
			
			Main.config_manager.save_settings();
		}

		private void add_macro() {
			Gtk.TreeIter iter;
			macro_model.append(out iter);
			Gtk.TreeSelection sel = macro_tree.get_selection();
			sel.unselect_all();
			sel.select_iter(iter);
			macro_tree.set_cursor(macro_model.get_path(iter),regex_col,true);
		}
		
		private void remove_macro() {
			Gtk.TreeIter iter;
			Gtk.TreeModel model;
			string regex;
			string result;
			Gtk.TreeSelection sel = macro_tree.get_selection();
			if(sel.get_selected(out model,out iter)) {
				model.get(iter,MacroColumns.REGEX,out regex,MacroColumns.RESULT,out result,-1);
				foreach(MacroManager.Macro m in Main.macro_manager.macros) {
					if(m.regex == regex) {
						Main.macro_manager.macros.remove(m);
						break;
					}
				}
				load_macros();
			}
		}
		
		private void regex_edited(string path,string new_text) {
			// Testing the regex for validity
			try {
				Regex test = new Regex(new_text);
				test.match("test",0,null);
				Gtk.TreeIter iter;
				string old_regex;
				if(macro_model.get_iter_from_string(out iter,path)) {
					macro_model.get(iter,MacroColumns.REGEX,out old_regex,-1);
					foreach(MacroManager.Macro macro in Main.macro_manager.macros) {
						if(macro.regex == old_regex) {
							macro.regex = new_text;
							break;
						}
					}
					macro_model.set(iter,MacroColumns.REGEX,new_text,-1);
				}
			} catch(Error e) {
				Gtk.MessageDialog d = new Gtk.MessageDialog(dialog,Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,Gtk.ButtonsType.CLOSE,_("The string entered isn't a valid regular expression."));
				d.response.connect(() => {
					d.destroy();
				});
				d.show_all();
			}
		}
		
		private void result_edited(string path,string new_text) {
			Gtk.TreeIter iter;
			string regex;
			if(macro_model.get_iter_from_string(out iter,path)) {
				macro_model.get(iter,MacroColumns.REGEX,out regex,-1);
				foreach(MacroManager.Macro macro in Main.macro_manager.macros) {
					if(macro.regex == regex) {
						macro.result = new_text;
						break;
					}
				}
				macro_model.set(iter,MacroColumns.RESULT,new_text,-1);
			}
		}
		
		private void load_macros() {
			macro_model.clear();
			Gtk.TreeIter iter;
			foreach(MacroManager.Macro macro in Main.macro_manager.macros) {
				macro_model.append(out iter);
				macro_model.set(iter,MacroColumns.REGEX,macro.regex,MacroColumns.RESULT,macro.result);
			}
		}
		
		private void save_macros() {
			Main.macro_manager.macros.clear();
			// Saving the data from the model
			macro_model.foreach((model,path,iter) => {
				string regex;
				string result;
				model.get(iter,MacroColumns.REGEX,out regex,MacroColumns.RESULT,out result,-1);
				MacroManager.Macro macro = new MacroManager.Macro(regex,result);
				Main.macro_manager.macros.add(macro);
				return false;
			});
		}
	
	}
}
