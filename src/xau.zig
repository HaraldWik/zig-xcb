const std = @import("std");

pub const Xauth = extern struct {
    family: u16,
    address_len: u16,
    address: ?[*]u8,
    number_len: u16,
    number: ?[*]u8,
    name_len: u16,
    name: ?[*]u8,
    data_len: u16,
    data: ?[*]u8,
};

fn secureZero(buf: []u8) void {
    const p: [*]volatile u8 = @ptrCast(buf.ptr);
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        p[i] = 0;
    }
}

pub export fn XauDisposeAuth(auth: ?*Xauth) void {
    const a = auth orelse return;
    std.c.free(a.address);
    std.c.free(a.number);
    std.c.free(a.name);
    secureZero(a.data.?[0..a.data_len]);
    std.c.free(a.data);
    std.c.free(a);
}

var xau_file_name: [std.posix.NAME_MAX]u8 = undefined;

pub fn XauFileName() ?[*:0]u8 {
    const slash_dot_xauthority = "/.Xauthority";

    if (std.c.getenv("XAUTHORITY")) |name| return name;

    const name: [:0]const u8 = std.mem.span(std.c.getenv("HOME") orelse return null);
    @memcpy(xau_file_name[0..name.len], name);
    @memcpy(xau_file_name[name.len..], slash_dot_xauthority);

    return xau_file_name[0 .. name.len + slash_dot_xauthority.len :0];
}

fn fail(local: *Xauth) ?*Xauth {
    XauDisposeAuth(local);
    return null;
}

pub fn XauReadAuth(auth_file: *std.c.FILE) ?*Xauth {
    var local = Xauth{
        .family = 0,
        .address_len = 0,
        .address = null,
        .number_len = 0,
        .number = null,
        .name_len = 0,
        .name = null,
        .data_len = 0,
        .data = null,
    };

    // --- read_short (family) ---
    {
        var buf: [2]u8 = undefined;
        if (std.c.fread(&buf, 1, 2, auth_file) != 2) return fail(&local);
        local.family = (@as(u16, buf[0]) << 8) | buf[1];
    }

    // --- read_counted_string (address) ---
    {
        var buf: [2]u8 = undefined;
        if (std.c.fread(&buf, 1, 2, auth_file) != 2) return fail(&local);
        local.address_len = (@as(u16, buf[0]) << 8) | buf[1];

        if (local.address_len > 0) {
            const ptr: ?[*]u8 = @ptrCast(std.c.malloc(local.address_len));
            if (ptr == null) return fail(&local);

            if (std.c.fread(ptr.?, 1, local.address_len, auth_file) != local.address_len) {
                std.c.free(ptr);
                return fail(&local);
            }

            local.address = ptr;
        }
    }

    // --- read_counted_string (number) ---
    {
        var buf: [2]u8 = undefined;
        if (std.c.fread(&buf, 1, 2, auth_file) != 2) return fail(&local);
        local.number_len = (@as(u16, buf[0]) << 8) | buf[1];

        if (local.number_len > 0) {
            const ptr: ?[*]u8 = @ptrCast(std.c.malloc(local.number_len));
            if (ptr == null) return fail(&local);

            if (std.c.fread(ptr.?, 1, local.number_len, auth_file) != local.number_len) {
                std.c.free(ptr);
                return fail(&local);
            }

            local.number = ptr;
        }
    }

    // --- read_counted_string (name) ---
    {
        var buf: [2]u8 = undefined;
        if (std.c.fread(&buf, 1, 2, auth_file) != 2) return fail(&local);
        local.name_len = (@as(u16, buf[0]) << 8) | buf[1];

        if (local.name_len > 0) {
            const ptr: [*]u8 = @ptrCast(std.c.malloc(local.name_len) orelse return fail(&local));

            if (std.c.fread(ptr, 1, local.name_len, auth_file) != local.name_len) {
                std.c.free(ptr);
                return fail(&local);
            }

            local.name = ptr;
        }
    }

    {
        var buf: [2]u8 = undefined;
        if (std.c.fread(&buf, 1, 2, auth_file) != 2) return fail(&local);
        local.data_len = (@as(u16, buf[0]) << 8) | buf[1];

        if (local.data_len > 0) {
            const ptr: [*]u8 = @ptrCast(std.c.malloc(local.name_len) orelse return fail(&local));

            if (std.c.fread(ptr, 1, local.data_len, auth_file) != local.data_len) {
                std.c.free(ptr);
                return fail(&local);
            }

            local.data = ptr;
        }
    }

    const ret: *Xauth = @ptrCast(@alignCast(std.c.malloc(@sizeOf(Xauth)) orelse return fail(&local)));
    ret.* = local;
    return ret;
}
pub export fn XauGetBestAuthByAddr(
    family: u16,
    address: ?[*]const u8,
    address_len: u16,
    number: ?[*]const u8,
    number_len: u16,
    types_len: c_int,
    types: [*]?[*]u8,
    type_lens: [*]const c_int,
) ?*Xauth {
    var best: ?*Xauth = null;
    var best_type: c_int = types_len;

    const auth_name = XauFileName() orelse return null;

    if (std.c.access(auth_name, std.c.R_OK) != 0) return null;

    const auth_file = std.c.fopen(auth_name, "rb") orelse return null;
    defer _ = std.c.fclose(auth_file);

    const family_wild: u16 = 0xFFFF;

    while (true) {
        const entry = XauReadAuth(auth_file) orelse break;

        const len_addr: usize = @intCast(address_len);
        const len_num: usize = @intCast(number_len);

        const match_family =
            (family == family_wild or entry.family == family_wild or
                (entry.family == family and
                    address_len == entry.address_len and
                    address != null and entry.address != null and
                    std.mem.eql(
                        u8,
                        entry.address.?[0..len_addr],
                        address.?[0..len_addr],
                    )));

        const match_number =
            (number_len == 0 or entry.number_len == 0 or
                (number_len == entry.number_len and
                    number != null and entry.number != null and
                    std.mem.eql(
                        u8,
                        entry.number.?[0..len_num],
                        number.?[0..len_num],
                    )));

        if (match_family and match_number) {
            if (best_type == 0) {
                best = entry;
                break;
            }

            var type_index: c_int = 0;
            while (type_index < best_type) : (type_index += 1) {
                const t = types[@intCast(type_index)];
                if (t != null and
                    type_lens[@intCast(type_index)] == entry.name_len and
                    entry.name != null and
                    std.mem.eql(
                        u8,
                        t.?[0..@intCast(entry.name_len)],
                        entry.name.?[0..@intCast(entry.name_len)],
                    ))
                {
                    break;
                }
            }

            if (type_index < best_type) {
                if (best != null) XauDisposeAuth(best);
                best = entry;
                best_type = type_index;

                if (type_index == 0) break;
                continue;
            }
        }

        XauDisposeAuth(entry);
    }

    return best;
}
