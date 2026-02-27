const microzig = @import("microzig");
const rp2xxx = microzig.hal;

const synth_mod = @import("synth");
const notes = synth_mod.notes;
const board = @import("board.zig");

const chip = rp2xxx.compatibility.chip;

pub const rp2040_options: microzig.Options = .{
    .log_level = .debug,
    .logFn = rp2xxx.uart.log,
    .interrupts = .{ .TIMER_IRQ_0 = .{ .c = timer_interrupt } },
};

pub const rp2350_options: microzig.Options = .{
    .log_level = .debug,
    .logFn = rp2xxx.uart.log,
    .interrupts = .{ .TIMER0_IRQ_0 = .{ .c = timer_interrupt } },
};

pub const microzig_options = if (chip == .RP2040) rp2040_options else rp2350_options;

var synth = synth_mod.Synth{ .master_gain = 1.0 };

fn setup_synth() void {
    synth.master_gain = 1.0;
    synth.voices[0].gain = 0.5;
    synth.voices[0].setWaveform(.sine);
    synth.voices[0].setADSR(0.01, 0.2, 0.5, 0.3);
}

fn timer_interrupt() callconv(.c) void {
    const cs = microzig.interrupt.enter_critical_section();
    defer cs.leave();

    const sample = synth.render();
    board.writeSample(sample, sample);
    board.led_blue.toggle();
    board.rearmTimer();
}

pub fn main() !void {
    board.init();

    setup_synth();

    const note_rate = 500; // ms
    var note_timeout = board.makeTimeout(note_rate);

    while (true) {
        asm volatile ("wfi");
        board.led_red.toggle();

        var voice: usize = 0;

        if (note_timeout.is_reached_by(board.getTimeSinceBoot())) {
            note_timeout = board.makeTimeout(note_rate);
            board.led_green.toggle();

            synth.noteOff(voice);
            voice = (voice + 1) % 4;

            synth.noteOn(voice, notes.freq.A4);
        }
    }
}
