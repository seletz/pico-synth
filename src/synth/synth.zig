const std = @import("std");
const voice = @import("voice.zig");
pub const notes = @import("notes.zig");
pub const osc = @import("osc.zig");
pub const lfo = @import("lfo.zig");

const testing = std.testing;

pub const Synth = struct {
    voices: [4]voice.Voice = [_]voice.Voice{.{}} ** 4,
    master_gain: f32 = 0.8,

    pub fn noteOn(self: *Synth, voice_idx: usize, freq: f32) void {
        self.voices[voice_idx].trigger(freq);
    }

    pub fn noteOff(self: *Synth, voice_idx: usize) void {
        self.voices[voice_idx].release();
    }

    pub fn render(self: *Synth) f32 {
        var mix: f32 = 0;
        for (&self.voices) |*v| mix += v.render();
        return std.math.clamp(mix * self.master_gain, -1.0, 1.0);
    }

    pub fn setLfoRate(self: *Synth, voice_idx: usize, rate: f32) void {
        self.voices[voice_idx].setLfoRate(rate);
    }

    pub fn setLfoDepth(self: *Synth, voice_idx: usize, depth: f32) void {
        self.voices[voice_idx].setLfoDepth(depth);
    }

    pub fn setLfoWaveform(self: *Synth, voice_idx: usize, waveform: lfo.Waveform) void {
        self.voices[voice_idx].setLfoWaveform(waveform);
    }
};

test "sine peak at quarter period" {
    var s = Synth{};
    s.master_gain = 1.0;
    // Transparent envelope (instant attack, full sustain, no release), high cutoff
    s.voices[0].gain = 1.0;
    s.noteOn(0, 440);

    // Sine peak at quarter period: round(44100 / 440 / 4) = 25
    const peak_sample: usize = 25;
    var peak_value: f32 = 0;
    for (0..peak_sample + 1) |i| {
        const sample = s.render();
        if (i == peak_sample) {
            peak_value = sample;
        }
    }
    try testing.expect(peak_value >= 0.99);
}
