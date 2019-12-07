const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

const CFLAGS = [_][]const u8{"-O2"};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const windows = b.option(
        bool,
        "windows",
        "cross-compile to Microsoft Windows",
    ) orelse false;

    var exe = b.addExecutable("blink", "src/main.zig");
    exe.setBuildMode(mode);
    exe.addIncludeDir("include");
    exe.addCSourceFile("src/lodepng.c", CFLAGS[0..]);
    if (windows) {
        exe.setTarget(
            builtin.Arch.x86_64,
            builtin.Os.windows,
            builtin.Abi.gnu,
        );
        exe.addIncludeDir("/usr/include");

        exe.addObjectFile("lib/libSDL2main.a");
        exe.addObjectFile("lib/libSDL2.dll.a");
        exe.addObjectFile("lib/libSDL2_ttf.dll.a");
        exe.addObjectFile("lib/libopengl32.a");
        exe.addObjectFile("lib/epoxy.lib");
    } else {
        exe.linkSystemLibrary("SDL2");
        exe.linkSystemLibrary("SDL2_ttf");
        exe.linkSystemLibrary("GL");
        exe.linkSystemLibrary("epoxy");
    }
    exe.linkSystemLibrary("c");

    exe.setOutputDir(".");

    b.default_step.dependOn(&exe.step);

    b.installArtifact(exe);
}
