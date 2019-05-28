SRC:=$(shell find src/ -type f -name '*.zig')

#LIB_PATH:=/usr/lib/x86_64-linux-gnu
LIB_PATH:=/usr/lib
INCLUDE_PATH:=/usr/include

default: blink

blink: $(SRC)
	zig build-exe src/main.zig --name blink -isystem $(INCLUDE_PATH) \
	    -L$(LIB_PATH) \
	    --library c \
	    --library SDL2 --library SDL2_image

clean:
	rm -rf zig-cache blink

.PHONY: default clean
