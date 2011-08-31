/*
 * networklist.vala
 *
 * Copyright (c) 2011 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class NetworkList : Object {
		public Gtk.Dialog dialog;
		private Gtk.Builder builder;

		private Gtk.TreeView network_tree;
		private Gtk.TreeView command_tree;
		private Gtk.TreeView server_tree;

		private Gtk.TreeViewColumn network_col;
		private Gtk.TreeViewColumn command_col;
		private Gtk.TreeViewColumn server_col;

		private Gtk.ListStore network_model = new Gtk.ListStore(1,typeof(string));
		private Gtk.ListStore command_model = new Gtk.ListStore(1,typeof(string));
		private Gtk.ListStore server_model  = new Gtk.ListStore(1,typeof(string));
		
		private Gtk.CheckButton auto_connect;

		public NetworkList() {
			builder = new Gtk.Builder();
			try {
				builder.add_from_file(get_file_path("share", "networks.ui"));
			} catch(Error e) {
				Posix.exit(Posix.EXIT_FAILURE);
			}
			
			dialog = builder.get_object("dialog1") as Gtk.Dialog;
			
			// Network
			
			network_tree = builder.get_object("network_list") as Gtk.TreeView;
			network_tree.model = network_model;

			Gtk.CellRendererText network_renderer = new Gtk.CellRendererText();
			network_renderer.editable = true;
			network_renderer.edited.connect(network_edited);
			network_col = new Gtk.TreeViewColumn.with_attributes(_("Networks"),network_renderer,"text",0,null);
			network_tree.append_column(network_col);
			Gtk.TreeSelection network_sel = network_tree.get_selection();
			network_sel.changed.connect(network_changed);
			
			// Commands
			
			command_tree = builder.get_object("command_list") as Gtk.TreeView;
			command_tree.model = command_model;

			Gtk.CellRendererText command_renderer = new Gtk.CellRendererText();
			command_renderer.editable = true;
			command_renderer.edited.connect(command_edited);
			command_col = new Gtk.TreeViewColumn.with_attributes(_("Commands"),command_renderer,"text",0,null);
			command_tree.append_column(command_col);
			
			// Servers
			
			server_tree = builder.get_object("server_list") as Gtk.TreeView;
			server_tree.model = server_model;

			Gtk.CellRendererText server_renderer = new Gtk.CellRendererText();
			server_renderer.editable = true;
			server_renderer.edited.connect(server_edited);
			server_col = new Gtk.TreeViewColumn.with_attributes(_("Servers"),server_renderer,"text",0,null);
			server_tree.append_column(server_col);
			
			// Network add/remove/connect
			
			((Gtk.Button)builder.get_object("add_network")).clicked.connect(() => {
				ServerManager.Network new_network = new ServerManager.Network();
				new_network.name = _("New Network");
				new_network.auto_connect = false;
				Main.server_manager.networks.add(new_network);
				Gtk.TreeIter iter;
				network_model.append(out iter);
				network_model.set(iter,0,new_network.name);
				Gtk.TreeSelection sel = network_tree.get_selection();
				sel.unselect_all();
				sel.select_iter(iter);
				network_tree.set_cursor(network_model.get_path(iter),network_col,true);
			});
			
			((Gtk.Button)builder.get_object("remove_network")).clicked.connect(() => {
				ServerManager.Network network = null;
				if((get_current_network() != null) && (network = Main.server_manager.find_network(get_current_network())) != null) {
					Gtk.MessageDialog d = new Gtk.MessageDialog(dialog,
					                                            Gtk.DialogFlags.MODAL,
					                                            Gtk.MessageType.QUESTION,
					                                            Gtk.ButtonsType.YES_NO,
					                                            "%s",
					                                            _("Are you sure? You cannot undo this."));
					d.response.connect((id) => {
						if(id == Gtk.ResponseType.YES) {
							Main.server_manager.networks.remove(network);
							Gtk.TreeSelection sel = network_tree.get_selection();
							Gtk.TreeModel model;
							Gtk.TreeIter iter;
							if(sel.get_selected(out model,out iter)) {
								network_model.remove(iter);
							}
						}
						d.destroy();
					});
					d.show_all();
				}
			});
			
			((Gtk.Button)builder.get_object("connect")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					// TODO: use the currently selected server
					if(network.servers.size != 0) {
						ServerManager.Network.ServerData server = network.servers[0];
						Main.server_manager.open_server(server.address,server.port,server.ssl,(server.password ?? ""),network);
					}
				}
			});
			
			((Gtk.Button)builder.get_object("add_server")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					ServerManager.Network.ServerData server = new ServerManager.Network.ServerData();
					server.address  = "irc.example.org";
					server.port     = 6667;
					server.ssl      = false;
					server.password = null;
					network.servers.add(server);
					Gtk.TreeIter iter;
					server_model.append(out iter);
					server_model.set(iter,0,"irc://irc.example.org:6667",-1);
					Gtk.TreeSelection sel = server_tree.get_selection();
					sel.unselect_all();
					sel.select_iter(iter);
					server_tree.set_cursor(server_model.get_path(iter),server_col,true);
				}
			});
			
			((Gtk.Button)builder.get_object("remove_server")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					Gtk.TreeModel model;
					Gtk.TreeIter  iter;
					string        server_address;
					Gtk.TreeSelection sel = server_tree.get_selection();
					if(sel.get_selected(out model,out iter)) {
						model.get(iter,0,out server_address,-1);
						ServerManager.Network.ServerData wanted_server = new ServerManager.Network.ServerData();
						foreach(ServerManager.Network.ServerData server in network.servers) {
							if(server.address == server_address.split(":")[1]) {
								wanted_server = server;
								break;
							}
						}
						network.servers.remove(wanted_server);
						server_model.remove(iter);
					}
				}
			});
			
			((Gtk.Button)builder.get_object("add_command")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					network.commands.add(" ");
					Gtk.TreeIter iter;
					command_model.append(out iter);
					command_model.set(iter,0," ",-1);
					Gtk.TreeSelection sel = command_tree.get_selection();
					sel.unselect_all();
					sel.select_iter(iter);
					command_tree.set_cursor(command_model.get_path(iter),command_col,true);
				}
			});
			
			((Gtk.Button)builder.get_object("remove_command")).clicked.connect(() => {
				ServerManager.Network network = null;
				if(get_current_network() != null && (network = Main.server_manager.find_network(get_current_network())) != null) {
					Gtk.TreeModel model;
					Gtk.TreeIter  iter;
					string        command;
					Gtk.TreeSelection sel = command_tree.get_selection();
					if(sel.get_selected(out model,out iter)) {
						model.get(iter,0,out command,-1);
						network.commands.remove_at(network.commands.index_of(command));
						command_model.remove(iter);
					}
				}
			});
			
			auto_connect = builder.get_object("network_autoconnect") as Gtk.CheckButton;
			
			auto_connect.toggled.connect(() => {
				if(get_current_network() != null) {
					Main.server_manager.find_network(get_current_network()).auto_connect = auto_connect.active;
				}
			});
			
			load_networks();
			dialog.show_all();
			
			dialog.response.connect(() => {
				dialog.destroy();
				Main.server_manager.save_networks();
				Main.gui.destroy_network_dialog();
			});
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
		
		private void load_networks() {
			network_model.clear();
			Gtk.TreeIter iter;
			foreach(ServerManager.Network network in Main.server_manager.networks) {
				network_model.append(out iter);
				network_model.set(iter,0,network.name,-1);
			}
		}
		
		private void network_changed() {
			Gtk.TreeModel model;
			Gtk.TreeIter iter;
			string network_name;
			Gtk.TreeSelection sel = network_tree.get_selection();
			if(sel.get_selected(out model,out iter)) {
				model.get(iter,0,out network_name,-1);
				ServerManager.Network? network = Main.server_manager.find_network(network_name);
				return_if_fail(network != null);
				server_model.clear();
				command_model.clear();
				Gtk.TreeIter s_iter;
				foreach(ServerManager.Network.ServerData server in network.servers) {
					StringBuilder server_str = new StringBuilder();
					(server.ssl ? server_str.append("ircs://") : server_str.append("irc://"));
					server_str.append(server.address).append(":").append(server.port.to_string());
					if(server.password != null) {
						server_str.append(" ").append(server.password);
					}
					server_model.append(out s_iter);
					server_model.set(s_iter,0,server_str.str,-1);
				}
				Gtk.TreeIter c_iter;
				foreach(string command in network.commands) {
					command_model.append(out c_iter);
					command_model.set(c_iter,0,command,-1);
				}
				auto_connect.active = network.auto_connect;
			} else {
				auto_connect.active = false;
				server_model.clear();
				command_model.clear();
			}
		}
		
		private void network_edited(string path,string new_text) {
			Gtk.TreeIter iter;
			string old_net_name;
			if(network_model.get_iter_from_string(out iter,path)) {
				network_model.get(iter,0,out old_net_name,-1);
				foreach(ServerManager.Network network in Main.server_manager.networks) {
					if(network.name == new_text && new_text != old_net_name) {
						return;
					}
				}
				ServerManager.Network network = Main.server_manager.find_network(old_net_name);
				network.name = new_text;
				network_model.set(iter,0,new_text,-1);
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
				int port = int.parse(raw_address.split(":")[2]);
				
				Gtk.TreeIter iter;
				string old_server_address;
				if(server_model.get_iter_from_string(out iter,path)) {
					server_model.get(iter,0,out old_server_address,-1);
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
					server_model.set(iter,0,new_text,-1);
				}
			} else {
				Gtk.MessageDialog d = new Gtk.MessageDialog(dialog,
				                                            Gtk.DialogFlags.MODAL,
				                                            Gtk.MessageType.ERROR,
				                                            Gtk.ButtonsType.CLOSE,
				                                            "%s",
				                                            _("The string entered isn't a valid server URL."));
				d.response.connect((id) => {d.destroy();});
				d.show_all();
			}
		}
		
		private void command_edited(string path,string new_text) {
			Gtk.TreeIter iter;
			string old_cmd;
			if(command_model.get_iter_from_string(out iter,path)) {
				command_model.get(iter,0,out old_cmd,-1);
				ServerManager.Network network = Main.server_manager.find_network(get_current_network());
				network.commands[network.commands.index_of(old_cmd)] = new_text;
				command_model.set(iter,0,new_text,-1);
			}
		}
	}
}
