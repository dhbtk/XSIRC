using Gee;
namespace XSIRC {
	public class Server : Object {
		public Gtk.Notebook notebook;
		public Gtk.Label label;
		// Settings
		public string server;
		public int port;
		public bool ssl;
		public string password;
		public string? network;
		// State
		public ArrayList<Channel> channels = new ArrayList<Channel>();
		public ArrayList<GUI.View?> views  = new ArrayList<GUI.View?>();
		public string nick;
		private time_t last_recieved = time_t();
		public IdleSource iterator;
		public bool connected = false;
		public bool sock_error = false;
		private PriorityQueue<OutgoingMessage> output_queue = new PriorityQueue<OutgoingMessage>();
		// Socket
		public SocketClient socket_client;
		public SocketConnection socket_conn;
		public DataInputStream socket_stream;
		
		public class Channel {
			public string name;
			public Topic topic;
			public ArrayList<string> raw_users = new ArrayList<string>();
			public ArrayList<string> users     = new ArrayList<string>();
			public bool userlist_recieved = true;
			public bool in_channel;
			public string mode;
			public class Topic {
				public string content;
				public string setter;
				public time_t time_set;
			}
		}
		
		private class OutgoingMessage {
			public string message;
			public int priority;
			public OutgoingMessage(string m,int p) {
				message = m;
				priority = p;
			}
		}
		
		public Server(string server,int port,bool ssl,string password,string? network = null) {
			// GUI
			notebook = new Gtk.Notebook();
			label    = new Gtk.Label((network != null ? network+" - " : "")+server);
			open_view("<server>",false); // Non-reordable
			// State stuff
			this.server   = server;
			this.port     = port;
			this.ssl      = ssl;
			this.password = password;
			this.network  = network;
			// Connecting etc.
			irc_connect();
		}
		
		public void iterate() {
			if(socket_ready()) {
				add_to_view("<server>","DEBUG -- socket ready");
				string s = socket_stream.read_line(null,null);
				if(s == null) {
					connected = false;
					sock_error = false;
				}
				if(!s.validate()) {
					s = convert(s,(ssize_t)s.size(),"UTF-8","ISO-8859-1");
					assert(s.validate()); // Kinda dangerous
					s = s.split("\n")[0];
				}
				add_to_view("<server>","DEBUG -- got: %s".printf(s));
				handle_server_input(s);
			}
		}
		
		private bool socket_ready() {
			if(socket_conn.socket.condition_check(IOCondition.IN) == IOCondition.IN) {
				return true;
			} else {
				return false;
			}
		}
		
		private void irc_connect() {
			Resolver resolver = Resolver.get_default();
			GLib.List<InetAddress> addresses = resolver.lookup_by_name(server,null);
			if(addresses.length() < 1) {
				add_to_view("<server>","ERROR: could not look up host name.");
				connected = false;
				sock_error = true;
				return;
			}
			InetAddress address = addresses.nth_data(0);
			add_to_view("<server>","DEBUG -- resolved %s to %s".printf(server,address.to_string()));
			
			socket_client = new SocketClient();
			socket_conn   = socket_client.connect(new InetSocketAddress(address,(uint16)port),null);
			add_to_view("<server>","DEBUG -- connected through port %d".printf(port));
			socket_stream = new DataInputStream(socket_conn.input_stream);
			
			send("USER %s rocks hard :%s".printf(Main.config["core"]["username"],Main.config["core"]["realname"]));
			send("NICK %s".printf(Main.config["core"]["nickname"]));
			if(password != "") {
				send("PASS %s".printf(password));
			}
			connected = true;
			sock_error = false;
		}
		
		private void send(string s,int priority = 0.5) {
			if(s.down().has_prefix("privmsg ") || s.down().has_prefix("notice ")) {
				string prefix = s.split(" :")[0] + " :";
				string message = s.substring(prefix.length());
				string[] split_message = {};
				while(message.length() != 0) {
					string[] split = message.split(" ");
					string msg = "";
					foreach(string i in split) {
						if(msg.length() >= 380) break;
						msg += i + " ";
					}
					message = message.substring(msg.strip().length()).strip();
					split_message += msg;
				}
				foreach(string i in split_message) {
					output_queue.offer(new OutgoingMessage(prefix+i,priority));
				}
			} else {
				output_queue.offer(new OutgoingMessage(s,priority));
			}
		}
		
		private void raw_send(string s) requires (s.size() <= 510) {
			
		}
		
		private void handle_server_input(owned string s) {
			
		}
		
		// GUI stuff
		
		private void open_view(string name,bool reordable = true) {
			if(find_view(name) != null) {
				return;
			}
			GUI.View view = Main.gui.create_view(name);
			views.add(view);
			notebook.append_page(view.scrolled_window,view.label);
			notebook.set_tab_reorderable(view.scrolled_window,reordable);
			notebook.show_all();
		}
		
		private void add_to_view(string name,string text) {
			GUI.View? view;
			if((view = find_view(name)) != null) {
				Main.gui.add_to_view(view,text);
			}
		}
		
		private GUI.View? find_view(string name) {
			foreach(GUI.View view in views) {
				if(view.name.down() == name.down()) {
					return view;
				}
			}
			return null;
		}
	}
}
