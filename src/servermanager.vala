/*
 * servermanager.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class ServerManager : Object {
		public class Network {
			public class ServerData {
				public string  address;
				public int     port;
				public bool    ssl;
				public string? password;
			}
			
			public string name;
			public LinkedList<ServerData?> servers = new LinkedList<ServerData?>();
			public LinkedList<string> commands    = new LinkedList<string>();
			public bool auto_connect;
			public int server_index = 0;
		}
		
		public LinkedList<Network> networks = new LinkedList<Network>();
		public ArrayList<Server> servers = new ArrayList<Server>();
		public KeyFile raw_conf = new KeyFile();
		public bool loaded_networks = false;
		
		public ServerManager() {
			stdout.printf("Loading networks\n");
			// Checking if networks.conf exists, and trying to load it
			if(FileUtils.test(Environment.get_user_config_dir()+"/xsirc/networks.conf",FileTest.EXISTS)) {
				try {
					raw_conf.load_from_file(Environment.get_user_config_dir()+"/xsirc/networks.conf",KeyFileFlags.KEEP_COMMENTS);
				} catch(KeyFileError e) {
					stderr.printf("Could not parse networks.conf\n");
				} catch(FileError e) {
					stderr.printf("Could not open networks.conf\n");
				}
			} else {
				stderr.printf("No networks.conf file found\n");
			}
			
			// Loading all networks
			foreach(string net_name in raw_conf.get_groups()) {
				loaded_networks = true;
				bool skip = false;
				string[] needed_keys = {"server0","autoconnect"};
				try {
					foreach(string key in needed_keys) {
						if(!raw_conf.has_key(net_name,key)) {
							stderr.printf("Could not parse network %s!\n",net_name);
							skip = true;
							break;
						}
					}
					if(skip) { continue; }
					Network network = new Network();
					network.name = net_name;
					for(int curr_server = 0;raw_conf.has_key(net_name,"server%d".printf(curr_server));curr_server++) {
						Network.ServerData server = new Network.ServerData();
						if(!Regex.match_simple("^(irc|sirc):\\/\\/[a-zA-Z0-9-_.]+:\\d+",raw_conf.get_string(net_name,"server%d".printf(curr_server)))) {
							stderr.printf("Could not parse server #%d in network %s!\n",curr_server,net_name);
							continue;
						}
						string[] split_server = raw_conf.get_string(net_name,"server%d".printf(curr_server)).split(" ");
						string server_data = split_server[0];
						if(split_server.length > 1) {
							server.password = string.joinv(" ",split_server[1:split_server.length-1]);
						} else {
							server.password = null;
						}
						string[] split_server_data = Regex.split_simple("(:\\/\\/|:)",server_data);
						server.ssl     = split_server_data[0] == "ircs";
						server.port    = int.parse(split_server_data[4]);
						server.address = split_server_data[2];
						network.servers.add(server);
					}
					network.auto_connect = raw_conf.get_boolean(net_name,"autoconnect");
					for(int curr_cmd = 0;raw_conf.has_key(net_name,"command%d".printf(curr_cmd));curr_cmd++) {
						network.commands.add(raw_conf.get_string(net_name,"command%d".printf(curr_cmd)));
					}
					networks.add(network);
				} catch(KeyFileError e) {
					stderr.printf("Error loading network: %s\n",e.message);
				}
				// Iterator thing
				TimeoutSource src = new TimeoutSource(100);
				src.set_callback(server_manager_iterator);
				src.attach(null);
			}
		}
		
		public void save_networks() {
			raw_conf = new KeyFile();
			foreach(Network network in networks) {
				raw_conf.set_boolean(network.name,"autoconnect",network.auto_connect);
				for(int i = 0;i < network.servers.size; i++) {
					StringBuilder s = new StringBuilder("irc");
					if(network.servers[i].ssl) {
						s.append("s");
					}
					s.append("://").append(network.servers[i].address).append(":").append(network.servers[i].port.to_string());
					if(network.servers[i].password != null) {
						s.append(" ").append(network.servers[i].password);
					}
					raw_conf.set_string(network.name,"server%d".printf(i),s.str);
				}
				for(int i = 0;i < network.commands.size; i++) {
					raw_conf.set_string(network.name,"command%d".printf(i),network.commands[i]);
				}
			}
			try {
				FileUtils.set_contents(Environment.get_user_config_dir()+"/xsirc/networks.conf",raw_conf.to_data());
			} catch(Error e) {
				
			}
		}
		
		public Network? find_network(string name) {
			foreach(Network network in networks) {
				if(network.name == name) {
					return network;
				}
			}
			return null;
		}
		
		public void startup() {
			foreach(Network network in networks) {
				stdout.printf("Iterating through network %s\n",network.name);
				if(!network.auto_connect) {
					continue;
				}
				Network.ServerData server = network.servers[0];
				open_server(server.address,server.port,server.ssl,(server.password ?? ""),network);
			}
		}
		
		public void iterate() {
			foreach(Server server in servers) {
				server.iterate();
			}
		}
		
		public void shutdown() {
			foreach(Server server in servers) {
				server.shutdown();
			}
		}
		
		public void open_server(string address,int port = 6667,bool ssl = false,string password = "",Network? network = null) {
			Server server = new Server(address,port,ssl,password,network);
			servers.add(server);
			Main.gui.servers_notebook.append_page(server.notebook,server.label);
			Main.gui.servers_notebook.show_all();
			Main.gui.servers_notebook.page = Main.gui.servers_notebook.page_num(server.notebook);
		}
		
		public void on_connect(Server server) requires (server.network != null) {
			foreach(string command in server.network.commands) {
				server.send(command.replace("$nick",server.nick));
			}
		}
		
		public void on_connect_error(Server server) requires (server.network != null) {
			server.network.server_index++;
			if((server.network.servers.size - 1) >= server.network.server_index) {
				server.irc_disconnect();
				Network.ServerData new_server = server.network.servers[server.network.server_index];
				server.add_to_view(_("<server>"),_("[Connection] Switching to server %s").printf(new_server.address));
				server.server  = new_server.address;
				server.port    = new_server.port;
				server.ssl     = new_server.ssl;
				server.password= new_server.password;
				server.label.label = Markup.escape_text("%s - %s".printf(server.network.name,server.server));
				server.irc_connect();
			} else {
				server.add_to_view(_("<server>"),_("[Error] No more servers to connect to."));
			}
		}
	}
	
	// Iterator
	bool server_manager_iterator() {
		Main.server_manager.iterate();
		return true;
	}
}
