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
		load_settings();
	}
	
	private void load_settings() {
		Gtk.CheckButton reply_button = new Gtk.CheckButton.with_label(_("Reply to CTCP messages"));
		reply_button.xalign = 0;
		reply_button.yalign = 0;
		Gtk.VBox box = new Gtk.VBox(false,0);
		box.pack_start(reply_button,false,false,0);
		prefs_widget = box;
		try {
			KeyFile conf = new KeyFile();
			conf.load_from_file(Environment.get_user_config_dir()+"/xsirc/ctcp.conf",0);
			if(conf.has_key("CTCP","reply_to_ctcps")) {
				reply_to_ctcps = conf.get_boolean("CTCP","reply_to_ctcps");
			}
		} catch(Error e) {
			
		}
		reply_button.toggled.connect(() => {
			if(!reply_button.active) {
				foreach(Server server in Main.server_manager.servers) {
					if(server.connected) {
						server.send("MODE %s +T".printf(server.nick));
					}
				}
			} else {
				foreach(Server server in Main.server_manager.servers) {
					if(server.connected) {
						server.send("MODE %s -T".printf(server.nick));
					}
				}
			}
			reply_to_ctcps = reply_button.active;
			save_settings();
		});
		reply_button.active = reply_to_ctcps;
	}
	
	private void save_settings() {
		try {
			KeyFile conf = new KeyFile();
			conf.set_boolean("CTCP","reply_to_ctcps",reply_to_ctcps);
			FileUtils.set_contents(Environment.get_user_config_dir()+"/xsirc/ctcp.conf",conf.to_data());
		} catch(Error e) {
			
		}
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
					server.send("NOTICE %s :\x01PING %s\x01".printf(usernick,msg));
					break;
				case "TIME":
					server.send("NOTICE %s :\x01TIME %s\x01".printf(usernick,gen_timestamp("%c",time_t())));
					break;
				case "SOURCE":
					server.send("NOTICE %s :\x01SOURCE https://github.com/NieXS/XSIRC/archives/master\x01".printf(usernick));
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
	
	public override bool on_notice(Server server,string usernick,string username,string usermask,string target,string message) {
		if(message.has_prefix("\x01")) {
			string prefix = message.replace("\x01","").split(" ")[0];
			string msg    = message.replace("\x01","").substring(prefix.length).strip();
			switch(prefix) {
				case "PING": // The only special case
					Posix.timeval current_time = Posix.timeval();
					current_time.get_time_of_day();
					Posix.timeval gotten_time = Posix.timeval();
					gotten_time.tv_sec = long.parse(msg.split(".")[0]);
					gotten_time.tv_usec = long.parse(msg.split(".")[1]);
					long sec_diff = current_time.tv_sec - gotten_time.tv_sec;
					long frac_diff = current_time.tv_usec - gotten_time.tv_usec;
					server.add_to_view(_("<server>"),_("Latency to %s: %d.%2d seconds.").printf(usernick,sec_diff,frac_diff));
					break;
				default:
					server.add_to_view(_("<server>"),_("%s reply from %s: %s").printf(prefix,usernick,msg));
					break;
			}
		}
		return true;
	}
}

Type register_plugin(TypeModule module) {
	return typeof(CTCPPlugin);
}
