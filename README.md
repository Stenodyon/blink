# Blink

Blink is a game prototype I am developing [on
stream](https://www.twitch.tv/stenodyon). It is a puzzle game involving lasers
and mirrors, and is heavily inspired by [Logic World](https://logicworld.net/)
and [OCTOPTICOM](https://store.steampowered.com/app/943190/OCTOPTICOM/).

## Cloning

This project uses the [Lazy-Zig](https://github.com/BraedonWooding/Lazy-Zig)
library as a git submodule. Once cloned, run

```
git submodule update --init --recursive
```

## Building
Dependencies:

* `0.4.0+3879bebc` (this is not the 0.4.0 release, this was the master
  branch last time I worked on this project, I'll stop using zig master branch
  at 0.5.0)
* `SDL2`
* `SDL2_ttf`
* `libGL`
* `libepoxy`
* `libSOIL`

Blink uses the zig build system. If the dependencies are met, you can simply run
```
zig build
```

The makefile calls the zig build system if you prefer GNU make.

## Usage

```bash
./blink [save-file]
```

## Controls

* Left click to place an item, right click to remove
* Hold left click to pan around
* Mouse wheel to zoom in/out.
* Ctrl+mouse wheel or 1-9 numbers to select an item
* Q and E to rotate the item
* F to flip switches
* F6 to save to "test.sav" (saving and loading is experimental)

## Available items

* **Block**: Blocks any rays hitting it
* **Laser**: Generates a light ray, always on.
* **Mirror**: Reflects light rays at a 90 degree angle.
* **Splitter**: Transparent mirror, will reflect *and* refract a light ray,
  effectivly splitting it. Can be used to merge rays as well.
* **Delayer**: Will delay the propagation of the ray by 1 tick.
* **Switch**: Will propagate the ray with a 1 tick delay like the delayer, but
  will cut the output when an input is received on the side.

