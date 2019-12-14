const std = @import("std");
const absInt = std.math.absInt;
const absFloat = std.math.absFloat;

const sdl = @import("sdl.zig");
const Direction = @import("entities.zig").Direction;

inline fn abs(x: var) @TypeOf(x) {
    if (@TypeOf(x) == f32) {
        return absFloat(x);
    } else {
        return absInt(x) catch unreachable;
    }
}

fn Vec2(comptime ValType: type) type {
    return struct {
        x: ValType,
        y: ValType,

        const Self = @This();

        pub fn new(_x: ValType, _y: ValType) Self {
            return Self{
                .x = _x,
                .y = _y,
            };
        }

        pub fn add(a: Self, b: Self) Self {
            return Self.new(a.x + b.x, a.y + b.y);
        }

        pub fn addi(a: *Self, b: Self) Self {
            a.x += b.x;
            a.y += b.y;
            return a.*;
        }

        pub fn sub(a: Self, b: Self) Self {
            return Self.new(
                a.x - b.x,
                a.y - b.y,
            );
        }

        pub fn subi(a: *Self, b: Self) Self {
            a.x -= b.x;
            a.y -= b.y;
            return a.*;
        }

        pub fn neg(a: Self) Self {
            return Self.new(
                -a.x,
                -a.y,
            );
        }

        pub fn mul(self: Self, scalar: ValType) Self {
            return Self.new(
                self.x * scalar,
                self.y * scalar,
            );
        }

        pub fn muli(self: *Self, scalar: ValType) Self {
            self.x *= scalar;
            self.y *= scalar;
            return self.*;
        }

        pub fn mulf(self: Self, scalar: f32) Self {
            if (ValType == f32) {
                return Self.new(self.x * scalar, self.y * scalar);
            } else {
                return Self.new(
                    @floatToInt(i32, @intToFloat(f32, self.x) * scalar),
                    @floatToInt(i32, @intToFloat(f32, self.y) * scalar),
                );
            }
        }

        pub fn mulfi(self: *Self, scalar: f32) Self {
            comptime if (ValType == f32) {
                self.x *= scalar;
                self.y *= scalar;
            } else {
                self.x = @floatToInt(i32, @intToFloat(f32, self.x) * scalar);
                self.y = @floatToInt(i32, @intToFloat(f32, self.y) * scalar);
            };
            return self.*;
        }

        pub fn div(self: Self, scalar: ValType) Self {
            return Self.new(
                @divFloor(self.x, scalar),
                @divFloor(self.y, scalar),
            );
        }

        pub fn divi(self: *Self, scalar: ValType) Self {
            self.x = @divFloor(self.x, scalar);
            self.y = @divFloor(self.y, scalar);
            return self.*;
        }

        pub fn divf(self: Self, scalar: f32) Self {
            if (ValType == f32) {
                return Self.new(self.x / scalar, self.y / scalar);
            } else {
                return Self.new(
                    @floatToInt(i32, @intToFloat(f32, self.x) / scalar),
                    @floatToInt(i32, @intToFloat(f32, self.y) / scalar),
                );
            }
        }

        pub fn divfi(self: *Self, scalar: f32) Self {
            self.x = @floatToInt(i32, @intToFloat(f32, self.x) / scalar);
            self.y = @floatToInt(i32, @intToFloat(f32, self.y) / scalar);
            return self.*;
        }

        pub fn mod(self: Self, scalar: i32) Self {
            return Self.new(
                @mod(self.x, scalar),
                @mod(self.y, scalar),
            );
        }

        pub fn modi(self: *Self, scalar: i32) Self {
            self.x = @mod(self.x, scalar);
            self.y = @mod(self.y, scalar);
            return self.*;
        }

        pub fn negi(a: *Self) Self {
            a.x = -a.x;
            a.y = -a.y;
            return a.*;
        }

        pub fn floor(self: Self) Vec2(i32) {
            if (ValType == i32) {
                return Self.new(self.x, self.y);
            } else {
                return Vec2(i32).new(
                    @floatToInt(i32, std.math.floor(self.x)),
                    @floatToInt(i32, std.math.floor(self.y)),
                );
            }
        }

        pub fn ceil(self: Self) Vec2(i32) {
            if (ValType == f32) {
                return Vec2(i32).new(
                    @floatToInt(i32, std.math.ceil(self.x)),
                    @floatToInt(i32, std.math.ceil(self.y)),
                );
            } else {
                return Self.new(self.x, self.y);
            }
        }

        pub fn equals(a: Self, b: Self) bool {
            return a.x == b.x and
                a.y == b.y;
        }

        pub fn hash(vec: Self) u32 {
            var seed: u32 = 2;
            seed ^= @bitCast(u32, vec.x) +%
                0x9e3779b9 +% (seed << 6) +% (seed >> 2);
            seed ^= @bitCast(u32, vec.y) +%
                0x9e3779b9 +% (seed << 6) +% (seed >> 2);
            return seed;
        }

        pub fn to_sdl(self: Self) sdl.Point {
            return sdl.Point{ .x = self.x, .y = self.y };
        }

        pub fn to_int(self: Self, comptime IT: type) Vec2(IT) {
            return Vec2(IT).new(
                @floatToInt(IT, self.x),
                @floatToInt(IT, self.y),
            );
        }

        pub fn to_float(self: Self, comptime FT: type) Vec2(FT) {
            if (ValType == f32) {
                return Self.new(self.x, self.y);
            } else {
                return Vec2(FT).new(
                    @intToFloat(FT, self.x),
                    @intToFloat(FT, self.y),
                );
            }
        }

        pub fn length_sq(self: Self) f32 {
            if (ValType == f32) {
                return self.x * self.x + self.y * self.y;
            } else {
                const x = @intToFloat(f32, self.x);
                const y = @intToFloat(f32, self.y);
                return x * x + y * y;
            }
        }

        pub fn distanceInt(self: Self, other: Vec2i) u32 {
            const distance = abs: {
                if (self.x == other.x) {
                    break :abs abs(self.y - other.y);
                } else if (self.y == other.y) {
                    break :abs abs(self.x - other.x);
                }
                unreachable;
            };
            return @intCast(u32, distance);
        }

        pub fn move(self: Self, distance: u32, direction: Direction) Self {
            const signed_dist = @intCast(i32, distance);
            return self.add(direction.delta().muli(signed_dist));
        }
    };
}

