const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const TailQueue = std.TailQueue;
const BufferedAtomicFile = std.io.BufferedAtomicFile;
const SliceInStream = std.io.SliceInStream;

const lazy = @import("lazy/index.zig");
const sdl = @import("sdl.zig");
const img = @import("img.zig");
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect = vec.Rect;
const display = @import("display.zig");

const entities = @import("entities.zig");
const Entity = entities.Entity;
const Direction = entities.Direction;
const Delayer = entities.Delayer;
const Switch = entities.Switch;

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

const SAVEFILE_HEADER = "BLINKSV\x00";

pub const State = struct {
    viewpos: Vec2i,
    viewport: Vec2i,

    entities: EntityMap,
    current_entity: usize,
    entity_ghost_dir: Direction,
    entity_wheel: [6]Entity,

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
            .viewpos = Vec2i.new(0, 0),
            .viewport = Vec2i.new(display.window_width, display.window_height),

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
                Entity{
                    .Switch = Switch{
                        .direction = .UP,
                        .is_on = false,
                        .is_flipped = false,
                    },
                },
            },

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
        }
        try self.update_trees(pos);
        return true;
    }

    pub fn remove_entity(self: *State, pos: Vec2i) !?EntityMap.KV {
        const entry = self.entities.remove(pos) orelse return null;
        const input_set = self.input_map.remove(pos) orelse unreachable;
        input_set.value.deinit();
        const side_input_set = self.side_input_map.remove(pos) orelse unreachable;
        side_input_set.value.deinit();

        switch (entry.value) {
            .Block,
            .Mirror,
            .Splitter,
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
        );
        const new_viewport = default_viewport.mulf(factor);
        const difference = new_viewport.sub(self.viewport).divi(2);
        self.viewport = new_viewport;
        _ = self.viewpos.subi(difference);
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
            self.entity_wheel_down(amount);
        } else {
            self.zoom_out();
        }
    }

    pub fn on_wheel_up(self: *State, amount: u32) void {
        if (sdl.GetModState() & sdl.KMOD_LCTRL != 0) {
            self.entity_wheel_up(amount);
        } else {
            self.zoom_in();
        }
    }

    pub fn set_selected_slot(self: *State, slot: usize) void {
        self.current_entity = slot;
        self.get_entity_ptr().set_direction(self.entity_ghost_dir);
    }

    pub fn update(self: *State) !void {
        try self.sim.update(self);
    }

    pub fn save(self: *State, filename: []const u8) !void {
        var file = try BufferedAtomicFile.create(self.entities.allocator, filename);
        var outstream = file.stream();
        defer file.destroy();
        try self.save_to_stream(outstream);
        try file.finish();
    }

    fn save_to_stream(
        self: *State,
        outstream: var,
    ) !void {
        // header
        try outstream.write(SAVEFILE_HEADER[0..]);

        // Entity count
        try outstream.writeIntLittle(usize, self.entities.count());

        // entity x (4B) y (4B) type (1B) [direction (1B) [is_on (1B)]]
        var entity_iterator = self.entities.iterator();
        while (entity_iterator.next()) |entry| {
            const pos = entry.key;
            try outstream.writeIntLittle(i32, pos.x);
            try outstream.writeIntLittle(i32, pos.y);
            try outstream.writeByte(@enumToInt(entry.value));

            switch (entry.value) {
                .Block => {},
                .Mirror, .Splitter, .Laser => |direction| {
                    try outstream.writeByte(@enumToInt(direction));
                },
                .Delayer => |*delayer| {
                    try outstream.writeByte(@enumToInt(delayer.direction));
                    try outstream.writeByte(@boolToInt(delayer.is_on));
                },
                .Switch => |*eswitch| {
                    try outstream.writeByte(@enumToInt(eswitch.direction));
                    try outstream.writeByte(@boolToInt(eswitch.is_on));
                    try outstream.writeByte(@boolToInt(eswitch.is_flipped));
                },
            }
        }
    }

    pub fn from_file(allocator: *Allocator, filename: []const u8) !?State {
        var file_contents = std.io.readFileAlloc(allocator, filename) catch |err| {
            if (err == error.FileNotFound) {
                std.debug.warn("Could not find savefile '{}'\n", filename);
                std.os.exit(1);
            }
            return err;
        };
        defer allocator.free(file_contents);
        var instream = SliceInStream.init(file_contents);
        return try State.from_stream(allocator, &instream.stream);
    }

    fn from_stream(allocator: *Allocator, instream: var) !?State {
        var state = State.new(allocator);

        // Header
        var buffer: [SAVEFILE_HEADER.len]u8 = undefined;
        if ((try instream.read(buffer[0..])) != SAVEFILE_HEADER.len) {
            std.debug.warn("Did not read 8 bytes for the header\n");
            return null;
        }
        if (std.mem.compare(u8, buffer[0..], SAVEFILE_HEADER[0..]) != .Equal) {
            std.debug.warn(
                "Header did not match: {} vs {}\n",
                buffer,
                SAVEFILE_HEADER,
            );
            return null;
        }

        // Entities
        const entity_count = try instream.readIntLittle(usize);

        var entity_it = lazy.range(usize(0), entity_count, 1);
        while (entity_it.next()) |i| {
            const pos_x = try instream.readIntLittle(i32);
            const pos_y = try instream.readIntLittle(i32);
            std.debug.warn("Loading entity at ({}, {})\n", pos_x, pos_y);
            const pos = Vec2i.new(pos_x, pos_y);

            const entity_type = @intToEnum(@TagType(Entity), @intCast(u3, try instream.readByte())); // ughh
            const entity = switch (entity_type) {
                .Block => blk: {
                    // Had to do this nonsense, otherwise the type of the switch
                    // would be inferred to @TagType(Entity) for some reason
                    const ret: Entity = Entity.Block;
                    break :blk ret;
                },
                .Mirror => blk: {
                    const direction = @intToEnum(Direction, @intCast(u2, try instream.readByte()));
                    break :blk Entity{ .Mirror = direction };
                },
                .Splitter => blk: {
                    const direction = @intToEnum(Direction, @intCast(u2, try instream.readByte()));
                    break :blk Entity{ .Splitter = direction };
                },
                .Laser => blk: {
                    const direction = @intToEnum(Direction, @intCast(u2, try instream.readByte()));
                    break :blk Entity{ .Laser = direction };
                },
                .Delayer => blk: {
                    const direction = @intToEnum(Direction, @intCast(u2, try instream.readByte()));
                    const is_on = (try instream.readByte()) > 0;
                    break :blk Entity{
                        .Delayer = Delayer{
                            .direction = direction,
                            .is_on = is_on,
                        },
                    };
                },
                .Switch => blk: {
                    const direction = @intToEnum(Direction, @intCast(u2, try instream.readByte()));
                    const is_on = (try instream.readByte()) > 0;
                    const is_flipped = (try instream.readByte()) > 0;
                    break :blk Entity{
                        .Switch = Switch{
                            .direction = direction,
                            .is_on = is_on,
                            .is_flipped = is_flipped,
                        },
                    };
                },
            };
            _ = try state.add_entity(entity, pos);
        }

        return state;
    }
};

