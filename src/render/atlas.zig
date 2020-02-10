const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const c = @import("../c.zig");
const Direction = @import("../entities.zig").Direction;

usingnamespace @import("../vec.zig");

pub const TextureAtlas = struct {
    handle: c.GLuint,
    width: c_int,
    height: c_int,
    cell_width: usize,
    cell_height: usize,
    textures: ArrayList(Rectf),
    index: StringHashMap(usize),
    index_storage: ArenaAllocator,

    pub fn load(
        allocator: *Allocator,
        path: []const u8,
        cell_width: usize,
        cell_height: usize,
    ) !TextureAtlas {
        var atlas = TextureAtlas{
            .handle = undefined,
            .width = undefined,
            .height = undefined,
            .cell_width = cell_width,
            .cell_height = cell_height,
            .textures = ArrayList(Rectf).init(allocator),
            .index = StringHashMap(usize).init(allocator),
            .index_storage = ArenaAllocator.init(allocator),
        };

        const texture_path = try std.mem.concat(
            allocator,
            u8,
            &[_][]const u8{ path, ".png\x00" },
        );
        const layout_path = try std.mem.concat(
            allocator,
            u8,
            &[_][]const u8{ path, ".json" },
        );
        defer {
            allocator.free(layout_path);
            allocator.free(texture_path);
        }

        // Load image data
        c.glGenTextures(1, &atlas.handle);
        c.glBindTexture(c.GL_TEXTURE_2D, atlas.handle);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_MIRRORED_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_MIRRORED_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

        var image_data: [*c]u8 = undefined;
        const ret = c.lodepng_decode32_file(
            &image_data,
            @ptrCast([*c]c_uint, &atlas.width),
            @ptrCast([*c]c_uint, &atlas.height),
            @ptrCast([*c]const u8, texture_path.ptr),
        );
        if (ret != 0) {
            std.debug.warn("Could not load {s}: {s}\n", .{
                texture_path,
                c.lodepng_error_text(ret),
            });
            std.process.exit(1);
        }
        defer c.free(image_data);
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            atlas.width,
            atlas.height,
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            image_data,
        );

        // Load layout
        const layout = std.io.readFileAlloc(allocator, layout_path) catch |err| {
            std.debug.panic("Could not load {}: {}\n", .{
                layout_path,
                @errorName(err),
            });
        };
        defer allocator.free(layout);

        var parser = json.Parser.init(allocator, true);
        defer parser.deinit();

        var tree = try parser.parse(layout);
        defer tree.deinit();

        var root = tree.root;
        var iter = root.Object.iterator();
        while (iter.next()) |entry| {
            const key = try std.mem.dupe(
                &atlas.index_storage.allocator,
                u8,
                entry.key,
            );
            _ = try atlas.index.put(key, atlas.index.count());

            var x = @intToFloat(f32, entry.value.Array.at(0).Integer);
            var y = @intToFloat(f32, entry.value.Array.at(1).Integer);
            var w = @intToFloat(f32, entry.value.Array.at(2).Integer);
            var h = @intToFloat(f32, entry.value.Array.at(3).Integer);

            x /= @intToFloat(f32, atlas.width);
            y /= @intToFloat(f32, atlas.height);
            w /= @intToFloat(f32, atlas.width);
            h /= @intToFloat(f32, atlas.height);

            try atlas.textures.append(Rectf.new(
                Vec2f.new(x, y),
                Vec2f.new(w, h),
            ));
        }

        return atlas;
    }

    pub fn deinit(self: *TextureAtlas) void {
        self.index_storage.deinit();
        c.glDeleteTextures(1, &self.handle);
        self.textures.deinit();
        self.index.deinit();
    }

    pub fn bind(self: *TextureAtlas) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.handle);
    }

    pub inline fn get_offset(
        self: *TextureAtlas,
        texture_id: usize,
    ) Vec2f {
        return self.get_offset_flip(texture_id, false, false);
    }

    pub inline fn get_tile_size(self: *TextureAtlas) Vec2f {
        return Vec2f{
            .x = @intToFloat(f32, self.cell_width) / @intToFloat(f32, self.width),
            .y = @intToFloat(f32, self.cell_height) / @intToFloat(f32, self.height),
        };
    }

    pub fn get_offset_flip(
        self: *TextureAtlas,
        texture_id: usize,
        horizontal: bool,
        vertical: bool,
    ) Vec2f {
        const cell_per_line = @divFloor(@intCast(usize, self.width), self.cell_width);
        var x = @intCast(i32, self.cell_width * (texture_id % cell_per_line));
        var y = @intCast(i32, self.cell_height * (texture_id / cell_per_line));
        if (horizontal)
            x = -x - @intCast(i32, self.cell_width);
        if (vertical)
            y = -y - @intCast(i32, self.cell_height);
        return Vec2f.new(
            @intToFloat(f32, x) / @intToFloat(f32, self.width),
            @intToFloat(f32, y) / @intToFloat(f32, self.height),
        );
    }

    pub fn id_of(self: *const TextureAtlas, name: []const u8) ?usize {
        const entry = self.index.get(name) orelse return null;
        return entry.value;
    }

    pub fn rect_of_flipped(
        self: *const TextureAtlas,
        texture_id: usize,
        horizontal: bool,
        vertical: bool,
    ) Rectf {
        var rect = self.textures.at(texture_id);
        if (horizontal)
            rect.pos.x = -rect.pos.x - rect.size.x;
        if (vertical)
            rect.pos.y = -rect.pos.y - rect.size.y;
        return rect;
    }

    pub inline fn rect_of(self: *const TextureAtlas, texture_id: usize) Rectf {
        return self.rect_of_flipped(texture_id, false, false);
    }
};
