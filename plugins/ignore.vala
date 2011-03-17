/*
 * ignore.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
using XSIRC;

public class IgnorePlugin : Plugin {
	
	private class Channel {
		
		public string name;
		public bool show_joins = true;
		public bool show_parts = true;
		public bool show_quits = true;
		public bool show_kicks = true;
		
		public Channel(string name) {
			this.name = name;
		}
	}

	private LinkedList<string> ignored_nicks = new LinkedList<string>();
	private LinkedList<string> ignored_regexes = new LinkedList<string>();
	private LinkedList<Channel> channels = new LinkedList<Channel>();

	public IgnorePlugin() {
		Object();
	}

	construct {
		name = _("Ignore");
		description = _("Selectively ignore messages.");
		version = "0.1";
		author = "NieXS";
		priority = int.MAX - 1; // Just before the MessagesPlugin, ideally
	}
}

Type register_type(TypeModule module) {
	return typeof(IgnorePlugin);
}
