# Blink

Blink is a game prototype I am developing [on
stream](https://www.twitch.tv/stenodyon). It is a puzzle game involving lasers
and mirrors, and is heavily inspired by
[OCTOPTICOM](https://store.steampowered.com/app/943190/OCTOPTICOM/).

## Building

Blink uses the zig build system. If the dependencies are met, you can simply run
```
zig build
```

Optionally Blink can use GNU make to build.

Dependencies:

* `zig 0.4.0`
* `SDL2`