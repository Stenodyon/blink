const std = @import("std");
const swap = std.mem.swap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const entities = @import("entities.zig");
const Direction = entities.Direction;
const Entity = entities.Entity;
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect = vec.Rect;
const State = @import("state.zig").State;

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

/// A LightTree is the entire path a light ray takes, from its origin to
/// its (possibly multiple) end(s)
pub const LightTree = struct {
    origin: Vec2i,
    direction: Direction,

    /// Helps determining when a light tree must be updated (a new entity
    /// has been added for example)
    bounding_box: ?Rect, // null means the whole space
    rays: ArrayList(LightRay),
    leaves: ArrayList(*Entity),

    pub fn new(
        origin: Vec2i,
        direction: Direction,
        allocator: *Allocator,
    ) LightTree {
        return LightTree{
            .origin = origin,
            .direction = direction,
            .bounding_box = Rect.new(origin, Vec2i.new(1, 1)),
            .rays = ArrayList(LightRay).init(allocator),
            .leaves = ArrayList(*Entity).init(allocator),
        };
    }

    pub fn in_bounds(self: *const LightTree, point: Vec2i) bool {
        const area = self.bounding_box orelse return true;
        return area.contains(point);
    }

    pub fn generate(
        self: *LightTree,
        state: *State,
    ) !void {
        try self.propagate_lightray(
            self.origin,
            self.direction,
            state,
        );
        if (self.bounding_box) |bounding_box| {
            std.debug.warn(
                "Tree bounding box is ({}, {}), ({}, {})\n",
                bounding_box.pos.x,
                bounding_box.pos.y,
                bounding_box.size.x,
                bounding_box.size.y,
            );
        } else {
            std.debug.warn("Tree has infinite bounding box\n");
        }
    }

    fn propagate_lightray(
        self: *LightTree,
        origin: Vec2i,
        direction: Direction,
        state: *const State,
    ) error{
        OutOfMemory,
        OutOfBounds,
    }!void {
        const hit_result = state.raycast(origin, direction);
        var distance: ?u32 = null;
        if (hit_result) |hit| {
            distance = hit.distance;
            if (self.bounding_box) |*bounding_box|
                bounding_box.expand_to_contain(hit.hitpos);
        } else if (self.bounding_box) |_| {
            self.bounding_box = null;
        }
        const new_ray = LightRay.new(
            direction,
            origin,
            distance,
        );
        try self.rays.append(new_ray);

        const hit = hit_result orelse return;
        if (hit.entity.is_input(direction))
            try self.leaves.append(hit.entity);

        for (hit.entity.propagated_rays(direction)) |newdir| {
            try self.propagate_lightray(
                hit.hitpos,
                newdir,
                state,
            );
        }
    }

    pub fn regenerate(
        self: *LightTree,
        state: *State,
    ) !void {
        self.bounding_box = Rect.new(
            self.origin,
            Vec2i.new(1, 1),
        );
        try self.rays.resize(0);
        try self.leaves.resize(0);
        try self.generate(state);
    }
};
