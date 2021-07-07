#include <chrono>
#include <fstream>
#include <iostream>
#include <optional>
#include <streambuf>
#include <string>
#include <utility>
#include <vector>

#include "SDL2/SDL.h"
#include "SDL2/SDL_syswm.h"
#include "bgfx/bgfx.h"
#include "bgfx/platform.h"
#include "bx/math.h"
#include "bx/thread.h"

#include "guard.hpp"

using namespace cppcraft;

int WIDTH = 640;
int HEIGHT = 480;

std::string loadFile(std::string file_path) {
  std::ifstream file(file_path);
  std::string str;

  file.seekg(0, std::ios::end);
  int64_t pos = file.tellg();
  if (pos < 0) {
    throw std::runtime_error("failed to open " + file_path);
  }
  str.reserve(file.tellg());
  file.seekg(0, std::ios::beg);

  str.assign(std::istreambuf_iterator<char>(file),
             std::istreambuf_iterator<char>());
  return str;
}

bgfx::ShaderHandle loadShader(std::string file_path) {
  auto contents = loadFile(file_path);
  auto handle = bgfx::alloc(contents.size());
  bgfx::copy(contents.c_str(), contents.size() + 1);

  auto shader = bgfx::createShader(handle);
  // TODO: figure out why this crashes
  // bgfx::setName(shader, file_path.c_str());
  return shader;
}

bgfx::ProgramHandle loadProgram(std::string vertex_file_path,
                                std::string fragment_file_path) {
  auto vertex_shader = loadShader(vertex_file_path);
  auto fragment_shader = loadShader(fragment_file_path);
  return bgfx::createProgram(vertex_shader, fragment_shader, true);
}

struct PosColorVertex {
  float m_x;
  float m_y;
  float m_z;
  uint32_t m_abgr;

  static void init() {
    if (!PosColorVertex::ms_layout_initialized) {
      PosColorVertex::ms_layout.begin()
          .add(bgfx::Attrib::Position, 3, bgfx::AttribType::Float)
          .add(bgfx::Attrib::Color0, 4, bgfx::AttribType::Uint8, true)
          .end();
    }
    PosColorVertex::ms_layout_initialized = true;
  }

  static bool ms_layout_initialized;
  static bgfx::VertexLayout ms_layout;
};

// ms_layout_initialized to false at first
// but it can't be done so in the class because C++
bool PosColorVertex::ms_layout_initialized = false;
bgfx::VertexLayout PosColorVertex::ms_layout;

static PosColorVertex vertex_data[] = {{0.5f, 0.5f, 0.0f, 0xff0000ff},
                                       {0.5f, -0.5f, 0.0f, 0xff0000ff},
                                       {-0.5f, -0.5f, 0.0f, 0xff00ff00},
                                       {-0.5f, 0.5f, 0.0f, 0xff00ff00}};

static uint16_t index_data[] = {
    0, 1, 3, 1, 2, 3,
};

bgfx::PlatformData getPlatformData(SDL_Window *window) {
  SDL_SysWMinfo wmi;
  SDL_VERSION(&wmi.version);
  if (!SDL_GetWindowWMInfo(window, &wmi)) {
    throw std::runtime_error("failed to fetch window manager info");
  }

  bgfx::PlatformData pd;
  // TODO: do other platforms and not just macOS
  pd.ndt = nullptr;
  pd.nwh = wmi.info.cocoa.window;
  pd.context = nullptr;
  pd.backBuffer = nullptr;
  pd.backBufferDS = nullptr;

  return pd;
}

class Renderer {
public:
  Renderer() {
    _program = loadProgram("shaders/vertex.bin", "shaders/fragment.bin");

    PosColorVertex::init();
    _vertex_buffer = bgfx::createVertexBuffer(
        bgfx::makeRef(vertex_data, sizeof(vertex_data)),
        PosColorVertex::ms_layout);

    _index_buffer =
        bgfx::createIndexBuffer(bgfx::makeRef(index_data, sizeof(index_data)));
  }

  ~Renderer() {
    bgfx::destroy(_vertex_buffer);
    bgfx::destroy(_index_buffer);
  }

