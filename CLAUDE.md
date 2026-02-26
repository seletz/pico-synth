# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pico-synth is an FM synthesizer written in Zig targeting the Raspberry Pi Pico 2W (RP2350, ARM). The development platform is the PicoCalc by ClockworkPi with a Pico 2W module installed.

## Build Commands

Tool versions are managed by [mise](https://mise.jdx.dev). Current toolchain: Zig 0.15.2.

- `zig build` — build both firmware targets (blinky and synth), outputs UF2 files to `zig-out/firmware/`
- `mise run clean` — remove `zig-out/`
- `mise run build` — same as `zig build`
- `mise run burn` — build, copy UF2 files to SD card at `/Volumes/NO NAME/pico2-apps`, then unmount

There is no test suite. The build itself is the primary validation step.

## Dependencies

- **MicroZig** — embedded Zig framework for RP2xxx. Referenced as a **local path dependency** at `../microzig` (sibling directory). This must be present for the build to work.

## Architecture

### Build System

`build.zig` defines two firmware targets, both compiled with `ReleaseSmall` for the `pico2_arm` board:
- **blinky** (`src/blinky/main.zig`) — LED test program for hardware validation
- **synth** (`src/synth/main.zig`) — the synthesizer firmware

### Synth Audio Pipeline

The signal flow is: **Oscillator → Filter → Envelope → Gain**, computed per-sample (no buffering).

| Module | File | Role |
|--------|------|------|
| Oscillator | `src/synth/osc.zig` | Phase-accumulator with sine/saw/square/triangle waveforms |
| Filter | `src/synth/filter.zig` | Biquad IIR filter (lowpass/highpass/bandpass) with Butterworth and self-oscillating modes |
| Envelope | `src/synth/env.zig` | ADSR and AR envelope generators as state machines |
| Voice | `src/synth/voice.zig` | Chains osc→filter→env→gain for one monophonic voice |
| Synth | `src/synth/synth.zig` | 4-voice polyphonic manager with quietest-voice stealing |

### Hardware I/O (PicoCalc)

- **Audio output**: PWM on GPIO27 (right) and GPIO28 (left), 8-bit, ~43 kHz sample rate via timer interrupt
- **LEDs**: GPIO2 (red), GPIO3 (green), GPIO4 (blue), GPIO5 (yellow)
- Shared state between main loop and timer ISR is protected with MicroZig critical sections

### Reference Material

`context/synth-fundamentals.md` contains detailed audio synthesis theory (oscillators, filters, envelopes, voice allocation) with Zig code examples. Consult this when implementing new DSP features.
