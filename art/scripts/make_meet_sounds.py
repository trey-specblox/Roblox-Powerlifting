"""Builds the game's bar, crowd and background sounds from the Sonniss GDC bundles (GAME_DESIGN §37.5 "Meet sounds").

    python -I art/scripts/make_meet_sounds.py

Reads the WAVs straight out of the downloaded zips and writes finished WAVs to OUT, which is outside this repo on
purpose: the Sonniss licence forbids supplying the sounds as sounds, so they must never go in a public repo or on the
Creator Store. Only this recipe and the manifest (art/sounds/sonniss_sounds.json) are tracked. No AI tools may touch them.

The thuds are the heart of it. NOTHING RECORDED IS EVER SLOWED DOWN, and a heavier thud is never longer (user, 2026-11-04:
a slowed recording "is very lazy"; "Its the Plates that are getting heavier and more compact the bar stays the same"). Each
thud is three parts mixed together:
  the bar     a normal drop at real speed, the same in every thud: a plate hitting, then the plates clacking on the sleeve.
  the plates  what grows with the weight, deeper and harder: sledgehammers on concrete at real speed, with a short made note
              and thump under them. It is over as quickly as a real landing in the user's gym video.
  the metal   real plate and handle hits at real speed, packed into about 25 ms; more plates on a heavier bar means more hits.
Every hit starts within a few milliseconds of the file's start, so the sound lands when the game plays it. Keep all four
BarThud cue volumes in MeetSoundConfig equal, so the bar sounds the same in the game; the files carry the loudness.
"""
import pathlib
import struct
import wave
import zipfile

import numpy as np

ZIPS = pathlib.Path(r"D:\Powerlifting Roblox Extras\RobloxKits\Sonniss")
OUT = pathlib.Path(r"D:\Powerlifting Roblox Extras\Sounds")
RATE = 48000
BED_RATE = 44100

Z2017 = "Sonniss.com - GDC 2017 - Game Audio Bundle Part 1of9.zip"
Z2018A = "Sonniss.com - GDC 2018 - Game Audio Bundle Part 1of8.zip"
Z2018B = "Sonniss.com - GDC 2018 - Game Audio Bundle Part 2of8.zip"
Z2026A = "Sonniss.com-GDC2026-GameAudioBundle4of5.zip"
Z2026B = "Sonniss.com-GDC2026-GameAudioBundle5of5.zip"
FILES = {
    "plate": (Z2018B, "TG_Weight Metal Plate"),
    "shake": (Z2018B, "TG_Bench Press"),
    "tone": (Z2018B, "Dining hall"),
    "handle": (Z2017, "Drop metal handle"),
    "rack": (Z2017, "Barbell steel bar"),
    "rattle": (Z2017, "Barbell weight 10kg"),
    "bag": (Z2017, "Punching bag hits"),
    "sledge": (Z2018A, "Sledgehammers"),
    "groan": (Z2018A, "Friendly Disappointment"),
    "hall": (Z2018A, "Community Centre,Hall"),
    "cheer": (Z2026A, "Small Club, 50 People"),
    "dense": (Z2026A, "Dense Immersive"),
    "match": (Z2026A, "SBvma_Masculine"),
    "thud": (Z2026B, "Metal Hit Thud Thump"),
}
_cache = {}


