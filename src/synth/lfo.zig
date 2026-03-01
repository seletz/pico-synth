const std = @import("std");

pub const Waveform = enum { sine, saw, square, tri };

pub const Lfo = struct {
    phase: f32 = 0,
    freq: f32 = 1.0,
    sample_rate: f32 = 44100,
    waveform: Waveform = .sine,
    depth: f32 = 0.0,
    retrigger: bool = false,

    /// Advance phase and return modulation value in range [-depth, +depth].
    /// When depth is 0, returns 0 immediately (no modulation cost).
    pub fn next(self: *Lfo) f32 {
        if (self.depth == 0) {
            // Still advance phase so waveform stays in sync
            self.phase += self.freq / self.sample_rate;
            if (self.phase >= 1.0) self.phase -= 1.0;
            return 0;
        }

        const raw: f32 = switch (self.waveform) {
            .sine => @sin(self.phase * std.math.tau),
            .saw => 2.0 * self.phase - 1.0,
            .square => if (self.phase < 0.5) @as(f32, 1.0) else @as(f32, -1.0),
            .tri => 1.0 - 4.0 * @abs(self.phase - 0.5),
        };

        self.phase += self.freq / self.sample_rate;
        if (self.phase >= 1.0) self.phase -= 1.0;

        return raw * self.depth;
    }

    /// Reset phase to 0 if retrigger is enabled.
    pub fn trigger(self: *Lfo) void {
        if (self.retrigger) self.phase = 0;
    }

    /// Modulate a base cutoff frequency by an LFO value.
    /// Returns clamp(base * (1 + lfo_value), 20, 20000).
    pub fn modulateCutoff(base: f32, lfo_value: f32) f32 {
        return std.math.clamp(base * (1.0 + lfo_value), 20.0, 20000.0);
    }
};

// ── Tests ────────────────────────────────────────────────────────────

const testing = std.testing;

test "zero depth produces zero output" {
    var l = Lfo{ .depth = 0.0, .freq = 5.0 };
    for (0..100) |_| {
        try testing.expectEqual(@as(f32, 0.0), l.next());
    }
}

test "zero depth still advances phase" {
    var l = Lfo{ .depth = 0.0, .freq = 5.0 };
    _ = l.next();
    try testing.expect(l.phase > 0);
}

test "sine waveform bounds" {
    var l = Lfo{ .depth = 1.0, .freq = 1.0, .sample_rate = 100, .waveform = .sine };
    for (0..200) |_| {
        const v = l.next();
        try testing.expect(v >= -1.0 and v <= 1.0);
    }
}

test "saw waveform bounds" {
    var l = Lfo{ .depth = 1.0, .freq = 1.0, .sample_rate = 100, .waveform = .saw };
    for (0..200) |_| {
        const v = l.next();
        try testing.expect(v >= -1.0 and v <= 1.0);
    }
}

test "square waveform bounds" {
    var l = Lfo{ .depth = 1.0, .freq = 1.0, .sample_rate = 100, .waveform = .square };
    for (0..200) |_| {
        const v = l.next();
        try testing.expect(v == 1.0 or v == -1.0);
    }
}

test "tri waveform bounds" {
    var l = Lfo{ .depth = 1.0, .freq = 1.0, .sample_rate = 100, .waveform = .tri };
    for (0..200) |_| {
        const v = l.next();
        try testing.expect(v >= -1.0 and v <= 1.0);
    }
}

test "depth scales output" {
    var full = Lfo{ .depth = 1.0, .freq = 1.0, .sample_rate = 100, .waveform = .sine };
    var half = Lfo{ .depth = 0.5, .freq = 1.0, .sample_rate = 100, .waveform = .sine };
    for (0..100) |_| {
        const f = full.next();
        const h = half.next();
        try testing.expectApproxEqAbs(f * 0.5, h, 1e-6);
    }
}

test "retrigger resets phase" {
    var l = Lfo{ .depth = 1.0, .freq = 1.0, .sample_rate = 100, .retrigger = true };
    // Advance a few samples
    for (0..25) |_| _ = l.next();
    try testing.expect(l.phase > 0);
    l.trigger();
    try testing.expectEqual(@as(f32, 0.0), l.phase);
}

test "no retrigger keeps phase" {
    var l = Lfo{ .depth = 1.0, .freq = 1.0, .sample_rate = 100, .retrigger = false };
    for (0..25) |_| _ = l.next();
    const phase_before = l.phase;
    l.trigger();
    try testing.expectEqual(phase_before, l.phase);
}

test "modulateCutoff basic" {
    // No modulation
    try testing.expectApproxEqAbs(1000.0, Lfo.modulateCutoff(1000, 0), 1e-3);
    // Positive modulation
    try testing.expectApproxEqAbs(1500.0, Lfo.modulateCutoff(1000, 0.5), 1e-3);
    // Negative modulation
    try testing.expectApproxEqAbs(500.0, Lfo.modulateCutoff(1000, -0.5), 1e-3);
}

test "modulateCutoff clamps to bounds" {
    // Deep negative should clamp to 20
    try testing.expectEqual(@as(f32, 20.0), Lfo.modulateCutoff(100, -2.0));
    // Deep positive should clamp to 20000
    try testing.expectEqual(@as(f32, 20000.0), Lfo.modulateCutoff(15000, 1.0));
}
