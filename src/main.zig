const std = @import("std");

pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    std.log.debug("hello world!", .{});
}

pub const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("SDL_syswm.h");
});
