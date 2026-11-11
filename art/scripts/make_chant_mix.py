# The State arena's crowd chant as ONE finished mix (GAME_DESIGN §36.4, user 2026-11-10: "Rebuild as one mix").
#
# The first version played a dry beat loop and dry chant clips on top of each other in the game. The user found it did not
# blend with the arena's background crowd, you could hear where it started, and it stuttered at the start. So this
# mixes everything ahead of time into one seamless stereo loop per chant:
#   - the stomp, stomp, clap beat (make_chant_beat.py's crowd, own work), made twice so left and right are different people;
#   - the chant: the word-checked ElevenLabs take, stacked many times a little out of time and a little higher or lower
#     in pitch, spread left to right, so it sounds like a whole crowd, not one clip;
#   - one shared arena echo over all of it, then the same filtering as the arena's background crowd (make_meet_sounds.py);
#   - the loop's join placed in the quietest moment (the rest at the end of a bar), never through a stomp.
# Then (user 2026-11-10): "the clap is too slow ... it needs to be quicker and more repeatable. Remove 'this all you' ...
# just make the chants repeat whatever lift's main chants is more often and with the faster claps." So the beat is faster
# (TEMPO) and each mix is the lift's own chant only, every other bar. Deadlift has two (user 2026-11-10: "Deadlift is
# 'lift it up' 'pick it up'"), in turn. The bench and deadlift takes are made with the same prompts as the squat one.
# The game plays each file looped and fades it in and out (MeetChant).
#
#   uv run --no-project --with numpy --with soundfile python art/scripts/make_chant_mix.py
# writes ChantMix_<Name>.wav to D:\Powerlifting Roblox Extras\Sounds\Shouts (they hold ElevenLabs audio, so they stay
# outside the repo, like the shouts) and listening files to D:\Powerlifting Roblox Extras\Sounds\ChantListen.
import importlib.util
import os
import pathlib

import numpy as np
import soundfile as sf

_HERE = os.path.dirname(os.path.abspath(__file__))


