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
        var i: usize = 0;
        var j: usize = 0;
        var k: usize = 0;
        while (i < 32) {
            chunk[i][j][k] = cube.CubeType.count;
            k += 1;
            if (k >= 32) {
                k = 0;
                j += 1;
            }
            if (j >= 32) {
                j = 0;
                i += 1;
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
            self.player.pos,
            self.player.getRotMatrix(),
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
        now: f32,
        width: u32,
        height: u32,
        pos: zlm.Vec3,
        rot: zlm.Mat4,
    ) void {
        const lookAt4 = zlm.Vec4.unitZ.transform(rot);
        const lookAt = pos.add(zlm.Vec3.new(lookAt4.x, lookAt4.y, lookAt4.z));


        const view = zlm.Mat4.createLookAt(
            lookAt,
            pos,
            zlm.Vec3.unitY,
        );
        const proj = zlm.Mat4.createPerspective(
            std.math.pi / 2.0,
            @intToFloat(f32, width) / @intToFloat(f32, height),
            0.1,
            100.0,
        );

        c.bgfx_set_view_transform(0, &view.fields, &proj.fields);
        c.bgfx_set_view_rect(0, 0, 0, @intCast(u16, width), @intCast(u16, height));
        c.bgfx_touch(0);

        const cubes = [_]*const cube.Cube{
            self.registry.getCube(cube.CubeType.grass),
            self.registry.getCube(cube.CubeType.cobblestone),
            self.registry.getCube(cube.CubeType.dirt),
        };
        var i: usize = 0;
        while (i < cubes.len) {
            var mtx = zlm.Mat4.createAngleAxis(
                zlm.Vec3.unitX,
                now * 0.7 + @intToFloat(f32, i),
            ).mul(zlm.Mat4.createAngleAxis(
                zlm.Vec3.unitY,
                now + @intToFloat(f32, i),
            )).mul(zlm.Mat4.createTranslationXYZ(
                (@intToFloat(f32, i) - 1) * 5.0,
                0,
                0,
            ));
            cubes[i].render(mtx.fields);
            i += 1;
        }


        _ = c.bgfx_frame(false);
    }
};