  void render(std::chrono::time_point<std::chrono::steady_clock> start) {
    const bx::Vec3 at = {0.0f, 0.0f, 0.0f};
    const bx::Vec3 eye = {0.0f, 0.0f, 10.0f};
    float view[16];
    bx::mtxLookAt(view, eye, at);

    float proj[16];
    bx::mtxProj(proj, 60.0f, float(WIDTH) / float(HEIGHT), 0.1f, 100.0f,
                bgfx::getCaps()->homogeneousDepth);
    bgfx::setViewTransform(0, view, proj);

    bgfx::setViewRect(0, 0, 0, WIDTH, HEIGHT);
    bgfx::touch(0);

    float mtx[16];
    bx::mtxRotateY(mtx, 0.0f);

    auto now = std::chrono::steady_clock::now();
    float time_sec =
        std::chrono::duration_cast<std::chrono::milliseconds>(now - start)
            .count() /
        1000.f;
    mtx[12] = bx::sin(time_sec);
    mtx[13] = bx::cos(time_sec);
    mtx[14] = 3 * bx::sin(time_sec / 3.0f);

    bgfx::setTransform(mtx);
    bgfx::setVertexBuffer(0, _vertex_buffer);
    bgfx::setIndexBuffer(_index_buffer);
    bgfx::setState(BGFX_STATE_DEFAULT);
    bgfx::submit(0, _program);
    bgfx::frame();
  }

private:
  bgfx::ProgramHandle _program;
  bgfx::VertexBufferHandle _vertex_buffer;
  bgfx::IndexBufferHandle _index_buffer;
};

int main(int argc, char *args[]) {
  Guard<int> sdl_init_guard(SDL_Init(SDL_INIT_VIDEO), [](int result) {
    if (!result) {
      SDL_Quit();
    }
  });
  if (*sdl_init_guard) {
    throw std::runtime_error("failed to init SDL");
  }

  Guard<SDL_Window *> sdl_window_guard(
      SDL_CreateWindow("hello world", SDL_WINDOWPOS_UNDEFINED,
                       SDL_WINDOWPOS_UNDEFINED, WIDTH, HEIGHT,
                       SDL_WINDOW_RESIZABLE | SDL_WINDOW_SHOWN),
      [](SDL_Window *window) {
        if (window != nullptr) {
          SDL_DestroyWindow(window);
        }
      });
  if (*sdl_window_guard == nullptr) {
    throw std::runtime_error("failed to create SDL window");
  }

  auto pd = getPlatformData(*sdl_window_guard);
  bgfx::setPlatformData(pd);
  bgfx::renderFrame();

  Guard<bool> bgfx_guard(bgfx::init(), [](bool success) {
    if (success) {
      bgfx::shutdown();
    }
  });
  if (!*bgfx_guard) {
    throw std::runtime_error("failed to init BGFX");
  }

  Renderer renderer;

  bgfx::reset(WIDTH, HEIGHT, BGFX_RESET_VSYNC);
  bgfx::setDebug(BGFX_DEBUG_TEXT | BGFX_DEBUG_STATS);
  bgfx::setViewRect(0, 0, 0, uint16_t(WIDTH), uint16_t(HEIGHT));
  bgfx::setViewClear(0, BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH, 0x443355FF, 1.0f,
                     0);
  bgfx::touch(0);

  bool quit = false;
  SDL_Event current_event;
  auto begin = std::chrono::steady_clock::now();
  while (!quit) {
    auto start = std::chrono::steady_clock::now();

    while (SDL_PollEvent(&current_event) != 0) {
      if (current_event.type == SDL_QUIT) {
        quit = true;
      }

      if (current_event.type == SDL_WINDOWEVENT) {
        auto window_event = current_event.window;
        if (window_event.event == SDL_WINDOWEVENT_RESIZED) {
          WIDTH = window_event.data1;
          HEIGHT = window_event.data2;
          bgfx::reset(WIDTH, HEIGHT, BGFX_RESET_VSYNC);
          bgfx::setViewRect(0, 0, 0, uint16_t(WIDTH), uint16_t(HEIGHT));
        }
      }
    }
    renderer.render(begin);

    auto end = std::chrono::steady_clock::now();
    auto time_spent =
        std::chrono::duration_cast<std::chrono::milliseconds>(end - start)
            .count();
    // TODO: move this out of the main loop / separate rendering from action
    if (time_spent < 16) {
      SDL_Delay(16 - time_spent);
    }
  }

  return 0;
}
