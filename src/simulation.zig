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

    pub fn update(self: *Simulation, state: *State) void {
        self.update_map.clear();
        self.to_update_secondary().clear();

        self.apply_updates(state);
        self.swap_sets();
    }

    fn apply_updates(self: *Simulation, state: *State) void {
        var update_iterator = self.update_map.iterator();
        while (update_iterator.next()) |update_entry| {
            var entity_entry = state.entities.get(update_entry.key) orelse unreachable;
            switch (entity_entry.value) {
                .Delayer => |*delayer| delayer.is_on = update_entry.value,
                else => unreachable,
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
