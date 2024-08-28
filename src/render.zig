const std = @import("std");
const rl = @import("raylib");
const rlm = rl.math;
const rg = @import("raygui");
const types = @import("types.zig");
const c = @import("constants.zig");

fn screenWrapPosition(p: rl.Vector2) rl.Vector2 {
    // wrap after origin crosses the screen + 1.5 to allow smooth out of site instead of jumping
    return rl.Vector2.init(@mod(p.x, c.WINDOW_SIZE.x + (1.5 * c.SCALE)), @mod(p.y, c.WINDOW_SIZE.y + (1.5 * c.SCALE)));
}

fn drawLines(origin: rl.Vector2, scale: f32, rotation: f32, points: []const rl.Vector2) void {
    const Transformer = struct {
        origin: rl.Vector2,
        scale: f32,
        rotation: f32,

        fn apply(self: @This(), p: rl.Vector2) rl.Vector2 {
            return rlm.vector2Add(
                rlm.vector2Scale(rlm.vector2Rotate(p, self.rotation), self.scale),
                self.origin,
            );
        }
    };

    const t = Transformer{ .origin = origin, .scale = scale, .rotation = rotation };

    for (0..points.len) |index| {
        rl.drawLineEx(
            t.apply(points[index]),
            t.apply(points[(index + 1) % points.len]),
            c.THICKNESS,
            rl.Color.white,
        );
    }
}

fn drawAsteroid(asteroid: types.Asteroid) void {
    drawLines(asteroid.position, asteroid.size.size(), 0.0, asteroid.points.slice());

    if (c.DEBUG) {
        rl.drawCircleLinesV(asteroid.position, asteroid.size.size(), rl.Color.red);
    }
}

fn drawParticle(particle: types.Particle) void {
    switch (particle.type) {
        .LINE => |line| {
            drawLines(
                particle.position,
                line.length,
                line.rotation,
                &.{ rl.Vector2.init(-0.5, 0), rl.Vector2.init(0.5, 0) },
            );
        },
        .DOT => |dot| {
            rl.drawCircleV(particle.position, dot.radius, rl.Color.white);
        },
    }
}

fn drawProjectile(projectile: types.Projectile) void {
    drawLines(
        projectile.position,
        0.3 * c.SCALE,
        projectile.rotation,
        &.{ rl.Vector2.init(0, -0.5), rl.Vector2.init(0, 0.5) },
    );
}

fn drawShip(ship: types.Ship, state: *types.State) void {
    drawLines(
        ship.position,
        c.SCALE,
        ship.rotation,
        &.{
            rl.Vector2.init(-0.4, -0.5),
            rl.Vector2.init(0.0, 0.5),
            rl.Vector2.init(0.4, -0.5),
            rl.Vector2.init(0.3, -0.4),
            rl.Vector2.init(-0.3, -0.4),
            rl.Vector2.init(-0.4, -0.5),
        },
    );

    if (ship.thrusting and @mod(@as(i32, @intFromFloat(state.now * 20.0)), 3) != 0) {
        drawLines(
            ship.position,
            c.SCALE,
            ship.rotation,
            &.{
                rl.Vector2.init(-0.2, -0.5),
                rl.Vector2.init(0.0, -0.7),
                rl.Vector2.init(0.2, -0.5),
            },
        );
    }

    if (c.DEBUG) {
        rl.drawCircleLinesV(ship.position, c.SHIP_COLISION_SIZE * c.SCALE, rl.Color.red);
    }
}

fn spawnDeathParticles(position: rl.Vector2, state: *types.State) !void {
    for (0..5) |_| {
        const angle = std.math.tau * state.random.float(f32);
        try state.particles.append(
            .{ .position = rlm.vctor2Add(
                position,
                rl.Vector2.init(
                    state.random.float(f32) * 2,
                    state.random.float(f32) * 2,
                ),
            ), .velocity = rlm.vector2Scale(
                rl.Vector2.init(
                    std.math.cos(angle),
                    std.math.sin(angle),
                ),
                2.0 * std.math.sin(state.random.float(f32)),
            ), .ttl = 1 + (2 * state.random.float(f32)), .type = .{
                .LINE = .{
                    .rotation = std.math.tau * state.random.float(f32),
                    .length = c.SCALE * (0.5 + (0.5 * state.random.float(f32))),
                },
            } },
        );
    }
}

fn shootProjectile(state: *types.State) !void {
    // throttle to one shot per 0.25 seconds
    if (state.ship.last_shot < state.now - 0.25) {
        state.ship.last_shot = state.now;
        const angle = state.ship.rotation;
        try state.projectiles.append(
            .{
                .position = state.ship.position,
                .velocity = rlm.vector2Add(
                    state.ship.velocity,
                    rlm.vector2Scale(
                        rl.Vector2.init(
                            -std.math.sin(angle),
                            std.math.cos(angle),
                        ),
                        3.0,
                    ),
                ),
                .rotation = state.ship.rotation,
                .ttl = 2.5,
            },
        );
    }
}

pub fn paint(state: *types.State) !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.black);

    rl.drawText(@ptrCast(state.score_text), 10, 10, 10, rl.Color.white);

    for (state.asteroids.items) |asteroid| {
        drawAsteroid(asteroid);
    }

    for (state.particles.items) |particle| {
        drawParticle(particle);
    }

    for (state.projectiles.items) |projectile| {
        drawProjectile(projectile);
    }

    if (state.ship.alive) {
        drawShip(state.ship, state);
    }
}
