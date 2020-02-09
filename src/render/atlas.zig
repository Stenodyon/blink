const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");
const Direction = @import("../entities.zig").Direction;
const Vec2f = @import("../vec.zig").Vec2f;

pub const TextureAtlas = struct {
    handle: c.GLuint,
    width: c_int,
    height: c_int,
    cell_width: usize,
    cell_height: usize,

    pub fn load(
        allocator: *Allocator,
        path: [*c]const u8,
        cell_width: usize,
        cell_height: usize,
    ) TextureAtlas {
        var atlas = TextureAtlas{
            .handle = undefined,
            .width = undefined,
            .height = undefined,
            .cell_width = cell_width,
            .cell_height = cell_height,
        };

        c.glGenTextures(1, &atlas.handle);
        c.glBindTexture(c.GL_TEXTURE_2D, atlas.handle);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_MIRRORED_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_MIRRORED_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

        var image_data: [*c]u8 = undefined;
        const err = c.lodepng_decode32_file(
            &image_data,
            @ptrCast([*c]c_uint, &atlas.width),
            @ptrCast([*c]c_uint, &atlas.height),
            path,
        );
        if (err != 0) {
            std.debug.warn(
                "Could not load data/entity_atlas.png: {c}\n",
                .{c.lodepng_error_text(err)},
            );
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

        return atlas;
    }

    pub fn deinit(self: *TextureAtlas) void {
        c.glDeleteTextures(1, &self.handle);
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
};
