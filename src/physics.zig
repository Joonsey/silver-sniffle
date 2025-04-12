const std = @import("std");
const rl = @import("raylib");
const World = @import("world.zig").World;

const GRAVITY: rl.Vector3 = .{ .x = 0, .y = -9.81, .z = 0 };

pub const Rigidbody = struct {
    collider: Collider = .{ .cuboid = .{ .x = 1, .y = 1, .z = 1 } },
    rb_type: RigidbodyType = .static,

    const Self = @This();
    pub const default = Self{ .collider = .{ .cuboid = .{ .x = 1, .y = 1, .z = 1 } }, .rb_type = .static };

    pub const RigidbodyType = enum { static, dynamic, kinematic };
    pub const ColliderTag = enum {
        sphere,
        cuboid,
    };

    pub const Collider = union(ColliderTag) { sphere: f32, cuboid: rl.Vector3 };

    pub fn DetectCollision(self: Self, a_pos: rl.Vector3, rhs: Self, b_pos: rl.Vector3) bool {
        switch (self.collider) {
            .sphere => |radius| {
                switch (rhs.collider) {
                    .sphere => |r_radius| {
                        return (a_pos.distance(b_pos) <= radius + r_radius);
                    },
                    .cuboid => |r_extents| {
                        var dmin: f32 = 0;
                        const r_half_extents = r_extents.scale(0.5);
                        const r_min = b_pos.subtract(r_half_extents);
                        const r_max = b_pos.add(r_half_extents);

                        if (a_pos.x < r_min.x) {
                            dmin += std.math.pow(f32, a_pos.x - r_min.x, 2);
                        } else if (a_pos.x > r_max.x) {
                            dmin += std.math.pow(f32, a_pos.x - r_max.x, 2);
                        }
                        if (a_pos.y < r_min.y) {
                            dmin += std.math.pow(f32, a_pos.y - r_min.y, 2);
                        } else if (a_pos.y > r_max.y) {
                            dmin += std.math.pow(f32, a_pos.y - r_max.y, 2);
                        }
                        if (a_pos.z < r_min.z) {
                            dmin += std.math.pow(f32, a_pos.z - r_min.z, 2);
                        } else if (a_pos.z > r_max.z) {
                            dmin += std.math.pow(f32, a_pos.z - r_max.z, 2);
                        }
                        return (dmin <= radius * radius);
                    },
                }
                return false;
            },
            .cuboid => |extents| {
                const half_extents = extents.scale(0.5);
                const min = a_pos.subtract(half_extents);
                const max = b_pos.add(half_extents);

                switch (rhs.collider) {
                    .sphere => |r_radius| {
                        var dmin: f32 = 0;
                        if (b_pos.x < min.x) {
                            dmin += std.math.pow(f32, b_pos.x - min.x, 2);
                        } else if (b_pos.x > max.x) {
                            dmin += std.math.pow(f32, b_pos.x - max.x, 2);
                        }
                        if (b_pos.y < min.y) {
                            dmin += std.math.pow(f32, b_pos.y - min.y, 2);
                        } else if (b_pos.y > max.y) {
                            dmin += std.math.pow(f32, b_pos.y - max.y, 2);
                        }
                        if (b_pos.z < min.z) {
                            dmin += std.math.pow(f32, b_pos.z - min.z, 2);
                        } else if (b_pos.z > max.z) {
                            dmin += std.math.pow(f32, b_pos.z - max.z, 2);
                        }
                        return (dmin <= r_radius * r_radius);
                    },
                    .cuboid => |r_extents| {
                        const r_half_extents = r_extents.scale(0.5);
                        const r_min = b_pos.subtract(r_half_extents);
                        const r_max = b_pos.add(r_half_extents);

                        if (max.x >= r_min.x and min.x <= r_max.x) {
                            if (max.y < r_min.y or min.y > r_max.y) return false;
                            if (max.z < r_min.z or min.z > r_max.z) return false;
                            return true;
                        }
                    },
                }
            },
        }
        return false;
    }
};

test "AABB collision" {
    const a: Rigidbody = .default;
    const b: Rigidbody = .default;
    const c: Rigidbody = .default;
    const a_t: Transform = .{ .translation = .{ .x = 0, .y = 0, .z = 0 } };
    const b_t: Transform = .{ .translation = .{ .x = 0.5, .y = 0.5, .z = 0 } };
    const c_t: Transform = .{ .translation = .{ .x = 3.0, .y = 0.5, .z = 0 } };

    try std.testing.expect(a.DetectCollision(a_t.translation, b, b_t.translation));
    try std.testing.expect(!a.DetectCollision(a_t.translation, c, c_t.translation));
}

pub const Velocity = struct { velocity: rl.Vector3 = .{ .x = 0, .y = 0, .z = 0 } };

pub const Transform = struct {
    translation: rl.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    scale: f32 = 1,
};

pub const IgnoreGravity = struct {};
pub const Grounded = struct {};
pub const Platform = struct {};

pub const Dampening = f32;

pub const Collision = struct {
    const ecs = @import("ecs").Entity;
    a: ecs.Entity,
    b: ecs.Entity,
    normal: rl.Vector3,
    depth: f32,
};

pub fn dampen_velocity(world: *World) void {
    const delta = world.frame_time;
    var view = world.registry.view(.{ Velocity, Rigidbody, Dampening }, .{});
    var iter = view.entityIterator();

    while (iter.next()) |entity| {
        var velo = view.get(Velocity, entity);
        const dampening = view.getConst(Dampening, entity);
        const dampen_amount = velo.velocity.scale(1 / dampening);
        velo.velocity = velo.velocity.subtract(dampen_amount.scale(delta));
    }
}

pub fn apply_gravity(world: *World) void {
    const delta = world.frame_time;
    var view = world.registry.view(.{Velocity}, .{IgnoreGravity});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var velo = view.get(Velocity, entity);
        velo.velocity = velo.velocity.add(GRAVITY.scale(delta));
    }
}

pub fn apply_velocity(world: *World) void {
    const delta = world.frame_time;
    var view = world.registry.view(.{ Velocity, Transform, Rigidbody }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const rb = view.getConst(Rigidbody, entity);
        const velo = view.getConst(Velocity, entity);
        var translation = view.get(Transform, entity);

        switch (rb.rb_type) {
            .static => {},
            else => {
                translation.translation = translation.translation.add(velo.velocity.scale(delta));
            },
        }
    }
}

pub fn snap_to_ground(world: *World) void {
    const delta = world.frame_time;
    // Look for prospective collisions with platforms
    // if one is found position the rigidbody so that it is on the ground
    const view = world.registry.view(.{ Velocity, Transform, Rigidbody }, .{});
    _ = view;
    _ = delta;
}

pub fn dynamics(world: *World) void {
    apply_gravity(world);
    dampen_velocity(world);
    apply_velocity(world);
}
