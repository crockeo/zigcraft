load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")

new_local_repository(
    name = "bgfx",
    path = "dependencies/bgfx",
    build_file = "@//external:BUILD.bgfx",
)

new_local_repository(
    name = "bimg",
    path = "dependencies/bimg",
    build_file = "@//external:BUILD.bimg",
)

git_repository(
    name = "astc-codec",
    remote = "git@github.com:google/astc-codec",
    commit = "9757befb64db6662aad45de09ca87cd6f599ac02",
)

new_local_repository(
    name = "bx",
    path = "dependencies/bx",
    build_file = "@//external:BUILD.bx",
)

# TODO: change this to a git repo of the real SDL2
# and build it from there, so it's not so brittle
new_local_repository(
    name = "sdl2",
    path = "/usr/local/Cellar/sdl2/2.0.14_1",
    build_file = "@//external:BUILD.sdl2",
)
