cc_binary(
    name = "cppcraft",
    visibility = ["//visibility:public"],
    srcs = [
        "main.cpp",
        "guard.hpp",
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
