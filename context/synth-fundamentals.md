# Synth Fundamentals

A primer on digital audio synthesis. Simple building blocks that chain together.

## Audio Timing

You need to output ~44,100 samples per second with consistent timing. The OS scheduler doesn't care about your audio — it'll pause your process for 10ms to handle something else. That's 441 samples of silence, audible as a click.

### The Solution: Buffers

Don't output sample-by-sample. Fill buffers ahead of time; a dedicated audio thread drains them at constant rate.

```
Your code          Audio system         Hardware
    │                   │                   │
    │  fill buffer      │                   │
    │ ─────────────────>│                   │
    │                   │  drain to DAC     │
    │                   │ ─────────────────>│
    │  fill next buffer │                   │
    │ ─────────────────>│                   │
```

The audio system maintains a ring buffer. Stay ahead of playback position. As long as you fill faster than it drains, you're fine.

### Buffer Size Tradeoff

| Size | Latency | Difficulty |
|------|---------|------------|
| 2048+ samples | ~50ms | Easy to fill in time |
| 64-256 samples | ~1-6ms | Must fill fast, miss one = glitch |

For ambient work, large buffers are fine.

## Oscillator

The foundation. Generates a periodic waveform.

```zig
const SineOsc = struct {
    phase: f32 = 0,
    freq: f32 = 440,
    sample_rate: f32 = 44100,

    pub fn next(self: *SineOsc) f32 {
        const sample = @sin(self.phase * std.math.tau);
        self.phase += self.freq / self.sample_rate;
        if (self.phase >= 1.0) self.phase -= 1.0;
        return sample;
    }
};
```

`phase` goes 0→1 over one cycle. At 440 Hz with 44100 sample rate, it increments by `440/44100 ≈ 0.01` per sample. After ~100 samples, one full cycle.

### Other Waveforms

Same phase accumulator, different output calculation:

```zig
const Osc = struct {
    phase: f32 = 0,
    freq: f32 = 440,
    sample_rate: f32 = 44100,
    waveform: enum { sine, saw, square, tri } = .sine,

    pub fn next(self: *Osc) f32 {
        const out = switch (self.waveform) {
            .sine => @sin(self.phase * std.math.tau),
            .saw => 2.0 * self.phase - 1.0,
            .square => if (self.phase < 0.5) 1.0 else -1.0,
            .tri => 1.0 - 4.0 * @abs(self.phase - 0.5),
        };
        
        self.phase += self.freq / self.sample_rate;
        if (self.phase >= 1.0) self.phase -= 1.0;
        return out;
    }
};
```

## Filters

Attenuate certain frequencies. The **cutoff frequency** is where attenuation begins.

### One-Pole LPF (Simplest)

```zig
const LPF = struct {
    prev: f32 = 0,
    coeff: f32 = 0.1,

    pub fn process(self: *LPF, input: f32) f32 {
        self.prev = self.prev + self.coeff * (input - self.prev);
        return self.prev;
    }
};

fn calcCoeff(cutoff_hz: f32, sample_rate: f32) f32 {
    const rc = 1.0 / (cutoff_hz * std.math.tau);
    const dt = 1.0 / sample_rate;
    return dt / (rc + dt);
}
```

Just exponential smoothing. High frequencies (rapid changes) get smoothed out. Low frequencies pass through.

Limitations: only -6 dB/octave rolloff, no resonance.

### Biquad Filter (The Workhorse)

Two-pole, two-zero filter. -12 dB/octave rolloff, can have resonance.