pub const Vec2i = Vec2(i32);
pub const Vec2f = Vec2(f32);

fn Rect(comptime T: type) type {
    return struct {
        const Self = @This();
        pos: Vec2(T),
        size: Vec2(T),

        pub fn new(pos: Vec2(T), size: Vec2(T)) Self {
            return Self{
                .pos = pos,
                .size = size,
            };
        }

        pub fn box(x: T, y: T, w: T, h: T) Self {
            return Self{
                .pos = Vec2(T).new(x, y),
                .size = Vec2(T).new(w, h),
            };
        }

        pub fn translate(self: *Self, vec: Vec2(T)) Self {
            self.pos.addi(vec);
            return self;
        }

        pub fn translated(self: *const Self, vec: Vec2(T)) Self {
            return Self{
                .pos = self.pos.add(vec),
                .size = self.size,
            };
        }

        pub fn contains(self: *const Self, point: Vec2(T)) bool {
            return point.x >= self.pos.x and
                point.x < (self.pos.x + self.size.x) and
                point.y >= self.pos.y and
                point.y < (self.pos.y + self.size.y);
        }

        pub fn expand_to_contain(self: *Self, point: Vec2(T)) void {
            if (point.x < self.pos.x) {
                self.size.x += self.pos.x - point.x;
                self.pos.x = point.x;
            } else if (point.x >= (self.pos.x + self.size.x)) {
                self.size.x = point.x - self.pos.x + 1;
            }

            if (point.y < self.pos.y) {
                self.size.y += self.pos.y - point.y;
                self.pos.y = point.y;
            } else if (point.y >= (self.pos.y + self.size.y)) {
                self.size.y = point.y - self.pos.y + 1;
            }
        }

        pub fn intersect_x(self: *Self, x_start: ValType, x_end: ValType) Self {
            const start = if (x_start < x_end) x_start else x_end;
            const end = if (x_start < x_end) x_end else x_start;

            if (start >= self.x + self.w or end < self.x) {
                self.w = 0;
                return;
            }

            if (start > self.x) self.x = start;
            if (end < self.x + self.w) self.w -= end - self.x;
        }

        pub fn intersect_y(self: *Self, y_start: ValType, x_end: ValType) Self {
            const start = if (y_start < y_end) y_start else y_end;
            const end = if (y_start < y_end) y_end else y_start;

            if (start >= self.y + self.h or end < self.y) {
                self.h = 0;
                return;
            }

            if (start > self.y) self.y = start;
            if (end < self.y + self.h) self.h -= end - self.y;
        }

        /// Turns rectangles with negative size into the same rectangle
        /// but with positive size
        pub fn canonic(self: *const Self) Self {
            const new_x = std.math.min(self.pos.x, self.pos.x + self.size.x);
            const new_y = std.math.min(self.pos.y, self.pos.y + self.size.y);
            const new_w = abs(self.size.x);
            const new_h = abs(self.size.y);
            return Self{
                .pos = Vec2(T).new(new_x, new_y),
                .size = Vec2(T).new(new_w, new_h),
            };
        }

        pub fn to_sdl(self: Self) sdl.Self {
            return sdl.Self{
                .x = self.pos.x,
                .y = self.pos.y,
                .w = self.size.x,
                .h = self.size.y,
            };
        }
    };
}

pub const Recti = Rect(i32);
pub const Rectf = Rect(f32);
