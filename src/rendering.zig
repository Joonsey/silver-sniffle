const std = @import("std");
const rl = @import("raylib");
const World = @import("world.zig").World;
const Transform = @import("physics.zig").Transform;

pub const Model = struct {
    model: *rl.Model,
};

pub fn draw_models(world: *World) void {
    var view = world.registry.view(.{ Model, Transform }, .{});
    var iter = view.entityIterator();

    while (iter.next()) |entity| {
        const model = view.getConst(Model, entity);
        const transform = view.getConst(Transform, entity);

        rl.drawModelEx(model.model.*, transform.translation, .{ .x = 0, .y = 1, .z = 0 }, 0, .{ .x = 1, .y = 1, .z = 1 }, rl.Color.white);
    }
}
