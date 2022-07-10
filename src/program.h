#pragma once

#include "bgfx/c99/bgfx.h"
#include "SDL.h"

#ifdef __cplusplus
extern "C" {
#endif

// horrible hack to get around zig not correctly parsing macros
static uint64_t program_state_default = BGFX_STATE_DEFAULT;

void realMain(
  SDL_Window *window,
  bgfx_program_handle_t shader,
  uint32_t width,
  uint32_t height
);

#ifdef __cplusplus
}
#endif
