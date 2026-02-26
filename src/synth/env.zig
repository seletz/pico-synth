const std = @import("std");

pub const ADSREnv = struct {
    stage: enum { idle, attack, decay, sustain, release } = .idle,
    level: f32 = 0,

    attack_rate: f32 = 0,
    decay_rate: f32 = 0,
    sustain_level: f32 = 0,
    release_rate: f32 = 0,

    pub fn trigger(self: *ADSREnv, a: f32, d: f32, s: f32, r: f32, sample_rate: f32) void {
        self.attack_rate = if (a <= 0) 1.0 else 1.0 / (a * sample_rate);
        self.decay_rate = if (d <= 0 or s >= 1.0) 0.0 else (1.0 - s) / (d * sample_rate);
        self.sustain_level = s;
        self.release_rate = if (r <= 0) 1.0 else s / (r * sample_rate);
        self.stage = .attack;
        // Keep current level to avoid click on re-trigger during release
    }

    pub fn release(self: *ADSREnv) void {
        self.stage = .release;
    }

    pub fn next(self: *ADSREnv) f32 {
        switch (self.stage) {
            .idle => return 0,

            .attack => {
                self.level += self.attack_rate;
                if (self.level >= 1.0) {
                    self.level = 1.0;
                    self.stage = .decay;
                }
            },

            .decay => {
                self.level -= self.decay_rate;
                if (self.level <= self.sustain_level) {
                    self.level = self.sustain_level;
                    self.stage = .sustain;
                }
            },

            .sustain => {}, // hold until release called

            .release => {
                self.level -= self.release_rate;
                if (self.level <= 0) {
                    self.level = 0;
                    self.stage = .idle;
                }
            },
        }
        return self.level;
    }
};

const testing = std.testing;

test "ADSR state machine transitions" {
    var env = ADSREnv{};

    // Starts idle
    try testing.expectEqual(.idle, env.stage);
    try testing.expect(env.next() == 0);

    // Trigger: attack=0.01s, decay=0.01s, sustain=0.5, release=0.01s @ 1000 Hz
    env.trigger(0.01, 0.01, 0.5, 0.01, 1000);
    try testing.expectEqual(.attack, env.stage);

    // Attack: 0.01s * 1000 Hz = 10 samples to reach 1.0
    for (0..9) |_| {
        _ = env.next();
    }
    try testing.expectEqual(.attack, env.stage);
    _ = env.next(); // sample 10 should hit 1.0
    try testing.expectEqual(.decay, env.stage);
    try testing.expect(env.level == 1.0);

    // Decay: from 1.0 to sustain 0.5, rate = 0.5/10 = 0.05/sample → 10 samples
    for (0..9) |_| {
        _ = env.next();
    }
    try testing.expectEqual(.decay, env.stage);
    _ = env.next(); // sample 10 should reach sustain
    try testing.expectEqual(.sustain, env.stage);
    try testing.expect(env.level == 0.5);

    // Sustain holds indefinitely
    for (0..100) |_| {
        _ = env.next();
    }
    try testing.expectEqual(.sustain, env.stage);
    try testing.expect(env.level == 0.5);

    // Release: from 0.5 to 0, rate = 0.5/10 = 0.05/sample → 10 samples
    env.release();
    try testing.expectEqual(.release, env.stage);
    for (0..9) |_| {
        _ = env.next();
    }
    try testing.expectEqual(.release, env.stage);
    _ = env.next(); // sample 10 should hit 0
    try testing.expectEqual(.idle, env.stage);
    try testing.expect(env.level == 0);
}

test "ADSR instant attack when attack time is zero" {
    var env = ADSREnv{};
    env.trigger(0, 0.01, 0.5, 0.01, 1000);

    // First sample should jump to 1.0 and transition to decay
    _ = env.next();
    try testing.expectEqual(.decay, env.stage);
    try testing.expect(env.level == 1.0);
}

test "ADSR skips decay when sustain is 1.0" {
    var env = ADSREnv{};
    env.trigger(0.01, 0.01, 1.0, 0.01, 1000);

    // Run through attack (10 samples)
    for (0..10) |_| _ = env.next();
    try testing.expectEqual(.decay, env.stage);
    // decay_rate is 0 when sustain >= 1.0, so first decay sample transitions immediately
    _ = env.next();
    try testing.expectEqual(.sustain, env.stage);
    try testing.expect(env.level == 1.0);
}

test "ADSR re-trigger during release does not click (level must not jump to zero)" {
    var env = ADSREnv{};

    // Trigger with short times @ 1000 Hz
    env.trigger(0.01, 0.01, 0.5, 0.02, 1000);

    // Run through attack (10 samples) + decay (10 samples) → sustain
    for (0..20) |_| _ = env.next();
    try testing.expectEqual(.sustain, env.stage);

    // Release — run a few samples so level drops but is still > 0
    env.release();
    for (0..5) |_| _ = env.next();
    try testing.expectEqual(.release, env.stage);
    const level_before_retrigger = env.level;
    try testing.expect(level_before_retrigger > 0);

    // Re-trigger while still releasing
    env.trigger(0.01, 0.01, 0.5, 0.02, 1000);

    // Level must not drop below where it was — that would be a click
    try testing.expect(env.level >= level_before_retrigger);
}

pub const AREnv = struct {
    stage: enum { idle, attack, release } = .idle,
    level: f32 = 0,
    attack_rate: f32 = 0,
    release_rate: f32 = 0,

    pub fn trigger(self: *AREnv, attack: f32, decay: f32, sample_rate: f32) void {
        self.attack_rate = 1.0 / (attack * sample_rate);
        self.release_rate = 1.0 / (decay * sample_rate);
        self.stage = .attack;
    }

    pub fn next(self: *AREnv) f32 {
        switch (self.stage) {
            .idle => return 0,
            .attack => {
                self.level += self.attack_rate;
                if (self.level >= 1.0) {
                    self.level = 1.0;
                    self.stage = .release;
                }
            },
            .release => {
                self.level -= self.release_rate;
                if (self.level <= 0) {
                    self.level = 0;
                    self.stage = .idle;
                }
            },
        }
        return self.level;
    }
};
