const std = @import("std");
const zlm = @import("zlm");

const c = @import("./bridge.zig").c;

pub const EventHandler = struct {
    event: c.SDL_Event,
    input: InputState,
    should_quit: bool,
    window_width: u32,
    window_height: u32,

    pub fn init(initial_window_width: u32, initial_window_height: u32) EventHandler {
        return EventHandler{
            .event = undefined,
            .input = InputState.init(),
            .should_quit = false,
            .window_width = initial_window_width,
            .window_height = initial_window_height,
        };
    }

    pub fn handleEvent(self: *EventHandler) bool {
        const has_event = c.SDL_PollEvent(&self.event);
        if (has_event == 0) {
            return false;
        }

        if (self.event.type == c.SDL_KEYDOWN or self.event.type == c.SDL_KEYUP) {
            self.handleKeyboardEvent(self.event.key);
        } else if (self.event.type == c.SDL_MOUSEMOTION) {
            self.handleMouseMotion(self.event.motion);
        } else if (self.event.type == c.SDL_QUIT) {
            self.should_quit = true;
        } else if (self.event.type == c.SDL_WINDOWEVENT) {
            self.handleWindowEvent(self.event.window);
        }

        return true;
    }

    fn handleKeyboardEvent(self: *EventHandler, event: c.SDL_KeyboardEvent) void {
        self.input.setPressed(event.keysym.scancode, event.state == c.SDL_PRESSED);
    }

    fn handleMouseMotion(self: *EventHandler, event: c.SDL_MouseMotionEvent) void {
        self.input.moveMouse(
            self.window_width,
            self.window_height,
            event.xrel,
            event.yrel,
        );
    }

    fn handleWindowEvent(self: *EventHandler, event: c.SDL_WindowEvent) void {
        if (event.event == c.SDL_WINDOWEVENT_RESIZED) {
            self.window_width = @intCast(u32, event.data1);
            self.window_width = @intCast(u32, event.data2);
            c.bgfx_reset(
                self.window_width,
                self.window_height,
                c.BGFX_RESET_VSYNC,
                c.BGFX_TEXTURE_FORMAT_COUNT,
            );
        }
    }
};

pub const InputState = struct {
    state: [512]bool,
    mouse_dx: f32,
    mouse_dy: f32,

    pub fn init() InputState {
        return InputState{
            .state = std.mem.zeroes([512]bool),
            .mouse_dx = 0.0,
            .mouse_dy = 0.0,
        };
    }

    pub fn moveMouse(
        self: *InputState,
        window_width: u32,
        window_height: u32,
        xrel: i32,
        yrel: i32,
    ) void {
        self.mouse_dx = @intToFloat(f32, xrel) / @intToFloat(f32, window_width);
        self.mouse_dy = @intToFloat(f32, yrel) / @intToFloat(f32, window_height);
    }

    pub fn getMouseRot(self: *InputState) zlm.Vec2 {
        const mouse_dx = self.mouse_dx;
        const mouse_dy = self.mouse_dy;
        self.mouse_dx = 0.0;
        self.mouse_dy = 0.0;
        return zlm.Vec2.new(mouse_dx, mouse_dy);
    }

    // TODO: optimize by turning this into a bitmask (if it doesn't compiler optimize already)
    pub fn setPressed(self: *InputState, scancode: c.SDL_Scancode, pressed: bool) void {
        self.state[scancode] = pressed;
    }

    pub fn isPressed(self: *const InputState, scancode: c.SDL_Scancode) bool {
        return self.state[scancode];
    }
};
