#include <gtk/gtk.h>

void entry_print(GtkWidget *entry) {
   const gchar *text = gtk_entry_get_text(entry);
   g_print("%s", text);
   gtk_main_quit();
}

int main(int argc, char** argv) {
   if(argc < 2)
      return 1;

   char* fname = argv[1];

   char* title;
   if(argc > 2)
      title = argv[2];
   else
      title = "Captcha";

   GtkWidget *window;
   GtkWidget *vbox;
   GtkWidget *image;
   GtkWidget *entry;

   gtk_init(&argc, &argv);

   window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
   gtk_window_set_title(GTK_WINDOW(window), title);

   vbox = gtk_vbox_new(FALSE, 0);
   gtk_container_add(GTK_CONTAINER(window), vbox);

   image = gtk_image_new_from_file(fname);
   entry = gtk_entry_new();

   gtk_box_pack_start(GTK_BOX(vbox), image, TRUE, TRUE, 30);
   gtk_box_pack_start(GTK_BOX(vbox), entry, FALSE, FALSE, 10);

   gtk_widget_show_all(window);

   g_signal_connect(G_OBJECT(window), "destroy", G_CALLBACK(gtk_main_quit), NULL);
   g_signal_connect(G_OBJECT(entry), "activate", G_CALLBACK(entry_print), NULL);

   gtk_main();

   return 0;
}
