public class TestPlugin : XSIRC.Plugin {
	public TestPlugin() {
		Object();
	}
	
	construct {
		name = "Test";
		description = "Test";
		author = "NieXS";
		version = "1.0";
		priority = 0;
		prefs_widget = null;
	}
}

#if !WINDOWS
//[ModuleInit]
Type register_plugin(TypeModule module) {
	return typeof(TestPlugin);
}
#endif
