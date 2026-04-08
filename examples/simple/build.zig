const std = @import("std");

const Scanner = @import("xcb").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xcb = b.dependency("xcb", .{ .target = target, .optimize = optimize });

    const xproto = b.dependency("xproto", .{});

    const scanner = Scanner.create(b);
    scanner.addProtocols(.{
        .root = xproto.path("src/"),
        .files = &.{
            "damage.xml", "dri2.xml",        "glx.xml",
            "record.xml", "screensaver.xml", "sync.xml",
            "xevie.xml",    "xfixes.xml", //"xkb.xml",
            "xselinux.xml", "xvmc.xml",
            "bigreq.xml",   "dbe.xml",
            "dri3.xml",     "present.xml",
            "render.xml",   "shape.xml",
            "xc_misc.xml",  "xf86dri.xml",
            "xinerama.xml", "xprint.xml",
            "xtest.xml",    "composite.xml",
            "dpms.xml",     "ge.xml",
            "randr.xml",    "res.xml",
            "shm.xml",      "xf86vidmode.xml",
            //"xinput.xml",
            "xproto.xml",   "xv.xml",
        },
    });

    const xcb_mod = b.createModule(.{
        .root_source_file = scanner.result,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "simple",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "xcb", .module = xcb_mod },
            },
        }),
    });
    exe.root_module.linkLibrary(xcb.artifact("xcb"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
