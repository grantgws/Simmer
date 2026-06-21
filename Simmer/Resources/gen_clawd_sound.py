import wave, struct, math

SR = 44100
AMP = 0.14  # softer

def lp(samples, alpha=0.12):
    """Stronger low-pass (~lower cutoff) to round off the edges."""
    out, y = [], 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out

def tri(freq, i):
    """Triangle wave — soft, mellow, far gentler than a square."""
    t = freq * i / SR
    return 2.0 * abs(2.0 * (t - math.floor(t + 0.5))) - 1.0

def note(freq, ms, gap_ms=10):
    n = int(SR * ms / 1000)
    atk = int(SR * 0.010)        # gentler 10ms attack
    rel = int(SR * 0.040)        # longer 40ms release (soft tail)
    s = []
    for i in range(n):
        env = 1.0
        if i < atk: env = i/atk
        elif i > n-rel: env = max(0.0, (n-i)/rel)
        s.append(AMP * tri(freq, i) * env)
    s = lp(s)
    s += [0.0]*int(SR*gap_ms/1000)
    return s

def write(name, notes):
    data = []
    for f, ms in notes:
        data += note(f, ms)
    w = wave.open(name, 'w')
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    for v in data:
        w.writeframes(struct.pack('<h', int(max(-1,min(1,v))*32767)))
    w.close()

# lower + triangle = mellow. motifs kept, pitched down ~an octave-ish.
# A) minimal two-note:        D5 -> G5
write('/tmp/clawd_A.wav', [(587, 110), (784, 130)])
# B) cheerful rising arpeggio: C5 -> E5 -> G5
write('/tmp/clawd_B.wav', [(523, 95), (659, 95), (784, 130)])
# C) curious lilt:             D5 -> F5 -> A5
write('/tmp/clawd_C.wav', [(587, 85), (698, 85), (880, 120)])
print("generated softened A, B, C")
