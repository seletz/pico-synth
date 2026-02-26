const std = @import("std");
const synth_mod = @import("synth");

pub fn main() void {
    var s = synth_mod.Synth{};

    // Trigger a note: A4 (440 Hz), cutoff 2000 Hz, attack 0.01s, decay 0.1s
    s.noteOn(440.0, 2000.0, 0.01, 0.1);

    std.debug.print("sample | value\n", .{});
    std.debug.print("-------+--------\n", .{});

    for (0..20) |i| {
        const sample = s.render();
        std.debug.print("{d:5}  | {d:.6}\n", .{ i, sample });
    }
}
