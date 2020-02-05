const std_build = @import("std").build;
const Builder = std_build.Builder;
const LibExeObjStep = std_build.LibExeObjStep;
const builtin = @import("builtin");

const CFLAGS = [_][]const u8{"-O2"};

pub fn build(b: *Builder) void {
    const windows_step = b.step("windows", "Cross-compile to Microsoft Windows");
    const package_step = b.step("package", "Package binaries for release");

    var exe_linux = build_linux(b);
    var exe_windows = build_windows(b);

    b.default_step.dependOn(&exe_linux.step);
    var install_windows = b.addInstallArtifact(exe_windows);
    windows_step.dependOn(&install_windows.step);

    var package_script = b.addSystemCommand(&[_][]const u8{"./package.sh"});
    package_script.step.dependOn(&exe_linux.step);
    package_script.step.dependOn(&exe_windows.step);
    package_step.dependOn(&package_script.step);

    b.installArtifact(exe_linux);
}

fn build_common(b: *Builder) *LibExeObjStep {
    const mode = b.standardReleaseOptions();
    var exe = b.addExecutable("blink", "src/main.zig");
    exe.setBuildMode(mode);
    exe.addIncludeDir("third-party/lodepng/include");
    exe.addIncludeDir("include");
    exe.addCSourceFile("third-party/lodepng/src/lodepng.c", CFLAGS[0..]);
    exe.linkSystemLibrary("c");
    exe.setOutputDir(".");

    return exe;
}

fn build_linux(b: *Builder) *LibExeObjStep {
    var exe = build_common(b);

    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_ttf");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("freetype2");

    return exe;
}

fn build_windows(b: *Builder) *LibExeObjStep {
    var exe = build_common(b);

    exe.setTarget(
        builtin.Arch.x86_64,
        builtin.Os.windows,
        builtin.Abi.gnu,
    );
    exe.addIncludeDir("/usr/include");

    exe.addObjectFile("deps/windows/lib/libSDL2main.a");
    exe.addObjectFile("deps/windows/lib/libSDL2.dll.a");
    exe.addObjectFile("deps/windows/lib/libSDL2_ttf.dll.a");
    exe.addObjectFile("deps/windows/lib/libopengl32.a");
    exe.addObjectFile("deps/windows/lib/epoxy.lib");
    //TODO: add freetype2

    return exe;
}
