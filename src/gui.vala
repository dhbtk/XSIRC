using Gee;
namespace XSIRC {
	public class GUI {
		// GUI proper
		public Gtk.Window main_window;
		public Gtk.TreeView user_list;
		public Gtk.Notebook servers_notebook;
		public Gtk.Label nickname_label;
		public Gtk.TextView text_entry;
		public Gtk.Entry topic_view;
		public Gtk.Statusbar status_bar;
		public View system_view;
		private bool destroyed = false;
		private const Gtk.ActionEntry[] menu_actions = {
			// Client
			{"ClientMenu",null,"_Client"},
			{"Connect",null,"_Connect...","<control><shift>O","Connect to a server.",connect_server_cb},
			{"DisconnectAll",null,"_Disconnect all"},
			{"ReconnectAll",null,"_Reconnect all"},
			{"OpenLastLink",null,"_Open last link"},
			{"DebugMenu",null,"_Debug"},
			{"FailAssertion",null,"_Fail assertion"},
			{"ThrowException",null,"_Throw exception"},
			{"ShowLog",null,"Show _log"},
			{"Exit",Gtk.STOCK_QUIT},
			// Edit
			{"EditMenu",null,"_Edit"},
			{"Cut",Gtk.STOCK_CUT},
			{"Copy",Gtk.STOCK_COPY},
			{"Paste",Gtk.STOCK_PASTE},
			{"Preferences",Gtk.STOCK_PREFERENCES,null,"<control><alt>P"},
			// View
			{"ViewMenu",null,"_View"},
			{"PrevServer",null,"Previous server","<control><shift>comma"},
			{"NextServer",null,"Next server","<control><shift>period"},
			{"PrevView",null,"Previous view","<control>comma"},
			{"NextView",null,"Next view","<control>period"},
			{"CloseView",null,"_Close view","<control>w"},
			{"RejoinChannel",null,"Re_join channel"},
			{"OpenView",null,"_Open view...","<control>o"},
			// Server
			{"ServerMenu",null,"_Server"},
			{"Disconnect",null,"_Disconnect","<control><shift>d"},
			{"Reconnect",null,"_Reconnect","<control><shift>r"},
			{"CloseServer",null,"_Close","<control><shift>w"},
			{"RejoinAll",null,"Re_join all"},
			{"GoAway",null,"_Mark as away","<control><shift>a"},
			// Help
			{"HelpMenu",null,"_Help"},
			{"HelpContents",null,"_Contents"},
			{"About",null,"_About"}
		};
		private string ui_manager_xml = """
<ui>
	<menubar name="MainMenu">
		<menu action="ClientMenu">
			<menuitem action="Connect"/>
			<menuitem action="DisconnectAll"/>
			<menuitem action="ReconnectAll"/>
			<menuitem action="OpenLastLink"/>
			<separator/>
			<menu action="DebugMenu">
				<menuitem action="FailAssertion"/>
				<menuitem action="ThrowException"/>
				<menuitem action="ShowLog"/>
			</menu>
			<separator/>
			<menuitem action="Exit"/>
		</menu>
		<menu action="EditMenu">
			<menuitem action="Cut"/>
			<menuitem action="Copy"/>
			<menuitem action="Paste"/>
			<separator/>
			<menuitem action="Preferences"/>
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
		</menu>
		<menu action="ServerMenu">
			<menuitem action="Disconnect"/>
			<menuitem action="Reconnect"/>
			<menuitem action="CloseServer"/>
			<menuitem action="RejoinAll"/>
			<separator/>
			<menuitem action="GoAway"/>
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
		public ArrayList<Server> servers = new ArrayList<Server>();
		public Gtk.TextTagTable global_tag_table = new Gtk.TextTagTable();
		
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
			Gtk.UIManager ui_manager = new Gtk.UIManager();
			ui_manager.insert_action_group(action_group,0);
			main_window.add_accel_group(ui_manager.get_accel_group());
			ui_manager.add_ui_from_string(ui_manager_xml,-1);		
			
			// Menu bar & children
			Gtk.MenuBar menu_bar = ui_manager.get_widget("/MainMenu") as Gtk.MenuBar;
			main_vbox.pack_start(menu_bar,false,true,0);
			
			// Topic text box
			topic_view = new Gtk.Entry();
			main_vbox.pack_start(topic_view,false,true,0);
			
			// Main HBox, users, servers notebook
			Gtk.HBox main_hbox = new Gtk.HBox(false,0);
			main_vbox.pack_start(main_hbox,true,true,0);
			
			// User list
			user_list = new Gtk.TreeView.with_model(new Gtk.ListStore(1,typeof(string)));
			Gtk.ScrolledWindow user_list_container = new Gtk.ScrolledWindow(null,null);
			user_list_container.add(user_list);
			main_hbox.pack_start(user_list_container,false,true,0);
			
			Gtk.CellRendererText renderer = new Gtk.CellRendererText();
			Gtk.TreeViewColumn display_column = new Gtk.TreeViewColumn.with_attributes("Users",renderer,"text",0,null);
			user_list.append_column(display_column);
			
			// Quick VBox for server notebook+input
			var vbox = new Gtk.VBox(false,0);
			main_hbox.pack_start(vbox,true,true,5);
			
			// Server notebook
			
			servers_notebook = new Gtk.Notebook();
			vbox.pack_start(servers_notebook,true,true,0);
			
			// Creating tags.
			set_up_text_tags();
			
			// System view goes here.
			
			system_view = create_view("System");
			servers_notebook.append_page(system_view.scrolled_window,system_view.label);
			servers_notebook.show_all();
			// Input entry
			
			text_entry = new Gtk.TextView();
			text_entry.accepts_tab = true;
			//text_entry.buffer.text = "test";
			vbox.pack_start(text_entry,false,true,0);
			
			// Status bar
			status_bar = new Gtk.Statusbar();
			main_vbox.pack_start(status_bar,false,true,0);
			main_window.show_all();

			// Activate signal
			text_entry.buffer.changed.connect(() => {
				if(text_entry.buffer.text.contains("\n")) {
					string text = text_entry.buffer.text.replace("\n","");
					parse_text(text);
					text_entry.buffer.text = "";
				}
			});
			// Server-switching
			servers_notebook.switch_page.connect((nb_page,page_num) => {
				update_gui(find_server_by_notebook(get_notebook_widget_by_page((int)page_num)));
			});
			
			// Ready to go!
			text_entry.grab_focus();
		
		}
		
		private void parse_text(string s) {
			//stdout.printf("Calling GUI.parse_text with argument \"%s\"\n",s);
			if(s.has_prefix("//")) {
				// Send privmsg to current channel + /
				string sent = s.substring(1);
				if(curr_server() != null && curr_server().current_view() != null) {
					curr_server().send("PRIVMSG %s :%s".printf(curr_server().current_view().name,sent));
					curr_server().add_to_view(curr_server().current_view().name,s);
				}
			} /*else if(s.has_prefix("//")) {
				// Client command
				string sent = s.substring(2).strip();
				print("\""+sent+"\"\n");
				string[] split = sent.split(" ");
				string cmd = split[0];
				sent = sent.substring(cmd.length);
				switch(cmd) {
					case "connect":
						open_server(split[1]);
						break;
					default:
						break;
				}
			}*/ else if(s.has_prefix("/")) {
				// IRC command, with exactly two exceptions
				string sent = s.substring(1);
				if(curr_server() != null && curr_server().current_view() != null) {
					curr_server().send(sent);
				}
			} else {
				if(curr_server() != null && curr_server().current_view() != null && s.size() > 0) {
					curr_server().send("PRIVMSG %s :%s".printf(curr_server().current_view().name,s));
					curr_server().add_to_view(curr_server().current_view().name,"<%s> %s".printf(curr_server().nick,s));
				}
			}
		}
		
		private bool quit() {
			// TODO
			return false;
		}
		
		public void main_loop() {
			Main.server_manager.startup();
			while(!destroyed) {
				while(Gtk.events_pending()) {
					Gtk.main_iteration();
				}
				foreach(Server server in servers) {
					server.iterate();
				}
				Posix.usleep(10);
			}
		}
		
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
		
		public void update_gui(Server? server,owned GUI.View? curr_view = null) {
			if(server != null) {
				// Only servers in the foreground can update the GUI
				if(server != curr_server()) {
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
						list.insert_with_values(out iter,0,0,user,-1);
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
							title_string.append(" (kicked) ");
							title_string.append("(").append(server.find_channel(curr_view.name).mode).append(")");
						}
					}
				}
				main_window.title = title_string.str;
			} else {
				(user_list.model as Gtk.ListStore).clear();
				main_window.title = "XSIRC - Idle";
			}
		}
		
		// View creation and adding-to
		
		public View create_view(string name) {
			Gtk.Label label = new Gtk.Label(name);
			
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
			string text = timestamp()+" "+what+"\n";
			bool scrolled = (int)view.scrolled_window.vadjustment.value == (int)(view.scrolled_window.vadjustment.upper - view.scrolled_window.vadjustment.page_size);
			Gtk.TextIter end_iter;
			view.text_view.buffer.get_end_iter(out end_iter);
			view.text_view.buffer.insert(end_iter,text,(int)text.size());
			if(scrolled) {
				Gtk.TextIter scroll_iter;
				view.text_view.buffer.get_end_iter(out scroll_iter);
				view.text_view.scroll_to_mark(view.text_view.buffer.create_mark(null,scroll_iter,false),0,true,0,1);
			}
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
			foreach(Server server in servers) {
				if(server.notebook == notebook) {
					return server;
				}
			}
			return null;
		}
		
		public Server? curr_server() {
			return find_server_by_notebook(get_curr_notebook_widget() as Gtk.Notebook);
		}
		
		public bool in_system_view() {
			return curr_server == null;
		}
		
		public void open_server(string address,int port = 6667,bool ssl = false,string password = "",ServerManager.Network? network = null) {
			Server server = new Server(address,port,ssl,password,network);
			servers.add(server);
			servers_notebook.append_page(server.notebook,server.label);
			servers_notebook.show_all();
			servers_notebook.page = servers_notebook.page_num(server.notebook);
		}
		// Menu callbacks
		
		public static void connect_server_cb(Gtk.Action action) {
			Main.gui.open_connect_dialog();
		}
		// Dialogs
		public void open_connect_dialog() {
			Gtk.Dialog dialog = new Gtk.Dialog.with_buttons("Connect to server",main_window,Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,Gtk.STOCK_OK,Gtk.ResponseType.ACCEPT,Gtk.STOCK_CANCEL,Gtk.ResponseType.REJECT,null);
			Gtk.HBox box = new Gtk.HBox(false,0);
			box.pack_start(new Gtk.Label("Server string:"),false,false,0);
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
					if(/^(irc|sirc):\/\/[a-zA-Z0-9-_.]+:\d+/.match(server_entry.text)) {
						string[] split_server_data = Regex.split_simple("(:\\/\\/|:)",server_entry.text);
						open_server(split_server_data[2],split_server_data[4].to_int(),split_server_data[0] == "ircs",server_entry.text.substring((long)server_entry.text.split(" ")[0].size()));
						dialog.destroy();
					}
				} else {
					dialog.destroy();
				}
			});
			dialog.show_all();
		}
		// Misc
		
		public string timestamp() {
			return Time.local(time_t()).format(Main.config["core"]["timestamp_format"]);
		}
	}
}
