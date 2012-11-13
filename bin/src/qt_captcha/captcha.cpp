#include "captcha.hpp"

Captcha::Captcha(QWidget * parent)
   : QWidget(parent)
{
   ui.setupUi(this);

   connect(ui.line1, SIGNAL(returnPressed()), SLOT(displayText()));
   connect(ui.line1, SIGNAL(textChanged(QString)), SLOT(updateCount(QString)));
}

void Captcha::setFile(const QString & fname)
{
   QPixmap pmap(fname);
   ui.label1->setPixmap(pmap);
}

void Captcha::setTitle(const QString & title)
{
   setWindowTitle(title);
}

void Captcha::setWhiteList(const QString & chars)
{
   ui.line1->setValidator(new QRegExpValidator(QRegExp("[" + chars + "]*"), this));
}

void Captcha::updateCount(const QString & text)
{
   ui.label2->setText(QString::number(text.length()));
}

void Captcha::displayText()
{
   std::wcout << ui.line1->text().toStdWString();
   exit(0);
}
