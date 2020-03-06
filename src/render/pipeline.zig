const std = @import("std");

const c = @import("../c.zig");
const ShaderProgram = @import("shader.zig").ShaderProgram;

pub const AttributeKind = enum {
    Byte,
    UByte,
    Short,
    UShort,
    Int,
    UInt,
    Float,
    Double,

    pub fn size(self: AttributeKind) usize {
        return switch (self) {
            .Byte, .UByte => 1,
            .Short, .UShort => 2,
            .Int, .UInt, .Float => 4,
            .Double => 8,
        };
    }

    pub fn glType(self: AttributeKind) c.GLuint {
        return switch (self) {
            .Byte => c.GL_BYTE,
            .UByte => c.GL_UNSIGNED_BYTE,
            .Short => c.GL_SHORT,
            .UShort => c.GL_UNSIGNED_SHORT,
            .Int => c.GL_INT,
            .UInt => c.GL_UNSIGNED_INT,
            .Float => c.GL_FLOAT,
            .Double => c.GL_DOUBLE,
        };
    }
};

pub const AttributeSpecif = struct {
    name: [:0]const u8,
    kind: AttributeKind,
    count: usize,

    pub fn from(
        name: [:0]const u8,
        kind: AttributeKind,
        count: usize,
    ) AttributeSpecif {
        return .{
            .name = name,
            .kind = kind,
            .count = count,
        };
    }
};

pub const UniformKind = enum {
    Int,
    UInt,
    Float,
    Vec2,
    Vec3,
    Vec4,
    Matrix2,
    Matrix3,
    Matrix4,

    pub fn argType(comptime self: UniformKind) type {
        return switch (self) {
            .Int => i32,
            .UInt => u32,
            .Float => f32,
            .Vec2 => *[2]f32,
            .Vec3 => *[3]f32,
            .Vec4 => *[4]f32,
            .Matrix2 => *[2 * 2]f32,
            .Matrix3 => *[3 * 3]f32,
            .Matrix4 => *[4 * 4]f32,
        };
    }
};

pub const UniformSpecif = struct {
    name: [:0]const u8,
    kind: UniformKind,

    pub fn from(name: [:0]const u8, kind: UniformKind) UniformSpecif {
        return UniformSpecif{
            .name = name,
            .kind = kind,
        };
    }
};

pub const PipelineConfig = struct {
    const Self = @This();

    vertexShader: [*:0]const u8,
    geometryShader: ?[*:0]const u8 = null,
    fragmentShader: [*:0]const u8,

    attributes: []AttributeSpecif,
    uniforms: []UniformSpecif,
};

pub fn Pipeline(comptime config: PipelineConfig) type {
    return struct {
        const Self = @This();

        vao: c.GLuint = undefined,
        vbo: c.GLuint = undefined,
        shader: ShaderProgram = undefined,
        uniformLocations: [config.uniforms.len]c.GLint = undefined,

        pub fn init() Self {
            var self = Self{};

            c.glGenVertexArrays(1, &self.vao);
            c.glBindVertexArray(self.vao);

            c.glGenBuffers(1, &self.vbo);
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);

            var geomShader: ?[]const [*:0]const u8 = null;
            if (config.geometryShader) |shader| {
                geomShader = &[_][*:0]const u8{shader};
            }

            self.shader = ShaderProgram.new(
                &[_][*:0]const u8{config.vertexShader},
                geomShader,
                &[_][*:0]const u8{config.fragmentShader},
            );
            self.shader.link();
            self.shader.set_active();

            for (config.uniforms) |uniform, i| {
                self.uniformLocations[i] = self.shader.uniform_location(uniform.name);
            }

            const stride: c.GLsizei = comptime blk: {
                var s: usize = 0;
                for (config.attributes) |attribute| {
                    s += attribute.kind.size();
                }
                break :blk s;
            };

            comptime var offset: usize = 0;
            inline for (config.attributes) |attribute, location| {
                c.glEnableVertexAttribArray(location);
                c.glVertexAttribPointer(
                    location,
                    attribute.count,
                    comptime attribute.kind.glType(),
                    c.GL_FALSE,
                    @intCast(c.GLsizei, stride),
                    @intToPtr(?*const c_void, offset),
                );
                offset += comptime (attribute.count + attribute.kind.size());
            }

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.shader.deinit();
            c.glDeleteBuffers(1, &self.vbo);
            c.glDeleteVertexArrays(1, &self.vao);
        }

        fn uniformIndex(comptime name: []const u8) usize {
            inline for (config.uniforms) |uniform, i| {
                if (comptime std.mem.eql(u8, name, uniform.name)) {
                    return i;
                }
            }
            unreachable;
        }

        pub fn setUniform(
            self: *Self,
            comptime name: []const u8,
            value: var,
        ) void {
            const index = comptime uniformIndex(name);
            const uniform = config.uniforms[index];
            const uniformArgType = uniform.kind.argType();

            const location = self.uniformLocations[index];

            if (@TypeOf(value) != uniformArgType)
                @compileError("Uniform \"" ++ uniform.name ++ "\" requires a " ++ @typeName(uniformArgType) ++ " but got " ++ @typeName(@TypeOf(value)));

            switch (uniform.kind) {
                .Int => c.glUniform1i(location, value),
                .UInt => c.glUniform1ui(location, value),
                .Float => c.glUniform1f(location, value),
                .Vec2 => c.glUniform2fv(location, 1, value),
                .Vec3 => c.glUniform3fv(location, 1, value),
                .Vec4 => c.glUniform4fv(location, 1, value),
                .Matrix2 => c.glUniformMatrix2fv(location, 1, c.GL_TRUE, value),
                .Matrix3 => c.glUniformMatrix3fv(location, 1, c.GL_TRUE, value),
                .Matrix4 => c.glUniformMatrix4fv(location, 1, c.GL_TRUE, value),
            }
        }

        pub fn setActive(self: *Self) void {
            c.glBindVertexArray(self.vao);
            self.shader.set_active();
        }
    };
}

fn glType(comptime t: type) c.GLint {
    switch (@typeInfo(t)) {
        .Int => |intType| switch (intType.bits) {
            8 => return if (intType.is_signed) c.GL_BYTE else c.GL_UNSIGNED_BYTE,
            16 => return if (intType.is_signed) c.GL_SHORT else c.GL_UNSIGNED_SHORT,
            32 => return if (intType.is_signed) c.GL_INT else c.GL_UNSIGNED_INT,
            else => unreachable,
        },
        .Float => |floatType| switch (floatType.bits) {
            16 => return c.GL_HALF_FLOAT,
            32 => return c.GL_FLOAT,
            64 => return c.GL_DOUBLE,
            else => unreachable,
        },
        else => unreachable,
    }
}
