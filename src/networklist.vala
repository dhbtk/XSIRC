/*
 * networklist.vala
 *
 * Copyright (c) 2011 Eduardo Niehues
 * Distributed under the New BSD License; see ../LICENSE for details.
 */
using Gee;
namespace XSIRC {
	public class NetworkList : Object {
		public Gtk.Dialog dialog;
		private Gtk.Builder builder;

		private Gtk.TreeView network_tree;
		private Gtk.TreeView command_tree;
		private Gtk.TreeView server_tree;

		private Gtk.TreeViewColumn network_col;
		private Gtk.TreeViewColumn command_col;
		private Gtk.TreeViewColumn server_col;

		private Gtk.ListStore network_model = new Gtk.ListStore(1,typeof(string));
		private Gtk.ListStore command_model = new Gtk.ListStore(1,typeof(string));
		private Gtk.ListStore server_model  = new Gtk.ListStore(1,typeof(string));

		public NetworkList() {
			builder = new Gtk.Builder();
			try {
				builder.add_from_file(PREFIX+"/share/xsirc/networks.ui");
			} catch(Error e) {
				Posix.exit(Posix.EXIT_FAILURE);
			}
			
			dialog = builder.get_object("dialog1") as Gtk.Dialog;

			network_tree = builder.get_object("network_tree") as Gtk.TreeView;
			network_tree.model = network_model;

			Gtk.CellRendererText network_renderer = new Gtk.CellRendererText();
			network_renderer.editable = true;
			network_renderer.edited.connect(network_edited);
			network_col = new Gtk.TreeViewColumn.with_attributes(_("Networks"),network_renderer,"text",1,null);
			network_tree.append_column(network_col);

			command_tree = builder.get_object("command_tree") as Gtk.TreeView;
			command_tree.model = command_model;

			Gtk.CellRendererText command_renderer = new Gtk.CellRendererText();
			command_renderer.editable = true;
			command_renderer.edited.connect(command_edited);
			command_col = new Gtk.TreeViewColumn.with_attributes(_("Commands"),command_renderer,"text",1,null);
			command_tree.append_column(command_col);

			server_tree = builder.get_object("server_tree") as Gtk.TreeView;
			server_tree.model = server_model;

			Gtk.CellRendererText server_renderer = new Gtk.CellRendererText();
			server_renderer.editable = true;
			server_renderer.edited.connect(server_edited);
			server_col = new Gtk.TreeViewColumn.with_attributes(_("Servers"),server_renderer,"text",1,null);
			server_tree.append_column(server_col);
		}
	}
}
