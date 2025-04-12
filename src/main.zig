const std = @import("std");
const rl = @import("raylib");
const physics = @import("physics.zig");
const rendering = @import("rendering.zig");
const World = @import("world.zig").World;

pub fn main() anyerror!void {
    var world = try World.init(std.heap.page_allocator);
    defer world.deinit();

    // Load Models
    var player_model = try rl.loadModel("./assets/models/cheffy.glb");

    try world.store_model(.player, &player_model);

    _ = world.spawn(.{ physics.Transform{ .translation = .{ .x = 3, .y = 0, .z = 0 } }, rendering.Model{ .model = &player_model } });

    defer rl.closeWindow();

    rl.setTargetFPS(60);

    try world.startup();
    while (!rl.windowShouldClose()) {
        world.update();
        world.draw();
    }
}
