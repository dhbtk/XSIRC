/*
 * highlights.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;

public class HighlightsPlugin : XSIRC.Plugin {
	public HighlightsPlugin() {
		name = "Highlights";
		description = "Adds support for configurable highlights.";
		author = "NieXS";
		version = "0.1";
		priority = 0;
		prefs_widget = null; // TODO
	}
	
	public override bool on_privmsg(XSIRC.Server server,string usernick,string username,string usermask,string target,string message) {
		stdout.printf("PRIVMSG!\n");
		return true;
	}
	
	public override bool on_notice(XSIRC.Server server,string usernick,string username,string usermask,string target,string message) {
		return true;
	}
}

void register_plugin(Module module) {
	HighlightsPlugin plugin = new HighlightsPlugin();
	XSIRC.Main.plugin_manager.add_plugin(plugin);
}
