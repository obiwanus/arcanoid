.SUFFIXES:
.SUFFIXES: .o .c .asm

appname := arcanoid

AS := nasm
ASFLAGS := -f elf -d ELF_TYPE -g
CC := clang
CFLAGS := -g -std=c11 -m32 -Wall -Wconversion
LDLIBS := -lX11 -lm -ldl

asmfiles := $(shell find . -name "*.asm")
objects  := $(patsubst %.asm, %.o, $(asmfiles))

all: $(appname)

%.o : %.asm main.o
	$(AS) $(ASFLAGS) $<

$(appname): $(objects) main.o
	$(CC) $(CFLAGS) -o $(appname) $(objects) main.o $(LDLIBS)

main.o: main.c game.h
	$(CC) $(CFLAGS) -c -o main.o main.c

clean:
	rm -f *.o
	rm -f $(appname)
