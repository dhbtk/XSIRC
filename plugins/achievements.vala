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
			FROBNICATOR,
		}
		private struct AchievementData {
			public string internal_name;
			public string short_name;
			public string description;
		}

		private const AchievementData[] achievements = {
			{"MAGIC", N_("Frobnicator"), N_("Change the magic switch back and forth repeatedly")}
		};

		private const double MAGIC_LIMIT = 30;

		private bool activated = false;
		private double magic_last = 0;
		private double magic_counter;
		private double save_progress = 0;

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

		void load() {
			awarded = new time_t[achievements.length];
			for (int i = 0; i < achievements.length; ++i) {
				awarded[i] = (time_t)0;
			}

			try {
				KeyFile conf = new KeyFile();
				conf.load_from_file(Environment.get_user_config_dir()+"/xsirc/achievements.conf", 0);

				if (conf.has_key("achievements", "active") &&
					conf.get_boolean("achievements", "active") == true)
				{
					activated = true;
				}

				int i = 0;
				foreach (AchievementData a in achievements) {
					if (conf.has_key("achievements", a.internal_name)) {
						awarded[i] = (time_t)conf.get_integer("achievements", a.internal_name);
					}
					++i;
				}
			} catch(Error e) {
				// No achievements saved yet.
			}
		}

		void save() {
			try {
				KeyFile conf = new KeyFile();

				conf.set_boolean("achievements", "active", activated);

				int i = 0;
				foreach (AchievementData a in achievements) {
					int val = (int)awarded[i];
					if (val != 0) {
						conf.set_integer("achievements", a.internal_name, val);
					}
					++i;
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
			magic_box.set_sensitive(activated);
		}

		private void fill_achievement_box() {
			var children = achievement_box.get_children();
			foreach (Gtk.Widget ch in children) {
				achievement_box.remove(ch);
			}

			for (int i = 0; i < achievements.length; ++i) {
				if (!has_achievement((AchievementID)i)) {
					continue;
				}
				AchievementData a = achievements[i];

				Gtk.Fixed ac = new Gtk.Fixed();
				Gtk.Image bg = new Gtk.Image.from_pixbuf(achievement_bg);
				bg.set_size_request(330, 60);
				ac.put(bg, 0, 0);
				Gtk.Label text = new Gtk.Label(_(a.short_name));
				ac.put(text, 20, 16);
				achievement_box.pack_start(ac, false, false, 6);
			}
		}

		void award_achievement(AchievementID id) {
			if (!has_achievement(id)) {
				AchievementData a = achievements[id];
#if !WINDOWS
				Notify.Notification notification = new Notify.Notification(
					_("Achievement unlocked - %s").printf(_(a.short_name)),
					Markup.escape_text("%s.".printf(_(a.description))),
					PREFIX+"/share/pixmaps/xsirc.png"
				);
				notification.set_timeout(4000);
				notification.set_urgency(Notify.Urgency.NORMAL);
				try {
					notification.show();
				} catch(Error e) {

				}
#endif
				awarded[id] = time_t();
				fill_achievement_box();
				save();
			}
		}

		private void set_up_prefs() {
			Gtk.VBox vbox = new Gtk.VBox(false, 0);

			Gtk.CheckButton chk_on = new Gtk.CheckButton.with_label(_("Activate achievements"));
			chk_on.active = activated;
			chk_on.toggled.connect(() => {
				activated = chk_on.active;
				reset();
				save();
			});
			vbox.pack_start(chk_on, false, false, 10);

			magic_box = new Gtk.HBox(false, 0);
			Gtk.Label magic_label = new Gtk.Label(_("Magic:"));
			magic_box.pack_start(magic_label, false, false, 5);
			Gtk.HScale magic_switch = new Gtk.HScale.with_range(1, 5, 1);
			magic_switch.add_mark(1, Gtk.PositionType.BOTTOM, null);
			magic_switch.add_mark(2, Gtk.PositionType.BOTTOM, null);
			magic_switch.add_mark(3, Gtk.PositionType.BOTTOM, null);
			magic_switch.add_mark(4, Gtk.PositionType.BOTTOM, null);
			magic_switch.add_mark(5, Gtk.PositionType.BOTTOM, null);
			magic_switch.value_pos = Gtk.PositionType.BOTTOM;
			magic_switch.set_increments(1, 1);
			magic_switch.set_digits(0);
			magic_switch.set_size_request(200, 1);
			magic_switch.value_pos = Gtk.PositionType.BOTTOM;
			magic_last = magic_switch.adjustment.value;
			magic_switch.adjustment.value_changed.connect(() => {
				double nval = magic_switch.adjustment.value;
				if (activated) {
					magic_counter += Math.fabs(nval - magic_last);
					if (magic_counter > MAGIC_LIMIT) {
						award_achievement(AchievementID.FROBNICATOR);
					}
				}
				// Hack: Work around a GTK+ bug where the scale's text
				// wouldn't get updated.
				vbox.queue_draw_area(130, 50, 350, 150);
				magic_last = nval;
			});
			magic_box.pack_start(magic_switch, false, false, 0);
			vbox.pack_start(magic_box, false, false, 0);

			Gtk.ScrolledWindow achievement_scroller = new Gtk.ScrolledWindow(null, null);
			achievement_box = new Gtk.VBox(false, 5);
			achievement_scroller.add_with_viewport(achievement_box);
			try {
#if WINDOWS
				achievement_bg = new Gdk.Pixbuf.from_file("resources\\achievement_bg.png");
#else
				achievement_bg = new Gdk.Pixbuf.from_file(PREFIX+"/share/xsirc/achievement_bg.png");
#endif
			}
			catch (Error e) {

			}
			fill_achievement_box();
			vbox.pack_start(achievement_scroller, true, true, 3);

			prefs_widget = vbox;
		}

		public override bool on_startup() {
#if !WINDOWS
			Notify.init("XSIRC");
#endif
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
