const std = @import("std");
const Allocator = std.mem.Allocator;
const SliceInStream = std.io.SliceInStream;
const BufferedAtomicFile = std.io.BufferedAtomicFile;

const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const entities = @import("entities.zig");
const Entity = entities.Entity;
const Direction = entities.Direction;
const Delayer = entities.Delayer;
const Switch = entities.Switch;

usingnamespace @import("state.zig");

const SAVEFILE_HEADER = "BLINKSV\x00";

// SAVE =======================================================================

/// Saves a state `state` to a file at `filename`
pub fn save_state(state: *State, filename: []const u8) !void {
    var file = try BufferedAtomicFile.create(state.entities.allocator, filename);
    var outstream = file.stream();
    defer file.destroy();
    try save_state_to_stream(state, outstream);
    try file.finish();
}

fn save_state_to_stream(
    state: *State,
    outstream: var,
) !void {
    // header
    try outstream.write(SAVEFILE_HEADER[0..]);

    // Entity count
    try outstream.writeIntLittle(usize, state.entities.count());

    // entity x (4B) y (4B) type (1B) [direction (1B) [is_on (1B)]]
    var entity_iterator = state.entities.iterator();
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
            .Lamp => |is_on| {
                try outstream.writeByte(@boolToInt(is_on));
            },
        }
    }
}

// LOAD =======================================================================

/// Loads a state from file `filename`
pub fn load_state(allocator: *Allocator, filename: []const u8) !?State {
    var file_contents = std.io.readFileAlloc(allocator, filename) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.warn("Could not find savefile '{}'\n", filename);
            std.os.exit(1);
        }
        return err;
    };
    defer allocator.free(file_contents);
    var instream = SliceInStream.init(file_contents);
    return try load_state_from_stream(allocator, &instream.stream);
}

fn load_state_from_stream(allocator: *Allocator, instream: var) !?State {
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

    var i: usize = 0;
    while (i < entity_count) : (i += 1) {
        const pos_x = try instream.readIntLittle(i32);
        const pos_y = try instream.readIntLittle(i32);
        const pos = Vec2i.new(pos_x, pos_y);

        const read_byte = @intCast(u3, try instream.readByte());
        const entity_type = @intToEnum(@TagType(Entity), read_byte);
        const entity = switch (entity_type) {
            .Block => blk: {
                // Had to do this nonsense, otherwise the type of the switch
                // would be inferred to @TagType(Entity) for some reason
                const ret: Entity = Entity.Block;
                break :blk ret;
            },
            .Mirror => blk: {
                const direction = try read_direction(instream);
                break :blk Entity{ .Mirror = direction };
            },
            .Splitter => blk: {
                const direction = try read_direction(instream);
                break :blk Entity{ .Splitter = direction };
            },
            .Laser => blk: {
                const direction = try read_direction(instream);
                break :blk Entity{ .Laser = direction };
            },
            .Delayer => blk: {
                const direction = try read_direction(instream);
                const is_on = (try instream.readByte()) > 0;
                break :blk Entity{
                    .Delayer = Delayer{
                        .direction = direction,
                        .is_on = is_on,
                    },
                };
            },
            .Switch => blk: {
                const direction = try read_direction(instream);
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
            .Lamp => blk: {
                const is_on = (try instream.readByte()) > 0;
                break :blk Entity{ .Lamp = is_on };
            },
        };
        _ = try state.add_entity(entity, pos);
    }

    return state;
}

inline fn read_direction(instream: var) !Direction {
    const read_byte = @intCast(u2, try instream.readByte());
    return @intToEnum(Direction, read_byte);
}

// TESTS ======================================================================

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
            .is_flipped = true,
        },
    }, Vec2i.new(42, 42));

    // Saving
    try save_state_to_stream(&state, &outstream.stream);
    var save_file = buffer.toOwnedSlice();
    defer std.debug.global_allocator.free(save_file);

    // Loading
    var instream = SliceInStream.init(save_file);
    const loaded_state = (try load_state_from_stream(
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
            // TODO: Test Lamp loading
            .Block, .Lamp => {},
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
