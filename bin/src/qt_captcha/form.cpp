#include "form.hpp"

Form::Form(QWidget * parent)
   : QWidget(parent)
{
   ui.setupUi(this);

   connect(ui.line1, SIGNAL(returnPressed()), SLOT(displayText()));
   connect(ui.line1, SIGNAL(textChanged(QString)), SLOT(updateCount(QString)));
}

void Form::setFile(const QString & fname)
{
   QPixmap pmap(fname);
   ui.label1->setPixmap(pmap);
}

void Form::setTitle(const QString & title)
{
   setWindowTitle(title);
}

void Form::setWhiteList(const QString & chars)
{
   ui.line1->setValidator(new QRegExpValidator(QRegExp("[" + chars + "]*"), this));
}

void Form::updateCount(const QString & text)
{
   ui.label2->setText(QString::number(text.length()));
}

void Form::displayText()
{
   std::wcout << ui.line1->text().toStdWString();
   exit(0);
}
