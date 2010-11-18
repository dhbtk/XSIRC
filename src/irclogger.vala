/*
 * irclogger.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
namespace XSIRC {
	public class IRCLogger : Object {
		public static void log(Server server,GUI.View view,owned string str) {
			str = Main.gui.timestamp() + " " + str;
			if(Main.config["core"]["log"] != "true") {
				return;
			}
			StringBuilder path = new StringBuilder(Environment.get_user_config_dir()+"/xsirc/irclogs/");
			if(server.network != null) {
				path.append(server.network.name);
			} else {
				path.append(server.server);
			}
			//path.append(view.name.down());
			DirUtils.create_with_parents(path.str,0755);
			
			path.append("/").append(view.name.down()).append("-");
#if WINDOWS
			path.append(localtime(time_t()).format(Main.config["core"]["log_date_format"])).append(".log");
#else
			path.append(Time.local(time_t()).format(Main.config["core"]["log_date_format"])).append(".log");
#endif
			//stdout.printf("%s\n",path.str);
			FileStream stream = FileStream.open(path.str,"a");
			if(stream == null) {
				stderr.printf("Could not open log file for appending!\n");
				Posix.exit(Posix.EXIT_FAILURE);
			}
			MIRCParser parser = new MIRCParser(str);
			MIRCParser.AttrChar[] chars  = parser.parse();
			foreach(MIRCParser.AttrChar c in chars) {
				stream.putc(c.contents);
			}
			stream.putc('\n');
		}
	}
}
