#include <chrono>
#include <fstream>
#include <iostream>
#include <memory>
#include <optional>
#include <streambuf>
#include <string>
#include <utility>
#include <vector>

#include "bgfx/bgfx.h"
#include "bgfx/platform.h"
#include "bx/math.h"
#include "bx/thread.h"
#include "SDL2/SDL.h"
#include "SDL2/SDL_syswm.h"

#include "guard.hpp"

using namespace cppcraft;

int WIDTH = 640;
int HEIGHT = 480;

// returns a ptr to the underlying data
// because we expect to load large binary files
// (e.g. models and textures)
// and don't want to pass it around on the stack
std::unique_ptr<std::vector<uint8_t>> loadBinaryFile(std::string file_path) {
  std::ifstream file(file_path, std::ios::binary);
  if (!file.good()) {
    // TODO: also change this to log the file_path when i get this all working
    throw std::runtime_error("cannot read file");
  }
  // TODO: figure out how to set -std=c++20 in bazel
  // so that i can use make_unique for this
  std::unique_ptr<std::vector<uint8_t>> contents(
    new std::vector<uint8_t>(std::istreambuf_iterator<char>(file), {})
  );
  return contents;
}

void loadBinaryFileMem_Release(void* _, void* raw_shared_contents) {
  auto shared_contents = static_cast<std::shared_ptr<std::vector<uint8_t>>*>(raw_shared_contents);
  delete shared_contents;
}

const bgfx::Memory* loadBinaryFileMem(std::string file_path) {
  auto contents = loadBinaryFile(file_path);
  auto shared_contents = new std::shared_ptr<std::vector<uint8_t>>(std::move(contents));
  auto handle = bgfx::makeRef(
    &(**shared_contents)[0],
    (*shared_contents)->size(),
    &loadBinaryFileMem_Release,
    shared_contents
  );
  return handle;
}

bgfx::ShaderHandle loadShader(std::string file_path) {
  return bgfx::createShader(loadBinaryFileMem(file_path));
}

bgfx::ProgramHandle loadProgram(std::string vertex_file_path,
                                std::string fragment_file_path) {
  auto vertex_shader = loadShader(vertex_file_path);
  auto fragment_shader = loadShader(fragment_file_path);
  return bgfx::createProgram(vertex_shader, fragment_shader, true);
}

bgfx::TextureHandle loadTexture(std::string file_path) {
  auto handle = loadBinaryFileMem(file_path);
  return bgfx::createTexture(handle, BGFX_SAMPLER_MIN_POINT | BGFX_SAMPLER_MAG_POINT | BGFX_SAMPLER_MIP_POINT);
}

class Texture {
public:
  Texture(std::string file_path) {
    _uniform = bgfx::createUniform("s_texColor", bgfx::UniformType::Sampler);
    _handle = loadTexture(file_path);
  }

  ~Texture() {
    bgfx::destroy(_uniform);
    bgfx::destroy(_handle);
  }

  Texture(const Texture&) = delete;
  Texture& operator=(const Texture&) = delete;

  // TODO: come up with a better name
  // that documents what this actually does
  void use() {
    bgfx::setTexture(0, _uniform, _handle);
  }

private:
  bgfx::UniformHandle _uniform;
  bgfx::TextureHandle _handle;
};

// TODO: think more about loading a cube
// that has the same texture on multiple sides
// how do we want to do the loading? the destroying? etc.
class Cube {
public:
  // TODO: think about a compressed index format for this
  struct Vertex {
    float x;
    float y;
    float z;

    float tex_x;
    float tex_y;

    static void init() {
      if (!initialized) {
        layout.begin()
          .add(bgfx::Attrib::Position, 3, bgfx::AttribType::Float)
          .add(bgfx::Attrib::TexCoord0, 2, bgfx::AttribType::Float)
          .end();
        initialized = true;
      }
    }

    static bool initialized;
    static bgfx::VertexLayout layout;
  };

  Cube(std::string texture_file_path,
       float width,
       float height,
       float depth)
    : _texture(texture_file_path) {
    width /= 2;
    height /= 2;
    depth /= 2;

    // reduce the total # of vertices
    // to compress data
    Vertex vertices[] = {
      {-1.0f, 1.0f, 1.0f, 0.0f, 0.0f},   {1.0f, 1.0f, 1.0f, 1.0f, 0.0f},
      {-1.0f, -1.0f, 1.0f, 0.0f, 1.0f},  {1.0f, -1.0f, 1.0f, 1.0f, 1.0f},
      {-1.0f, 1.0f, -1.0f, 0.0f, 0.0f},  {1.0f, 1.0f, -1.0f, 0.0f, 0.0f},
      {-1.0f, -1.0f, -1.0f, 0.0f, 0.0f}, {1.0f, -1.0f, -1.0f, 0.0f, 0.0f},
    };

    uint16_t indices[] = {
        0, 1, 2, 1, 3, 2, 4, 6, 5, 5, 6, 7, 0, 2, 4, 4, 2, 6,
        1, 5, 3, 5, 7, 3, 0, 4, 1, 4, 5, 1, 2, 3, 6, 6, 3, 7,
    };

    Vertex::init();
    _program = loadProgram("shaders/vertex.bin", "shaders/fragment.bin");
    _vertices = bgfx::createVertexBuffer(
        bgfx::copy(vertices, sizeof(vertices)),
        Vertex::layout);
    _indices =
        bgfx::createIndexBuffer(bgfx::copy(indices, sizeof(indices)));
  }

  ~Cube() {
    bgfx::destroy(_program);
    bgfx::destroy(_vertices);
    bgfx::destroy(_indices);
  }

  Cube(const Cube&) = delete;
  Cube& operator=(const Cube&) = delete;

  void render(float mtx[16]) {
    bgfx::setTransform(mtx);
    _texture.use();
    bgfx::setVertexBuffer(0, _vertices);
    bgfx::setIndexBuffer(_indices);
    bgfx::setState(BGFX_STATE_DEFAULT);
    bgfx::submit(0, _program);
    bgfx::frame();
  }

private:
  bgfx::ProgramHandle _program;
  bgfx::VertexBufferHandle _vertices;
  bgfx::IndexBufferHandle _indices;

  Texture _texture;
};

bool Cube::Vertex::initialized = false;
bgfx::VertexLayout Cube::Vertex::layout;

bgfx::PlatformData getPlatformData(SDL_Window *window) {
  SDL_SysWMinfo wmi;
  SDL_VERSION(&wmi.version);
  if (!SDL_GetWindowWMInfo(window, &wmi)) {
    throw std::runtime_error("failed to fetch window manager info");
  }

  bgfx::PlatformData pd;
  // TODO: implement for
  //   - linux / BSD (x11 and wayland?)
  //   - windows
#if BX_PLATFORM_OSX
  pd.ndt = nullptr;
  pd.nwh = wmi.info.cocoa.window;
#endif

  pd.context = nullptr;
  pd.backBuffer = nullptr;
  pd.backBufferDS = nullptr;

  return pd;
}

class Renderer {
public:
  Renderer()
    : _grass_cube("res/cobblestone.ktx", 1.0f, 1.0f, 1.0f) {}

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

    auto now = std::chrono::steady_clock::now();
    float time_sec =
        std::chrono::duration_cast<std::chrono::milliseconds>(now - start)
            .count() /
        1000.f;

    float mtx[16];
    bx::mtxRotateXY(mtx, time_sec, time_sec);
    mtx[11] = 0.0f;
    mtx[12] = 0.0f;
    mtx[13] = 0.0f;
    _grass_cube.render(mtx);
  }

private:
  Cube _grass_cube;
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