def parse_wav(raw):
    assert raw[:4] == b"RIFF" and raw[8:12] == b"WAVE", "not a WAV"
    pos, fmt, data = 12, None, None
    while pos + 8 <= len(raw):
        tag, size = raw[pos:pos + 4], struct.unpack("<I", raw[pos + 4:pos + 8])[0]
        if tag == b"fmt ":
            code, channels, rate, _, _, bits = struct.unpack("<HHIIHH", raw[pos + 8:pos + 24])
            if code == 0xFFFE:
                code = struct.unpack("<H", raw[pos + 32:pos + 34])[0]
            fmt = (code, channels, rate, bits)
        elif tag == b"data":
            data = raw[pos + 8:pos + 8 + size]
        pos += 8 + size + (size & 1)
    code, channels, rate, bits = fmt
    if code == 3 and bits == 32:
        x = np.frombuffer(data, dtype="<f4").astype(np.float64)
    elif code == 1 and bits == 16:
        x = np.frombuffer(data, dtype="<i2").astype(np.float64) / 32768
    elif code == 1 and bits == 24:
        b = np.frombuffer(data, dtype=np.uint8)
        b = b[:len(b) // 3 * 3].reshape(-1, 3)
        v = b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16)
        x = (v - ((v & 0x800000) << 1)).astype(np.float64) / 8388608
    else:
        raise ValueError(f"format {fmt}")
    x = x[:len(x) // channels * channels].reshape(-1, channels)
    return x, rate


def load(key):
    """(samples by channel, rate) of a source file, read from its zip once."""
    if key not in _cache:
        zip_name, word = FILES[key]
        with zipfile.ZipFile(ZIPS / zip_name) as z:
            for info in z.infolist():
                base = info.filename.replace("\\", "/").split("/")[-1]
                if base.lower().endswith(".wav") and word.lower() in base.lower():
                    _cache[key] = parse_wav(z.read(info))
                    break
            else:
                raise FileNotFoundError(word)
    return _cache[key]


def resample(x, rate, out_rate, speed=1.0):
    """To out_rate. speed below 1 is slower and deeper. Works on one channel."""
    want = int(len(x) * out_rate / rate / speed)
    s = np.fft.rfft(x)
    keep = want // 2 + 1
    s = s[:keep] if keep <= len(s) else np.concatenate([s, np.zeros(keep - len(s), dtype=complex)])
    return np.fft.irfft(s, want) * want / len(x)


def cut(key, start, seconds, speed=1.0):
    """A mono piece of a source, starting just before `start`, at RATE."""
    x, rate = load(key)
    a = max(0, int((start - 0.012) * rate))
    return resample(x[a:a + int(seconds * rate)].mean(axis=1), rate, RATE, speed)


def cut_stereo(key, start, seconds, out_rate=BED_RATE):
    x, rate = load(key)
    a = int(start * rate)
    x = x[a:a + int(seconds * rate)]
    if x.shape[1] >= 6:
        x = x[:, [0, 1]]
    elif x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    return np.stack([resample(x[:, 0], rate, out_rate), resample(x[:, 1], rate, out_rate)], axis=1)


def band(x, low, high, rate=RATE):
    """Keeps low..high Hz, with soft edges so nothing rings."""
    s = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1 / rate)
    gain = np.ones(len(f))
    if low:
        gain *= np.clip((f - low * 0.7) / (low * 0.3), 0, 1)
    if high:
        gain *= np.clip((high * 1.3 - f) / (high * 0.3), 0, 1)
    if x.ndim == 2:
        gain = gain[:, None]
    return np.fft.irfft(s * gain, len(x), axis=0)


def peak_to(x, db=-3.0):
    return x * 10 ** (db / 20) / (np.abs(x).max() + 1e-12)


def rms_to(x, db):
    return x * 10 ** (db / 20) / (np.sqrt((x ** 2).mean()) + 1e-12)


def fades(x, fade_out=0.15, fade_in=0.003, rate=RATE):
    x = x.copy()
    a, b = int(fade_in * rate), min(int(fade_out * rate), len(x) // 2)
    x[:a] = (x[:a].T * np.linspace(0, 1, a)).T
    x[-b:] = (x[-b:].T * (np.linspace(1, 0, b) ** 2)).T
    return x


def stack(*layers):
    """Mixes (samples, gain, delay seconds), mono or all stereo."""
    size = max(len(x) + int(d * RATE) for x, _, d in layers)
    total = np.zeros(size)
    for x, gain, delay in layers:
        d = int(delay * RATE)
        total[d:d + len(x)] += x * gain
    return total


def sub_kick(start_hz, end_hz, seconds, sweep=0.05):
    """The made low hit: a sine sweeping down fast and dying away."""
    t = np.arange(int(seconds * RATE)) / RATE
    freq = end_hz + (start_hz - end_hz) * np.exp(-t / sweep)
    tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE)
    return tone * np.exp(-t / (seconds * 0.28)) * np.minimum(t / 0.002, 1)


def room(x, seconds, wet, rate=RATE, seed=7, dark=2600):
    """A made hall echo: dying noise, darker towards the end. Mono or stereo."""
    random = np.random.default_rng(seed)
    n = int(seconds * rate)
    t = np.arange(n) / rate

    def one(signal):
        ir = band(random.standard_normal(n), 120, dark, rate) * np.exp(-t * 6.9 / seconds)
        ir[:int(0.012 * rate)] = 0  # a gap before the first echo, as in a real room
        ir /= np.sqrt((ir ** 2).sum()) + 1e-12
        size = len(signal) + n
        return np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(ir, size), size)

    if x.ndim == 1:
        return np.concatenate([x, np.zeros(n)]) + one(x) * wet
    dry = np.concatenate([x, np.zeros((n, x.shape[1]))])
    return dry + np.stack([one(x[:, c]) for c in range(x.shape[1])], axis=1) * wet


