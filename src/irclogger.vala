/*
 * irclogger.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
namespace XSIRC {
	public class IRCLogger : Object {
		public static bool logging_enabled;
		public static void log(Server server,GUI.View view,owned string str) {
			str = Main.gui.timestamp() + " " + str;
			if(!logging_enabled) {
				return;
			}
#if WINDOWS
			StringBuilder path = new StringBuilder(Environment.get_user_config_dir()+"\\xsirc\\irclogs\\");
#else
			StringBuilder path = new StringBuilder(Environment.get_user_config_dir()+"/xsirc/irclogs/");
#endif
			if(server.network != null) {
				path.append(server.network.name);
			} else {
				path.append(server.server);
			}
			//path.append(view.name.down());
			DirUtils.create_with_parents(path.str,0755);
#if WINDOWS
			path.append("\\").append(view.name.down()).append("-").append(gen_timestamp(Main.config["core"]["log_date_format"],time_t())).append(".log");
#else
			path.append("/").append(view.name.down()).append("-").append(gen_timestamp(Main.config["core"]["log_date_format"],time_t())).append(".log");
#endif
			Main.gui.add_to_view(Main.gui.system_view,path.str);
			//stdout.printf("%s\n",path.str);
			File f = File.new_for_path(path.str);
			try {
				DataOutputStream stream = new DataOutputStream(f.append_to(FileCreateFlags.NONE,null));
				MIRCParser parser = new MIRCParser(str);
				MIRCParser.AttrChar[] chars  = parser.parse();
				foreach(MIRCParser.AttrChar c in chars) {
					stream.put_byte(c.contents);
				}
				stream.put_byte('\n');
			} catch(Error e) {
				Main.gui.add_to_view(Main.gui.system_view,"Could not log: %s".printf(e.message));
			}
		}
	}
}
