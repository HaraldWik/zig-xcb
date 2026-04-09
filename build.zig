const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xau = b.addLibrary(.{
        .name = "xau",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/xau.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const xcb = b.addLibrary(.{
        .name = "xcb",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    xcb.root_module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "xcb_auth.c",
            "xcb_conn.c",
            "xcb_ext.c",
            "xcb_in.c",
            "xcb_list.c",
            "xcb_out.c",
            "xcb_util.c",
            "xcb_xid.c",
            "icccm.c",
        },
    });
    xcb.root_module.addCSourceFiles(.{
        .root = b.path("xcbgen/"),
        .files = &.{
            "xselinux.c",
            "xvmc.c",
            "xf86vidmode.c",
            "ge.c",
            "xf86dri.c",
            "render.c",
            "randr.c",
            "record.c",
            "xinput.c",
            "glx.c",
            "xinerama.c",
            "xv.c",
            "xc_misc.c",
            "sync.c",
            "shm.c",
            "present.c",
            "xfixes.c",
            "composite.c",
            "shape.c",
            "xevie.c",
            "xprint.c",
            "res.c",
            "xkb.c",
            "dbe.c",
            "screensaver.c",
            "dpms.c",
            "xproto.c",
            "dri3.c",
            "damage.c",
            "bigreq.c",
            "dri2.c",
            "xtest.c",
        },
    });
    xcb.root_module.addIncludePath(b.path("src/"));
    xcb.root_module.addIncludePath(b.path("xcbgen"));

    xcb.installHeader(b.path("src/xcb.h"), "xcb.h");
    xcb.installHeader(b.path("src/xcb.h"), "xcb/xcb.h");
    xcb.installHeader(b.path("src/xcbext.h"), "xcb/xcbext.h");
    xcb.installHeader(b.path("src/xcbint.h"), "xcb/xcbint.h");
    xcb.installHeader(b.path("src/xcb_windefs.h"), "xcb/xcb_windefs.h");
    xcb.installHeader(b.path("src/xcb_icccm.h"), "xcb/xcb_icccm.h");

    xcb.installHeader(b.path("xcbgen/xselinux.h"), "xcb/xselinux.h");
    xcb.installHeader(b.path("xcbgen/xvmc.h"), "xcb/xvmc.h");
    xcb.installHeader(b.path("xcbgen/xf86vidmode.h"), "xcb/xf86vidmode.h");
    xcb.installHeader(b.path("xcbgen/ge.h"), "xcb/ge.h");
    xcb.installHeader(b.path("xcbgen/xf86dri.h"), "xcb/xf86dri.h");
    xcb.installHeader(b.path("xcbgen/render.h"), "xcb/render.h");
    xcb.installHeader(b.path("xcbgen/randr.h"), "xcb/randr.h");
    xcb.installHeader(b.path("xcbgen/record.h"), "xcb/record.h");
    xcb.installHeader(b.path("xcbgen/xinput.h"), "xcb/xinput.h");
    xcb.installHeader(b.path("xcbgen/glx.h"), "xcb/glx.h");
    xcb.installHeader(b.path("xcbgen/xinerama.h"), "xcb/xinerama.h");
    xcb.installHeader(b.path("xcbgen/xv.h"), "xcb/xv.h");
    xcb.installHeader(b.path("xcbgen/xc_misc.h"), "xcb/xc_misc.h");
    xcb.installHeader(b.path("xcbgen/sync.h"), "xcb/sync.h");
    xcb.installHeader(b.path("xcbgen/shm.h"), "xcb/shm.h");
    xcb.installHeader(b.path("xcbgen/present.h"), "xcb/present.h");
    xcb.installHeader(b.path("xcbgen/xfixes.h"), "xcb/xfixes.h");
    xcb.installHeader(b.path("xcbgen/composite.h"), "xcb/composite.h");
    xcb.installHeader(b.path("xcbgen/shape.h"), "xcb/shape.h");
    xcb.installHeader(b.path("xcbgen/xevie.h"), "xcb/xevie.h");
    xcb.installHeader(b.path("xcbgen/xprint.h"), "xcb/xprint.h");
    xcb.installHeader(b.path("xcbgen/res.h"), "xcb/res.h");
    xcb.installHeader(b.path("xcbgen/xkb.h"), "xcb/xkb.h");
    xcb.installHeader(b.path("xcbgen/dbe.h"), "xcb/dbe.h");
    xcb.installHeader(b.path("xcbgen/screensaver.h"), "xcb/screensaver.h");
    xcb.installHeader(b.path("xcbgen/dpms.h"), "xcb/dpms.h");
    xcb.installHeader(b.path("xcbgen/xproto.h"), "xcb/xproto.h");
    xcb.installHeader(b.path("xcbgen/dri3.h"), "xcb/dri3.h");
    xcb.installHeader(b.path("xcbgen/damage.h"), "xcb/damage.h");
    xcb.installHeader(b.path("xcbgen/bigreq.h"), "xcb/bigreq.h");
    xcb.installHeader(b.path("xcbgen/dri2.h"), "xcb/dri2.h");
    xcb.installHeader(b.path("xcbgen/xtest.h"), "xcb/xtest.h");

    xcb.root_module.linkLibrary(xau);

    b.installArtifact(xau);
    b.installArtifact(xcb);
}

const zig_xcb_build = @This();

pub const Scanner = struct {
    run: *std.Build.Step.Run,
    result: std.Build.LazyPath,

    pub const AddProtocolsOptions = struct {
        root: std.Build.LazyPath,
        files: []const []const u8,
    };

    pub fn create(b: *std.Build) *@This() {
        const scanner_source_path = b.dependencyFromBuildZig(zig_xcb_build, .{}).path("src/scanner.zig");
        const exe = b.addExecutable(.{
            .name = "xcb-scanner",
            .root_module = b.createModule(.{
                .root_source_file = scanner_source_path,
                .target = b.graph.host,
            }),
        });

        const run = b.addRunArtifact(exe);
        run.addArg("-o");

        const result = run.addOutputFileArg("xcb.zig");

        const scanner = b.allocator.create(Scanner) catch @panic("OOM");
        scanner.* = .{
            .run = run,
            .result = result,
        };
        return scanner;
    }

    pub fn addProtocol(scanner: *Scanner, path: std.Build.LazyPath) void {
        scanner.run.addArg("-i");
        scanner.run.addFileArg(path);
    }

    pub fn addProtocols(scanner: *Scanner, options: AddProtocolsOptions) void {
        for (options.files) |file| {
            const path = options.root.path(options.root.dependency.dependency.builder, file);
            scanner.addProtocol(path);
        }
    }
};
