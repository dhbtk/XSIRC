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
			{MessageID.PRIVMSG,"Normal message","$USERNICK, $USERNAME, $USERMASK, $MESSAGE"},
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
			{MessageID.PRIVMSG,"<$USERNICK> $MESSAGE"},
			{MessageID.ACTION,"* $USERNICK $MESSAGE"},
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
			return true;
		}
		
		public override bool on_part(Server server,string usernick,string username,string usermask,string channel,string message) {
			return true;
		}
		
		public override bool on_kick(Server server,string kicked,string usernick,string username,string usermask,string channel,string message) {
			return true;
		}
		
		public override bool on_nick(Server server,string new_nick,string usernick,string username,string usermask) {
			return true;
		}
		
		public override bool on_privmsg(Server server,string usernick,string username,string usermask,string target,string message) {
			return true;
		}
		
		public override bool on_notice(Server server,string usernick,string username,string usermask,string target,string message) {
			return true;
		}
		
		public override bool on_quit(Server server,string usernick,string username,string usermask,string message) {
			return true;
		}
		
		public override bool on_chan_user_mode(Server server,string usernick,string username,string usermask,string channel,string modes,string targets) {
			return true;
		}
		
		public override bool on_chan_mode(Server server,string usernick,string username,string usermask,string channel,string modes) {
			return true;
		}
		
		public override bool on_mode(Server server,string usernick,string mode) {
			return true;
		}
		
		public override bool on_topic(Server server,string usernick,string username,string usermask,string channel,string topic) {
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
		}
	}
}

void register_plugin(Module module) {
	XSIRC.MessagesPlugin plugin = new XSIRC.MessagesPlugin();
	XSIRC.Main.plugin_manager.add_plugin(plugin);
}
