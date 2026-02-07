const std = @import("std");

const osc = @import("osc.zig");
const filter = @import("filter.zig");
const env = @import("env.zig");

const Voice = struct {
    osc: osc.Osc = .{},
    lpf: filter.Biquad = .{},
    env: env.ADSREnv = .{},
    gain: f32 = 0.25,
    active: bool = false,
    age: u64 = 0,

    pub fn trigger(self: *Voice, freq: f32, cutoff: f32, attack: f32, decay: f32) void {
        self.osc.freq = freq;
        self.lpf.setLowpass(cutoff, 1.0, 44100);
        self.env.trigger(attack, decay, 44100);
        self.active = true;
        self.age = 0;
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
