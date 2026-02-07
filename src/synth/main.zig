const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

const synth = @import("synth.zig");

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
};

pub fn main() !void {
    pin_config.apply();
    const pins = pin_config.pins();

    var count: u4 = 0;

    while (true) {
        if ((count & 0x1) == 0) {
            pins.led_red.toggle();
        }
        if ((count & 0x2) == 0) {
            pins.led_green.toggle();
        }
        if ((count & 0x4) == 0) {
            pins.led_yellow.toggle();
        }
        if ((count & 0x8) == 0) {
            pins.led_blue.toggle();
        }

        count += 1;

        time.sleep_ms(100);
    }
}
