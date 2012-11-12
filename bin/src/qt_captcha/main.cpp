#include <QApplication>
#include <QFile>

#include "form.hpp"

int main(int argc, char ** argv)
{
   QApplication app(argc, argv);

   QString fname;
   QString title;
   QString whitelist;

   if(argc < 2)
      return -1;

   fname = argv[1];

   QFile file(fname);
   if(!file.exists())
      return -1;

   if(argc > 2)
      title = argv[2];
   else
      title = "Captcha";

   if(argc > 3)
      whitelist = QString::fromUtf8(argv[3]);

   Form form;
   form.setTitle(title);
   form.setFile(fname);
   if(!whitelist.isNull())
      form.setWhiteList(whitelist);
   form.show();

   return app.exec();
}
