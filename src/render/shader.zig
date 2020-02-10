const std = @import("std");
const panic = std.debug.panic;

const c = @import("../c.zig");

const LOG_BUFFER_SIZE = 512;

fn check_shader(shader: c.GLuint) void {
    var status: c.GLuint = undefined;
    c.glGetShaderiv(
        shader,
        c.GL_COMPILE_STATUS,
        @ptrCast([*c]c_int, &status),
    );

    if (status != c.GL_TRUE) {
        var log_buffer: [LOG_BUFFER_SIZE]u8 = undefined;
        c.glGetShaderInfoLog(shader, LOG_BUFFER_SIZE, null, &log_buffer);
        panic("Shader compilation error:\n{}\n", .{&log_buffer});
    }
}

fn check_program(program: c.GLuint) void {
    var status: c.GLuint = undefined;
    c.glGetProgramiv(
        program,
        c.GL_LINK_STATUS,
        @ptrCast([*c]c_int, &status),
    );

    if (status != c.GL_TRUE) {
        var log_buffer: [LOG_BUFFER_SIZE]u8 = undefined;
        c.glGetProgramInfoLog(program, LOG_BUFFER_SIZE, null, &log_buffer);
        panic("Shader linking error:\n{}\n", .{&log_buffer});
    }
}

fn compile_shader(shader: c.GLuint, source: [*c]const [*c]const u8) void {
    c.glShaderSource(shader, 1, source, null);
    c.glCompileShader(shader);
    check_shader(shader);
}

pub const ShaderProgram = struct {
    handle: c.GLuint,

    pub fn new(
        vertex_shader_src: [*c]const [*c]const u8,
        geometry_shader_src: [*c]const [*c]const u8,
        fragment_shader_src: [*c]const [*c]const u8,
    ) ShaderProgram {
        var shader_program = ShaderProgram{
            .handle = undefined,
        };
        const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
        compile_shader(vertex_shader, vertex_shader_src);

        const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        compile_shader(fragment_shader, fragment_shader_src);

        var geometry_shader: ?c.GLuint = null;
        if (geometry_shader_src) |geom_shader_source| {
            geometry_shader = c.glCreateShader(c.GL_GEOMETRY_SHADER);
            compile_shader(geometry_shader.?, geom_shader_source);
        }

        shader_program.handle = c.glCreateProgram();
        c.glAttachShader(shader_program.handle, vertex_shader);
        if (geometry_shader) |geom_shader|
            c.glAttachShader(shader_program.handle, geom_shader);
        c.glAttachShader(shader_program.handle, fragment_shader);

        c.glDeleteShader(fragment_shader);
        if (geometry_shader) |geom_shader|
            c.glDeleteShader(geom_shader);
        c.glDeleteShader(vertex_shader);

        return shader_program;
    }

    pub fn deinit(self: *ShaderProgram) void {
        c.glDeleteProgram(self.handle);
    }

    pub fn link(self: *ShaderProgram) void {
        c.glLinkProgram(self.handle);
        check_program(self.handle);
    }

    pub inline fn set_active(self: *ShaderProgram) void {
        c.glUseProgram(self.handle);
    }

    pub inline fn uniform_location(
        self: *const ShaderProgram,
        uniform_name: [*c]const u8,
    ) c.GLint {
        return c.glGetUniformLocation(self.handle, uniform_name);
    }
};
