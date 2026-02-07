const std = @import("std");

const Osc = struct {
    phase: f32 = 0,
    freq: f32 = 440,
    sample_rate: f32 = 44100,
    waveform: enum { sine, saw, square, tri } = .sine,

    pub fn next(self: *Osc) f32 {
        const out = switch (self.waveform) {
            .sine => @sin(self.phase * std.math.tau),
            .saw => 2.0 * self.phase - 1.0,
            .square => if (self.phase < 0.5) 1.0 else -1.0,
            .tri => 1.0 - 4.0 * @abs(self.phase - 0.5),
        };

        self.phase += self.freq / self.sample_rate;
        if (self.phase >= 1.0) self.phase -= 1.0;
        return out;
    }
};
