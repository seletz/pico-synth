const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const blinky = mb.add_firmware(.{
        .name = "blinky",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/blinky/main.zig"),
    });

    const synth = mb.add_firmware(.{
        .name = "synth",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/synth/main.zig"),
    });

    mb.install_firmware(blinky, .{});
    mb.install_firmware(synth, .{});
}
