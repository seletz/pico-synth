const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const peripherals = microzig.chip.peripherals;
const interrupt = microzig.cpu.interrupt;
const time = rp2xxx.time;

// Compile-time pin configuration for PicoCalc
const pin_config = rp2xxx.pins.GlobalConfiguration{
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

pub const timer = if (chip == .RP2040) peripherals.TIMER else peripherals.TIMER0;
const timer_irq = if (chip == .RP2040) .TIMER_IRQ_0 else .TIMER0_IRQ_0;

const TIMER_DELAY: u32 = 23; // 23us -> ca 43khz

const Duration = microzig.drivers.time.Duration;

pub const led_red = pins.led_red;
pub const led_green = pins.led_green;
pub const led_blue = pins.led_blue;
pub const led_yellow = pins.led_yellow;

pub fn writeSample(sample_r: f32, sample_l: f32) void {
    const pwm_r: u8 = @intFromFloat((sample_r + 1.0) * 127.5);
    const pwm_l: u8 = @intFromFloat((sample_l + 1.0) * 127.5);
    pins.pwm_r.set_level(pwm_r);
    pins.pwm_l.set_level(pwm_l);
}

pub fn setAlarm(us: u32) void {
    const current = time.get_time_since_boot();
    const target = current.add_duration(Duration.from_us(us));
    timer.ALARM0.write_raw(@intCast(@intFromEnum(target) & 0xffffffff));
}

pub fn rearmTimer() void {
    timer.INTR.modify(.{ .ALARM_0 = 1 });
    setAlarm(TIMER_DELAY);
}

pub fn getTimeSinceBoot() microzig.drivers.time.Absolute {
    return time.get_time_since_boot();
}

pub fn makeTimeout(ms: u32) microzig.drivers.time.Absolute {
    return microzig.drivers.time.make_timeout_us(time.get_time_since_boot(), ms * 1000);
}

pub fn init() void {
    pin_config.apply();

    pins.pwm_r.slice().set_wrap(0xff);
    pins.pwm_l.slice().set_wrap(0xff);
    pins.pwm_r.slice().enable();
    pins.pwm_l.slice().enable();
    timer.INTE.toggle(.{ .ALARM_0 = 1 });

    setAlarm(TIMER_DELAY);

    interrupt.enable(timer_irq);
    microzig.cpu.interrupt.enable_interrupts();
}
