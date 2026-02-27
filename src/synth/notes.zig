/// Note frequencies in Hz (A4 = 440Hz standard tuning)
/// Reference: https://www.seventhstring.com/resources/notefrequencies.html
pub const freq = struct {
    // Octave 4 (middle C)
    pub const C4: f32 = 261.6;
    pub const Cs4: f32 = 277.2;
    pub const D4: f32 = 293.7;
    pub const Ds4: f32 = 311.1;
    pub const E4: f32 = 329.6;
    pub const F4: f32 = 349.2;
    pub const Fs4: f32 = 370.0;
    pub const G4: f32 = 392.0;
    pub const Gs4: f32 = 415.3;
    pub const A4: f32 = 440.0;
    pub const As4: f32 = 466.2;
    pub const B4: f32 = 493.9;

    // Octave 5
    pub const C5: f32 = 523.3;
    pub const Cs5: f32 = 554.4;
    pub const D5: f32 = 587.3;
    pub const Ds5: f32 = 622.3;
    pub const E5: f32 = 659.3;
    pub const F5: f32 = 698.5;
    pub const Fs5: f32 = 740.0;
    pub const G5: f32 = 784.0;
    pub const Gs5: f32 = 830.6;
    pub const A5: f32 = 880.0;
    pub const As5: f32 = 932.3;
    pub const B5: f32 = 987.8;

    // Octave 6
    pub const C6: f32 = 1047.0;
    pub const Cs6: f32 = 1109.0;
    pub const D6: f32 = 1175.0;
    pub const Ds6: f32 = 1245.0;
    pub const E6: f32 = 1319.0;
    pub const F6: f32 = 1397.0;
    pub const Fs6: f32 = 1480.0;
    pub const G6: f32 = 1568.0;
    pub const Gs6: f32 = 1661.0;
    pub const A6: f32 = 1760.0;
    pub const As6: f32 = 1865.0;
    pub const B6: f32 = 1976.0;
};
