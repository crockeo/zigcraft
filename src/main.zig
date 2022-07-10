const std = @import("std");
const zlm = @import("zlm");

const c = @import("./bridge.zig").c;
const cube = @import("./cube.zig");
const EventHandler = @import("./events.zig").EventHandler;
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
    const renderer = try Renderer.init(gpa.allocator());
    defer renderer.deinit();

    const shader_program = try shader.ShaderProgram.initFromFiles(
        gpa.allocator(),
        "shaders/vertex.bin",
        "shaders/fragment.bin",
    );
    defer shader_program.deinit();

    const beginning = std.time.nanoTimestamp();
    var event_handler: EventHandler = EventHandler.init(INIT.resolution.width, INIT.resolution.height);
    var timer = try std.time.Timer.start();
    var pos = zlm.Vec3.new(0, 0, 0);

    var rotX: f32 = 0.0;
    var rotY: f32 = 0.0;

    while (!event_handler.should_quit) {
        const dt = timer.lap();
        const dtf = @intToFloat(f32, dt) / @intToFloat(f32, std.time.ns_per_s);

        // Note that rotX and rotY
        // come from mouseRot.dy and mouseRot.dx
        // because of 2D movement vs. rotational axes.
        const mouseRot = event_handler.input.getMouseRot();
        rotY -= mouseRot.x * std.math.pi;
        rotX += mouseRot.y * std.math.pi;
        if (rotX < -std.math.pi / 3.0) {
            rotX = -std.math.pi / 3.0;
        }
        if (rotX > std.math.pi / 3.0) {
            rotX = std.math.pi / 3.0;
        }

        const rot = zlm.Mat4.createAngleAxis(
            zlm.Vec3.unitX,
            rotX,
        ).mul(zlm.Mat4.createAngleAxis(
            zlm.Vec3.unitY,
            rotY,
        ));

        const forward4 = zlm.Vec4.new(0, 0, -1, 0).transform(rot);
        const forward = zlm.vec3(forward4.x, forward4.y, forward4.z);

        const left4 = zlm.Vec4.unitX.transform(rot);
        const left = zlm.vec3(left4.x, left4.y, left4.z);

        if (event_handler.input.isPressed(c.SDL_SCANCODE_W)) {
            pos = pos.add(forward.scale(dtf * 5));
        }
        if (event_handler.input.isPressed(c.SDL_SCANCODE_S)) {
            pos = pos.add(forward.scale(-dtf * 5));
        }

        if (event_handler.input.isPressed(c.SDL_SCANCODE_A)) {
            pos = pos.add(left.scale(dtf * 5));
        }
        if (event_handler.input.isPressed(c.SDL_SCANCODE_D)) {
            pos = pos.add(left.scale(-dtf * 5));
        }

        while (event_handler.handleEvent()) {}
        renderer.render(
            beginning,
            event_handler.window_width,
            event_handler.window_height,
            pos,
            rot,
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

    pub fn render(
        self: *const Renderer,
        beginning: i128,
        width: u32,
        height: u32,
        pos: zlm.Vec3,
        rot: zlm.Mat4,
    ) void {
        const lookAt4 = zlm.Vec4.unitZ.transform(rot);
        const lookAt = pos.add(zlm.Vec3.new(lookAt4.x, lookAt4.y, lookAt4.z));


        const view = zlm.Mat4.createLookAt(
            lookAt,
            pos,
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
        const now = std.time.nanoTimestamp();
        const time_passed = @intToFloat(f32, now - beginning) / @intToFloat(f32, std.time.ns_per_s);
        var i: usize = 0;
        while (i < cubes.len) {
            var mtx = zlm.Mat4.createAngleAxis(
                zlm.Vec3.unitX,
                time_passed * 0.7 + @intToFloat(f32, i),
            ).mul(zlm.Mat4.createAngleAxis(
                zlm.Vec3.unitY,
                time_passed + @intToFloat(f32, i),
            )).mul(zlm.Mat4.createTranslationXYZ(
                (@intToFloat(f32, i) - 1) * 5.0,
                0,
                0,
            ));
            cubes[i].render(mtx.fields);
            i += 1;
        }


        _ = c.bgfx_frame(false);
    }
};
