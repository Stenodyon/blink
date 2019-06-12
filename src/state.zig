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
const LightRay = entities.LightRay;
const Direction = entities.Direction;

const EntityMap = std.HashMap(Vec2i, Entity, Vec2i.hash, Vec2i.equals);
const SegmentList = std.ArrayList(LightRay);

pub const State = struct {
    viewpos: Vec2i,

    entities: EntityMap,
    current_entity: u32,
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
    };

    pub fn raycast(self: *State, pos: Vec2i, direction: Direction) ?RayHit {
        var closest: ?Vec2i = null;
        var entity_iterator = self.entities.iterator();
        std.debug.warn("Raycasting from ({}, {})\n", pos.x, pos.y);
        while (entity_iterator.next()) |entry| {
            var position = entry.key;
            const entity_position = position;
            if (entity_position.equals(pos)) // We can't hit ourselves
                continue;
            switch (direction) {
                .UP => {},
                .DOWN => {
                    position.y = -position.y;
                },
                .LEFT => {
                    const temp = position.x;
                    position.x = position.y;
                    position.y = -temp;
                },
                .RIGHT => {
                    const temp = position.x;
                    position.x = -position.y;
                    position.y = -temp;
                },
            }
            if (position.x != pos.x)
                continue;
            if (pos.y < position.y)
                continue;
            if (closest) |best_candidate| {
                if (position.y > best_candidate.y)
                    closest = entity_position;
            } else {
                closest = entity_position;
            }
        }
        const hitpos = closest orelse return null;
        const distance = hitpos.distanceInt(pos);
        //        std.debug.warn(
        //            "Raycast hit ({}, {}) at distance {}\n",
        //            hitpos.x,
        //            hitpos.y,
        //            distance,
        //        );
        return RayHit{
            .hitpos = hitpos,
            .distance = distance,
        };
    }

    pub fn create_lightrays(self: *State) !void {
        try self.lightrays.resize(0);
        var entity_iterator = self.entities.iterator();
        while (entity_iterator.next()) |entry| {
            const position = entry.key;
            const entity = entry.value;
            switch (entity) {
                .Laser => |direction| {
                    const hit_result = self.raycast(position, direction);
                    if (hit_result) |hit| {
                        const new_ray = LightRay.new(
                            direction,
                            position,
                            hit.distance,
                        );
                        try self.lightrays.append(new_ray);
                    }
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
            sdl.K_q => {
                self.get_entity_ptr().cclockwise();
            },
            else => {},
        }
    }
};
