const std = @import("std");

const c = @import("./bridge.zig").c;
const shader = @import("./shader.zig");
const texture = @import("./texture.zig");

pub const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,

    tex_index: u32,
    tex_x: f32,
    tex_y: f32,

    const state = struct {
        var layout: c.bgfx_vertex_layout_t = undefined;
        var created: bool = false;
    };

    pub fn init() !void {
        if (Vertex.state.created) {
            return;
        }

        _ = c.bgfx_vertex_layout_begin(
            &Vertex.state.layout,
            c.BGFX_RENDERER_TYPE_NOOP,
        );
        _ = c.bgfx_vertex_layout_add(
            &Vertex.state.layout,
            c.BGFX_ATTRIB_POSITION,
            3,
            c.BGFX_ATTRIB_TYPE_FLOAT,
            false,
            false,
        );
        _ = c.bgfx_vertex_layout_add(
            &Vertex.state.layout,
            c.BGFX_ATTRIB_INDICES,
            4,
            c.BGFX_ATTRIB_TYPE_UINT8,
            false,
            true,
        );
        _ = c.bgfx_vertex_layout_add(
            &Vertex.state.layout,
            c.BGFX_ATTRIB_TEXCOORD0,
            2,
            c.BGFX_ATTRIB_TYPE_FLOAT,
            false,
            false,
        );
        _ = c.bgfx_vertex_layout_end(&Vertex.state.layout);
        Vertex.state.created = true;
    }
};

