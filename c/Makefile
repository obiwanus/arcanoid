.SUFFIXES:
.SUFFIXES: .o .c .h

appname := arcanoid

CC := clang
CFLAGS := -g -std=c11 -Wall -Wconversion
LDLIBS := -lX11 -lm -ldl

srcfiles := $(shell find . -name "*.c")
hfiles := $(shell find . -name "*.h")
objects  := $(patsubst %.c, %.o, $(srcfiles))

all: $(appname)

%.o : %.c %.h
	$(CC) $(CFLAGS) -c $< -o $@

$(appname): $(objects) $(hfiles)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(appname) $(objects) $(LDLIBS)

clean:
	rm -f $(objects)
	rm -f $(appname)
