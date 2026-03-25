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

    // std.Io.Dir.createDirAbsolute(b.graph.io, b.pathJoin(&.{ b.build_root.path orelse "", "zig-pkg/xcbgen" }), .default_dir) catch |err| switch (err) {
    //     error.PathAlreadyExists => {},
    //     else => std.debug.panic("create dir xcbgen in zig-pkg: {s}", .{@errorName(err)}),
    // };

    for (protocol_file_names) |file_name| {
        const xcbgen = xproto_dep.builder.build_root.path orelse ".";
        const c_client_python_script = b.pathJoin(&.{ b.build_root.path orelse ".", "src/c_client.py" });

        const xproto_cmd = b.addSystemCommand(&.{ python, c_client_python_script });
        xproto_cmd.setEnvironmentVariable("PYTHONPATH", xcbgen);
        xproto_cmd.addFileArg(xproto_dep.builder.path(xproto_dep.builder.pathJoin(&.{ "src/", file_name })));
        xproto_cmd.setCwd(b.path("zig-pkg/xcbgen"));
        xcbgen_step.dependOn(&xproto_cmd.step);
    }

    const lib = b.addLibrary(.{
        .name = "xcb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
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

    lib.installHeader(b.path("src/xcb.h"), "xcb/xcb.h");
    lib.installHeader(b.path("src/xcbext.h"), "xcb/xcbext.h");
    lib.installHeader(b.path("src/xcbint.h"), "xcb/xcbint.h");
    lib.installHeader(b.path("src/xcb_windefs.h"), "xcb/xcb_windefs.h");

    lib.root_module.linkSystemLibrary("xau", .{});

    // lib.root_module.addIncludePath(h_file.dirname());
    lib.root_module.addCSourceFiles(.{
        .root = b.path("zig-pkg/xcbgen/"),
        .files = &.{
            "xproto.c",
        },
    });
    for (protocol_file_names) |file_name| {
        lib.root_module.addCSourceFile(.{
            .file = b.path(b.fmt("zig-pkg/xcbgen/{s}.c", .{file_name[0 .. file_name.len - 4]})),
        });
    }
    lib.root_module.addIncludePath(b.path("zig-pkg/xcbgen/"));
    lib.root_module.addCMacro("XCB_QUEUE_BUFFER_SIZE", "1028");
    var buf: [128]u8 = undefined;
    const iov_max_string = buf[0..std.fmt.printInt(&buf, std.posix.IOV_MAX, 10, .lower, .{})];
    lib.root_module.addCMacro("IOV_MAX", iov_max_string);

    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addCSourceFile(.{ .file = b.path("example/main.c") });
    exe.root_module.addIncludePath(b.path("src/"));
    exe.root_module.addIncludePath(b.path("zig-pkg/xcbgen/"));

    // exe.root_module.linkSystemLibrary("xcb", .{});

    exe.root_module.linkLibrary(lib);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
