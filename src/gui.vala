/*
 * gui.vala
 *
 * Copyright (c) 2012 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class GUI : Object {
		public static const string link_regex = "([a-z]+://[a-zA-Z0-9\\-.]+(:[0-9]+)?(/[a-zA-Z0-9\\-_$.+\\[\\]!*\\(),;:@&=?/~#%]+)?)";
		// GUI proper
		public Gtk.Window main_window {get; private set;}
		public Gtk.TreeView user_list {get; private set;}
		public Gtk.Label user_count {get; private set;}
		public Gtk.Label nickname {get; private set;}
		private Gtk.VBox user_list_box;
		private Gtk.Label no_servers_warning = new Gtk.Label(_("No servers! Connect to a server using Ctrl-Shift-O, or open the network list with Ctrl-N."));
		public Gtk.Notebook servers_notebook {get; private set;}
		public Gtk.Label nickname_label {get; private set;}
		public IRCEntry text_entry {get; private set;}
		public Gtk.Entry topic_view {get; private set;}
		public HashMap<View.HighlightLevel,bool> highlight_level_enabled = new HashMap<View.HighlightLevel,bool>();
		public bool has_quit {get; private set;}
		private const Gtk.ActionEntry[] menu_actions = {
			// Client
			{"ClientMenu",null,N_("_Client")},
			{"Networks",Gtk.Stock.NETWORK,N_("Networks list"),"<control>N",null,open_network_list_cb},
			{"Connect",Gtk.Stock.CONNECT,N_("_Connect..."),"<control><shift>O",N_("Connect to a server."),connect_server_cb},
			{"DisconnectAll",Gtk.Stock.DISCONNECT,N_("_Disconnect all"),null,null,disconnect_all_cb},
			{"ReconnectAll",Gtk.Stock.NETWORK,N_("_Reconnect all"),null,null,reconnect_all_cb},
			{"OpenLastLink",null,N_("_Open last link"),"F2",null,open_last_link_cb},
			{"OpenSLastLink",null,N_("O_pen sec-to-last link"),"<control>F2",null,open_sl_link_cb},
			{"Exit",Gtk.Stock.QUIT,null,null,null,quit_client_cb},
			// Edit
			{"EditMenu",null,N_("_Edit")},
			{"Bold",Gtk.Stock.BOLD,null,"<control>B",null,bold_cb},
			{"Italic",Gtk.Stock.ITALIC,null,"<control>I",null,italic_cb},
			{"Underlined",Gtk.Stock.UNDERLINE,null,"<control>U",null,underlined_cb},
			{"Color",Gtk.Stock.COLOR_PICKER,N_("_Color"),"<control>K",null,color_cb},
			{"RemoveFormatting",Gtk.Stock.CLEAR,N_("_Remove formatting"),"<control>R",null,remove_cb},
			// Settings
			{"SettingsMenu",null,N_("Se_ttings")},
			{"Preferences",Gtk.Stock.PREFERENCES,null,"<control><alt>P",null,spawn_preferences_cb},
			// View
			{"ViewMenu",null,N_("_View")},
			{"PrevServer",Gtk.Stock.GOTO_FIRST,N_("Previous server"),"<control><alt>comma",null,previous_server_cb},
			{"NextServer",Gtk.Stock.GOTO_LAST,N_("Next server"),"<control><alt>period",null,next_server_cb},
			{"PrevView",Gtk.Stock.GO_BACK,N_("Previous view"),"<control>comma",null,previous_view_cb},
			{"NextView",Gtk.Stock.GO_FORWARD,N_("Next view"),"<control>period",null,next_view_cb},
			{"CloseView",Gtk.Stock.CLOSE,N_("_Close view"),"<control>w",null,close_view_cb},
			{"RejoinChannel",Gtk.Stock.REFRESH,N_("Re_join channel"),null,null,rejoin_chan_cb},
			{"OpenView",Gtk.Stock.OPEN,N_("_Open view..."),"<control>o",null,open_view_cb},
			// These names never see the light of day, so there's no need to translate them
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
			{"ServerMenu",null,N_("_Server")},
			{"Disconnect",Gtk.Stock.DISCONNECT,N_("_Disconnect"),"<control><shift>d",null,disconnect_server_cb},
			{"Reconnect",Gtk.Stock.CONNECT,N_("_Reconnect"),"<control><shift>r",null,reconnect_server_cb},
			{"CloseServer",Gtk.Stock.CLOSE,N_("_Close"),"<control><shift>w",null,close_server_cb},
			{"RejoinAll",Gtk.Stock.REFRESH,N_("Re_join all"),null,null,rejoin_all_cb},
			{"GoAway",null,N_("_Mark as away"),"<control><shift>a",null,go_away_cb},
			// Help
			{"HelpMenu",null,N_("_Help")},
			{"HelpContents",Gtk.Stock.HELP,N_("_Online help"),"F1",null,spawn_help_cb},
			{"About",Gtk.Stock.ABOUT,null,null,null,spawn_about_cb}
		};
		public Gtk.UIManager menu_ui {get; private set;}
		private string menu_ui_xml = """
<ui>
	<menubar name="MainMenu">
		<menu action="ClientMenu">
			<menuitem action="Networks"/>
			<menuitem action="Connect"/>
			<separator/>
			<menuitem action="DisconnectAll"/>
			<menuitem action="ReconnectAll"/>
			<separator/>
			<menuitem action="OpenLastLink"/>
			<menuitem action="OpenSLastLink"/>
			<separator/>
			<menuitem action="Exit"/>
		</menu>
		<menu action="EditMenu">
			<menuitem action="Bold"/>
			<menuitem action="Italic"/>
			<menuitem action="Underlined"/>
			<menuitem action="Color"/>
			<menuitem action="RemoveFormatting"/>
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
		</menu>
		<menu action="HelpMenu">
			<menuitem action="HelpContents"/>
			<menuitem action="About"/>
		</menu>
	</menubar>
</ui>""";
		private bool gui_updated = true;
		private PrefDialog preferences_dialog = null;
		private NetworkList network_dialog = null;
		private Gtk.VBox server_vbox;
		private Gtk.HBox main_hbox;
		private Gtk.ScrolledWindow user_list_container;
		
		public class View {
			public enum HighlightLevel {
				NONE,
				BORING,
				NORMAL,
				IMPORTANT
			}
			public string name;
			public Gtk.ScrolledWindow scrolled_window;
			public Gtk.TextView text_view;
			public Gtk.Label label;
			public HighlightLevel highlight_level;
			
			public View(string name) {
				this.name = name;
				
				highlight_level = HighlightLevel.NONE;
				
				label = new Gtk.Label(Markup.escape_text(name));
				label.use_markup = true;
				
				text_view = new Gtk.TextView();
				text_view.editable = false;
				text_view.cursor_visible = false;
				text_view.wrap_mode = Gtk.WrapMode.WORD;
				text_view.modify_font(Pango.FontDescription.from_string(Main.config.string["font"]));
				text_view.indent = -20;
				
				scrolled_window = new Gtk.ScrolledWindow(null,null);
				scrolled_window.vscrollbar_policy = Gtk.PolicyType.ALWAYS;
				scrolled_window.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
				scrolled_window.add(text_view);
			}
			
			public void add_text(string what) {
				string text;
				if(Main.config.bool["show_timestamps"]) {
					text = Main.gui.timestamp() + " "+what+"\n";
				} else {
					text = what+"\n";
				}
				MIRCParser parser = new MIRCParser(text);
				bool scrolled = (int)scrolled_window.vadjustment.value == (int)(scrolled_window.vadjustment.upper -
				                                                                scrolled_window.vadjustment.page_size);
				parser.insert(text_view);
				if(scrolled) {
					Gtk.TextIter iter;
					text_view.buffer.get_end_iter(out iter);
					text_view.scroll_to_mark(text_view.buffer.create_mark(null,iter,false),0,true,0,1);
				}
			}
		}
		
		public GUI() {
			main_window = new Gtk.Window(Gtk.WindowType.TOPLEVEL);
			main_window.title = "XSIRC";
			main_window.set_default_size(640,320);
			main_window.delete_event.connect(quit);
			main_window.destroy.connect(()=>{Gtk.main_quit();});
			
			Gtk.VBox main_vbox = new Gtk.VBox(false,0); // Main VBox, holds menubar + userlist, server notebook, entry field + status bar
			main_window.add(main_vbox);
			
			// Menus
			Gtk.ActionGroup action_group = new Gtk.ActionGroup("MenuActions");

			// This makes translations work, at the expense of a warning. I'm
			// not sure what the proper way of doing this is.
			action_group.set_translation_domain(null);

			action_group.add_actions(menu_actions,null);
			menu_ui = new Gtk.UIManager();
			menu_ui.insert_action_group(action_group,0);
			main_window.add_accel_group(menu_ui.get_accel_group());
			try {
				menu_ui.add_ui_from_string(menu_ui_xml,-1);
			} catch(Error e) {
				stderr.printf("menu_ui.add_ui_from_string failed!\n");
				Posix.exit(Posix.EXIT_FAILURE);
			}
			
			// Menu bar & children
			Gtk.MenuBar menu_bar = menu_ui.get_widget("/MainMenu") as Gtk.MenuBar;
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
			main_hbox = new Gtk.HBox(false,5);
			main_vbox.pack_start(main_hbox,true,true,0);
			
			// User list
			user_list_box = new Gtk.VBox(false,0);
			user_count = new Gtk.Label(Markup.escape_text(_("No users")));
			user_count.use_markup = true;
			user_list_box.pack_start(user_count,false,false,5);
			user_list = new Gtk.TreeView.with_model(new Gtk.ListStore(1,typeof(string)));
			user_list.headers_visible = false;
			user_list_container = new Gtk.ScrolledWindow(null,null);
			user_list_container.add(user_list);
			user_list_container.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			user_list_container.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			user_list_container.set_size_request(120,-1);
			user_list_box.pack_start(user_list_container,true,true,0);
			main_hbox.pack_start(user_list_box,false,true,0);
			
			Gtk.CellRendererText renderer = new Gtk.CellRendererText();
			Gtk.TreeViewColumn display_column = new Gtk.TreeViewColumn.with_attributes(_("Users"),renderer,"text",0,null);
			user_list.append_column(display_column);
			
			// Quick VBox for server notebook+input
			server_vbox = new Gtk.VBox(false,0);
			main_hbox.pack_start(server_vbox,true,true,0);
			
			// Server notebook
			
			servers_notebook = new Gtk.Notebook();
			switch(Main.config.string["tab_pos"]) {
				case "top":
					servers_notebook.tab_pos = Gtk.PositionType.TOP;
					break;
				case "left":
					servers_notebook.tab_pos = Gtk.PositionType.LEFT;
					break;
				case "right":
					servers_notebook.tab_pos = Gtk.PositionType.RIGHT;
					break;
				default:
					servers_notebook.tab_pos = Gtk.PositionType.BOTTOM;
					break;
			}
			server_vbox.pack_start(servers_notebook,true,true,0);
			server_vbox.pack_start(no_servers_warning,false,false,5);
			
			// Input entry
			Gtk.HBox entry_box = new Gtk.HBox(false,0);
			nickname = new Gtk.Label(Main.config.string["nickname"]);
			entry_box.pack_start(nickname,false,false,5);
			text_entry = new IRCEntry();
			entry_box.pack_start(text_entry,true,true,0);
			server_vbox.pack_start(entry_box,false,false,0);
			
			
			// Server-switching
			servers_notebook.switch_page.connect((nb_page,page_num) => {
				update_gui(find_server_by_notebook(get_notebook_widget_by_page((int)page_num)),null,true);
			});
			servers_notebook.page_added.connect(() => {
				no_servers_warning.visible = false;
			});
			servers_notebook.page_removed.connect(() => {
				if(servers_notebook.get_n_pages() == 0) {
					no_servers_warning.visible = true;
				}
			});
			
			main_window.show_all();
			
			TimeoutSource src = new TimeoutSource(100);
			src.set_callback(() => {
				if(!gui_updated) {
					update_gui(current_server());
					gui_updated = true;
				}
				return true;
			});
			src.attach(null);
			
			// GUI settings
			apply_settings();
			
			// Ready to go!
			text_entry.grab_focus();
			
			// Checking if it's a probable first run
			if(!Main.config_manager.loaded_config) {
				create_prefs_dialog();
			}
		
		}
		
		public void startup() {
			
		}
		
		public void apply_settings() {
			if(!Main.config.bool["show_user_list"]) {
				user_list_box.visible = false;
			} else {
				user_list_box.visible = true;
			}
			main_hbox.remove(user_list_box);
			main_hbox.remove(server_vbox);
			if(Main.config.string["userlist_pos"] == "left") {
				main_hbox.pack_start(user_list_box,false,true,0);
				main_hbox.pack_start(server_vbox,true,true,0);
			} else {
				main_hbox.pack_start(server_vbox,true,true,0);
				main_hbox.pack_start(user_list_box,false,true,0);
			}
			
			if(!Main.config.bool["show_topic_bar"]) {
				((Gtk.Widget)topic_view).visible = false;
			} else {
				((Gtk.Widget)topic_view).visible = true;
			}
			
			switch(Main.config.string["tab_pos"]) {
				case "top":
					servers_notebook.tab_pos = Gtk.PositionType.TOP;
					foreach(Server server in Main.server_manager.servers) {
						server.notebook.tab_pos = Gtk.PositionType.TOP;
					}
					break;
				case "left":
					servers_notebook.tab_pos = Gtk.PositionType.LEFT;
					foreach(Server server in Main.server_manager.servers) {
						server.notebook.tab_pos = Gtk.PositionType.LEFT;
					}
					break;
				case "right":
					servers_notebook.tab_pos = Gtk.PositionType.RIGHT;
					foreach(Server server in Main.server_manager.servers) {
						server.notebook.tab_pos = Gtk.PositionType.RIGHT;
					}
					break;
				default:
					servers_notebook.tab_pos = Gtk.PositionType.BOTTOM;
					foreach(Server server in Main.server_manager.servers) {
						server.notebook.tab_pos = Gtk.PositionType.BOTTOM;
					}
					break;
			}
			highlight_level_enabled[View.HighlightLevel.BORING] = true;
			highlight_level_enabled[View.HighlightLevel.NORMAL] = true;
			highlight_level_enabled[View.HighlightLevel.IMPORTANT] = true;
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
		
		public void parse_text(string s) {
			stdout.printf("Calling GUI.parse_text with argument \"%s\"\n",s);
			if(s.has_prefix("//")) {
				// Send privmsg to current channel + /
				string sent = s.substring(1);
				if(current_server() != null && current_server().current_view() != null) {
					current_server().send("PRIVMSG %s :%s".printf(current_server().current_view().name,sent),(float)0.5,current_server().current_view().name);
				}
			} else if(s.has_prefix("/")) {
				// IRC command
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
				if(current_server() != null && current_server().current_view() != null && s.length > 0) {
					current_server().send("PRIVMSG %s :%s".printf(current_server().current_view().name,s),(float)0.5,current_server().current_view().name);
				}
			}
		}
		
		private bool quit() {
			bool q = false;
			int connected_networks = 0;
			foreach(Server server in Main.server_manager.servers) {
				if(server.connected && !server.sock_error) {
					connected_networks++;
				}
			}
			if(connected_networks > 0) {
				// l10n: The %d is the number of networks, %s is either "network" (singular) or "networks" (plural)
				Gtk.MessageDialog d = new Gtk.MessageDialog(main_window,Gtk.DialogFlags.MODAL,Gtk.MessageType.QUESTION,Gtk.ButtonsType.YES_NO,_("Really quit? You are connected to %d IRC %s."),connected_networks,(connected_networks > 1 ? _("networks") : _("network")));
				d.response.connect((id) => {
					if(id != Gtk.ResponseType.YES) {
						q = true;
					}
					d.destroy();
				});
				d.run();
			}
			if(!q) {
				has_quit = true;
			}
			return q;
		}
		
		public void update_gui(Server? server,owned GUI.View? curr_view = null,bool force = false) {
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
				nickname.label = server.nick;
				StringBuilder title_string = new StringBuilder("XSIRC - ");
				title_string.append(server.nick).append("@");
				if(server.network != null) {
					title_string.append(server.network.name);
				} else {
					title_string.append(server.server);
				}
				if(server.connecting) {
					title_string.append(_(" (connecting)"));
				} else if(!server.connected) {
					title_string.append(_(" (disconnected)"));
				}
				if(server.current_view() != null) {
					title_string.append(" - ").append(curr_view.name);
					if(server.find_channel(curr_view.name) != null) {
						if(!server.find_channel(curr_view.name).in_channel) {
							title_string.append(_(" (out of channel)"));
						}
						title_string.append(" (").append(server.find_channel(curr_view.name).mode).append(")");
						title_string.append(_(" (%d users)").printf(server.find_channel(curr_view.name).users.size));
						user_count.label = Markup.escape_text(_("%d users").printf(server.find_channel(curr_view.name).users.size));
						topic_view.text = server.find_channel(curr_view.name).topic.content;
					} else {
						user_count.label = Markup.escape_text(_("No users"));
						topic_view.text = "";
					}
				}
				// Updating the labels in the view menu
				for(int i = 1; i <= 10; i++) {
					Gtk.MenuItem item = menu_ui.get_widget("/MainMenu/ViewMenu/View%d".printf(i)) as Gtk.MenuItem;
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
				nickname.label = Main.config.string["nickname"];
				main_window.title = _("XSIRC - Idle");
				// Hiding the view shortcuts
				for(int i = 1; i <= 10; i++) {
					Gtk.MenuItem item = menu_ui.get_widget("/MainMenu/ViewMenu/View%d".printf(i)) as Gtk.MenuItem;
					item.visible = false;
				}
			}
			// Updating labels
			foreach(Server server_ in Main.server_manager.servers) {
				if(!server_.connected) {
					if(current_server() != server_ && server_.label.label.has_prefix("<span")) {
						string color = server_.label.label.split("\"")[1];
						server_.label.label = "<span foreground=\"%s\">(%s)</span>".printf(color,Markup.escape_text((server_.network != null ? server_.network.name+" - " : "")+server_.server));
					} else {
						server_.label.label = "(%s)".printf(Markup.escape_text((server_.network != null ? server_.network.name+" - " : "")+server_.server));
					}
				} else {
					if(current_server() != server_ && server_.label.label.has_prefix("<span")) {
						string color = server_.label.label.split("\"")[1];
						server_.label.label = "<span foreground=\"%s\">%s</span>".printf(color,Markup.escape_text((server_.network != null ? server_.network.name+" - " : "")+server_.server));
					} else {
						server_.label.label = "%s".printf(Markup.escape_text((server_.network != null ? server_.network.name+" - " : "")+server_.server));
					}
				}
				foreach(Server.Channel channel in server_.channels) {
					View view = server_.find_view(channel.name);
					if(!channel.in_channel) {
						if(server_.current_view() != view && view.label.label.has_prefix("<span")) {
							string color = view.label.label.split("\"")[1];
							view.label.label = "<span foreground=\"%s\">(%s)</span>".printf(color,Markup.escape_text(channel.name));
						} else {
							view.label.label = "(%s)".printf(Markup.escape_text(channel.name));
						}
					} else {
						if(server_.current_view() != view && view.label.label.has_prefix("<span")) {
							string color = view.label.label.split("\"")[1];
							view.label.label = "<span foreground=\"%s\">%s</span>".printf(color,Markup.escape_text(channel.name));
						} else {
							view.label.label = "%s".printf(Markup.escape_text(channel.name));
						}
					}
				}
			}
		}
		
		public void queue_update_gui() {
			gui_updated = false;
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
		
		public static void open_network_list_cb(Gtk.Action action) {
			Main.gui.create_network_dialog();
		}
		
		public static void connect_server_cb(Gtk.Action action) {
			Main.gui.open_connect_dialog();
		}
		
		public static void disconnect_all_cb(Gtk.Action action) {
			foreach(Server server in Main.server_manager.servers) {
				server.send_quit_message();
			}
		}

		public static void reconnect_all_cb(Gtk.Action action) {
			foreach(Server server in Main.server_manager.servers) {
				server.irc_disconnect();
				server.irc_connect();
			}
		}
		
		public static void quit_client_cb(Gtk.Action action) {
			Gtk.main_quit();
		}
		
		public static void bold_cb(Gtk.Action action) {
			Main.gui.text_entry.insert_bold();
		}
		
		public static void italic_cb(Gtk.Action action) {
			Main.gui.text_entry.insert_italic();
		}
		
		public static void underlined_cb(Gtk.Action action) {
			Main.gui.text_entry.insert_underlined();
		}
		
		public static void color_cb(Gtk.Action action) {
			Main.gui.text_entry.insert_color();
		}
		
		public static void remove_cb(Gtk.Action action) {
			Main.gui.text_entry.insert_remove();
		}
		
		public static void spawn_preferences_cb(Gtk.Action action) {
			Main.gui.create_prefs_dialog();
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
				Gtk.Dialog dialog = new Gtk.Dialog.with_buttons(_("Open view"),Main.gui.main_window,Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,Gtk.Stock.OK,Gtk.ResponseType.ACCEPT,Gtk.Stock.CANCEL,Gtk.ResponseType.REJECT,null);
				dialog.key_press_event.connect((key) => {
					if(key.keyval == Gdk.keyval_from_name("Escape")) {
						dialog.destroy();
						return true;
					}
					return false;
				});
				Gtk.HBox box = new Gtk.HBox(false,0);
				box.pack_start(new Gtk.Label(_("View name:")),false,false,0);
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
			int view_no = int.parse(action.name.substring(4));
			view_no--;
			if(Main.gui.current_server() != null && Main.gui.current_server().notebook.get_n_pages() >= view_no) {
				Main.gui.current_server().notebook.page = view_no;
			}
		}
		
		public static void disconnect_server_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.send_quit_message();
			}
		}
		
		public static void reconnect_server_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.irc_disconnect();
				server.irc_connect();
			}
		}
		
		public static void close_server_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				server.send_quit_message();
				Main.server_manager.servers.remove(server);
				Main.gui.servers_notebook.remove_page(Main.gui.servers_notebook.page_num(server.notebook));
			}
		}
		
		public static void rejoin_all_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				foreach(Server.Channel channel in server.channels) {
					server.send("PART %s".printf(channel.name));
					server.send("JOIN %s".printf(channel.name));
				}
			}
		}
		
		public static void go_away_cb(Gtk.Action action) {
			Server server;
			if((server = Main.gui.current_server()) != null) {
				if(server.am_away) {
					server.send("AWAY");
				} else {
					server.send("AWAY :%s".printf(Main.config.string["away_msg"]));
				}
			}
		}
		
		public static void open_nth_last_link(int n) {
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
					int matches = 0;
					for(int i = lines.length-1; i >= 0; i--) {
						MatchInfo info;
						if(!regex.match(lines[i],0,out info)) {
							continue;
						}
						if (matches < n) {
							++matches;
							continue;
						}
						Main.gui.open_link(info.fetch(1));
						break;
					}
				}
			}
		}
		
		public static void open_last_link_cb(Gtk.Action action) {
			open_nth_last_link(0);
		}

		public static void open_sl_link_cb(Gtk.Action action) {
			open_nth_last_link(1);
		}
		
		public static void spawn_help_cb(Gtk.Action action) {
			Main.gui.open_link("http://xsirc.niexs.net/manual.html");
		}
		
		public static void spawn_about_cb(Gtk.Action action) {
			Gtk.AboutDialog.set_url_hook((Gtk.AboutDialogActivateLinkFunc)open_browser);
			Gtk.AboutDialog d = new Gtk.AboutDialog();
			d.authors = {"Eduardo Niehues (NieXS) <neo.niexs@gmail.com>","Simon Lindholm (operator[]) <simon.lindholm10@gmail.com>"};
			d.artists = {"MonkeyofDoom (found in Foonetic and xkcd fora)"};
			d.copyright = _("Copyright (c) 2010-12 Eduardo Niehues. All rights reserved.");
			d.license = """Copyright (c) 2010-12, Eduardo Niehues.
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
				d.logo = new Gdk.Pixbuf.from_file(get_icon_path());
			} catch(Error e) {
				
			}
			d.program_name = "XSIRC";
			d.comments = _("GTK+ IRC Client");
			d.version      = VERSION;
			d.website      = "http://xsirc.niexs.net";
			d.response.connect(() => {d.destroy();});
			d.show_all();
		}
		
		// Link opener for the about dialog
		public static void open_browser(Gtk.AboutDialog dialog,string link) {
			Main.gui.open_link(link);
		}
		// Dialogs
		public void open_connect_dialog() {
			Gtk.Dialog dialog = new Gtk.Dialog.with_buttons(_("Connect to server"),main_window,Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,Gtk.Stock.OK,Gtk.ResponseType.ACCEPT,Gtk.Stock.CANCEL,Gtk.ResponseType.REJECT,null);
			Gtk.HBox box = new Gtk.HBox(false,0);
			box.pack_start(new Gtk.Label(_("Server URL:")),false,false,0);
			Gtk.Entry server_entry = new Gtk.Entry();
			server_entry.text = "irc://";
			server_entry.activate.connect(() => {
				dialog.response(Gtk.ResponseType.ACCEPT);
			});
			dialog.key_press_event.connect((key) => {
				if(key.keyval == Gdk.keyval_from_name("Escape")) {
					dialog.destroy();
					return true;
				}
				return false;
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
						int port = split_server_data[2] != null ? int.parse(split_server_data[2]) : 6667;
						Main.server_manager.open_server(address,port,ssl,server_entry.text.substring(server_entry.text.split(" ")[0].length));
						dialog.destroy();
					}
				} else {
					dialog.destroy();
				}
			});
			dialog.show_all();
		}
		
		public void create_prefs_dialog() {
			if(preferences_dialog != null) {
				preferences_dialog.dialog.present();
			} else {
				preferences_dialog = new PrefDialog();
			}
		}
		
		public void destroy_prefs_dialog() {
			preferences_dialog = null;
		}
		
		public void create_network_dialog() {
			if(network_dialog != null) {
				network_dialog.dialog.present();
			} else {
				network_dialog = new NetworkList();
			}
		}
		
		public void destroy_network_dialog() {
			network_dialog = null;
		}
		
		// Misc
		
		public void open_link(string link) {
#if WINDOWS
			open_url_in_browser(link);
#else
			try {
				Process.spawn_command_line_async(Main.config.string["web_browser"].printf(link));
			} catch(SpawnError e) {
				Gtk.MessageDialog d = new Gtk.MessageDialog(Main.gui.main_window,0,Gtk.MessageType.ERROR,Gtk.ButtonsType.OK,"%s",_("Could not open web browser. Check your preferences."));
				d.response.connect(() => {d.destroy();});
				d.show_all();
			}
#endif
		}

		public string timestamp() {
			return gen_timestamp(Main.config.string["timestamp_format"],time_t());
		}
	}

	public static string get_file_path(string category, string file) {
#if WINDOWS
		return "resources\\" + file;
#else
		string ret = PREFIX;
		if (category == "pixmap") {
			ret = ret + "/share/pixmaps";
		} else if (category == "share") {
			ret = ret + "/share/xsirc";
		} else {
			assert_not_reached();
		}
		return ret + "/" + file;
#endif
	}

	public static string get_icon_path() {
		return get_file_path("pixmap", "xsirc.png");
	}
}
