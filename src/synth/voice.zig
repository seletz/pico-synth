const std = @import("std");

const osc = @import("osc.zig");
const filter = @import("filter.zig");
const env = @import("env.zig");

pub const Voice = struct {
    osc: osc.Osc = .{},
    lpf: filter.Biquad = .{},
    env: env.ADSREnv = .{},
    gain: f32 = 0.25,
    active: bool = false,
    age: u64 = 0,

    // Per-voice persistent settings (SID-style)
    attack: f32 = 0,
    decay: f32 = 0,
    sustain: f32 = 1.0,
    release_time: f32 = 0,
    cutoff: f32 = 20000,

    pub fn setADSR(self: *Voice, a: f32, d: f32, s: f32, r: f32) void {
        self.attack = a;
        self.decay = d;
        self.sustain = s;
        self.release_time = r;
    }

    pub fn setCutoff(self: *Voice, cutoff_freq: f32) void {
        self.cutoff = cutoff_freq;
        self.lpf.setLowpass(cutoff_freq, 1.0, 44100);
    }

    pub fn setWaveform(self: *Voice, waveform: @FieldType(osc.Osc, "waveform")) void {
        self.osc.waveform = waveform;
    }

    pub fn trigger(self: *Voice, freq: f32) void {
        self.osc.freq = freq;
        self.lpf.setLowpass(self.cutoff, 1.0, 44100);
        self.env.trigger(self.attack, self.decay, self.sustain, self.release_time, 44100);
        self.active = true;
        self.age = 0;
    }

    pub fn release(self: *Voice) void {
        self.env.release();
    }

    pub fn render(self: *Voice) f32 {
        if (!self.active) return 0;

        self.age += 1;

        const out = self.osc.next();
        const filtered = self.lpf.process(out);
        const shaped = filtered * self.env.next();

        if (self.env.stage == .idle) self.active = false;

        return shaped * self.gain;
    }
};