test "save/load" {
    // Init
    const Buffer = std.Buffer;
    const BufferOutStream = std.io.BufferOutStream;

    var buffer = try Buffer.initSize(std.debug.global_allocator, 0);
    var outstream = BufferOutStream.init(&buffer);
    var state = State.new(std.debug.global_allocator);

    _ = try state.add_entity(Entity.Block, Vec2i.new(1, 1));
    _ = try state.add_entity(Entity{ .Laser = .UP }, Vec2i.new(-10, 2));
    _ = try state.add_entity(Entity{ .Mirror = .RIGHT }, Vec2i.new(14, 3));
    _ = try state.add_entity(Entity{ .Splitter = .DOWN }, Vec2i.new(1, 12));
    _ = try state.add_entity(Entity{
        .Delayer = Delayer{
            .direction = .LEFT,
            .is_on = false,
        },
    }, Vec2i.new(-5, 4));
    _ = try state.add_entity(Entity{
        .Switch = Switch{
            .direction = .UP,
            .is_on = true,
        },
    }, Vec2i.new(42, 42));

    // Saving
    try state.save_to_stream(&outstream.stream);
    var save_file = buffer.toOwnedSlice();
    std.debug.warn("Save file: {}\n", save_file);
    defer std.debug.global_allocator.free(save_file);

    // Loading
    var instream = SliceInStream.init(save_file);
    const loaded_state = (try State.from_stream(
        std.debug.global_allocator,
        &instream.stream,
    )) orelse {
        std.debug.panic("State.from_stream did not return a state\n");
    };

    // Checking equality
    if (loaded_state.entities.count() != state.entities.count()) {
        std.debug.panic(
            "loaded_state has the wrong number of entities ({} vs {})\n",
            loaded_state.entities.count(),
            state.entities.count(),
        );
    }

    var entity_iterator = state.entities.iterator();
    while (entity_iterator.next()) |entry| {
        var loaded_entry = loaded_state.entities.get(entry.key) orelse {
            std.debug.panic(
                "Loaded state doesn't have an entity at ({}, {})\n",
                entry.key.x,
                entry.key.y,
            );
        };
        if (@enumToInt(entry.value) != @enumToInt(loaded_entry.value)) {
            std.debug.panic(
                "Expected {} but loaded {}\n",
                @tagName(entry.value),
                @tagName(loaded_entry.value),
            );
        }
        switch (entry.value) {
            .Block => {},
            .Mirror, .Splitter, .Laser => |direction| {
                switch (loaded_entry.value) {
                    .Mirror, .Splitter, .Laser => |loaded_direction| {
                        if (direction != loaded_direction) {
                            std.debug.panic(
                                "Expected direction {} but loaded {}\n",
                                @enumToInt(direction),
                                @enumToInt(loaded_direction),
                            );
                        }
                    },
                    else => unreachable,
                }
            },
            .Delayer => |*delayer| {
                switch (loaded_entry.value) {
                    .Delayer => |*loaded_delayer| {
                        if (delayer.direction != loaded_delayer.direction) {
                            std.debug.panic(
                                "Expected direction {} but loaded {}\n",
                                @enumToInt(delayer.direction),
                                @enumToInt(loaded_delayer.direction),
                            );
                        }
                        if (delayer.is_on != loaded_delayer.is_on) {
                            std.debug.panic(
                                "Expected is_on {} but loaded {}\n",
                                delayer.is_on,
                                loaded_delayer.is_on,
                            );
                        }
                    },
                    else => unreachable,
                }
            },
            .Switch => |*eswitch| {
                switch (loaded_entry.value) {
                    .Switch => |*loaded_switch| {
                        if (eswitch.direction != loaded_switch.direction) {
                            std.debug.panic(
                                "Expected direction {} but loaded {}\n",
                                @enumToInt(eswitch.direction),
                                @enumToInt(loaded_switch.direction),
                            );
                        }
                        if (eswitch.is_on != loaded_switch.is_on) {
                            std.debug.panic(
                                "Expected is_on {} but loaded {}\n",
                                eswitch.is_on,
                                loaded_switch.is_on,
                            );
                        }
                        if (eswitch.is_flipped != loaded_switch.is_flipped) {
                            std.debug.panic(
                                "Expected is_flipped {} but loaded {}\n",
                                eswitch.is_flipped,
                                loaded_switch.is_flipped,
                            );
                        }
                    },
                    else => unreachable,
                }
            },
        }
    }
}
