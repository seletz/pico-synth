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

// Compile-time pin configuration
const pin_config = rp2xxx.pins.GlobalConfiguration{
    // PicoCalc: GPIO2 is available on the connector on the right side.
    .GPIO2 = .{
        .name = "led",
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

fn timer_interrupt() callconv(.c) void {
    const cs = microzig.interrupt.enter_critical_section();
    defer cs.leave();

    pins.led.toggle();

    timer.INTR.modify(.{ .ALARM_0 = 1 });
    set_alarm(1_000_000);
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
}
