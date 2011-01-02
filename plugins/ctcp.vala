/*
 * ctcp.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
using XSIRC;

public class CTCPPlugin : Plugin {
	private bool reply_to_ctcps = true;
	private string version_reply = "XSIRC "+VERSION+" for "+OS;
	private HashMap<string,string> replies = new HashMap<string,string>();
	
	public CTCPPlugin() {
		Object();
	}
	
	construct {
		name = "CTCP";
		description = _("Customizable CTCP replies.");
		version = "0.1";
		author = "NieXS";
		priority = int.MAX - 1;
		prefs_widget = null;
	}
	
	public override bool on_privmsg(Server server,string usernick,string username,string usermask,string target,string message) {
		if(!reply_to_ctcps) {
			return true;
		}
		if(message.has_prefix("\x01") && message.has_suffix("\x01")) {
			string prefix = message.split(" ")[0].substring(1);
			string msg    = message.replace("\x01","").substring(prefix.length).strip();
			switch(prefix) {
				case "VERSION":
					server.send("NOTICE %s :\x01VERSION %s\x01".printf(usernick,version_reply));
					break;
				case "PING":
					server.send("NOTICE %s :\x01PING %s\x01".printf(usernick,msg)); // TODO: check this out, not sure if this is the right way
					break;
				case "TIME":
					server.send("NOTICE %s :\x01TIME %d\x01".printf(usernick,(int)time_t()));
					break;
				default:
					foreach(string rpl in replies.keys) {
						if(prefix == rpl) { // Case-sensitive
							server.send("NOTICE %s :\x01%s %s\x01".printf(usernick,rpl,replies[rpl]));
							break;
						}
					}
					break;
			}
		}
		return true;
	}
}

#if !WINDOWS
Type register_plugin(TypeModule module) {
	return typeof(CTCPPlugin);
}
#endif
