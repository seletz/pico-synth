const std = @import("std");
const microzig = @import("microzig");

const rtt = microzig.cpu.rtt;
const rtt_inst = rtt.RTT(.{ .linker_section = ".rtt" });
var rtt_logger: ?rtt_inst.Writer = null;

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime "[{}.{:0>6}] " ++ level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (rtt_logger) |writer| {
        const current_time = microzig.hal.time.get_time_since_boot();
        const seconds = current_time.to_us() / std.time.us_per_s;
        const microseconds = current_time.to_us() % std.time.us_per_s;

        writer.print(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};
    }
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

// pub const microzig_options = microzig.Options{
//     .log_level = .debug,
//     .logFn = log,
// };

pub fn main() !void {
    // rtt_inst.init();
    // rtt_logger = rtt_inst.writer(0);

    std.log.info("debugtest: hello from RTT!", .{});
    std.log.info("debugtest: hitting breakpoint now", .{});

    // Loop with RTT output — test RTT first, then breakpoints
    var i: u32 = 0;
    while (true) : (i += 1) {
        std.log.info("debugtest: iteration {}", .{i});
        microzig.hal.time.sleep_ms(1000);

        // if (i == 5) {
        //     std.log.info("debugtest: hitting breakpoint now", .{});
        //     microzig.hal.time.sleep_ms(100);
        //     @breakpoint();
        // }
    }
}
