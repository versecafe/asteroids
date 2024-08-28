const std = @import("std");
const rl = @import("raylib");
const rlm = rl.math;
const rg = @import("raygui");
const Vector2 = rl.Vector2;

const THICKNESS = 2.0;
const SCALE = 25.0;
const WINDOW_SIZE = Vector2.init(640 * 1.2, 480 * 1.2);
const ROT_SPEED = 0.8; // rotations per second
const ROT_DRAG = 0.09;
const DRAG = 0.03;
const SPEED = 0.25;
const DEBUG = false;
const SHIP_COLISION_SIZE = 0.4;
const SCREEN_CENTER = rlm.vector2Scale(WINDOW_SIZE, 0.5);
const SPAWN_RADIUS = 3.0;

const Ship = struct {
    position: Vector2,
    velocity: Vector2 = Vector2.init(0.0, 0.0),
    rotation: f32 = 0.0,
    rotational_velocity: f32 = 0.0,
    thrusting: bool = false,
    alive: bool = true,
    death_time: f32 = 0.0,
    last_shot: f32 = 0.0,
};

const AsteroidSize = enum {
    BIG,
    MEDIUM,
    SMALL,

    fn size(self: @This()) f32 {
        return switch (self) {
            .BIG => SCALE * 1,
            .MEDIUM => SCALE * 0.8,
            .SMALL => SCALE * 0.4,
        };
    }

    fn velocityFactor(self: @This()) f32 {
        return switch (self) {
            .BIG => 1.5,
            .MEDIUM => 2.0,
            .SMALL => 3.0,
        };
    }

    fn health(self: @This()) i32 {
        return switch (self) {
            .BIG => 5,
            .MEDIUM => 3,
            .SMALL => 2,
        };
    }

    fn value(self: @This()) i32 {
        return switch (self) {
            .BIG => 100,
            .MEDIUM => 50,
            .SMALL => 20,
        };
    }
};

const Asteroid = struct {
    position: Vector2,
    velocity: Vector2,
    size: AsteroidSize,
    health: i32,
    points: std.BoundedArray(Vector2, 16),
};

const ParticleType = enum {
    LINE,
    DOT,
};

const Particle = struct {
    position: Vector2,
    velocity: Vector2,
    ttl: f32,
    type: union(ParticleType) {
        LINE: struct {
            rotation: f32,
            length: f32,
        },
        DOT: struct {
            radius: f32,
        },
    },
};

const Projectile = struct {
    position: Vector2,
    velocity: Vector2,
    rotation: f32,
    ttl: f32,
};

const State = struct {
    now: f32 = 0.0,
    delta: f32 = 0.0,
    random: std.Random,
    ship: Ship,
    score: i32 = 0,
    score_text: []const u8 = "0",
    asteroids: std.ArrayList(Asteroid),
    particles: std.ArrayList(Particle),
    projectiles: std.ArrayList(Projectile),
};

fn screenWrapPosition(p: Vector2) Vector2 {
    // wrap after origin crosses the screen + 1.5 to allow smooth out of site instead of jumping
    return Vector2.init(@mod(p.x, WINDOW_SIZE.x + (1.5 * SCALE)), @mod(p.y, WINDOW_SIZE.y + (1.5 * SCALE)));
}

fn drawLines(origin: Vector2, scale: f32, rotation: f32, points: []const Vector2) void {
    const Transformer = struct {
        origin: Vector2,
        scale: f32,
        rotation: f32,

        fn apply(self: @This(), p: Vector2) Vector2 {
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
            THICKNESS,
            rl.Color.white,
        );
    }
}

fn drawAsteroid(asteroid: Asteroid) void {
    drawLines(asteroid.position, asteroid.size.size(), 0.0, asteroid.points.slice());

    if (DEBUG) {
        rl.drawCircleLinesV(asteroid.position, asteroid.size.size(), rl.Color.red);
    }
}

fn drawParticle(particle: Particle) void {
    switch (particle.type) {
        .LINE => |line| {
            drawLines(
                particle.position,
                line.length,
                line.rotation,
                &.{ Vector2.init(-0.5, 0), Vector2.init(0.5, 0) },
            );
        },
        .DOT => |dot| {
            rl.drawCircleV(particle.position, dot.radius, rl.Color.white);
        },
    }
}