def _module(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


M = _module("make_meet_sounds")
B = _module("make_chant_beat")

RATE = M.RATE
SHOUTS = pathlib.Path(r"D:\Powerlifting Roblox Extras\Sounds\Shouts")
LISTEN = pathlib.Path(r"D:\Powerlifting Roblox Extras\Sounds\ChantListen")
TEMPO = 144              # beats a minute (the first version's 116 was too slow for the user)
BEAT = 60 / TEMPO
BAR = 4 * BEAT
LOOP_BARS = 4            # each loop: the chant on bars 1 and 3, the beat alone on bars 2 and 4
CHANT_BARS = (0, 2)

# Each mix: its chant on each of CHANT_BARS. Only word-checked takes (the ones in Shouts/Raw).
MIXES = {
    "LiftOrLose": ("LiftOrLose", "LiftOrLose"),
    "SquatItUp": ("SquatItUp", "SquatItUp"),
    "PressItUp": ("PressItUp", "PressItUp"),
    "Deadlift": ("LiftItUp", "PickItUp"),
}
VOICES = 14              # copies of the take stacked into one crowd
VOICE_SPREAD = 0.028     # how far out of time each copy is (seconds, standard deviation)
VOICE_PITCH = 0.035      # how much higher or lower each copy is (share of its pitch, standard deviation)
CHANT_OVER_BEAT_DB = 3   # the chant this much louder than the beat around it, as in the reference


def take(path):
    """A take, mono at RATE, silence trimmed, with a soft start and end."""
    data, rate = sf.read(path, always_2d=True)
    mono = M.resample(data.mean(axis=1), rate, RATE)
    hop = RATE // 100
    n = len(mono) // hop
    level = np.sqrt((mono[:n * hop].reshape(n, hop) ** 2).mean(axis=1))
    loud = np.nonzero(level >= level.max() * 10 ** (-35 / 20))[0]
    start, end = max(0, loud[0] * hop - int(0.03 * RATE)), min(len(mono), (loud[-1] + 1) * hop + int(0.3 * RATE))
    x = mono[start:end].copy()
    a, b = int(0.04 * RATE), int(0.25 * RATE)
    x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    x[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    # Every take to one loudness over its loud part, so two different takes in one loop match.
    loud_part = level[level >= level.max() * 0.25]
    x *= 10 ** (-14 / 20) / (np.sqrt((loud_part ** 2).mean()) + 1e-12)
    # (Where its first word hits: the chant is placed so that lands on the bar.)
    first = int(np.argmax(level[loud[0]:loud[0] + 40] >= level.max() * 0.5)) + loud[0]
    return x, max(0, first * hop - start) / RATE


def crowd_of(x, seed):
    """Many copies of one chant, each a little out of time, higher or lower and somewhere left to right."""
    random = np.random.default_rng(seed)
    copies = []
    for i in range(VOICES):
        speed = 1 + (0 if i == 0 else random.normal(0, VOICE_PITCH))
        y = M.resample(x, RATE, RATE, speed=speed)
        delay = 0 if i == 0 else abs(random.normal(0, VOICE_SPREAD))
        pan = random.uniform(-0.9, 0.9)
        gain = 1.0 if i == 0 else random.uniform(0.45, 0.85)
        copies.append((y * gain, delay, pan))
    size = max(len(y) + int(d * RATE) for y, d, _ in copies)
    out = np.zeros((size, 2))
    for y, delay, pan in copies:
        d = int(delay * RATE)
        out[d:d + len(y), 0] += y * np.sqrt((1 - pan) / 2)
        out[d:d + len(y), 1] += y * np.sqrt((1 + pan) / 2)
    return out


def beat_channel(seed_base, bars):
    """One side's stomping and clapping crowd, dry, with room before the start for people a little early."""
    lead = int(0.2 * RATE)
    n = int(bars * BAR * RATE)
    dry = np.zeros(lead + n + int(1.0 * RATE))
    seed = seed_base
    for bar in range(bars):
        for beat, kind in enumerate(B.PATTERN):
            if kind is None:
                continue
            seed += 1
            at = (bar * 4 + beat) * BEAT
            x, start = B.crowd(B.one_stomp if kind == "stomp" else B.one_clap,
                               B.STOMPERS if kind == "stomp" else B.CLAPPERS, seed, at)
            x = M.peak_to(x, -1) * (1.0 if kind == "stomp" else 0.75)
            s = lead + int(start * RATE)
            dry[s:s + len(x)] += x[:len(dry) - s]
    return dry, lead


def fold(x, n, lead=0):
    """Wraps whatever runs past the loop's end back onto its start, and the `lead` before its start onto its end: no seam."""
    out = x[lead:lead + n].copy()
    if lead:
        out[n - lead:] += x[:lead]
    rest = x[lead + n:]
    while len(rest):
        part = rest[:n]
        out[:len(part)] += part
        rest = rest[n:]
    return out


def rms_db(x):
    return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)


def build(paths):
    bars = LOOP_BARS
    n = int(bars * BAR * RATE)
    left, lead = beat_channel(100, bars)
    right, _ = beat_channel(200, bars)
    beat = np.stack([left, right], axis=1)
    # Stomps are felt in the middle, so the two sides share some of each other.
    beat = np.stack([beat[:, 0] * 0.8 + beat[:, 1] * 0.2, beat[:, 1] * 0.8 + beat[:, 0] * 0.2], axis=1)
    chant = np.zeros_like(beat)
    for i, (bar, path) in enumerate(zip(CHANT_BARS, paths)):
        x, first = take(path)
        # (Each repeat a different crowd, so the repeats are not copies of each other.)
        voices = crowd_of(x, 300 + i)
        at = lead + int((bar * BAR - first) * RATE)
        end = min(len(chant), at + len(voices))
        chant[at:end] += voices[:end - at]
    # The beat folded first, so it is measured where it really plays; the chant set against the beat under it.
    beat = fold(beat, n, lead)
    chant = fold(chant, n, lead)
    loud = np.abs(chant).max(axis=1) > np.abs(chant).max() * 0.1
    chant *= 10 ** ((rms_db(beat[loud]) + CHANT_OVER_BEAT_DB - rms_db(chant[loud])) / 20)
    dry = beat + chant
    # One arena echo over all of it (the chant's take already has some, so the whole is not drowned), folded too.
    wet = fold(M.room(dry, 2.4, 0.5, seed=41, dark=4200), n)
    mix = M.band(wet, 70, 8000)
    # The join in the quietest 40 ms of the loop's last rest, never through a stomp: the file starts there.
    hop = int(0.01 * RATE)
    last_rest = int(((bars - 1) * BAR + 3 * BEAT) * RATE)
    # (Kept 0.2 s clear of the next stomp, whose early people start before the beat.)
    window = mix[last_rest + int(0.05 * RATE):last_rest + int((BEAT - 0.15) * RATE)].mean(axis=1)
    last_rest += int(0.05 * RATE)
    k = len(window) // hop
    level = np.convolve((window[:k * hop].reshape(k, hop) ** 2).mean(axis=1), np.ones(4), "valid")
    cut = last_rest + int(np.argmin(level)) * hop
    mix = np.concatenate([mix[cut:], mix[:cut]])
    return M.peak_to(mix, -3), cut / RATE


def bed():
    data, rate = sf.read(M.OUT / "ArenaBed.wav", always_2d=True)
    return np.stack([M.resample(data[:, c], rate, RATE) for c in range(2)], axis=1)


def listening_file(name, mix, mix_volume, bed_x, bed_volume=0.4):
    """As the player hears it in the arena: the crowd alone, the chant fading in, two loops, the fade out."""
    before, fade_in, fade_out, after = 6.0, 1.5, 0.9, 4.0
    run = len(mix) * 2 / RATE if len(mix) / RATE < 12 else len(mix) / RATE * 1.2
    total = int((before + run + fade_out + after) * RATE)
    out = np.tile(bed_x, (total // len(bed_x) + 1, 1))[:total] * bed_volume
    s = int(before * RATE)
    length = int((run + fade_out) * RATE)
    chant = np.tile(mix, (length // len(mix) + 1, 1))[:length] * mix_volume
    envelope = np.ones(length)
    a, b = int(fade_in * RATE), int(fade_out * RATE)
    envelope[:a] = np.linspace(0, 1, a)
    envelope[-b:] = np.linspace(1, 0, b)
    out[s:s + length] += chant * envelope[:, None]
    sf.write(LISTEN / f"{name}.wav", np.clip(out, -1, 1), RATE, subtype="PCM_16")


def main():
    LISTEN.mkdir(exist_ok=True)
    bed_x = bed()
    bed_level = rms_db(bed_x * 0.4)
    for name, chants in MIXES.items():
        path = SHOUTS / f"ChantMix_{name}.wav"
        mix, cut = build([SHOUTS / "Raw" / f"Chant_{chant}.mp3" for chant in chants])
        sf.write(path, mix, RATE, subtype="PCM_16")
        # Its volume in the game: about 5 dB over the arena crowd (played at 0.4), so it leads without drowning it.
        volume = round(float(10 ** ((bed_level + 5 - rms_db(mix)) / 20)), 2)
        listening_file(f"5_{name}", mix, volume, bed_x)
        seam = np.abs(mix[:int(0.02 * RATE)]).max(), np.abs(mix[-int(0.02 * RATE):]).max()
        print(f"{path.name}: {len(mix) / RATE:.3f} s at {TEMPO} BPM, join at {cut:.2f} s in, level {rms_db(mix):.1f} dB, "
              f"game volume {volume}, first/last 20 ms peak {seam[0]:.3f}/{seam[1]:.3f}")


if __name__ == "__main__":
    main()
