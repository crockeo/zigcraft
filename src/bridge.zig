pub const c = @cImport({
    @cInclude("bgfx/c99/bgfx.h");
    @cInclude("program.h");
    @cInclude("SDL.h");
    @cInclude("SDL_syswm.h");
});
