/*
 * server.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
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
		public LinkedList<Channel?> channels = new LinkedList<Channel?>();
		public LinkedList<GUI.View?> views  = new LinkedList<GUI.View?>();
		public string nick;
		private time_t last_recieved = time_t();
		public bool connected = false;
		public bool sock_error = false;
		private LinkedList<OutgoingMessage?> output_queue = new LinkedList<OutgoingMessage?>();
		public unowned Thread sender_thread;
		private bool shutting_down = false;
		public bool am_away;
		private int nick_tries = 0;
		private bool sent_ping = false;
		// Socket
		public SocketClient socket_client;
		public SocketConnection socket_conn;
		public DataInputStream socket_stream;
		private bool connecting = false;
		private string error = null;
		private InetAddress address;
		
		public class Channel : Object {
			public Topic topic;
			public ArrayList<string> raw_users = new ArrayList<string>();
			public ArrayList<string> users     = new ArrayList<string>();
			public bool userlist_recieved = true;
			public bool in_channel;
			public string mode;
			public bool got_create_date = false;
			public struct Topic {
				public string content;
				public string setter;
				public time_t time_set;
			}
			public string title;
			public Channel() {
				title = "";
				topic = Topic();
				topic.content  = "";
				topic.setter   = "";
				topic.time_set = (time_t)0;
				in_channel = true;
				mode = "";
			}
		}
		
		private struct OutgoingMessage {
			public string message;
			public float priority;
		}
		
		public Server(string server,int port,bool ssl,string password,ServerManager.Network? network = null) {
			// GUI
			notebook = new Gtk.Notebook();
			notebook.tab_pos = Gtk.PositionType.BOTTOM;
			label    = new Gtk.Label((network != null ? network.name+" - " : "")+server);
			label.use_markup = true;
			open_view("<server>");
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
				Main.server_manager.on_connect_error(this);
				Main.gui.update_gui(this);
			}
			
			notebook.switch_page.connect((page,page_num) => {
				Main.gui.update_gui(this,find_view_from_page_num((int)page_num));
				find_view_from_page_num((int)page_num).label.label = Markup.escape_text(find_view_from_page_num((int)page_num).name);
				Main.gui.text_entry.grab_focus();
			});
			notebook.page_removed.connect(() => {
				Main.gui.queue_update_gui();
			});
		}
		
		~Server() {
			shutting_down = true;
			sender_thread.join();
		}
		
		public void iterate() {
			if(connecting) {
				if(connected) {
					connecting = false;
					add_to_view("<server>","DEBUG -- connected through port %d".printf(port));
					socket_stream = new DataInputStream(socket_conn.input_stream);
			
					raw_send("USER %s rocks hard :%s".printf(Main.config["core"]["username"],Main.config["core"]["realname"]));
					raw_send("NICK %s".printf(Main.config["core"]["nickname"]));
					if(password != "") {
						send("PASS %s".printf(password));
					}
					connected = true;
					sock_error = false;
					foreach(Channel channel in channels) {
						if(!channel.in_channel) {
							send("JOIN %s".printf(channel.title));
						}
					}
					Main.gui.update_gui(this);
				} else if(sock_error) {
					connecting = false;
					Main.plugin_manager.on_connect_error(this);
					add_to_view("<server>","ERROR: could not connect - %s".printf(error));
					Main.server_manager.on_connect_error(this);
					Main.gui.update_gui(this);
				}
			} else if(socket_ready() && connected && !sock_error) {
				//add_to_view("<server>","DEBUG -- socket ready");
				string s = null;
				try {
					s = socket_stream.read_line(null,null);
				} catch(Error e) {
					connected = false;
					sock_error = true;
					Main.gui.update_gui(this);
					add_to_view("<server>","ERROR: error fetching line: %s".printf(e.message));
				}
				if(s == null) {
					connected = false;
					sock_error = false;
					Main.gui.update_gui(this);
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
			if(connected && !sock_error) {
				// Checking if almost timeouting
				if(((int)time_t() - (int)last_recieved) >= 250) {
					if(!sent_ping) {
						send("PING :lagcheck");
						sent_ping = true;
					}
				}
				// Ping timeout
				if(((int)time_t() - (int)last_recieved) >= 300) {
					add_to_view("<server>","Ping timeout. Reconnecting...");
					try {
						last_recieved = time_t();
						irc_disconnect();
						irc_connect();
					} catch(Error e) {
						
					}
				}
			}
		}
		
		private bool socket_ready() {
			if(!connected || sock_error) {
				return false;
			} else if(socket_conn.socket == null) {
				return false;
			} else if(socket_conn.socket.condition_check(IOCondition.IN) == IOCondition.IN) {
				return true;
			} else {
				return false;
			}
		}
		
		public void irc_connect() throws Error {
			Resolver resolver = Resolver.get_default();
			GLib.List<InetAddress> addresses = resolver.lookup_by_name(server,null);
			if(addresses.length() < 1) {
				add_to_view("<server>","ERROR: could not look up host name.");
				connected = false;
				sock_error = true;
				return;
			}
			address = addresses.nth_data(0);
			add_to_view("<server>","DEBUG -- resolved %s to %s".printf(server,address.to_string()));
			
			socket_client = new SocketClient();
			try {
				Thread.create(socket_connect_async,true);
			} catch(ThreadError e) {
				connected = false;
				sock_error = true;
			}
		}
		
		private void* socket_connect_async() {
			connecting = true;
			try {
				socket_conn = socket_client.connect(new InetSocketAddress(address,(uint16)port),null);
				connected = true;
				sock_error = false;
			} catch(Error e) {
				connected = false;
				sock_error = true;
				error = e.message;
			}
			return null;
		}
		
		public void irc_disconnect() {
			try {
				socket_conn.socket.close();
			} catch(Error e) {
				
			}
			connected = false;
			sock_error = false;
			foreach(Channel channel in channels) {
				channel.in_channel = false;
			}
			Main.plugin_manager.on_disconnect(this);
			Main.gui.update_gui(this);
		}
		
		public void send(string s,float priority = 0.5,string view_name = "") {
			if(s.down().has_prefix("privmsg ") || s.down().has_prefix("notice ")) {
				string prefix = s.split(" :")[0] + " :";
				string message = s.substring(prefix.length);
				string[] split_message = {};
				while(message.length != 0) {
					string[] split = message.split(" ");
					StringBuilder str = new StringBuilder("");
					int n = 1;
					foreach(string i in split) {
						if(str.str.length >= 380) break;
						str.append(i);
						if(n < split.length) {
							str.append(" ");
						}
						n++;
					}
					message = message.substring(str.str.length);
					split_message += str.str;
				}
				foreach(string i in split_message) {
					stdout.printf("%s\n",i);
					string target = s.split(" ")[1];
					string msg = i; // herp derp
					if(s.down().has_prefix("notice")) {
						add_to_view(target,"-%s- %s".printf(nick,msg));
					} else if(msg.has_prefix("ACTION")) {
						add_to_view(target,"* %s %s".printf(nick,msg.replace("","").substring(7)));
					} else if(msg.has_prefix("")) {
						add_to_view(target,">%s< CTCP %s".printf(nick,msg.replace("","")));
					} else {
						add_to_view(target,"<%s> %s".printf(nick,msg));
					}
					OutgoingMessage outg = {prefix+i,priority};
					output_queue.offer(outg);
				}
			} else {
				OutgoingMessage outg = {s,priority};
				output_queue.offer(outg);
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
			while(!shutting_down) {
				OutgoingMessage message;
				if(output_queue.size != 0) {
					message = output_queue.poll();
					Posix.usleep(((int)message.priority*1000));
					raw_send(message.message);
				}
				Posix.usleep(10);
			}
			return null;
		}
		
		private void handle_server_input(owned string s) {
			stdout.printf("%s\n",s);
			last_recieved = time_t();
			// Getting PING out of the way.
			if(s.has_prefix("ERROR")) {
				irc_disconnect();
			}
			if(s.has_prefix("PING :")) {
				send("PONG :"+s.split(" :")[1]);
			} else {
				string[] split = s.split(" ");
				string usernick;
				string username;
				string usermask;
				string target;
				string message;
				if(/^[^ ]+?![^ ]+?@[^ ]+? /.match(s)) {
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
					case "PONG":
						sent_ping = false;
						break;
					case "JOIN":
						if(find_channel(message) == null) {
							Channel channel = new Channel();
							this.channels.add(channel);
							channel.title = message;
							open_view(message);
						}
						find_channel(message).in_channel = true;
						send("NAMES %s".printf(message));
						send("MODE "+message);
						Main.plugin_manager.on_join(this,usernick,username,usermask,message);
						add_to_view(message,"%s [%s@%s] has joined %s".printf(usernick,username,usermask,message));
						break;
					case "PART":
						message = message == s ? "" : message;
						Main.plugin_manager.on_part(this,usernick,username,usermask,split[2],message);
						add_to_view(split[2],"%s [%s@%s] has left %s [%s]".printf(usernick,username,usermask,split[2],message));
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
						message = message == s ? "" : message;
						Main.plugin_manager.on_kick(this,split[3],usernick,username,usermask,split[2],message);
						add_to_view(find_channel(split[2]).title,"%s has kicked %s from %s [%s]".printf(split[3],usernick,split[2],message));
						break;
					case "NICK":
						if(nick.down() == usernick.down()) {
							nick = message;
							Main.gui.update_gui(this);
						}
						Main.plugin_manager.on_nick(this,message,usernick,username,usermask);
						foreach(Channel channel in channels) {
							if(usernick.down() in channel.users) {
								add_to_view(channel.title,"%s is now known as %s.".printf(usernick,message));
								send("NAMES %s".printf(channel.title));
							}
						}
						foreach(GUI.View view in views) {
							if(view.name.down() == usernick.down()) {
								view.name = message;
								view.label.label = message;
								add_to_view(view.name,"%s is now known as %s.".printf(usernick,message));
							}
						}
						break;
					case "INVITE":
						add_to_view("<server>","%s has invited you to %s.".printf(usernick,split[3]));
						break;
					case "001":
						Main.plugin_manager.on_connect(this);
						Main.server_manager.on_connect(this);
						nick_tries = 0;
						nick = split[2];
						add_to_view("<server>",message);
						break;
					case "002":
					case "003":
						add_to_view("<server>",message);
						break;
					case "004":
						add_to_view("<server>","Server info: %s %s %s %s".printf(split[3],split[4],split[5],split[6]));
						break;
					case "005":
						StringBuilder supported = new StringBuilder("");
						for(int i = 3; !split[i].has_prefix(":"); i++) {
							supported.append(split[i]).append(" ");
						}
						add_to_view("<server>","Server info: %s are supported by this server".printf(supported.str));
						break;
					case "PRIVMSG":
						Main.plugin_manager.on_privmsg(this,usernick,username,usermask,target,message);
						if(message[0] == '\x01') {
							message = message.replace(((char)1).to_string(),"");
							string prefix = message.split(" ")[0];
							message = message.substring(prefix.length);
							switch(prefix) {
								case "ACTION":
									add_to_view(target,"* %s%s".printf(usernick,message));
									break;
								case "PING":
									add_to_view("<server>","Got CTCP PING from %s".printf(usernick));
									send("NOTICE "+target+" :\x01PING"+message+"\x01");
									break;
								case "VERSION":
									add_to_view("<server>","Got CTCP VERSION from %s".printf(usernick));
#if WINDOWS
									send("NOTICE "+target+" :\x01VERSION "+"XSIRC:"+VERSION+":"+"Windows"+"\x01");
#else
									send("NOTICE "+target+" :\x01VERSION "+"XSIRC:"+VERSION+":"+"Unix-like"+"\x01");
#endif
									break;
								default:
									add_to_view("<server>","UNHANDLED CTCP MESSAGE -- PREFIX: %s; MESSAGE: %s".printf(prefix,message));
									break;
							}
						} else {
							add_to_view(target,"<%s> %s".printf(usernick,message));
						}
						/*if(message.down().contains(nick.down())) {
							Notifier.fire_notification(this,find_view(target),"<%s> %s".printf(usernick,message));
						}*/
						break;
					case "NOTICE":
						if(split[2] == "AUTH") {
							add_to_view("<server>","AUTH -- %s".printf(message));
						} else {
							Main.plugin_manager.on_notice(this,usernick,username,usermask,target,message);
							if(message.has_prefix(((char)1).to_string())) {
								message = message.replace(((char)1).to_string(),"");
								string prefix = message.split(" ")[0];
								message = message.substring(prefix.length);
								switch(prefix) {
									default:
										add_to_view("<server>","UNHANDLED CTCP REPLY -- PREFIX: %s; SENDER: %s; MESSAGE: %s".printf(prefix,target,message));
										break;
								}
							} else {
								if(find_view(target) != null) {
									add_to_view(target,"-%s- %s".printf(usernick,message));
								} else {
									add_to_view(current_view().name,"-%s- %s".printf(usernick,message));
								}
							}
						}
						break;
					case "QUIT":
						Main.plugin_manager.on_quit(this,usernick,username,usermask,message);
						foreach(Channel channel in channels) {
							if(usernick.down() in channel.users) {
								add_to_view(channel.title,"%s has disconnected [%s]".printf(usernick,message));
								send("NAMES %s".printf(channel.title));
							}
						}
						break;
					case "MODE":
						if(split[4] != null && !(/^[0-9]+$/.match(split[4]))) {
							string targets = string.joinv(" ",split[4:(split.length-1)]);
							Main.plugin_manager.on_chan_user_mode(this,usernick,username,usermask,split[2],split[3],targets);
							add_to_view(split[2],"%s sets %s on %s".printf(usernick,split[3],targets));
							send("NAMES %s".printf(split[2]));
						} else if(split[2].has_prefix("#")) {
							string targets = string.joinv(" ",split[3:(split.length-1)]);
							Main.plugin_manager.on_chan_mode(this,usernick,username,usermask,split[2],targets);
							add_to_view(split[2],"%s sets mode %s on %s".printf(usernick,targets,split[2]));
							send("MODE %s".printf(split[2]));
						} else {
							Main.plugin_manager.on_mode(this,usernick,message);
							add_to_view("<server>","Changing mode: %s".printf(message));
						}
						break;
					case "TOPIC":
						Channel chan = find_channel(split[2]);
						chan.topic.setter = usernick;
						chan.topic.content = message;
						chan.topic.time_set = time_t();
						Main.plugin_manager.on_topic(this,usernick,username,usermask,chan.title,message);
						add_to_view(split[2],"%s has set the topic to: %s".printf(usernick,message));
						Main.gui.update_gui(this);
						break;
					case "333":
						Channel chan = find_channel(split[3]);
						chan.topic.setter = split[4];
						chan.topic.time_set = (time_t)split[5].to_int();
