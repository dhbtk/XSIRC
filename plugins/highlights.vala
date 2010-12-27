/*
 * highlights.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;

public class HighlightsPlugin : XSIRC.Plugin {
	// TODO: make these customizable
	private LinkedList<string> highlight_regexes = new LinkedList<string>();
	private bool highlight_on_nick = true;
	private bool highlight_on_notices = false;
	private bool highlight_on_pms = true;
	private bool highlight_on_all_privmsgs = false;
	private bool blink_on_taskbar = false;
	private bool blink_status_icon = false;
	private bool pop_up_libnotify = true;
	private bool add_to_server_view = true;
	private Gtk.ListStore model = new Gtk.ListStore(1,typeof(string));
	private Gtk.TreeView tree = new Gtk.TreeView();
	private Gtk.StatusIcon icon;
	
	public HighlightsPlugin() {
		name = "Highlights";
		description = _("Adds support for configurable highlights.");
		author = "NieXS";
		version = "0.1";
		priority = 0;
		Gtk.VBox vbox = new Gtk.VBox(false,0);
		prefs_widget = vbox;
		load_settings();
		Gtk.CheckButton h_on_nick = new Gtk.CheckButton.with_mnemonic(_("Highlight on _nickname"));
		h_on_nick.toggled.connect(() => {
			highlight_on_nick = h_on_nick.active;
			save_settings();
		});
		h_on_nick.active = highlight_on_nick;
		vbox.pack_start(h_on_nick,false,false,0);
		Gtk.CheckButton h_on_notice = new Gtk.CheckButton.with_mnemonic(_("Highlight on n_otices"));
		h_on_notice.toggled.connect(() => {
			highlight_on_notices = h_on_notice.active;
			save_settings();
		});
		h_on_notice.active = highlight_on_notices;
		vbox.pack_start(h_on_notice,false,false,0);
		Gtk.CheckButton h_on_pms = new Gtk.CheckButton.with_mnemonic(_("Highlight on _private messages"));
		h_on_pms.toggled.connect(() => {
			highlight_on_pms = h_on_pms.active;
			save_settings();
		});
		h_on_pms.active = highlight_on_pms;
		vbox.pack_start(h_on_pms,false,false,0);
		Gtk.CheckButton h_on_all_pms = new Gtk.CheckButton.with_mnemonic(_("Highlight on _all messages"));
		h_on_all_pms.toggled.connect(() => {
			highlight_on_all_privmsgs = h_on_all_pms.active;
			save_settings();
		});
		h_on_all_pms.active = highlight_on_all_privmsgs;
		vbox.pack_start(h_on_all_pms,false,false,0);
		// Other stuff
		vbox.pack_start(new Gtk.Label(_("When highlighting:")),false,false,0);
		Gtk.CheckButton notify_taskbar = new Gtk.CheckButton.with_label(_("Blink on the taskbar"));
		notify_taskbar.active = blink_on_taskbar;
		notify_taskbar.toggled.connect(() => {
			blink_on_taskbar = notify_taskbar.active;
			save_settings();
		});
		vbox.pack_start(notify_taskbar,false,false,0);
		Gtk.CheckButton notify_tray = new Gtk.CheckButton.with_label(_("Blink the tray icon"));
		notify_tray.active = blink_status_icon;
		notify_tray.toggled.connect(() => {
			blink_status_icon = notify_tray.active;
			save_settings();
		});
		vbox.pack_start(notify_tray,false,false,0);
		Gtk.CheckButton notify_balloon = new Gtk.CheckButton.with_label(_("Pop up a notification balloon"));
		notify_balloon.active = pop_up_libnotify;
		notify_balloon.toggled.connect(() => {
			pop_up_libnotify = notify_balloon.active;
			save_settings();
		});
		vbox.pack_start(notify_balloon,false,false,0);
		Gtk.CheckButton notify_server_view = new Gtk.CheckButton.with_label(_("Add message to server view"));
		notify_server_view.active = add_to_server_view;
		notify_server_view.toggled.connect(() => {
			add_to_server_view = notify_server_view.active;
			save_settings();
		});
		vbox.pack_start(notify_server_view,false,false);
		// Tree View
		vbox.pack_start(new Gtk.Label(_("Regexes to highlight on:")),false,false,0);
		Gtk.CellRendererText renderer = new Gtk.CellRendererText();
		renderer.editable = true;
		renderer.edited.connect(regex_edited);
		tree.append_column(new Gtk.TreeViewColumn.with_attributes(_("Regex"),renderer,"text",0,null));
		tree.model = model;
		display_regexes();
		Gtk.Button add_button = new Gtk.Button.from_stock(Gtk.STOCK_ADD);
		add_button.clicked.connect(add_regex);
		Gtk.Button remove_button = new Gtk.Button.from_stock(Gtk.STOCK_REMOVE);
		remove_button.clicked.connect(remove_regex);
		Gtk.ScrolledWindow scroll = new Gtk.ScrolledWindow(null,null);
		Gtk.HButtonBox bbox = new Gtk.HButtonBox();
		scroll.add(tree);
		bbox.pack_start(add_button,true,true,0);
		bbox.pack_start(remove_button,true,true,0);
		Gtk.VBox tree_box = new Gtk.VBox(false,0);
		tree_box.pack_start(scroll,true,true,0);
		tree_box.pack_start(bbox,false,false,0);
		vbox.pack_start(tree_box,true,true,0);
		
		icon = new Gtk.StatusIcon.from_file(PREFIX+"/share/pixmaps/xsirc.png");
		icon.activate.connect(() => {
			XSIRC.Main.gui.main_window.present();
			XSIRC.Main.gui.main_window.set_urgency_hint(false);
			icon.blinking = false;
		});
	}
	
	private void display_regexes() {
		model.clear();
		foreach(string regex in highlight_regexes) {
			Gtk.TreeIter iter;
			model.append(out iter);
			model.set(iter,0,regex,-1);
		}
	}
	
	private void regex_edited(string path,string new_text) {
		Gtk.TreeIter iter;
		string old_regex;
		if(model.get_iter_from_string(out iter,path)) {
			model.get(iter,0,out old_regex,-1);
			highlight_regexes[highlight_regexes.index_of(old_regex)] = new_text;
			display_regexes();
			save_settings();
		}
	}
	
	private void add_regex() {
		highlight_regexes.add("regex");
		display_regexes();
		save_settings();
	}
	
	private void remove_regex() {
		Gtk.TreeModel model;
		Gtk.TreeIter iter;
		Gtk.TreeSelection sel = tree.get_selection();
		string regex;
		if(sel.get_selected(out model,out iter)) {
			model.get(iter,0,out regex,-1);
			highlight_regexes.remove(regex);
			display_regexes();
			save_settings();
		}
	}
	
	private void load_settings() {
		KeyFile conf = new KeyFile();
		if(FileUtils.test(Environment.get_user_config_dir()+"/xsirc/highlights.conf",FileTest.EXISTS)) {
			try {
				conf.load_from_file(Environment.get_user_config_dir()+"/xsirc/highlights.conf",0);
				if(conf.has_key("XSIRC","highlight_on_nick")) {
					highlight_on_nick = conf.get_boolean("XSIRC","highlight_on_nick");
				}
				if(conf.has_key("XSIRC","highlight_on_notices")) {
					highlight_on_notices = conf.get_boolean("XSIRC","highlight_on_notices");
				}
				if(conf.has_key("XSIRC","highlight_on_pms")) {
					highlight_on_pms = conf.get_boolean("XSIRC","highlight_on_pms");
				}
				if(conf.has_key("XSIRC","highlight_on_all_privmsgs")) {
					highlight_on_all_privmsgs = conf.get_boolean("XSIRC","highlight_on_all_privmsgs");
				}
				if(conf.has_key("XSIRC","blink_on_taskbar")) {
					blink_on_taskbar = conf.get_boolean("XSIRC","blink_on_taskbar");
				}
				if(conf.has_key("XSIRC","blink_status_icon")) {
					blink_status_icon = conf.get_boolean("XSIRC","blink_status_icon");
				}
				if(conf.has_key("XSIRC","pop_up_libnotify")) {
					pop_up_libnotify = conf.get_boolean("XSIRC","pop_up_libnotify");
				}
				if(conf.has_key("XSIRC","add_to_server_view")) {
					add_to_server_view = conf.get_boolean("XSIRC","add_to_server_view");
				}
				for(int i = 0;conf.has_key("XSIRC","regex%d".printf(i));i++) {
					highlight_regexes.add(conf.get_string("XSIRC","regex%d".printf(i)));
				}
			} catch(Error e) {
				stderr.printf("Could not open highlights.conf\n");
			}
		}
	}
	
	private void save_settings() {
		KeyFile conf = new KeyFile();
		try {
			conf.set_boolean("XSIRC","highlight_on_nick",highlight_on_nick);
			conf.set_boolean("XSIRC","highlight_on_notices",highlight_on_notices);
			conf.set_boolean("XSIRC","highlight_on_pms",highlight_on_pms);
			conf.set_boolean("XSIRC","highlight_on_all_privmsgs",highlight_on_all_privmsgs);
			conf.set_boolean("XSIRC","blink_on_taskbar",blink_on_taskbar);
			conf.set_boolean("XSIRC","blink_status_icon",blink_status_icon);
			conf.set_boolean("XSIRC","pop_up_libnotify",pop_up_libnotify);
			conf.set_boolean("XSIRC","add_to_server_view",add_to_server_view);
			int i = 0;
			foreach(string regex in highlight_regexes) {
				conf.set_string("XSIRC","regex%d".printf(i),regex);
				i++;
			}
			FileUtils.set_contents(Environment.get_user_config_dir()+"/xsirc/highlights.conf",conf.to_data());
		} catch(Error e) {
			stderr.printf("Could not save highlights.conf\n");
		}
	}
	
	public override bool on_startup() {
#if !WINDOWS
		Notify.init("XSIRC");
#endif
		return true;
	}
	
	public override bool on_privmsg(XSIRC.Server server,string usernick,string username,string usermask,string target,string message) {
		if(highlight_on_all_privmsgs) {
			string my_message = message;
			string my_target = target.down() == server.nick.down() ? usernick : target;
			// Checking for ACTIONS
			if(my_message.has_prefix("\x01")) {
				my_message = my_message.replace("\x01","").substring(7);
				my_message = "%s * %s %s".printf(my_target,usernick,my_message);
			} else {
				my_message = "<%s:%s> %s".printf(my_target,usernick,my_message);
			}
			highlight(server.server+" - "+my_target,my_message);
			return true;
		}
		if(highlight_on_pms && target.down() == server.nick.down()) {
			string my_message = message;
			string my_target = target.down() == server.nick.down() ? usernick : target;
			// Checking for ACTIONS
			if(my_message.has_prefix("\x01")) {
				my_message = my_message.replace("\x01","").substring(7);
				my_message = "%s * %s %s".printf(my_target,usernick,my_message);
			} else {
				my_message = "<%s:%s> %s".printf(my_target,usernick,my_message);
			}
			if(add_to_server_view) {
				server.add_to_view(_("<server>"),my_message);
			}
			highlight(server.server+" - "+my_target,my_message);
			return true;
		}
		foreach(string pattern in highlight_regexes) {
			if(Regex.match_simple(pattern,message,RegexCompileFlags.CASELESS)) {
				string my_message = message;
				string my_target = target.down() == server.nick.down() ? usernick : target;
				// Checking for ACTIONS
				if(my_message.has_prefix("\x01")) {
					my_message = my_message.replace("\x01","").substring(7);
					my_message = "%s * %s %s".printf(my_target,usernick,my_message);
				} else {
					my_message = "<%s:%s> %s".printf(my_target,usernick,my_message);
				}
				if(add_to_server_view) {
					server.add_to_view(_("<server>"),my_message);
				}
				highlight(server.server+" - "+my_target,my_message);
				return true;
			}
		}
		if(highlight_on_nick && Regex.match_simple("\\b"+Regex.escape_string(server.nick)+"\\b",message,RegexCompileFlags.CASELESS)) {
			string my_message = message;
			string my_target = target.down() == server.nick.down() ? usernick : target;
			// Checking for ACTIONS
			if(my_message.has_prefix("\x01")) {
				my_message = my_message.replace("\x01","").substring(7);
				my_message = "%s * %s %s".printf(my_target,usernick,my_message);
			} else {
				my_message = "<%s:%s> %s".printf(my_target,usernick,my_message);
			}
			if(add_to_server_view) {
				server.add_to_view(_("<server>"),my_message);
			}
			highlight(server.server+" - "+my_target,my_message);
			return true;
		}
		return true;
	}
	
	public override bool on_notice(XSIRC.Server server,string usernick,string username,string usermask,string target,string message) {
		if(highlight_on_notices) {
			string my_message = message;
			string my_target = target.down() == server.nick.down() ? usernick : target;
			if(!my_message.has_prefix("\x01")) { // We don't really want to be highlighted on CTCP replies
				my_message = "-%s- %s".printf(usernick,my_message);
				highlight(server.server+" - "+my_target,my_message);
			}
		}
		return true;
	}
	
	private void highlight(string title,string content) {
		if(XSIRC.Main.gui.main_window.is_active) {
			return;
		}
		// Haven't figured out the API for Win32 balloons yet :/
		if(blink_status_icon) {
			icon.blinking = true;
		}
		if(blink_on_taskbar) {
			XSIRC.Main.gui.main_window.set_urgency_hint(true);
			TimeoutSource src = new TimeoutSource(5000);
			src.set_callback(() => {
				icon.blinking = false;
				XSIRC.Main.gui.main_window.set_urgency_hint(false);
				return true;
			});
			src.attach(null);
		}
		if(pop_up_libnotify) {
#if !WINDOWS
			Notify.Notification notification = new Notify.Notification(title,Markup.escape_text(content),PREFIX+"/share/pixmaps/xsirc.png",null);
			notification.set_timeout(5000);
			notification.set_urgency(Notify.Urgency.CRITICAL);
			try {
				notification.show();
			} catch(Error e) {
			
			}
#endif
		}
	}
}

[CCode (cname = "G_MODULE_EXPORT register_plugin")]
void register_plugin(Module module) {
	HighlightsPlugin plugin = new HighlightsPlugin();
	XSIRC.Main.plugin_manager.add_plugin(plugin);
}
