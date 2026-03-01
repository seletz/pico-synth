const std = @import("std");

const osc = @import("osc.zig");
const filter = @import("filter.zig");
const env = @import("env.zig");
const lfo_mod = @import("lfo.zig");

pub const Voice = struct {
    osc: osc.Osc = .{},
    lpf: filter.Biquad = .{},
    env: env.ADSREnv = .{},
    lfo: lfo_mod.Lfo = .{},
    gain: f32 = 0.25,
    active: bool = false,
    age: u64 = 0,

    // Per-voice persistent settings (SID-style)
    attack: f32 = 0,
    decay: f32 = 0,
    sustain: f32 = 1.0,
    release_time: f32 = 0,
    cutoff: f32 = 20000,

    // LFO filter modulation throttle
    mod_counter: u32 = 0,
    mod_interval: u32 = 64,

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
        self.lfo.trigger();
        self.mod_counter = 0;
        self.active = true;
        self.age = 0;
    }

    pub fn release(self: *Voice) void {
        self.env.release();
    }

    pub fn setLfoRate(self: *Voice, rate: f32) void {
        self.lfo.freq = rate;
    }

    pub fn setLfoDepth(self: *Voice, depth: f32) void {
        self.lfo.depth = depth;
    }

    pub fn setLfoWaveform(self: *Voice, waveform: lfo_mod.Waveform) void {
        self.lfo.waveform = waveform;
    }

    pub fn render(self: *Voice) f32 {
        if (!self.active) return 0;

        self.age += 1;

        // Tick LFO every sample (cheap: phase increment + waveform math)
        const lfo_value = self.lfo.next();

        // Throttled filter update: recompute biquad coefficients every mod_interval samples
        self.mod_counter += 1;
        if (self.mod_counter >= self.mod_interval) {
            const modulated_cutoff = lfo_mod.Lfo.modulateCutoff(self.cutoff, lfo_value);
            self.lpf.setLowpass(modulated_cutoff, 1.0, 44100);
            self.mod_counter = 0;
        }

        const out = self.osc.next();
        const filtered = self.lpf.process(out);
        const shaped = filtered * self.env.next();

        if (self.env.stage == .idle) self.active = false;

        return shaped * self.gain;
    }
};
