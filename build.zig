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

    const synth_module = b.createModule(.{
        .root_source_file = b.path("src/synth/synth.zig"),
    });

    const synth = mb.add_firmware(.{
        .name = "synth",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/pico-synth/main.zig"),
        .imports = &.{
            .{ .name = "synth", .module = synth_module },
        },
    });

    mb.install_firmware(blinky, .{});
    mb.install_firmware(synth, .{});

    // Native macOS build for testing DSP code without hardware
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = b.resolveTargetQuery(.{}),
        .optimize = .Debug,
    });
    const native = b.addExecutable(.{
        .name = "synth-native",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/native/main.zig"),
            .target = b.resolveTargetQuery(.{}),
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "synth", .module = synth_module },
                .{ .name = "raylib", .module = raylib_dep.module("raylib") },
            },
        }),
    });
    native.linkLibrary(raylib_dep.artifact("raylib"));
    b.installArtifact(native);

    // Unit tests for synth DSP modules
    const synth_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/synth/synth.zig"),
            .target = b.resolveTargetQuery(.{}),
            .optimize = .Debug,
        }),
    });
    const run_tests = b.addRunArtifact(synth_tests);
    const test_step = b.step("test", "Run synth unit tests");
    test_step.dependOn(&run_tests.step);
}
