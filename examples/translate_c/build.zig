const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xcb_dep = b.dependency("xcb", .{ .target = target, .optimize = optimize });

    const xcb_translate_c = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("xcb.h",
            \\#include <xcb/xcb.h>
        ),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "translate_c",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "xcb", .module = xcb_translate_c.createModule() },
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