```zig
const Biquad = struct {
    // Coefficients
    b0: f32 = 1, b1: f32 = 0, b2: f32 = 0,
    a1: f32 = 0, a2: f32 = 0,
    
    // State (previous samples)
    x1: f32 = 0, x2: f32 = 0,  // input history
    y1: f32 = 0, y2: f32 = 0,  // output history

    pub fn process(self: *Biquad, x0: f32) f32 {
        const y0 = self.b0 * x0 
                 + self.b1 * self.x1 
                 + self.b2 * self.x2
                 - self.a1 * self.y1 
                 - self.a2 * self.y2;

        self.x2 = self.x1;
        self.x1 = x0;
        self.y2 = self.y1;
        self.y1 = y0;

        return y0;
    }
    
    pub fn setLowpass(self: *Biquad, cutoff: f32, q: f32, sample_rate: f32) void {
        const omega = std.math.tau * cutoff / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / (2.0 * q);

        const a0 = 1.0 + alpha;
        
        self.b0 = ((1.0 - cos_omega) / 2.0) / a0;
        self.b1 = (1.0 - cos_omega) / a0;
        self.b2 = self.b0;
        self.a1 = (-2.0 * cos_omega) / a0;
        self.a2 = (1.0 - alpha) / a0;
    }
    
    pub fn setHighpass(self: *Biquad, cutoff: f32, q: f32, sample_rate: f32) void {
        const omega = std.math.tau * cutoff / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / (2.0 * q);

        const a0 = 1.0 + alpha;
        
        self.b0 = ((1.0 + cos_omega) / 2.0) / a0;
        self.b1 = (-(1.0 + cos_omega)) / a0;
        self.b2 = self.b0;
        self.a1 = (-2.0 * cos_omega) / a0;
        self.a2 = (1.0 - alpha) / a0;
    }
    
    pub fn setBandpass(self: *Biquad, center: f32, q: f32, sample_rate: f32) void {
        const omega = std.math.tau * center / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / (2.0 * q);

        const a0 = 1.0 + alpha;

        self.b0 = alpha / a0;
        self.b1 = 0;
        self.b2 = -alpha / a0;
        self.a1 = (-2.0 * cos_omega) / a0;
        self.a2 = (1.0 - alpha) / a0;
    }
};
```

**Q** (quality factor) controls resonance:
- Q = 0.707: Butterworth, flat passband, no resonance
- Q = 2-10: Audible peak at cutoff, classic synth sweep
- Q > 10: Self-oscillation, filter screams

### Biquad is Universal

Same structure, different coefficients:

| Filter Type | What It Does |
|-------------|--------------|
| Lowpass | Passes below cutoff |
| Highpass | Passes above cutoff |
| Bandpass | Passes around center |
| Notch | Removes around center |
| Peaking EQ | Boosts/cuts around center |
| Shelving | Boosts/cuts above/below cutoff |

## Envelope (ADSR)

Shapes amplitude over time. No buffer needed — just state.

```
level
1.0 ┼───╱╲
    │  ╱  ╲
    │ ╱    ╲─────────╲
    │╱                ╲
  0 ┼─────────────────────
      A   D    S      R
```

```zig
const Env = struct {
    stage: enum { idle, attack, decay, sustain, release } = .idle,
    level: f32 = 0,
    
    attack_rate: f32 = 0,
    decay_rate: f32 = 0,
    sustain_level: f32 = 0,
    release_rate: f32 = 0,
    
    pub fn trigger(self: *Env, a: f32, d: f32, s: f32, r: f32, sample_rate: f32) void {
        self.attack_rate = 1.0 / (a * sample_rate);
        self.decay_rate = (1.0 - s) / (d * sample_rate);
        self.sustain_level = s;
        self.release_rate = s / (r * sample_rate);
        self.stage = .attack;
        self.level = 0;
    }
    
    pub fn release(self: *Env) void {
        self.stage = .release;
    }
    
    pub fn next(self: *Env) f32 {
        switch (self.stage) {
            .idle => return 0,
            
            .attack => {
                self.level += self.attack_rate;
                if (self.level >= 1.0) {
                    self.level = 1.0;
                    self.stage = .decay;
                }
            },
            
            .decay => {
                self.level -= self.decay_rate;
                if (self.level <= self.sustain_level) {
                    self.level = self.sustain_level;
                    self.stage = .sustain;
                }
            },
            
            .sustain => {},  // hold until release called
            
            .release => {
                self.level -= self.release_rate;
                if (self.level <= 0) {
                    self.level = 0;
                    self.stage = .idle;
                }
            },
        }
        return self.level;
    }
};
```

### Simplified AR Envelope

