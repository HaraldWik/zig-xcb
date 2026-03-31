const std = @import("std");
const xcb = @import("xcb");

pub fn main() !void {
    var connection = xcb.Connection.connect(null, null);
    defer connection.disconnect();
}

// pub fn main() !void {

//     // Connect to X server
//     const connection = xcb.xcb_connect(null, null);
//     if (xcb.xcb_connection_has_error(connection) != 0) return error.Connect;
//     defer xcb.xcb_disconnect(connection);

//     // Get first screen
//     const setup = xcb.xcb_get_setup(connection);
//     const screen_iter = xcb.xcb_setup_roots_iterator(setup);
//     const screen = screen_iter.data;

//     // Create a simple window
//     const window = xcb.xcb_generate_id(connection);
//     const width: u16 = 400;
//     const height: u16 = 300;

//     _ = xcb.xcb_create_window(
//         connection,
//         screen.*.root_depth,
//         window,
//         screen.*.root,
//         0,
//         0,
//         width,
//         height,
//         10,
//         xcb.XCB_WINDOW_CLASS_INPUT_OUTPUT,
//         screen.*.root_visual,
//         0,
//         null,
//     );

//     // Set window title
//     const title = "Zig XCB Window";
//     _ = xcb.xcb_change_property(
//         connection,
//         xcb.XCB_PROP_MODE_REPLACE,
//         window,
//         xcb.XCB_ATOM_WM_NAME,
//         xcb.XCB_ATOM_STRING,
//         8,
//         @intCast(title.len),
//         title.ptr,
//     );

//     // Set up WM_DELETE_WINDOW so the window manager close button works
//     const wm_protocols_atom = xcb.xcb_intern_atom_reply(connection, xcb.xcb_intern_atom(connection, 0, 12, "WM_PROTOCOLS"), null).?.*.atom;
//     const wm_delete_window_atom = xcb.xcb_intern_atom_reply(connection, xcb.xcb_intern_atom(connection, 0, 16, "WM_DELETE_WINDOW"), null).?.*.atom;

//     var ev = [_]u32{wm_delete_window_atom};
//     _ = xcb.xcb_change_property(
//         connection,
//         xcb.XCB_PROP_MODE_REPLACE,
//         window,
//         wm_protocols_atom,
//         4, // format
//         32, // data length
//         1,
//         &ev,
//     );

//     _ = xcb.xcb_map_window(connection, window);
//     _ = xcb.xcb_flush(connection);

//     std.debug.print("Window created! Polling events...\n", .{});

//     var running: bool = true;
//     while (running) {
//         var event = xcb.xcb_poll_for_event(connection);
//         while (event != null) : (event = xcb.xcb_poll_for_event(connection)) {
//             const ev_type = event.*.response_type & 0x7f;
//             switch (ev_type) {
//                 xcb.XCB_EXPOSE => std.debug.print("Window exposed!\n", .{}),
//                 xcb.XCB_KEY_PRESS => {
//                     std.debug.print("Key pressed, exiting...\n", .{});
//                     running = false;
//                 },
//                 xcb.XCB_CLIENT_MESSAGE => {
//                     const cm: *xcb.xcb_client_message_event_t = @ptrCast(event);
//                     if (cm.*.data.data32[0] == wm_delete_window_atom) {
//                         std.debug.print("Window close requested, exiting...\n", .{});
//                         running = false;
//                     }
//                 },
//                 else => {},
//             }
//             std.c.free(event);
//         }
//         _ = xcb.xcb_flush(connection);
//     }
// }
