const std = @import("std");

const c = @import("./bridge.zig").c;

pub const Texture = struct {
    allocator: std.mem.Allocator,
    index: u8,
    name: []const u8,
    uniform: c.bgfx_uniform_handle_t,
    handle: c.bgfx_texture_handle_t,

    pub fn init(allocator: std.mem.Allocator, index: u8, contents: []const u8) !Texture {
        const copy_contents = c.bgfx_copy(
            @ptrCast(*const anyopaque, contents),
            @intCast(u32, contents.len),
        ) orelse return error.FailedCopy;

        var nameArr = std.ArrayList(u8).init(allocator);
        try nameArr.writer().print("s_texColor{d}", .{index});
        try nameArr.append(0);
        var name = nameArr.toOwnedSlice();

        return Texture{
            .allocator = allocator,
            .index = index,
            .name = name,
            .uniform = c.bgfx_create_uniform(@ptrCast([*c]u8, name), c.BGFX_UNIFORM_TYPE_SAMPLER, 1),
            .handle = c.bgfx_create_texture(
                copy_contents,
                c.BGFX_SAMPLER_MIN_POINT | c.BGFX_SAMPLER_MAG_POINT | c.BGFX_SAMPLER_MIP_POINT,
                0,
                null,
            ),
        };
    }

    pub fn initFromFile(allocator: std.mem.Allocator, index: u8, path: []const u8) !Texture {
        const cwd = std.fs.cwd();

        var file = try cwd.openFile(path, .{});
        defer file.close();

        // TODO: bump the max size for textures?
        const contents = try file.readToEndAlloc(allocator, 65536);
        defer allocator.free(contents);

        return try Texture.init(allocator, index, contents);
    }


    pub fn deinit(self: *const Texture) void {
        c.bgfx_destroy_uniform(self.uniform);
        self.allocator.free(self.name);
        c.bgfx_destroy_texture(self.handle);
    }

    pub fn use(self: *const Texture) void {
        c.bgfx_set_texture(self.index, self.uniform, self.handle, std.math.maxInt(u32));
    }
};
