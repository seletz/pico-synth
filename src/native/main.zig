const std = @import("std");
const rl = @import("raylib");
const synth_mod = @import("synth");

var synth = synth_mod.Synth{};

fn audioCallback(buffer: ?*anyopaque, frames: c_uint) callconv(.c) void {
    const samples: [*]f32 = @ptrCast(@alignCast(buffer));
    for (0..frames) |i| {
        samples[i] = synth.render();
    }
}

pub fn main() void {
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const stream = rl.loadAudioStream(44100, 32, 1) catch {
        std.debug.print("failed to load audio stream\n", .{});
        return;
    };
    defer rl.unloadAudioStream(stream);

    // Unity gain, envelope
    synth.master_gain = 1.0;
    const voice = synth.noteOn(440, 20000, 0.5, 0.2, 0.5, 0.8);
    synth.voices[0].gain = 1.0;

    rl.setAudioStreamCallback(stream, audioCallback);
    rl.playAudioStream(stream);

    std.debug.print("playing 440 Hz sine for 5 seconds...\n", .{});
    std.Thread.sleep(2 * std.time.ns_per_s);
    synth.voices[voice].env.release();
    std.Thread.sleep(3 * std.time.ns_per_s);
    std.debug.print("done.\n", .{});
}
