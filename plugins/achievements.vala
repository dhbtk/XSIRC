/*
 * achievements.vala
 *
 * Copyright (c) 2011 Simon Lindholm
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;

namespace XSIRC {
	public class AchievementsPlugin : Plugin {

		private enum AchievementID {
			M50,
			M300,
			M1000,
			M5000,
			M10000,
			M100000,
			OMNIPRESENT,
			MAGIC,
			KONAMI,
			NITPICKER,
			E,
			ADVENTURE,
			ECHO,
			BEBOLD,
			LUCKY,
			SLOW,
			ALLCAPS,
			APL,
			UNIMAGINATIVE,
			EMPTY,
			TALKATIVE,
			EEGAME
		}
		private struct AchievementData {
			public AchievementID id;
			public string short_name;
			public string description;
		}

		private const AchievementData[] achievements = {
			{AchievementID.M50, N_("Tin"),
				N_("Type 50 messages.")},
			{AchievementID.M300, N_("Spartan"),
				N_("Type 300 messages.")},
			{AchievementID.M1000, N_("The worth of a picture"),
				N_("Type 1,000 messages.")},
			{AchievementID.M5000, N_("0x1388"),
				N_("Type 5,000 messages.")},
			{AchievementID.M10000, N_("Myriapost"),
				N_("Type 10,000 messages.")},
			{AchievementID.M100000, N_("Decimegapost!"),
				N_("Type 100,000 messages.")},
			{AchievementID.OMNIPRESENT, N_("Omnipresent"),
				N_("Keep the program open for a week.")},
			{AchievementID.MAGIC, N_("Frobnicator"),
			    N_("Change the magic switch back and forth repeatedly.")},
			{AchievementID.KONAMI, N_("+100 lives!"),
			    N_("Use the Konami Code.")},
			{AchievementID.NITPICKER, N_("Nitpicker"),
			    N_("Change one letter in a channel's subject.")},
			{AchievementID.E, N_("Anti-ɐʍɥɔs"),
			    N_("Accomplish communication of many non-fifth symbols in a row.")},
			{AchievementID.ADVENTURE, N_("Adventurer"),
			    N_("Pretend IRC is a text-based adventure.")},
			{AchievementID.ECHO, N_("Echo"),
			    N_("Repeat what you just said.")},
			{AchievementID.BEBOLD, N_("Be bold"),
			    N_("Use all the different formatting functions.")},
			{AchievementID.LUCKY, N_("Cheese's fault"),
			    N_("Be lucky.")},
			{AchievementID.SLOW, N_("Slow typist"),
			    N_("Spend more than 60 minutes typing a message.")},
			{AchievementID.ALLCAPS, N_("COBOL specialist"),
			    N_("Type in ALLCAPS.")},
			{AchievementID.APL, N_("APL programmer"),
			    N_("Type a message consisting of lots of special characters.")},
			{AchievementID.UNIMAGINATIVE, N_("Creativity... fading..."),
			    N_("Repeat the exact same thing 10 times within a chat session.")},
			{AchievementID.EMPTY, N_("Hello? Anyone there?"),
			    N_("Say something in an empty channel.")},
			{AchievementID.TALKATIVE, N_("Talkative"),
			    N_("Talk continuously for five hours.")},
			{AchievementID.EEGAME, N_("Egg finder"),
			    N_("Discover the hidden Easter egg game.")}
		};

		private bool unsaved = false;
		private double save_progress = 0;
		private time_t last_message_time = time_t();

		// OMNIPRESENT
		private TimeoutSource? omnipresent_timeout = null;

		// MAGIC
		private int magic_value = 1;
		private double magic_counter;

		// E
		private unichar e_char;
		private HashSet<unichar> counted_alphabet = new HashSet<unichar>();

		// M50, etc.
		private int sent_messages = 0;

		// ECHO
		private string last_message = "";

		// BEBOLD
		private int used_formatting = 0;

		// SLOW
		private time_t slow_start = time_t();

		// KONAMI
		private int konami_state;

		// UNIMAGINATIVE
		private HashMap<uint, int> unimaginative_seen = new HashMap<uint, int>();

		// TALKATIVE
		private time_t talkative_start = time_t();

		private Gtk.HBox magic_box;
		private Gtk.VBox achievement_box;
		private Gdk.Pixbuf achievement_bg;
		private Gtk.MenuItem game_menu_item;

		private EasterEggGame game;
		private int game_highscore = 0;

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

		private string get_internal_name(AchievementData a) {
			string str = a.id.to_string();
			int prefix_len = AchievementID.E.to_string().length-1;
			return str.substring(prefix_len);
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

				if (conf.has_key("achievements", "active")) {
					enabled = conf.get_boolean("achievements", "active");
				}

				if (conf.has_key("achievements", "sent_messages")) {
					sent_messages = conf.get_integer("achievements", "sent_messages");
				}

				if (conf.has_key("achievements", "used_formatting")) {
					used_formatting = conf.get_integer("achievements", "used_formatting");
				}

				if (conf.has_key("achievements", "magic_value")) {
					magic_value = conf.get_integer("achievements", "magic_value");
				}

				if (conf.has_key("achievements", "game_highscore")) {
					game_highscore = conf.get_integer("achievements", "game_highscore");
				}

				foreach (AchievementData a in achievements) {
					if (conf.has_key("achievements", get_internal_name(a))) {
						awarded[a.id] = (time_t)conf.get_integer("achievements", get_internal_name(a));
					}
				}
			} catch(Error e) {
				// Nothing saved yet.
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

			// Konami code achievement
			Main.gui.main_window.key_press_event.connect((key) => {
				test_achievement(AchievementID.KONAMI, () => test_konami(key.keyval));
				return false;
			});

			// Slow typist achievement
			Main.gui.text_entry.key_press_event.connect((key) => {
				if (Main.gui.text_entry.text == "") {
					slow_start = time_t();
				}
				return false;
			});

			// Set up the fake 'Save as...' easter-egg menu entry. Its
			// visibility state is setup in reset().
			game_menu_item = new Gtk.MenuItem.with_label(_("Save as..."));
			game_menu_item.activate.connect(cb_game_open);
			Gtk.MenuItem view_menu_item = Main.gui.menu_ui.get_widget("/MainMenu/ViewMenu") as Gtk.MenuItem;
			assert (view_menu_item != null);
			Gtk.Menu view_menu = view_menu_item.get_submenu() as Gtk.Menu;
			assert (view_menu != null);
			view_menu.insert(game_menu_item, 8);

			game = new EasterEggGame(game_highscore, (hs) => {
				game_highscore = hs;
				save();
			});
		}

		private void save() {
			try {
				KeyFile conf = new KeyFile();

				conf.set_boolean("achievements", "active", enabled);
				conf.set_integer("achievements", "sent_messages", sent_messages);
				conf.set_integer("achievements", "used_formatting", used_formatting);
				conf.set_integer("achievements", "magic_value", magic_value);

				if (game_highscore > 0) {
					conf.set_integer("achievements", "game_highscore", game_highscore);
				}

				foreach (AchievementData a in achievements) {
					int val = (int)awarded[a.id];
					if (val != 0) {
						conf.set_integer("achievements", get_internal_name(a), val);
					}
				}

				FileUtils.set_contents(Environment.get_user_config_dir()+"/xsirc/achievements.conf",conf.to_data());
			} catch(Error e) {

			}
			unsaved = false;
			save_progress = 0;
		}

		// Do a partial save, such that a full save gets done when all the
		// progress values add up to 1 ('progress' being some value between
		// 0 and 1 in each step), and mark the data as being in an unsaved
		// state to be saved when the program is closed. The function may be
		// called with the value 0 to get only this latter effect.
		private void incremental_save(double progress) {
			unsaved = true;
			save_progress += progress;
			if (save_progress >= 1) {
				save();
			}
		}

		private bool has_achievement(AchievementID id) {
			return ((int)awarded[id] != 0);
		}

		private void reset() {
			magic_counter = 0;
			konami_state = 0;
			magic_box.set_sensitive(enabled);
			unimaginative_seen.clear();

			if (omnipresent_timeout != null) {
				omnipresent_timeout.destroy();
				omnipresent_timeout = null;
			}
			if (enabled && !has_achievement(AchievementID.OMNIPRESENT)) {
				omnipresent_timeout = new TimeoutSource(1000*60*60*24*7);
				omnipresent_timeout.set_callback(() => {
					award_achievement(AchievementID.OMNIPRESENT);
					return false;
				});
				omnipresent_timeout.attach(null);
			}

			if (enabled) {
				game_menu_item.show();
			}
			else{
				game_menu_item.hide();
			}

			if (unsaved) {
				// If the plugin is disabled we will not be notified on shutdown,
				// so save now if we have unsaved data.
				save();
			}
		}

		private void cb_game_open() {
			assert(enabled);
			if (magic_value == 5) {
				award_achievement(AchievementID.EEGAME);
				game.open();
			}
			else {
				Gtk.MessageDialog d = new Gtk.MessageDialog(
						Main.gui.main_window,
						Gtk.DialogFlags.MODAL,
						Gtk.MessageType.QUESTION,
						Gtk.ButtonsType.YES_NO,
						"%s",
						_("Insufficient magic.")
				);
				d.response.connect((id) => {
					d.destroy();
				});
				d.run();
			}
		}


		private bool test_e(string message) {
			string[] words = message.down().split(" ");
			int counted_words = 0;
			foreach (string word in words) {
				if (word.index_of_char(e_char) != -1) {
					return false;
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
				if (3*alpha >= 2*len && len > 0) {
					++counted_words;
				}
			}

			return (counted_words >= 7);
		}

		private bool test_allcaps(string message) {
			unichar c;
			int i = 0, upper = 0;
			while (message.get_next_char(ref i, out c)) {
				if (c.islower()) {
					return false;
				}
				if (c.isupper()) {
					++upper;
				}
			}

			return (upper >= 10);
		}

		private bool test_apl(string message) {
			unichar c;
			for (int i = 0; message.get_next_char(ref i, out c); ) {
				if (c.isalpha()) {
					return false;
				}
			}

			HashSet<unichar> special = new HashSet<unichar>();
			for (int i = 0; message.get_next_char(ref i, out c); ) {
				if (!c.isdigit() && !c.isspace()) {
					special.add(c);
				}
			}

			return (special.size >= 7);
		}

		private bool test_echo(string message) {
			int since_last = (int)(time_t() - last_message_time);
			if (since_last < 60*3 && message == last_message) {
				return true;
			}
			last_message = message;
			return false;
		}

		private bool test_lucky() {
			return (Random.int_range(0, 200) == 0);
		}

		private bool test_slow() {
			int since_start = (int)(time_t() - slow_start);
			return (since_start >= 60*60);
		}

		private bool test_konami(uint key) {
			bool valid = false;
			if (key == Gdk.keyval_from_name("Up")) {
				if (konami_state != 1) konami_state = 0;
				valid = true;
			}
			else if (key == Gdk.keyval_from_name("Down")) {
				valid = (konami_state == 2 || konami_state == 3);
			}
			else if (key == Gdk.keyval_from_name("Left")) {
				valid = (konami_state == 4 || konami_state == 6);
			}
			else if (key == Gdk.keyval_from_name("Right")) {
				valid = (konami_state == 5 || konami_state == 7);
			}
			else if (key == 'b' || key == 'B') {
				valid = (konami_state == 8);
			}
			else if (key == 'a' || key == 'A') {
				valid = (konami_state == 9);
			}

			if (valid) {
				++konami_state;
			}
			else {
				konami_state = 0;
			}
			return (konami_state == 10);
		}

		private bool test_talkative() {
			time_t now = time_t();
			int since_last = (int)(now - last_message_time);
			if (since_last >= 60*5) {
				talkative_start = now;
			}

			int since_start = (int)(now - talkative_start);
			return (since_start >= 60*60*5);
		}

		private bool test_unimaginative(string message) {
			uint hash = message.hash();

			int since_last = (int)(time_t() - last_message_time);
			if (since_last >= 60*90) {
				// Not saying anything in 90 minutes counts as expiry of a
				// chat session.
				unimaginative_seen.clear();
			}

			if (!unimaginative_seen.has_key(hash)) {
				unimaginative_seen.set(hash, 1);
				return false;
			}

			int c = unimaginative_seen.get(hash) + 1;
			if (c < 10) {
				unimaginative_seen.set(hash, c);
				return false;
			}

			unimaginative_seen.clear();
			return true;
		}

		private bool test_adventure(string message) {
			return /^(> ?)?(go (west|east|north|south)|xyzzy|inventory|examine .*)$/.match(message);
		}

		private bool test_bebold(string message) {
			unichar c;
			int f = used_formatting;
			for (int i = 0; message.get_next_char(ref i, out c); ) {
				switch (c) {
					case 2: // Bold
						f |= 1;
						break;
					case 22: // Italics
						f |= 2;
						break;
					case 31: // Underline
						f |= 4;
						break;
					case 3: // Color
						f |= 8;
						break;
				}
			}
			if (f == used_formatting) {
				return false;
			}
			used_formatting = f;
			if (used_formatting == 15) {
				return true;
			}
			save();
			return false;
		}

		private bool test_empty(Server server, string target) {
			// (I don't know enough about IRC to tell if this could be replaced
			// by a check for (channel != null && channel.users.size == 1).)

			Server.Channel? channel = server.find_channel(target);
			if (channel == null) {
				return false;
			}
			string nick = server.nick.down();
			foreach (string user in channel.users) {
				if (user.down() != nick) {
					return false;
				}
			}
			return true;
		}

		private bool modification_change(string a, string b) {
			bool has_mod = false;
			for (int i = 0; i < a.length; ++i) {
				if (a[i] != b[i]) {
					if (has_mod) {
						return false;
					}
					has_mod = true;
				}
			}
			return has_mod;
		}

		private bool addition_change(string a, string b) {
			bool has_mod = false;
			for (int i = 0, j = 0; i < a.length; ++i, ++j) {
				if (a[i] != b[j]) {
					if (has_mod) {
						return false;
					}
					--i;
					has_mod = true;
				}
			}
			return true;
		}

		private bool single_change(string a, string b) {
			int sa = a.length, sb = b.length;
			if (sa == sb) {
				return modification_change(a, b);
			}
			if (sa+1 == sb) {
				return addition_change(a, b);
			}
			if (sa == sb+1) {
				return addition_change(b, a);
			}
			return false;
		}

		private bool test_nitpicker(Server server, Server.Channel.Topic current, Server.Channel.Topic old) {
			return (server.nick.down() == current.setter.down() && single_change(current.content, old.content));
		}

		private TestFunc test_message_count(int lim) {
			return () => (sent_messages >= lim);
		}

		private delegate bool TestFunc();
		private void test_achievement(AchievementID id, TestFunc func) {
			if (!has_achievement(id) && func()) {
				award_achievement(id);
			}
		}

		private delegate bool MessageTestFunc(string message);
		private void test_message_achievement(AchievementID id, MessageTestFunc func, string message) {
			test_achievement(id, () => func(message));
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
				Gtk.Label text = new Gtk.Label(_("<b>%s</b>: %s").printf(
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
			if (has_achievement(id)) {
				return;
			}
			AchievementData a = achievements[id];
			string title = _("Achievement unlocked - %s").printf(_(a.short_name));
			string desc = _(a.description);
#if !WINDOWS
			var notification = new Notify.Notification(title, Markup.escape_text(desc), get_icon_path());
			notification.set_timeout(4000);
			notification.set_urgency(Notify.Urgency.NORMAL);
			try {
				notification.show();
			} catch(Error e) {

			}
#else
			Server? server = Main.gui.current_server();
			if (server != null) {
				GUI.View? view = server.current_view();
				if (view != null) {
					view.add_text("\x02" + title + "\x02: " + desc);
				}
			}
#endif
			awarded[id] = time_t();
			build_achievement_box();
			save();
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
			magic_switch.adjustment.value = magic_value;
			magic_switch.adjustment.value_changed.connect(() => {
				int nval = (int)(magic_switch.adjustment.value + 0.5);
				if (enabled) {
					int dif = nval - magic_value;
					magic_counter += (dif < 0 ? -dif : dif);
					test_achievement(AchievementID.MAGIC, () => (magic_counter >= 30));
				}
				magic_value = nval;
				incremental_save(0);
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

		public override bool on_topic(Server server, Server.Channel.Topic topic,
		        Server.Channel.Topic old_topic, string channel, string username, string usermask) {
			test_achievement(AchievementID.NITPICKER, () => test_nitpicker(server, topic, old_topic));
			return true;
		}

		public override bool on_sent_message(Server server, string nick, string target,
		                                     string message, string raw_msg) {
			if (message.has_prefix("\x01")) { // CTCP / action, ignore
				string msg = message.slice(1, -1);
				return true;
			}
			++sent_messages;
			test_message_achievement(AchievementID.E, test_e, message);
			test_message_achievement(AchievementID.ALLCAPS, test_allcaps, message);
			test_message_achievement(AchievementID.APL, test_apl, message);
			test_message_achievement(AchievementID.ADVENTURE, test_adventure, message);
			test_message_achievement(AchievementID.ECHO, test_echo, message);
			test_message_achievement(AchievementID.BEBOLD, test_bebold, message);
			test_message_achievement(AchievementID.UNIMAGINATIVE, test_unimaginative, message);
			test_achievement(AchievementID.TALKATIVE, test_talkative);
			test_achievement(AchievementID.LUCKY, test_lucky);
			test_achievement(AchievementID.SLOW, test_slow);
			test_achievement(AchievementID.EMPTY, () => test_empty(server, target));
			test_achievement(AchievementID.M50, test_message_count(50));
			test_achievement(AchievementID.M300, test_message_count(300));
			test_achievement(AchievementID.M1000, test_message_count(1000));
			test_achievement(AchievementID.M5000, test_message_count(5000));
			test_achievement(AchievementID.M10000, test_message_count(10000));
			test_achievement(AchievementID.M100000, test_message_count(100000));

			last_message_time = time_t();
			incremental_save(0.02);
			return true;
		}

		public override bool on_shutdown() {
			if (unsaved) {
				save();
			}
			return true;
		}
	}

	public class EasterEggGame {

		private const int W = 560;
		private const int H = 440;

		private bool running = false;
		private Gtk.Window? window;

		public delegate void HighscoreSetter(int hs);
		private int highscore;
		private HighscoreSetter highscore_setter;

		public EasterEggGame(int hs, HighscoreSetter hs_setter) {
			highscore = hs;
			highscore_setter = hs_setter;
		}

		private bool cb_close() {
			close();
			return false;
		}

		public void close() {
			if (running) stop();
			assert(window != null);
			assert(!running);
			window.destroy();
			window = null;
		}

		public void open() {
			if (window != null) {
				window.present();
				return;
			}

			window = new Gtk.Window();
			window.title = _("XSIRC 2D");
			window.set_size_request(W, H);
			window.resizable = false;
			window.window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
			window.delete_event.connect(cb_close);
			window.key_press_event.connect(cb_keypress);
			window.key_release_event.connect(cb_keyrelease);
			window.focus_out_event.connect(cb_focusout);
			window.expose_event.connect(cb_expose);
			window.set_app_paintable(true);
			window.show_all();
		}

		private bool cb_keypress(Gdk.EventKey ev) {
			uint key = ev.keyval;
			if (!running) {
				if (key == 32) {
					start();
				}
				else if (key == Gdk.keyval_from_name("Escape")) {
					close();
				}
			}
			else {
				handle_keypress(key);
			}
			return false;
		}

		private bool cb_focusout(Gdk.EventFocus ev) {
			if (running) {
				handle_unfocus();
			}
			return false;
		}

		private bool cb_keyrelease(Gdk.EventKey ev) {
			uint key = ev.keyval;
			if (running) {
				handle_keyrelease(key);
			}
			return false;
		}

		private bool cb_expose(Gdk.EventExpose ev) {
			Cairo.Context context = Gdk.cairo_create(ev.window);
			if (!running) {
				draw_menu(context);
			}
			else {
				draw(context);
			}
			return false;
		}


		// Helpers //

		private static void draw_centered_text(Cairo.Context cx, string text) {
			double x, y;
			cx.get_current_point(out x, out y);
			Cairo.TextExtents ext;
			cx.text_extents(text, out ext);
			cx.rel_move_to(-ext.width/2, ext.height/2);
			cx.show_text(text);
			cx.move_to(x, y);
		}


		// Menu logic //

		// Draw a XSIRC 2D logo to the screen.
		private void draw_logo(Cairo.Context cx) {
			cx.select_font_face("monospace", Cairo.FontSlant.NORMAL,
								Cairo.FontWeight.BOLD);
			cx.set_source_rgb(0.9, 0.1, 0.1);
			cx.set_font_size(72);
			Cairo.TextExtents ext;
			cx.text_extents("XS", out ext);
			cx.move_to(W/2 - ext.width/2, 100);
			cx.show_text("XS");

			cx.select_font_face("monospace", Cairo.FontSlant.ITALIC,
								Cairo.FontWeight.NORMAL);
			cx.set_source_rgb(0.3, 0.1, 0.9);
			cx.set_font_size(40);
			cx.move_to(W/2 - ext.width/2 - 7, 140);
			cx.show_text("IRC");

			cx.select_font_face("monospace", Cairo.FontSlant.NORMAL,
								Cairo.FontWeight.BOLD);
			cx.set_source_rgb(0.1, 0.1, 0.1);
			cx.set_font_size(26);
			cx.rel_move_to(22, 1);
			cx.rotate(-Math.PI/2);
			cx.show_text("2D");
			cx.identity_matrix();
		}

		// Draw the menu screen that is first encountered when starting the game.
		private void draw_menu(Cairo.Context cx) {
			cx.set_source_rgb(1, 1, 1);
			cx.paint();

			draw_logo(cx);

			cx.select_font_face("sans-serif", Cairo.FontSlant.NORMAL,
								Cairo.FontWeight.NORMAL);
			cx.set_source_rgb(0.1, 0.1, 0.1);
			cx.set_font_size(30);
			cx.move_to(W/2, H/2);
			draw_centered_text(cx, _("Press SPACE to start."));

			string intro_msg = _("Your favorite channel is being invaded by spammers and badly\nwritten IRC bots. Shoot them out of existance and save the\nchannel from dying, without harming the innocent users!");
			cx.rel_move_to(0, 44);
			cx.set_font_size(14);
			string[] intro_lines = intro_msg.split("\n");
			foreach(string line in intro_lines) {
				draw_centered_text(cx, line);
				cx.rel_move_to(0, 18);
			}

			cx.set_font_size(15);
			cx.move_to(W/2, 360);
			draw_centered_text(cx, _("Shoot with SPACE."));
			cx.rel_move_to(0, 18);
			draw_centered_text(cx, _("Steer with the ARROW KEYS."));
			cx.rel_move_to(0, 18);
			draw_centered_text(cx, _("Quit with ESCAPE."));
		}


		// Game logic //

		private struct Position {
			public double x;
			public double y;
			public void wrap() {
				if (x < 0) x += W;
				if (x >= W) x -= W;
				if (y < 0) y += H;
				if (y >= H) y -= H;
			}

			public bool hit(Position p2, double dist) {
				double dx = p2.x - x;
				double dy = p2.y - y;
				return (dx*dx + dy*dy <= dist*dist);
			}
		}

		// An entity, like the player or a bot.
		private abstract class Entity {
			public Position pos { get; private set; }
			public EasterEggGame game { get; private set; }
			protected double vx;
			protected double vy;
			private int invincibility_time_end;

			public Entity(EasterEggGame game, int invincibility_time) {
				// Make the entity drift in some random direction, but avoid
				// nearly axis-aligned ones to make them move all over the
				// space.
				double angle = 0;
				do {
					angle = Random.double_range(0, Math.PI*2);
				} while (nearly_axis_aligned(angle));

				double speed = Random.double_range(0.7, 1.2);
				pos.x = Random.double_range(30, W-30);
				pos.y = Random.double_range(30, H-30);
				vx = Math.cos(angle) * speed;
				vy = Math.sin(angle) * speed;
				this.game = game;
				invincibility_time_end = game.time + invincibility_time;
			}

			public bool is_invincible() {
				return game.time < invincibility_time_end;
			}

			public bool has_invincibility_flash() {
				int inv_left = invincibility_time_end - game.time;
				return (inv_left > 0 && (inv_left / 256)%2 != 0);
			}

			public void move() {
				pos.x += vx;
				pos.y += vy;
				pos.wrap();
			}

			public abstract void draw(Cairo.Context cx, Position pos);
			public abstract Message? send_message();
			public abstract void set_message_color(Cairo.Context cx);
		}

		private class PlayerEntity : Entity {

			private int next_shot;
			public bool shooting = false;
			public double angle;

			public PlayerEntity (EasterEggGame game) {
				base(game, 0);
				vx = vy = 0;
				pos.x = W/2;
				pos.y = H/2;
				angle = -Math.PI/2;
				next_shot = game.time;
			}

			public void logic(bool space, int hor, int ver) {
				const double add_speed = 5.0 / 60;
				const double remove_speed = 6.0 / 60;
				const double max_speed = 4.0;

				if (space && next_shot <= game.time) {
					shooting = true;
					next_shot = game.time + 80;
				}
				else {
					shooting = false;
				}

				angle += hor * 0.8 * (Math.PI*2 / 60);
				if (ver > 0) {
					// Moving forward.
					vy += add_speed * Math.sin(angle);
					vx += add_speed * Math.cos(angle);
					double sp2 = vx*vx + vy*vy;
					if (sp2 > max_speed*max_speed) {
						double f = max_speed / Math.sqrt(sp2);
						vx *= f;
						vy *= f;
					}
				}
				else if (ver < 0) {
					// Reducing speed.
					double sp = Math.sqrt(vx*vx + vy*vy);
					double nsp = sp - remove_speed;
					if (nsp <= 0) {
						vx = vy = 0;
					}
					else {
						nsp /= sp;
						vx *= nsp;
						vy *= nsp;
					}
				}
			}

			public override void draw(Cairo.Context cx, Position pos) {
				const double size = 3.3;
				cx.move_to(pos.x, pos.y);
				cx.rotate(angle);
				cx.rel_move_to(6*size, 0);
				cx.rel_line_to(-8*size, 3*size);
				cx.rel_line_to(0, -6*size);
				cx.close_path();
				cx.set_source_rgb(1, 0, 0);
				cx.fill();
				cx.identity_matrix();
			}

			public override Message? send_message() {
				return null;
			}

			public override void set_message_color(Cairo.Context cx) {}
		}

		private class UserEntity : Entity {

			static const string[] random_messages = {
				"I'm a dinosaur!",
				"This is a message!",
				"Communication!",
				"Dummy string!",
				"Achievements are awesome!",
				"IRC is cool!",
				"<insert message>"
			};

			private static string get_random_message() {
				return random_messages[Random.int_range(0, random_messages.length)];
			}

			private int next_message_time;

			public UserEntity (EasterEggGame game) {
				base(game, 0);
				next_message_time = game.time;
			}

			public override void draw(Cairo.Context cx, Position pos) {
				const double size = 3.3;
				cx.move_to(pos.x, pos.y);
				cx.rel_move_to(0, -4*size);
				cx.rel_line_to(3*size, 6*size);
				cx.rel_line_to(-6*size, 0);
				cx.close_path();
				cx.set_source_rgb(0, 0, 0);
				cx.fill();

				cx.move_to(pos.x, pos.y + 2*size + 6);
				cx.set_source_rgb(0, 0.7, 0);
				cx.set_font_size(11);
				draw_centered_text(cx, "user");
			}

			public override Message? send_message() {
				if (Random.int_range(0, 200) != 0) return null;
				if (game.time < next_message_time) return null;

				Entity? target = game.get_random_entity(this, true);
				if (target == null) {
					return null;
				}

				double angle = aim_at_moving_target(pos, target.pos, target.vx,
				                                    target.vy, Message.SPEED);

				next_message_time = game.time + 1000;
				return new Message(this, angle, get_random_message());
			}

			public override void set_message_color(Cairo.Context cx) {
				cx.set_source_rgb(0, 0, 0.2);
			}
		}

		private class SpambotEntity : Entity {

			static const string[] random_messages = {
				"egg bacon sausage spam",
				"words words words",
				"you won the lottery!",
				"buy wow gold powerleveling services",
				"your ebay account could be suspended",
				"just $10 for achievement hints"
			};

			private static string get_random_message() {
				string msg = "spam spam spam spam";
				if (Random.next_double() < 0.4) {
					msg = random_messages[Random.int_range(0, random_messages.length)];
				}
				return msg;
			}

			private int next_message_time;

			public SpambotEntity (EasterEggGame game) {
				base(game, 1000);
				next_message_time = game.time + 1500;
			}

			public override void draw(Cairo.Context cx, Position pos) {
				const double size = 10;

				if (!has_invincibility_flash()) {
					cx.move_to(pos.x, pos.y);
					cx.rel_move_to(-size, -size);
					cx.rel_line_to(2*size, 0);
					cx.rel_line_to(0, 2*size);
					cx.rel_line_to(-2*size, 0);
					cx.close_path();
					cx.set_source_rgb(0, 0, 0);
					cx.fill();
				}

				cx.move_to(pos.x, pos.y + size + 6);
				cx.set_source_rgb(0.6, 0.2, 0.2);
				cx.set_font_size(11);
				draw_centered_text(cx, "spambot");
			}

			public override Message? send_message() {
				if (game.time < next_message_time) return null;

				Entity? target = null;
				if (Random.next_double() < 0.5) {
					target = game.get_random_entity(this, false);
				}

				double angle;
				if (target != null) {
					angle = aim_at_moving_target(pos, target.pos, target.vx,
					                             target.vy, Message.SPEED);
				}
				else {
					angle = Random.double_range(0, Math.PI*2);
				}

				next_message_time = game.time + 500;
				return new Message(this, angle, get_random_message());
			}

			public override void set_message_color(Cairo.Context cx) {
				cx.set_source_rgb(0.3, 0, 0);
			}
		}

		private class BotEntity : Entity {

			private string get_random_message() {
				switch (Random.int_range(0, 7)) {
					case 0:
						return "UHNAMES NAMESX SAFELIST HCN MAXCHANNELS=20 CHANLIMIT=#:";
					case 1:
						return "PREFIX=(qaohv)~&@%+ CHANMODES=beI,kfL,lj,psmntirRcOAQKVCuzNSMTG";
					case 2:
						return "STATUSMSG=~&@%+ : EXCEPTS INVEX CMDS=KNOCK,MAP,DCCALLOW,USERIP";
					case 3:
						return "%d users online".printf(game.entities.size);
					case 4:
						return "server online for %d seconds".printf(game.time/1000);
					case 5:
						return "improbability level: 2^%d:1".printf(Random.int_range(35000, 400000)*2+1);
					case 6:
						return gen_timestamp("%a, %d %b %Y %T %z", time_t());
				}
				assert_not_reached();
			}

			private int next_message_time;

			public BotEntity (EasterEggGame game) {
				base(game, 1000);
				next_message_time = game.time + 3500;
			}

			public override void draw(Cairo.Context cx, Position pos) {
				const double size = 10;

				if (!has_invincibility_flash()) {
					cx.move_to(pos.x, pos.y);
					cx.rel_move_to(-size, -size);
					cx.rel_line_to(2*size, 0);
					cx.rel_line_to(0, 2*size);
					cx.rel_line_to(-2*size, 0);
					cx.close_path();
					cx.set_source_rgb(0, 0, 0);
					cx.fill();
				}

				cx.move_to(pos.x, pos.y + size + 6);
				cx.set_source_rgb(0.3, 0.3, 0.3);
				cx.set_font_size(11);
				draw_centered_text(cx, "bot");
			}

			public override Message? send_message() {
				if (game.time < next_message_time) return null;

				Entity? target = null;
				if (Random.next_double() < 0.7) {
					target = game.get_random_entity(this, false);
				}

				double angle;
				if (target != null) {
					angle = aim_at_moving_target(pos, target.pos, target.vx,
					                             target.vy, Message.SPEED);
				}
				else {
					angle = Random.double_range(0, Math.PI*2);
				}

				next_message_time = game.time + 3500;
				return new Message(this, angle, get_random_message());
			}

			public override void set_message_color(Cairo.Context cx) {
				cx.set_source_rgb(0.2, 0.2, 0.2);
			}
		}


		// A text string sent from an entity. Messages are not translated since
		// non-English spam looks bad and the English texts fit quite well;
		// this does not matter greatly because one doesn't have very much time
		// to actually read them.
		// 'pos' represents the position the message in some way; when being
		// transmitted it is the end, and when being received (i.e. the dead
		// flag is set) it is the beginning. Note that this is always fixed
		// with respect to the displayed message.
		private class Message {
			public static const double SPEED = 6;

			public string msg { get; private set; }
			public Position pos { get; private set; }
			public bool dead { get; private set; }
			public Entity sender { get; private set; }
			private string sent_part = "";
			private double angle;
			private int starting_end_time;
			private EasterEggGame game;
			private double max_visible_length = 0;
			private double shown_length = 0;

			public Message(Entity sender, double angle, string msg) {
				this.sender = sender;
				this.angle = angle;
				this.msg = msg;
				dead = false;
				pos = sender.pos;
				game = sender.game;
				starting_end_time = game.time + 100;
			}

			// Check whether the message was just shot - it cannot hit
			// anything in that case (see the comment in move_messages() for
			// the reasoning behind this).
			public bool just_started() {
				return game.time < starting_end_time;
			}

			// Return whether the message should be removed, which is the case
			// when it is dead and invisible, and thus pointless to keep around.
			public bool should_be_removed() {
				return (dead && max_visible_length <= 0);
			}

			public void die() {
				assert(!dead);
				dead = true;

				// Correct 'pos' to have its new meaning.
				pos.x -= Math.cos(angle) * shown_length;
				pos.y -= Math.sin(angle) * shown_length;

				// Set the maximum string length to a value such that (with
				// the max-length being decreased in move()) the string never
				// reaches further than the current position.
				max_visible_length = shown_length;
			}

			public void move() {
				// Grow or shrink the maximum visible length.
				max_visible_length += (dead?-1:1) * SPEED;

				// Move the relevant end-point of the message.
				pos.x += Math.cos(angle) * SPEED;
				pos.y += Math.sin(angle) * SPEED;
			}

			public void draw(Cairo.Context cx) {
				cx.set_font_size(13);

				// Calculate which part to send.
				if (dead) {
					// Remove things at the end.
					while (sent_part.length > 0) {
						Cairo.TextExtents ext;
						cx.text_extents(sent_part, out ext);
						if (ext.width > max_visible_length) {
							// The current string is too long; shrink it.
							sent_part = sent_part.substring(0, sent_part.length-1);
						}
						else {
							break;
						}
					}
				}
				else {
					// Expand at the beginning.
					while (sent_part.length < msg.length) {
						int next_from = msg.length - sent_part.length - 1;
						string next_suffix = msg.substring(next_from);
						Cairo.TextExtents ext;
						cx.text_extents(next_suffix, out ext);
						if (ext.width > max_visible_length) {
							// That string would be too long; keep the current one.
							break;
						}
						sent_part = next_suffix;
					}
				}

				Cairo.TextExtents ext;
				cx.text_extents(sent_part, out ext);
				shown_length = ext.width;
				cx.move_to(pos.x, pos.y);
				cx.rotate(angle);

				// The position given by m.pos is either at the end or the
				// beginning of the text, depending on whether the message is
				// shrinking or growing (ie. is dead or not). Correct for this.
				cx.rel_move_to((dead ? 0 : -ext.width), ext.height/2);

				sender.set_message_color(cx);
				cx.show_text(sent_part);
				cx.identity_matrix();
			}
		}

		// A bullet shot by the player.
		private class Bullet {
			private static const double SPEED = 12.0;

			public Position pos;
			private double vx;
			private double vy;
			public double dist = 0.0;
			public Bullet(PlayerEntity pl) {
				pos = pl.pos;
				vx = SPEED * Math.cos(pl.angle);
				vy = SPEED * Math.sin(pl.angle);
			}

			public void move() {
				pos.x += vx;
				pos.y += vy;
				pos.wrap();
				dist += SPEED;
			}
		}


		// Calculate the angle at which to shoot to hit a moving target.
		// The math used is magic and stolen from somewhere on the Internet
		// (though it is obviously based on solving some simple second-degree
		// equation).
		private static double aim_at_moving_target(
				Position from, Position to,
				double vx, double vy, double speed) {
			double dx = to.x - from.x;
			double dy = to.y - from.y;

			double a = vx * vx + vy * vy - speed * speed;
			double b = 2 * (vx * dx + vy * dy);
			double c = dx * dx + dy * dy;

			double det = b * b - 4 * a * c;
			// If the determinant is negative, there is no way to hit the
			// target. I don't think this will ever happen since the speed of
			// messages is greater than that of entities, but shoot randomly
			// if it does.
			if (det < 0) {
				return Random.double_range(0, Math.PI*2);
			}

			// Calculate the time that we will hit the target.
			double a_sign = (a < 0 ? -1 : 1);
			double t = (a_sign * Math.sqrt(det) - b) / (2 * a);

			// Aim for where the target will be after time t.
			dx += t * vx;
			dy += t * vy;
			return Math.atan2(dy, dx);
		}

		// Check whether an angle is nearly 0, 90, 180 or 270 degrees.
		private static bool nearly_axis_aligned(double angle) {
			const double eps = 0.2*Math.PI/2;
			assert(angle >= 0);
			return Math.fmod(angle+eps, Math.PI/2) <= eps*2;
		}


		private int time;
		private int end_time;
		private TimeoutSource game_loop_timeout = null;
		private LinkedList<Entity> entities = null;
		private LinkedList<Message> messages = null;
		private LinkedList<Bullet> bullets = null;
		private PlayerEntity player_entity;

		private enum Keys {
			Space, Left, Down, Up, Right, LAST
		}
		private bool[] keys;
		private int time_next_bot;
		private double bot_delay_exp;
		private bool next_is_bot;
		private double happiness;
		private int score;
		private bool game_over;

		private void start() {
			assert(!running);
			running = true;
			game_over = false;
			time = 0;
			game_loop_timeout = new TimeoutSource(16);
			game_loop_timeout.set_callback(() => {
				time += 16;
				game_logic();
				return true;
			});
			game_loop_timeout.attach(null);
			entities = new LinkedList<Entity>();
			messages = new LinkedList<Message>();
			bullets = new LinkedList<Bullet>();
			happiness = 1.0;
			score = 0;
			time_next_bot = time + 1000;
			bot_delay_exp = 1;
			next_is_bot = false;
			keys = new bool[Keys.LAST];
			unmark_keys();

			player_entity = new PlayerEntity(this);
			entities.add(player_entity);
			for (int i = 0; i < 5; ++i) {
				entities.add(new UserEntity(this));
			}

			window.queue_draw();
		}

		private void stop() {
			assert(running);
			game_loop_timeout.destroy();
			game_loop_timeout = null;
			entities = null;
			messages = null;
			bullets = null;
			player_entity = null;
			running = false;
		}

		// Return a random entity other than 'self', giving more weight to
		// ones near it.
		private Entity? get_random_entity(Entity self, bool only_users) {
			var users = new ArrayList<Entity>();
			var probs = new ArrayList<double?>();
			double prsum = 0;

			foreach (Entity e in entities) {
				if (only_users && !(e is UserEntity)) continue;
				if (e != self) {
					double dx = self.pos.x - e.pos.x;
					double dy = self.pos.y - e.pos.y;
					double dsq = dx*dx + dy*dy;
					double pr = 0.1 + 30/(0.01*dsq + 100);
					users.add(e);
					probs.add(pr);
					prsum += pr;
				}
			}

			if (users.is_empty) return null;
			double rand = Random.double_range(0, prsum);
			prsum = 0;
			for (int i = 0; i < users.size; ++i) {
				prsum += probs[i];
				if (prsum >= rand) {
					return users[i];
				}
			}

			// Floating point imprecision could theoretically get us here.
			return null;
		}

		private int next_bot_delay() {
			bot_delay_exp *= 0.93;
			if (Random.next_double() < 0.35) {
				next_is_bot = true;
				return (int)(bot_delay_exp*1000) + 1000;
			}
			else {
				next_is_bot = false;
				return (int)(bot_delay_exp*1400) + 1300;
			}
		}

		private void end_game() {
			game_over = true;
			end_time = time;
			if (score > highscore) {
				highscore = score;
				highscore_setter(highscore);
			}
		}

		private void add_happiness(double incr) {
			assert(!game_over);
			happiness += incr;
			if (happiness > 1) happiness = 1;
			if (happiness <= 0) {
				happiness = 0;
				end_game();
			}
		}

		private void handle_keypress(uint key) {
			if (key == Gdk.keyval_from_name("Escape")) {
				close();
			}
			else if (game_over && key == Gdk.keyval_from_name("Return")) {
				stop();
				start();
			}
			else {
				mark_key(key, true);
			}
		}

		private void handle_keyrelease(uint key) {
			mark_key(key, false);
		}

		private void handle_unfocus() {
			unmark_keys();
		}

		private void unmark_keys() {
			for (int i = 0; i < Keys.LAST; ++i) {
				keys[i] = false;
			}
		}

		private void mark_key(uint key, bool state) {
			if (key == ' ') {
				keys[Keys.Space] = state;
			}
			else if (key == Gdk.keyval_from_name("Left")) {
				keys[Keys.Left] = state;
			}
			else if (key == Gdk.keyval_from_name("Down")) {
				keys[Keys.Down] = state;
			}
			else if (key == Gdk.keyval_from_name("Up")) {
				keys[Keys.Up] = state;
			}
			else if (key == Gdk.keyval_from_name("Right")) {
				keys[Keys.Right] = state;
			}
		}

		// Move messages and test for collisions. Called once per frame.
		private void move_messages() {

			Iterator<Message> mit = messages.iterator();
			while (mit.next()) {
				Message m = mit.get();

				m.move();

				if (m.should_be_removed()) {
					mit.remove();
					continue;
				}

				// There is nothing more to do for dead messages.
				if (m.dead) continue;

				// Stop messages at the edges, by setting them into the
				// 'receiving' state.
				if (m.pos.x < 0 || m.pos.y < 0 ||
				    m.pos.x > W || m.pos.y > H) {
					m.die();
					continue;
				}

				// Don't test for collisions for newly sent messages since it
				// might make two bots that are too close to each other spam
				// indefinitely, hanging the application.
				if (m.just_started()) continue;

				foreach (Entity e in entities) {
					if (m.sender != e && !e.is_invincible() && m.pos.hit(e.pos, 13)) {
						// The message hit an entity - set it to a dead state
						// and apply some effects depending on the types of
						// sender and receiver.

						if (e is BotEntity) {
							// Duplicate the message.
							double angle = Random.double_range(0, Math.PI*2);
							for (int i = 0; i < 3; ++i) {
								Message nm = new Message(e, angle, m.msg);
								messages.add(nm);
								angle += (Math.PI*2/3);
							}
						}
						else if (e is UserEntity && !game_over) {
							if (m.sender is BotEntity) {
								add_happiness(-0.05);
							}
							else if (m.sender is SpambotEntity) {
								add_happiness(-0.07);
							}
						}
						m.die();
						break;
					}
				}
			}
		}

		private void game_logic() {

			if (!game_over) {
				// Regenerate some amount of happiness each frame.
				add_happiness(0.0012);

				// Increase the score continuously.
				score += 20;
			}

			// Introduce new spam bots.
			if (!game_over && time_next_bot <= time) {
				Entity bot;
				if (next_is_bot) {
					bot = new BotEntity(this);
				}
				else {
					bot = new SpambotEntity(this);
				}
				entities.add(bot);
				time_next_bot += next_bot_delay();
			}

			// Handle player logic.
			if (!game_over) {
				player_entity.logic(keys[Keys.Space],
				            (keys[Keys.Right]?1:0) - (keys[Keys.Left]?1:0),
				            (keys[Keys.Up]?1:0) - (keys[Keys.Down]?1:0));
			}


			// Move entities and possibly send messages from them.
			foreach (Entity e in entities) {
				e.move();
				Message? m = e.send_message();
				if (m != null) {
					messages.add(m);
				}
			}

			// Bullets
			if (!game_over && player_entity.shooting) {
				bullets.add(new Bullet(player_entity));
			}
			Iterator<Bullet> bit = bullets.iterator();
			while (bit.next()) {
				Bullet b = bit.get();
				b.move();

				if (b.dist >= 150) {
					bit.remove();
					continue;
				}

				if (game_over) continue;

				// See if they hit something.
				foreach (Entity e in entities) {
					if (e != player_entity && b.pos.hit(e.pos, 15)) {
						if (e is UserEntity) {
							add_happiness(-0.04);
						}
						else {
							// Destroy the targetted bot or spambot.
							score += 1000;
							entities.remove(e);
						}
						bit.remove();
						break;
					}
				}
			}

			move_messages();

			window.queue_draw();
		}

		private void draw(Cairo.Context cx) {
			const int EDGE = 20;

			// Clear the background.
			cx.set_source_rgb(1, 1, 1);
			cx.paint();

			// Use monospace everywhere.
			cx.select_font_face("monospace", Cairo.FontSlant.NORMAL,
			                    Cairo.FontWeight.NORMAL);

			// Draw all entities, possibly several times for wrap-around.
			foreach (Entity e in entities) {
				Position pos = e.pos;
				int edgex = (pos.x < EDGE || pos.x >= H-EDGE)?1:0;
				int edgey = (pos.y < EDGE || pos.y >= H-EDGE)?1:0;
				for (int wx = 0; wx <= edgex; ++wx) {
					for (int wy = 0; wy <= edgey; ++wy) {
						Position p = pos;
						if (wx != 0) p.x += (pos.x < W/2 ? W : -W);
						if (wy != 0) p.y += (pos.y < H/2 ? H : -H);
						e.draw(cx, p);
					}
				}
			}

			// Draw the messages.
			foreach (Message m in messages) {
				m.draw(cx);
			}

			// Draw the bullets.
			cx.set_source_rgb(1, 0, 0);
			foreach (Bullet b in bullets) {
				cx.arc(b.pos.x, b.pos.y, 2.0, 0, Math.PI*2);
				cx.fill();
			}

			// Draw a happiness meter in the corner.
			const double health_bar_width = 70;
			double health_width = health_bar_width * happiness;
			double health_r = (happiness < 0.5 ? 1 : (1 - happiness)/0.5);
			double health_g = (happiness > 0.5 ? 1 : happiness/0.5);
			cx.rectangle(W-10 - health_bar_width, 10, health_width, 10);
			cx.set_source_rgb(health_r, health_g, 0);
			cx.fill();
			cx.rectangle(W-10, 10, -health_bar_width, 10);
			cx.set_source_rgb(0, 0, 0);
			cx.set_line_width(1);
			cx.stroke();

			// Draw the score.
			cx.move_to(W-80, 32);
			cx.set_source_rgb(0, 0, 0);
			cx.set_font_size(10);
			cx.show_text(_("Score: %d").printf(score));

			if (game_over) {
				// Draw a "game over" screen.
				cx.set_source_rgb(0, 0, 0);
				cx.move_to(W/2, 200);
				cx.set_font_size(76);
				cx.select_font_face("sans-serif", Cairo.FontSlant.NORMAL,
				                    Cairo.FontWeight.BOLD);
				draw_centered_text(cx, _("GAME OVER"));

				cx.select_font_face("monospace", Cairo.FontSlant.NORMAL,
				                    Cairo.FontWeight.NORMAL);
				cx.set_font_size(30);
				cx.rel_move_to(0, 64);
				draw_centered_text(cx, _("SCORE: %d TIME: %ds").printf(score, end_time/1000));
				cx.rel_move_to(0, 56);
				draw_centered_text(cx, _("press ENTER to retry"));

				cx.set_font_size(10);
				string hs_text = _("(highscore: %d)").printf(highscore);
				Cairo.TextExtents ext;
				cx.text_extents(hs_text, out ext);

				cx.move_to(W-ext.width - 10, H-10);
				cx.show_text(hs_text);
			}
		}
	}
}

#if !WINDOWS
//[ModuleInit]
Type register_plugin(TypeModule module) {
	return typeof(XSIRC.AchievementsPlugin);
}
#endif
