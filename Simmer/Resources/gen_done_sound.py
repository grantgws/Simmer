import wave, struct, math

SR = 44100
AMP = 0.12  # softer than the action chime — it's good news, not urgent

def lp(samples, alpha=0.12):
    out, y = [], 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out

def tri(freq, i):
    t = freq * i / SR
    return 2.0 * abs(2.0 * (t - math.floor(t + 0.5))) - 1.0

def note(freq, ms, gap_ms=10):
    n = int(SR * ms / 1000)
    atk = int(SR * 0.010)
    rel = int(SR * 0.050)        # longer, softer tail for a "settled" feel
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
    w = wave.open(name, 'w'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    for v in data:
        w.writeframes(struct.pack('<h', int(max(-1,min(1,v))*32767)))
    w.close()

# D) descending "settle":  G5 -> E5 -> C5  (relaxes down, clearly not an alert)
write('/tmp/done_D.wav', [(784, 90), (659, 90), (523, 150)])
# E) gentle two-note "ta-da": G5 -> C6     (light, upward, cheerful but soft)
write('/tmp/done_E.wav', [(784, 90), (1047, 150)])
# F) warm low "thunk-bloom": C5 -> E5      (small, mellow, understated)
write('/tmp/done_F.wav', [(523, 90), (659, 150)])
print("generated D, E, F")
