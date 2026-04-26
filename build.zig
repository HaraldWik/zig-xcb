const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xcb = b.dependency("xcb", .{});
    const xproto = b.dependency("xproto", .{});

    const python = b.findProgram(&.{"python3"}, &.{"python"}) catch @panic("could locate python3");

    const c_client = b.pathFromRoot("src/c_client.py");

    var required_protocols_buffer: [protocols.len][:0]const u8 = undefined;
    var required_protocols: std.ArrayList([:0]const u8) = .initBuffer(&required_protocols_buffer);

    outter: for (protocols) |protocol| {
        for (core_protocols) |core| {
            if (std.mem.eql(u8, protocol, core)) {
                required_protocols.appendAssumeCapacity(protocol);
                continue :outter;
            }
        }

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
        .XCB_QUEUE_BUFFER_SIZE = 1024,
        .IOV_MAX = std.posix.IOV_MAX,
    });

    libxcb.installConfigHeader(config_header);
    libxcb.root_module.addCMacro("HAVE_CONFIG_H", "1");
    libxcb.root_module.addIncludePath(config_header.getOutputFile().dirname());

    // libxcb.root_module.addCMacro("XCB_QUEUE_BUFFER_SIZE", "1024");
    // libxcb.root_module.addCMacro("IOV_MAX", "1024");

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

    libxcb.root_module.addIncludePath(xcb.path("src/"));
    libxcb.installHeadersDirectory(xcb.path("src/"), "xcb/", .{});

    const xcbgen = b.addWriteFiles().getDirectory();

    for (required_protocols.items) |protocol| {
        const run = b.addSystemCommand(&.{ python, c_client });
        run.addFileArg(xproto.path("src/").path(b, b.fmt("{s}.xml", .{protocol})));
        run.setCwd(xcbgen);
        run.setEnvironmentVariable("PYTHONPATH", xproto.builder.pathFromRoot("."));

        libxcb.step.dependOn(&run.step);

        libxcb.root_module.addCSourceFile(.{ .file = xcbgen.path(b, b.fmt("{s}.c", .{protocol})) });
    }

    libxcb.root_module.addIncludePath(xcbgen);
    libxcb.installHeadersDirectory(xcbgen, "xcb/", .{});

    libxcb.root_module.linkLibrary(libxau);

    b.installArtifact(libxcb);

    // xcb.h
    // xcb_windefs.h
    // xcbext.h
    // xcbint.h
}

pub const core_protocols: []const [:0]const u8 = &.{
    "bigreq",
    "xc_misc",
    "xproto",
};

pub const protocols: []const [:0]const u8 = &.{
    "bigreq",
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
    "xc_misc",
    "xevie",
    "xf86dri",
    "xf86vidmode",
    "xfixes",
    "xinerama",
    "xinput",
    "xkb",
    "xprint",
    "xproto",
    "xselinux",
    "xtest",
    "xv",
    "xvmc",
};
