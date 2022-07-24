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
    chunk: [32][32][32]cube.CubeType,

    pub fn init(allocator: std.mem.Allocator) !World {
        var chunk: [32][32][32]cube.CubeType = undefined;
        var x: usize = 0;
        var y: usize = 0;
        var z: usize = 0;
        while (x < 32) {
            if (y == 14) {
                chunk[x][y][z] = cube.CubeType.grass;
            } else {
                chunk[x][y][z] = cube.CubeType.count;
            }

            z += 1;
            if (z >= 32) {
                z = 0;
                y += 1;
            }
            if (y >= 32) {
                y = 0;
                x += 1;
            }
        }

        return World{
            .renderer = try Renderer.init(allocator),
            .now = 0.0,

            .player = Player.init(),
            .chunk = chunk,
        };
    }

    pub fn deinit(self: *const World) void {
        self.renderer.deinit();
    }

    pub fn update(self: *World, input: *events.InputState, dt: f32) !void {
        self.now += dt;
        self.player.update(input, dt);
    }

    pub fn render(self: *const World, window_width: u32, window_height: u32) !void {
        self.renderer.render(
            self.now,
            window_width,
            window_height,
            self,
        );
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
        world: *const World,
    ) void {
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

        // TODO: hate this syntax. how fix?
        for (world.chunk) |x, xi| {
            for (x) |y, yi| {
                for (y) |cubeType, zi| {
                    if (cubeType == cube.CubeType.count) {
                        continue;
                    }

                    const cubeInstance = self.registry.getCube(cubeType);
                    const mtx = zlm.Mat4.createTranslationXYZ(
                        (@intToFloat(f32, xi) - 16.0) * 2.0,
                        (@intToFloat(f32, yi) - 16.0) * 2.0,
                        (@intToFloat(f32, zi) - 16.0) * 2.0,
                    );
                    cubeInstance.render(mtx.fields);
                }
            }
        }

        _ = c.bgfx_frame(false);
    }
};
