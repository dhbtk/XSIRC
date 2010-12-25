/*
 * pluginmanager.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class PluginManager : Object {
		
		public class PrefWindow : Object {
			private Gtk.Dialog window;
			private Gtk.Builder ui_builder;
			private Gtk.ListStore plugin_model = new Gtk.ListStore(1,typeof(string));
			private Gtk.TreeView plugin_tree;
			private Gtk.TreeSelection plugin_selection;
			private Gtk.Label plugin_name;
			private Gtk.Label plugin_description;
			private Gtk.Label plugin_author;
			private Gtk.Label plugin_version;
			private Gtk.Label default_widget = new Gtk.Label("No settings.");
			private Gtk.VBox vbox;
			private Gtk.Widget current_widget = null;
			
			public PrefWindow() {
				ui_builder = new Gtk.Builder();
				try {
					ui_builder.add_from_file(PREFIX+"/share/xsirc/pluginprefwindow.ui");
				} catch(Error e) {
					Posix.exit(Posix.EXIT_FAILURE);
				}
				// Grabbing all widgets
				window = ui_builder.get_object("dialog1") as Gtk.Dialog;
				window.set_default_size(320,320);
				plugin_tree = ui_builder.get_object("plugin_tree") as Gtk.TreeView;
				plugin_name = ui_builder.get_object("plugin_name") as Gtk.Label;
				plugin_description = ui_builder.get_object("description") as Gtk.Label;
				plugin_author = ui_builder.get_object("author") as Gtk.Label;
				plugin_version = ui_builder.get_object("version") as Gtk.Label;
				vbox = ui_builder.get_object("vbox") as Gtk.VBox;
				
				// Setting up the tree view
				plugin_tree.append_column(new Gtk.TreeViewColumn.with_attributes("Plugins",new Gtk.CellRendererText(),"text",0,null));
				plugin_tree.model = plugin_model;
				plugin_selection = plugin_tree.get_selection();
				plugin_selection.changed.connect(plugin_changed);
				load_plugins();
				
				window.show_all();
				window.response.connect(() => {
					// The last plugin's widget is getting destroyed with the 
					// window, it seems
					if(current_widget != null) {
						vbox.remove(current_widget);
					}
					window.destroy();
					Main.gui.destroy_plugin_prefs_window();
				});
			}
			
			private void load_plugins() {
				// The list is sorted by priority instead of plugin name, and to
				// change that we need a copy of the list to re-sort
				ArrayList<Plugin> plugins = new ArrayList<Plugin>();
				foreach(Plugin plugin in Main.plugin_manager.plugins) {
					plugins.add(plugin);
				}
				plugins.sort((CompareFunc)plugin_al_sort);
				// Adding the names to the tree's model
				foreach(Plugin plugin in plugins) {
					Gtk.TreeIter iter;
					plugin_model.append(out iter);
					plugin_model.set(iter,0,plugin.name,-1);
				}
			}
			
			private void plugin_changed() {
				Gtk.TreeModel model;
				Gtk.TreeIter iter;
				if(plugin_selection.get_selected(out model,out iter)) {
					string plugin_name;
					model.get(iter,0,out plugin_name,-1);
					Plugin plugin = Main.plugin_manager.find_plugin(plugin_name);
					this.plugin_name.label = plugin_name;
					plugin_description.label = plugin.description;
					plugin_author.label = "Author: "+plugin.author;
					plugin_version.label = "Version: "+plugin.version;
					// Updating the settings
					if(current_widget != null) {
						vbox.remove(current_widget);
					}
					if(plugin.prefs_widget != null) {
						vbox.pack_start(plugin.prefs_widget,true,true,0);
						current_widget = plugin.prefs_widget;
					} else {
						vbox.pack_start(default_widget,true,true,0);
						current_widget = default_widget;
					}
					window.show_all();
				}
			}
			
			public static int plugin_al_sort(Plugin a,Plugin b) {
				return strcmp(a.name,b.name);
			}
		}
		
		internal ArrayList<Plugin> plugins = new ArrayList<Plugin>();
		
		private delegate void RegisterPluginFunc(Module module);
		
		public PluginManager() {
			// If modules aren't supported, the client shouldn't even have
			// compiled, but checking doesn't hurt
			assert(Module.supported());
		}
		
		public void startup() {
			load_plugins();
			
			// Infodump for plugins, testing stuff
			stdout.printf("Dumping plugin info\n");
			foreach(Plugin plugin in plugins) {
				stdout.printf("Info for plugin %s:\n",plugin.name);
				stdout.printf("\tDescription: %s\n",plugin.description);
				stdout.printf("\tVersion: %s\n",plugin.version);
				stdout.printf("\tAuthor: %s\n",plugin.author);
			}
		}
		
		private LinkedList<string> load_plugins() {
			// Loading "system" plugins, that is, those installed in PREFIX/lib/xsirc
			File sys_plugin_dir = File.new_for_path(PREFIX+"/lib/xsirc");
			assert(sys_plugin_dir.query_exists());
			LinkedList<string> failed_plugins = new LinkedList<string>();
			try {
				FileEnumerator sys_files = sys_plugin_dir.enumerate_children("standard::name",0);
				FileInfo file;
				while((file = sys_files.next_file()) != null) {
					stdout.printf("In loop\n");
					if(true/*file.get_file_type() == FileType.REGULAR*/) {
						string name = file.get_name();
						stdout.printf("%s\n",name);
						if(name.has_suffix("."+Module.SUFFIX)) {
							if(!load_plugin(PREFIX+"/lib/xsirc/"+name)) {
								stderr.printf("Could not load a default plugin. This is, most likely, a bug. File name: %s\n",name);
							}
						}
					}
				}
			} catch(Error e) {
				
			}
			
			File user_plugin_dir = File.new_for_path(Environment.get_user_config_dir()+"/xsirc/plugins");
			try {
				FileEnumerator user_files = user_plugin_dir.enumerate_children("standard::name",0);
				FileInfo file;
				while((file = user_files.next_file()) != null) {
					if(file.get_file_type() == FileType.REGULAR) {
						string name = file.get_attribute_string("standard::name");
						if(name.has_suffix("."+Module.SUFFIX)) {
							if(!load_plugin(Environment.get_user_config_dir()+"/xsirc/plugins/"+name)) {
								failed_plugins.add(name);
							}
						}
					}
				}
			} catch(Error e) {
				
			}
			
			return failed_plugins;
		}
		
		private bool load_plugin(string filename) {
			stdout.printf("Loading module %s\n",filename);
			Module module = Module.open(filename,0);
			if(module == null) {
				stdout.printf("Failed to load module %s: %s\n",filename,Module.error());
				return false;
			}
			
			stdout.printf("Loaded module %s\n",filename);
			
			void* func;
			module.symbol("register_plugin",out func);
			RegisterPluginFunc register_plugin = (RegisterPluginFunc)func;
			
			register_plugin(module);
			module.make_resident();
			return true;
		}
		
		public void add_plugin(Plugin plugin) {
			// Checking for duplicates
			foreach(Plugin plugin_ in plugins) {
				if(plugin_.name == plugin.name) {
					stderr.printf("Duplicate plugin %s!\n",plugin.name);
					return;
				}
			}
			plugins.add(plugin);
			plugins.sort((CompareFunc)plugincmp);
		}
		
		public Plugin? find_plugin(string name) {
			foreach(Plugin plugin in plugins) {
				if(plugin.name == name) {
					return plugin;
				}
			}
			return null;
		}
		
		// API goes here.
		
		internal void on_join(Server server,string usernick,string username,string usermask,string channel) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_join(server,usernick,username,usermask,channel)) {
					break;
				}
			}
		}
		
		internal void on_part(Server server,string usernick,string username,string usermask,string channel,string message) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_part(server,usernick,username,usermask,channel,message)) {
					break;
				}
			}
		}
		
		internal void on_kick(Server server,string kicked,string usernick,string username,string usermask,string channel,string message) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_kick(server,kicked,usernick,username,usermask,channel,message)) {
					break;
				}
			}
		}
		
		internal void on_nick(Server server,string new_nick,string usernick,string username,string usermask) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_nick(server,new_nick,usernick,username,usermask)) {
					break;
				}
			}
		}
		
		internal void on_privmsg(Server server,string usernick,string username,string usermask,string target,string message) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_privmsg(server,usernick,username,usermask,target,message)) {
					break;
				}
			}
		}
		
		internal void on_notice(Server server,string usernick,string username,string usermask,string target,string message) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_notice(server,usernick,username,usermask,target,message)) {
					break;
				}
			}
		}
		
		internal void on_quit(Server server,string usernick,string username,string usermask,string message) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_quit(server,usernick,username,usermask,message)) {
					break;
				}
			}
		}
		
		internal void on_chan_user_mode(Server server,string usernick,string username,string usermask,string channel,string modes,string targets) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_chan_user_mode(server,usernick,username,usermask,channel,modes,targets)) {
					break;
				}
			}
		}
		
		internal void on_chan_mode(Server server,string usernick,string username,string usermask,string channel,string modes) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_chan_mode(server,usernick,username,usermask,channel,modes)) {
					break;
				}
			}
		}
		
		internal void on_mode(Server server,string usernick,string mode) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_mode(server,usernick,mode)) {
					break;
				}
			}
		}
		
		internal void on_topic(Server server,string usernick,string username,string usermask,string channel,string topic) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_topic(server,usernick,username,usermask,channel,topic)) {
					break;
				}
			}
		}
		
		internal void on_startup() {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_startup()) {
					break;
				}
			}
		}
		
		internal void on_shutdown() {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_shutdown()) {
					break;
				}
			}
		}
		
		internal void on_connect(Server server) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_connect(server)) {
					break;
				}
			}
		}
		
		internal void on_disconnect(Server server) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_disconnect(server)) {
					break;
				}
			}
		}
		
		internal void on_connect_error(Server server) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_connect_error(server)) {
					break;
				}
			}
		}
	}
	
	int plugincmp(Plugin a,Plugin b) {
		if(a.priority < b.priority) {
			return -1;
		} else if(a.priority == b.priority) {
			return 0;
		} else {
			return 1;
		}
	}
}
