using Gtk;
int main(string[] args) {
	Gtk.init(ref args);
	Builder builder = new Builder();
	builder.add_from_file("networks.ui");
	Dialog d = builder.get_object("dialog1") as Dialog;
	d.show_all();
	Gtk.main();
	return 0;
}
