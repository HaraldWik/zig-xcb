#include <xcb/xcb.h>
#include <xcb/xproto.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

typedef struct App {
    xcb_connection_t *conn;
    xcb_screen_t *screen;
    xcb_window_t window;
    xcb_gcontext_t gc;

    xcb_atom_t wm_protocols;
    xcb_atom_t wm_delete_window;

    uint16_t width;
    uint16_t height;
    int running;

    uint32_t color_phase;
} App;

static xcb_atom_t intern_atom(xcb_connection_t *conn, const char *name) {
    xcb_intern_atom_cookie_t cookie =
        xcb_intern_atom(conn, 0, (uint16_t)strlen(name), name);

    xcb_intern_atom_reply_t *reply =
        xcb_intern_atom_reply(conn, cookie, NULL);

    if (!reply) {
        fprintf(stderr, "Failed to intern atom: %s\n", name);
        exit(1);
    }

    xcb_atom_t atom = reply->atom;
    free(reply);
    return atom;
}

static void set_window_title(App *app, const char *title) {
    xcb_change_property(
        app->conn,
        XCB_PROP_MODE_REPLACE,
        app->window,
        XCB_ATOM_WM_NAME,
        XCB_ATOM_STRING,
        8,
        (uint32_t)strlen(title),
        title
    );
}

static void setup_wm_delete(App *app) {
    app->wm_protocols = intern_atom(app->conn, "WM_PROTOCOLS");
    app->wm_delete_window = intern_atom(app->conn, "WM_DELETE_WINDOW");

    xcb_change_property(
        app->conn,
        XCB_PROP_MODE_REPLACE,
        app->window,
        app->wm_protocols,
        XCB_ATOM_ATOM,
        32,
        1,
        &app->wm_delete_window
    );
}

static uint32_t rgb(uint8_t r, uint8_t g, uint8_t b) {
    return ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}

static void clear(App *app, uint32_t color) {
    xcb_change_gc(app->conn, app->gc, XCB_GC_FOREGROUND, &color);

    xcb_rectangle_t rect = {
        .x = 0,
        .y = 0,
        .width = app->width,
        .height = app->height
    };

    xcb_poly_fill_rectangle(app->conn, app->window, app->gc, 1, &rect);
}

static void draw_rect(App *app, int x, int y, int w, int h, uint32_t color) {
    xcb_change_gc(app->conn, app->gc, XCB_GC_FOREGROUND, &color);

    xcb_rectangle_t rect = {
        .x = (int16_t)x,
        .y = (int16_t)y,
        .width = (uint16_t)w,
        .height = (uint16_t)h
    };

    xcb_poly_fill_rectangle(app->conn, app->window, app->gc, 1, &rect);
}

static void draw_scene(App *app) {
    clear(app, rgb(18, 18, 24));

    int cx = app->width / 2;
    int cy = app->height / 2;

    for (int i = 0; i < 8; i++) {
        int pad = i * 18;
        int w = app->width - pad * 2;
        int h = app->height - pad * 2;
        if (w <= 0 || h <= 0) break;

        uint8_t r = (uint8_t)((app->color_phase + i * 30) & 0xff);
        uint8_t g = (uint8_t)((app->color_phase * 2 + i * 20) & 0xff);
        uint8_t b = (uint8_t)((app->color_phase * 3 + i * 10) & 0xff);

        draw_rect(app, pad, pad, w, h, rgb(r, g, b));
    }

    draw_rect(app, cx - 100, cy - 20, 200, 40, rgb(240, 240, 240));
    draw_rect(app, cx - 90,  cy - 10, 180, 20, rgb(30, 30, 30));

    xcb_flush(app->conn);
}

