const std = @import("std");

const Quality = struct { butterworth: f32 = 0.707, classic: f32 = 5, screaming: f32 = 10 };

const Biquad = struct {
    // Coefficients
    b0: f32 = 1,
    b1: f32 = 0,
    b2: f32 = 0,
    a1: f32 = 0,
    a2: f32 = 0,

    // State (previous samples)
    x1: f32 = 0,
    x2: f32 = 0, // input history
    y1: f32 = 0,
    y2: f32 = 0, // output history

    pub fn process(self: *Biquad, x0: f32) f32 {
        const y0 = self.b0 * x0 + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2;

        self.x2 = self.x1;
        self.x1 = x0;
        self.y2 = self.y1;
        self.y1 = y0;

        return y0;
    }

    pub fn setLowpass(self: *Biquad, cutoff: f32, q: f32, sample_rate: f32) void {
        const omega = std.math.tau * cutoff / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / (2.0 * q);

        const a0 = 1.0 + alpha;

        self.b0 = ((1.0 - cos_omega) / 2.0) / a0;
        self.b1 = (1.0 - cos_omega) / a0;
        self.b2 = self.b0;
        self.a1 = (-2.0 * cos_omega) / a0;
        self.a2 = (1.0 - alpha) / a0;
    }

    pub fn setHighpass(self: *Biquad, cutoff: f32, q: f32, sample_rate: f32) void {
        const omega = std.math.tau * cutoff / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / (2.0 * q);

        const a0 = 1.0 + alpha;

        self.b0 = ((1.0 + cos_omega) / 2.0) / a0;
        self.b1 = (-(1.0 + cos_omega)) / a0;
        self.b2 = self.b0;
        self.a1 = (-2.0 * cos_omega) / a0;
        self.a2 = (1.0 - alpha) / a0;
    }

    pub fn setBandpass(self: *Biquad, center: f32, q: f32, sample_rate: f32) void {
        const omega = std.math.tau * center / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / (2.0 * q);

        const a0 = 1.0 + alpha;

        self.b0 = alpha / a0;
        self.b1 = 0;
        self.b2 = -alpha / a0;
        self.a1 = (-2.0 * cos_omega) / a0;
        self.a2 = (1.0 - alpha) / a0;
    }
};
