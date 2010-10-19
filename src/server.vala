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
		public ServerManager.Network network;
		// State
		public LinkedList<Channel> channels = new LinkedList<Channel>();
		public LinkedList<GUI.View> views  = new LinkedList<GUI.View>();
		public string nick;
		private time_t last_recieved = time_t();
		public IdleSource iterator;
		public bool connected = false;
		public bool sock_error = false;
		private LinkedList<OutgoingMessage> output_queue = new LinkedList<OutgoingMessage>();
		public unowned Thread sender_thread;
		// Socket
		public SocketClient socket_client;
		public SocketConnection socket_conn;
		public DataInputStream socket_stream;
		
		/*public struct Channel {
			public string name;
			public string topic_content;
			public string topic_setter;
			public time_t topic_time_set;
			public LinkedList<string> raw_users;
			public LinkedList<string> users;
			public bool   userlist_recieved;
			public bool   in_channel;
			public string mode;
		}*/
		
		public class Channel : Object {
			public Topic topic;
			public ArrayList<string> raw_users = new ArrayList<string>();
			public ArrayList<string> users     = new ArrayList<string>();
			public bool userlist_recieved = true;
			public bool in_channel;
			public string mode;
			public class Topic : Object {
				public string content;
				public string setter;
				public time_t time_set;
			}
			public string title {get; set;}
			public Channel() {
				title = "";
				topic = new Topic();
				topic.content  = "";
				topic.setter   = "";
				topic.time_set = (time_t)0;
				in_channel = true;
				mode = null;
			}
		}
		
		private class OutgoingMessage {
			public string message;
			public float priority;
			public OutgoingMessage(string m,float p) {
				message = m;
				priority = p;
			}
		}
		
		public Server(string server,int port,bool ssl,string password,ServerManager.Network? network = null) {
			// GUI
			notebook = new Gtk.Notebook();
			label    = new Gtk.Label((network != null ? network.name+" - " : "")+server);
			open_view("<server>",false); // Non-reordable
			// State stuff
			this.server   = server;
			this.port     = port;
			this.ssl      = ssl;
			this.password = password;
			this.network  = network;
			nick          = Main.config["core"]["nickname"];
			// Connecting etc.
			try {
				sender_thread = Thread.create(thread_func,true);
			} catch(ThreadError e) {
				Posix.exit(Posix.EXIT_FAILURE); // We need threads.
			}
			try {
				irc_connect();
			} catch(Error e) {
				connected = false;
				sock_error = true;
				add_to_view("<server>","ERROR: could not connect - %s".printf(e.message));
			}
		}
		
		~Server() {
			sender_thread.join();
		}
		
		public void iterate() {
			if(socket_ready() && connected && !sock_error) {
				//add_to_view("<server>","DEBUG -- socket ready");
				string s = null;
				try {
					s = socket_stream.read_line(null,null);
				} catch(Error e) {
					connected = false;
					sock_error = true;
					add_to_view("<server>","ERROR: error fetching line: %s".printf(e.message));
				}
				if(s == null) {
					connected = false;
					sock_error = false;
					return;
				}
				if(!s.validate()) {
					try {
						s = convert(s,(ssize_t)s.size(),"UTF-8","ISO-8859-1");
						assert(s.validate()); // Kinda dangerous
					} catch(ConvertError e) {
						return;
					}
				}
				s = s.strip().replace("\r","").replace("\n","");
				//add_to_view("<server>","DEBUG -- got: %s".printf(s));
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
		
		private void irc_connect() throws Error {
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
			
			raw_send("USER %s rocks hard :%s".printf(Main.config["core"]["username"],Main.config["core"]["realname"]));
			raw_send("NICK %s".printf(Main.config["core"]["nickname"]));
			if(password != "") {
				send("PASS %s".printf(password));
			}
			connected = true;
			sock_error = false;
		}
		
		public void send(string s,float priority = 0.5) {
			if(s.down().has_prefix("privmsg ") || s.down().has_prefix("notice ")) {
				string prefix = s.split(" :")[0] + " :";
				string message = s.substring(prefix.length);
				string[] split_message = {};
				while(message.length != 0) {
					string[] split = message.split(" ");
					string msg = "";
					foreach(string i in split) {
						if(msg.length >= 380) break;
						msg += i + " ";
					}
					message = message.substring(msg.strip().length).strip();
					split_message += msg;
				}
				foreach(string i in split_message) {
					output_queue.offer(new OutgoingMessage(prefix+i,priority));
				}
			} else {
				output_queue.offer(new OutgoingMessage(s,priority));
			}
		}
		
		private void raw_send(owned string s) {
			stdout.printf(">> %s\n",s);
			s = s + "\n";
			try {
				s = convert(s,(ssize_t)s.size(),"ISO-8859-1","UTF-8");
			} catch(ConvertError e) {
				// Oh well. Sending as is.
			}
			try {
				socket_conn.output_stream.write(s,s.size(),null);
			} catch(Error e) {
				add_to_view("<server>","Error sending line: %s".printf(e.message));
			}
		}
		
		private void* thread_func() {
			while(true) {
				OutgoingMessage message;
				if((message = output_queue.poll()) != null) {
					Posix.usleep(((int)message.priority*1000));
					raw_send(message.message);
				}
				Posix.usleep(10);
			}
		}
		
		private void handle_server_input(owned string s) {
			stdout.printf("%s\n",s);
			// Getting PING out of the way.
			if(s.has_prefix("PING :")) {
				send("PONG :"+s.split(" :")[1]);
			} else {
				string[] split = s.split(" ");
				string usernick;
				string username;
				string usermask;
				string target;
				string message;
				if(Regex.match_simple("^:.+\\!.+\\@.+ ",s)) {
					usernick = split[0].replace(":","").split("!")[0];
					username = split[0].replace(":","").split("!")[1].split("@")[0];
					usermask = split[0].replace(":","").split("!")[1].split("@")[1];
				} else {
					usernick = "";
					username = "";
					usermask = "";
				}
				if(split[2].down() == nick.down()) {
					target = usernick;
				} else {
					target = split[2];
				}
				message = s.replace(s.split(" :")[0]+" :","");
				switch(split[1]) {
					case "353":
						Channel channel = find_channel(split[4]);
						return_if_fail(channel != null);
						if(channel.userlist_recieved) {
							channel.users.clear();
							channel.raw_users.clear();
						}
						string[] users = message.split(" ");
						foreach(string user in users) {
							channel.raw_users.add(user);
							user = user.down();
							if(/^(&|@|%|\+)/.match(user)) {
								user = user.substring(1);
							}
							channel.users.add(user);
						}
						channel.userlist_recieved = false;
						break;
					case "366":
						Channel channel = find_channel(split[3]);
						return_if_fail(channel != null);
						channel.userlist_recieved = true;
						channel.raw_users.sort((CompareFunc)ircusrcmp);
						channel.users.sort();
						// User list
						Gtk.ListStore list = Main.gui.user_list.model as Gtk.ListStore;
						list.clear();
						Gtk.TreeIter iter;
						foreach(string user in channel.raw_users) {
							//list.append(out iter);
							list.insert_with_values(out iter,0,0,user,-1);
						}
						break;
					case "JOIN":
						if(find_channel(message) == null) {
							Channel channel = new Channel();
							this.channels.add(channel);
							channel.title = message;
							open_view(message);
						}
						send("NAMES %s".printf(message));
						send("MODE "+message);
						add_to_view(message,"%s [%s@%s] has joined %s".printf(usernick,username,usermask,message));
						break;
					case "PART":
						if(usernick.down() == nick.down()) {
							channels.remove(find_channel(split[2].down()));
							GUI.View view = find_view(split[2]);
							views.remove(view);
							notebook.remove_page(notebook.page_num(view.scrolled_window));
						} else {
							send("NAMES %s".printf(split[2]));
						}
						break;
					case "KICK":
						if(split[3].down() == nick.down()) {
							find_channel(split[3]).in_channel = false;
						} else {
							send("NAMES %s".printf(split[2]));
						}
						add_to_view(find_channel(split[2]).title,"%s has kicked %s from %s [%s]".printf(split[3],usernick,split[2],message));
						break;
					case "NICK":
						if(nick.down() == usernick.down())
							nick = message;
						foreach(Channel channel in channels) {
							if(usernick.down() in channel.users) {
								add_to_view(channel.title,"%s is now known as %s.".printf(usernick,message));
								send("NAMES %s".printf(channel.title));
							}
						}
						break;
					case "001":
						break;
					case "INVITE":
						break;
					case "PRIVMSG":
						add_to_view(split[2],"<%s> %s".printf(usernick,message));
						break;
					default:
						add_to_view("<server>","UNHANDLED MESSAGE: %s".printf(s));
						break;
				}
			}
		}
		
		// Misc utility
		private Channel? find_channel(string s) {
			foreach(Channel channel in this.channels) {
				if(channel.title.down() == s.down()) {
					return channel;
				}
			}
			return null;
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
			notebook.page = notebook.page_num(view.scrolled_window);
		}
		
		public void add_to_view(string name,string text) {
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
		
		public Gtk.Widget? get_current_notebook_widget() {
			for(int i = 0;i < notebook.get_n_pages();i++) {
				if(notebook.page_num(notebook.get_nth_page(i)) == notebook.page) {
					return notebook.get_nth_page(i);
				}
			}
			return null;
		}
		
		private GUI.View? find_view_from_scrolled_window(Gtk.ScrolledWindow? scrolled_window) {
			foreach(GUI.View view in views) {
				if(scrolled_window == view.scrolled_window) {
					return view;
				}
			}
			return null;
		}
			
		public GUI.View? current_view() {
			return find_view_from_scrolled_window((Gtk.ScrolledWindow)get_current_notebook_widget());
		}
	}
	int ircusrcmp(string a,string b) {
		// Comparison table
		HashMap<unichar,int> comp_table = new HashMap<unichar,int>();
		comp_table['&'] = 10;
		comp_table['@'] =  8;
		comp_table['%'] =  6;
		comp_table['+'] =  2;
		string user_a = (string)a;
		string user_b = (string)b;
		unichar prefix_a = user_a[0];
		unichar prefix_b = user_b[0];
		// Hacking this for display, since we can't easily reverse a Gee Linked
		// List
		if((prefix_a in comp_table) && !(prefix_b in comp_table)) {
			return 1;
		} else if(!(prefix_a in comp_table) && (prefix_b in comp_table)) {
			return -1;
		} else if((prefix_a in comp_table) && (prefix_b in comp_table)) {
			if(comp_table[prefix_a] > comp_table[prefix_b]) {
				return 1;
			} else if(comp_table[prefix_a] < comp_table[prefix_b]) {
				return -1;
			} else {
				int i = strcmp(a.down(),b.down());
				if(i>0) {
					return -1;
				}else if(i<0) {
					return 1;
				}else {
					return 0;
				}
			}
		} else {
			int i = strcmp(a.down(),b.down());
			if(i>0) {
				return -1;
			}else if(i<0) {
				return 1;
			}else {
				return 0;
			}
		}
	}
}
