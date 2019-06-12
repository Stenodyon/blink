const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var exe = b.addExecutable("blink", "src/main.zig");
    exe.setBuildMode(mode);

    exe.addIncludeDir("/usr/include");

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_image");
    exe.linkSystemLibrary("SDL2_ttf");

    exe.setOutputDir(".");

    b.default_step.dependOn(&exe.step);

    b.installArtifact(exe);
}