def saturate(x, drive):
    """Soft clipping: louder, and it adds the overtones small speakers need."""
    x = x / (np.abs(x).max() + 1e-12)
    return np.tanh(x * drive) / np.tanh(drive)


# Every thud is this long at every weight: heavier is deeper and harder, never longer.
THUD_SECONDS = 1.45
# Light to massive. Real landings in the user's gym video are loudest at 64-116 Hz and fall 12 dB within about 0.04-0.11 s.
TIERS = [
    dict(name="BarThud_1", note=110, peak=-9.0, sledge=0.6, drive=1.4, plates=2),
    dict(name="BarThud_2", note=95, peak=-6.5, sledge=0.8, drive=1.8, plates=3),
    dict(name="BarThud_3", note=82, peak=-4.0, sledge=0.9, drive=2.2, plates=4),
    dict(name="BarThud_4", note=70, peak=-2.0, sledge=1.0, drive=2.6, plates=6),
]
# Real metal hits in landing order, and when each lands after the first (seconds): plates don't all touch at the same instant.
METAL_HITS = [("plate", 14.36, 0.0), ("plate", 2.90, 0.004), ("plate", 5.35, 0.009), ("handle", 3.84, 0.013), ("plate", 11.74, 0.018), ("plate", 8.58, 0.024)]
# The metal's energy against the deep part's in the first 0.1 s. The user chose this "Strong metal" by ear over 0.2.
METAL_RATIO = 0.5


def starts_now(x):
    """Trims a recorded hit so it starts right at its first sharp rise, so every layer lands together."""
    env = np.abs(x)
    at = int(np.argmax(env >= env.max() * 0.2))
    return x[max(0, at - int(0.001 * RATE)):]


def tight_note(hz, tau=0.05):
    """A short made low note: gone as quickly as a real landing, so it never rings like a slowed recording."""
    t = np.arange(int(0.35 * RATE)) / RATE
    freq = hz * (1 + 0.7 * np.exp(-t / 0.012))
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / tau) * np.minimum(t / 0.001, 1)


def body_noise(tau=0.045):
    random = np.random.default_rng(5)
    n = int(0.3 * RATE)
    t = np.arange(n) / RATE
    return peak_to(band(random.standard_normal(n), 60, 320) * np.exp(-t / tau), 0)


def build_bar():
    """A normal drop's bar, real speed, the same in every thud, with only a touch of room."""
    plate = peak_to(starts_now(cut("plate", 11.74, 1.0)), 0)
    rattle = fades(peak_to(band(cut("rattle", 4.34, 1.3), 200, 9000), 0), 0.5, 0.02)
    shake = fades(peak_to(band(cut("shake", 8.38, 0.9), 200, 9000), 0), 0.4, 0.02)
    x = stack((plate, 0.85, 0), (rattle, 0.55, 0.04), (shake, 0.3, 0.1))
    return peak_to(room(band(x, 110, 0), 0.25, 0.1, seed=9, dark=5000), -9)


def build_plates(tier):
    """The plates hitting the floor, what grows with the weight: recorded sledgehammers on concrete at real speed, with a
    tight made note and thump under them. Soft clipping adds the overtones that small speakers need."""
    sledge = stack((peak_to(starts_now(band(cut("sledge", 25.49, 0.4), 0, 1800)), 0), 1, 0),
                   (peak_to(starts_now(band(cut("sledge", 18.25, 0.4), 0, 1800)), 0), 0.8, 0))
    x = stack((sledge, tier["sledge"], 0), (tight_note(tier["note"]), 1.1, 0), (tight_note(tier["note"] * 2.1, 0.03), 0.3, 0),
              (body_noise(), 0.5, 0))
    return saturate(x, tier["drive"])


def one_metal_hit(key, start):
    """A recorded metal hit at real speed. Soft clipping lifts its ring against its first click, so it isn't only a click."""
    x = starts_now(band(cut(key, start, 0.3), 350, 9000))
    x = saturate(x, 5) * np.exp(-np.arange(len(x)) / RATE / 0.05)
    return peak_to(x, 0)


def energy(x, seconds=0.1):
    return float((x[:int(seconds * RATE)] ** 2).sum())


