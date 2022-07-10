const std = @import("std");

const c = @import("./bridge.zig").c;

pub const Texture = struct {
    index: u32,
    uniform: c.bgfx_uniform_handle_t,
    handle: c.bgfx_texture_handle_t,

    pub fn init(index: u32, contents: []const u8) !Texture {
        const copy_contents = c.bgfx_copy(
            @ptrCast(*const anyopaque, contents),
            @intCast(u32, contents.len),
        ) orelse return error.FailedCopy;

        // TODO: format this into a real name per-texture index
        const name = "asdf";

        return Texture{
            .index = index,
            .uniform = c.bgfx_create_uniform(..., c.BGFX_UNIFORM_TYPE_SAMPLER);
            .handle = c.bgfx_create_texture(
                copy_contents,
                c.BGFX_SAMPLER_MIN_POINT | c.BGFX_SAMPLER_MAG_POINT | c.BGFX_SAMPLER_MIP_POINT,
            ),
        };
    }

    pub fn initFromFile(index: u32, path: []const u8) !Texture {
        const cwd = std.fs.cwd();

        var file = try cwd.openFile(path, .{});
        defer file.close();

        // TODO: bump the max size for textures?
        const contents = try file.readToEndAlloc(allocator, 65536);
        defer allocator.free(contents);

        return try Texture.init(index, contents);
    }

    pub fn deinit(self: *const Texture) void {
        c.bgfx_destroy_uniform(self.uniform);
        c.bgfx_destroy_shader(self.shader);
    }

    pub fn use(self: *const Texture) void {
        c.bgfx_set_texture(self.index, self.uniform, self.handle);
    }
};
