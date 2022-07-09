const std = @import("std");

pub const c = @cImport({
    @cInclude("program.h");
    @cInclude("SDL.h");
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
    );
    if (window == null) {
        std.log.err("Failed to initialize SDL window.", .{});
        return error.FailedSDLWindowInit;
    }
    defer c.SDL_DestroyWindow(window);

    c.realMain(window, WIDTH, HEIGHT);
}
