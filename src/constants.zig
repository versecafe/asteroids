const rl = @import("raylib");
const rlm = rl.math;

pub const THICKNESS = 2.0;
pub const SCALE = 25.0;
pub const WINDOW_SIZE = rl.Vector2.init(640 * 1.2, 480 * 1.2);
pub const ROT_SPEED = 0.8; // rotations per second
pub const ROT_DRAG = 0.09;
pub const DRAG = 0.03;
pub const SPEED = 0.25;
pub const DEBUG = false;
pub const SHIP_COLISION_SIZE = 0.4;
pub const SCREEN_CENTER = rlm.rl.Vector2Scale(WINDOW_SIZE, 0.5);
pub const SPAWN_RADIUS = 3.0;
