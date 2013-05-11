/*
 * pluginmanager.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class PluginManager : Object {
		private class PluginRegistrar : TypeModule {
			private unowned Module module;
			private delegate Type RegisterPluginFunc(TypeModule module);
			
			public PluginRegistrar(Module module) {
				this.module = module;
				module.make_resident();
			}
			
			public override bool load() {
				void* func;
				module.symbol("register_plugin",out func);
				RegisterPluginFunc register_plugin = (RegisterPluginFunc)func;
				Type type = register_plugin((TypeModule)this);
				Plugin obj = Object.new(type) as Plugin;
				
				Main.plugin_manager.add_plugin(obj);
				return true;
			}
			
			public override void unload() {
				// Don't, ever
			}
		}
		
		
		internal ArrayList<Plugin> plugins = new ArrayList<Plugin>();
		private ArrayList<PluginRegistrar> registrars = new ArrayList<PluginRegistrar>();
		
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
			/*
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
			*/
			return failed_plugins;
		}
		
		private bool load_plugin(string filename) {
			Module module = Module.open(filename,0);
			if(module == null) {
				stdout.printf("Failed to load module %s: %s\n",filename,Module.error());
				return false;
			}
			PluginRegistrar registrar = new PluginRegistrar(module);
			registrar.load();
			registrars.add(registrar);
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

			// Keep the plugins sorted. Completely sorting them after every
			// insertion is technically O(N^2 log N) for N insertions and
			// suboptimal to an O(N log N) solution of sorting the plugins
			// only after inserting all of them, or using a heap, but this
			// doesn't matter in practice since N is about 10.
			plugins.sort((CompareDataFunc)plugincmp);
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
		
		internal void on_sent_message(Server server,string nick,string target,string message,string raw_msg) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_sent_message(server,nick,target,message,raw_msg)) {
					break;
				}
			}
		}
		
		internal void on_topic(Server server,Server.Channel.Topic topic,
		        Server.Channel.Topic old_topic,string channel,string username,string usermask) {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_topic(server,topic,old_topic,channel,username,usermask)) {
					break;
				}
			}
		}
		
		public void on_startup() {
			foreach(Plugin plugin in plugins) {
				if(plugin.enabled && !plugin.on_startup()) {
					break;
				}
			}
		}
		
		public void on_shutdown() {
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
