const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const xau = b.addLibrary(.{
        .name = "xau",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/xau.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const mod = b.addModule("xcb", .{
        .root_source_file = scanner.result,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addCSourceFiles(.{
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
        },
    });
    mod.addCSourceFiles(.{
        .root = b.path("src/xcbgen/"),
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
    mod.addIncludePath(b.path("src/"));
    mod.addIncludePath(b.path("src/xcbgen"));

    mod.linkLibrary(xau);
}

pub const Scanner = struct {
    run: *std.Build.Step.Run,
    result: std.Build.LazyPath,

    pub const AddProtocolsOptions = struct {
        root: std.Build.LazyPath,
        files: []const []const u8,
    };

    pub fn create(b: *std.Build) *@This() {
        const exe = b.addExecutable(.{
            .name = "xcb-scanner",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/scanner.zig"),
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

// const zig_xcb_build_zig = @This();

// pub const Scanner = struct {
//     run: *std.Build.Step.Run,
//     result: std.Build.LazyPath,

//     xcb_protocols: std.Build.LazyPath,

//     pub const Options = struct {
//         xcb_xml: ?std.Build.LazyPath = null,
//         xcb_protocols: ?std.Build.LazyPath = null,
//     };

//     pub fn create(b: *std.Build, options: Options) *Scanner {
//         const pkg_config_exe_path = b.graph.environ_map.get("PKG_CONFIG") orelse "pkg-config";
//         const xcb_xml: std.Build.LazyPath = options.xcb_xml orelse blk: {
//             const pc_output = b.run(&.{ pkg_config_exe_path, "--variable=pkgdatadir", "xcb-scanner" });
//             break :blk .{
//                 .cwd_relative = b.pathJoin(&.{ std.mem.trim(u8, pc_output, &std.ascii.whitespace), "xcb.xml" }),
//             };
//         };
//         const xcb_protocols: std.Build.LazyPath = options.xcb_protocols orelse blk: {
//             const pc_output = b.run(&.{ pkg_config_exe_path, "--variable=pkgdatadir", "xcb-protocols" });
//             break :blk .{
//                 .cwd_relative = std.mem.trim(u8, pc_output, &std.ascii.whitespace),
//             };
//         };

//         const exe = b.addExecutable(.{
//             .name = "zig-xcb-scanner",
//             .root_module = b.createModule(.{
//                 .root_source_file = blk: {
//                     if (b.available_deps.len > 0) {
//                         break :blk b.dependencyFromBuildZig(zig_xcb_build_zig, .{}).path("src/scanner.zig");
//                     } else {
//                         break :blk b.path("src/scanner.zig");
//                     }
//                 },
//                 .target = b.graph.host,
//             }),
//         });

//         const run = b.addRunArtifact(exe);

//         run.addArg("-o");
//         const result = run.addOutputFileArg("xcb.zig");

//         run.addArg("-i");
//         run.addFileArg(xcb_xml);

//         const scanner = b.allocator.create(Scanner) catch @panic("OOM");
//         scanner.* = .{
//             .run = run,
//             .result = result,
//             .xcb_protocols = xcb_protocols,
//         };

//         return scanner;
//     }

//     /// Scan protocol xml provided by the wayland-protocols package at the given path
//     /// relative to the wayland-protocols installation. (e.g. "xproto/bigreq.xml")
//     pub fn addSystemProtocol(scanner: *Scanner, sub_path: []const u8) void {
//         const b = scanner.run.step.owner;

//         scanner.run.addArg("-i");
//         scanner.run.addFileArg(scanner.xcb_protocols.path(b, sub_path));
//     }

//     /// Scan the protocol xml at the given path.
//     pub fn addCustomProtocol(scanner: *Scanner, path: std.Build.LazyPath) void {
//         scanner.run.addArg("-i");
//         scanner.run.addFileArg(path);
//     }
// };