#if WINDOWS
						add_to_view(split[3],"Topic set by %s on %s".printf(split[4],localtime(chan.topic.time_set).format("%c")));
#else
						add_to_view(split[3],"Topic set by %s on %s".printf(split[4],Time.local(chan.topic.time_set).format("%c")));
#endif
						break;
					/*case "305":
						am_away = false;
						break;
					case "306":
						am_away = true;
						break;*/
					// Error messages
					case "401":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "402":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "403":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "404":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "405":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "406":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "407":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "409":
						add_to_view("<server>",message);
						break;
					case "411":
						add_to_view("<server>",message);
						break;
					case "412":
						add_to_view("<server>",message);
						break;
					case "413":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "414":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "421":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "422":
						add_to_view("<server>",message);
						break;
					case "423":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "424":
						add_to_view("<server>",message);
						break;
					case "431":
						add_to_view("<server>",message);
						break;
					case "432":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "433":
						nick_tries++;
						StringBuilder new_nick = new StringBuilder(nick);
						for(int i = 0; i < nick_tries; i++) {
							new_nick.append("_");
						}
						send("NICK %s".printf(new_nick.str));
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "436":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "441":
						add_to_view("<server>","%s isn't on %s".printf(split[3],split[4]));
						break;
					case "442":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "443":
						add_to_view("<server>","%s is already on %s".printf(split[3],split[4]));
						break;
					case "444":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "445":
						add_to_view("<server>",message);
						break;
					case "446":
						add_to_view("<server>",message);
						break;
					case "451":
						add_to_view("<server>",message);
						break;
					case "461":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "462":
						add_to_view("<server>",message);
						break;
					case "463":
						add_to_view("<server>",message);
						break;
					case "464":
						add_to_view("<server>",message);
						break;
					case "465":
						add_to_view("<server>",message);
						break;
					case "467":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "471":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "472":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "473":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "474":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "475":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "481":
						add_to_view("<server>",message);
						break;
					case "482":
						add_to_view("<server>","%s: %s".printf(split[3],message));
						break;
					case "483":
						add_to_view("<server>",message);
						break;
					case "491":
						add_to_view("<server>",message);
						break;
					case "501":
						add_to_view("<server>",message);
						break;
					case "502":
						add_to_view("<server>",message);
						break;
					// Command responses
					case "302":
						string name = message.split("=")[0];
						add_to_view("<server>","Userhost for %s: %s".printf(name,message));
						break;
					case "303":
						add_to_view("<server>","%s is on".printf(message));
						break;
					case "301":
						add_to_view("<server>","%s is away: %s".printf(split[3],message));
						break;
					case "305":
						add_to_view("<server>","You are no longer marked as away.");
						am_away = false;
						break;
					case "306":
						add_to_view("<server>","You are now marked as away.");
						am_away = true;
						break;
					case "311":
						add_to_view("<server>","WHOIS for %s: %s@%s: %s".printf(split[3],split[4],split[5],message));
						break;
					case "312":
						add_to_view("<server>","WHOIS for %s: in server %s: %s".printf(split[3],split[4],message));
						break;
					case "313":
						add_to_view("<server>","WHOIS for %s: is an IRCop".printf(split[3]));
						break;
					case "317":
						add_to_view("<server>","WHOIS for %s: %s seconds idle".printf(split[3],split[4]));
						break;
					case "318":
						add_to_view("<server>","WHOIS for %s: end of /WHOIS list.".printf(split[3]));
						break;
					case "319":
						add_to_view("<server>","WHOIS for %s: in channels %s".printf(split[3],message));
						break;
					case "307":
						add_to_view("<server>","WHOIS for %s: is a registered nickname".printf(split[3]));
						break;
					case "314":
						add_to_view("<server>","WHOWAS for %s: %s@%s: %s".printf(split[3],split[4],split[5],message));
						break;
					case "369":
						add_to_view("<server>","WHOWAS for %s: end of /WHOWAS list.".printf(split[3]));
						break;
					case "321":
						add_to_view("<server>","LIST: Channel (Users) Topic");
						break;
					case "322":
						add_to_view("<server>","LIST: %s (%s) %s".printf(split[3],split[4],message));
						break;
					case "323":
						add_to_view("<server>","LIST: end of /LIST.");
						break;
					case "324":
						Channel chan = find_channel(split[3]);
						chan.mode = string.joinv(" ",split[4:(split.length-1)]);
						Main.gui.update_gui(this);
						break;
					case "331":
						add_to_view(split[2],"No topic is set");
						break;
					case "329":
						if(find_channel(split[3]) != null && !find_channel(split[3]).got_create_date) {
#if WINDOWS
							add_to_view(split[3],"Channel was created %s".printf(localtime((time_t)split[4].to_int()).format("%c")));
#else
							add_to_view(split[3],"Channel was created %s".printf(Time.local((time_t)split[4].to_int()).format("%c")));
#endif
							find_channel(split[3]).got_create_date = true;
						}
						break;
					case "332":
						Channel chan = find_channel(split[3]);
						chan.topic.content = message;
						add_to_view(split[3],"The topic is: %s".printf(message));
						Main.gui.update_gui(this);
						break;
					case "341":
						add_to_view("<server>","INVITE: inviting %s to %s".printf(split[3],split[4]));
						break;
					case "342":
						add_to_view("<server>","SUMMON: summoning %s to IRC".printf(split[3]));
						break;
					case "351":
						add_to_view("<server>","Server version: %s; server software: %s; %s".printf(split[3],split[4],message));
						break;
					case "352":
						add_to_view("<server>","WHO in %s: %s!%s@%s in server %s (%s) %s".printf(split[3],split[7],split[4],split[5],split[6],split[8],message));
						break;
					case "315":
						add_to_view("<server>","WHO in %s: end of /WHO list.".printf(split[3]));
						break;
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
						Main.gui.update_gui(this);
						break;
					case "364":
						add_to_view("<server>","LINKS: %s %s :%s".printf(split[3],split[4],message));
						break;
					case "365":
						add_to_view("<server>","LINKS: end of /LINKS list.");
						break;
					case "367":
						add_to_view("<server>","Bans for %s: %s".printf(split[3],split[4]));
						break;
					case "368":
						add_to_view("<server>","Bans for %s: end of ban list.");
						break;
					case "348":
						add_to_view("<server>","Exceptions for %s: %s".printf(split[3],split[4]));
						break;
					case "349":
						add_to_view("<server>","Exceptions for %s: end of exceptions list.");
						break;
					case "371":
						add_to_view("<server>","INFO: %s".printf(message));
						break;
					case "374":
						add_to_view("<server>","INFO: end of /INFO list.");
						break;
					case "375":
						add_to_view("<server>","MOTD for %s:".printf(server));
						break;
					case "372":
						add_to_view("<server>",message);
						break;
					case "376":
						add_to_view("<server>","End of /MOTD command.");
						break;
					case "381":
						add_to_view("<server>","You are now an IRCop.");
						break;
					case "382":
						add_to_view("<server>","Rehashing config file %s.".printf(split[3]));
						break;
					case "391":
						add_to_view("<server>","Server's local time: %s".printf(message));
						break;
					/* TODO: implement 200, 201, 202, 203, 204, 205, 206, 208,
					         261, 211, 212, 213, 214, 215, 216, 218, 219, 241,
					         242, 243, 244 */
					case "221":
						add_to_view("<server>","Your mode is: %s".printf(split[3]));
						break;
					case "251":
						add_to_view("<server>","Server info: %s".printf(message));
						break;
					case "252":
						add_to_view("<server>","Server info: %s operator(s) online".printf(split[3]));
						break;
					case "253":
						add_to_view("<server>","Server info: %s unknown connection(s)".printf(split[3]));
						break;
					case "254":
						add_to_view("<server>","Server info: %s channels formed".printf(split[3]));
						break;
					case "255":
					case "265":
					case "266":
						add_to_view("<server>","Server info: %s".printf(message));
						break;
					case "256":
						add_to_view("<server>","Administrative info for %s:".printf(split[3]));
						break;
					case "257":
						add_to_view("<server>",message);
						break;
					case "258":
						add_to_view("<server>",message);
						break;
					case "259":
						add_to_view("<server>",message);
						break;
					default:
						add_to_view("<server>","UNHANDLED MESSAGE: %s".printf(s));
						break;
				}
			}
		}
		
		// Misc utility
		public Channel? find_channel(string s) {
			foreach(Channel channel in this.channels) {
				if(channel.title.down() == s.down()) {
					return channel;
				}
			}
			return null;
		}
		
		// GUI stuff
		
		public void open_view(string name,bool reordable = true) {
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
			open_view(name);
			GUI.View? view;
			if((view = find_view(name)) != null) {
				IRCLogger.log(this,view,text);
				Main.gui.add_to_view(view,text);
				if(current_view() != view) {
					view.label.label = "<span foreground=\"red\">%s</span>".printf(Markup.escape_text(view.name));
				}
				if(Main.gui.current_server() != this) {
					label.label = "<span foreground=\"red\">%s</span>".printf(Markup.escape_text((network != null ? network.name+" - " : "")+server));
				}
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
		
		public GUI.View? find_view_from_scrolled_window(Gtk.ScrolledWindow? scrolled_window) {
			foreach(GUI.View view in views) {
				if(scrolled_window == view.scrolled_window) {
					return view;
				}
			}
			return null;
		}
		
		private GUI.View? find_view_from_page_num(int num) {
			foreach(Gtk.Widget child in notebook.get_children()) {
				if(notebook.page_num(child) == num) {
					return find_view_from_scrolled_window(child as Gtk.ScrolledWindow);
				}
			}
			return null;
		}
			
		public GUI.View? current_view() {
			return find_view_from_scrolled_window((Gtk.ScrolledWindow)get_current_notebook_widget());
		}
		
		public void close_view(owned GUI.View? view = null) {
			if(view == null) {
				view = current_view();
			}
			if(view == null || view.name == "<server>") {
				return;
			}
			if(view.name.has_prefix("#") && (find_channel(view.name) != null) && find_channel(view.name).in_channel) {
				send("PART %s".printf(view.name));
			} else {
				views.remove(view);
				notebook.remove_page(notebook.page_num(view.scrolled_window));
			}
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
		if((comp_table.has_key(prefix_a)) && !(comp_table.has_key(prefix_b))) {
			return -1;
		} else if(!(comp_table.has_key(prefix_a)) && (comp_table.has_key(prefix_b))) {
			return 1;
		} else if((comp_table.has_key(prefix_a)) && (comp_table.has_key(prefix_b))) {
			if(comp_table[prefix_a] > comp_table[prefix_b]) {
				return -1;
			} else if(comp_table[prefix_a] < comp_table[prefix_b]) {
				return 1;
			} else {
				return strcmp(a.down(),b.down());
			}
		} else {
			return strcmp(a.down(),b.down());
		}
	}
}
