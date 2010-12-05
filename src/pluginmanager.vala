using Gee;
namespace XSIRC {
	public class PluginManager : Object {
		private ArrayList<Plugin> plugins = new ArrayList<Plugin>();
		
		private delegate Type RegisterPluginFunc(Module module);
		
		public PluginManager() {
			// If modules aren't supported, the client shouldn't even have
			// compiled, but checking doesn't hurt
			assert(Module.supported());
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
					if(file.get_file_type() == FileType.REGULAR) {
						string name = file.get_attribute_string("standard::name");
						if(name.has_suffix("."+Module.SUFFIX)) {
							if(!load_plugin(name)) {
								stderr.printf("Could not load a default plugin. This is, most likely, a bug. File name: %s\n",name);
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
			Module module = Module.open(filename,ModuleFlags.BIND_LAZY);
			if(module == null) {
				stdout.printf("Failed to load module %s\n",filename);
				return false;
			}
			
			stdout.printf("Loaded module %s\n",filename);
			
			void* func;
			module.symbol("register_plugin",out func);
			RegisterPluginFunc register_plugin = (RegisterPluginFunc)func;
			
			Type plugin_type = register_plugin(module);
			
			plugins.add(Object.new(plugin_type) as Plugin);
			plugins.sort((CompareFunc)plugincmp);
			return true;
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
