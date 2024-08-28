This is just a simple project for learning zig but it does provide a working
game of asteroids for any platform if anyone is bored and wants to give it a
try.

## Building

To build the game you need to have zig installed. You can get it from
https://ziglang.org/download/

Once you have zig installed you can build the game by running:

```sh
zig build --release=fast
```

This will create a `zig-cache` directory and a `asteroids` executable in the
current directory.

## Running

To run the game you can run:

```sh
./zig-out/bin/asteroids
```

## Controls

- W - Move forward
- A - Rotate left
- R - Rotate right
- Space - Fire

## Configuration File

The game can be configured by modifying the `config.txt` file, it can modify
the following fields:

```zig
var WINDOW_SIZE = rl.Vector2.init(640 * 1.2, 480 * 1.2);
var THICKNESS: f32 = 2.0;
var SCALE: f32 = 25.0;
var ROT_SPEED: f32 = 0.8; // rotations per second
var ROT_DRAG: f32 = 0.09;
var DRAG: f32 = 0.03;
var SPEED: f32 = 0.25;
var DEBUG: bool = false;
var SHIP_COLISION_SIZE: f32 = 0.4;
var SPAWN_RADIUS: f32 = 3.0;
var MAX_ASTEROIDS: u32 = 15;
```

declaring the variables works like so, note all fields are optional:

```env
DEBUG=false
SHIP_COLISION_SIZE=0.4
SPAWN_RADIUS=3.0
MAX_ASTEROIDS=15
WINDOW_SIZE=800,600
```

## Run Dev or Test

If you are actually working on this as a jumping off point to learn zig you can use the
following commands to run and test the game:

```sh
zig build run # compiles and launches without optimizations
```

```sh
zig build test # runs the base tests for init update and no mem leaks
```

Note that `config.txt` is still used when running the game in dev mode or runnint tests,
try setting `DEBUG=true` in `config.txt` to see the collision debug mode.
