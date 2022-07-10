const std = @import("std");

const c = @import("./bridge.zig").c;
const shader = @import("./shader.zig");
const texture = @import("./texture.zig");

const WIDTH: u32 = 640;
const HEIGHT: u32 = 480;

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
        .width = WIDTH,
        .height = HEIGHT,
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
    // ./src/main.zig:10:30: error: missing field: 'resolution'
    // const INIT: c.bgfx_init_t = .{
    .callback = null,
    .allocator = null,
};

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.log.err("Failed to initialize SDL.", .{});
        return error.FailedSDLInit;
    }
    defer c.SDL_Quit();

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

    if (!c.bgfx_init(&INIT)) {
        std.log.err("Failed to initialize BGFX.", .{});
        return error.FailedBGFXInit;
    }
    defer c.bgfx_shutdown();

    c.bgfx_reset(WIDTH, HEIGHT, c.BGFX_RESET_VSYNC, c.BGFX_TEXTURE_FORMAT_COUNT);
    c.bgfx_set_view_rect(
        0,
        0,
        0,
        @intCast(u16, WIDTH),
        @intCast(u16, HEIGHT),
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

    const shader_program = try shader.ShaderProgram.initFromFile(
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

    c.realMain(
        window,
        shader_program.handle,
        WIDTH,
        HEIGHT,
    );
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
