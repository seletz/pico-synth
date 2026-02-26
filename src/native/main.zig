const std = @import("std");
const rl = @import("raylib");

fn audioCallback(_: ?*anyopaque, _: c_uint) callconv(.c) void {
    // silence — nothing to do
}

pub fn main() void {
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const stream = rl.loadAudioStream(44100, 32, 1) catch {
        std.debug.print("failed to load audio stream\n", .{});
        return;
    };
    defer rl.unloadAudioStream(stream);

    rl.setAudioStreamCallback(stream, audioCallback);
    rl.playAudioStream(stream);

    std.debug.print("playing silence for 3 seconds...\n", .{});
    std.Thread.sleep(3 * std.time.ns_per_s);
    std.debug.print("done.\n", .{});
}
