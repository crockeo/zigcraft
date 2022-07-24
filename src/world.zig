const std = @import("std");
const zlm = @import("zlm");

const c = @import("./bridge.zig").c;
const cube = @import("./cube.zig");
const shader = @import("./shader.zig");
const events = @import("./events.zig");

pub const World = struct {
    renderer: Renderer,
    now: f32,

    player: Player,
    chunk_store: ChunkStore,

    pub fn init(allocator: std.mem.Allocator) !World {
        return World{
            .renderer = try Renderer.init(allocator),
            .now = 0.0,

            .player = Player.init(),
            .chunk_store = ChunkStore.init(allocator),
        };
    }

    pub fn deinit(self: *World) void {
        self.renderer.deinit();
        self.chunk_store.deinit();
    }

    pub fn update(self: *World, input: *events.InputState, dt: f32) !void {
        self.now += dt;
        self.player.update(input, dt);
    }

    pub fn render(self: *World, window_width: u32, window_height: u32) !void {
        try self.renderer.render(
            self.now,
            window_width,
            window_height,
            self,
        );
    }

    const ChunkInfo = struct {
        chunk: *const Chunk,
        x_offset: i64,
        z_offset: i64,
    };

    fn currentChunk(self: *World) !ChunkInfo {
        const x = @floatToInt(i64, self.player.pos.x / (Chunk.WORLD_WIDTH / 2));
        const z = @floatToInt(i64, self.player.pos.z / (Chunk.WORLD_DEPTH / 2));
        return ChunkInfo{
            .chunk = try self.chunk_store.load(x, z),
            .x_offset = x,
            .z_offset = z,
        };
    }
};

const ChunkStore = struct {
    const Self = @This();

    const Index: type = i64;
    const HashMap: type = std.AutoHashMap(struct{x: Index, z: Index}, Chunk);
    cache: ChunkStore.HashMap,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .cache = ChunkStore.HashMap.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.cache.deinit();
    }

    pub fn load(self: *Self, x: Index, z: Index) !*Chunk {
        const key = .{.x = x, .z = z};
        if (!self.cache.contains(key)) {
            var chunk = Chunk.init();
            chunk.randomize();
            try self.cache.put(key, chunk);
        }

        return self.cache.getPtr(key) orelse return error.InvariantViolated;
    }

    pub fn unload(_: *Self, _: *Chunk) void {
        // TODO: make this actually do something once we save these to disk
    }
};