static void init_app(App *app) {
    int screen_num = 0;
    app->conn = xcb_connect(NULL, &screen_num);

    if (xcb_connection_has_error(app->conn)) {
        fprintf(stderr, "Failed to connect to X server\n");
        exit(1);
    }

    const xcb_setup_t *setup = xcb_get_setup(app->conn);
    xcb_screen_iterator_t iter = xcb_setup_roots_iterator(setup);

    for (int i = 0; i < screen_num; i++) {
        xcb_screen_next(&iter);
    }

    app->screen = iter.data;
    app->width = 800;
    app->height = 500;
    app->running = 1;
    app->color_phase = 0;

    app->window = xcb_generate_id(app->conn);
    app->gc = xcb_generate_id(app->conn);

    uint32_t window_values[] = {
        app->screen->black_pixel,
        XCB_EVENT_MASK_EXPOSURE |
        XCB_EVENT_MASK_KEY_PRESS |
        XCB_EVENT_MASK_BUTTON_PRESS |
        XCB_EVENT_MASK_POINTER_MOTION |
        XCB_EVENT_MASK_STRUCTURE_NOTIFY
    };

    xcb_create_window(
        app->conn,
        XCB_COPY_FROM_PARENT,
        app->window,
        app->screen->root,
        100, 100,
        app->width, app->height,
        0,
        XCB_WINDOW_CLASS_INPUT_OUTPUT,
        app->screen->root_visual,
        XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK,
        window_values
    );

    uint32_t gc_values[] = {
        app->screen->white_pixel,
        0
    };

    xcb_create_gc(
        app->conn,
        app->gc,
        app->window,
        XCB_GC_FOREGROUND | XCB_GC_GRAPHICS_EXPOSURES,
        gc_values
    );

    set_window_title(app, "XCB Demo Window");
    setup_wm_delete(app);

    xcb_map_window(app->conn, app->window);
    xcb_flush(app->conn);
}

static void handle_key_press(App *app, xcb_key_press_event_t *ev) {
    printf("Key press: detail=%u\n", ev->detail);

    // Escape on many layouts is often keycode 9 in X11.
    if (ev->detail == 9) {
        app->running = 0;
        return;
    }

    app->color_phase += 17;
    draw_scene(app);
}

static void handle_button_press(App *app, xcb_button_press_event_t *ev) {
    printf("Mouse button %u at (%d, %d)\n", ev->detail, ev->event_x, ev->event_y);

    int size = 60;
    int x = ev->event_x - size / 2;
    int y = ev->event_y - size / 2;

    uint8_t r = (uint8_t)((ev->event_x * 3) & 0xff);
    uint8_t g = (uint8_t)((ev->event_y * 2) & 0xff);
    uint8_t b = (uint8_t)((app->color_phase * 5) & 0xff);

    draw_rect(app, x, y, size, size, rgb(r, g, b));
    xcb_flush(app->conn);
}

static void handle_motion(App *app, xcb_motion_notify_event_t *ev) {
    char title[128];
    snprintf(title, sizeof(title), "XCB Demo Window - mouse (%d, %d)", ev->event_x, ev->event_y);
    set_window_title(app, title);
    xcb_flush(app->conn);
}

static void handle_configure(App *app, xcb_configure_notify_event_t *ev) {
    app->width = ev->width;
    app->height = ev->height;
    printf("Resize: %ux%u\n", app->width, app->height);
    draw_scene(app);
}

static void handle_client_message(App *app, xcb_client_message_event_t *ev) {
    if (ev->type == app->wm_protocols &&
        ev->data.data32[0] == app->wm_delete_window) {
        app->running = 0;
    }
}

static void event_loop(App *app) {
    draw_scene(app);

    while (app->running) {
        xcb_generic_event_t *event = xcb_wait_for_event(app->conn);
        if (!event) {
            break;
        }

        uint8_t type = event->response_type & ~0x80;

        switch (type) {
            case XCB_EXPOSE:
                draw_scene(app);
                break;

            case XCB_KEY_PRESS:
                handle_key_press(app, (xcb_key_press_event_t *)event);
                break;

            case XCB_BUTTON_PRESS:
                handle_button_press(app, (xcb_button_press_event_t *)event);
                break;

            case XCB_MOTION_NOTIFY:
                handle_motion(app, (xcb_motion_notify_event_t *)event);
                break;

            case XCB_CONFIGURE_NOTIFY:
                handle_configure(app, (xcb_configure_notify_event_t *)event);
                break;

            case XCB_CLIENT_MESSAGE:
                handle_client_message(app, (xcb_client_message_event_t *)event);
                break;

            default:
                break;
        }

        free(event);
    }
}

static void cleanup(App *app) {
    if (app->conn) {
        xcb_free_gc(app->conn, app->gc);
        xcb_destroy_window(app->conn, app->window);
        xcb_disconnect(app->conn);
    }
}

int main(void) {
    App app = {0};

    init_app(&app);
    event_loop(&app);
    cleanup(&app);

    return 0;
}