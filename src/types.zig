const std = @import("std");
const rl = @import("raylib");
const rlm = rl.math;
const c = @import("constants.zig");

pub const Ship = struct {
    position: rl.Vector2,
    velocity: rl.Vector2 = rl.Vector2.init(0.0, 0.0),
    rotation: f32 = 0.0,
    rotational_velocity: f32 = 0.0,
    thrusting: bool = false,
    alive: bool = true,
    death_time: f32 = 0.0,
    last_shot: f32 = 0.0,
};

pub const AsteroidSize = enum {
    BIG,
    MEDIUM,
    SMALL,

    pub fn size(self: @This()) f32 {
        return switch (self) {
            .BIG => c.SCALE * 1,
            .MEDIUM => c.SCALE * 0.8,
            .SMALL => c.SCALE * 0.4,
        };
    }

    pub fn velocityFactor(self: @This()) f32 {
        return switch (self) {
            .BIG => 1.5,
            .MEDIUM => 2.0,
            .SMALL => 3.0,
        };
    }

    pub fn health(self: @This()) i32 {
        return switch (self) {
            .BIG => 5,
            .MEDIUM => 3,
            .SMALL => 2,
        };
    }

    pub fn value(self: @This()) i32 {
        return switch (self) {
            .BIG => 100,
            .MEDIUM => 50,
            .SMALL => 20,
        };
    }
};

pub const Asteroid = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    size: AsteroidSize,
    health: i32,
    points: std.BoundedArray(rl.Vector2, 16),
};

pub const ParticleType = enum {
    LINE,
    DOT,
};

pub const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
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

pub const Projectile = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    rotation: f32,
    ttl: f32,
};

pub const State = struct {
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
