/*
 * notifier.vala
 *
 * Copyright (c) 2010 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class Notifier : Object {
		public static void handle_click(Notify.Notification notification,string action) {
			string server_name = action.split(" ")[0];
			string view_name   = action.split(" ")[1];
			foreach(Server s in Main.server_manager.servers) {
				if(s.server == server_name) {
					Main.gui.servers_notebook.page = Main.gui.servers_notebook.page_num(s.notebook);
					foreach(GUI.View view in s.views) {
						if(view.name == view_name) {
							s.notebook.page = s.notebook.page_num(view.scrolled_window);
							break;
						}
					}
					break;
				}
			}
			Main.gui.main_window.present();
			try {
				notification.close();
			} catch(Error e) {
				
			}
		}
		
		public static void fire_notification(Server server,GUI.View view,string text) {
			if(!Notify.is_initted()) {
				Notify.init("XSIRC");
			}
			Notify.Notification note = new Notify.Notification("Highlight",text,PREFIX+"/share/pixmaps/xsirc.png",null);
			note.set_timeout(Notify.EXPIRES_DEFAULT);
			note.add_action(server.server+" "+view.name,"View",handle_click);
			try {
				note.show();
			} catch(Error e) {
				
			}
		}
	}
}
