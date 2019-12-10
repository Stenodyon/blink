const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

//const lazy = @import("lazy");
const sdl = @import("sdl.zig");
const img = @import("img.zig");
const display = @import("display.zig");

const InputState = @import("input.zig").InputState;
const entities = @import("entities.zig");
const Entity = entities.Entity;
const Direction = entities.Direction;
const Delayer = entities.Delayer;
const Switch = entities.Switch;

usingnamespace @import("vec.zig");
usingnamespace @import("lightray.zig");
usingnamespace @import("simulation.zig");

const EntityMap = std.HashMap(
    Vec2i,
    Entity,
    Vec2i.hash,
    Vec2i.equals,
);

const TreeMap = std.HashMap(
    Vec2i,
    LightTree,
    Vec2i.hash,
    Vec2i.equals,
);

pub const EntitySet = std.HashMap(
    Vec2i,
    void,
    Vec2i.hash,
    Vec2i.equals,
);

const IOMap = std.HashMap(
    Vec2i,
    EntitySet,
    Vec2i.hash,
    Vec2i.equals,
);

pub var game_state: State = undefined;

pub const State = struct {
    viewpos: Vec2f,
    viewport: Vec2f,
    input_state: InputState,

    entities: EntityMap,
    current_entity: usize,
    entity_wheel: [8]Entity,
    selection_rect: ?Rectf,
    selected_entities: EntitySet,
    copy_buffer: EntityMap,

    lighttrees: TreeMap,
    input_map: IOMap,
    side_input_map: IOMap,
    sim: Simulation,

    const zoom_factors = [_]f32{
        0.5, 0.75, 1, 1.5, 2, 3, 5, 10,
    };
    zoom_index: usize,

    pub fn new(allocator: *Allocator) State {
        return State{
            .viewpos = Vec2f.new(0, 0),
            .viewport = Vec2i.new(
                display.window_width,
                display.window_height,
            ).divi(display.GRID_SIZE).to_float(f32),
            .input_state = .Normal,

            .entities = EntityMap.init(allocator),
            .current_entity = 0,
            .entity_wheel = [_]Entity{
                Entity.Block,
                Entity{ .Laser = .UP },
                Entity{ .Mirror = .UP },
                Entity{ .DoubleMirror = .UP },
                Entity{ .Splitter = .UP },
                Entity{
                    .Delayer = Delayer{
                        .direction = .UP,
                        .is_on = false,
                    },
                },
                Entity{
                    .Switch = Switch{
                        .direction = .UP,
                        .is_on = false,
                        .is_flipped = false,
                    },
                },
                Entity{ .Lamp = false },
            },
            .selection_rect = null,
            .selected_entities = EntitySet.init(allocator),
            .copy_buffer = EntityMap.init(allocator),

            .lighttrees = TreeMap.init(allocator),
            .input_map = IOMap.init(allocator),
            .side_input_map = IOMap.init(allocator),
            .sim = Simulation.init(allocator),

            .zoom_index = 2,
        };
    }

    pub fn destroy(self: *State) void {
        self.entities.deinit();
        self.lighttrees.deinit();
        self.selected_entities.deinit();

        var input_map_iter = self.input_map.iterator();
        while (input_map_iter.next()) |input_set| input_set.value.deinit();
        self.input_map.deinit();

        var side_input_map_iter = self.side_input_map.iterator();
        while (side_input_map_iter.next()) |input_set| input_set.value.deinit();
        self.side_input_map.deinit();

        self.sim.deinit();
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
        _ = try self.input_map.put(pos, EntitySet.init(self.input_map.allocator));
        _ = try self.side_input_map.put(pos, EntitySet.init(self.side_input_map.allocator));
        switch (entity) {
            .Block,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            => {},

            .Laser => |direction| try self.add_tree(pos, direction),
            .Delayer => |*delayer| {
                try self.add_tree(pos, delayer.direction);
                try self.sim.queue_update(pos);
            },
            .Switch => |*eswitch| {
                try self.add_tree(pos, eswitch.direction);
                try self.sim.queue_update(pos);
            },
            .Lamp => {
                try self.sim.queue_update(pos);
            },
        }
        try self.update_trees(pos);
        return true;
    }

    pub fn get_entity(self: *const State, pos: Vec2i) ?*const Entity {
        const entry = self.entities.get(pos) orelse return null;
        return &entry.value;
    }

    pub fn remove_entity(self: *State, pos: Vec2i) !?EntityMap.KV {
        const entry = self.entities.remove(pos) orelse return null;
        const input_set = self.input_map.remove(pos) orelse unreachable;
        input_set.value.deinit();
        const side_input_set = self.side_input_map.remove(pos) orelse unreachable;
        side_input_set.value.deinit();
        _ = self.selected_entities.remove(pos);

        switch (entry.value) {
            .Block,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            .Lamp,
            => {},
            .Laser => |direction| try self.remove_tree(pos, direction),
            .Delayer => |*delayer| try self.remove_tree(pos, delayer.direction),
            .Switch => |*eswitch| try self.remove_tree(pos, eswitch.direction),
        }
        try self.update_trees(pos);
        self.sim.dequeue_update(pos);

        return entry;
    }

    pub fn add_tree(self: *State, pos: Vec2i, direction: Direction) !void {
        var tree = LightTree.new(
            pos,
            direction,
            self.lighttrees.allocator,
        );
        try tree.generate(self);
        _ = try self.lighttrees.put(pos, tree);
        var output_iterator = tree.leaves.iterator();
        while (output_iterator.next()) |output_pos| {
            try self.sim.queue_update(output_pos);
            const input_entry = self.input_map.get(output_pos) orelse unreachable;
            _ = try input_entry.value.put(pos, {});
        }

        var side_output_iterator = tree.side_leaves.iterator();
        while (side_output_iterator.next()) |output_pos| {
            try self.sim.queue_update(output_pos);
            const input_entry = self.side_input_map.get(output_pos) orelse unreachable;
            _ = try input_entry.value.put(pos, {});
        }
    }

    pub fn remove_tree(self: *State, pos: Vec2i, direction: Direction) !void {
        var tree_entry = self.lighttrees.remove(pos) orelse unreachable;

        var output_iterator = tree_entry.value.leaves.iterator();
        while (output_iterator.next()) |output_pos| {
            try self.sim.queue_update(output_pos);
            const input_entry = self.input_map.get(output_pos) orelse {
                std.debug.assert(output_pos.equals(pos));
                continue;
            };
            _ = input_entry.value.remove(pos);
        }

        var side_output_iterator = tree_entry.value.side_leaves.iterator();
        while (side_output_iterator.next()) |output_pos| {
            try self.sim.queue_update(output_pos);
            const input_entry = self.side_input_map.get(output_pos) orelse {
                std.debug.assert(output_pos.equals(pos));
                continue;
            };
            _ = input_entry.value.remove(pos);
        }

        tree_entry.value.destroy();
    }

    fn update_tree(self: *State, pos: Vec2i, tree: *LightTree) !void {
        for (tree.leaves.toSlice()) |leaf| {
            // If the tree updates because an entity was removed,
            // this entity could be among the outputs
            var input_set = self.input_map.get(leaf) orelse continue;
            _ = input_set.value.remove(pos);
            try self.sim.queue_update(leaf);
        }
        for (tree.side_leaves.toSlice()) |leaf| {
            var input_set = self.side_input_map.get(leaf) orelse continue;
            _ = input_set.value.remove(pos);
            try self.sim.queue_update(leaf);
        }

        try tree.regenerate(self);

        for (tree.leaves.toSlice()) |leaf| {
            try self.sim.queue_update(leaf);
            var input_set = self.input_map.get(leaf) orelse unreachable;
            _ = try input_set.value.put(pos, {});
        }
        for (tree.side_leaves.toSlice()) |leaf| {
            try self.sim.queue_update(leaf);
            var input_set = self.side_input_map.get(leaf) orelse unreachable;
            _ = try input_set.value.put(pos, {});
        }
    }

    pub fn update_trees(self: *State, pos: ?Vec2i) !void { // null means update all trees
        var tree_iterator = self.lighttrees.iterator();
        if (pos) |position| {
            while (tree_iterator.next()) |entry| {
                var tree = &entry.value;
                if (tree.in_bounds(position))
                    try self.update_tree(entry.key, tree);
            }
        } else {
            while (tree_iterator.next()) |entry| {
                var tree = &entry.value;
                try self.update_tree(entry.key, tree);
            }
        }
    }

    pub fn get_zoom_factor(self: *const State) f32 {
        return State.zoom_factors[self.zoom_index];
    }

    fn set_zoom_factor(self: *State, index: usize) void {
        const factor = State.zoom_factors[index];
        const default_viewport = Vec2i.new(
            display.window_width,
            display.window_height,
        ).divi(display.GRID_SIZE).to_float(f32);
        const new_viewport = default_viewport.mulf(factor);
        self.viewport = new_viewport;
    }

    fn zoom_in(self: *State) void {
        if (self.zoom_index > 0) {
            self.zoom_index -= 1;
            self.set_zoom_factor(self.zoom_index);
        }
    }

    fn zoom_out(self: *State) void {
        if (self.zoom_index + 1 < State.zoom_factors.len) {
            self.zoom_index += 1;
            self.set_zoom_factor(self.zoom_index);
        }
    }

    fn entity_wheel_down(self: *State, amount: u32) void {
        const slot = @mod(self.current_entity + amount, @intCast(u32, self.entity_wheel.len));
        self.set_selected_slot(slot);
    }

    fn entity_wheel_up(self: *State, amount: u32) void {
        const slot = @mod((self.current_entity + self.entity_wheel.len) -% amount, @intCast(u32, self.entity_wheel.len));
        self.set_selected_slot(slot);
    }

    pub fn on_wheel_down(self: *State, amount: u32) void {
        if (sdl.GetModState() & sdl.KMOD_LCTRL != 0) {
            self.zoom_out();
        } else {
            self.entity_wheel_down(amount);
        }
    }

    pub fn on_wheel_up(self: *State, amount: u32) void {
        if (sdl.GetModState() & sdl.KMOD_LCTRL != 0) {
            self.zoom_in();
        } else {
            self.entity_wheel_up(amount);
        }
    }

    pub fn find_entity_slot(self: *const State, entity_type: @TagType(Entity)) ?usize {
        for (self.entity_wheel) |wheel_entity, i| {
            if (@TagType(Entity)(wheel_entity) == entity_type) {
                return i;
            }
        }
        return null;
    }

    pub fn set_selected_slot(self: *State, slot: usize) void {
        self.current_entity = slot;
    }

    pub fn set_selected_entity(self: *State, entity: Entity) void {
        if (self.find_entity_slot(@TagType(Entity)(entity))) |slot| {
            self.set_selected_slot(slot);
            self.get_entity_ptr().set_properties_from(&entity);
            self.set_ghost_direction(entity.get_direction());
        }
    }

    pub fn get_ghost_direction(self: *State) Direction {
        return self.get_entity_ptr().get_direction();
    }

    pub fn set_ghost_direction(self: *State, direction: Direction) void {
        for (self.entity_wheel) |*entity| {
            entity.set_direction(direction);
        }
    }

    pub fn capture_selection_rect(self: *State) !void {
        const sel_rect = self.selection_rect.?.canonic();
        const min_pos = sel_rect.pos.floor();
        const max_pos = sel_rect.pos.add(sel_rect.size).ceil();

        var y: i32 = min_pos.y;
        while (y < max_pos.y) : (y += 1) {
            var x: i32 = min_pos.x;
            while (x < max_pos.x) : (x += 1) {
                const pos = Vec2i.new(x, y);
                if (!self.entities.contains(pos))
                    continue;
                _ = try self.selected_entities.put(pos, {});
            }
        }
        self.selection_rect = null;
    }

    pub fn delete_selection(self: *State) !void {
        var to_remove = ArrayList(Vec2i).init(std.heap.c_allocator);
        defer to_remove.deinit();

        var entity_iterator = self.selected_entities.iterator();
        while (entity_iterator.next()) |entry| {
            try to_remove.append(entry.key);
        }

        for (to_remove.toSlice()) |pos| {
            _ = try self.remove_entity(pos);
        }
        self.selected_entities.clear();
    }

    pub fn copy_selection(self: *State, center: Vec2i) !void {
        var entity_iterator = self.selected_entities.iterator();
        while (entity_iterator.next()) |entry| {
            const entity = self.entities.get(entry.key).?.value;
            const new_pos = entry.key.sub(center);
            _ = try self.copy_buffer.put(new_pos, entity);
        }
    }

    pub fn check_copy_collision(self: *State, pos: Vec2i) bool {
        var entity_iterator = self.copy_buffer.iterator();
        while (entity_iterator.next()) |entry| {
            const entity_pos = entry.key.add(pos);
            if (self.entities.contains(entity_pos))
                return false;
        }
        return true;
    }

    pub fn place_copy(self: *State, pos: Vec2i) !bool {
        if (!self.check_copy_collision(pos))
            return false;
        var entity_iterator = self.copy_buffer.iterator();
        while (entity_iterator.next()) |entry| {
            _ = try self.add_entity(entry.value, entry.key.add(pos));
        }
        return true;
    }

    pub fn place_selected_copy(self: *State, pos: Vec2i) !bool {
        if (!self.check_copy_collision(pos))
            return false;
        var entity_iterator = self.copy_buffer.iterator();
        while (entity_iterator.next()) |entry| {
            const new_pos = entry.key.add(pos);
            _ = try self.add_entity(entry.value, new_pos);
            _ = try self.selected_entities.put(new_pos, {});
        }
        return true;
    }

    pub fn update(self: *State) !void {
        try self.sim.update(self);
    }
};
