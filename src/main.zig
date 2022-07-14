const std = @import("std");
const zlm = @import("zlm");

const c = @import("./bridge.zig").c;
const cube = @import("./cube.zig");
const EventHandler = @import("./events.zig").EventHandler;
const texture = @import("./texture.zig");
const World = @import("./world.zig").World;

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

    const window = c.SDL_CreateWindow(
        "hello world",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        @intCast(c_int, INIT.resolution.width),
        @intCast(c_int, INIT.resolution.height),
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_SHOWN,
    ) orelse {
        std.log.err("Failed to initialize SDL window.", .{});
        return error.FailedSDLWindowInit;
    };
    defer c.SDL_DestroyWindow(window);

    if (c.SDL_SetRelativeMouseMode(c.SDL_TRUE) != 0) {
        std.log.err("Failed to capture mouse.", .{});
        return error.FailedSDLCaptureMouse;
    }

    // TODO: fetch display mode (and update?) based on target display
    var display_mode: c.SDL_DisplayMode = undefined;
    if (c.SDL_GetDisplayMode(0, 0, &display_mode) != 0) {
        std.log.err("Failed to get DisplayMode", .{});
        return error.FailedSDLDisplayMode;
    }
    const target_ns_per_frame = std.time.ns_per_s / @intCast(usize, display_mode.refresh_rate) / 2;

    try registerPlatformData(window);

    if (!c.bgfx_init(&INIT)) {
        std.log.err("Failed to initialize BGFX.", .{});
        return error.FailedBGFXInit;
    }
    defer c.bgfx_shutdown();

    c.bgfx_reset(INIT.resolution.width, INIT.resolution.height, c.BGFX_RESET_VSYNC, c.BGFX_TEXTURE_FORMAT_COUNT);
    c.bgfx_set_view_rect(
        0,
        0,
        0,
        @intCast(u16, INIT.resolution.width),
        @intCast(u16, INIT.resolution.height),
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
    var world = try World.init(gpa.allocator());
    defer world.deinit();

    const beginning = std.time.nanoTimestamp();
    var event_handler: EventHandler = EventHandler.init(INIT.resolution.width, INIT.resolution.height);
    var timer = try std.time.Timer.start();
    while (!event_handler.should_quit) {
        const dt = timer.lap();
        const dtf = @intToFloat(f32, dt) / @intToFloat(f32, std.time.ns_per_s);

        while (event_handler.handleEvent()) {}

        try world.update(&event_handler.input, dtf);
        try world.render(
            beginning,
            event_handler.window_width,
            event_handler.window_height,
        );

        if (dt < target_ns_per_frame) {
            std.time.sleep(target_ns_per_frame - dt);
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
