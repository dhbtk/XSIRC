[CCode (cname = "make_localtime", cheader_filename = "localtime_r_w32.h")]
GLib.Time localtime(time_t time);

[CCode (cname = "set_up_table_raw", cheader_filename = "tag_table.h")]
Gtk.TextTagTable set_up_table_raw();

[CCode (cname = "gtk_text_buffer_insert_with_tag_array", cheader_filename = "tag_table.h", array_length = false, array_null_terminated = true)]
void my_insert_with_tag_array(Gtk.TextView view,string what,string[] tags);

//[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
//namespace XSIRC {
	public const string PACKAGE_NAME;
	public const string APPNAME;
	public const string VERSION;
	public const string GETTEXT_PACKAGE;
	public const string OS;
	public const string PREFIX;
//}
