const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const windows = b.option(
        bool,
        "windows",
        "create windows build",
    ) orelse false;

    var exe = b.addExecutable("blink", "src/main.zig");
    exe.setBuildMode(mode);
    if (windows) {
        exe.setTarget(
            builtin.Arch.x86_64,
            builtin.Os.windows,
            builtin.Abi.gnu,
        );
        exe.addIncludeDir("/usr/include");
    }

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_ttf");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("SOIL");

    exe.setOutputDir(".");

    b.default_step.dependOn(&exe.step);

    b.installArtifact(exe);
}
