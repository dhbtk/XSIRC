/*
 * plugin.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public interface Plugin : Object {
		public abstract string name {get; private set;}
		public abstract string description {get; private set;}
		public abstract string author {get; private set;}
		public abstract string version {get; private set;}
		public abstract int priority {get; private set;}
		
		public bool on_join(Server server,string usernick,string username,string usermask,string channel) {
			return false;
		}
		
		public bool on_part(Server server,string usernick,string username,string usermask,string channel,string message) {
			return false;
		}
		
		public bool on_kick(Server server,string kicker,string usernick,string username,string usermask,string channel,string message) {
			return false;
		}
		
		public bool on_nick(Server server,string new_nick,string usernick,string username,string usermask) {
			return false;
		}
		
		public bool on_privmsg(Server server,string usernick,string username,string usermask,string target,string message) {
			return false;
		}
		
		public bool on_notice(Server server,string usernick,string username,string usermask,string target,string message) {
			return false;
		}
		
		public bool on_quit(Server server,string usernick,string username,string usermask,string message) {
			return false;
		}
		
		public bool on_chan_user_mode(Server server,string usernick,string username,string usermask,string channel,string modes,string targets) {
			return false;
		}
		
		public bool on_chan_mode(Server server,string usernick,string username,string usermask,string channel,string modes) {
			return false;
		}
		
		public bool on_mode(Server server,string usernick,string mode) {
			return false;
		}
		
		public bool on_topic(Server server,string usernick,string username,string usermask,string channel,string topic) {
			return false;
		}
	}
}