def build_thud(tier, bar):
    plates = peak_to(band(build_plates(tier), 28, 2200), tier["peak"])
    metal = stack(*[(one_metal_hit(key, start), 1, delay) for key, start, delay in METAL_HITS[:tier["plates"]]])
    metal = metal * np.sqrt(METAL_RATIO * energy(plates) / energy(metal))
    x = stack((plates, 1, 0), (metal, 1, 0), (bar, 1, 0))[:int(THUD_SECONDS * RATE)]
    # Soft-limits only what would clip, so the bar's clacking after the hit is untouched.
    over = np.abs(x) > 0.75
    x[over] = np.sign(x[over]) * (0.75 + 0.23 * np.tanh((np.abs(x[over]) - 0.75) / 0.23))
    return fades(x, 0.4, 0.0005)


def build_caught():
    """Spotters catching a missed squat or bench: rack, plates clattering, a short thump."""
    x = stack((peak_to(cut("rack", 4.16, 1.2), 0), 0.8, 0), (peak_to(cut("shake", 8.38, 1.0), 0), 0.5, 0.02),
              (peak_to(cut("rattle", 1.28, 1.3), 0), 0.35, 0.05), (sub_kick(110, 60, 0.3), 0.55, 0))
    return peak_to(fades(room(saturate(x, 1.6), 0.5, 0.18)[:int(1.5 * RATE)], 0.4), -3)


def build_clap():
    """The head referee's single sharp clap: three tiny bursts of the palm meeting, in a small hall."""
    random = np.random.default_rng(3)
    n = int(0.09 * RATE)
    t = np.arange(n) / RATE
    burst = band(random.standard_normal(n), 900, 4200) * np.exp(-t / 0.014)
    low = band(random.standard_normal(n), 350, 1100) * np.exp(-t / 0.02)
    x = stack((burst, 0.4, 0), (burst, 0.6, 0.006), (burst, 1.0, 0.012), (low, 0.5, 0.012))
    return peak_to(fades(room(x, 0.45, 0.28, dark=5000), 0.15, 0.0005), -3)


def bell(hz, seconds, level=1.0):
    t = np.arange(int(seconds * RATE)) / RATE
    tone = sum(g * np.sin(2 * np.pi * hz * m * t) * np.exp(-t / (seconds * d))
               for m, g, d in ((1, 1, 0.3), (2, 0.42, 0.2), (2.76, 0.16, 0.12), (4.07, 0.07, 0.07)))
    return tone * np.minimum(t / 0.002, 1) * level


def build_good_lights():
    """Three white lights: a clean rising two-note bell, not a game-show ding."""
    return peak_to(fades(room(stack((bell(659.3, 0.9), 0.75, 0), (bell(987.8, 1.1), 1, 0.09)), 0.8, 0.25, dark=6000), 0.3), -4)


def build_bad_lights():
    """Three red lights: a short low buzz, rough but not painful."""
    t = np.arange(int(0.62 * RATE)) / RATE
    wave_ = sum(np.sin(2 * np.pi * 98 * k * t) / k for k in range(1, 22)) + 0.7 * sum(
        np.sin(2 * np.pi * 103.5 * k * t) / k for k in range(1, 18))
    x = band(saturate(wave_, 1.5), 70, 1500) * np.minimum(t / 0.008, 1) * np.minimum((t[-1] - t) / 0.05, 1)
    return peak_to(fades(room(x, 0.45, 0.16), 0.2), -6)


