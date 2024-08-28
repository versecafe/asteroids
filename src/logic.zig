const std = @import("std");
const rl = @import("raylib");
const rlm = rl.math;
const types = @import("types.zig");
const c = @import("constants.zig");

fn screenWrapPosition(p: rl.Vector2) rl.Vector2 {
    // wrap after origin crosses the screen + 1.5 to allow smooth out of site instead of jumping
    return rl.Vector2.init(@mod(p.x, c.WINDOW_SIZE.x + (1.5 * c.SCALE)), @mod(p.y, c.WINDOW_SIZE.y + (1.5 * c.SCALE)));
}

fn spawnDeathParticles(position: rl.Vector2, state: *types.State) !void {
    for (0..5) |_| {
        const angle = std.math.tau * state.random.float(f32);
        try state.particles.append(
            .{ .position = rlm.vector2Add(
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

pub fn initAsteroids(state: *types.State) !void {
    for (0..20) |_| {
        const angle = std.math.tau * state.random.float(f32);
        const size = state.random.enumValue(types.AsteroidSize);
        const position = rl.Vector2.init(
            state.random.float(f32) * c.WINDOW_SIZE.x,
            state.random.float(f32) * c.WINDOW_SIZE.y,
        );
        var points = try std.BoundedArray(rl.Vector2, 16).init(0);
        const n = state.random.intRangeAtMost(i32, 8, 16);

        for (0..@intCast(n)) |index| {
            const radius = 0.9 + (0.35 * state.random.float(f32));
            const point_angle = (@as(f32, @floatFromInt(index)) * (std.math.tau / @as(f32, @floatFromInt(n)))) + (std.math.pi * 0.1 * state.random.float(f32));
            try points.append(rlm.vector2Scale(
                rl.Vector2.init(std.math.cos(point_angle), std.math.sin(point_angle)),
                radius,
            ));
        }
        if (!(rlm.vector2Distance(position, state.ship.position) < (size.size() + (c.SPAWN_RADIUS * c.SCALE)))) {
            try state.asteroids.append(.{
                .position = position,
                .velocity = rlm.vector2Scale(
                    rl.Vector2.init(std.math.cos(angle), std.math.sin(angle)),
                    size.velocityFactor() * state.random.float(f32),
                ),
                .size = size,
                .health = size.health(),
                .points = points,
            });
        }
    }
}

fn reset(state: *types.State) !void {
    state.ship.alive = true;
    state.ship.death_time = 0.0;
    state.score = 0;
    state.score_text = "";
    state.ship = .{
        .position = rlm.vector2Scale(c.WINDOW_SIZE, 0.5),
    };
    try state.asteroids.resize(0);
    try state.particles.resize(0);
    try state.projectiles.resize(0);

    try initAsteroids(state);
}

pub fn copyIntStr(n: i32) []const u8 {
    var buffer: [4096]u8 = undefined;
    const result = std.fmt.bufPrintZ(buffer[0..], "{d}", .{n}) catch unreachable;
    return @as([]const u8, result);
}

pub fn update(state: *types.State) !void {
    state.delta = rl.getFrameTime();
    state.now += state.delta;

    if (rl.isKeyDown(rl.KeyboardKey.key_a) or rl.isKeyDown(rl.KeyboardKey.key_left)) {
        state.ship.rotational_velocity -= state.delta * c.ROT_SPEED;
    }
    if (rl.isKeyDown(rl.KeyboardKey.key_d) or rl.isKeyDown(rl.KeyboardKey.key_right)) {
        state.ship.rotational_velocity += state.delta * c.ROT_SPEED;
    }

    state.ship.rotational_velocity = state.ship.rotational_velocity * (1.0 - c.ROT_DRAG);
    state.ship.rotation += state.ship.rotational_velocity;

    if (rl.isKeyDown(rl.KeyboardKey.key_w) or rl.isKeyDown(rl.KeyboardKey.key_up)) {
        const angle = state.ship.rotation + (std.math.pi * 0.5);
        const direction = rl.Vector2.init(
            std.math.cos(angle),
            std.math.sin(angle),
        );
        state.ship.velocity = rlm.vector2Add(
            state.ship.velocity,
            rlm.vector2Scale(direction, c.SPEED),
        );
        state.ship.thrusting = true;
    } else {
        state.ship.thrusting = false;
    }

    state.ship.velocity = rlm.vector2Scale(state.ship.velocity, 1.0 - c.DRAG);
    state.ship.position = screenWrapPosition(rlm.vector2Add(
        state.ship.position,
        state.ship.velocity,
    ));

    var index: usize = 0;
    while (index < state.asteroids.items.len) {
        const asteroid: *types.Asteroid = &state.asteroids.items[index];
        asteroid.position = screenWrapPosition(
            rlm.vector2Add(asteroid.position, asteroid.velocity),
        );

        if (rlm.vector2Distance(asteroid.position, state.ship.position) < (asteroid.size.size() + (c.SHIP_COLISION_SIZE * c.SCALE)) and state.ship.alive) {
            state.ship.alive = false;
            state.ship.death_time = state.now;

            try spawnDeathParticles(state.ship.position, state);
        }
        if (asteroid.health > 0) {
            var projectile_index: usize = 0;
            while (projectile_index < state.projectiles.items.len) {
                var projectile: *types.Projectile = &state.projectiles.items[projectile_index];
                if (rlm.vector2Distance(asteroid.position, projectile.position) < (asteroid.size.size() + (0.3 * c.SCALE))) {
                    projectile.ttl = 0;
                    asteroid.health -= 1;
                }
                projectile_index += 1;
            }
            index += 1;
        } else {
            state.score = state.score + asteroid.size.value();
            try spawnDeathParticles(asteroid.position, state);
            _ = state.asteroids.swapRemove(index);
        }
    }

    index = 0;
    while (index < state.particles.items.len) {
        var particle: *types.Particle = &state.particles.items[index];
        particle.position = screenWrapPosition(
            rlm.vector2Add(particle.position, particle.velocity),
        );

        if (particle.ttl > state.delta) {
            particle.ttl -= state.delta;
            index += 1;
        } else {
            _ = state.particles.swapRemove(index);
        }
    }

    index = 0;
    while (index < state.projectiles.items.len) {
        var projectile: *types.Projectile = &state.projectiles.items[index];
        projectile.position = screenWrapPosition(
            rlm.vector2Add(projectile.position, projectile.velocity),
        );

        if (projectile.ttl > state.delta) {
            projectile.ttl -= state.delta;
            index += 1;
        } else {
            _ = state.projectiles.swapRemove(index);
        }
    }

    if (rl.isKeyDown(rl.KeyboardKey.key_space)) {
        try shootProjectile(state);
    }

    state.score_text = copyIntStr(state.score);

    if (!state.ship.alive and (state.now - state.ship.death_time) > 2.0) {
        try reset(state);
    }

    if (state.asteroids.items.len == 0) {
        try initAsteroids(state);
    }
}
