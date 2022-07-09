const std = @import("std");

pub const c = @cImport({
    @cInclude("bgfx/c99/bgfx.h");
    @cInclude("program.h");
    @cInclude("SDL.h");
    @cInclude("SDL_syswm.h");
});

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.log.err("Failed to initialize SDL.", .{});
        return error.FailedSDLInit;
    }
    defer c.SDL_Quit();

    const WIDTH: u32 = 640;
    const HEIGHT: u32 = 480;
    const window = c.SDL_CreateWindow(
        "hello world",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        WIDTH,
        HEIGHT,
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_SHOWN,
    ) orelse {
        std.log.err("Failed to initialize SDL window.", .{});
        return error.FailedSDLWindowInit;
    };
    defer c.SDL_DestroyWindow(window);

    try registerPlatformData(window);

    c.realMain(window, WIDTH, HEIGHT);
}

fn registerPlatformData(window: *c.SDL_Window) !void {
    var wmi: c.SDL_SysWMinfo = undefined;
    wmi.version.major = c.SDL_MAJOR_VERSION;
    wmi.version.minor = c.SDL_MINOR_VERSION;
    wmi.version.patch = c.SDL_PATCHLEVEL;
    if (c.SDL_GetWindowWMInfo(window, &wmi) != c.SDL_TRUE) {
        return error.FailedGetWindowWMInfo;
    }

    // TODO: populate platform data for non-macOS targets
    var pd: c.bgfx_platform_data_t = undefined;
    pd.ndt = null;
    pd.nwh = wmi.info.cocoa.window;
    pd.context = null;
    pd.backBuffer = null;
    pd.backBufferDS = null;

    c.bgfx_set_platform_data(&pd);
    _ = c.bgfx_render_frame(-1);
}