For percussive hits or drones where you don't hold notes:

```zig
const AREnv = struct {
    stage: enum { idle, attack, release } = .idle,
    level: f32 = 0,
    attack_rate: f32 = 0,
    release_rate: f32 = 0,

    pub fn trigger(self: *AREnv, attack: f32, decay: f32, sample_rate: f32) void {
        self.attack_rate = 1.0 / (attack * sample_rate);
        self.release_rate = 1.0 / (decay * sample_rate);
        self.stage = .attack;
    }

    pub fn next(self: *AREnv) f32 {
        switch (self.stage) {
            .idle => return 0,
            .attack => {
                self.level += self.attack_rate;
                if (self.level >= 1.0) {
                    self.level = 1.0;
                    self.stage = .release;
                }
            },
            .release => {
                self.level -= self.release_rate;
                if (self.level <= 0) {
                    self.level = 0;
                    self.stage = .idle;
                }
            },
        }
        return self.level;
    }
};
```

## Mixer

Mixing is summation, not averaging. Two sounds together should be louder.

```zig
fn mix(voices: []const f32) f32 {
    var sum: f32 = 0;
    for (voices) |v| sum += v;
    return sum;
}
```

### Clipping Problem

10 voices at 0.5 amplitude = sum of 5.0. DAC only accepts -1.0 to 1.0. Everything above clips — harsh digital distortion.

### Solutions

**Gain staging**: Keep voices quiet enough that sum stays in range.

```zig
const voice_gain = 1.0 / @as(f32, @floatFromInt(max_voices));
```

**Soft clipping**: Let it exceed, then squash smoothly.

```zig
fn softClip(x: f32) f32 {
    return std.math.tanh(x);  // asymptotically approaches ±1
}
```

**Hard clamp**: Simple, acceptable for well-behaved content.

```zig
fn mix(voices: []const f32) f32 {
    var sum: f32 = 0;
    for (voices) |v| sum += v;
    return std.math.clamp(sum, -1.0, 1.0);
}
```

## Chaining Components

No intermediate buffers. Each sample flows through the chain in registers.

```zig
fn renderVoice(voice: *Voice) f32 {
    const osc_out = voice.osc.next();
    const filtered = voice.lpf.process(osc_out);
    const shaped = filtered * voice.env.next();
    return shaped * voice.gain;
}

fn audioCallback(output: []f32, frames: usize, voices: []Voice) void {
    for (0..frames) |i| {
        var mix: f32 = 0;
        for (voices) |*v| {
            if (v.active) mix += renderVoice(v);
        }
        output[i * 2] = mix;      // left
        output[i * 2 + 1] = mix;  // right
    }
}
```

### When You Do Buffer

- **Between threads**: Lock-free queues pass events (note on, parameter change), not samples.
- **Delay effects**: Write now, read from the past.
- **FFT/spectral**: Need a block to transform.

## Complete 4-Voice Synth

```zig
const Voice = struct {
    osc: Osc = .{},
    lpf: Biquad = .{},
    env: AREnv = .{},
    gain: f32 = 0.25,
    active: bool = false,
    age: u64 = 0,

    pub fn trigger(self: *Voice, freq: f32, cutoff: f32, attack: f32, decay: f32) void {
        self.osc.freq = freq;
        self.lpf.setLowpass(cutoff, 1.0, 44100);
        self.env.trigger(attack, decay, 44100);
        self.active = true;
        self.age = 0;
    }

    pub fn render(self: *Voice) f32 {
        if (!self.active) return 0;
        
        self.age += 1;
        
        const out = self.osc.next();
        const filtered = self.lpf.process(out);
        const shaped = filtered * self.env.next();
        
        if (self.env.stage == .idle) self.active = false;
        
        return shaped * self.gain;
    }
};

const Synth = struct {
    voices: [4]Voice = [_]Voice{.{}} ** 4,
    master_gain: f32 = 0.8,

    pub fn noteOn(self: *Synth, freq: f32, cutoff: f32, attack: f32, decay: f32) void {
        const idx = self.findFreeVoice();
        self.voices[idx].trigger(freq, cutoff, attack, decay);
    }

    fn findFreeVoice(self: *Synth) usize {
        // First: find inactive voice
        for (self.voices, 0..) |v, i| {
            if (!v.active) return i;
        }
        // All busy: steal quietest
        var quietest: usize = 0;
        var min_level: f32 = 1.0;
        for (self.voices, 0..) |v, i| {
            if (v.env.level < min_level) {
                min_level = v.env.level;
                quietest = i;
            }
        }
        return quietest;
    }

    pub fn render(self: *Synth) f32 {
        var mix: f32 = 0;
        for (&self.voices) |*v| mix += v.render();
        return std.math.clamp(mix * self.master_gain, -1.0, 1.0);
    }
};
```

