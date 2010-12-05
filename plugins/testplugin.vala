public class TestPlugin : XSIRC.Plugin {
	public TestPlugin() {
		name = "Test";
		description = "Test";
		author = "NieXS";
		version = "1.0";
		priority = 0;
		prefs_widget = null;
	}
}

void register_plugin(Module module) {
	TestPlugin plugin = new TestPlugin();
	XSIRC.Main.plugin_manager.add_plugin(plugin);
}
