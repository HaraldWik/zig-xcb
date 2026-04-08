const std = @import("std");

pub const Connection = struct {
    has_error: c_int,

    setup: *xproto.Setup,
    fd: c_int,

    //     /* I/O data */
    iolock: std.c.pthread_mutex_t,
    //     _xcb_in in;
    //     _xcb_out out;

    //     /* misc data */
    //     _xcb_ext ext;
    //     _xcb_xid xid;

    pub fn connect(display_name: ?[*:0]const u8, screenp: ?*c_int) *Connection {
        return ffi.xcb_connect(display_name, screenp);
    }
    pub fn disconnect(c: *Connection) void {
        ffi.xcb_disconnect(c);
    }
};

pub const Header = packed struct {
    major_opcode: u8,
    minor_opcode: u8, // usually 0 if not an extension sub-op
    length: u16, // in 4-byte units
};

const ffi = struct {
    extern fn xcb_connect(display_name: ?[*:0]const u8, screenp: ?*c_int) *Connection;
    extern fn xcb_disconnect(c: *Connection) void;
};

pub const Timestamp = enum(u32) {
    _,
};

pub const VisualId = enum(u32) {
    _,
};

pub const Drawable = extern union {
    window: Window,
    pixmap: Pixmap,
};
