SRC=$(shell find src/ -type f -name '*.zig')

default: blink

blink: $(SRC)
	zig build-exe src/main.zig --output blink -L/usr/lib/x86_64-linux-gnu --library SDL2

clean:
	rm -f blink

.PHONY: default clean
