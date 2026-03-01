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

// QWERTZ keyboard layout: one octave C4–C5
// White keys: A S D F G H J K → C4 D4 E4 F4 G4 A4 B4 C5
// Black keys: W E   T Z U     → C#4 D#4  F#4 G#4 A#4
const KeyMapping = struct { key: rl.KeyboardKey, freq: f32 };
const key_map = [_]KeyMapping{
    // White keys
    .{ .key = .a, .freq = 261.63 }, // C4
    .{ .key = .s, .freq = 293.66 }, // D4
    .{ .key = .d, .freq = 329.63 }, // E4
    .{ .key = .f, .freq = 349.23 }, // F4
    .{ .key = .g, .freq = 392.00 }, // G4
    .{ .key = .h, .freq = 440.00 }, // A4
    .{ .key = .j, .freq = 493.88 }, // B4
    .{ .key = .k, .freq = 523.25 }, // C5
    // Black keys
    .{ .key = .w, .freq = 277.18 }, // C#4
    .{ .key = .e, .freq = 311.13 }, // D#4
    .{ .key = .t, .freq = 369.99 }, // F#4
    .{ .key = .y, .freq = 415.30 }, // G#4 (QWERTZ "Z" is at US "Y" position)
    .{ .key = .u, .freq = 466.16 }, // A#4
};

pub fn main() void {
    rl.initWindow(400, 200, "pico-synth");
    defer rl.closeWindow();

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
    synth.voices[0].cutoff = 1500;
    synth.voices[0].setWaveform(.square);
    synth.voices[0].setADSR(0.01, 0.2, 0.5, 0.3);
    synth.voices[0].setLfoRate(10);
    synth.voices[0].setLfoDepth(0.5);

    rl.setAudioStreamCallback(stream, audioCallback);
    rl.playAudioStream(stream);

    rl.setTargetFPS(60);

    var active_key: ?rl.KeyboardKey = null;

    while (!rl.windowShouldClose()) {
        // Handle note-on/off via state-based checks (consistent within a frame)
        for (key_map) |km| {
            if (rl.isKeyPressed(km.key)) {
                synth.noteOn(0, km.freq);
                active_key = km.key;
            }
        }

        if (active_key) |ak| {
            if (rl.isKeyReleased(ak)) {
                synth.noteOff(0);
                active_key = null;
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);
        rl.drawText("QWERTZ keyboard => voice 0", 10, 10, 20, .dark_gray);
        rl.drawText("W E   T Z U     = sharps", 20, 40, 16, .gray);
        rl.drawText("A S D F G H J K = C4..C5", 10, 60, 16, .gray);
        rl.drawText("ESC to quit", 10, 170, 14, .light_gray);
    }
}
