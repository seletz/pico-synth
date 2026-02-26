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

    // Configure voice 0
    synth.master_gain = 1.0;
    synth.voices[0].gain = 0.5;
    synth.voices[0].setWaveform(.sine);
    synth.voices[0].setADSR(0.5, 0.2, 0.5, 0.8);

    synth.voices[1].gain = 0.5;
    synth.voices[1].setWaveform(.sine);
    synth.voices[1].setADSR(0.5, 0.2, 0.5, 0.8);

    rl.setAudioStreamCallback(stream, audioCallback);
    rl.playAudioStream(stream);

    std.debug.print("playing 440 Hz sine for 5 seconds...\n", .{});
    synth.noteOn(0, 440);
    synth.noteOn(1, 460);
    std.Thread.sleep(2 * std.time.ns_per_s);
    synth.noteOff(0);
    std.Thread.sleep(1 * std.time.ns_per_s);
    synth.noteOff(1);
    std.Thread.sleep(2 * std.time.ns_per_s);
    std.debug.print("done.\n", .{});
}
