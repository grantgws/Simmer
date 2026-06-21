import wave, struct, math

SR = 44100
DUR = 24.0                      # seconds
N = int(SR * DUR)
BPM = 78.0
BEAT = 60.0 / BPM               # ~0.769s per beat

# ----- oscillators -----
def sine(freq, i):
    return math.sin(2.0 * math.pi * freq * i / SR)

def tri(freq, i):
    t = freq * i / SR
    return 2.0 * abs(2.0 * (t - math.floor(t + 0.5))) - 1.0

# ----- one-pole low-pass (rounds off edges, kills harshness) -----
def lp(samples, alpha):
    out = [0.0] * len(samples)
    y = 0.0
    for k, x in enumerate(samples):
        y += alpha * (x - y)
        out[k] = y
    return out

# note frequencies (equal temperament, A4=440)
def f(name):
    names = {'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,
             'G':7,'G#':8,'A':9,'A#':10,'B':11}
    letter = name[:-1]
    octave = int(name[-1])
    semis = names[letter] + (octave - 4) * 12 - 9   # relative to A4
    return 440.0 * (2.0 ** (semis / 12.0))

# ----- smooth pad note: blend of sine + triangle, slightly detuned voices -----
def pad_voice(freq, length, atk, rel):
    buf = [0.0] * length
    for i in range(length):
        # blend sine (round) + small triangle (subtle warmth)
        s = 0.78 * sine(freq, i) + 0.22 * tri(freq, i)
        # add a faintly detuned second voice for chorus warmth
        s += 0.20 * sine(freq * 1.003, i)
        # gentle attack / release envelope (raised-cosine for smoothness)
        env = 1.0
        if i < atk:
            env = 0.5 - 0.5 * math.cos(math.pi * i / atk)
        elif i > length - rel:
            x = (length - i) / rel
            env = 0.5 - 0.5 * math.cos(math.pi * x)
        buf[i] = s * env
    return buf

# ----- chord progression: Cmaj7 - Am7 - Fmaj7 - G  (Imaj7-vi7-IVmaj7-V) -----
# two passes through the 4-chord loop ~= 8 chords, each 3 beats long
chords = [
    ['C3', 'E4', 'G4', 'B4'],   # Cmaj7
    ['A2', 'E4', 'G4', 'C5'],   # Am7
    ['F3', 'A4', 'C5', 'E5'],   # Fmaj7
    ['G3', 'D4', 'G4', 'B4'],   # G
]

chord_beats = 3.0
chord_len = int(SR * BEAT * chord_beats)

pad = [0.0] * N
# fill the timeline, looping the progression
pos = 0
idx = 0
while pos < N:
    notes = chords[idx % len(chords)]
    length = min(chord_len + int(SR * 0.5), N - pos)  # slight overlap tail
    atk = int(SR * 0.35)        # slow 350ms swell
    rel = int(SR * 0.55)        # long 550ms release -> overlaps next chord
    for nm in notes:
        v = pad_voice(f(nm), length, atk, rel)
        for i in range(length):
            pad[pos + i] += v[i] * 0.25   # mix voices down
    pos += chord_len
    idx += 1

# soften the pad heavily
pad = lp(pad, 0.06)

# ----- gentle sine arpeggio on top (bell-like) -----
arp = [0.0] * N
# arpeggiate the top chord tones, one soft note per beat, sparse
arp_pattern_per_chord = [0, 2, 3, 2]   # indices into the chord's notes
note_len = int(SR * BEAT * 0.9)
n_atk = int(SR * 0.012)
n_rel = int(SR * 0.45)          # long soft tail
beat_samps = int(SR * BEAT)
beat_count = 0
t = 0
while t < N:
    chord_index = (t // chord_len) % len(chords)
    notes = chords[chord_index]
    step = arp_pattern_per_chord[beat_count % len(arp_pattern_per_chord)]
    nm = notes[step]
    freq = f(nm) * 2.0          # one octave up, sparkly but soft
    length = min(note_len + n_rel, N - t)
    for i in range(length):
        s = sine(freq, i)
        env = 1.0
        if i < n_atk:
            env = i / n_atk
        elif i > length - n_rel:
            x = (length - i) / n_rel
            env = 0.5 - 0.5 * math.cos(math.pi * x)
        arp[t + i] += s * env
    beat_count += 1
    t += beat_samps

arp = lp(arp, 0.10)

# ----- mix -----
PAD_GAIN = 0.62
ARP_GAIN = 0.16
mix = [0.0] * N
for i in range(N):
    mix[i] = pad[i] * PAD_GAIN + arp[i] * ARP_GAIN

# global fade in (0.5s) and fade out (1.5s)
fi = int(SR * 0.5)
fo = int(SR * 1.5)
for i in range(fi):
    mix[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
for i in range(fo):
    g = 0.5 - 0.5 * math.cos(math.pi * (fo - i) / fo)
    mix[N - fo + i] *= g

# normalize to target peak (~ -14 dBFS = 0.20 linear)
peak = max(abs(v) for v in mix) or 1.0
TARGET = 0.18
scale = TARGET / peak
mix = [v * scale for v in mix]

# slight stereo widening: pad centered, arp panned subtly via tiny delay
def to_i16(v):
    return int(max(-1.0, min(1.0, v)) * 32767)

w = wave.open('/tmp/simmer-music.wav', 'w')
w.setnchannels(2)
w.setsampwidth(2)
w.setframerate(SR)
delay = int(SR * 0.008)         # 8ms haas for gentle width
frames = bytearray()
for i in range(N):
    left = mix[i]
    right = mix[i - delay] if i - delay >= 0 else mix[i]
    frames += struct.pack('<hh', to_i16(left), to_i16(right))
w.writeframes(bytes(frames))
w.close()
print("wrote /tmp/simmer-music.wav  peak(pre-norm)=%.3f scale=%.3f" % (peak, scale))
