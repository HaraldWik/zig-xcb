 has_error: c_int,

    xcb_setup_t *setup;
    int fd;

    pthread_mutex_t iolock;
    _xcb_in in;
    _xcb_out out;

    _xcb_ext ext;
    _xcb_xid xid;