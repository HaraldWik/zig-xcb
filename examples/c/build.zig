const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xcb = b.dependency("xcb", .{
        .target = target,
        .optimize = optimize,
        // .composite = true,
        // .damage = true,
        // .dbe = true,
        // .dpms = true,
        // .dri2 = true,
        // .dri3 = true,
        // .ge = true,
        // .glx = true,
        // .present = true,
        // .randr = true,
        // .record = true,
        // .render = true,
        // .res = true,
        // .screensaver = true,
        // .shape = true,
        // .shm = true,
        // .sync = true,
        // .xevie = true,
        // .xf86dri = true,
        // .xf86vidmode = true,
        // .xfixes = true,
        // .xinerama = true,
        // .xinput = true,
        // .xkb = true,
        // .xprint = true,
        // .xselinux = true,
        // .xtest = true,
        // .xv = true,
        // .xvmc = true,
    });

    const exe = b.addExecutable(.{
        .name = "c",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addCSourceFile(.{ .file = b.path("src/main.c") });

    exe.root_module.linkLibrary(xcb.artifact("xcb"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
