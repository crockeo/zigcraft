const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("cppcraft", "src/main.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

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

fn buildSdl2(_: *std.build.Builder) !void {
// # TODO: actually build it ourselves
// # so that we have a hermetic build
// cc_library(
//     name = "sdl2",
//     visibility = ["//visibility:public"],
//     hdrs = glob(["include/SDL2/*.h"]),
//     includes = ["include"],
//     linkopts = [
//         "-L/opt/homebrew/Cellar/sdl2/2.0.20/lib/",
// 	"-lSDL2",
//     ],
// )

// cc_library(
//     name = "sdl2_core",
//     visibility = ["//visibility:public"],
//     srcs = glob([
//         "src/*.c",
//         "src/atomic/*.c",
//         "src/audio/*.c",
//         "src/core/*.c",
//         "src/cpuinfo/*.c",
//         "src/dynapi/*.c",
//         "src/events/*.c",
//         "src/file/*.c",
//         "src/filesystem/*.c",
//         "src/haptic/*.c",
//         "src/hidapi/*.c",
//         "src/joystick/*.c",
//         "src/libm/*.c",
//         "src/loadso/*.c",
//         "src/locale/*.c",
//         "src/main/*.c",
//         "src/misc/*.c",
//         "src/power/*.c",
//         "src/render/*.c",
//         "src/sensor/*.c",
//         "src/stdlib/*.c",
//         "src/test/*.c",
//         "src/thread/*.c",
//         "src/timer/*.c",
//         "src/video/*.c",
//     ]),
//     hdrs = glob([
//         "src/**/*.h",
// 	"include/**/*.h",
//     ]),
//     includes = [
//         "include",
//     ],
// )

// objc_library(
//     name = "sdl2_macos_mixin",
//     srcs = [
//     ],
// )

// cc_library(
//     name = "sdl2_macos",
//     visibility = ["//visibility:public"],
//     srcs = glob([
//     ]),
//     deps = [
//         ":sdl2_core",
// 	":sdl2_macos_mixin",
//     ],
// )
}
