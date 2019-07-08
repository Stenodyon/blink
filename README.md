# Blink

Blink is a game prototype I am developing [on
stream](https://www.twitch.tv/stenodyon). It is a puzzle game involving lasers
and mirrors, and is heavily inspired by
[OCTOPTICOM](https://store.steampowered.com/app/943190/OCTOPTICOM/).

## Cloning

This project uses the [Lazy-Zig](https://github.com/BraedonWooding/Lazy-Zig)
library as a git submodule. Once cloned, run

```
git submodule update --init --recursive
```

## Building

Blink uses the zig build system. If the dependencies are met, you can simply run
```
zig build
```

Optionally Blink can use GNU make to build.

Dependencies:

* `zig 0.4.0+be51511d2` (this is not the 0.4.0 release, this was the master
  branch last time I worked on this project, I'll stop using zig master branch
  at 0.5.0)
* `SDL2`
* `SDL2_ttf`