fn drawProjectile(projectile: Projectile) void {
    drawLines(
        projectile.position,
        0.3 * SCALE,
        projectile.rotation,
        &.{ Vector2.init(0, -0.5), Vector2.init(0, 0.5) },
    );
}

fn drawShip(ship: Ship, state: *State) void {
    drawLines(
        ship.position,
        SCALE,
        ship.rotation,
        &.{
            Vector2.init(-0.4, -0.5),
            Vector2.init(0.0, 0.5),
            Vector2.init(0.4, -0.5),
            Vector2.init(0.3, -0.4),
            Vector2.init(-0.3, -0.4),
            Vector2.init(-0.4, -0.5),
        },
    );

    if (ship.thrusting and @mod(@as(i32, @intFromFloat(state.now * 20.0)), 3) != 0) {
        drawLines(
            ship.position,
            SCALE,
            ship.rotation,
            &.{
                Vector2.init(-0.2, -0.5),
                Vector2.init(0.0, -0.7),
                Vector2.init(0.2, -0.5),
            },
        );
    }

    if (DEBUG) {
        rl.drawCircleLinesV(ship.position, SHIP_COLISION_SIZE * SCALE, rl.Color.red);
    }
}

fn spawnDeathParticles(position: Vector2, state: *State) !void {
    for (0..5) |_| {
        const angle = std.math.tau * state.random.float(f32);
        try state.particles.append(
            .{ .position = rlm.vector2Add(
                position,
                Vector2.init(
                    state.random.float(f32) * 2,
                    state.random.float(f32) * 2,
                ),
            ), .velocity = rlm.vector2Scale(
                Vector2.init(
                    std.math.cos(angle),
                    std.math.sin(angle),
                ),
                2.0 * std.math.sin(state.random.float(f32)),
            ), .ttl = 1 + (2 * state.random.float(f32)), .type = .{
                .LINE = .{
                    .rotation = std.math.tau * state.random.float(f32),
                    .length = SCALE * (0.5 + (0.5 * state.random.float(f32))),
                },
            } },
        );
    }
}

