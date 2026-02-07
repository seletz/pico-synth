const std = @import("std");

pub const ADSREnv = struct {
    stage: enum { idle, attack, decay, sustain, release } = .idle,
    level: f32 = 0,

    attack_rate: f32 = 0,
    decay_rate: f32 = 0,
    sustain_level: f32 = 0,
    release_rate: f32 = 0,

    pub fn trigger(self: *ADSREnv, a: f32, d: f32, s: f32, r: f32, sample_rate: f32) void {
        self.attack_rate = 1.0 / (a * sample_rate);
        self.decay_rate = (1.0 - s) / (d * sample_rate);
        self.sustain_level = s;
        self.release_rate = s / (r * sample_rate);
        self.stage = .attack;
        self.level = 0;
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
