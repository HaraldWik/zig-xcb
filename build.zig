const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xcb = b.dependency("xcb", .{});
    const xproto = b.dependency("xproto", .{});
    const xcb_util = b.dependency("xcb_util", .{});

    const python = b.findProgram(&.{"python3"}, &.{"python"}) catch @panic("could locate python3");

    const c_client = b.pathFromRoot("src/c_client.py");

    var required_protocols = std.ArrayList([:0]const u8).initCapacity(b.allocator, core_protocols.len + protocols.len) catch @panic("OOM");
    defer required_protocols.deinit(b.allocator);
    required_protocols.appendSliceAssumeCapacity(core_protocols);

    for (protocols) |protocol| {
        const option = b.option(bool, protocol, protocol) orelse false;
        if (option) required_protocols.appendAssumeCapacity(protocol);
    }

    const libxau = b.addLibrary(.{
        .name = "Xau",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/xau.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const libxcb = b.addLibrary(.{
        .name = "xcb",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const config_header = b.addConfigHeader(.{ .include_path = "config.h" }, .{
        .XCB_QUEUE_BUFFER_SIZE = b.option(i64, "queue_buffer_size", "queue buffer size") orelse 1024,
        .IOV_MAX = std.posix.IOV_MAX,
    });

    libxcb.installConfigHeader(config_header);
    libxcb.root_module.addCMacro("HAVE_CONFIG_H", "1");
    libxcb.root_module.addIncludePath(config_header.getOutputFile().dirname());

    libxcb.root_module.addCSourceFiles(.{
        .root = xcb.path("src/"),
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

    const xcbgen = b.addWriteFiles().getDirectory();

    for (required_protocols.items) |protocol| {
        const run = b.addSystemCommand(&.{ python, c_client });
        run.addFileArg(xproto.path("src/").path(b, b.fmt("{s}.xml", .{protocol})));
        run.setCwd(xcbgen);
        run.setEnvironmentVariable("PYTHONPATH", xproto.builder.pathFromRoot("."));

        libxcb.step.dependOn(&run.step);

        libxcb.root_module.addCSourceFile(.{ .file = xcbgen.path(b, b.fmt("{s}.c", .{protocol})) });
    }

    libxcb.root_module.addIncludePath(xcb.path("src/"));
    libxcb.installHeadersDirectory(xcb.path("src/"), "xcb/", .{});

    libxcb.root_module.addIncludePath(xcbgen);

    const icccm = b.option(bool, "icccm", "whether to enable the ICCCM library") orelse false;
    if (icccm) {
        libxcb.root_module.addCSourceFile(.{ .file = xcb_util.path("icccm/icccm.c") });
        libxcb.root_module.addIncludePath(xcb_util.path("icccm/"));
    }

    libxcb.root_module.linkLibrary(libxau);

    b.installArtifact(libxcb);

    const translate = b.option(bool, "translate_c", "adds a module named 'xcb' which will include all the declerations in zig") orelse false;
    if (!translate) return;

    var allocating = std.Io.Writer.Allocating.init(b.allocator);
    defer allocating.deinit();
    const writer = &allocating.writer;
    writer.writeAll("#include <xcb.h>\n") catch {};
    for (required_protocols.items) |protocol|
        writer.print("#include <{s}.h>\n", .{protocol}) catch {};
    if (icccm) writer.writeAll("#include <xcb_icccm.h>\n") catch {};

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("xcb.h", writer.buffered()),
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(xcb.path("src/"));
    translate_c.addIncludePath(xcbgen);
    if (icccm) translate_c.addIncludePath(xcb_util.path("icccm/"));

    const mod = b.addModule("xcb", .{
        .root_source_file = translate_c.getOutput(),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.linkLibrary(libxcb);
}

pub const core_protocols: []const [:0]const u8 = &.{
    "bigreq",
    "xc_misc",
    "xproto",
};

pub const protocols: []const [:0]const u8 = &.{
    "composite",
    "damage",
    "dbe",
    "dpms",
    "dri2",
    "dri3",
    "ge",
    "glx",
    "present",
    "randr",
    "record",
    "render",
    "res",
    "screensaver",
    "shape",
    "shm",
    "sync",
    "xevie",
    "xf86dri",
    "xf86vidmode",
    "xfixes",
    "xinerama",
    "xinput",
    "xkb",
    "xprint",
    "xselinux",
    "xtest",
    "xv",
    "xvmc",
};
