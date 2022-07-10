const std = @import("std");
const zlm = @import("zlm");

const c = @import("./bridge.zig").c;
const cube = @import("./cube.zig");
const shader = @import("./shader.zig");
const texture = @import("./texture.zig");

const INIT: c.bgfx_init_t = .{
    .type = c.BGFX_RENDERER_TYPE_COUNT,
    .vendorId = c.BGFX_PCI_ID_NONE,
    .deviceId = 0,
    .capabilities = std.math.maxInt(u64),
    .debug = true,
    .profile = false,
    .platformData = .{
        .ndt = null,
        .nwh = null,
        .context = null,
        .backBuffer = null,
        .backBufferDS = null,
    },
    .resolution = .{
        .format = c.BGFX_TEXTURE_FORMAT_COUNT,
        .width = 640,
        .height = 480,
        .reset = c.BGFX_RESET_VSYNC,
        .numBackBuffers = 0,
        .maxFrameLatency = 0,
    },
    .limits = .{
        .maxEncoders = std.math.maxInt(u16),
        .minResourceCbSize = 0,
        .transientVbSize = std.math.maxInt(u32),
        .transientIbSize = std.math.maxInt(u32),
    },
    .callback = null,
    .allocator = null,
};

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.log.err("Failed to initialize SDL.", .{});
        return error.FailedSDLInit;
    }
    defer c.SDL_Quit();

    var width: u32 = INIT.resolution.width;
    var height: u32 = INIT.resolution.height;
    const window = c.SDL_CreateWindow(
        "hello world",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        @intCast(c_int, width),
        @intCast(c_int, height),
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_SHOWN,
    ) orelse {
        std.log.err("Failed to initialize SDL window.", .{});
        return error.FailedSDLWindowInit;
    };
    defer c.SDL_DestroyWindow(window);

    try registerPlatformData(window);

    if (!c.bgfx_init(&INIT)) {
        std.log.err("Failed to initialize BGFX.", .{});
        return error.FailedBGFXInit;
    }
    defer c.bgfx_shutdown();

    c.bgfx_reset(width, height, c.BGFX_RESET_VSYNC, c.BGFX_TEXTURE_FORMAT_COUNT);
    c.bgfx_set_view_rect(
        0,
        0,
        0,
        @intCast(u16, width),
        @intCast(u16, height),
    );
    c.bgfx_set_view_clear(
        0,
        c.BGFX_CLEAR_COLOR | c.BGFX_CLEAR_DEPTH,
        0x443355FF,
        1.0,
        0,
    );
    c.bgfx_touch(0);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const renderer = try Renderer.init(gpa.allocator());
    defer renderer.deinit();

    const shader_program = try shader.ShaderProgram.initFromFiles(
        gpa.allocator(),
        "shaders/vertex.bin",
        "shaders/fragment.bin",
    );
    defer shader_program.deinit();

    const cobblestone = try texture.Texture.initFromFile(
        gpa.allocator(),
        0,
        "res/cobblestone.ktx",
    );
    defer cobblestone.deinit();

    var quit: bool = false;
    var current_event: c.SDL_Event = undefined;

    var timer = try std.time.Timer.start();
    while (!quit) {
        timer.reset();

        while (c.SDL_PollEvent(&current_event) != 0) {
            if (current_event.type == c.SDL_QUIT) {
                quit = true;
            }

            // TODO: handle window resizing
            // if (current_event.type == SDL_WINDOWEVENT) {
            //     auto window_event = current_event.window;
            //     if (window_event.event == SDL_WINDOWEVENT_RESIZED) {
            //         width = window_event.data1;
            //         height = window_event.data2;
            //         bgfx::reset(width, height, BGFX_RESET_VSYNC);
            //         bgfx::setViewRect(0, 0, 0, uint16_t(width), uint16_t(height));
            //     }
            // }
        }
        renderer.render(width, height);

        const time_spent = timer.lap();
        if (time_spent < 16 * std.time.ns_per_ms) {
            std.time.sleep(16 * std.time.ns_per_ms - time_spent);
        }
    }
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

const Renderer = struct {
    grass: cube.Cube,
    cobblestone: cube.Cube,
    dirt: cube.Cube,

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        return Renderer{
            .grass = try cube.Cube.init(
                allocator,
                "res/grass_top.ktx",
                "res/grass_side.ktx",
                "res/dirt.ktx",
                2.0,
                2.0,
                2.0,
            ),
            .cobblestone = try cube.Cube.init(
                allocator,
                "res/cobblestone.ktx",
                "res/cobblestone.ktx",
                "res/cobblestone.ktx",
                2.0,
                2.0,
                2.0,
            ),
            .dirt = try cube.Cube.init(
                allocator,
                "res/dirt.ktx",
                "res/dirt.ktx",
                "res/dirt.ktx",
                2.0,
                2.0,
                2.0,
            ),
        };
    }

    pub fn deinit(self: *const Renderer) void {
        self.grass.deinit();
        self.cobblestone.deinit();
        self.dirt.deinit();
    }

    pub fn render(self: *const Renderer, width: u32, height: u32) void {
        const view = zlm.Mat4.createLookAt(
            zlm.Vec3.new(0, 0, 5),
            zlm.Vec3.zero,
            zlm.Vec3.unitY,
        );
        const proj = zlm.Mat4.createPerspective(
            90.0,
            @intToFloat(f32, width) / @intToFloat(f32, height),
            0.1,
            100.0,
        );

        c.bgfx_set_view_transform(0, &view.fields, &proj.fields);
        c.bgfx_set_view_rect(0, 0, 0, @intCast(u16, width), @intCast(u16, height));
        c.bgfx_touch(0);

        const cubes = [_]*const cube.Cube{
            &self.grass,
            &self.cobblestone,
            &self.dirt,
        };
        var i: usize = 0;
        while (i < cubes.len) {
            // TODO: make the cubes rotate
            // for reference...
            //
            // getting the time:
            //
            //   auto now = std::chrono::steady_clock::now();
            //   float time_sec =
            //       std::chrono::duration_cast<std::chrono::milliseconds>(now - start)
            //           .count() /
            //       1000.f;
            //
            // and then using it:
            //
            //   float mtx[16];
            //   bx::mtxRotateXY(mtx, time_sec * 0.7 + i, time_sec + i);
            //   mtx[12] = ((float)i - 1) * 3.0f;
            //   mtx[13] = 0.0f;
            //   mtx[14] = 0.0f;
            var mtx = [16]f32{
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            };
            mtx[12] = (@intToFloat(f32, i) - 1) * 3.0;
            mtx[13] = 0;
            mtx[14] = 0;
            cubes[i].render(mtx);
            i += 1;
        }


        _ = c.bgfx_frame(false);
    }
};
