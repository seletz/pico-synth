# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pico-synth is an FM synthesizer written in Zig targeting the Raspberry Pi Pico 2W (RP2350, ARM). The development platform is the PicoCalc by ClockworkPi with a Pico 2W module installed.

## Build Commands

Tool versions are managed by [mise](https://mise.jdx.dev). Current toolchain: Zig 0.15.2.

- `zig build` — build all targets: firmware (UF2 to `zig-out/firmware/`) and native desktop binary (`zig-out/bin/synth-native`)
- `mise run clean` — remove `zig-out/`
- `mise run build` — same as `zig build`
- `mise run burn` — build, copy UF2 files to SD card at `/Volumes/NO NAME/pico2-apps`, then unmount

There is no test suite. The build itself is the primary validation step.

## Dependencies

All external dependencies are **local path references** to sibling directories:

- **MicroZig** (`../microzig`) — embedded Zig framework for RP2xxx (firmware targets)
- **raylib-zig** (`../raylib-zig`) — Zig bindings for raylib (native target)
- **raylib** (`../raylib`) — raylib C source, cloned for reference/debugging

## Architecture

### Build System

`build.zig` defines three targets:

Firmware (compiled with `ReleaseSmall` for `pico2_arm`):
- **blinky** (`src/blinky/main.zig`) — LED test program for hardware validation
- **synth** (`src/synth/main.zig`) — the synthesizer firmware

Native desktop (uses raylib for audio + window + input):
- **synth-native** (`src/native/main.zig`) — desktop development build with raylib audio callback and keyboard input

### Synth Audio Pipeline

The signal flow is: **Oscillator → Filter → Envelope → Gain**, computed per-sample (no buffering).

| Module | File | Role |
|--------|------|------|
| Oscillator | `src/synth/osc.zig` | Phase-accumulator with sine/saw/square/triangle waveforms |
| Filter | `src/synth/filter.zig` | Biquad IIR filter (lowpass/highpass/bandpass) with Butterworth and self-oscillating modes |
| Envelope | `src/synth/env.zig` | ADSR and AR envelope generators as state machines |
| Voice | `src/synth/voice.zig` | Chains osc→filter→env→gain for one monophonic voice |
| Synth | `src/synth/synth.zig` | 4-voice polyphonic manager with quietest-voice stealing |

### Native Desktop Target

`src/native/main.zig` provides an interactive desktop version using raylib:
- Audio via raylib audio stream callback at 44100 Hz, 32-bit float, mono
- Window with game loop (`initWindow` / `beginDrawing` / `endDrawing`)
- Keyboard input maps one octave (C4–C5) to voice 0

**GLFW keyboard on macOS**: raylib bundles GLFW which uses a hardcoded scancode table (`cocoa_init.m:createKeyTablesCocoa`) mapping macOS virtual keycodes to US QWERTY key positions. On a QWERTZ keyboard, Z and Y are physically swapped — use `.y` for the key labeled "Z" and vice versa.

### Hardware I/O (PicoCalc)

- **Audio output**: PWM on GPIO27 (right) and GPIO28 (left), 8-bit, ~43 kHz sample rate via timer interrupt
- **LEDs**: GPIO2 (red), GPIO3 (green), GPIO4 (blue), GPIO5 (yellow)
- Shared state between main loop and timer ISR is protected with MicroZig critical sections

### Reference Material

`context/synth-fundamentals.md` contains detailed audio synthesis theory (oscillators, filters, envelopes, voice allocation) with Zig code examples. Consult this when implementing new DSP features.
