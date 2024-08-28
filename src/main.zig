const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const types = @import("types.zig");
const render = @import("render.zig");
const logic = @import("logic.zig");
const c = @import("constants.zig");

pub fn main() !void {
    rl.initWindow(c.WINDOW_SIZE.x, c.WINDOW_SIZE.y, "Asteroids!");
    rl.setWindowPosition(300, 100);
    rl.setTargetFPS(120);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var prng = std.rand.Xoshiro256.init(@bitCast(std.time.timestamp())); // seed

    var state: types.State = .{
        .random = prng.random(),
        .ship = .{
            .position = rl.math.vector2Scale(c.WINDOW_SIZE, 0.5),
        },
        .asteroids = std.ArrayList(types.Asteroid).init(allocator),
        .particles = std.ArrayList(types.Particle).init(allocator),
        .projectiles = std.ArrayList(types.Projectile).init(allocator),
    };
    defer state.asteroids.deinit();
    defer state.particles.deinit();
    defer state.projectiles.deinit();

    try logic.initAsteroids(&state); // crate the initial asteroids

    while (!rl.windowShouldClose()) {
        try logic.update(&state); // update global state
        try render.paint(&state); // render new frame off state
    }
}

// test a basic state setup, run a update, and confirm no memory leaks after deinit
test "init without graphics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var prng = std.rand.Xoshiro256.init(@bitCast(std.time.timestamp())); // seed

    var state: types.State = .{
        .random = prng.random(),
        .ship = .{
            .position = rl.math.vector2Scale(c.WINDOW_SIZE, 0.5),
        },
        .asteroids = std.ArrayList(types.Asteroid).init(allocator),
        .particles = std.ArrayList(types.Particle).init(allocator),
        .projectiles = std.ArrayList(types.Projectile).init(allocator),
    };
    defer state.asteroids.deinit();
    defer state.particles.deinit();
    defer state.projectiles.deinit();

    try logic.initAsteroids(&state);

    try logic.update(&state);

    try std.testing.expectEqual(state.asteroids.items.len <= 20, true);
    try std.testing.expectEqual(state.particles.items.len == 0, true);
    try std.testing.expectEqual(state.projectiles.items.len == 0, true);
}
