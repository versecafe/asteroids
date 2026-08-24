const rl = @import("raylib");
const rlm = rl.math;
const types = @import("types.zig");
const c = @import("constants.zig");

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
    drawLines(asteroid.position, asteroid.size.size(), 0.0, asteroid.points[0..asteroid.point_count]);

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

fn drawShip(ship: types.Ship, now: f32) void {
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

    if (ship.thrusting and @mod(@as(i32, @intFromFloat(now * 20.0)), 3) != 0) {
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
        rl.drawCircleLinesV(ship.position, c.SHIP_COLLISION_SIZE * c.SCALE, rl.Color.green);
    }
}

pub fn paint(state: *types.State) !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.black);

    rl.drawText(state.score_text, 10, 10, 10, rl.Color.white);

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
        drawShip(state.ship, state.now);
    }
}