def steady(x, rate, window=1.2, strength=0.8):
    """Rides the level of a crowd recording, so no single shout or big cheer jumps out of a background loop."""
    power = (x ** 2).mean(axis=1)
    n = int(window * rate)
    kernel = np.hanning(n)
    kernel /= kernel.sum()
    size = len(power) + n
    smooth = np.fft.irfft(np.fft.rfft(power, size) * np.fft.rfft(kernel, size), size)[n // 2:n // 2 + len(power)]
    level = np.sqrt(np.maximum(smooth, 1e-12))
    gain = (np.median(level) / level) ** strength
    return x * np.clip(gain, 0.15, 3)[:, None]


def loop(x, crossfade, rate):
    """Makes a stereo bed loop without a seam: its tail fades into its start."""
    n = int(crossfade * rate)
    body = x[:-n].copy()
    up = np.sqrt(np.linspace(0, 1, n))[:, None]
    down = np.sqrt(np.linspace(1, 0, n))[:, None]
    body[:n] = body[:n] * up + x[-n:] * down
    return body


def scatter(bed, events, rate, seed, every, level_db, dark):
    """Far-off gym noises dropped into a bed at random times and sides, kept off the crossfade at the end."""
    random = np.random.default_rng(seed)
    at = 1.0
    end = len(bed) / rate - 6
    while at < end:
        key, start, seconds, speed = events[random.integers(len(events))]
        source, source_rate = load(key)
        piece = source[int(start * source_rate):int((start + seconds) * source_rate)].mean(axis=1)
        piece = band(peak_to(resample(piece, source_rate, rate, speed), 0), 90, dark, rate)
        gain = 10 ** ((level_db + random.uniform(-7, 2)) / 20)
        pan = random.uniform(0.2, 0.8)
        wet = room(np.stack([piece * (1 - pan), piece * pan], axis=1) * gain, 1.1, 0.75, rate, int(random.integers(1000)), dark)
        a = int(at * rate)
        b = min(a + len(wet), len(bed))
        bed[a:b] += wet[:b - a]
        at += random.uniform(*every)
    return bed


GYM_NOISES = [("plate", 2.90, 1.0, 1.0), ("plate", 5.35, 1.2, 0.9), ("plate", 8.58, 1.2, 0.8), ("rack", 0.82, 1.2, 1.0),
              ("rack", 4.16, 1.2, 1.0), ("rack", 8.28, 1.2, 0.95), ("rack", 11.50, 1.2, 1.0), ("rattle", 1.28, 1.4, 1.0),
              ("rattle", 9.06, 1.5, 1.0), ("shake", 0.61, 0.9, 1.0), ("shake", 19.06, 0.9, 1.0), ("handle", 1.87, 0.8, 0.9),
              ("bag", 3.80, 0.5, 1.0), ("sledge", 12.30, 0.5, 0.7)]


def build_gym_bed():
    """The main gym: ventilation hum, far voices and activity, weights clanking now and then in other rooms."""
    seconds = 84
    tone = rms_to(band(cut_stereo("tone", 20, seconds), 70, 0, BED_RATE), -44)
    hall = rms_to(steady(cut_stereo("hall", 60, seconds), BED_RATE), -38)
    bed = scatter(tone + hall, GYM_NOISES, BED_RATE, 11, (1.6, 6.5), -25, 4500)
    return peak_to(loop(bed, 4, BED_RATE), -10)


def build_meet_bed():
    """The Local meet hall: a crowd indoors (the recording is outdoors, so it gets a hall), with warm-up weights far off."""
    seconds = 64
    x, rate = load("dense")
    crowd = cut_stereo("dense", 0, len(x) / rate)
    # The recording is shorter than the bed, so it repeats, joined without a seam.
    crowd = np.tile(loop(crowd, 3, BED_RATE), (seconds * BED_RATE // (len(crowd) - 3 * BED_RATE) + 1, 1))[:seconds * BED_RATE]
    crowd = room(steady(band(crowd, 90, 7000, BED_RATE), BED_RATE), 1.3, 0.45, BED_RATE, 21)[:seconds * BED_RATE]
    bed = rms_to(crowd, -26) + rms_to(cut_stereo("hall", 80, seconds), -36)
    bed = scatter(bed, GYM_NOISES[:9], BED_RATE, 12, (4, 11), -30, 3500)
    return peak_to(loop(bed, 4, BED_RATE), -10)


def build_arena_bed():
    """The State arena: a real sports match crowd, in a much bigger room."""
    seconds = 64
    crowd = steady(band(cut_stereo("match", 150, seconds), 70, 8000, BED_RATE), BED_RATE)
    crowd = room(crowd, 2.2, 0.5, BED_RATE, 31)[:seconds * BED_RATE]
    return peak_to(loop(crowd, 4, BED_RATE), -9)


def save(name, x, rate=RATE):
    channels = 1 if x.ndim == 1 else x.shape[1]
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def describe(name, x, rate=RATE):
    mono = x if x.ndim == 1 else x.mean(axis=1)
    w = mono[:int(0.4 * rate)]
    s = np.abs(np.fft.rfft(w * np.hanning(len(w)))) ** 2
    f = np.fft.rfftfreq(len(w), 1 / rate)

    def db_in(a, b):
        return 10 * np.log10(s[(f >= a) & (f < b)].sum() / len(w) + 1e-12)

    print(f"{name:12s} {len(x) / rate:5.1f}s peak {20 * np.log10(np.abs(x).max() + 1e-9):6.1f} dB  whole-rms "
          f"{20 * np.log10(np.sqrt((mono ** 2).mean()) + 1e-9):6.1f} dB   first 0.4 s: 30-100 Hz {db_in(30, 100):6.1f}  100-300 Hz "
          f"{db_in(100, 300):6.1f}  300-2k {db_in(300, 2000):6.1f}  2k+ {db_in(2000, 20000):6.1f}")


def report_thuds(done):
    """Checks what the user asked for: one length, a hit as short as a real landing, and the same bar after it."""
    for tier in TIERS:
        x = done[tier["name"]]
        hop = RATE // 200
        n = len(x) // hop
        db = 20 * np.log10(np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(axis=1)) + 1e-9)
        at = int(np.argmax(db))
        after = np.nonzero(db[at:] < db[at] - 12)[0]
        print(f"{tier['name']}: {len(x) / RATE:.2f} s, loudest at {at * hop / RATE * 1000:3.0f} ms, down 12 dB after {after[0] * hop / RATE:.2f} s, "
              f"level at 0.5 s {db[int(0.5 * RATE / hop)]:.1f} dB")


def main():
    OUT.mkdir(exist_ok=True)
    print("For comparison, the takes that were 'too underwhelming':")
    describe("Plate 2", peak_to(cut("plate", 5.35, 1.6), -3))
    describe("Handle 2", peak_to(cut("handle", 3.84, 1.3), -3))
    print("\nNew:")
    done = {}
    bar = build_bar()
    for tier in TIERS:
        done[tier["name"]] = build_thud(tier, bar)
    report_thuds(done)
    # The fullest of the six takes by measurement.
    done["BarRack"] = peak_to(fades(cut("rack", 20.09, 1.7)), -3)
    done["BarCaught"] = build_caught()
    # A gym squat or bench rep's rattle at the bottom: the bench press shaking take the user approved, as recorded.
    done["BarShake"] = peak_to(fades(cut("shake", 8.38, 1.0), 0.3), -3)
    done["RefereeClap"] = build_clap()
    done["LightsGood"] = build_good_lights()
    done["LightsBad"] = build_bad_lights()
    done["CrowdGroan"] = peak_to(fades(cut("groan", 0, 8), 0.6), -3)
    x, rate = load("cheer")
    mono = x.mean(axis=1)
    env = np.convolve(np.abs(mono[::480]), np.ones(600) / 600, "same")
    at = max(0, int(np.argmax(env) * 480 - 3.5 * rate))
    done["CrowdCheer"] = peak_to(fades(resample(mono[at:at + 7 * rate], rate, RATE), 0.6), -3)
    for name, x in done.items():
        save(name, x)
        describe(name, x)
    beds = {"GymBed": build_gym_bed(), "MeetBed": build_meet_bed(), "ArenaBed": build_arena_bed()}
    for name, x in beds.items():
        save(name, x, BED_RATE)
        describe(name, x, BED_RATE)
        print(f"   {(OUT / (name + '.wav')).stat().st_size // 1024 // 1024} MB")

    # One file to listen to, in order, with the old Plate 2 first for comparison.
    gap = np.zeros(int(0.8 * RATE))
    parts, cursor = [], 0.0
    print("\nListening file:")
    order = [("OLD Plate 2 (for comparison)", peak_to(cut("plate", 5.35, 1.6), -3))]
    order += [(tier["name"], done[tier["name"]]) for tier in TIERS]
    order += [("BarThud_1 then BarThud_4 again, to compare", done["BarThud_1"]), ("", done["BarThud_4"])]
    order += [(n, done[n]) for n in ("BarRack", "BarCaught", "RefereeClap", "LightsGood", "LightsBad", "CrowdCheer", "CrowdGroan")]
    for label, x in order:
        if label:
            print(f"  {int(cursor // 60)}:{cursor % 60:04.1f} {label}")
        parts += [x, gap]
        cursor += (len(x) + len(gap)) / RATE
    for name, x in beds.items():
        print(f"  {int(cursor // 60)}:{cursor % 60:04.1f} {name} (30 s, played at its real level would be quieter)")
        y = resample(x[:30 * BED_RATE].mean(axis=1), BED_RATE, RATE)
        y = fades(y, 1.5, 0.5)
        parts += [y, gap]
        cursor += (len(y) + len(gap)) / RATE
    save("Heavy_Thuds_Listen", np.concatenate(parts))


if __name__ == "__main__":
    main()
