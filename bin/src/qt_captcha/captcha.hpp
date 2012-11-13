#ifndef FORM_HPP
#define FORM_HPP

#include <QWidget>
#include <QRegExpValidator>
#include <iostream>

#include "ui_form.h"

class Captcha : public QWidget
{
   Q_OBJECT

   Ui::Form ui;

public:
   Captcha(QWidget * parent = 0);

   void setFile(const QString &);
   void setTitle(const QString &);
   void setWhiteList(const QString &);

private slots:
   void updateCount(const QString &);
   void displayText();
};

#endif // FORM_HPP
