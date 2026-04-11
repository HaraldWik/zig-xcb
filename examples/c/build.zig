const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xcb = b.dependency("xcb", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "c",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addCSourceFile(.{ .file = b.path("src/main.c") });

    exe.root_module.addIncludePath(xcb.path("include"));

    exe.root_module.linkLibrary(xcb.artifact("xcb"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