fn shootProjectile(state: *State) !void {
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
                        Vector2.init(
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

fn render(state: *State) !void {
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

pub fn copyIntStr(n: i32) []const u8 {
    var buffer: [4096]u8 = undefined;
    const result = std.fmt.bufPrintZ(buffer[0..], "{d}", .{n}) catch unreachable;
    return @as([]const u8, result);
}

fn update(state: *State) !void {
    state.delta = rl.getFrameTime();
    state.now += state.delta;

    if (rl.isKeyDown(rl.KeyboardKey.key_a) or rl.isKeyDown(rl.KeyboardKey.key_left)) {
        state.ship.rotational_velocity -= state.delta * ROT_SPEED;
    }
    if (rl.isKeyDown(rl.KeyboardKey.key_d) or rl.isKeyDown(rl.KeyboardKey.key_right)) {
        state.ship.rotational_velocity += state.delta * ROT_SPEED;
    }

    state.ship.rotational_velocity = state.ship.rotational_velocity * (1.0 - ROT_DRAG);
    state.ship.rotation += state.ship.rotational_velocity;

    if (rl.isKeyDown(rl.KeyboardKey.key_w) or rl.isKeyDown(rl.KeyboardKey.key_up)) {
        const angle = state.ship.rotation + (std.math.pi * 0.5);
        const direction = Vector2.init(
            std.math.cos(angle),
            std.math.sin(angle),
        );
        state.ship.velocity = rlm.vector2Add(
            state.ship.velocity,
            rlm.vector2Scale(direction, SPEED),
        );
        state.ship.thrusting = true;
    } else {
        state.ship.thrusting = false;
    }

    state.ship.velocity = rlm.vector2Scale(state.ship.velocity, 1.0 - DRAG);
    state.ship.position = screenWrapPosition(rlm.vector2Add(
        state.ship.position,
        state.ship.velocity,
    ));

    var index: usize = 0;
    while (index < state.asteroids.items.len) {
        const asteroid: *Asteroid = &state.asteroids.items[index];
        asteroid.position = screenWrapPosition(
            rlm.vector2Add(asteroid.position, asteroid.velocity),
        );

        if (rlm.vector2Distance(asteroid.position, state.ship.position) < (asteroid.size.size() + (SHIP_COLISION_SIZE * SCALE)) and state.ship.alive) {
            state.ship.alive = false;
            state.ship.death_time = state.now;

            try spawnDeathParticles(state.ship.position, state);
        }
        if (asteroid.health > 0) {
            var projectile_index: usize = 0;
            while (projectile_index < state.projectiles.items.len) {
                var projectile: *Projectile = &state.projectiles.items[projectile_index];
                if (rlm.vector2Distance(asteroid.position, projectile.position) < (asteroid.size.size() + (0.3 * SCALE))) {
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
        var particle: *Particle = &state.particles.items[index];
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
        var projectile: *Projectile = &state.projectiles.items[index];
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

fn initAsteroids(state: *State) !void {
    for (0..20) |_| {
        const angle = std.math.tau * state.random.float(f32);
        const size = state.random.enumValue(AsteroidSize);
        const position = Vector2.init(
            state.random.float(f32) * WINDOW_SIZE.x,
            state.random.float(f32) * WINDOW_SIZE.y,
        );
        var points = try std.BoundedArray(Vector2, 16).init(0);
        const n = state.random.intRangeAtMost(i32, 8, 16);

        for (0..@intCast(n)) |index| {
            const radius = 0.9 + (0.35 * state.random.float(f32));
            const point_angle = (@as(f32, @floatFromInt(index)) * (std.math.tau / @as(f32, @floatFromInt(n)))) + (std.math.pi * 0.1 * state.random.float(f32));
            try points.append(rlm.vector2Scale(
                Vector2.init(std.math.cos(point_angle), std.math.sin(point_angle)),
                radius,
            ));
        }
        if (!(rlm.vector2Distance(position, state.ship.position) < (size.size() + (SPAWN_RADIUS * SCALE)))) {
            try state.asteroids.append(.{
                .position = position,
                .velocity = rlm.vector2Scale(
                    Vector2.init(std.math.cos(angle), std.math.sin(angle)),
                    size.velocityFactor() * state.random.float(f32),
                ),
                .size = size,
                .health = size.health(),
                .points = points,
            });
        }
    }
}

fn reset(state: *State) !void {
    state.ship.alive = true;
    state.ship.death_time = 0.0;
    state.score = 0;
    state.score_text = "";
    state.ship = .{
        .position = rlm.vector2Scale(WINDOW_SIZE, 0.5),
    };
    try state.asteroids.resize(0);
    try state.particles.resize(0);
    try state.projectiles.resize(0);

    try initAsteroids(state);
}

pub fn main() !void {
    rl.initWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Asteroids!");
    rl.setWindowPosition(300, 100);
    rl.setTargetFPS(120);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var prng = std.rand.Xoshiro256.init(@bitCast(std.time.timestamp())); // seed

    var state: State = undefined;
    state = .{
        .random = prng.random(),
        .ship = .{
            .position = rlm.vector2Scale(WINDOW_SIZE, 0.5),
        },
        .asteroids = std.ArrayList(Asteroid).init(allocator),
        .particles = std.ArrayList(Particle).init(allocator),
        .projectiles = std.ArrayList(Projectile).init(allocator),
    };
    defer state.asteroids.deinit();
    defer state.particles.deinit();
    defer state.projectiles.deinit();

    try initAsteroids(&state);

    while (!rl.windowShouldClose()) {
        try update(&state); // update global state
        try render(&state); // render new frame off state
    }
}

test "init without graphics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var prng = std.rand.Xoshiro256.init(@bitCast(std.time.timestamp())); // seed

    var state: State = undefined;
    state = .{
        .random = prng.random(),
        .ship = .{
            .position = rlm.vector2Scale(WINDOW_SIZE, 0.5),
        },
        .asteroids = std.ArrayList(Asteroid).init(allocator),
        .particles = std.ArrayList(Particle).init(allocator),
        .projectiles = std.ArrayList(Projectile).init(allocator),
    };
    defer state.asteroids.deinit();
    defer state.particles.deinit();
    defer state.projectiles.deinit();

    try initAsteroids(&state);

    try std.testing.expectEqual(state.asteroids.items.len <= 20, true);
    try std.testing.expectEqual(state.particles.items.len == 0, true);
    try std.testing.expectEqual(state.projectiles.items.len == 0, true);
}
