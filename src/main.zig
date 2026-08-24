const std = @import("std");
const rl = @import("raylib");
const types = @import("types.zig");
const render = @import("render.zig");
const logic = @import("logic.zig");
const c = @import("constants.zig");

pub fn main(init: std.process.Init) !void {
    try c.parseConfig(init.io);

    rl.initWindow(@as(i32, @intFromFloat(c.WINDOW_SIZE.x)), @as(i32, @intFromFloat(c.WINDOW_SIZE.y)), "Asteroids!");
    defer rl.closeWindow();
    rl.setWindowPosition(300, 100);
    rl.setTargetFPS(120);

    const allocator = init.gpa;
    var prng = std.Random.Xoshiro256.init(c.SEED);

    var state: types.State = .{
        .allocator = allocator,
        .random = prng.random(),
        .ship = .{
            .position = rl.math.vector2Scale(c.WINDOW_SIZE, 0.5),
        },
    };
    defer state.asteroids.deinit(allocator);
    defer state.particles.deinit(allocator);
    defer state.projectiles.deinit(allocator);

    try logic.initAsteroids(&state); // crate the initial asteroids

    while (!rl.windowShouldClose()) {
        try logic.update(&state); // update global state
        try render.paint(&state); // render new frame off state
    }
}

// test a basic state setup, run a update, and confirm no memory leaks after deinit
test "init without graphics" {
    try c.parseConfig(std.testing.io);

    const allocator = std.testing.allocator;
    var prng = std.Random.Xoshiro256.init(@bitCast(std.Io.Timestamp.now(std.testing.io, .real).toSeconds()));

    var state: types.State = .{
        .allocator = allocator,
        .random = prng.random(),
        .ship = .{
            .position = rl.math.vector2Scale(c.WINDOW_SIZE, 0.5),
        },
    };
    defer state.asteroids.deinit(allocator);
    defer state.particles.deinit(allocator);
    defer state.projectiles.deinit(allocator);

    try logic.initAsteroids(&state);

    try logic.update(&state);

    try std.testing.expectEqual(state.asteroids.items.len <= 20, true);
    try std.testing.expectEqual(state.particles.items.len == 0, true);
    try std.testing.expectEqual(state.projectiles.items.len == 0, true);
}
