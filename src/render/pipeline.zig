const std = @import("std");

const c = @import("../c.zig");
const ShaderProgram = @import("shader.zig").ShaderProgram;

pub fn PipelineConfig(
    comptime AttributeConfig: type,
    comptime UniformConfig: type,
) type {
    return struct {
        const Self = @This();
        pub const Attributes = AttributeConfig;
        pub const Uniforms = UniformConfig;

        vertexShader: [*:0]const u8,
        geometryShader: ?[*:0]const u8 = null,
        fragmentShader: [*:0]const u8,
    };
}

pub fn Pipeline(comptime config: var) type {
    if (!@hasDecl(@TypeOf(config), "Attributes") or
        !@hasDecl(@TypeOf(config), "Uniforms"))
    {
        @compileError("config must be of type PipelineConfig");
    }
    const Attributes = @TypeOf(config).Attributes;
    const Uniforms = @TypeOf(config).Uniforms;

    if (@TypeOf(config) != PipelineConfig(Attributes, Uniforms)) {
        @compileError("config must be of type PipelineConfig");
    }

    const attributes = std.meta.fields(Attributes);
    const uniforms = std.meta.fields(Uniforms);
    return struct {
        const Self = @This();

        vao: c.GLuint = undefined,
        vbo: c.GLuint = undefined,
        shader: ShaderProgram = undefined,
        uniformLocations: [uniforms.len]c.GLint = undefined,

        pub inline fn init() Self {
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

            for (uniforms) |field, i| {
                self.uniformLocations[i] = shader.uniform_location(field.name);
            }

            const stride: c.GLsizei = comptime blk: {
                var s: c.GLsizei = 0;
                for (attributes) |field, i| {
                    s += @sizeOf(field.field_type);
                }
                break :blk s;
            };

            var offset: usize = 0;
            for (attributes) |field, i| {
                const attributeSize = switch (@typeInfo(field.field_type)) {
                    .Array => |array| array.len,
                    else => 1,
                };
                const attributeType = switch (@typeInfo(field.field_type)) {
                    .Array => |array| glType(array.child),
                    else => glType(field.field_type),
                };
                c.glEnableVertexAttribArray(i);
                c.glVertexAttribPointer(
                    i,
                    attributeSize,
                    attributeType,
                    c.GL_FALSE,
                    stride,
                    @intToPtr(?*const c_void, offset),
                );
                offset += @sizeOf(field.field_type);
            }

            return self;
        }

        pub inline fn deinit(self: *Self) void {
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
