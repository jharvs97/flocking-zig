const std = @import("std");
const rl = @import("raylib");
const rm = @import("raylib-math");

const Boid = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
};

const System = struct {
    boids: std.ArrayListUnmanaged(Boid) = .{},
    avoid_factor: f32,
    matching_factor: f32,
    centering_factor: f32,
    turning_factor: f32,
    max_speed: f32,
    min_speed: f32,
    visual_range: f32,
    protected_range: f32,
    margin: struct { left: f32, right: f32, top: f32, bottom: f32 },
};

fn update(system: *System) void {
    for (system.boids.items, 0..) |*boid, i| {
        var separation = rm.vector2Zero();
        var average_velocity = rm.vector2Zero();
        var average_position = rm.vector2Zero();
        var neighbours: i32 = 0;
        for (system.boids.items, 0..) |other, j| {
            if (i == j) continue;
            const distance_vector = rm.vector2Subtract(boid.position, other.position);
            const magnitude = rm.vector2Length(distance_vector);
            if (magnitude <= system.protected_range) {
                separation = rm.vector2Add(separation, distance_vector);
            }
            if (magnitude <= system.visual_range) {
                average_velocity = rm.vector2Add(average_velocity, other.velocity);
                average_position = rm.vector2Add(average_position, other.position);
                neighbours += 1;
            }
        }
        boid.velocity = rm.vector2Add(boid.velocity, rm.vector2Scale(separation, system.avoid_factor));
        if (neighbours > 0) {
            average_velocity = rm.vector2Scale(average_velocity, 1.0 / @as(f32, @floatFromInt(neighbours)));
            average_position = rm.vector2Scale(average_position, 1.0 / @as(f32, @floatFromInt(neighbours)));

            boid.velocity = rm.vector2Add(
                boid.velocity,
                rm.vector2Scale(
                    rm.vector2Subtract(average_velocity, boid.velocity),
                    system.matching_factor,
                ),
            );

            boid.velocity = rm.vector2Add(
                boid.velocity,
                rm.vector2Scale(
                    rm.vector2Subtract(average_position, boid.position),
                    system.centering_factor,
                ),
            );
        }
        const speed = rm.vector2Length(boid.velocity);
        if (speed > system.max_speed) {
            boid.velocity = rm.vector2Scale(rm.vector2Scale(boid.velocity, 1.0 / speed), system.max_speed);
        }
        if (speed < system.min_speed) {
            boid.velocity = rm.vector2Scale(rm.vector2Scale(boid.velocity, 1.0 / speed), system.min_speed);
        }
        boid.position = rm.vector2Add(boid.position, boid.velocity);

        if (boid.position.x < system.margin.left) {
            boid.velocity.x += system.turning_factor;
        }
        if (boid.position.x > system.margin.right) {
            boid.velocity.x -= system.turning_factor;
        }
        if (boid.position.y < system.margin.top) {
            boid.velocity.y += system.turning_factor;
        }
        if (boid.position.y > system.margin.bottom) {
            boid.velocity.y -= system.turning_factor;
        }
    }
}

pub fn addBoid(system: *System, allocator: std.mem.Allocator, b: Boid) void {
    system.boids.append(allocator, b) catch unreachable;
}

pub fn deinit(system: *System, allocator: std.mem.Allocator) void {
    system.boids.deinit(allocator);
}

pub fn main() anyerror!void {
    const screen_width = 1280;
    const screen_height = 720;

    rl.initWindow(screen_width, screen_height, "Flocking");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var backing = try std.heap.page_allocator.alloc(u8, 1024 * 1024 * 16);
    var fba = std.heap.FixedBufferAllocator.init(backing);

    defer {
        std.heap.page_allocator.free(backing);
    }

    var camera: rl.Camera2D = undefined;
    camera.offset = rm.vector2Zero();
    camera.rotation = 0;
    camera.target = rm.vector2Zero();
    camera.zoom = 0;

    var prng = std.rand.DefaultPrng.init(0);
    var rand = prng.random();

    const margin = 250;

    var system = System{
        .avoid_factor = 0.02,
        .visual_range = 30,
        .protected_range = 10,
        .matching_factor = 0.05,
        .centering_factor = 0.005,
        .turning_factor = 0.2,
        .min_speed = 2,
        .max_speed = 3,
        .margin = .{
            .left = margin,
            .right = screen_width - margin,
            .top = margin,
            .bottom = screen_height - margin,
        },
    };

    defer deinit(&system, fba.allocator());

    while (!rl.windowShouldClose()) {
        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
            addBoid(&system, fba.allocator(), .{
                .position = rl.getMousePosition(),
                .velocity = rm.vector2Scale(randomUnitVector(rand), (rand.float(f32) + 0.1) * 2),
            });
        }

        update(&system);

        rl.beginDrawing();
        {
            {
                rl.clearBackground(rl.Color.ray_white);

                for (system.boids.items) |b| {
                    rl.drawCircleV(b.position, 2, rl.Color{ .a = 128, .r = 0, .g = 0, .b = 0 });
                }
            }
        }
        rl.endDrawing();
    }
}

pub fn randomUnitVector(rand: std.rand.Random) rl.Vector2 {
    const angle = rand.float(f32) * (2 * std.math.pi);
    const x = std.math.cos(angle);
    const y = std.math.sin(angle);
    return .{ .x = x, .y = y };
}

pub fn randomColor(rand: std.rand.Random) rl.Color {
    const angle = rand.float(f32) * 360;
    return rl.Color.fromHSV(angle, 1, 1);
}