pub const Cube = struct {
    program: shader.ShaderProgram,
    top_texture: texture.Texture,
    side_texture: texture.Texture,
    bottom_texture: texture.Texture,
    vertices: c.bgfx_vertex_buffer_handle_t,
    indices: c.bgfx_index_buffer_handle_t,

    pub fn init(
        allocator: std.mem.Allocator,
        top_file_path: []const u8,
        side_file_path: []const u8,
        bottom_file_path: []const u8,
        width: f32,
        height: f32,
        depth: f32,
    ) !Cube {
        const program = try shader.ShaderProgram.initFromFiles(
            allocator,
            "shaders/vertex.bin",
            "shaders/fragment.bin",
        );
        const top_texture = try texture.Texture.initFromFile(allocator, 0, top_file_path);
        const side_texture = try texture.Texture.initFromFile(allocator, 1, side_file_path);
        const bottom_texture = try texture.Texture.initFromFile(allocator, 2, bottom_file_path);

        var w = width / 2;
        var h = height / 2;
        var d = depth / 2;

        try Vertex.init();
        const vertices = [24]Vertex{
            // top
            .{.x = -w, .y = h, .z = -d, .tex_index = 0, .tex_x = 0.0, .tex_y = 0.0},
            .{.x = w, .y = h, .z = -d, .tex_index = 0, .tex_x = 1.0, .tex_y = 0.0},
            .{.x = w, .y = h, .z = d, .tex_index = 0, .tex_x = 1.0, .tex_y = 1.0},
            .{.x = -w, .y = h, .z = d, .tex_index = 0, .tex_x = 0.0, .tex_y = 1.0},

            // bottom
            .{.x = -w, .y = -h, .z = -d, .tex_index = 2, .tex_x = 0.0, .tex_y = 0.0},
            .{.x = w, .y = -h, .z = -d, .tex_index = 2, .tex_x = 1.0, .tex_y = 0.0},
            .{.x = w, .y = -h, .z = d, .tex_index = 2, .tex_x = 1.0, .tex_y = 1.0},
            .{.x = -w, .y = -h, .z = d, .tex_index = 2, .tex_x = 0.0, .tex_y = 1.0},

            // back
            .{.x = -w, .y = -h, .z = -d, .tex_index = 1, .tex_x = 0.0, .tex_y = 1.0},
            .{.x = w, .y = -h, .z = -d, .tex_index = 1, .tex_x = 1.0, .tex_y = 1.0},
            .{.x = w, .y = h, .z = -d, .tex_index = 1, .tex_x = 1.0, .tex_y = 0.0},
            .{.x = -w, .y = h, .z = -d, .tex_index = 1, .tex_x = 0.0, .tex_y = 0.0},

            // front
            .{.x = -w, .y = -h, .z = d, .tex_index = 1, .tex_x = 0.0, .tex_y = 1.0},
            .{.x = w, .y = -h, .z = d, .tex_index = 1, .tex_x = 1.0, .tex_y = 1.0},
            .{.x = w, .y = h, .z = d, .tex_index = 1, .tex_x = 1.0, .tex_y = 0.0},
            .{.x = -w, .y = h, .z = d, .tex_index = 1, .tex_x = 0.0, .tex_y = 0.0},

            // left
            .{.x = -w, .y = -h, .z = -d, .tex_index = 1, .tex_x = 0.0, .tex_y = 1.0},
            .{.x = -w, .y = h, .z = -d, .tex_index = 1, .tex_x = 0.0, .tex_y = 0.0},
            .{.x = -w, .y = h, .z = d, .tex_index = 1, .tex_x = 1.0, .tex_y = 0.0},
            .{.x = -w, .y = -h, .z = d, .tex_index = 1, .tex_x = 1.0, .tex_y = 1.0},

            // right
            .{.x = w, .y = -h, .z = -d, .tex_index = 1, .tex_x = 0.0, .tex_y = 1.0},
            .{.x = w, .y = h, .z = -d, .tex_index = 1, .tex_x = 0.0, .tex_y = 0.0},
            .{.x = w, .y = h, .z = d, .tex_index = 1, .tex_x = 1.0, .tex_y = 0.0},
            .{.x = w, .y = -h, .z = d, .tex_index = 1, .tex_x = 1.0, .tex_y = 1.0},
        };
        const vertex_buffer = c.bgfx_create_vertex_buffer(
            c.bgfx_copy(&vertices, vertices.len * @sizeOf(Vertex)),
            &Vertex.state.layout,
            c.BGFX_BUFFER_NONE,
        );

        const indices = [36]u16{
            // top
            0,
            1,
            2,
            0,
            2,
            3,

            // bottom
            6,
            5,
            4,
            7,
            6,
            4,

            // back
            8,
            9,
            10,
            8,
            10,
            11,

            // front
            14,
            13,
            12,
            15,
            14,
            12,

            // left
            16,
            17,
            18,
            16,
            18,
            19,

            // right
            22,
            21,
            20,
            23,
            22,
            20,
        };
        const index_buffer = c.bgfx_create_index_buffer(
            c.bgfx_copy(&indices, indices.len * @sizeOf(u16)),
            c.BGFX_BUFFER_NONE,
        );

        return Cube{
            .program = program,
            .top_texture = top_texture,
            .side_texture = side_texture,
            .bottom_texture = bottom_texture,
            .vertices = vertex_buffer,
            .indices = index_buffer,
        };
    }

    pub fn deinit(self: *const Cube) void {
        self.program.deinit();
        self.top_texture.deinit();
        self.side_texture.deinit();
        self.bottom_texture.deinit();
        c.bgfx_destroy_vertex_buffer(self.vertices);
        c.bgfx_destroy_index_buffer(self.indices);
    }

    pub fn render(self: *const Cube, mtx: [16]f32) void {
        _ = c.bgfx_set_transform(&mtx, 1);
        self.top_texture.use();
        self.side_texture.use();
        self.bottom_texture.use();
        // TODO: change this from hard-coded to a VertexBuffer & IndexBuffer type
        c.bgfx_set_vertex_buffer(0, self.vertices, 0, 24);
        c.bgfx_set_index_buffer(self.indices, 0, 36);
        c.bgfx_set_state(
            c.program_state_default,
            0,
        );
        c.bgfx_submit(0, self.program.handle, 0, c.BGFX_DISCARD_ALL);
    }
};
