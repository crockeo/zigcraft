const std = @import("std");

pub const c = @cImport({
    @cInclude("program.h");
});

pub fn main() !void {
    c.realMain();
}
