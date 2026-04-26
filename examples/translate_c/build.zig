const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xcb_dep = b.dependency("xcb", .{
        .target = target,
        .optimize = optimize,
        .glx = true,
        .randr = true,
        .render = true,
        .shape = true,
        .shm = true,
        .xfixes = true,
        .xinput = true,
        .icccm = true,
        .translate_c = true,
    });

    const exe = b.addExecutable(.{
        .name = "translate_c",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "xcb", .module = xcb_dep.module("xcb") },
            },
        }),
    });
    exe.root_module.linkLibrary(xcb_dep.artifact("xcb"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
