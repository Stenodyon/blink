const std = @import("std");
const swap = std.mem.swap;

const Direction = @import("entities.zig").Direction;
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect = vec.Rect;

pub const LightRay = struct {
    direction: Direction,
    origin: Vec2i,
    length: ?u32,

    pub fn new(direction: Direction, origin: Vec2i, length: ?u32) LightRay {
        return LightRay{
            .direction = direction,
            .origin = origin,
            .length = length,
        };
    }

    pub fn get_endpoint(self: *const LightRay) ?Vec2i {
        if (self.length) |len| {
            return self.origin.move(len, self.direction);
        } else {
            return null;
        }
    }

    // Used to check if the ray is visible
    pub fn intersects(self: *const LightRay, area: Rect) bool {
        switch (self.direction) {
            .UP, .DOWN => {
                if (self.origin.x < area.pos.x or self.origin.x >= (area.pos.x + area.size.x))
                    return false;
                if (self.get_endpoint()) |endpoint| {
                    var min_val = self.origin.y;
                    var max_val = endpoint.y;
                    if (min_val > max_val) swap(i32, &min_val, &max_val);

                    if (min_val >= (area.pos.y + area.size.y) or max_val < area.pos.y)
                        return false;
                } else {
                    if (self.direction == .DOWN and self.origin.y >= (area.pos.y + area.size.y))
                        return false;
                    if (self.direction == .UP and self.origin.y < area.pos.y)
                        return false;
                }

                return true;
            },
            .LEFT, .RIGHT => {
                if (self.origin.y < area.pos.y or self.origin.y >= (area.pos.y + area.size.y))
                    return false;
                if (self.get_endpoint()) |endpoint| {
                    var min_val = self.origin.x;
                    var max_val = endpoint.x;
                    if (min_val > max_val) swap(i32, &min_val, &max_val);

                    if (min_val >= (area.pos.x + area.size.x) or max_val < area.pos.x)
                        return false;
                } else {
                    if (self.direction == .DOWN and self.origin.x >= (area.pos.x + area.size.x))
                        return false;
                    if (self.direction == .UP and self.origin.x < area.pos.x)
                        return false;
                }

                return true;
            },
        }
    }
};
