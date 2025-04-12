const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const physics = @import("physics.zig");
const rendering = @import("rendering.zig");
const World = @import("world.zig").World;

var WINDOW_WIDTH: i32 = 1600;
var WINDOW_HEIGHT: i32 = 900;
const RENDER_WIDTH: i32 = 720;
const RENDER_HEIGHT: i32 = 480;
var show_world = true;

/// updates the global WINDOW_WIDTH and WINDOW_HEIGHT variables
pub fn setup_window() void {
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "silver sniffle");
    const monitor = rl.getCurrentMonitor();
    WINDOW_WIDTH = rl.getMonitorWidth(monitor);
    WINDOW_HEIGHT = rl.getMonitorHeight(monitor);
    rl.setWindowSize(WINDOW_WIDTH, WINDOW_HEIGHT);
}

fn draw_dev_ui(world: *World, camera: *rl.Camera3D) !void {
    var y_padding: f32 = 5;
    _ = rg.guiCheckBox(.{ .x = 10, .y = y_padding, .height = 20, .width = 20 }, "World", &show_world);
    if (show_world) y_padding += world.draw_dev_ui(y_padding);

    var buffer: [32]u8 = undefined;
    var text_value = std.fmt.bufPrintZ(&buffer, "{d:.2}", .{camera.position.x}) catch unreachable;
    _ = rg.guiValueBoxFloat(.{ .x = 100, .y = y_padding + 20, .width = 100, .height = 20 }, "camera x", text_value, &camera.position.x, true);
    text_value = std.fmt.bufPrintZ(&buffer, "{d:.2}", .{camera.position.y}) catch unreachable;
    _ = rg.guiValueBoxFloat(.{ .x = 100, .y = y_padding + 40, .width = 100, .height = 20 }, "camera y", text_value, &camera.position.y, true);
}

pub fn main() anyerror!void {
    setup_window();
    defer rl.closeWindow();

    var world = try World.init(std.heap.page_allocator);
    defer world.deinit();

    rg.guiLoadStyle("./assets/style_cyber.rgs");

    // in order to make refering to shaders and models less annoying, we store them in the world
    var player_model = try rl.loadModel("./assets/models/cheffy.glb");
    defer player_model.unload();

    try world.store_model(.player, &player_model);

    var camera = rl.Camera3D{
        .position = .{ .x = 0, .y = 4, .z = -8 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = .perspective,
    };

    _ = world.spawn(.{ physics.Transform{ .translation = .{ .x = 3, .y = 0, .z = 0 } }, rendering.Model{ .model = &player_model } });

    const scene = try rl.loadRenderTexture(RENDER_WIDTH, RENDER_HEIGHT);
    rl.setTargetFPS(60);

    // To have a system run in the ecs world, register it, wondering if there is a better place for this code to live
    // (J): Don't they already reside in startup?
    // sounds like they belong in there, but i can let you decide. I do not mind this also.
    // the fact that register_system is public is giving observer pattern vibes however
    try world.register_system(physics.dynamics, .update);
    try world.register_system(rendering.draw_models, .draw);

    try world.startup();
    while (!rl.windowShouldClose()) {
        world.update();

        // drawing scene to scene texture
        scene.begin();
        camera.begin();
        rl.clearBackground(rl.Color.dark_gray);
        world.draw();
        camera.end();
        scene.end();

        // drawing scene at desired resolution
        rl.beginDrawing();
        rl.drawTexturePro(scene.texture, .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(RENDER_WIDTH),
            .height = @floatFromInt(-RENDER_HEIGHT),
        }, .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(WINDOW_WIDTH),
            .height = @floatFromInt(WINDOW_HEIGHT),
        }, rl.Vector2.zero(), 0, .white);
        try draw_dev_ui(&world, &camera);
        rl.endDrawing();
    }
}
