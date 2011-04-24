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
			
			// Macros; TODO
			// Plugins; TODO
			dialog.response.connect(() => {
				save_settings();
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
	}
}
