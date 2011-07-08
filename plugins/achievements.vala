/*
 * achievements.vala
 *
 * Copyright (c) 2011 Simon Lindholm
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;

namespace XSIRC {
	public class AchievementsPlugin : Plugin {

		public enum AchievementID {
			MAGIC,
			E
		}
		private struct AchievementData {
			public AchievementID id;
			public string internal_name;
			public string short_name;
			public string description;
		}

		private const AchievementData[] achievements = {
			{AchievementID.MAGIC, "MAGIC", N_("Frobnicator"),
			    N_("Change the magic switch back and forth repeatedly.")},
			{AchievementID.E, "E", N_("Anti-ɐʍɥɔs"),
			    N_("Accomplish communication of many non-fifth symbols in a row.")}
		};

		private const double MAGIC_LIMIT = 30;

		private double save_progress = 0;

		// MAGIC
		private double magic_last = 0;
		private double magic_counter;

		// E
		private unichar e_char;
		private HashSet<unichar> counted_alphabet = new HashSet<unichar>();

		private Gtk.HBox magic_box;
		private Gtk.VBox achievement_box;
		private Gdk.Pixbuf achievement_bg = null;

		private time_t[] awarded;
		public AchievementsPlugin() {
			Object();
		}

		construct {
			name = _("Achievements");
			description = _("IRC Achievements.");
			author = "operator[]";
			version = "0.1";
			priority = 0;
			prefs_widget = null;
			load();
			set_up_prefs();
			reset();
		}

		private void load() {
			awarded = new time_t[achievements.length];
			for (int i = 0; i < achievements.length; ++i) {
				awarded[i] = (time_t)0;
				assert(achievements[i].id == (AchievementID)i);
			}

			enabled = false;
			try {
				KeyFile conf = new KeyFile();
				conf.load_from_file(Environment.get_user_config_dir()+"/xsirc/achievements.conf", 0);

				if (conf.has_key("achievements", "active") &&
					conf.get_boolean("achievements", "active") == true)
				{
					enabled = true;
				}

				foreach (AchievementData a in achievements) {
					if (conf.has_key("achievements", a.internal_name)) {
						awarded[a.id] = (time_t)conf.get_integer("achievements", a.internal_name);
					}
				}
			} catch(Error e) {
				// No achievements saved yet.
			}

			// 'No E' achievement - localize 'e' into some other common letter
			// for other languages ('a' might make sense in Spanish for example,
			// to mimic 'A Void'), and also localize the alphabet in which the
			// letter is supposed to be avoided - gaining the achievement
			// automatically when writing in languages based on other alphabets
			// or typing lots of smileys would be bad. (Letter frequences tend
			// not to differ too much between languages using the same alphabets,
			// so that's less of a problem.)
			string counted_alphabet_str = _("COUNTED_ALPHABET=abcdefghijklmnopqrstuvwxyz").substring(17);
			unichar c;
			int i = 0;
			while (counted_alphabet_str.get_next_char(ref i, out c)) {
				counted_alphabet.add(c);
			}
			e_char = _("E_CHAR=e").get(7);
		}

		private void save() {
			try {
				KeyFile conf = new KeyFile();

				conf.set_boolean("achievements", "active", enabled);

				foreach (AchievementData a in achievements) {
					int val = (int)awarded[a.id];
					if (val != 0) {
						conf.set_integer("achievements", a.internal_name, val);
					}
				}

				FileUtils.set_contents(Environment.get_user_config_dir()+"/xsirc/achievements.conf",conf.to_data());
			} catch(Error e) {

			}
			save_progress = 0;
		}

		private void incremental_save(double progress) {
			save_progress += progress;
			if (save_progress > 1) {
				save();
			}
		}

		private bool has_achievement(AchievementID id) {
			return ((int)awarded[id] != 0);
		}

		private void reset() {
			magic_counter = 0;
			magic_box.set_sensitive(enabled);
		}


		private void test_e(string message) {
			if (has_achievement(AchievementID.E)) {
				return;
			}

			string[] words = message.down().split(" ");
			int counted_words = 0;
			foreach (string word in words) {
				if (word.index_of_char(e_char) != -1) {
					return;
				}

				// Only count words with a sufficient density of letters.
				unichar c;
				int i = 0, alpha = 0, len = 0;
				while (word.get_next_char(ref i, out c)) {
					if (counted_alphabet.contains(c)) {
						++alpha;
					}
					++len;
				}
				if (3*alpha >= 2*len) {
					++counted_words;
				}
			}

			if (counted_words >= 7) {
				award_achievement(AchievementID.E);
			}
		}


		private void build_achievement_box() {
			var children = achievement_box.get_children();
			foreach (Gtk.Widget ch in children) {
				achievement_box.remove(ch);
			}

			foreach(AchievementData a in achievements) {
				if (!has_achievement(a.id)) {
					continue;
				}

				Gtk.Fixed ac = new Gtk.Fixed();
				Gtk.Image bg = new Gtk.Image.from_pixbuf(achievement_bg);
				bg.set_size_request(330, 60);
				ac.put(bg, 0, 6);
				Gtk.Label text = new Gtk.Label(_("<b>%s</b>: %s.").printf(
								Markup.escape_text(_(a.short_name)),
								Markup.escape_text(_(a.description))
							));
				text.use_markup = true;
				text.set_size_request(290, -1);
				text.wrap = true;
				int lines = text.get_layout().get_line_count();
				int y = (lines == 1 ? 27 : lines == 2 ? 19 : 10);
				ac.put(text, 20, y);
				achievement_box.pack_start(ac, false, false, 0);
			}
			achievement_box.show_all();
		}

		private void award_achievement(AchievementID id) {
			if (!has_achievement(id)) {
				AchievementData a = achievements[id];
#if !WINDOWS
				Notify.Notification notification = new Notify.Notification(
					_("Achievement unlocked - %s").printf(_(a.short_name)),
					Markup.escape_text("%s.".printf(_(a.description))),
					get_file_path("pixmap", "xsirc.png")
				);
				notification.set_timeout(4000);
				notification.set_urgency(Notify.Urgency.NORMAL);
				try {
					notification.show();
				} catch(Error e) {

				}
#endif
				awarded[id] = time_t();
				build_achievement_box();
				save();
			}
		}

		private void set_up_prefs() {
			Gtk.VBox vbox = new Gtk.VBox(false, 0);

			Gtk.HBox first_row_box = new Gtk.HBox(false, 0);

			Gtk.CheckButton chk_on = new Gtk.CheckButton.with_label(_("Enable achievements"));
			chk_on.xalign = 0;
			chk_on.active = enabled;
			chk_on.toggled.connect(() => {
				enabled = chk_on.active;
				reset();
				save();
			});
			first_row_box.pack_start(chk_on, true, false, 0);

			magic_box = new Gtk.HBox(false, 0);
			Gtk.Label magic_label = new Gtk.Label(_("Magic:"));
			magic_box.pack_start(magic_label, false, false, 5);
			Gtk.HScale magic_switch = new Gtk.HScale.with_range(1, 5, 1);
			magic_switch.value_pos = Gtk.PositionType.BOTTOM;
			magic_switch.set_increments(1, 1);
			magic_switch.set_digits(0);
			magic_switch.set_size_request(200, -1);
			magic_switch.value_pos = Gtk.PositionType.BOTTOM;
			magic_last = magic_switch.adjustment.value;
			magic_switch.adjustment.value_changed.connect(() => {
				double nval = magic_switch.adjustment.value;
				if (enabled) {
					magic_counter += Math.fabs(nval - magic_last);
					if (magic_counter > MAGIC_LIMIT) {
						award_achievement(AchievementID.MAGIC);
					}
				}
				magic_last = nval;
			});
			magic_box.pack_start(magic_switch, false, false, 0);
			first_row_box.pack_start(magic_box, false, false, 3);

			vbox.pack_start(first_row_box, false, false, 0);

			Gtk.ScrolledWindow achievement_scroller = new Gtk.ScrolledWindow(null, null);
			achievement_box = new Gtk.VBox(false, 5);
			achievement_scroller.add_with_viewport(achievement_box);
			try {
				achievement_bg = new Gdk.Pixbuf.from_file(get_file_path("share", "achievement_bg.png"));
			}
			catch (Error e) {

			}
			build_achievement_box();
			vbox.pack_start(achievement_scroller, true, true, 0);

			prefs_widget = vbox;
		}

		public override bool on_startup() {
#if !WINDOWS
			Notify.init("XSIRC");
#endif
			return true;
		}

		public override bool on_sent_message(Server server, string nick, string target, string message, string raw_msg) {
			if (message.has_prefix("\x01")) { // CTCP / action, ignore
				string msg = message.slice(1, -1);
				stdout.printf("CTCP: %s\n", msg);
				return true;
			}
			test_e(message);
			return true;
		}
	}
}

#if !WINDOWS
//[ModuleInit]
Type register_plugin(TypeModule module) {
	return typeof(XSIRC.AchievementsPlugin);
}
#endif
