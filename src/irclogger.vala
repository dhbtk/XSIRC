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
			StringBuilder path = new StringBuilder(Main.config.string["log_folder"].replace("/","\\")+"\\");
#else
			StringBuilder path = new StringBuilder(Main.config.string["log_folder"]+"/");
#endif
			if(server.network != null) {
				path.append(server.network.name);
			} else {
				path.append(server.server);
			}
			//path.append(view.name.down());
			DirUtils.create_with_parents(path.str,0755);
#if WINDOWS
			path.append("\\").append(view.name.down().replace("<","").replace(">","")).append("-").append(gen_timestamp(Main.config.string["log_date_format"],time_t())).append(".log");
#else
			path.append("/").append(view.name.down()).append("-").append(gen_timestamp(Main.config.string["log_date_format"],time_t())).append(".log");
#endif
			//Main.gui.add_to_view(Main.gui.system_view,path.str);
			//stdout.printf("%s\n",path.str);
			File f = File.new_for_path(path.str);
			try {
				DataOutputStream stream = new DataOutputStream(f.append_to(FileCreateFlags.NONE,null));
				MIRCParser parser = new MIRCParser(str);
				MIRCParser.AttrChar[] chars  = parser.parse();
				StringBuilder s = new StringBuilder();
				foreach(MIRCParser.AttrChar c in chars) {
					s.append_unichar(c.contents);
				}
#if WINDOWS
				s.append_c('\r');
#endif
				s.append_c('\n');
				stream.put_string(s.str);
			} catch(Error e) {
				stderr.printf("Could not log: %s",e.message);
			}
		}
	}
}
