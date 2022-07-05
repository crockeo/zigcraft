const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("cppcraft", "src/main.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    try buildSdl2(b, exe);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "");
    run_step.dependOn(&run_cmd.step);
}

fn buildBgfx(_: *std.build.Builder) !void {
    // cc_library(
    //     name = "bgfx",
    //     visibility = ["//visibility:public"],
    //     srcs = [
    //         "src/bgfx.cpp",
    //         "src/debug_renderdoc.cpp",
    //         "src/dxgi.cpp",
    //         "src/glcontext_egl.cpp",
    //         "src/glcontext_glx.cpp",
    //         "src/glcontext_html5.cpp",
    //         "src/glcontext_wgl.cpp",
    //         "src/nvapi.cpp",
    //         "src/renderer_d3d11.cpp",
    //         "src/renderer_d3d12.cpp",
    //         "src/renderer_d3d9.cpp",
    //         "src/renderer_gl.cpp",
    //         "src/renderer_gnm.cpp",
    //         "src/renderer_noop.cpp",
    //         "src/renderer_nvn.cpp",
    //         "src/renderer_vk.cpp",
    //         "src/renderer_webgpu.cpp",
    //         "src/shader.cpp",
    //         "src/shader_dx9bc.cpp",
    //         "src/shader_dxbc.cpp",
    //         "src/shader_spirv.cpp",
    //         "src/topology.cpp",
    //         "src/vertexlayout.cpp",
    //     ],
    //     hdrs = glob([
    //         "**/*.h",
    //         "**/*.inl",
    //     ]),
    //     deps = [
    //         "@bimg//:bimg",
    //         "@bx//:bx",
    //     ],
    //     defines = [
    //         "BGFX_CONFIG_RENDERER_VULKAN=0",
    //         "BGFX_CONFIG_RENDERER_METAL=1",
    // 	# emergency "oh shit i need to debug" lever
    //         "BGFX_CONFIG_DEBUG=1",
    //     ],
    //     includes = [
    //         "3rdparty",
    //         "3rdparty/khronos",
    //         "include",
    //     ],
    // )

    // objc_library(
    //     name = "bgfx_macos",
    //     visibility = ["//visibility:public"],
    //     srcs = [
    //         "src/glcontext_eagl.mm",
    //         "src/glcontext_nsgl.mm",
    //         "src/renderer_mtl.mm",
    //     ],
    //     hdrs = glob([
    //         "**/*.h",
    //         "**/*.inl",
    //     ]),
    //     includes = [
    //         "include",
    //     ],
    //     sdk_frameworks = [
    //         "Cocoa",
    //         "Metal",
    //         "QuartzCore",
    //     ],
    //     copts = [
    //         "-fno-objc-arc",
    //     ],
    //     deps = [":bgfx"],
    // )
}

fn buildBimg(_: *std.build.Builder) !void {
    // cc_library(
    //     name = "bimg",
    //     visibility = ["//visibility:public"],
    //     srcs = [
    //         "src/image.cpp",
    //         "src/image_cubemap_filter.cpp",
    //         "src/image_decode.cpp",
    //         "src/image_encode.cpp",
    //         "src/image_gnf.cpp",
    //     ],
    //     hdrs = glob(["**"]),
    //     includes = [
    //         "3rdparty",
    // 	"3rdparty/iqa/include",
    //         "include",
    //     ],
    //     deps = [
    // 	"@astc-codec//:astc_codec",
    //         "@bx//:bx",
    //     ],
    // )
}

fn buildBx(_: *std.build.Builder) !void {
    // cc_library(
    //     name = "bx",
    //     visibility = ["//visibility:public"],
    //     srcs = [
    //         "src/allocator.cpp",
    //         "src/bx.cpp",
    //         "src/commandline.cpp",
    //         "src/crtnone.cpp",
    //         "src/debug.cpp",
    //         "src/dtoa.cpp",
    //         "src/easing.cpp",
    //         "src/file.cpp",
    //         "src/filepath.cpp",
    //         "src/hash.cpp",
    //         "src/math.cpp",
    //         "src/mutex.cpp",
    //         "src/os.cpp",
    //         "src/process.cpp",
    //         "src/semaphore.cpp",
    //         "src/settings.cpp",
    //         "src/sort.cpp",
    //         "src/string.cpp",
    //         "src/thread.cpp",
    //         "src/timer.cpp",
    //         "src/url.cpp",
    //     ],
    //     hdrs = glob(["**"]),
    //     includes = [
    //         "3rdparty",
    // 	"include",
    // 	"include/compat/osx",
    //     ],
    // )
}

fn buildSdl2(_: *std.build.Builder, exe: *std.build.LibExeObjStep) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try pkgConfig(gpa.allocator(), exe, "sdl2");
}

fn pkgConfig(allocator: std.mem.Allocator, exe: *std.build.LibExeObjStep, pkg_name: []const u8) !void {
    const result = try std.ChildProcess.exec(
        .{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "pkg-config",
                "--cflags-only-I",
                "--libs-only-L",
                "--libs-only-l",
                pkg_name,
            },
        },
    );
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    var iter = std.mem.split(u8, std.mem.trim(u8, result.stdout, " \n"), " ");
    while (iter.next()) |arg| {
        const flag = arg[0..2];
        const content = arg[2..];

        if (std.mem.eql(u8, flag, "-I")) {
            exe.addIncludeDir(content);
        } else if (std.mem.eql(u8, flag, "-L")) {
            exe.addLibPath(content);
        } else if (std.mem.eql(u8, flag, "-l")) {
            exe.linkSystemLibraryName(content);
        } else {
            std.log.err("Linker flag and content: {s}{s}", .{ flag, content });
            return error.UnexpectedLinkerCommand;
        }
    }
}
