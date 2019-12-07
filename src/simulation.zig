const std = @import("std");
const Allocator = std.mem.Allocator;

const state_ns = @import("state.zig");
const State = state_ns.State;
const EntitySet = state_ns.EntitySet;

const Vec2i = @import("vec.zig").Vec2i;

const UpdateMap = std.HashMap(
    Vec2i,
    bool,
    Vec2i.hash,
    Vec2i.equals,
);

pub const Simulation = struct {
    to_update1: EntitySet,
    to_update2: EntitySet,
    swapped: bool,
    update_map: UpdateMap,

    pub fn init(allocator: *Allocator) Simulation {
        return Simulation{
            .to_update1 = EntitySet.init(allocator),
            .to_update2 = EntitySet.init(allocator),
            .swapped = false,
            .update_map = UpdateMap.init(allocator),
        };
    }

    pub fn deinit(self: *Simulation) void {
        self.to_update1.deinit();
        self.to_update2.deinit();
    }

    pub fn queue_update(self: *Simulation, entity_pos: Vec2i) !void {
        _ = try self.to_update_primary().put(entity_pos, {});
    }

    pub fn dequeue_update(self: *Simulation, entity_pos: Vec2i) void {
        _ = self.to_update_primary().remove(entity_pos);
    }

    pub fn update(self: *Simulation, state: *State) !void {
        self.update_map.clear();
        self.to_update_secondary().clear();

        var update_iterator = self.to_update_primary().iterator();
        while (update_iterator.next()) |update_entry| {
            var entity_entry = state.entities.get(update_entry.key) orelse unreachable;
            switch (entity_entry.value) {
                .Block,
                .Laser,
                .Mirror,
                .DoubleMirror,
                .Splitter,
                => unreachable,
                .Delayer => |*delayer| {
                    const new_value = self.get_input(state, update_entry.key);
                    if (new_value != delayer.is_on) {
                        _ = try self.update_map.put(
                            entity_entry.key,
                            new_value,
                        );
                        try self.propagate_update(state, entity_entry.key);
                    }
                },
                .Switch => |*eswitch| {
                    const input_value = self.get_input(state, update_entry.key);
                    const side_input_value = self.get_side_input(state, update_entry.key);
                    const new_value = input_value and !side_input_value;
                    if (new_value != eswitch.is_on) {
                        _ = try self.update_map.put(
                            entity_entry.key,
                            new_value,
                        );
                        try self.propagate_update(state, entity_entry.key);
                    }
                },
                .Lamp => |is_on| {
                    const new_value = self.get_input(state, update_entry.key);
                    if (new_value != is_on) {
                        _ = try self.update_map.put(
                            entity_entry.key,
                            new_value,
                        );
                    }
                },
            }
        }

        self.apply_updates(state);
        self.swap_sets();
    }

    fn get_input(self: *Simulation, state: *State, entity_pos: Vec2i) bool {
        const input_set = state.input_map.get(entity_pos) orelse unreachable;
        var input_iterator = input_set.value.iterator();
        while (input_iterator.next()) |input_entry| {
            const input_entity_pos = input_entry.key;
            const input_entity = state.entities.get(input_entity_pos) orelse unreachable;
            if (input_entity.value.is_emitting())
                return true;
        }
        return false;
    }

    fn get_side_input(self: *Simulation, state: *State, entity_pos: Vec2i) bool {
        const input_set = state.side_input_map.get(entity_pos) orelse unreachable;
        var input_iterator = input_set.value.iterator();
        while (input_iterator.next()) |input_entry| {
            const input_entity_pos = input_entry.key;
            const input_entity = state.entities.get(input_entity_pos) orelse unreachable;
            if (input_entity.value.is_emitting())
                return true;
        }
        return false;
    }

    fn propagate_update(self: *Simulation, state: *State, origin: Vec2i) !void {
        var tree_entry = state.lighttrees.get(origin) orelse unreachable;
        var output_iterator = tree_entry.value.leaves.iterator();
        while (output_iterator.next()) |output_pos| {
            _ = try self.to_update_secondary().put(output_pos, {});
        }

        var side_output_iterator = tree_entry.value.side_leaves.iterator();
        while (side_output_iterator.next()) |output_pos| {
            _ = try self.to_update_secondary().put(output_pos, {});
        }
    }

    fn apply_updates(self: *Simulation, state: *State) void {
        var update_iterator = self.update_map.iterator();
        while (update_iterator.next()) |update_entry| {
            var entity_entry = state.entities.get(update_entry.key) orelse unreachable;
            switch (entity_entry.value) {
                .Block,
                .Laser,
                .Mirror,
                .DoubleMirror,
                .Splitter,
                => unreachable,
                .Delayer => |*delayer| delayer.is_on = update_entry.value,
                .Switch => |*eswitch| eswitch.is_on = update_entry.value,
                .Lamp => |*is_on| is_on.* = update_entry.value,
            }
        }
    }

    fn swap_sets(self: *Simulation) void {
        self.swapped = !self.swapped;
    }

    fn to_update_primary(self: *Simulation) *EntitySet {
        return if (self.swapped) &self.to_update2 else &self.to_update1;
    }

    fn to_update_secondary(self: *Simulation) *EntitySet {
        return if (self.swapped) &self.to_update1 else &self.to_update2;
    }
};