const Chunk = struct {
    const Self = @This();

    const WIDTH: usize = 64;
    const HEIGHT: usize = 128;
    const DEPTH: usize = 64;
    const CHUNK_LEN: usize = Self.WIDTH * Self.HEIGHT * Self.DEPTH;

    const WORLD_WIDTH: f32 = @intToFloat(f32, Self.WIDTH) * 2.0;
    const WORLD_HEIGHT: f32 = @intToFloat(f32, Self.HEIGHT) * 2.0;
    const WORLD_DEPTH: f32 = @intToFloat(f32, Self.DEPTH) * 2.0;

    cubes: [Self.WIDTH][Self.HEIGHT][Self.DEPTH]cube.CubeType,

    pub fn init() Self {
        var self = Self{
            .cubes = undefined,
        };
        var i: usize = 0;
        while (i < Self.WIDTH * Self.HEIGHT * Self.DEPTH) : (i += 1) {
            self.set(i, cube.CubeType.count);
        }
        return self;
    }

    pub fn randomize(self: *Self) void {
        var rnd = std.rand.DefaultPrng.init(@intCast(u64, std.time.nanoTimestamp()));
        var x: usize = 0;
        while (x < Self.WIDTH) : (x += 1) {
            var y: usize = 0;
            while (y < Self.HEIGHT) : (y += 1) {
                var z: usize = 0;
                while (z < Self.DEPTH) : (z += 1) {
                    if (y > Self.HEIGHT / 2 - 2) {
                        continue;
                    } else if (y == Self.HEIGHT / 2 - 2) {
                        self.setXYZ(x, y, z, cube.CubeType.grass);
                    } else {
                        const dirtChance = (@intToFloat(f32, y) - 2) / @intToFloat(f32, Self.HEIGHT) / 2;
                        const roll = rnd.random().float(f32);
                        if (roll <= dirtChance) {
                            self.setXYZ(x, y, z, cube.CubeType.dirt);
                        } else {
                            self.setXYZ(x, y, z, cube.CubeType.cobblestone);
                        }
                    }
                }
            }
        }
    }

    pub fn setXYZ(self: *Self, x: usize, y: usize, z: usize, cube_type: cube.CubeType) void {
        self.cubes[x][y][z] = cube_type;
    }

    pub fn set(self: *Self, index: usize, cube_type: cube.CubeType) void {
        const pos = Self.indexToXYZ(index);
        self.cubes[pos.x][pos.y][pos.z] = cube_type;
    }

    pub fn getXYZ(self: *const Self, x: usize, y: usize, z: usize) cube.CubeType {
        return self.cubes[x][y][z];
    }

    pub fn get(self: *Self, index: usize) cube.CubeType {
        const pos = Self.indexToXYZ(index);
        return self.cubes[pos.x][pos.y][pos.z];
    }

    pub fn isVisible(self: *const Self, x: usize, y: usize, z: usize) bool {
        // TODO: represent visibility across the boundaries of chunks

        // TODO: do fancy math around the current FOV of the user,
        // the angle they're facing at,
        // and which blocks could technically be visible

        if (x == 0 or x == Self.WIDTH - 1
                or y == 0 or y == Self.HEIGHT - 1
                or z == 0 or z == Self.DEPTH - 1) {
            return true;
        }

        // TODO: make this better. inline for loop?
        if (self.getXYZ(x - 1, y, z) == cube.CubeType.count) {
            return true;
        }
        if (self.getXYZ(x + 1, y, z) == cube.CubeType.count) {
            return true;
        }
        if (self.getXYZ(x, y - 1, z) == cube.CubeType.count) {
            return true;
        }
        if (self.getXYZ(x, y + 1, z) == cube.CubeType.count) {
            return true;
        }
        if (self.getXYZ(x, y, z - 1) == cube.CubeType.count) {
            return true;
        }
        if (self.getXYZ(x, y, z + 1) == cube.CubeType.count) {
            return true;
        }

        return false;
    }

    fn indexToXYZ(index: usize) struct{x: usize, y: usize, z: usize} {
        const x: usize = index / (Self.HEIGHT * Self.DEPTH);
        const y: usize = index % (Self.HEIGHT * Self.DEPTH) / Self.WIDTH;
        const z: usize = index % (Self.HEIGHT * Self.DEPTH) % Self.WIDTH;
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    fn xyzToIndex(x: usize, y: usize, z: usize) usize {
        return x * (Self.HEIGHT * Self.DEPTH) + y * Self.WIDTH + z;
    }
};

const Player = struct {
    const Self = @This();

    pos: zlm.Vec3,
    vel: zlm.Vec3,
    rot: zlm.Vec2,

    pub fn init() Player {
        return Player{
            .rot = zlm.Vec2.new(0, 0),
            .vel = zlm.Vec3.new(0, 0, 0),
            .pos = zlm.Vec3.new(0, 0, 0),
        };
    }

    pub fn update(self: *Self, input: *events.InputState, dt: f32) void {
        // Note that rotX and rotY
        // come from mouseRot.dy and mouseRot.dx
        // because of 2D movement vs. rotational axes.
        const mouseRot = input.getMouseRot();
        self.rot.y -= mouseRot.x * std.math.pi;
        self.rot.x += mouseRot.y * std.math.pi;
        if (self.rot.x < -std.math.pi / 3.0) {
            self.rot.x = -std.math.pi / 3.0;
        }
        if (self.rot.x > std.math.pi / 3.0) {
            self.rot.x = std.math.pi / 3.0;
        }

        const maxSpeed = 10.0;
        const acceleration = 80.0;

        if (input.isPressed(c.SDL_SCANCODE_W)) {
            self.vel.z -= dt * acceleration;
        }
        if (input.isPressed(c.SDL_SCANCODE_S)) {
            self.vel.z += dt * acceleration;
        }
        if (!input.isPressed(c.SDL_SCANCODE_W) and !input.isPressed(c.SDL_SCANCODE_S) and self.vel.z != 0) {
            const mul: f32 = if (self.vel.z > 0) -1.0 else 1.0;
            self.vel.z += mul * dt * acceleration;
            if (std.math.absFloat(self.vel.z) > 2 * dt * acceleration) {
                self.vel.z = 0;
            }
        }

        if (input.isPressed(c.SDL_SCANCODE_A)) {
            self.vel.x += dt * acceleration;
        }
        if (input.isPressed(c.SDL_SCANCODE_D)) {
            self.vel.x -= dt * acceleration;
        }
        if (!input.isPressed(c.SDL_SCANCODE_A) and !input.isPressed(c.SDL_SCANCODE_D) and self.vel.x != 0) {
            const mul: f32 = if (self.vel.x > 0) -1.0 else 1.0;
            self.vel.x += mul * dt * acceleration;
            if (std.math.absFloat(self.vel.x) > 2 * dt * acceleration) {
                self.vel.x = 0;
            }
        }

        const lateral = self.vel.swizzle("x0z");
        if (lateral.length2() > maxSpeed * maxSpeed) {
            const yComponent = self.vel.y;
            self.vel = lateral.normalize().scale(maxSpeed);
            self.vel.y = yComponent;
        }

        const rot = self.getRotMatrix();
        const rotVel = self.vel.swizzle("xyz0").transform(rot).swizzle("x0z");
        self.pos = self.pos.add(rotVel.scale(dt));
    }

    fn getRotMatrix(self: *const Self) zlm.Mat4 {
        return zlm.Mat4.createAngleAxis(
            zlm.Vec3.unitX,
            self.rot.x,
        ).mul(zlm.Mat4.createAngleAxis(
            zlm.Vec3.unitY,
            self.rot.y,
        ));
    }
};

const Renderer = struct {
    registry: cube.CubeRegistry,

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        return Renderer{
            .registry = try cube.CubeRegistry.init(allocator),
        };
    }

    pub fn deinit(self: *const Renderer) void {
        self.registry.deinit();
    }

    pub fn render(
        self: *const Renderer,
        _: f32,  // now
        width: u32,
        height: u32,
        world: *World,
    ) !void {
        const lookAt4 = zlm.Vec4.unitZ.transform(world.player.getRotMatrix());
        const lookAt = world.player.pos.add(zlm.Vec3.new(lookAt4.x, lookAt4.y, lookAt4.z));

        const view = zlm.Mat4.createLookAt(
            lookAt,
            world.player.pos,
            zlm.Vec3.unitY,
        );
        const proj = zlm.Mat4.createPerspective(
            std.math.pi / 3.0,
            @intToFloat(f32, width) / @intToFloat(f32, height),
            0.1,
            100.0,
        );

        c.bgfx_set_view_transform(0, &view.fields, &proj.fields);
        c.bgfx_set_view_rect(0, 0, 0, @intCast(u16, width), @intCast(u16, height));
        c.bgfx_touch(0);

        // TODO: figuring out how to render more things on the screen at once, e.g. instancing?
        const chunk_info = try world.currentChunk();
        const x_offset = @intToFloat(f32, chunk_info.x_offset) * Chunk.WORLD_WIDTH;
        const z_offset = @intToFloat(f32, chunk_info.z_offset) * Chunk.WORLD_DEPTH;

        var x: usize = 0;
        while (x < Chunk.WIDTH) : (x += 1) {
            var y: usize = 0;
            while (y < Chunk.HEIGHT) : (y += 1) {
                var z: usize = 0;
                while (z < Chunk.DEPTH) : (z += 1) {
                    if (!chunk_info.chunk.isVisible(x, y, z)) {
                        continue;
                    }

                    const cube_type = chunk_info.chunk.getXYZ(x, y, z);
                    if (cube_type == cube.CubeType.count) {
                        continue;
                    }

                    const cubeInstance = self.registry.getCube(cube_type);
                    const mtx = zlm.Mat4.createTranslationXYZ(
                        x_offset + (@intToFloat(f32, x) - @intToFloat(f32, Chunk.WIDTH) / 2.0) * 2.0,
                        (@intToFloat(f32, y) - @intToFloat(f32, Chunk.HEIGHT) / 2.0) * 2.0,
                        z_offset + (@intToFloat(f32, z) - @intToFloat(f32, Chunk.DEPTH) / 2.0) * 2.0,
                    );
                    cubeInstance.render(mtx.fields);
                }
            }
        }

        _ = c.bgfx_frame(false);
    }
};

test "Chunk::index -> xyz -> index" {
    const index = 1241;
    const pos = Chunk.indexToXYZ(index);
    const newIndex = Chunk.xyzToIndex(pos.x, pos.y, pos.z);
    try std.testing.expect(index == newIndex);
}

test "Chunk::xyz -> index -> xyz" {
    const pos = .{.x = 5, .y = 10, .z = 32};
    const index = Chunk.xyzToIndex(pos.x, pos.y, pos.z);
    const newPos = Chunk.indexToXYZ(index);

    try std.testing.expect(
        pos.x == newPos.x
            and pos.y == newPos.y
            and pos.z == newPos.z
    );
}
