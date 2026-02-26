const std = @import("std");
const synth_mod = @import("synth");

pub fn main() void {
    const sample_rate: f32 = 44100;
    const freq: f32 = 440;

    // Sine peak is at phase = 0.25 (sin(pi/2) = 1.0).
    // Phase advances by freq/sample_rate per sample.
    // The oscillator outputs sin(phase * tau) BEFORE advancing, so
    // sample N has phase = N * freq / sample_rate.
    const period = sample_rate / freq;
    const quarter_period = period / 4.0;
    const peak_sample: u32 = @intFromFloat(@round(quarter_period));

    std.debug.print("--- Sine peak test ---\n", .{});
    std.debug.print("freq={d:.1} Hz  sample_rate={d:.0}  period={d:.2} samples\n", .{ freq, sample_rate, period });
    std.debug.print("expected peak near sample {d} (quarter_period={d:.2})\n\n", .{ peak_sample, quarter_period });

    var s = synth_mod.Synth{};

    // Set gains to unity
    s.master_gain = 1.0;

    // Trigger voice 0: transparent envelope (A=0, D=0, S=1, R=0), high cutoff
    s.noteOn(freq, 20000.0, 0, 0, 1.0, 0);

    // Set voice gain to unity (noteOn uses voice 0 since all are free)
    s.voices[0].gain = 1.0;

    // Render samples around the expected peak
    const window = 5;
    const start = peak_sample - window;
    const end = peak_sample + window;

    std.debug.print("sample | value\n", .{});
    std.debug.print("-------+-----------\n", .{});

    var max_val: f32 = -1.0;
    var max_idx: u32 = 0;

    for (0..end + 1) |i| {
        const sample = s.render();
        if (i >= start) {
            const marker: u8 = if (i == peak_sample) '*' else ' ';
            std.debug.print("{d:5}  | {d: >10.6} {c}\n", .{ i, sample, marker });
        }
        if (sample > max_val) {
            max_val = sample;
            max_idx = @intCast(i);
        }
    }

    std.debug.print("\nactual peak: sample {d}, value {d:.6}\n", .{ max_idx, max_val });
}
