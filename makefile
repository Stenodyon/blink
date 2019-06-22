SRC:=$(shell find src/ -type f -name '*.zig')

#LIB_PATH:=/usr/lib/x86_64-linux-gnu
LIB_PATH:=/usr/lib
INCLUDE_PATH:=/usr/include

default: blink

blink: $(SRC)
	zig build

clean:
	rm -rf zig-cache blink blink.o

.PHONY: default clean
