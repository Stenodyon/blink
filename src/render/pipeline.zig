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

    pub fn glType(self: AttributeSpecif) c.GLuint {
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
    name: []const u8,
    kind: AttributeKind,
    count: usize,

    pub fn from(
        name: []const u8,
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
};

pub const UniformSpecif = struct {
    name: []const u8,
    kind: UniformKind,

    pub fn from(name: []const u8, kind: UniformKind) UniformSpecif {
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

            var geomShader = null;
            if (config.geomShader) |shader| {
                geomShader = [_][*:0]const u8{shader};
            }

            self.shader = ShaderProgram.new(
                &[_][*:0]const u8{config.vertexShader},
                geomShader,
                &[_][*:0]const u8{config.fragmentShader},
            );
            shader.link();
            shader.set_active();

            for (config.uniforms) |uniform, i| {
                self.uniformLocations[i] = shader.uniform_location(uniform.name);
            }

            const stride: c.GLsizei = comptime blk: {
                var s: c.GLsizei = 0;
                for (attributes) |attribute| {
                    s += @sizeOf(attribute.kind.size());
                }
                break :blk s;
            };

            comptime var offset: usize = 0;
            inline for (attributes) |attribute, location| {
                c.glEnableVertexAttribArray(location);
                c.glVertexAttribPointer(
                    location,
                    attribute.count,
                    comptime attribute.kind.glType(),
                    c.GL_FALSE,
                    stride,
                    @intToPtr(?*const c_void, offset),
                );
                offset += attribute.count + attribute.kind.size();
            }

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.shader.deinit();
            c.glDeleteBuffers(1, &self.vbo);
            c.glDeleteVertexArrays(1, &self.vao);
        }

        fn uniformIndex(comptime name: []const u8) usize {
            inline for (uniforms) |field, i| {
                if (comptime std.mem.eql(u8, name, field.name)) {
                    return i;
                }
            }
            unreachable;
        }

        fn uniformType(comptime name: []const u8) type {
            inline for (uniforms) |field| {
                if (comptime std.mem.eql(u8, name, field.name)) {
                    return field.field_type;
                }
            }
            unreachable;
        }

        pub fn setUniform(self: *Self, comptime name: []const u8, value: var) void {
            const index = comptime uniformIndex(name);
            const t = comptime uniformType(name);
            if (@TypeOf(value) != t)
                @compileError("Uniform " ++ name ++ " has type " ++ @typeName(t) ++ " but got " ++ @typeName(@TypeOf(value)));
            const location = self.uniformLocations[index];
            // TODO: OpenGL call
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