Audio callback:

```zig
fn audioCallback(output: []f32, frames: usize, synth: *Synth) void {
    for (0..frames) |i| {
        const sample = synth.render();
        output[i * 2] = sample;
        output[i * 2 + 1] = sample;
    }
}
```

## Polyphony: Synth Model vs Tracker Model

Two fundamentally different approaches to managing voices.

### Synth/MIDI Model

Notes arrive as events. The synth decides which voice handles each.

```
t=0   noteOn(C4)    → voice 0 plays C4
t=1   noteOn(E4)    → voice 1 plays E4
t=2   noteOn(G4)    → voice 2 plays G4
t=3   noteOn(B4)    → voice 3 plays B4
t=4   noteOn(D5)    → ??? all voices busy
```

When voices run out, you need **voice stealing** — killing an existing voice to make room.

#### Stealing Strategies

**Round-robin**: Kill next voice in rotation. Simple but may cut mid-attack.

```zig
self.next_voice = (self.next_voice + 1) % 4;
```

**Oldest**: Kill voice playing longest. Old notes probably in release, less audible.

```zig
fn findOldest(voices: []Voice) usize {
    var oldest: usize = 0;
    var max_age: u64 = 0;
    for (voices, 0..) |v, i| {
        if (v.age > max_age) {
            max_age = v.age;
            oldest = i;
        }
    }
    return oldest;
}
```

**Quietest**: Kill voice with lowest amplitude. Best for hiding the theft.

```zig
fn findQuietest(voices: []Voice) usize {
    var quietest: usize = 0;
    var min_level: f32 = 1.0;
    for (voices, 0..) |v, i| {
        if (v.env.level < min_level) {
            min_level = v.env.level;
            quietest = i;
        }
    }
    return quietest;
}
```

### Tracker Model

Fixed channels. You, the composer, explicitly control what plays where.

```
Channel 1:  C-4 ... ... E-4 ... ... G-4 ...
Channel 2:  ... E-4 ... ... G-4 ... ... C-5
Channel 3:  ... ... G-4 ... ... C-5 ... ...
Channel 4:  ... ... ... ... ... ... ... ...
```

Want a fifth note? Pick a channel to sacrifice, or wait. The constraint is part of the art form.

### Why Trackers Didn't Need Voice Stealing

The composer *is* the voice allocator. You see all channels, you manage them. The constraint forced creative decisions:
- Arpeggios instead of held chords
- Careful voice leading
- Knowing when to let a note die

Modern DAWs with unlimited polyphony hide this entirely. You lose something.

### For Ambient/Generative Work

Options:
1. **Enough voices**: 8-12 voices, stealing rarely happens at low event density
2. **Quietest stealing**: Graceful overlap, dying notes fade naturally
3. **Tracker ethos**: Fixed voices, explicit control, constraint shapes output

## State Summary

Every audio component follows the same pattern: minimal state, per-sample computation.

| Component | State | Per-Sample Work |
|-----------|-------|-----------------|
| Oscillator | phase | increment, wrap, compute waveform |
| Filter (1-pole) | prev | one multiply, one add |
| Filter (biquad) | x1, x2, y1, y2 | 5 multiplies, shuffle history |
| Envelope | stage, level | compare, add/subtract |
| Delay | buffer, position | read, write, increment |

Only delay needs a buffer — because it holds past samples. Everything else is "where am I" plus "what's the next value."
