/*
 * gui.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class GUI : Object {
		public static const string link_regex = "([a-z]+://[a-zA-Z0-9\\-.]+(:[0-9]+)?(/[a-zA-Z0-9\\-_$.+\\[\\]!*\\(),;:@&=?/~#%]+){0,1})";
		// GUI proper
		public Gtk.Window main_window;
		public Gtk.TreeView user_list;
		public Gtk.Notebook servers_notebook;
		public Gtk.Label nickname_label;
		public Gtk.Entry text_entry;
		public Gtk.Entry topic_view;
		public Gtk.Statusbar status_bar;
		public View system_view;
		public bool destroyed = false;
		private Gtk.MenuItem[] views_menu = new Gtk.MenuItem[9];
		private const Gtk.ActionEntry[] menu_actions = {
			// Client
			{"ClientMenu",null,"_Client"},
			{"Connect",Gtk.STOCK_CONNECT,"_Connect...","<control><shift>O","Connect to a server.",connect_server_cb},
			{"DisconnectAll",Gtk.STOCK_DISCONNECT,"_Disconnect all",null,null,disconnect_all_cb},
			{"ReconnectAll",Gtk.STOCK_NETWORK,"_Reconnect all",null,null,reconnect_all_cb},
			{"OpenLastLink",null,"_Open last link","F2",null,open_last_link_cb},
			{"OpenSLastLink",null,"O_pen sec-to-last link","<control>F2",null,open_sl_link_cb},
			{"Exit",Gtk.STOCK_QUIT,null,null,null,quit_client_cb},
			// Settings
			{"SettingsMenu",null,"S_ettings"},
			{"Preferences",Gtk.STOCK_PREFERENCES,null,"<control><alt>P",null,spawn_preferences_cb},
			{"AdvancedMenu",null,"_Advanced"},
			{"MacroPreferences",null,"_Macros...",null,null,spawn_macro_preferences_cb},
			{"PluginPreferences",null,"_Plugins...",null,null,spawn_plugin_preferences_cb},
			// View
			{"ViewMenu",null,"_View"},
			{"PrevServer",Gtk.STOCK_GOTO_FIRST,"Previous server","<control><alt>comma",null,previous_server_cb},
			{"NextServer",Gtk.STOCK_GOTO_LAST,"Next server","<control><alt>period",null,next_server_cb},
			{"PrevView",Gtk.STOCK_GO_BACK,"Previous view","<control>comma",null,previous_view_cb},
			{"NextView",Gtk.STOCK_GO_FORWARD,"Next view","<control>period",null,next_view_cb},
			{"CloseView",Gtk.STOCK_CLOSE,"_Close view","<control>w",null,close_view_cb},
			{"RejoinChannel",null,"Re_join channel",null,null,rejoin_chan_cb},
			{"OpenView",Gtk.STOCK_OPEN,"_Open view...","<control>o",null,open_view_cb},
			{"View1",null,"View 1","<alt>1",null,change_view_cb},
			{"View2",null,"View 2","<alt>2",null,change_view_cb},
			{"View3",null,"View 3","<alt>3",null,change_view_cb},
			{"View4",null,"View 4","<alt>4",null,change_view_cb},
			{"View5",null,"View 5","<alt>5",null,change_view_cb},
			{"View6",null,"View 6","<alt>6",null,change_view_cb},
			{"View7",null,"View 7","<alt>7",null,change_view_cb},
			{"View8",null,"View 8","<alt>8",null,change_view_cb},
			{"View9",null,"View 9","<alt>9",null,change_view_cb},
			{"View10",null,"View 10","<alt>0",null,change_view_cb},
			// Server
			{"ServerMenu",null,"_Server"},
			{"Disconnect",Gtk.STOCK_DISCONNECT,"_Disconnect","<control><shift>d",null,disconnect_server_cb},
			{"Reconnect",Gtk.STOCK_CONNECT,"_Reconnect","<control><shift>r",null,reconnect_server_cb},
			{"CloseServer",Gtk.STOCK_CLOSE,"_Close","<control><shift>w",null,close_server_cb},
			{"RejoinAll",null,"Re_join all",null,null,rejoin_all_cb},
			{"GoAway",null,"_Mark as away","<control><shift>a",null,go_away_cb},
			// Help
			{"HelpMenu",null,"_Help"},
			{"HelpContents",Gtk.STOCK_HELP,"_Contents","F1",null,spawn_help_cb},
			{"About",Gtk.STOCK_ABOUT,null,null,null,spawn_about_cb}
		};
		private Gtk.UIManager ui_manager;
		private string ui_manager_xml = """
<ui>
	<menubar name="MainMenu">
		<menu action="ClientMenu">
			<menuitem action="Connect"/>
			<menuitem action="DisconnectAll"/>
			<menuitem action="ReconnectAll"/>
			<menuitem action="OpenLastLink"/>
			<menuitem action="OpenSLastLink"/>
			<separator/>
			<menuitem action="Exit"/>
		</menu>
		<menu action="ViewMenu">
			<menuitem action="PrevServer"/>
			<menuitem action="NextServer"/>
			<separator/>
			<menuitem action="PrevView"/>
			<menuitem action="NextView"/>
			<menuitem action="CloseView"/>
			<menuitem action="RejoinChannel"/>
			<menuitem action="OpenView"/>
			<separator/>
			<menuitem action="View1"/>
			<menuitem action="View2"/>
			<menuitem action="View3"/>
			<menuitem action="View4"/>
			<menuitem action="View5"/>
			<menuitem action="View6"/>
			<menuitem action="View7"/>
			<menuitem action="View8"/>
			<menuitem action="View9"/>
			<menuitem action="View10"/>
		</menu>
		<menu action="ServerMenu">
			<menuitem action="Disconnect"/>
			<menuitem action="Reconnect"/>
			<menuitem action="CloseServer"/>
			<menuitem action="RejoinAll"/>
			<separator/>
			<menuitem action="GoAway"/>
		</menu>
		<menu action="SettingsMenu">
			<menuitem action="Preferences"/>
			<menu action="AdvancedMenu">
				<menuitem action="MacroPreferences"/>
				<menuitem action="PluginPreferences"/>
			</menu>
		</menu>
		<menu action="HelpMenu">
			<menuitem action="HelpContents"/>
			<menuitem action="About"/>
		</menu>
	</menubar>
</ui>""";
		// Other stuff
		private LinkedList<string> command_history = new LinkedList<string>();
		private int command_history_index = 0;
		public Gtk.TextTagTable global_tag_table = new Gtk.TextTagTable();
		private bool gui_updated = true;
		private TabCompleter tab_completer = new TabCompleter();
		//private unowned Thread server_threads;
		public Mutex gui_mutex = new Mutex();
		private PrefWindow prefs_window;
		private MacroManager.PrefWindow macro_prefs_window;
		private PluginManager.PrefWindow plugin_prefs_window;
		
		public class View {
			public string name;
			public Gtk.ScrolledWindow scrolled_window;
			public Gtk.TextView text_view;
			public Gtk.Label label;
		}
		
		public GUI() {
			main_window = new Gtk.Window(Gtk.WindowType.TOPLEVEL);
			main_window.title = "XSIRC";
			main_window.set_default_size(640,320);
			main_window.delete_event.connect(quit);
			main_window.destroy.connect(()=>{destroyed=true;});
			
			Gtk.VBox main_vbox = new Gtk.VBox(false,0); // Main VBox, holds menubar + userlist, server notebook, entry field + status bar
			main_window.add(main_vbox);
			
			// Menus
			Gtk.ActionGroup action_group = new Gtk.ActionGroup("MenuActions");
			action_group.add_actions(menu_actions,null);
			ui_manager = new Gtk.UIManager();
			ui_manager.insert_action_group(action_group,0);
			main_window.add_accel_group(ui_manager.get_accel_group());
			try {
				ui_manager.add_ui_from_string(ui_manager_xml,-1);
			} catch(Error e) {
				Posix.exit(Posix.EXIT_FAILURE);
			}
			
			// Menu bar & children
			Gtk.MenuBar menu_bar = ui_manager.get_widget("/MainMenu") as Gtk.MenuBar;
			main_vbox.pack_start(menu_bar,false,true,0);
			
			// Topic text box
			topic_view = new Gtk.Entry();
			main_vbox.pack_start(topic_view,false,true,0);
			topic_view.activate.connect(() => {
				if(current_server() != null && current_server().current_view() != null && current_server().current_view().name.has_prefix("#")) {
					current_server().send("TOPIC %s :%s".printf(current_server().current_view().name,topic_view.text));
				}
			});
			
			// Main HBox, users, servers notebook
			Gtk.HPaned main_hbox = new Gtk.HPaned();
			main_vbox.pack_start(main_hbox,true,true,0);
			
			// User list
			user_list = new Gtk.TreeView.with_model(new Gtk.ListStore(1,typeof(string)));
			Gtk.ScrolledWindow user_list_container = new Gtk.ScrolledWindow(null,null);
			user_list_container.add(user_list);
			main_hbox.add1(user_list_container);
			
			Gtk.CellRendererText renderer = new Gtk.CellRendererText();
			Gtk.TreeViewColumn display_column = new Gtk.TreeViewColumn.with_attributes("Users",renderer,"text",0,null);
			user_list.append_column(display_column);
			
			// Quick VBox for server notebook+input
			var vbox = new Gtk.VBox(false,0);
			main_hbox.add2(vbox);
			
			// Server notebook
			
			servers_notebook = new Gtk.Notebook();
			servers_notebook.tab_pos = Gtk.PositionType.BOTTOM;
			vbox.pack_start(servers_notebook,true,true,0);
			
			// Creating tags.
			set_up_text_tags();
			
			// System view goes here.
			
			system_view = create_view("System");
			servers_notebook.append_page(system_view.scrolled_window,system_view.label);
			servers_notebook.show_all();
			// Input entry
			
			text_entry = new Gtk.Entry();
			//Gtk.ScrolledWindow te_scroll = new Gtk.ScrolledWindow(null,null);
			//te_scroll.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			//te_scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			//te_scroll.add(text_entry);
			vbox.pack_start(/*te_scroll*/text_entry,false,false,0);
			
			// Status bar
			status_bar = new Gtk.Statusbar();
			main_vbox.pack_start(status_bar,false,true,0);
			main_window.show_all();

			// Activate signal
			text_entry.activate.connect(() => {
				command_history.insert(0,text_entry.text);
				foreach(string text in text_entry.text.split("\n")) {
					parse_text(text);
				}
				text_entry.text = "";
			});
			// Command history, tab completion
			text_entry.key_press_event.connect((key) => {
				if(key.keyval == Gdk.keyval_from_name("Up")) {
					tab_completer.reset();
					command_history_index++;
					if((command_history.size - 1) >= command_history_index) {
						text_entry.text = command_history[command_history_index];
					}
					return true;
				} else if(key.keyval == Gdk.keyval_from_name("Down")) {
					tab_completer.reset();
					command_history_index--;
					if((command_history.size - 1) >= command_history_index && command_history_index > -1) {
						text_entry.text = command_history[command_history_index];
					}
					return true;
				} else if(key.keyval == Gdk.keyval_from_name("Tab")) {
					tab_completer.complete(current_server(),current_server().current_view(),text_entry);
					return true;
				} else {
					tab_completer.reset();
				}
				return false;
			});
			
			// Server-switching
			servers_notebook.switch_page.connect((nb_page,page_num) => {
				update_gui(find_server_by_notebook(get_notebook_widget_by_page((int)page_num)),null,true);
				text_entry.grab_focus();
			});
			
			// Servers thread
			
			//server_threads = Thread.create(thread_func,true);
			
			// Ready to go!
			text_entry.grab_focus();
			
			// Checking if it's a probable first run
			if(!Main.config_manager.loaded_config) {
				create_prefs_window();
			}
		
		}
		
		public void iterate() {
			while(Gtk.events_pending()) {
				Gtk.main_iteration();
			}
			if(!gui_updated) {
				update_gui(current_server());
				gui_updated = true;
			}
		}
		
		private void parse_text(string s) {
			//stdout.printf("Calling GUI.parse_text with argument \"%s\"\n",s);
			command_history_index = -1;
			if(s.has_prefix("//")) {
				// Send privmsg to current channel + /
				string sent = s.substring(1);
				if(current_server() != null && current_server().current_view() != null) {
					current_server().send("PRIVMSG %s :%s".printf(current_server().current_view().name,sent),(float)0.5,current_server().current_view().name);
				}
			} else if(s.has_prefix("/")) {
				// IRC command, with exactly two exceptions
				string sent = s.substring(1);
				if(current_server() != null && current_server().current_view() != null) {
					string result;
					if((result = Main.macro_manager.parse_string(sent)) != null) {
						current_server().send(result);
					} else {
						current_server().send(sent);
					}
				}
			} else {
				if(current_server() != null && current_server().current_view() != null && s.size() > 0) {
					current_server().send("PRIVMSG %s :%s".printf(current_server().current_view().name,s),(float)0.5,current_server().current_view().name);
					//current_server().add_to_view(current_server().current_view().name,"<%s> %s".printf(current_server().nick,s));
				}
			}
		}
		
		private bool quit() {
			// TODO
			return false;
		}
		
		/*private void* thread_func() {
			while(!destroyed) {
				foreach(Server server in servers) {
					server.iterate();
				}
				Posix.usleep(1);
			}
			return null;
		}*/
		
		private void set_up_text_tags() {
			string[] colors = {"white","black","dark blue","green","red","dark red","purple","brown","yellow","light green","cyan","light cyan","blue","pink","grey","light grey"};
			// Foregrounds
			foreach(string color in colors) {
				Gtk.TextTag tag = new Gtk.TextTag(color);
				tag.foreground = color;
				global_tag_table.add(tag);
			}
			// Backgrounds
			foreach(string color in colors) {
				Gtk.TextTag tag = new Gtk.TextTag("back "+color);
				tag.background = color;
				global_tag_table.add(tag);
			}
			// Bold, underlined, italics
			Gtk.TextTag bold = new Gtk.TextTag("bold");
			bold.weight = Pango.Weight.BOLD;
			Gtk.TextTag underlined = new Gtk.TextTag("underlined");
			underlined.underline = Pango.Underline.SINGLE;
			Gtk.TextTag italic = new Gtk.TextTag("italic");
			italic.style = Pango.Style.ITALIC;
			global_tag_table.add(bold);
			global_tag_table.add(underlined);
			global_tag_table.add(italic);
		}
		
		public void update_gui(Server? server,owned GUI.View? curr_view = null,bool force = false) {
			//gui_mutex.lock();
			if(server != null) {
				// Only servers in the foreground can update the GUI
				if(server != current_server() && !force) {
					return;
				}
				// User list
				if(curr_view == null) {
					curr_view = server.current_view();
				}
				Gtk.ListStore list = user_list.model as Gtk.ListStore;
				list.clear();
				if((curr_view != null) && (server.find_channel(curr_view.name) != null)) {
					Gtk.TreeIter iter;
					foreach(string user in server.find_channel(curr_view.name).raw_users) {
						list.append(out iter);
						list.set(iter,0,user,-1);
					}
				}
				StringBuilder title_string = new StringBuilder("XSIRC - ");
				title_string.append(server.nick).append("@");
				if(server.network != null) {
					title_string.append(server.network.name);
				} else {
					title_string.append(server.server);
				}
				if(!server.connected) {
					title_string.append(" (disconnected)");
				}
				if(server.current_view() != null) {
					title_string.append(" - ").append(curr_view.name);
					if(server.find_channel(curr_view.name) != null) {
						if(!server.find_channel(curr_view.name).in_channel) {
							title_string.append(" (kicked)");
						}
						title_string.append(" (").append(server.find_channel(curr_view.name).mode).append(")");
						topic_view.text = server.find_channel(curr_view.name).topic.content;
					} else {
						topic_view.text = "";
					}
				}
				// Updating the labels in the view menu
				for(int i = 1; i <= 10; i++) {
					Gtk.MenuItem item = ui_manager.get_widget("/MainMenu/ViewMenu/View%d".printf(i)) as Gtk.MenuItem;
					item.visible = false;
					if(current_server() != null) {
						if(current_server().notebook.get_n_pages() >= i) {
							item.label = current_server().find_view_from_scrolled_window(current_server().notebook.get_nth_page(i-1) as Gtk.ScrolledWindow).name;
							item.visible = true;
						}
					}
				}
				server.label.label = Markup.escape_text((server.network != null ? server.network.name+" - " : "")+server.server);
				main_window.title = title_string.str;
			} else {
				(user_list.model as Gtk.ListStore).clear();
				topic_view.text = "";
				main_window.title = "XSIRC - Idle";
			}
			//gui_mutex.unlock();
		}
		
		public void queue_update_gui() {
			gui_updated = false;
		}
		
		// View creation and adding-to
		
		public View create_view(string name) {
			Gtk.Label label = new Gtk.Label(Markup.escape_text(name));
			label.use_markup = true;
			Gtk.TextView text_view = new Gtk.TextView.with_buffer(new Gtk.TextBuffer(global_tag_table));
			text_view.editable = false;
			text_view.cursor_visible = false;
			text_view.wrap_mode = Gtk.WrapMode.WORD;
			text_view.modify_font(Pango.FontDescription.from_string(Main.config["core"]["font"]));
			
			Gtk.ScrolledWindow scrolled_window = new Gtk.ScrolledWindow(null,null);
			scrolled_window.vscrollbar_policy = Gtk.PolicyType.ALWAYS;
			scrolled_window.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			scrolled_window.add(text_view);
			
			View view = new View();
			view.name = name;
			view.scrolled_window = scrolled_window;
			view.text_view = text_view;
			view.label = label;
			return view;
		}
		
		public void add_to_view(View view,string what) {
			//gui_mutex.lock();
			string text = timestamp()+" "+what+"\n";
			// Parsing text
			MIRCParser parser = new MIRCParser(text);
			bool scrolled = (int)view.scrolled_window.vadjustment.value == (int)(view.scrolled_window.vadjustment.upper - view.scrolled_window.vadjustment.page_size);
			parser.insert(view.text_view);
			if(scrolled) {
				Gtk.TextIter scroll_iter;
				view.text_view.buffer.get_end_iter(out scroll_iter);
				view.text_view.scroll_to_mark(view.text_view.buffer.create_mark(null,scroll_iter,false),0,true,0,1);
			}
			//gui_mutex.unlock();
		}
		
		// Network and view finding stuff
		
		public Gtk.Widget? get_curr_notebook_widget() {
			foreach(Gtk.Widget child in servers_notebook.get_children()) {
				if(servers_notebook.page_num(child) == servers_notebook.page) {
					return child;
				}
			}
			return null;
		}
		
		private Gtk.Notebook? get_notebook_widget_by_page(int page_num) {
			foreach(Gtk.Widget child in servers_notebook.get_children()) {
				if(servers_notebook.page_num(child) == page_num) {
					return child as Gtk.Notebook;
				}
			}
			return null;
		}
		
		public Server? find_server_by_notebook(Gtk.Notebook? notebook) {
			foreach(Server server in Main.server_manager.servers) {
				if(server.notebook == notebook) {
					return server;
				}
			}
			return null;
		}
		
		public Server? current_server() {
			return find_server_by_notebook(get_curr_notebook_widget() as Gtk.Notebook);
		}
		
		public bool in_system_view() {
			return current_server() == null;
		}
		
		// Menu callbacks
		
		public static void connect_server_cb(Gtk.Action action) {
			Main.gui.open_connect_dialog();
		}
		
		public static void disconnect_all_cb(Gtk.Action action) {
			foreach(Server server in Main.server_manager.servers) {
				server.send("QUIT :%s".printf(Main.config["core"]["quit_msg"]));
			}
		}

		public static void reconnect_all_cb(Gtk.Action action) {
			foreach(Server server in Main.server_manager.servers) {
				server.irc_disconnect();
				try {
					server.irc_connect();
				} catch(Error e) {
					
				}
			}
		}
		
		public static void quit_client_cb(Gtk.Action action) {
			Main.gui.destroyed = true;
		}
		
		public static void spawn_preferences_cb(Gtk.Action action) {
			Main.gui.create_prefs_window();
		}
		
		public static void spawn_macro_preferences_cb(Gtk.Action action) {
			Main.gui.create_macro_prefs_window();
		}
		
		public static void spawn_plugin_preferences_cb(Gtk.Action action) {
			Main.gui.create_plugin_prefs_window();
		}
		
		public static void previous_server_cb(Gtk.Action action) {
			Main.gui.servers_notebook.prev_page();
		}
		
		public static void next_server_cb(Gtk.Action action) {
			Main.gui.servers_notebook.next_page();
		}
		
		public static void previous_view_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.notebook.prev_page();
			}
		}
		
		public static void next_view_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.notebook.next_page();
			}
		}
		
		public static void close_view_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.close_view();
			}
		}
		
		public static void rejoin_chan_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				GUI.View? view = server.current_view();
				if(view != null && view.name.has_prefix("#")) {
					server.send("PART %s".printf(view.name));
					server.send("JOIN %s".printf(view.name));
				}
			}
		}
		
		public static void open_view_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				Gtk.Dialog dialog = new Gtk.Dialog.with_buttons("Open view",Main.gui.main_window,Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,Gtk.STOCK_OK,Gtk.ResponseType.ACCEPT,Gtk.STOCK_CANCEL,Gtk.ResponseType.REJECT,null);
				Gtk.HBox box = new Gtk.HBox(false,0);
				box.pack_start(new Gtk.Label("View name:"),false,false,0);
				Gtk.Entry server_entry = new Gtk.Entry();
				server_entry.activate.connect(() => {
					dialog.response(Gtk.ResponseType.ACCEPT);
				});
				box.pack_start(server_entry,false,false,0);
				server_entry.grab_focus();
				dialog.vbox.pack_start(box,false,false,0);
				dialog.response.connect((id) => {
					if(id == Gtk.ResponseType.ACCEPT) {
						server.open_view(server_entry.text);
					}
					dialog.destroy();
				});
				dialog.show_all();
			}
		}
		
		public static void change_view_cb(Gtk.Action action) {
			int view_no = action.name.substring(4).to_int();
			view_no--;
			if(Main.gui.current_server() != null && Main.gui.current_server().notebook.get_n_pages() >= view_no) {
				Main.gui.current_server().notebook.page = view_no;
			}
		}
		
		public static void disconnect_server_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.send("QUIT :%s".printf(Main.config["core"]["quit_msg"]));
			}
		}
		
		public static void reconnect_server_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.irc_disconnect();
				try {
					server.irc_connect();
				} catch(Error e) {
					
				}
			}
		}
		
		public static void close_server_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.send("QUIT :%s".printf(Main.config["core"]["quit_msg"]));
				Main.server_manager.servers.remove(server);
				Main.gui.servers_notebook.remove_page(Main.gui.servers_notebook.page_num(server.notebook));
			}
		}
		
		public static void rejoin_all_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				foreach(Server.Channel channel in server.channels) {
					server.send("PART %s".printf(channel.title));
					server.send("JOIN %s".printf(channel.title));
				}
			}
		}
		
		public static void go_away_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				if(server.am_away) {
					server.send("AWAY");
				} else {
					server.send("AWAY :%s".printf(Main.config["core"]["away_msg"]));
				}
			}
		}
		
		public static void open_last_link_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				View? view;
				if((view = server.current_view()) != null) {
					string[] lines = view.text_view.buffer.text.split(" ");
					Regex regex = null;
					try {
						regex = new Regex(link_regex);
					} catch(RegexError e) {
						return;
					}
					for(int i = lines.length-1; i >= 0; i--) {
						MatchInfo info;
						if(!regex.match(lines[i],0,out info)) {
							//stderr.printf("Line doesn't match\n");
							continue;
						}
						try {
							Process.spawn_async(null,(Main.config["core"]["web_browser"]+" "+info.fetch(1)).split(" "),null,0,null,null);
						} catch(SpawnError e) {
							Gtk.MessageDialog d = new Gtk.MessageDialog(Main.gui.main_window,0,Gtk.MessageType.ERROR,Gtk.ButtonsType.OK,"Could not open web browser. Check your preferences.");
							d.response.connect(() => {d.destroy();});
							d.show_all();
						}
						break;
					}
				}
			}
		}
		
		public static void open_sl_link_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				View? view;
				if((view = server.current_view()) != null) {
					string[] lines = view.text_view.buffer.text.split(" ");
					Regex regex = null;
					try {
						regex = new Regex(link_regex);
					} catch(RegexError e) {
						return;
					}
					bool first_match = true;
					for(int i = lines.length-1; i >= 0; i--) {
						MatchInfo info;
						if(!regex.match(lines[i],0,out info)) {
							continue;
						}
						if(first_match) {
							first_match = false;
							continue;
						}
						try {
							Process.spawn_async(null,(Main.config["core"]["web_browser"]+" "+info.fetch(1)).split(" "),null,0,null,null);
						} catch(SpawnError e) {
							Gtk.MessageDialog d = new Gtk.MessageDialog(Main.gui.main_window,0,Gtk.MessageType.ERROR,Gtk.ButtonsType.OK,"Could not open web browser. Check your preferences.");
							d.response.connect(() => {d.destroy();});
							d.show_all();
						}
						break;
					}
				}
			}
		}
		
		public static void spawn_help_cb(Gtk.Action action) {
				try {
					Process.spawn_async(null,(Main.config["core"]["web_browser"]+" http://xsirc.niexs.net/manual.html").split(" "),null,0,null,null);
				} catch(SpawnError e) {
					Gtk.MessageDialog d = new Gtk.MessageDialog(Main.gui.main_window,0,Gtk.MessageType.ERROR,Gtk.ButtonsType.OK,"Could not open web browser. Check your preferences.");
					d.response.connect(() => {d.destroy();});
					d.show_all();
				}
		}
		
		public static void spawn_about_cb(Gtk.Action action) {
			Gtk.AboutDialog d = new Gtk.AboutDialog();
			d.authors = {"Eduardo Niehues (NieXS) <neo.niexs@gmail.com>"};
			d.copyright = "Copyright (c) 2010 Eduardo Niehues. All rights reserved.";
			d.license = """Copyright (c) 2010, Eduardo Niehues.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Eduardo Niehues nor the
      names of his contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL EDUARDO NIEHUES BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.""";
			try {
				d.logo = new Gdk.Pixbuf.from_file(PREFIX+"/share/pixmaps/xsirc.png");
			} catch(Error e) {
				
			}
			d.program_name = "XSIRC";
			d.comments = "GTK+ IRC Client";
			d.version      = VERSION;
			d.website      = "http://xsirc.niexs.net";
			d.response.connect(() => {d.destroy();});
			d.show_all();
		}
		// Dialogs
		public void open_connect_dialog() {
			//gui_mutex.lock();
			Gtk.Dialog dialog = new Gtk.Dialog.with_buttons("Connect to server",main_window,Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,Gtk.STOCK_OK,Gtk.ResponseType.ACCEPT,Gtk.STOCK_CANCEL,Gtk.ResponseType.REJECT,null);
			Gtk.HBox box = new Gtk.HBox(false,0);
			box.pack_start(new Gtk.Label("Server URL:"),false,false,0);
			Gtk.Entry server_entry = new Gtk.Entry();
			server_entry.text = "irc://";
			server_entry.activate.connect(() => {
				dialog.response(Gtk.ResponseType.ACCEPT);
			});
			box.pack_start(server_entry,false,false,0);
			server_entry.grab_focus();
			dialog.vbox.pack_start(box,false,false,0);
			dialog.response.connect((id) => {
				if(id == Gtk.ResponseType.ACCEPT) {
					// Checking for a valid pseudo-uri
					if(/^(irc|sirc):\/\/[a-zA-Z0-9-_.]+/.match(server_entry.text)) {
						string[] split_server_data = server_entry.text.split(":");
						bool ssl = split_server_data[0] == "ircs";
						string address = split_server_data[1].substring(2);
						int port = split_server_data[2] != null ? split_server_data[2].to_int() : 6667;
						Main.server_manager.open_server(address,port,ssl,server_entry.text.substring(server_entry.text.split(" ")[0].length));
						dialog.destroy();
					}
				} else {
					dialog.destroy();
				}
			});
			dialog.show_all();
			//gui_mutex.unlock();
		}
		
		public void create_prefs_window() {
			prefs_window = new PrefWindow();
		}
		
		public void destroy_prefs_window() {
			prefs_window = null;
		}
		
		public void create_macro_prefs_window() {
			macro_prefs_window = new MacroManager.PrefWindow();
		}
		
		public void destroy_macro_prefs_window() {
			macro_prefs_window = null;
		}
		
		public void create_plugin_prefs_window() {
			plugin_prefs_window = new PluginManager.PrefWindow();
		}
		
		public void destroy_plugin_prefs_window() {
			plugin_prefs_window = null;
		}
		// Misc
		
		public string timestamp() {
#if WINDOWS
			return localtime(time_t()).format(Main.config["core"]["timestamp_format"]);
#else
			return Time.local(time_t()).format(Main.config["core"]["timestamp_format"]);
#endif
		}
	}
}
