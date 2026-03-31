pub const Connection = struct {
    has_error: c_int,

    setup: *xproto.Setup,
    //     int fd;

    //     /* I/O data */
    //     pthread_mutex_t iolock;
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

pub const ffi = struct {
    extern fn xcb_connect(display_name: ?[*:0]const u8, screenp: ?*c_int) *Connection;
    extern fn xcb_disconnect(c: *Connection) void;
};

pub const BOOL = bool;

pub const INT8 = i8;
pub const INT16 = i16;
pub const INT32 = i32;

pub const CARD8 = u8;
pub const CARD16 = u16;
pub const CARD32 = u32;
