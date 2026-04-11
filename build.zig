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
        .root = b.path("include/xcb/"),
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
        .root = b.path("include/xcb/"),
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
    xcb.root_module.addIncludePath(b.path("include/xcb/"));

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
