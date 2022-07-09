const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("cppcraft", "src/main.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    exe.addIncludeDir("src");

    const bx = buildBx(b);
    exe.linkLibrary(bx);

    const bimg = buildBimg(b, bx);
    exe.linkLibrary(bimg);

    const bgfx = buildBgfx(b, bimg, bx);
    exe.linkLibrary(bgfx);

    const cppcraft = try buildCppCraft(b, bgfx, bimg, bx);
    exe.linkLibrary(cppcraft);

    try buildSdl2(b, exe);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "");
    run_step.dependOn(&run_cmd.step);
}

fn buildCppCraft(b: *std.build.Builder, bgfx: *std.build.LibExeObjStep, bimg: *std.build.LibExeObjStep, bx: *std.build.LibExeObjStep) !*std.build.LibExeObjStep {
    const cppcraft = b.addStaticLibrary("cppcraft", null);

    cppcraft.linkLibCpp();
    try buildSdl2(b, cppcraft);

    cppcraft.addCSourceFiles(
        &.{
            "src/program.cpp",
        },
        &.{},
    );

    cppcraft.addIncludeDir("dependencies/bgfx/include");
    cppcraft.addIncludeDir("dependencies/bimg/include");
    cppcraft.addIncludeDir("dependencies/bx/include");

    cppcraft.linkLibrary(bgfx);
    cppcraft.linkLibrary(bimg);
    cppcraft.linkLibrary(bx);

    return cppcraft;
}

fn buildBgfx(b: *std.build.Builder, bimg: *std.build.LibExeObjStep, bx: *std.build.LibExeObjStep) *std.build.LibExeObjStep {
    const bgfx = b.addStaticLibrary("bgfx", null);

    bgfx.defineCMacro("BGFX_CONFIG_RENDERER_VULKAN", "0");
    bgfx.defineCMacro("BGFX_CONFIG_RENDERER_METAL", "1");
    bgfx.defineCMacro("BGFX_CONFIG_DEBUG", "1");

    bgfx.linkFramework("Cocoa");
    bgfx.linkFramework("Metal");
    bgfx.linkFramework("QuartzCore");

    bgfx.linkLibrary(bimg);
    bgfx.addIncludeDir("dependencies/bimg/include");

    bgfx.linkLibrary(bx);
    bgfx.addIncludeDir("dependencies/bx/include");

    bgfx.addCSourceFiles(
        &.{
            "dependencies/bgfx/src/bgfx.cpp",
            "dependencies/bgfx/src/debug_renderdoc.cpp",
            "dependencies/bgfx/src/dxgi.cpp",
            "dependencies/bgfx/src/glcontext_eagl.mm",
            "dependencies/bgfx/src/glcontext_egl.cpp",
            "dependencies/bgfx/src/glcontext_glx.cpp",
            "dependencies/bgfx/src/glcontext_html5.cpp",
            "dependencies/bgfx/src/glcontext_nsgl.mm",
            "dependencies/bgfx/src/glcontext_wgl.cpp",
            "dependencies/bgfx/src/nvapi.cpp",
            "dependencies/bgfx/src/renderer_d3d11.cpp",
            "dependencies/bgfx/src/renderer_d3d12.cpp",
            "dependencies/bgfx/src/renderer_d3d9.cpp",
            "dependencies/bgfx/src/renderer_gl.cpp",
            "dependencies/bgfx/src/renderer_gnm.cpp",
            "dependencies/bgfx/src/renderer_mtl.mm",
            "dependencies/bgfx/src/renderer_noop.cpp",
            "dependencies/bgfx/src/renderer_nvn.cpp",
            "dependencies/bgfx/src/renderer_vk.cpp",
            "dependencies/bgfx/src/renderer_webgpu.cpp",
            "dependencies/bgfx/src/shader.cpp",
            "dependencies/bgfx/src/shader_dx9bc.cpp",
            "dependencies/bgfx/src/shader_dxbc.cpp",
            "dependencies/bgfx/src/shader_spirv.cpp",
            "dependencies/bgfx/src/topology.cpp",
            "dependencies/bgfx/src/vertexlayout.cpp",
        },
        &.{}
        // TODO: do i need this?
        // "-fno-objc-arc",
    );
    bgfx.addIncludeDir("dependencies/bgfx/include");

    return bgfx;
}

fn buildBimg(b: *std.build.Builder, bx: *std.build.LibExeObjStep) *std.build.LibExeObjStep {
    const bimg = b.addStaticLibrary("bimg", null);

    bimg.linkLibrary(bx);
    bimg.addIncludeDir("dependencies/bx/include");

    // TODO: need to build and link astc-codec
    // cc_library(
    //     name = "bimg",
    //     visibility = ["//visibility:public"],
    //     srcs = [
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

    bimg.addCSourceFiles(
        &.{
            "dependencies/bimg/src/image.cpp",
            "dependencies/bimg/src/image_cubemap_filter.cpp",
            "dependencies/bimg/src/image_decode.cpp",
            "dependencies/bimg/src/image_encode.cpp",
            "dependencies/bimg/src/image_gnf.cpp",
        },
        &.{},
    );
    bimg.addIncludeDir("dependencies/bimg/include");
    bimg.addIncludeDir("dependencies/bimg/3rdparty");
    bimg.addIncludeDir("dependencies/bimg/3rdparty/astc-codec/include");
    bimg.addIncludeDir("dependencies/bimg/3rdparty/iqa/include");

    return bimg;
}

fn buildBx(b: *std.build.Builder) *std.build.LibExeObjStep {
    const bx = b.addStaticLibrary("bx", null);

    bx.linkLibC();
    bx.linkLibCpp();
    bx.linkFramework("CoreFoundation");

    bx.addCSourceFiles(&.{
        "dependencies/bx/src/allocator.cpp",
        "dependencies/bx/src/bx.cpp",
        "dependencies/bx/src/commandline.cpp",
        "dependencies/bx/src/crtnone.cpp",
        "dependencies/bx/src/debug.cpp",
        "dependencies/bx/src/dtoa.cpp",
        "dependencies/bx/src/easing.cpp",
        "dependencies/bx/src/file.cpp",
        "dependencies/bx/src/filepath.cpp",
        "dependencies/bx/src/hash.cpp",
        "dependencies/bx/src/math.cpp",
        "dependencies/bx/src/mutex.cpp",
        "dependencies/bx/src/os.cpp",
        "dependencies/bx/src/process.cpp",
        "dependencies/bx/src/semaphore.cpp",
        "dependencies/bx/src/settings.cpp",
        "dependencies/bx/src/sort.cpp",
        "dependencies/bx/src/string.cpp",
        "dependencies/bx/src/thread.cpp",
        "dependencies/bx/src/timer.cpp",
        "dependencies/bx/src/url.cpp",
    }, &.{});
    bx.addIncludeDir("dependencies/bx/3rdparty");
    bx.addIncludeDir("dependencies/bx/include");
    bx.addIncludeDir("dependencies/bx/include/compat/osx");

    return bx;
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
