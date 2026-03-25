const std = @import("std");

pub const protocol_file_names: []const []const u8 = &.{
    "bigreq.xml",
    "composite.xml",
    "damage.xml",
    "dbe.xml",
    "dpms.xml",
    "dri2.xml",
    "dri3.xml",
    "ge.xml",
    "glx.xml",
    "present.xml",
    "randr.xml",
    "record.xml",
    "render.xml",
    "res.xml",
    "screensaver.xml",
    "shape.xml",
    "shm.xml",
    "sync.xml",
    "xc_misc.xml",
    "xevie.xml",
    "xf86dri.xml",
    "xf86vidmode.xml",
    "xfixes.xml",
    "xinerama.xml",
    "xinput.xml",
    "xkb.xml",
    "xprint.xml",
    "xproto.xml",
    "xselinux.xml",
    "xtest.xml",
    "xv.xml",
    "xvmc.xml",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const python = b.findProgram(&.{"python3"}, &.{"python"}) catch @panic("could not find python3");
    const xproto_dep = b.dependency("xproto", .{});

    const xcbgen_step = b.step("xcbgen", "Generates the xcb proto.xml files into .c and .h files");

    std.Io.Dir.createDirAbsolute(b.graph.io, b.pathJoin(&.{ b.build_root.path orelse "", "zig-pkg/xcbgen" }), .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => std.debug.panic("create dir xcbgen in zig-pkg: {s}", .{@errorName(err)}),
    };

    const xcbgen_path = "zig-pkg/xcbgen";

    for (protocol_file_names) |file_name| {
        const xcbgen = xproto_dep.builder.build_root.path orelse ".";
        const c_client_python_script = b.pathJoin(&.{ b.build_root.path orelse ".", "src/c_client.py" });

        const xproto_cmd = b.addSystemCommand(&.{ python, c_client_python_script });
        xproto_cmd.setEnvironmentVariable("PYTHONPATH", xcbgen);
        xproto_cmd.addFileArg(xproto_dep.builder.path(xproto_dep.builder.pathJoin(&.{ "src/", file_name })));
        xproto_cmd.setCwd(b.path(xcbgen_path));
        xcbgen_step.dependOn(&xproto_cmd.step);
    }

    const lib = b.addLibrary(.{
        .name = "xcb",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib.step.dependOn(xcbgen_step);

    lib.root_module.addCSourceFiles(.{
        .root = b.path("src/"),
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
    lib.root_module.addIncludePath(b.path("src/"));

    lib.installHeader(b.path("src/xcb.h"), "xcb.h");
    lib.installHeader(b.path("src/xcb.h"), "xcb/xcb.h");
    lib.installHeader(b.path("src/xcbext.h"), "xcb/xcbext.h");
    lib.installHeader(b.path("src/xcbint.h"), "xcb/xcbint.h");
    lib.installHeader(b.path("src/xcb_windefs.h"), "xcb/xcb_windefs.h");

    for (protocol_file_names) |file_name| {
        const real_path = b.path(b.fmt("{s}/{s}.h", .{ xcbgen_path, file_name[0 .. file_name.len - 4] }));
        lib.installHeader(
            real_path,
            b.fmt("xcb/xcb_{s}.h", .{file_name[0 .. file_name.len - 4]}),
        );
        lib.installHeader(
            real_path,
            b.fmt("{s}.h", .{file_name[0 .. file_name.len - 4]}),
        );
    }

    lib.root_module.linkSystemLibrary("xau", .{});

    lib.root_module.addCSourceFiles(.{
        .root = b.path(xcbgen_path),
        .files = &.{
            "xproto.c",
        },
    });
    for (protocol_file_names) |file_name| {
        lib.root_module.addCSourceFile(.{
            .file = b.path(b.fmt("{s}/{s}.c", .{ xcbgen_path, file_name[0 .. file_name.len - 4] })),
        });
    }
    lib.root_module.addIncludePath(b.path(xcbgen_path));
    var buf: [128]u8 = undefined;
    const iov_max_string = buf[0..std.fmt.printInt(&buf, std.posix.IOV_MAX, 10, .lower, .{})];
    lib.root_module.addCMacro("IOV_MAX", iov_max_string);

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("xcb.h",
            \\#include <xcb.h>
            \\#include <bigreq.h>
            \\#include <composite.h>
            \\#include <damage.h>
            \\#include <dbe.h>
            \\#include <dpms.h>
            \\#include <dri2.h>
            \\#include <dri3.h>
            \\#include <ge.h>
            \\#include <glx.h>
            \\#include <present.h>
            \\#include <randr.h>
            \\#include <record.h>
            \\#include <render.h>
            \\#include <res.h>
            \\#include <screensaver.h>
            \\#include <shape.h>
            \\#include <shm.h>
            \\#include <sync.h>
            \\#include <xc_misc.h>
            \\#include <xevie.h>
            \\#include <xf86dri.h>
            \\#include <xf86vidmode.h>
            \\#include <xfixes.h>
            \\#include <xinerama.h>
            \\#include <xinput.h>
            \\#include <xkb.h>
            \\#include <xprint.h>
            \\#include <xproto.h>
            \\#include <xselinux.h>
            \\#include <xtest.h>
            \\#include <xv.h>
            \\#include <xvmc.h>
        ),
        .target = target,
        .optimize = optimize,
    });
    for (lib.root_module.include_dirs.items) |include_dir| {
        translate_c.addIncludePath(include_dir.path);
    }

    const mod = b.addModule("xcb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = translate_c.createModule() },
        },
    });
    mod.linkLibrary(lib);

    b.installArtifact(lib);
}
