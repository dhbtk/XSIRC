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
		// Other stuff
		private LinkedList<string> command_history = new LinkedList<string>();
		private int command_history_index = 0;
		public ArrayList<Server> servers = new ArrayList<Server>();
		
		public GUI() {
			main_window = new Gtk.Window(Gtk.WindowType.TOPLEVEL);
			main_window.title = "XSIRC";
			main_window.set_default_size(640,320);
			main_window.destroy.connect(Gtk.main_quit);
			
			Gtk.VBox main_vbox = new Gtk.VBox(false,0); // Main VBox, holds menubar + userlist, server notebook, entry field + status bar
			main_window.add(main_vbox);
			
			// Menu bar & children
			Gtk.MenuBar menu_bar = new Gtk.MenuBar();
			main_vbox.pack_start(menu_bar,false,true,0);
			
			// Menus: Client | Edit | View | Server | Help
			// Client menu
			
			Gtk.MenuItem client_menu_item = new Gtk.MenuItem.with_label("Client");
			menu_bar.add(client_menu_item);
			
			Gtk.Menu client_menu = new Gtk.Menu();
			
			client_menu_item.submenu = client_menu;
			
			Gtk.ImageMenuItem connect_item = new Gtk.ImageMenuItem.from_stock(Gtk.STOCK_CONNECT,null);
			client_menu.append(connect_item);
			connect_item.activate.connect(() => {
				stdout.printf("TODO\n");
			});
			
			Gtk.MenuItem disconnect_all_servers_item = new Gtk.MenuItem.with_label("Disconnect from all servers");
			client_menu.append(disconnect_all_servers_item);
			disconnect_all_servers_item.activate.connect(() => {
				stdout.printf("TODO\n");
			});
			
			Gtk.MenuItem reconnect_all_servers_item = new Gtk.MenuItem.with_label("Reconnect to all servers");
			client_menu.append(reconnect_all_servers_item);
			
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
	}
}
