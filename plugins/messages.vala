/*
 * messages.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;

namespace XSIRC {
	public class MessagesPlugin : Plugin {
		
		private enum MessageID {
			JOIN,
			PART,
			KICK,
			NICK,
			PRIVMSG,
			ACTION,
			CTCPMSG,
			NOTICE,
			QUIT,
			CHANUSERMODE,
			CHANMODE,
			MODE,
			TOPIC
		}
		
		private struct MessageType {
			public MessageID id;
			public string name;
			public string accepted_params;
		}
		
		private struct DefaultMessage {
			public MessageID id;
			public string message;
		}
		
		private const MessageType[] message_types = {
			{MessageID.JOIN,"User join","$USERNICK, $USERNAME, $USERMASK, $CHANNEL"},
			{MessageID.PART,"User part","$USERNICK, $USERNAME, $USERMASK, $CHANNEL, $MESSAGE"},
			{MessageID.KICK,"User kicked","$KICKED, $USERNICK, $USERNAME, $USERMASK, $MESSAGE"},
			{MessageID.NICK,"User changed nick","$NEWNICK, $USERNICK, $USERNAME, $USERMASK"},
			{MessageID.PRIVMSG,"Normal message","$USERNICK, $USERNAME, $USERMASK, $MESSAGE, $USERRANK"},
			{MessageID.ACTION,"User action (/me)","$USERNICK, $USERNAME, $USERMASK, $MESSAGE"},
			{MessageID.CTCPMSG,"CTCP request","$USERNICK, $USERNAME, $USERMASK, $REQUEST"},
			{MessageID.NOTICE,"Notice","$USERNICK, $USERNAME, $USERMASK, $MESSAGE"},
			{MessageID.QUIT,"User disconnect","$USERNICK, $USERNAME, $USERMASK, $MESSAGE"},
			{MessageID.CHANUSERMODE,"Channel user mode change","$USERNICK, $USERNAME, $USERMASK, $CHANNEL, $MODES, $TARGETS"},
			{MessageID.CHANMODE,"Channel mode change","$USERNICK, $USERNAME, $USERMASK, $CHANNEL, $MODES"},
			{MessageID.TOPIC,"Topic change","$USERNICK, $USERNAME, $USERMASK, $CHANNEL, $MESSAGE"}
		};
		
		private const DefaultMessage[] default_messages = {
			{MessageID.JOIN,"$USERNICK [$USERNAME@$USERMASK] has joined $CHANNEL"},
			{MessageID.PART,"$USERNICK [$USERNAME@$USERMASK] has left $CHANNEL [$MESSAGE]"},
			{MessageID.KICK,"$USERNICK has kicked $KICKED from $CHANNEL [$MESSAGE]"},
			{MessageID.PRIVMSG,"<$USERRANK$USERNICK> $MESSAGE"},
			{MessageID.ACTION,"* $USERRANK$USERNICK $MESSAGE"},
			{MessageID.CTCPMSG,"Got CTCP $REQUEST from $USERNICK"},
			{MessageID.NOTICE,"-$USERNICK- $MESSAGE"},
			{MessageID.QUIT,"$USERNICK [$USERNAME@$USERMASK] has disconnected [$MESSAGE]"},
			{MessageID.CHANUSERMODE,"$USERNICK sets mode $MODES on $TARGETS"},
			{MessageID.CHANMODE,"$USERNICK sets $CHANNEL's mode: $MODES"},
			{MessageID.TOPIC,"$USERNICK sets the topic to $MESSAGE"}
		};
		
		private HashMap<MessageID,string> messages = new HashMap<MessageID,string>();
		
		public MessagesPlugin() {
			name = "Messages";
			description = "Customizable messages.";
			author = "NieXS";
			version = "0.1";
			priority = int.MAX;
			prefs_widget = null;
			load_default_messages();
			load_messages();
		}
		
		private void load_default_messages() {
			foreach(DefaultMessage message in default_messages) {
				messages[message.id] = message.message;
			}
		}
		
		private void load_messages() {
			string[] names = {"JOIN","PART","KICK","PRIVMSG","ACTION","CTCPMSG","NOTICE","QUIT","CHANUSERMODE","CHANMODE","TOPIC"};
			try {
				KeyFile conf = new KeyFile();
				conf.load_from_file(Environment.get_user_config_dir()+"/xsirc/messages.conf",0);
				int i = 0;
				foreach(string name in names) {
					if(conf.has_key("messages",name)) {
						messages[(MessageID)i] = conf.get_string("messages",name);
					}
					i++;
				}
			} catch(Error e) {
				
			}
		}
		
		public override bool on_join(Server server,string usernick,string username,string usermask,string channel) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL"};
			string[] replacements = {usernick,username,usermask,channel};
			int i = 0;
			string result = messages[MessageID.JOIN];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			server.add_to_view(channel,result);
			return true;
		}
		
		public override bool on_part(Server server,string usernick,string username,string usermask,string channel,string message) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL","$MESSAGE"};
			string[] replacements = {usernick,username,usermask,channel,message};
			int i = 0;
			string result = messages[MessageID.PART];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			server.add_to_view(channel,result);
			return true;
		}
		
		public override bool on_kick(Server server,string kicked,string usernick,string username,string usermask,string channel,string message) {
			string[] replaced = {"$KICKED","$USERNICK","$USERNAME","$USERMASK","$CHANNEL","$MESSAGE"};
			string[] replacements = {kicked,usernick,username,usermask,channel,message};
			int i = 0;
			string result = messages[MessageID.KICK];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			server.add_to_view(channel,result);
			return true;
		}
		
		public override bool on_nick(Server server,string new_nick,string usernick,string username,string usermask) {
			string[] replaced = {"$NEWNICK","$USERNICK","$USERNAME","$USERMASK"};
			string[] replacements = {new_nick,usernick,username,usermask};
			int i = 0;
			string result = messages[MessageID.NICK];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			foreach(Server.Channel channel in server.channels) {
				if(usernick.down() in channel.users) {
					server.add_to_view(channel.title,result);
				}
			}
			foreach(GUI.View view in server.views) {
				if(view.name.down() == usernick.down()) {
					server.add_to_view(view.name,result);
				}
			}
			return true;
		}
		
		public override bool on_privmsg(Server server,string usernick,string username,string usermask,string target,string message) {
			// Finding the rank.
			string userrank = " ";
			if(server.find_channel(target) != null) {
				foreach(string user in server.find_channel(target).raw_users) {
					if(user.substring(1) == usernick) {
						userrank = user[0:1];
						break;
					}
				}
			}
			if(message.has_prefix("\001ACTION") && message.has_suffix("\x01")) { // ACTION
				message = message.replace("\x01","").substring(7);
				string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$MESSAGE"};
				string[] replacements = {usernick,username,usermask,message};
				int i = 0;
				string result = messages[MessageID.ACTION];
				foreach(string s in replaced) {
					if(s in result) {
						result = result.replace(s,replacements[i]);
					}
					i++;
				}
				server.add_to_view(target,result);
			} else if(message.has_prefix("\x01") && message.has_suffix("\x01")) { // CTCPMSG
				message = message.replace("\x01","");
				string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$REQUEST"};
				string[] replacements = {usernick,username,usermask,message};
				int i = 0;
				string result = messages[MessageID.CTCPMSG];
				foreach(string s in replaced) {
					if(s in result) {
						result = result.replace(s,replacements[i]);
					}
					i++;
				}
				server.add_to_view("<server>",result);
			} else { // PRIVMSG
				string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$MESSAGE","$USERRANK"};
				string[] replacements = {usernick,username,usermask,message,userrank};
				int i = 0;
				string result = messages[MessageID.PRIVMSG];
				foreach(string s in replaced) {
					if(s in result) {
						result = result.replace(s,replacements[i]);
					}
					i++;
				}
				server.add_to_view(target,result);
			}
			return true;
		}
		
		/*public override bool on_notice(Server server,string usernick,string username,string usermask,string target,string message) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL"};
			string[] replacements = {usernick,username,usermask,channel};
			int i = 0;
			string result = messages[MessageType.JOIN];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			return true;
		}
		
		public override bool on_quit(Server server,string usernick,string username,string usermask,string message) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL"};
			string[] replacements = {usernick,username,usermask,channel};
			int i = 0;
			string result = messages[MessageType.JOIN];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			return true;
		}
		
		public override bool on_chan_user_mode(Server server,string usernick,string username,string usermask,string channel,string modes,string targets) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL"};
			string[] replacements = {usernick,username,usermask,channel};
			int i = 0;
			string result = messages[MessageType.JOIN];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			return true;
		}
		
		public override bool on_chan_mode(Server server,string usernick,string username,string usermask,string channel,string modes) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL"};
			string[] replacements = {usernick,username,usermask,channel};
			int i = 0;
			string result = messages[MessageType.JOIN];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			return true;
		}
		
		public override bool on_mode(Server server,string usernick,string mode) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL"};
			string[] replacements = {usernick,username,usermask,channel};
			int i = 0;
			string result = messages[MessageType.JOIN];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			return true;
		}
		
		public override bool on_topic(Server server,string usernick,string username,string usermask,string channel,string topic) {
			string[] replaced = {"$USERNICK","$USERNAME","$USERMASK","$CHANNEL"};
			string[] replacements = {usernick,username,usermask,channel};
			int i = 0;
			string result = messages[MessageType.JOIN];
			foreach(string s in replaced) {
				if(s in result) {
					result = result.replace(s,replacements[i]);
				}
				i++;
			}
			return true;
		}
		
		public override bool on_startup() {
			return true;
		}
		
		public override bool on_shutdown() {
			return true;
		}
		
		public override bool on_connect(Server server) {
			return true;
		}
		
		public override bool on_disconnect(Server server) {
			return true;
		}
		
		public override bool on_connect_error(Server server) {
			return true;
		}*/
	}
}

void register_plugin(Module module) {
	XSIRC.MessagesPlugin plugin = new XSIRC.MessagesPlugin();
	XSIRC.Main.plugin_manager.add_plugin(plugin);
}
