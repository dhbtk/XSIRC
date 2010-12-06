/*
 * highlights.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;

public class HighlightsPlugin : XSIRC.Plugin {
	// TODO: make these customizable
	private LinkedList<string> highlight_regexes = new LinkedList<string>();
	private bool highlight_on_nick = true;
	private bool highlight_on_notices = false;
	
	public HighlightsPlugin() {
		name = "Highlights";
		description = "Adds support for configurable highlights.";
		author = "NieXS";
		version = "0.1";
		priority = 0;
		prefs_widget = null; // TODO
	}
	
	public override bool on_startup() {
		Notify.init("XSIRC");
		return true;
	}
	
	public override bool on_privmsg(XSIRC.Server server,string usernick,string username,string usermask,string target,string message) {
		foreach(string pattern in highlight_regexes) {
			if(Regex.match_simple(pattern,message)) {
				string my_message = message;
				// Checking for ACTIONS
				if(my_message.has_prefix("\x01")) {
					my_message = my_message.replace("\x01","").substring(7);
					my_message = "%s * %s %s".printf(target,usernick,my_message);
				} else {
					my_message = "<%s:%s> %s".printf(target,usernick,my_message);
				}
				server.add_to_view("<server>",my_message);
				highlight(server.server+" - "+target,my_message);
				return true;
			}
		}
		if(highlight_on_nick && Regex.match_simple("\\b"+Regex.escape_string(server.nick)+"\\b",message)) {
			string my_message = message;
			// Checking for ACTIONS
			if(my_message.has_prefix("\x01")) {
				my_message = my_message.replace("\x01","").substring(7);
				my_message = "%s * %s %s".printf(target,usernick,my_message);
			} else {
				my_message = "<%s:%s> %s".printf(target,usernick,my_message);
			}
			server.add_to_view("<server>",my_message);
			highlight(server.server+" - "+target,my_message);
			return true;
		}
		return true;
	}
	
	public override bool on_notice(XSIRC.Server server,string usernick,string username,string usermask,string target,string message) {
		return true;
	}
	
	private void highlight(string title,string content) {
		Notify.Notification notification = new Notify.Notification(title,Markup.escape_text(content),PREFIX+"/share/pixmaps/xsirc.png",null);
		notification.set_timeout(5000);
		notification.set_urgency(Notify.Urgency.CRITICAL);
		try {
			notification.show();
		} catch(Error e) {
			
		}
	}
}

void register_plugin(Module module) {
	HighlightsPlugin plugin = new HighlightsPlugin();
	XSIRC.Main.plugin_manager.add_plugin(plugin);
}
