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
		// Other stuff
		private LinkedList<string> command_history = new LinkedList<string>();
		private int command_history_index = 0;
		public ArrayList<Server> servers = new ArrayList<Server>();
		
		public struct View {
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
			
			// Menu bar & children
			Gtk.MenuBar menu_bar = new Gtk.MenuBar();
			main_vbox.pack_start(menu_bar,false,true,0);
			
			// Menus: Client | Edit | View | Server | Help
			// Client menu
			
			Gtk.MenuItem client_menu_item = new Gtk.MenuItem.with_mnemonic("_Client");
			menu_bar.add(client_menu_item);
			
			Gtk.Menu client_menu = new Gtk.Menu();
			
			client_menu_item.submenu = client_menu;
			
			Gtk.ImageMenuItem connect_item = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_CONNECT,null);
			client_menu.append(connect_item);
			connect_item.activate.connect(() => {
				stdout.printf("TODO\n");
			});
			
			Gtk.MenuItem disconnect_all_servers_item = new Gtk.MenuItem.with_label("Disconnect all");
			client_menu.append(disconnect_all_servers_item);
			disconnect_all_servers_item.activate.connect(() => {
				stdout.printf("TODO\n");
			});
			
			Gtk.MenuItem reconnect_all_servers_item = new Gtk.MenuItem.with_label("Reconnect all");
			client_menu.append(reconnect_all_servers_item);
			
			// Edit menu
			Gtk.MenuItem edit_menu_item = new Gtk.MenuItem.with_mnemonic("_Edit");
			Gtk.Menu edit_menu = new Gtk.Menu();
			menu_bar.add(edit_menu_item);
			
			
			// Topic text box
			topic_view = new Gtk.Entry();
			main_vbox.pack_start(topic_view,false,true,0);
			
			// Main HBox, users, servers notebook
			Gtk.HBox main_hbox = new Gtk.HBox(false,0);
			main_vbox.pack_start(main_hbox,true,true,0);
			
			// User list
			user_list = new Gtk.TreeView.with_model(new Gtk.ListStore(1,typeof(string)));
			main_hbox.pack_start(user_list,false,true,0);
			
			var display_column = new Gtk.TreeViewColumn();
			display_column.title = "Users";
			var renderer = new Gtk.CellRendererText();
			user_list.append_column(display_column);
			
			display_column.set_attributes(renderer,"text",0);
			// Debugging things
			Gtk.TreeIter iter;
			Gtk.ListStore model = user_list.model as Gtk.ListStore;
			model.append(out iter);
			model.set(iter,0,"Yes!",-1);
			
			// Quick VBox for server notebook+input
			var vbox = new Gtk.VBox(false,0);
			main_hbox.pack_start(vbox,true,true,5);
			
			// Server notebook
			
			servers_notebook = new Gtk.Notebook();
			vbox.pack_start(servers_notebook,true,true,0);
			
			// System view goes here.
			
			system_view = create_view("System");
			servers_notebook.append_page(system_view.scrolled_window,system_view.label);
			servers_notebook.show_all();
			// Input entry
			
			text_entry = new Gtk.TextView();
			text_entry.accepts_tab = true;
			text_entry.buffer.text = "test";
			vbox.pack_start(text_entry,false,true,0);
			
			// Status bar
			status_bar = new Gtk.Statusbar();
			main_vbox.pack_start(status_bar,false,true,0);
			main_window.show_all();

			// Activate signal
			text_entry.buffer.changed.connect(() => {
				if(text_entry.buffer.text.contains("\n")) {
					foreach(string text in this.text_entry.buffer.text.split("\n")) {
						parse_text(text);
					}
					text_entry.buffer.text = "";
				}
			});
		
		}
		
		private void parse_text(string text) {
			
		}
		
		private bool quit() {
			// TODO
			return false;
		}
		
		public void main_loop() {
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
		// View creation and adding-to
		
		public View create_view(string name) {
			Gtk.Label label = new Gtk.Label(name);
			
			Gtk.TextView text_view = new Gtk.TextView();
			text_view.editable = false;
			text_view.cursor_visible = false;
			text_view.wrap_mode = Gtk.WrapMode.WORD;
			text_view.modify_font(Pango.FontDescription.from_string(Main.config["core"]["font"]));
			
			Gtk.ScrolledWindow scrolled_window = new Gtk.ScrolledWindow(null,null);
			scrolled_window.vscrollbar_policy = Gtk.PolicyType.ALWAYS;
			scrolled_window.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
			scrolled_window.add(text_view);
			
			View view = {name,scrolled_window,text_view,label};
			
			return view;
		}
		
		public void add_to_view(View view,string what) {
			string text = "\n"+timestamp()+" "+what;
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
		
		public void open_server(string address,int port = 6667,bool ssl = false,string password = "",string? network = null) {
			Server server = new Server(address,port,ssl,password,network);
			servers.add(server);
			servers_notebook.append_page(server.notebook,server.label);
			servers_notebook.show_all();
		}
		// Dialogs
		
		// Misc
		
		public string timestamp() {
			return Time.local(time_t()).format(Main.config["core"]["timestamp_format"]);
		}
	}
}
