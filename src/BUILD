cc_binary(
    name = "cppcraft",
    visibility = ["//visibility:public"],
    srcs = [
        "guard.hpp",
        "main.cpp",
        "program.cpp",
        "program.h",
    ],
    data = [
        "//shaders",
        "//res",
    ],
    deps = [
        "@bgfx//:bgfx_macos",
        "@bimg//:bimg",
        "@bx//:bx",
        "@sdl2//:sdl2",
    ],
)
