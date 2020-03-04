const std = @import("std");

const c = @import("../c.zig");

pub fn PipelineConfig(comptime UniformConfig: type) type {
    return struct {
        const Self = @This();
        pub const Uniforms = UniformConfig;

        vertexShader: [*:0]const u8,
        geometryShader: ?[*:0]const u8 = null,
        fragmentShader: [*:0]const u8,
    };
}

pub fn Pipeline(comptime config: var) type {
    if (!@hasDecl(@TypeOf(config), "Uniforms")) {
        @compileError("config must be of type PipelineConfig");
    }
    const Uniforms = @TypeOf(config).Uniforms;

    if (@TypeOf(config) != PipelineConfig(Uniforms)) {
        @compileError("config must be of type PipelineConfig");
    }

    const uniforms = std.meta.fields(Uniforms);
    return struct {
        const Self = @This();

        pub inline fn init() Self {
            return Self{};
        }

        fn uniformIndex(comptime name: []const u8) usize {
            inline for (uniforms) |field, i| {
                if (comptime std.mem.eql(u8, name, field.name)) {
                    return i;
                }
            }
            unreachable;
        }

        pub fn setUniform(self: *Self, comptime name: []const u8, value: var) void {
            const index = comptime uniformIndex(name);
            if (@TypeOf(value) != uniforms[index].field_type)
                @compileError("Uniform " ++ name ++ " has type " ++ @typeName(uniforms[index].field_type) ++ " but got " ++ @typeName(@TypeOf(value)));
            // TODO: OpenGL call
        }

        pub inline fn deinit(self: *Self) void {
            // TODO
        }
    };
}

test "compiles" {
    const Uniforms = struct {
        transparency: f64,
    };
    const config = PipelineConfig(Uniforms){
        .vertexShader = "",
        .fragmentShader = "",
    };

    const pipeline = Pipeline(config).init();
    defer pipeline.deinit();

    pipeline.setUniform("transparency", @as(f64, 64));
}
