const c = @import("./bridge.zig").c;

pub const EventHandler = struct {
    event: c.SDL_Event,
    should_quit: bool,
    window_width: u32,
    window_height: u32,

    pub fn init(initial_window_width: u32, initial_window_height: u32) EventHandler {
        return EventHandler{
            .event = undefined,
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

        if (self.event.type == c.SDL_QUIT) {
            self.should_quit = true;
        } else if (self.event.type == c.SDL_WINDOWEVENT) {
            self.handleWindowEvent(self.event.window);
        }

        return true;
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
