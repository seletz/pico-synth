const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const peripherals = microzig.chip.peripherals;
const interrupt = microzig.cpu.interrupt;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const clocks = rp2xxx.clocks;
const regs = microzig.chip.registers;
const multicore = rp2xxx.multicore;

const osc = @import("osc.zig");

// Compile-time pin configuration
const pin_config = rp2xxx.pins.GlobalConfiguration{
    // PicoCalc: GPIO2 is available on the connector on the right side.
    .GPIO2 = .{
        .name = "led_red",
        .direction = .out,
    },
    .GPIO3 = .{
        .name = "led_green",
        .direction = .out,
    },
    .GPIO4 = .{
        .name = "led_blue",
        .direction = .out,
    },
    .GPIO5 = .{
        .name = "led_yellow",
        .direction = .out,
    },
    .GPIO27 = .{
        .name = "pwm_r",
        .function = .PWM5_B,
    },
    .GPIO28 = .{ .name = "pwm_l", .function = .PWM6_A },
};
const pins = pin_config.pins();

const chip = rp2xxx.compatibility.chip;

const timer = if (chip == .RP2040) peripherals.TIMER else peripherals.TIMER0;
const timer_irq = if (chip == .RP2040) .TIMER_IRQ_0 else .TIMER0_IRQ_0;

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

const TIMER_DELAY: u32 = 23; // 23us -> ca 43khz

var sine_osc = osc.Osc{ .phase = 0.0, .freq = 440.0, .waveform = .sine };

fn timer_interrupt() callconv(.c) void {
    const cs = microzig.interrupt.enter_critical_section();
    defer cs.leave();

    const sample = sine_osc.next();
    const pwm_value: u8 = @intFromFloat((sample + 1.0) * 127.5);

    pins.pwm_r.set_level(pwm_value);
    pins.pwm_l.set_level(pwm_value);

    pins.led_blue.toggle();

    timer.INTR.modify(.{ .ALARM_0 = 1 });
    set_alarm(TIMER_DELAY);
}

pub fn set_alarm(us: u32) void {
    const Duration = microzig.drivers.time.Duration;
    const current = time.get_time_since_boot();
    const target = current.add_duration(Duration.from_us(us));

    timer.ALARM0.write_raw(@intCast(@intFromEnum(target) & 0xffffffff));
}

pub fn main() !void {
    pin_config.apply();

    pins.pwm_r.slice().set_wrap(0xff);
    pins.pwm_l.slice().set_wrap(0xff);
    timer.INTE.toggle(.{ .ALARM_0 = 1 });

    set_alarm(TIMER_DELAY);

    interrupt.enable(timer_irq);
    microzig.cpu.interrupt.enable_interrupts();

    while (true) {
        asm volatile ("wfi");
        pins.led_red.toggle();
    }
}
