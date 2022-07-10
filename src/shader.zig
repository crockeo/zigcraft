const std = @import("std");

const c = @import("./bridge.zig").c;

pub const Shader = struct {
    handle: c.bgfx_shader_handle_t,

    pub fn init(contents: []const u8) !Shader {
        const copy_contents = c.bgfx_copy(
            @ptrCast(*const anyopaque, contents),
            @intCast(u32, contents.len),
        ) orelse return error.FailedCopy;

        const handle = c.bgfx_create_shader(copy_contents);
        if (handle.idx == 65535) {
            return error.FailedCreateShader;
        }
        return Shader{
            .handle = handle,
        };
    }

    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8) !Shader {
        const cwd = std.fs.cwd();

        var file = try cwd.openFile(path, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 65536);
        defer allocator.free(contents);

        return try Shader.init(contents);
    }

    pub fn deinit(self: *const Shader) void {
        c.bgfx_destroy_shader(self.handle);
    }
};

pub const ShaderProgram = struct {
    handle: c.bgfx_program_handle_t,
    vertex_shader: Shader,
    fragment_shader: Shader,

    pub fn init(vertex_shader: Shader, fragment_shader: Shader) !ShaderProgram {
        return ShaderProgram{
            .handle = c.bgfx_create_program(vertex_shader.handle, fragment_shader.handle, false),
            .vertex_shader = vertex_shader,
            .fragment_shader = fragment_shader,
        };
    }

    pub fn initFromFiles(allocator: std.mem.Allocator, vertex_path: []const u8, fragment_path: []const u8) !ShaderProgram {
        const vertex_shader = try Shader.initFromFile(allocator, vertex_path);
        const fragment_shader = try Shader.initFromFile(allocator, fragment_path);
        return ShaderProgram.init(vertex_shader, fragment_shader);
    }

    pub fn deinit(self: *const ShaderProgram) void {
        c.bgfx_destroy_program(self.handle);
        self.vertex_shader.deinit();
        self.fragment_shader.deinit();
    }
};
