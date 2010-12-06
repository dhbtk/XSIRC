#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <pango/pango.h>
#include <glib.h>
#include <string.h>

GtkTextTagTable* set_up_table_raw() {
	GtkTextTagTable* table = gtk_text_tag_table_new();
	GtkTextTag* bold_tag = gtk_text_tag_new("bold");
	g_object_set(bold_tag,"weight",PANGO_WEIGHT_BOLD,NULL);
	GtkTextTag* red_tag = gtk_text_tag_new("red");
	g_object_set(red_tag,"foreground","red",NULL);
	GdkColor* color;
	g_object_get(red_tag,"foreground-gdk",&color,NULL);
	printf("%x\n",color->red);
	gtk_text_tag_table_add(table,red_tag);
	gtk_text_tag_table_add(table,bold_tag);
	return table;
}

void gtk_text_buffer_insert_with_tag_array(GtkTextView* text_view,char* what,char** tags,int tags_length) {
	GtkTextIter start_iter;
	GtkTextIter end_iter;
	GtkTextBuffer* buffer = gtk_text_view_get_buffer(text_view);
	gtk_text_buffer_get_end_iter(buffer,&start_iter);
	
	gtk_text_buffer_insert(buffer,&start_iter,what,-1);
	
	end_iter = start_iter;
	gtk_text_iter_forward_char(&end_iter);
	int i;
	char* colors[] = {"white","black","dark blue","green","red","dark red","purple","brown","yellow","light green","cyan","light cyan","blue","pink","grey","light grey",NULL};
	for(i = 0;i < tags_length;i++) {
		if(gtk_text_tag_table_lookup(gtk_text_buffer_get_tag_table(buffer),tags[i]) == NULL) {
			// Checking if it's a color
			printf("%s doesn't exist yet\n",tags[i]);
			int found = 0;
			int n;
			for(n = 0;n < 16; n++) {
				if(!strcmp(tags[i],colors[n])) {
					found = 1;
					break;
				}
			}
			GtkTextTag* tag;
			if(found) {
				tag = gtk_text_buffer_create_tag(buffer,tags[i],"foreground",tags[i],NULL);
				GdkColor* color;
				g_object_get(tag,"foreground-gdk",&color,NULL);
				printf("%s %x %x %x\n",tags[i],color->red,color->green,color->blue);
			} else if(g_str_has_prefix(tags[i],"back ")) {
				char* color;
				char* name = tags[i][5];
				for(n = 0;n < 16;n++) {
					if(!strcmp(colors[n],name)) {
						color = colors[n];
						break;
					}
				}
				tag = gtk_text_buffer_create_tag(buffer,tags[i],"background",color,NULL);
			} else {
				// Bold, italics, underline
				if(!strcmp(tags[i],"bold")) {
					tag = gtk_text_buffer_create_tag(buffer,tags[i],"weight",PANGO_WEIGHT_BOLD,NULL);
				} else if(!strcmp(tags[i],"underlined")) {
					tag = gtk_text_buffer_create_tag(buffer,tags[i],"underline",PANGO_UNDERLINE_SINGLE,NULL);
				} else {
					tag = gtk_text_buffer_create_tag(buffer,tags[i],"style",PANGO_STYLE_ITALIC,NULL);
				}
			}
			gtk_text_buffer_apply_tag(buffer,tag,&start_iter,&end_iter);
		}
		gtk_text_buffer_apply_tag_by_name(buffer,tags[i],&start_iter,&end_iter);
	}
}
