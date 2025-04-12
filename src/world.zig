const std = @import("std");
const ecs = @import("ecs");
const rl = @import("raylib");
const rendering = @import("rendering.zig");
const physics = @import("physics.zig");

pub const ShaderTag = enum { grass, road };
pub const ModelTag = enum { grass, road, player };
pub const SystemType = enum { draw, update, startup };

const ShaderMap = std.AutoArrayHashMapUnmanaged(ShaderTag, rl.Shader);
const ModelMap = std.AutoArrayHashMapUnmanaged(ModelTag, rl.Model);
const ScheduleList = std.ArrayListUnmanaged(*const fn (*World) void);
pub const World = struct {
    main_camera: rl.Camera,
    registry: ecs.Registry,
    allocator: std.mem.Allocator,
    shaders: ShaderMap,
    models: ModelMap,
    startup_schedule: ScheduleList,
    update_schedule: ScheduleList,
    draw_schedule: ScheduleList,
    frame_time: f32,

    const Self = @This();

    const ZERO_VEC: rl.Vector3 = .{ .x = 0, .y = 0, .z = 0 };

    pub fn init(allocator: std.mem.Allocator) !Self {
        const camera = rl.Camera3D{ .position = .{ .x = 0, .y = 4, .z = -8 }, .target = .{ .x = 0, .y = 0, .z = 0 }, .up = .{ .x = 0, .y = 1, .z = 0 }, .fovy = 45, .projection = .perspective };
        const registry = ecs.Registry.init(allocator);
        const shaders: ShaderMap = .empty;
        const models: ModelMap = .empty;
        const startup_schedule: ScheduleList = .empty;
        const update_schedule: ScheduleList = .empty;
        const draw_schedule: ScheduleList = .empty;
        raylib_init();

        return .{ .registry = registry, .allocator = allocator, .main_camera = camera, .shaders = shaders, .models = models, .startup_schedule = startup_schedule, .update_schedule = update_schedule, .draw_schedule = draw_schedule, .frame_time = 0 };
    }

    pub fn raylib_init() void {
        var WINDOW_WIDTH: i32 = 1600;
        var WINDOW_HEIGHT: i32 = 900;
        rl.setConfigFlags(.{ .window_resizable = true });
        rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "silver sniffle");
        const monitor = rl.getCurrentMonitor();
        WINDOW_WIDTH = rl.getMonitorWidth(monitor);
        WINDOW_HEIGHT = rl.getMonitorHeight(monitor);
    }

    pub fn map_shaders(self: *Self) void {
        var iter = self.models.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr;
            const material_count: usize = @intCast(value.materialCount);
            const shader_opt: ?rl.Shader = switch (key) {
                ModelTag.grass => self.shaders.get(ShaderTag.grass).?,
                ModelTag.road => self.shaders.get(ShaderTag.road).?,
                else => null,
            };

            if (shader_opt) |shader| {
                for (0..material_count) |i| {
                    value.*.materials[i].shader = shader;
                }
            }
        }
    }

    pub fn store_model(self: *Self, tag: ModelTag, model: *rl.Model) !void {
        try self.models.put(self.allocator, tag, model.*);
    }

    pub fn store_shader(self: *Self, tag: ShaderTag, shader: *rl.Shader) !void {
        try self.shaders.put(self.allocator, tag, shader.*);
    }

    pub fn register_system(self: *Self, system: fn (*World) void, system_type: SystemType) !void {
        switch (system_type) {
            .update => try self.update_schedule.append(self.allocator, system),
            .draw => try self.draw_schedule.append(self.allocator, system),
            .startup => try self.startup_schedule.append(self.allocator, system),
        }
    }

    pub fn set_shader_time(self: *Self) void {
        const time: f32 = @floatCast(rl.getTime());
        var iter = self.shaders.iterator();
        while (iter.next()) |shader| {
            const time_loc = rl.getShaderLocation(shader.value_ptr.*, "time");
            rl.setShaderValue(shader.value_ptr.*, time_loc, &time, .float);
        }
    }

    pub fn deinit(self: *Self) void {
        self.registry.deinit();
        rl.closeWindow();
    }

    pub fn startup(self: *Self) !void {
        // Register systems
        try self.register_system(physics.dynamics, .update);
        try self.register_system(rendering.draw_models, .draw);

        for (self.startup_schedule.items) |system| {
            system(self);
        }
    }

    pub fn update(self: *Self) void {
        self.frame_time = rl.getFrameTime();
        self.set_shader_time();
        for (self.update_schedule.items) |system| {
            system(self);
        }
    }

    pub fn draw(self: *Self) void {
        rl.beginDrawing();
        self.main_camera.begin();
        rl.clearBackground(rl.Color.dark_gray);
        for (self.draw_schedule.items) |system| {
            system(self);
        }
        self.main_camera.end();
        rl.endDrawing();
    }

    pub fn spawn(self: *Self, components: anytype) ecs.Entity {
        const entity = self.registry.create();
        if (components.len > 0) {
            inline for (components) |component| {
                switch (@typeInfo(@TypeOf(component))) {
                    .type => self.registry.add(entity, std.mem.zeroes(component)),
                    else => self.registry.add(entity, component),
                }
            }
        }
        return entity;
    }
};
