const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl.zig");
const img = @import("img.zig");
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect = vec.Rect;
const utils = @import("utils.zig");

const entities = @import("entities.zig");
const Entity = entities.Entity;
const Direction = entities.Direction;
const LightRay = @import("lightray.zig").LightRay;

const EntityMap = std.HashMap(Vec2i, Entity, Vec2i.hash, Vec2i.equals);
const SegmentList = std.ArrayList(LightRay);

pub const State = struct {
    viewpos: Vec2i,

    entities: EntityMap,
    current_entity: usize,
    entity_wheel: [2]Entity,

    lightrays: SegmentList,

    pub fn new(allocator: *Allocator) State {
        var new_state = State{
            .viewpos = Vec2i.new(0, 0),

            .entities = EntityMap.init(allocator),
            .current_entity = 0,
            .entity_wheel = [_]Entity{
                Entity.Block,
                Entity{ .Laser = Direction.UP },
            },

            .lightrays = SegmentList.init(allocator),
        };
        return new_state;
    }

    pub fn destroy(self: *State) void {
        self.entities.deinit();
        self.lightrays.deinit();
    }

    pub const RayHit = struct {
        hitpos: Vec2i,
        distance: u32,
        entity: *Entity,
    };

    pub fn raycast(self: *State, origin: Vec2i, direction: Direction) ?RayHit {
        var closest: ?Vec2i = null;
        var closest_entity: ?*Entity = null;
        var entity_iterator = self.entities.iterator();
        std.debug.warn("Raycasting from ({}, {})\n", origin.x, origin.y);
        while (entity_iterator.next()) |entry| {
            var pos = origin;
            var position = entry.key;
            const entity_position = position;
            if (entity_position.equals(pos)) // We can't hit ourselves
                continue;
            switch (direction) {
                .UP => {},
                .DOWN => {
                    position.y = -position.y;
                    pos.y = -pos.y;
                },
                .LEFT => {
                    var temp = position.x;
                    position.x = -position.y;
                    position.y = temp;

                    temp = pos.x;
                    pos.x = -pos.y;
                    pos.y = temp;
                },
                .RIGHT => {
                    var temp = position.x;
                    position.x = -position.y;
                    position.y = -temp;

                    temp = pos.x;
                    pos.x = -pos.y;
                    pos.y = -temp;
                },
            }
            if (position.x != pos.x)
                continue;
            if (pos.y < position.y)
                continue;
            if (closest) |best_candidate| {
                if (position.y > best_candidate.y) {
                    closest = entity_position;
                    closest_entity = &entry.value;
                }
            } else {
                closest = entity_position;
                closest_entity = &entry.value;
            }
        }
        const hitpos = closest orelse return null;
        const distance = hitpos.distanceInt(origin);
        std.debug.warn(
            "Raycast hit ({}, {}) at distance {}\n",
            hitpos.x,
            hitpos.y,
            distance,
        );
        return RayHit{
            .hitpos = hitpos,
            .distance = distance,
            .entity = closest_entity orelse unreachable,
        };
    }

    fn propagate_lightray(
        self: *State,
        origin: Vec2i,
        direction: Direction,
    ) !void {
        const hit_result = self.raycast(origin, direction);
        var distance: ?u32 = null;
        if (hit_result) |hit| distance = hit.distance;

        const new_ray = LightRay.new(
            direction,
            origin,
            distance,
        );
        try self.lightrays.append(new_ray);

        const hit = hit_result orelse return;
        switch (hit.entity.*) {
            .Block, .Laser => return,
            // Other entities would have different behavior, like mirrors
            // would propagate the ray at a 90 degree angle, ...
            else => unreachable,
        }
    }

    pub fn create_lightrays(self: *State) !void {
        try self.lightrays.resize(0);
        var entity_iterator = self.entities.iterator();
        while (entity_iterator.next()) |entry| {
            const position = entry.key;
            const entity = entry.value;
            switch (entity) {
                .Laser => |direction| {
                    try self.propagate_lightray(position, direction);
                },
                else => {},
            }
        }
    }

    pub fn get_current_entity(self: *const State) Entity {
        return self.entity_wheel[self.current_entity];
    }

    fn get_entity_ptr(self: *State) *Entity {
        return &self.entity_wheel[self.current_entity];
    }

    pub fn place_entity(self: *State, pos: Vec2i) !bool {
        return self.add_entity(self.get_current_entity(), pos);
    }

    pub fn add_entity(self: *State, entity: Entity, pos: Vec2i) !bool {
        if (self.entities.contains(pos))
            return false;

        _ = try self.entities.put(pos, entity);
        try self.create_lightrays();
        return true;
    }

    pub fn remove_entity(self: *State, pos: Vec2i) !?EntityMap.KV {
        const entity = self.entities.remove(pos);
        if (entity) |_|
            try self.create_lightrays();
        return entity;
    }

    pub fn on_wheel_down(self: *State, amount: u32) void {
        self.current_entity = @mod(self.current_entity + amount, @intCast(u32, self.entity_wheel.len));
    }

    pub fn on_wheel_up(self: *State, amount: u32) void {
        self.current_entity = @mod(self.current_entity -% amount, @intCast(u32, self.entity_wheel.len));
    }

    pub fn on_key_up(self: *State, keysym: sdl.Keysym) void {
        switch (keysym.sym) {
            sdl.K_0,
            sdl.K_1,
            sdl.K_2,
            sdl.K_3,
            sdl.K_4,
            sdl.K_5,
            sdl.K_6,
            sdl.K_7,
            sdl.K_8,
            sdl.K_9,
            => {
                const index = @intCast(usize, utils.slot_value(keysym.sym));
                if (index < self.entity_wheel.len) {
                    self.current_entity = index;
                }
            },
            sdl.K_q => {
                self.get_entity_ptr().cclockwise();
            },
            sdl.K_e => {
                self.get_entity_ptr().clockwise();
            },
            else => {},
        }
    }
};
