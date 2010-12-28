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
		public string server {get; set;}
		public int port {get; set;}
		public bool ssl {get; set;}
		public string password {get; set;}
		public ServerManager.Network network {get; private set;}
		// State
		public LinkedList<Channel> channels {get; private set; default = new LinkedList<Channel>();}
		public LinkedList<GUI.View> views {get; private set; default = new LinkedList<GUI.View>();}
		public string nick {get; private set;}
		public string my_username {get; private set;}
		public string my_hostmask {get; private set;}
		private time_t last_recieved = time_t();
		public bool connected {get; private set; default = false;}
		public bool sock_error {get; private set; default = false;}
		private LinkedList<OutgoingMessage?> output_queue = new LinkedList<OutgoingMessage?>();
		private unowned Thread sender_thread;
		private bool shutting_down = false;
		public bool am_away {get; private set;}
		private int nick_tries = 0;
		private bool sent_ping = false;
		// Socket
		private SocketClient socket_client;
		private SocketConnection socket_conn;
		private DataInputStream socket_stream;
		public bool connecting = false;
		
		public class Channel : Object {
			public Topic topic;
			public ArrayList<string> raw_users = new ArrayList<string>();
			public ArrayList<string> users     = new ArrayList<string>();
			public bool userlist_recieved = true;
			public bool in_channel = true;
			public string mode = "";
			public bool got_create_date = false;
			public struct Topic {
				public string content;
				public string setter;
				public time_t time_set;
			}
			public string name = "";
			public Channel() {
				topic = Topic();
				topic.content  = "";
				topic.setter   = "";
				topic.time_set = (time_t)0;
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
			open_view(_("<server>"));
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
			irc_connect();
			
			notebook.switch_page.connect((page,page_num) => {
				Main.gui.update_gui(this,find_view_from_page_num((int)page_num));
				find_view_from_page_num((int)page_num).label.label = Markup.escape_text(find_view_from_page_num((int)page_num).name);
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
			if(socket_ready() && connected && !sock_error) {
				//add_to_view(_("<server>"),_("DEBUG -- socket ready");
				string s = null;
				try {
					s = socket_stream.read_line(null,null);
				} catch(Error e) {
					connected = false;
					sock_error = true;
					Main.gui.update_gui(this);
					add_to_view(_("<server>"),_("ERROR: error fetching line: %s").printf(e.message));
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
				//add_to_view(_("<server>"),_("DEBUG -- got: %s").printf(s));
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
					add_to_view(_("<server>"),_("Ping timeout. Reconnecting..."));
					last_recieved = time_t();
					irc_disconnect();
					irc_connect();
				}
			}
		}
		
		private bool socket_ready() {
			if(!connected || sock_error) {
				return false;
			} else if(socket_conn.socket == null) {
				return false;
			} else if(((socket_conn.socket.condition_check(IOCondition.IN) & IOCondition.IN) > 0) || ((socket_conn.socket.condition_check(IOCondition.PRI) & IOCondition.PRI) > 0)) {
				return true;
			} else {
				return false;
			}
		}
		
		public void irc_connect() {
			socket_connect_async.begin();
		}
		
		private async void socket_connect_async() {
			connecting = true;
			add_to_view(_("<server>"),_("[Connection] Starting connection attempt..."));
			Resolver resolver = Resolver.get_default();
			add_to_view(_("<server>"),_("[Connection] Resolving name %s...").printf(server));
			bool error = false;
			GLib.List<InetAddress> addresses = null;
			try {
#if WINDOWS
				addresses = resolver.lookup_by_name(server,null); // no async?
#else
				addresses = yield resolver.lookup_by_name_async(server,null);
#endif
			} catch(Error ee) { // TODO: report this bug, can not have two GLib.Errors with the same name in the same async method
				error = true;
			}
			if(error || addresses.length() < 1) {
				add_to_view(_("<server>"),_("[Connection] Error: could not look up host name."));
				connecting = false;
				connected = false;
				sock_error = true;
				return;
			}
			InetAddress address = addresses.nth_data(0);
			add_to_view(_("<server>"),_("[Connection] Resolved %s to %s.").printf(server,address.to_string()));
			socket_client = new SocketClient();
			try {
				socket_conn = yield socket_client.connect_async(new InetSocketAddress(address,(uint16)port),null);
				connected = true;
				sock_error = false;
			} catch(Error e) {
				connected = false;
				sock_error = true;
				add_to_view(_("<server>"),_("[Connection] Error: could not connect -- %s").printf(e.message));
				Main.server_manager.on_connect_error(this);
				Main.plugin_manager.on_connect_error(this);
				return;
			}
			connecting = false;
			add_to_view(_("<server>"),_("[Connection] Connected! Sending USER, NICK and PASS.").printf(port));
			socket_stream = new DataInputStream(socket_conn.input_stream);
	
			raw_send("USER %s rocks hard :%s".printf(Main.config["core"]["username"],Main.config["core"]["realname"]));
			raw_send("NICK %s".printf(Main.config["core"]["nickname"]));
			if(password != "") {
				send("PASS %s".printf(password));
			}
			Main.gui.update_gui(this);
			last_recieved = time_t();
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
						if(str.str.length >= 460) break;
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
						add_to_view(target,"*  %s %s".printf(nick,msg.replace("","").substring(7)));
					} else if(msg.has_prefix("")) {
						add_to_view(target,">%s< CTCP %s".printf(nick,msg.replace("","")));
					} else {
						add_to_view(target,"< %s> %s".printf(nick,msg));
					}
					OutgoingMessage outg = {prefix+i,priority};
					lock(output_queue) {
						output_queue.offer(outg);
					}
				}
			} else {
				OutgoingMessage outg = {s,priority};
				lock(output_queue) {
					output_queue.offer(outg);
				}
			}
		}
		
		private void raw_send(owned string s) {
			return_if_fail(connected);
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
				add_to_view(_("<server>"),_("Error sending line: %s").printf(e.message));
			}
		}
		
		private void* thread_func() {
			while(!shutting_down) {
				OutgoingMessage message;
				if(output_queue.size != 0) {
					lock(output_queue) {
						message = output_queue.poll();
					}
					Posix.usleep(((int)message.priority*1000));
					raw_send(message.message);
				}
				Posix.usleep(10);
			}
			return null;
		}
		
		private void handle_server_input(owned string s) {
			sent_ping = false;
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
							channel.name = message;
							open_view(message);
						}
						find_channel(message).in_channel = true;
						send("NAMES %s".printf(message));
						send("MODE "+message);
						Main.plugin_manager.on_join(this,usernick,username,usermask,message);
						break;
					case "PART":
						message = message == s ? "" : message;
						Main.plugin_manager.on_part(this,usernick,username,usermask,split[2],message);
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
							find_channel(split[2]).in_channel = false;
						} else {
							send("NAMES %s".printf(split[2]));
						}
						message = message == s ? "" : message;
						Main.plugin_manager.on_kick(this,split[3],usernick,username,usermask,split[2],message);
						break;
					case "NICK":
						if(nick.down() == usernick.down()) {
							nick = message;
							Main.gui.update_gui(this);
						}
						Main.plugin_manager.on_nick(this,message,usernick,username,usermask);
						foreach(Channel channel in channels) {
							if(usernick.down() in channel.users) {
								send("NAMES %s".printf(channel.name));
							}
						}
						foreach(GUI.View view in views) {
							if(view.name.down() == usernick.down()) {
								view.name = message;
								view.label.label = message;
							}
						}
						break;
					case "INVITE":
						add_to_view(_("<server>"),_("%s has invited you to %s.").printf(usernick,split[3]));
						break;
					case "001":
						foreach(Channel channel in channels) {
							if(!channel.in_channel) {
								send("JOIN %s".printf(channel.name));
							}
						}
						Main.plugin_manager.on_connect(this);
						Main.server_manager.on_connect(this);
						nick_tries = 0;
						nick = split[2];
						add_to_view(_("<server>"),_("[Server info] Welcome to the Internet Relay Network ")+nick);
						break;
					case "002":
					case "003":
						add_to_view(_("<server>"),_("[Server info] ")+message);
						break;
					case "004":
						add_to_view(_("<server>"),_("[Server info] Your server is %s running %s. Available user modes: %s. Available channel modes: %s").printf(split[3],split[4],split[5],split[6]));
						break;
					case "005":
						StringBuilder supported = new StringBuilder("");
						for(int i = 3; !split[i].has_prefix(":"); i++) {
							supported.append(split[i]).append(" ");
						}
						add_to_view(_("<server>"),_("[Server info] %s are supported by this server").printf(supported.str));
						break;
					case "PRIVMSG":
						Main.plugin_manager.on_privmsg(this,usernick,username,usermask,target,message);
						break;
					case "NOTICE":
						if(split[2] == "AUTH") {
							add_to_view(_("<server>"),_("[Auth] %s").printf(message));
						} else {
							Main.plugin_manager.on_notice(this,usernick,username,usermask,target,message);
							if(message.has_prefix(((char)1).to_string())) {
								message = message.replace(((char)1).to_string(),"");
								string prefix = message.split(" ")[0];
								message = message.substring(prefix.length);
								switch(prefix) {
									default:
										add_to_view(_("<server>"),_("UNHANDLED CTCP REPLY -- PREFIX: %s; SENDER: %s; MESSAGE: %s").printf(prefix,target,message));
										break;
								}
							} else {
							}
						}
						break;
					case "QUIT":
						Main.plugin_manager.on_quit(this,usernick,username,usermask,message);
						foreach(Channel channel in channels) {
							if(usernick.down() in channel.users) {
								send("NAMES %s".printf(channel.name));
							}
						}
						break;
					case "MODE":
						if(split[4] != null && !(/^[0-9]+$/.match(split[4]))) {
							string targets = string.joinv(" ",split[4:(split.length-1)]);
							Main.plugin_manager.on_chan_user_mode(this,usernick,username,usermask,split[2],split[3],targets);
							send("NAMES %s".printf(split[2]));
						} else if(split[2].has_prefix("#")) {
							string targets = string.joinv(" ",split[3:(split.length-1)]);
							Main.plugin_manager.on_chan_mode(this,usernick,username,usermask,split[2],targets);
							send("MODE %s".printf(split[2]));
						} else {
							Main.plugin_manager.on_mode(this,usernick,message);
						}
						break;
					case "TOPIC":
						Channel chan = find_channel(split[2]);
						chan.topic.setter = usernick;
						chan.topic.content = message;
						chan.topic.time_set = time_t();
						Main.plugin_manager.on_topic(this,usernick,username,usermask,chan.name,message);
						Main.gui.update_gui(this);
						break;
					case "333":
						Channel chan = find_channel(split[3]);
						chan.topic.setter = split[4];
						chan.topic.time_set = (time_t)split[5].to_int();
						add_to_view(split[3],_("Topic set by %s on %s").printf(split[4],gen_timestamp("%c",chan.topic.time_set)));
						break;
					/*case "305":
						am_away = false;
						break;
					case "306":
						am_away = true;
						break;*/
					// Error messages
					case "401":
						add_to_view(_("<server>"),_("[Error:401] No such nickname/channel: %s").printf(split[3]));
						break;
					case "402":
						add_to_view(_("<server>"),_("[Error:402] No such server: %s").printf(split[3]));
						break;
					case "403":
						add_to_view(_("<server>"),_("[Error:403] No such channel: %s").printf(split[3]));
						break;
					case "404":
						add_to_view(_("<server>"),_("[Error:404] Cannot send to channel: %s").printf(split[3]));
						break;
					case "405":
						add_to_view(_("<server>"),_("[Error:405] Cannot join %s: joined too many channels.").printf(split[3]));
						break;
					case "406":
						add_to_view(_("<server>"),_("[Error:406] There was no such nickname: %s").printf(split[3]));
						break;
					case "407":
						add_to_view(_("<server>"),_("[Error:407] Too many targets for notice/message."));
						break;
					case "408":
						add_to_view(_("<server>"),_("[Error:408] No such service: %s").printf(split[3]));
						break;
					case "409":
						add_to_view(_("<server>"),_("[Error:409] No origin specified."));
						break;
					case "411":
						add_to_view(_("<server>"),_("[Error:411] No recipient given for command."));
						break;
					case "412":
						add_to_view(_("<server>"),_("[Error:412] No text to send."));
						break;
					case "413":
						add_to_view(_("<server>"),_("[Error:413] No toplevel domain specified for mask %s").printf(split[3]));
						break;
					case "414":
						add_to_view(_("<server>"),_("[Error:414] Wildcard in toplevel domain in mask %s").printf(split[3]));
						break;
					case "415":
						add_to_view(_("<server>"),_("[Error:415] Bad server/host mask: %s").printf(split[3]));
						break;
					case "421":
						add_to_view(_("<server>"),_("[Error:421] Unknown command: %s").printf(split[3]));
						break;
					case "422":
						add_to_view(_("<server>"),_("[MOTD] MOTD file missing"));
						break;
					case "423":
						add_to_view(_("<server>"),_("[Admin] No admin info available for server %s").printf(split[3]));
						break;
					case "424":
						add_to_view(_("<server>"),_("[Error:424] File error."));
						break;
					case "431":
						add_to_view(_("<server>"),_("[Error:431] No nickname given."));
						break;
					case "432":
						add_to_view(_("<server>"),_("[Error:432] Illegal nickname given."));
						break;
					case "433":
						nick_tries++;
						StringBuilder new_nick = new StringBuilder(nick);
						for(int i = 0; i < nick_tries; i++) {
							new_nick.append("_");
						}
						send("NICK %s".printf(new_nick.str));
						add_to_view(_("<server>"),_("[Error:433] Nickname %s already in use.").printf(nick));
						break;
					case "436":
						add_to_view(_("<server>"),_("[Error:436] Nickname collision kill."));
						break;
					case "437":
						add_to_view(_("<server>"),_("[Error:437] Nick/channel temporarily unavailable: %s").printf(split[3]));
						break;
					case "441":
						add_to_view(_("<server>"),_("[Error:441] %s isn't in channel %s.").printf(split[3],split[4]));
						break;
					case "442":
						add_to_view(_("<server>"),_("[Error:442] You're not in channel %s.").printf(split[3]));
						break;
					case "443":
						add_to_view(_("<server>"),_("[Error:443] %s is already in channel %s.").printf(split[3],split[4]));
						break;
					case "444":
						add_to_view(_("<server>"),_("[Error:444] User %s is not logged in.").printf(split[3]));
						break;
					case "445":
						add_to_view(_("<server>"),_("[Error:445] SUMMON has been disabled."));
						break;
					case "446":
						add_to_view(_("<server>"),_("[Error:446] USERS has been disabled."));
						break;
					case "451":
						add_to_view(_("<server>"),_("[Error:451] You have not registered."));
						break;
					case "461":
						add_to_view(_("<server>"),_("[Error:461] Not enough parameters for command %s.").printf(split[3]));
						break;
					case "462":
						add_to_view(_("<server>"),_("[Error:462] You have already registered."));
						break;
					case "463":
						add_to_view(_("<server>"),_("[Error:463] Your host is not priviledged."));
						break;
					case "464":
						add_to_view(_("<server>"),_("[Error:464] Password incorrect."));
						break;
					case "465":
						add_to_view(_("<server>"),_("[Error:465] You are banned from this server."));
						break;
					case "466":
						add_to_view(_("<server>"),_("[Error:466] You will be banned from this server."));
						break;
					case "467":
						add_to_view(_("<server>"),_("[Error:467] The key for channel %s has already been set.").printf(split[3]));
						break;
					case "471":
						add_to_view(_("<server>"),_("[Error:471] Cannot join channel %s: channel is full (+l)").printf(split[3]));
						break;
					case "472":
						add_to_view(_("<server>"),_("[Error:472] The server does not recognize the mode char %s.").printf(split[3]));
						break;
					case "473":
						add_to_view(_("<server>"),_("[Error:473] Cannot join channel %s: channel is invite-only (+i)").printf(split[3]));
						break;
					case "474":
						add_to_view(_("<server>"),_("[Error:474] Cannot join channel %s: you are banned (+b)").printf(split[3]));
						break;
					case "475":
						add_to_view(_("<server>"),_("[Error:475] Cannot join channel %s: bad key.").printf(split[3]));
						break;
					case "476":
						add_to_view(_("<server>"),_("[Error:476] Bad channel mask for %s.").printf(split[3]));
						break;
					case "477":
						add_to_view(_("<server>"),_("[Error:477] The channel %s does not support modes.").printf(split[3]));
						break;
					case "478":
						if(split[4] == "b") {
							add_to_view(_("<server>"),_("[Error:478] Channel %s's ban list is full.").printf(split[3]));
						} else {
							add_to_view(_("<server>"),_("[Error:478] Channel %s's exceptions list is full.").printf(split[3]));
						}
						break;
					case "481":
						add_to_view(_("<server>"),_("[Error:481] Permission denied: you are not an IRC operator."));
						break;
					case "482":
						add_to_view(_("<server>"),_("[Error:482] You're not an operator in %s").printf(split[3]));
						break;
					case "483":
						add_to_view(_("<server>"),_("[Error:483] You cannot kill a server."));
						break;
					case "491":
						add_to_view(_("<server>"),_("[Error:491] No O-lines for your host."));
						break;
					case "501":
						add_to_view(_("<server>"),_("[Error:501] Unknown mode flag."));
						break;
					case "502":
						add_to_view(_("<server>"),_("[Error:502] Cannot view or set the mode for other users."));
						break;
					// Command responses
					case "302":
						string name = message.split("=")[0];
						add_to_view(_("<server>"),_("[Userhost] %s: %s").printf(name,message));
						break;
					case "303":
						add_to_view(_("<server>"),_("[ISON] %s is on").printf(message));
						break;
					case "301":
						add_to_view(_("<server>"),_("[WHOIS] %s is away: %s").printf(split[3],message));
						break;
					case "305":
						add_to_view(_("<server>"),_("[Away] You are no longer marked as away."));
						am_away = false;
						break;
					case "306":
						add_to_view(_("<server>"),_("[Away] You are now marked as away."));
						am_away = true;
						break;
					case "311":
						add_to_view(_("<server>"),_("[WHOIS] %s: %s@%s: %s").printf(split[3],split[4],split[5],message));
						break;
					case "312":
						add_to_view(_("<server>"),_("[WHOIS] %s: in server %s: %s").printf(split[3],split[4],message));
						break;
					case "313":
						add_to_view(_("<server>"),_("[WHOIS] %s: is an IRCop").printf(split[3]));
						break;
					case "317":
						add_to_view(_("<server>"),_("[WHOIS] %s: %s seconds idle").printf(split[3],split[4]));
						break;
					case "318":
						add_to_view(_("<server>"),_("[WHOIS] %s: end of /WHOIS list.").printf(split[3]));
						break;
					case "319":
						add_to_view(_("<server>"),_("[WHOIS] %s: in channels %s").printf(split[3],message));
						break;
					case "307":
						add_to_view(_("<server>"),_("[WHOIS] %s: is a registered nickname").printf(split[3]));
						break;
					case "314":
						add_to_view(_("<server>"),_("[WHOWAS] %s: %s@%s: %s").printf(split[3],split[4],split[5],message));
						break;
					case "369":
						add_to_view(_("<server>"),_("[WHOWAS] %s: end of /WHOWAS list.").printf(split[3]));
						break;
					case "321":
						add_to_view(_("<server>"),_("[List] Channel (Users) Topic"));
						break;
					case "322":
						add_to_view(_("<server>"),_("[List] %s (%s) %s").printf(split[3],split[4],message));
						break;
					case "323":
						add_to_view(_("<server>"),_("[List] end of /LIST."));
						break;
					case "324":
						Channel chan = find_channel(split[3]);
						chan.mode = string.joinv(" ",split[4:(split.length-1)]);
						Main.gui.update_gui(this);
						break;
					case "331":
						add_to_view(split[2],_("No topic is set"));
						break;
					case "329":
						if(find_channel(split[3]) != null && !find_channel(split[3]).got_create_date) {
							add_to_view(split[3],_("Channel was created %s").printf(gen_timestamp("%c",(time_t)split[4].to_int())));
							find_channel(split[3]).got_create_date = true;
						}
						break;
					case "332":
						Channel chan = find_channel(split[3]);
						chan.topic.content = message;
						add_to_view(split[3],_("The topic is: %s").printf(message));
						Main.gui.update_gui(this);
						break;
					case "341":
						add_to_view(_("<server>"),_("[Invite] inviting %s to %s").printf(split[3],split[4]));
						break;
					case "342":
						add_to_view(_("<server>"),_("[Summon] summoning %s to IRC").printf(split[3]));
						break;
					case "351":
						add_to_view(_("<server>"),_("Server version: %s; server software: %s; %s").printf(split[3],split[4],message));
						break;
					case "352":
						add_to_view(_("<server>"),_("[WHO] %s: %s!%s@%s in server %s (%s) %s").printf(split[3],split[7],split[4],split[5],split[6],split[8],message));
						break;
					case "315":
						add_to_view(_("<server>"),_("[WHO] in %s: end of /WHO list.").printf(split[3]));
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
						add_to_view(_("<server>"),_("[Links] %s %s :%s").printf(split[3],split[4],message));
						break;
					case "365":
						add_to_view(_("<server>"),_("[Links] end of /LINKS list."));
						break;
					case "367":
						add_to_view(_("<server>"),_("[Banlist] %s: %s").printf(split[3],split[4]));
						break;
					case "368":
						add_to_view(_("<server>"),_("[Banlist] %s: end of ban (mode +b) list."));
						break;
					case "348":
						add_to_view(_("<server>"),_("[Exceptions] %s: %s").printf(split[3],split[4]));
						break;
					case "349":
						add_to_view(_("<server>"),_("[Exceptions] %s: end of exceptions (mode +e) list."));
						break;
					case "371":
						add_to_view(_("<server>"),_("[Info] %s").printf(message));
						break;
					case "374":
						add_to_view(_("<server>"),_("[Info] end of /INFO list."));
						break;
					case "375":
						add_to_view(_("<server>"),_("[MOTD] %s:").printf(server));
						break;
					case "372":
						add_to_view(_("<server>"),_("[MOTD] ")+message);
						break;
					case "376":
						add_to_view(_("<server>"),_("[MOTD] End of /MOTD command."));
						break;
					case "381":
						add_to_view(_("<server>"),_("[Oper] You are now an IRCop."));
						break;
					case "382":
						add_to_view(_("<server>"),_("[Rehash] Rehashing config file %s.").printf(split[3]));
						break;
					case "391":
						add_to_view(_("<server>"),_("[Time] Server's local time: %s").printf(message));
						break;
					/* TODO: implement 200, 201, 202, 203, 204, 205, 206, 208,
					         261, 211, 212, 213, 214, 215, 216, 218, 219, 241,
					         242, 243, 244 */
					case "221":
						add_to_view(_("<server>"),_("[Mode] Your mode is: %s").printf(split[3]));
						break;
					case "251":
						add_to_view(_("<server>"),_("[Server info] %s").printf(message));
						break;
					case "252":
						add_to_view(_("<server>"),_("[Server info] %s operator(s) online").printf(split[3]));
						break;
					case "253":
						add_to_view(_("<server>"),_("[Server info] %s unknown connection(s)").printf(split[3]));
						break;
					case "254":
						add_to_view(_("<server>"),_("[Server info] %s channels formed").printf(split[3]));
						break;
					case "255":
					case "265":
					case "266":
						add_to_view(_("<server>"),_("[Server info] %s").printf(message));
						break;
					case "256":
						add_to_view(_("<server>"),_("[Admin] Administrative info for %s:").printf(split[3]));
						break;
					case "257":
						add_to_view(_("<server>"),_("[Admin] ")+message);
						break;
					case "258":
						add_to_view(_("<server>"),_("[Admin] ")+message);
						break;
					case "259":
						add_to_view(_("<server>"),_("[Admin] ")+message);
						break;
					default:
						add_to_view(_("<server>"),_("UNHANDLED MESSAGE: %s").printf(s));
						break;
				}
			}
		}
		
		// Misc utility
		public Channel? find_channel(string s) {
			foreach(Channel channel in this.channels) {
				if(channel.name.down() == s.down()) {
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
		
		public GUI.View? find_view(string name) {
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
			if(view == null || view.name == _("<server>")) {
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
