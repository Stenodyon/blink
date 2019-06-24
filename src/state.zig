const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const TailQueue = std.TailQueue;

const sdl = @import("sdl.zig");
const img = @import("img.zig");
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect = vec.Rect;
const utils = @import("utils.zig");

const entities = @import("entities.zig");
const Entity = entities.Entity;
const Direction = entities.Direction;
const Delayer = entities.Delayer;

usingnamespace @import("lightray.zig");

const EntityMap = std.HashMap(
    Vec2i,
    Entity,
    Vec2i.hash,
    Vec2i.equals,
);

const TreeMap = std.HashMap(
    RayOrigin,
    LightTree,
    RayOrigin.hash,
    RayOrigin.equals,
);

const IOSet = std.HashMap(
    Vec2i,
    void,
    Vec2i.hash,
    Vec2i.equals,
);

const IOMap = std.HashMap(
    Vec2i,
    IOSet,
    Vec2i.hash,
    Vec2i.equals,
);

const UpdateMap = std.HashMap(
    Vec2i,
    bool,
    Vec2i.hash,
    Vec2i.equals,
);

pub const State = struct {
    viewpos: Vec2i,

    entities: EntityMap,
    current_entity: usize,
    entity_ghost_dir: Direction,
    entity_wheel: [5]Entity,

    lighttrees: TreeMap,
    input_map: IOMap,
    update_map: UpdateMap,

    pub fn new(allocator: *Allocator) State {
        var new_state = State{
            .viewpos = Vec2i.new(0, 0),

            .entities = EntityMap.init(allocator),
            .current_entity = 0,
            .entity_ghost_dir = .UP,
            .entity_wheel = [_]Entity{
                Entity.Block,
                Entity{ .Laser = .UP },
                Entity{ .Mirror = .UP },
                Entity{ .Splitter = .UP },
                Entity{
                    .Delayer = Delayer{
                        .direction = .UP,
                        .is_on = false,
                    },
                },
            },

            .lighttrees = TreeMap.init(allocator),
            .input_map = IOMap.init(allocator),
            .update_map = UpdateMap.init(allocator),
        };
        return new_state;
    }

    pub fn destroy(self: *State) void {
        self.entities.deinit();
        self.lighttrees.deinit();

        var input_map_iter = self.input_map.iterator();
        while (input_map_iter.next()) |input_set| input_set.value.deinit();
        self.input_map.deinit();
        self.update_map.deinit();
    }

    pub const RayHit = struct {
        hitpos: Vec2i,
        distance: u32,
        entity: *Entity,
    };

    fn to_canonic(pos: Vec2i, direction: Direction) Vec2i {
        switch (direction) {
            .UP => {
                return Vec2i.new(pos.x, pos.y);
            },
            .DOWN => {
                return Vec2i.new(-pos.x, -pos.y);
            },
            .LEFT => {
                return Vec2i.new(-pos.y, pos.x);
            },
            .RIGHT => {
                return Vec2i.new(pos.y, -pos.x);
            },
        }
    }

    pub fn raycast(
        self: *const State,
        origin: Vec2i,
        direction: Direction,
    ) ?RayHit {
        var hitpos_canonic: ?Vec2i = null;
        var closest: ?Vec2i = null;
        var closest_entity: ?*Entity = null;
        std.debug.warn("Raycasting from ({}, {})\n", origin.x, origin.y);
        const pos = to_canonic(origin, direction);

        var entity_iterator = self.entities.iterator();
        while (entity_iterator.next()) |entry| {
            const entity_position = entry.key;
            const position = to_canonic(entity_position, direction);

            if (entity_position.equals(origin)) // We can't hit ourselves
                continue;
            if (position.x != pos.x)
                continue;
            if (pos.y < position.y)
                continue;
            //std.debug.warn("Hit ({}
            if (hitpos_canonic) |best_candidate| {
                if (position.y > best_candidate.y) {
                    hitpos_canonic = position;
                    closest = entity_position;
                    closest_entity = &entry.value;
                }
            } else {
                hitpos_canonic = position;
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
        _ = try self.input_map.put(pos, IOSet.init(self.input_map.allocator));
        switch (entity) {
            .Block,
            .Mirror,
            .Splitter,
            => {},

            .Laser => |direction| try self.add_tree(pos, direction),
            .Delayer => |*delayer| try self.add_tree(pos, delayer.direction),
        }
        try self.update_trees(pos);
        return true;
    }

    pub fn remove_entity(self: *State, pos: Vec2i) !?EntityMap.KV {
        const entry = self.entities.remove(pos) orelse return null;
        const input_set = self.input_map.remove(pos) orelse unreachable;
        input_set.value.deinit();

        switch (entry.value) {
            .Block,
            .Mirror,
            .Splitter,
            => {},
            .Laser => |direction| self.remove_tree(pos, direction),
            .Delayer => |*delayer| self.remove_tree(pos, delayer.direction),
        }
        try self.update_trees(pos);

        return entry;
    }

    pub fn add_tree(self: *State, pos: Vec2i, direction: Direction) !void {
        var tree = LightTree.new(
            pos,
            direction,
            self.lighttrees.allocator,
        );
        try tree.generate(self);
        _ = try self.lighttrees.put(
            RayOrigin{
                .position = pos,
                .direction = direction,
            },
            tree,
        );
    }

    pub fn remove_tree(self: *State, pos: Vec2i, direction: Direction) void {
        _ = self.lighttrees.remove(RayOrigin{
            .position = pos,
            .direction = direction,
        }) orelse unreachable;
    }

    pub fn get_tree(
        self: *State,
        pos: Vec2i,
        direction: Direction,
    ) ?*LightTree {
        return self.lighttrees.get(RayOrigin{
            .position = pos,
            .direction = direction,
        });
    }

    pub fn update_trees(self: *State, pos: ?Vec2i) !void { // null means update all trees
        var tree_iterator = self.lighttrees.iterator();
        if (pos) |position| {
            while (tree_iterator.next()) |entry| {
                var tree = &entry.value;
                if (tree.in_bounds(position)) {
                    for (tree.leaves.toSlice()) |leaf| {
                        var input_set = self.input_map.get(leaf) orelse unreachable;
                        _ = input_set.value.remove(entry.key.position);
                    }

                    try tree.regenerate(self);

                    for (tree.leaves.toSlice()) |leaf| {
                        var input_set = self.input_map.get(leaf) orelse unreachable;
                        _ = try input_set.value.put(entry.key.position, {});
                    }
                }
            }
        } else {
            while (tree_iterator.next()) |entry| {
                var tree = &entry.value;
                for (tree.leaves.toSlice()) |leaf| {
                    var input_set = self.input_map.get(leaf) orelse unreachable;
                    _ = input_set.value.remove(entry.key.position);
                }

                try tree.regenerate(self);

                for (tree.leaves.toSlice()) |leaf| {
                    var input_set = self.input_map.get(leaf) orelse unreachable;
                    _ = try input_set.value.put(entry.key.position, {});
                }
            }
        }
    }

    pub fn on_wheel_down(self: *State, amount: u32) void {
        const slot = @mod(self.current_entity + amount, @intCast(u32, self.entity_wheel.len));
        self.set_selected_slot(slot);
    }

    pub fn on_wheel_up(self: *State, amount: u32) void {
        const slot = @mod((self.current_entity + self.entity_wheel.len) -% amount, @intCast(u32, self.entity_wheel.len));
        self.set_selected_slot(slot);
    }

    pub fn set_selected_slot(self: *State, slot: usize) void {
        self.current_entity = slot;
        self.get_entity_ptr().set_direction(self.entity_ghost_dir);
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
                    self.set_selected_slot(index);
                }
            },
            sdl.K_q => {
                self.entity_ghost_dir = self.entity_ghost_dir.cclockwise();
                self.get_entity_ptr().set_direction(self.entity_ghost_dir);
            },
            sdl.K_e => {
                self.entity_ghost_dir = self.entity_ghost_dir.clockwise();
                self.get_entity_ptr().set_direction(self.entity_ghost_dir);
            },
            else => {},
        }
    }
};
