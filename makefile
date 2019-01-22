SRC:=$(shell find src/ -type f -name '*.zig')

#LIB_PATH:=/usr/lib/x86_64-linux-gnu
LIB_PATH:=/usr/lib

default: blink

blink: $(SRC)
	zig build-exe src/main.zig --output blink -L$(LIB_PATH) \
	    --library SDL2 --library SDL2_image

clean:
	rm -f blink

.PHONY: default clean
