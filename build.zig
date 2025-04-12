const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const ResolvedTarget = Build.ResolvedTarget;
const Dependency = Build.Dependency;
const sokol = @import("sokol");

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // note that the sokol dependency is built with `.with_sokol_imgui = true`
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });
    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    // inject the cimgui header search path into the sokol C library compile step
    dep_sokol.artifact("sokol_clib").addIncludePath(dep_cimgui.path("src"));

    // main module with sokol and cimgui imports
    const mod_main = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
        },
    });

    // wasm is not supported, for now
    if (target.result.cpu.arch.isWasm()) {
        @panic("Unsupported build target");
    } else {
        const exe = b.addExecutable(.{
            .name = "demo",
            .root_module = mod_main,
        });
        b.installArtifact(exe);
        b.step("run", "Run demo").dependOn(&b.addRunArtifact(exe).step);
    }
}
