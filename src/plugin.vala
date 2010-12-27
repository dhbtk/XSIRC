/*
 * plugin.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class Plugin : Object {
		public string name;
		public string description;
		public string author;
		public string version;
		public int priority = 0;
		public bool enabled = true;
		public Gtk.Widget prefs_widget = null;
		
		public virtual bool on_join(Server server,string usernick,string username,string usermask,string channel) {
			return true;
		}
		
		public virtual bool on_part(Server server,string usernick,string username,string usermask,string channel,string message) {
			return true;
		}
		
		public virtual bool on_kick(Server server,string kicker,string usernick,string username,string usermask,string channel,string message) {
			return true;
		}
		
		public virtual bool on_nick(Server server,string new_nick,string usernick,string username,string usermask) {
			return true;
		}
		
		public virtual bool on_privmsg(Server server,string usernick,string username,string usermask,string target,string message) {
			return true;
		}
		
		public virtual bool on_notice(Server server,string usernick,string username,string usermask,string target,string message) {
			return true;
		}
		
		public virtual bool on_quit(Server server,string usernick,string username,string usermask,string message) {
			return true;
		}
		
		public virtual bool on_chan_user_mode(Server server,string usernick,string username,string usermask,string channel,string modes,string targets) {
			return true;
		}
		
		public virtual bool on_chan_mode(Server server,string usernick,string username,string usermask,string channel,string modes) {
			return true;
		}
		
		public virtual bool on_mode(Server server,string usernick,string mode) {
			return true;
		}
		
		public virtual bool on_topic(Server server,string usernick,string username,string usermask,string channel,string topic) {
			return true;
		}
		
		public virtual bool on_startup() {
			return true;
		}
		
		public virtual bool on_shutdown() {
			return true;
		}
		
		public virtual bool on_connect(Server server) {
			return true;
		}
		
		public virtual bool on_disconnect(Server server) {
			return true;
		}
		
		public virtual bool on_connect_error(Server server) {
			return true;
		}
	}
}
