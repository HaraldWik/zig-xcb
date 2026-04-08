const std = @import("std");
const xcb = @cImport({
    @cInclude("xcb/xcb.h");
});

pub fn main() !void {
    // Connect to the X server
    var screen_index: c_int = 0;
    const connection = xcb.xcb_connect(null, &screen_index);
    if (xcb.xcb_connection_has_error(connection) != 0) {
        return error.XcbConnect;
    }
    defer xcb.xcb_disconnect(connection);

    const setup = xcb.xcb_get_setup(connection);
    var iter = xcb.xcb_setup_roots_iterator(setup);
    var screen: *xcb.xcb_screen_t = undefined;
    for (0..@intCast(screen_index)) |_| {
        xcb.xcb_screen_next(&iter);
    }
    screen = iter.data orelse return error.XcbUnsupported;

    const window: xcb.xcb_window_t = xcb.xcb_generate_id(connection);

    const mask: u32 = xcb.XCB_CW_BACK_PIXEL | xcb.XCB_CW_EVENT_MASK;
    const values: [2]u32 = [_]u32{
        screen.*.white_pixel,
        xcb.XCB_EVENT_MASK_EXPOSURE | xcb.XCB_EVENT_MASK_KEY_PRESS,
    };

    _ = xcb.xcb_create_window(
        connection,
        xcb.XCB_COPY_FROM_PARENT, // depth
        window, // window ID
        screen.*.root, // parent
        0,
        0, // x, y
        400,
        300, // width, height
        10, // border width
        xcb.XCB_WINDOW_CLASS_INPUT_OUTPUT, // class
        screen.*.root_visual, // visual
        mask,
        &values[0],
    );

    // Map the window on screen
    _ = xcb.xcb_map_window(connection, window);
    _ = xcb.xcb_flush(connection);

    std.debug.print("Window created on screen {}\n", .{screen_index});

    // Simple blocking event loop
    var event: ?*xcb.xcb_generic_event_t = null;
    while (true) {
        event = xcb.xcb_wait_for_event(connection);
        if (event == null) break;

        const ev_code = event.?.response_type & 0x7f;
        if (ev_code == xcb.XCB_EXPOSE) {
            // Handle expose/redraw if needed
        } else if (ev_code == xcb.XCB_KEY_PRESS) {
            break; // exit on key press
        }
    }
}
