/*
 * prefwindow.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class PrefWindow : Object {
		private Gtk.Dialog window;
		private Gtk.Builder ui_builder;
		private Gtk.ListStore network_store = new Gtk.ListStore(1,typeof(string));
		private Gtk.ListStore server_store  = new Gtk.ListStore(1,typeof(string));
		private Gtk.ListStore cmd_store     = new Gtk.ListStore(1,typeof(string));
		private Gtk.TreeView network_tree;
		private Gtk.TreeView server_tree;
		private Gtk.TreeView cmd_tree;
		private Gtk.CheckButton network_ac;
		public PrefWindow() {
			ui_builder = new Gtk.Builder();
			try {
				ui_builder.add_from_file(PREFIX+"/share/xsirc/prefwindow.ui");
			} catch(Error e) {
				Posix.exit(Posix.EXIT_FAILURE);
			}
			window = ui_builder.get_object("dialog1") as Gtk.Dialog;
			// Setting all the widget's contents according to current settings
			((Gtk.Entry)ui_builder.get_object("nickname")).text = Main.config["core"]["nickname"];
			((Gtk.Entry)ui_builder.get_object("username")).text = Main.config["core"]["username"];
			((Gtk.Entry)ui_builder.get_object("realname")).text = Main.config["core"]["realname"];
			((Gtk.Entry)ui_builder.get_object("quit_msg")).text = Main.config["core"]["quit_msg"];
			((Gtk.Entry)ui_builder.get_object("away_msg")).text = Main.config["core"]["away_msg"];
			((Gtk.Entry)ui_builder.get_object("web_browser")).text = Main.config["core"]["web_browser"];
			((Gtk.Entry)ui_builder.get_object("timestamp_format")).text = Main.config["core"]["timestamp_format"];
			((Gtk.Entry)ui_builder.get_object("log_date_format")).text = Main.config["core"]["log_date_format"];
			
			((Gtk.CheckButton)ui_builder.get_object("logging")).active = IRCLogger.logging_enabled;
			((Gtk.FontButton)ui_builder.get_object("font")).font_name = Main.config["core"]["font"];
			// Setting up the tree views
			network_tree = ((Gtk.TreeView)ui_builder.get_object("network_tree"));
			server_tree  = ((Gtk.TreeView)ui_builder.get_object("server_tree"));
			cmd_tree     = ((Gtk.TreeView)ui_builder.get_object("command_tree"));
			network_ac   = ((Gtk.CheckButton)ui_builder.get_object("autoconnect"));
			
			network_ac.toggled.connect(() => {
				if(get_current_network() != null) {
					Main.server_manager.find_network(get_current_network()).auto_connect = network_ac.active;
				}
			});
			
			Gtk.CellRendererText net_renderer = new Gtk.CellRendererText();
			net_renderer.editable = true;
			net_renderer.edited.connect(network_edited);
			Gtk.TreeViewColumn network_col = new Gtk.TreeViewColumn.with_attributes("Networks",net_renderer,"text",0,null);
			network_tree.append_column(network_col);
			network_tree.model = network_store;
			Gtk.TreeSelection network_selection = network_tree.get_selection();
			network_selection.changed.connect(network_changed);
			init_network_tree();
			
			Gtk.CellRendererText server_renderer = new Gtk.CellRendererText();
			server_renderer.editable = true;
			server_renderer.edited.connect(server_edited);
			Gtk.TreeViewColumn server_col  = new Gtk.TreeViewColumn.with_attributes("Servers",server_renderer,"text",0,null);
			server_tree.append_column(server_col);
			server_tree.model = server_store;
			
			Gtk.CellRendererText cmd_renderer = new Gtk.CellRendererText();
			cmd_renderer.editable = true;
			cmd_renderer.edited.connect(cmd_edited);
			Gtk.TreeViewColumn cmd_col     = new Gtk.TreeViewColumn.with_attributes("Commands",cmd_renderer,"text",0,null);
			cmd_tree.append_column(cmd_col);
			cmd_tree.model = cmd_store;
			
			// Setting up the add/remove buttons for networks/servers/commands
			((Gtk.Button)ui_builder.get_object("network_add")).clicked.connect(() => {
				ServerManager.Network new_network = new ServerManager.Network();
				new_network.name = "New Network";
				new_network.auto_connect = false;
				Main.server_manager.networks.add(new_network);
				init_network_tree();
			});
			((Gtk.Button)ui_builder.get_object("network_remove")).clicked.connect(() => {
				ServerManager.Network network = null;
				if((get_current_network() != null) && (network = Main.server_manager.find_network(get_current_network())) != null) {
					Gtk.MessageDialog d = new Gtk.MessageDialog(window,
					                                            Gtk.DialogFlags.MODAL,
					                                            Gtk.MessageType.QUESTION,
					                                            Gtk.ButtonsType.YES_NO,
					                                            "Are you sure? You cannot undo this.");
					d.response.connect((id) => {
						if(id == Gtk.ResponseType.YES) {
							Main.server_manager.networks.remove(network);
							init_network_tree();
						}
						d.destroy();
					});
					d.show_all();
				}
			});
			((Gtk.Button)ui_builder.get_object("network_connect")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					if(network.servers.size != 0) {
						ServerManager.Network.ServerData server = network.servers[0];
						Main.server_manager.open_server(server.address,server.port,server.ssl,(server.password ?? ""),network);
					}
				}
			});
			((Gtk.Button)ui_builder.get_object("server_add")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					ServerManager.Network.ServerData server = ServerManager.Network.ServerData();
					server.address = "irc.example.org";
					server.port    = 6667;
					server.ssl     = false;
					server.password= null;
					network.servers.add(server);
				}
				network_changed();
			});
			((Gtk.Button)ui_builder.get_object("server_remove")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					Gtk.TreeModel model;
					Gtk.TreeIter  iter;
					string        server_address;
					Gtk.TreeSelection sel = server_tree.get_selection();
					if(sel.get_selected(out model,out iter)) {
						model.get(iter,0,out server_address,-1);
						ServerManager.Network.ServerData wanted_server = {};
						foreach(ServerManager.Network.ServerData server in network.servers) {
							if(server.address == server_address.split(":")[1]) {
								wanted_server = server;
								break;
							}
						}
						network.servers.remove(wanted_server);
						network_changed();
					}
				}
			});
			((Gtk.Button)ui_builder.get_object("command_add")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					network.commands.add("new command");
					network_changed();
				}
			});
			((Gtk.Button)ui_builder.get_object("command_remove")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					Gtk.TreeModel model;
					Gtk.TreeIter  iter;
					string        command;
					Gtk.TreeSelection sel = cmd_tree.get_selection();
					if(sel.get_selected(out model,out iter)) {
						model.get(iter,0,out command,-1);
						network.commands.remove_at(network.commands.index_of(command));
						network_changed();
					}
				}
			});
			window.response.connect((id) => {
				Main.config["core"]["nickname"] = ((Gtk.Entry)ui_builder.get_object("nickname")).text;
				Main.config["core"]["username"] = ((Gtk.Entry)ui_builder.get_object("username")).text;
				Main.config["core"]["realname"] = ((Gtk.Entry)ui_builder.get_object("realname")).text;
				Main.config["core"]["quit_msg"] = ((Gtk.Entry)ui_builder.get_object("quit_msg")).text;
				Main.config["core"]["away_msg"] = ((Gtk.Entry)ui_builder.get_object("away_msg")).text;
				Main.config["core"]["web_browser"] = ((Gtk.Entry)ui_builder.get_object("web_browser")).text;
				Main.config["core"]["timestamp_format"] = ((Gtk.Entry)ui_builder.get_object("timestamp_format")).text;
				Main.config["core"]["log_date_format"] = ((Gtk.Entry)ui_builder.get_object("log_date_format")).text;
		
				IRCLogger.logging_enabled   = ((Gtk.CheckButton)ui_builder.get_object("logging")).active ? true : false;
				Main.config["core"]["font"] = ((Gtk.FontButton)ui_builder.get_object("font")).font_name;
				Main.config_manager.save_settings();
				Main.server_manager.save_networks();
				// Updating the fonts
				Main.gui.system_view.text_view.modify_font(Pango.FontDescription.from_string(Main.config["core"]["font"]));
				foreach(Server server in Main.server_manager.servers) {
					foreach(GUI.View view in server.views) {
						view.text_view.modify_font(Pango.FontDescription.from_string(Main.config["core"]["font"]));
					}
				}
				window.destroy();
				Main.gui.destroy_prefs_window();
			});
			
			window.show_all();
		}
		
		private void init_network_tree() {
			network_store.clear();
			Gtk.TreeIter iter;
			foreach(ServerManager.Network network in Main.server_manager.networks) {
				network_store.append(out iter);
				network_store.set(iter,0,network.name,-1);
			}
		}
		
		private void network_changed() {
			Gtk.TreeModel model;
			Gtk.TreeIter  iter;
			string        network_name;
			Gtk.TreeSelection sel = network_tree.get_selection();
			if(sel.get_selected(out model,out iter)) {
				model.get(iter,0,out network_name,-1);
				ServerManager.Network network = Main.server_manager.find_network(network_name);
				// Clearing the rows first
				server_store.clear();
				cmd_store.clear();
				Gtk.TreeIter s_iter;
				foreach(ServerManager.Network.ServerData server in network.servers) {
					StringBuilder server_str = new StringBuilder();
					(server.ssl ? server_str.append("ircs://") : server_str.append("irc://"));
					server_str.append(server.address).append(":").append(server.port.to_string());
					if(server.password != null) {
						server_str.append(" ").append(server.password);
					}
					server_store.append(out s_iter);
					server_store.set(s_iter,0,server_str.str,-1);
				}
				Gtk.TreeIter c_iter;
				LinkedList<string> clist = new LinkedList<string>();
				foreach(string command in network.commands) {
					cmd_store.append(out c_iter);
					cmd_store.set(c_iter,0,command,-1);
				}
				network_ac.active = network.auto_connect;
			} else {
				network_ac.active = false;
				server_store.clear();
				cmd_store.clear();
			}
		}
		
		private string? get_current_network() {
			Gtk.TreeModel model;
			Gtk.TreeIter  iter;
			string        network_name;
			Gtk.TreeSelection sel = network_tree.get_selection();
			if(sel.get_selected(out model,out iter)) {
				model.get(iter,0,out network_name,-1);
				return network_name;
			} else {
				return null;
			}
		}
		
		private void network_edited(string path,string new_text) {
			Gtk.TreeIter iter;
			string old_net_name;
			if(network_store.get_iter_from_string(out iter,path)) {
				network_store.get(iter,0,out old_net_name,-1);
				foreach(ServerManager.Network network in Main.server_manager.networks) {
					if(network.name == new_text) {
						return;
					}
				}
				ServerManager.Network network = Main.server_manager.find_network(old_net_name);
				network.name = new_text;
				network_store.set(iter,0,new_text,-1);
			}
		}
		
		private void server_edited(string path,string new_text) {
			if(/^ircs?:\/\/[a-zA-Z0-9\-_.]+:[0-9]+( .+)?$/.match(new_text)) {
				string[] split = new_text.split(" ");
				string raw_address = split[0];
				string password;
				if(split.length > 1) {
					password = string.joinv(" ",split[1:split.length-1]);
				} else {
					password = null;
				}
				bool ssl = new_text.has_prefix("ircs://");
				string address = raw_address.split(":")[1].substring(2);
				int port = raw_address.split(":")[2].to_int();
				
				Gtk.TreeIter iter;
				string old_server_address;
				if(server_store.get_iter_from_string(out iter,path)) {
					server_store.get(iter,0,out old_server_address,-1);
					old_server_address = old_server_address.split(":")[1].substring(2);
					ServerManager.Network network = Main.server_manager.find_network(get_current_network());
					foreach(ServerManager.Network.ServerData server in network.servers) {
						if(server.address == old_server_address) {
							server.address  = address;
							server.ssl      = ssl;
							server.port     = port;
							server.password = password;
							break;
						}
					}
					server_store.set(iter,0,new_text,-1);
				}	
			} else {
				Gtk.MessageDialog d = new Gtk.MessageDialog(window,
				                                            Gtk.DialogFlags.MODAL,
				                                            Gtk.MessageType.ERROR,
				                                            Gtk.ButtonsType.CLOSE,
				                                            "The string entered isn't a valid server URL.");
				d.response.connect((id) => {d.destroy();});
				d.show_all();
			}
		}
		
		private void cmd_edited(string path,string new_text) {
			Gtk.TreeIter iter;
			string old_cmd;
			if(cmd_store.get_iter_from_string(out iter,path)) {
				cmd_store.get(iter,0,out old_cmd,-1);
				ServerManager.Network network = Main.server_manager.find_network(get_current_network());
				network.commands[network.commands.index_of(old_cmd)] = new_text;
				cmd_store.set(iter,0,new_text,-1);
			}
		}
	}
}
