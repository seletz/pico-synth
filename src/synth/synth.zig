const std = @import("std");
const voice = @import("voice.zig");

pub const Synth = struct {
    voices: [4]voice.Voice = [_]voice.Voice{.{}} ** 4,
    master_gain: f32 = 0.8,

    pub fn noteOn(self: *Synth, freq: f32, cutoff: f32, attack: f32, decay: f32, sustain: f32, release: f32) void {
        const idx = self.findFreeVoice();
        self.voices[idx].trigger(freq, cutoff, attack, decay, sustain, release);
    }

    fn findFreeVoice(self: *Synth) usize {
        // First: find inactive voice
        for (self.voices, 0..) |v, i| {
            if (!v.active) return i;
        }
        // All busy: steal quietest
        var quietest: usize = 0;
        var min_level: f32 = 1.0;
        for (self.voices, 0..) |v, i| {
            if (v.env.level < min_level) {
                min_level = v.env.level;
                quietest = i;
            }
        }
        return quietest;
    }

    pub fn render(self: *Synth) f32 {
        var mix: f32 = 0;
        for (&self.voices) |*v| mix += v.render();
        return std.math.clamp(mix * self.master_gain, -1.0, 1.0);
    }
};
