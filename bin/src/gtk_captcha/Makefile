TARGET  = gtk_captcha
LIBS    = `pkg-config --libs gtk+-2.0`
FLAGS   = `pkg-config --cflags gtk+-2.0`
C       = gcc -O3

all:
	$(C) $(FLAGS) $(LIBS) main.c -o $(TARGET)
	strip $(TARGET)

clean:
	rm -f ./*.o $(TARGET)
