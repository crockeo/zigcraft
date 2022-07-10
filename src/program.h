#pragma once

#include "bgfx/c99/bgfx.h"

#ifdef __cplusplus
extern "C" {
#endif

// horrible hack to get around zig not correctly parsing macros
static uint64_t program_state_default = BGFX_STATE_DEFAULT;

#ifdef __cplusplus
}
#endif
