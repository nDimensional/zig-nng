const std = @import("std");
const nng = @import("nng");

const url = "ipc:///Users/joelgustafson/Projects/zig-nng/socket";

pub fn main() !void {
    nng.setLogger(.SYSTEM);

    const pub_thread = try std.Thread.spawn(.{}, run_pub, .{});
    const sub_thread = try std.Thread.spawn(.{}, run_sub, .{});

    sub_thread.join();
    pub_thread.join();

    // const rep_thread = try std.Thread.spawn(.{}, run_rep, .{});
    // const req_thread = try std.Thread.spawn(.{}, run_req, .{});

    // req_thread.join();
    // rep_thread.join();
}

fn run_pub() !void {
    const sock = try nng.Socket.PUB.open();
    defer sock.close();

    try sock.listen(url);

    var i: u32 = 0;
    while (true) : (i += 1) {
        const msg = try nng.Message.init(4);
        std.mem.writeInt(u32, msg.body()[0..4], i, .big);

        std.log.info("[pub] sending message: {s}", .{std.fmt.fmtSliceHexLower(msg.body())});
        try sock.send(msg, .{});
        std.posix.nanosleep(1, 0);
    }
}

fn run_sub() !void {
    const sock = try nng.Socket.SUB.open();
    defer sock.close();

    try sock.set(nng.Options.SUB.SUBSCRIBE, "");

    std.posix.nanosleep(3, 0);

    try sock.dial(url);

    while (true) {
        const msg = try sock.recv(.{});
        defer msg.deinit();
        std.log.info("[sub] received message: {s}", .{std.fmt.fmtSliceHexLower(msg.body())});
    }
}

fn run_rep() !void {
    std.log.warn("SERVER", .{});

    const sock = try nng.Socket.REP.open();
    defer sock.close();

    try sock.listen(url);

    const msg = try sock.recv(.{});
    defer msg.deinit();

    const msg_dupe = try msg.dupe();
    errdefer msg_dupe.deinit();
    try sock.send(msg_dupe, .{});
}

fn run_req() !void {
    std.log.warn("CLIENT", .{});

    const sock = try nng.Socket.REQ.open();
    defer sock.close();

    std.posix.nanosleep(1, 0);

    try sock.dial(url);

    {
        const msg = try nng.Message.init(8);
        errdefer msg.deinit();

        const body = msg.body();
        try std.testing.expectEqual(body.len, 8);

        std.mem.writeInt(u64, body[0..8], std.math.maxInt(u64), .big);
        try sock.send(msg, .{});
    }

    {
        const msg = try sock.recv(.{});
        defer msg.deinit();

        const body = msg.body();
        try std.testing.expectEqual(body.len, 8);
        try std.testing.expectEqual(
            std.math.maxInt(u64),
            std.mem.readInt(u64, body[0..8], .big),
        );
    }
}
