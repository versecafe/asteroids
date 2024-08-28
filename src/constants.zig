const rl = @import("raylib");
const rlm = rl.math;
const std = @import("std");

// these are mutable just to allow config.txt to override them
pub var WINDOW_SIZE = rl.Vector2.init(640 * 1.2, 480 * 1.2);
pub var THICKNESS: f32 = 2.0;
pub var SCALE: f32 = 25.0;
pub var ROT_SPEED: f32 = 0.8; // rotations per second
pub var ROT_DRAG: f32 = 0.09;
pub var DRAG: f32 = 0.03;
pub var SPEED: f32 = 0.25;
pub var DEBUG: bool = false;
pub var SHIP_COLISION_SIZE: f32 = 0.4;
pub var SPAWN_RADIUS: f32 = 3.0;
pub var MAX_ASTEROIDS: u32 = 15;

pub fn parseConfig() !void {
    var file = try std.fs.cwd().openFile("config.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var parts = std.mem.split(u8, line, "=");
        if (parts.next()) |key| {
            if (parts.next()) |value| {
                const trimmed_key = std.mem.trim(u8, key, " ");
                const trimmed_value = std.mem.trim(u8, value, " ");
                std.debug.print("{s}, {s}", .{ trimmed_key, trimmed_value });

                inline for (@typeInfo(@This()).Struct.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, trimmed_key)) {
                        std.debug.print(" MATCHED\n", .{});
                        if (std.mem.eql(u8, trimmed_key, "WINDOW_SIZE")) {
                            var sections = std.mem.split(u8, trimmed_value, ",");
                            if (sections.next()) |x| {
                                if (sections.next()) |y| {
                                    WINDOW_SIZE = rl.Vector2.init(
                                        try std.fmt.parseFloat(f32, std.mem.trim(u8, x, " ")),
                                        try std.fmt.parseFloat(f32, std.mem.trim(u8, y, " ")),
                                    );
                                }
                            }
                        }
                        if (std.mem.eql(u8, trimmed_key, "THICKNESS")) {
                            THICKNESS = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "SCALE")) {
                            SCALE = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "ROT_SPEED")) {
                            ROT_SPEED = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "ROT_DRAG")) {
                            ROT_DRAG = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "DRAG")) {
                            DRAG = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "SPEED")) {
                            SPEED = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "DEBUG")) {
                            if (std.mem.eql(u8, trimmed_value, "true")) {
                                DEBUG = true;
                            } else if (std.mem.eql(u8, trimmed_value, "false")) {
                                DEBUG = false;
                            } else {
                                std.debug.print("ERROR: DEBUG must be true or false\n", .{});
                            }
                        }
                        if (std.mem.eql(u8, trimmed_key, "SHIP_COLISION_SIZE")) {
                            SHIP_COLISION_SIZE = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "SPAWN_RADIUS")) {
                            SPAWN_RADIUS = try std.fmt.parseFloat(f32, trimmed_value);
                        }
                        if (std.mem.eql(u8, trimmed_key, "MAX_ASTEROIDS")) {
                            MAX_ASTEROIDS = try std.fmt.parseUnsigned(u32, trimmed_value, 10);
                        }

                        break;
                    }
                } else {
                    std.debug.print(".\n", .{});
                }
            }
        }
    }
}
