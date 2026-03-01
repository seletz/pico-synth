const std = @import("std");
const rl = @import("raylib");
const synth_mod = @import("synth");

var synth = synth_mod.Synth{};

// LFO state (mutable so keyboard controls can adjust)
var lfo_rate: f32 = 2.0;
var lfo_depth: f32 = 0.5;
var lfo_waveform_idx: u8 = 0;
const waveform_names = [_][*:0]const u8{ "sine", "tri", "saw", "square" };
const waveform_values = [_]synth_mod.lfo.Waveform{ .sine, .tri, .saw, .square };

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
    rl.initWindow(400, 300, "pico-synth");
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
    synth.setLfoRate(0, lfo_rate);
    synth.setLfoDepth(0, lfo_depth);
    synth.setLfoWaveform(0, waveform_values[lfo_waveform_idx]);

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

        // LFO controls: 1/2 = rate, 3/4 = depth, 5 = waveform
        if (rl.isKeyPressed(.one)) {
            lfo_rate = @max(0.1, lfo_rate - 0.5);
            synth.setLfoRate(0, lfo_rate);
        }
        if (rl.isKeyPressed(.two)) {
            lfo_rate = @min(20.0, lfo_rate + 0.5);
            synth.setLfoRate(0, lfo_rate);
        }
        if (rl.isKeyPressed(.three)) {
            lfo_depth = @max(0.0, lfo_depth - 0.1);
            synth.setLfoDepth(0, lfo_depth);
        }
        if (rl.isKeyPressed(.four)) {
            lfo_depth = @min(1.0, lfo_depth + 0.1);
            synth.setLfoDepth(0, lfo_depth);
        }
        if (rl.isKeyPressed(.five)) {
            lfo_waveform_idx = (lfo_waveform_idx + 1) % @as(u8, waveform_values.len);
            synth.setLfoWaveform(0, waveform_values[lfo_waveform_idx]);
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);
        rl.drawText("QWERTZ keyboard => voice 0", 10, 10, 20, .dark_gray);
        rl.drawText("W E   T Z U     = sharps", 20, 40, 16, .gray);
        rl.drawText("A S D F G H J K = C4..C5", 10, 60, 16, .gray);

        // LFO status display
        var rate_buf: [32]u8 = undefined;
        const rate_str = std.fmt.bufPrintZ(&rate_buf, "LFO rate:  {d:.1} Hz  [1/2]", .{lfo_rate}) catch "?";
        rl.drawText(rate_str, 10, 100, 16, .dark_blue);

        var depth_buf: [32]u8 = undefined;
        const depth_str = std.fmt.bufPrintZ(&depth_buf, "LFO depth: {d:.1}     [3/4]", .{lfo_depth}) catch "?";
        rl.drawText(depth_str, 10, 120, 16, .dark_blue);

        var wave_buf: [32]u8 = undefined;
        const wave_str = std.fmt.bufPrintZ(&wave_buf, "LFO wave:  {s}      [5]", .{waveform_names[lfo_waveform_idx]}) catch "?";
        rl.drawText(wave_str, 10, 140, 16, .dark_blue);

        rl.drawText("ESC to quit", 10, 270, 14, .light_gray);
    }
}
