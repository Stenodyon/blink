const std = @import("std");

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
        _ = c.printf(
            c"%s\n",
            &log_buffer,
        );
        std.process.exit(255);
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
        _ = c.printf(
            c"%s\n",
            &log_buffer,
        );
        std.process.exit(255);
    }
}

fn compile_shader(shader: c.GLuint, source: [*c]const [*c]const u8) void {
    c.glShaderSource(shader, 1, source, null);
    c.glCompileShader(shader);
    check_shader(shader);
}

pub const ShaderProgram = struct {
    vertex_shader: c.GLuint,
    geometry_shader: ?c.GLuint,
    fragment_shader: c.GLuint,
    handle: c.GLuint,

    pub fn new(
        vertex_shader_src: [*c]const [*c]const u8,
        geometry_shader_src: ?[*c]const [*c]const u8,
        fragment_shader_src: [*c]const [*c]const u8,
    ) ShaderProgram {
        var shader_program = ShaderProgram{
            .vertex_shader = undefined,
            .geometry_shader = null,
            .fragment_shader = undefined,
            .handle = undefined,
        };
        shader_program.vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
        compile_shader(shader_program.vertex_shader, vertex_shader_src);

        shader_program.fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        compile_shader(shader_program.fragment_shader, fragment_shader_src);

        if (geometry_shader_src) |geom_shader_source| {
            shader_program.geometry_shader = c.glCreateShader(c.GL_GEOMETRY_SHADER);
            compile_shader(shader_program.geometry_shader.?, geom_shader_source);
        }

        shader_program.handle = c.glCreateProgram();
        c.glAttachShader(shader_program.handle, shader_program.vertex_shader);
        if (shader_program.geometry_shader) |geom_handle|
            c.glAttachShader(shader_program.handle, geom_handle);
        c.glAttachShader(shader_program.handle, shader_program.fragment_shader);

        return shader_program;
    }

    pub fn deinit(self: *ShaderProgram) void {
        c.glDeleteProgram(self.handle);
        c.glDeleteShader(self.fragment_shader);
        if (self.geometry_shader) |geom_shader|
            c.glDeleteShader(geom_shader);
        c.glDeleteShader(self.vertex_shader);
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
