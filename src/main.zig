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

    c.realMain();
}
