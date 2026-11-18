# The Nationals hall's crowd chants (GAME_DESIGN §39, user 2026-11-17: "Remake more but for Nationals ... different voices
# ... you can hear more people"; "just make sure its the same quality as the other ai generated voices"). Made exactly as
# the State chants (make_chant_mix.py: one finished stereo loop each, the stomp, stomp, clap beat at 144 BPM, the chant on
# every other bar, one arena echo, the arena's filtering, the join in the quietest moment), with three changes:
#   - new ElevenLabs takes in a new voice (a national championship crowd of men and women, deep and high voices mixed),
#     word-checked; none of the State takes is reused;
#   - MORE PEOPLE, NOT LOUDER: each chant bar stacks BOTH takes of its phrase (two different crowds), each spread into
#     more copies than State's (VOICES), and the loop sits at the same level over the arena crowd as State's;
#   - each mix has TWO phrases in turn (State had one, deadlift two):
#       ForTheWin  LIFT OR LOSE / LET'S GO     (making it wins the lifter their class)
#       Squat      SQUAT IT UP / STAND IT UP
#       Bench      PRESS IT UP / LOCK IT OUT
#       Deadlift   LIFT IT UP / PICK IT UP     (the user's deadlift chants, new voices)
# The game plays each looped behind the curtain while the chant builds (NationalsChant: fading up over BuildSeconds).
#
#   uv run --no-project --with numpy --with soundfile python art/scripts/make_nationals_chant_mix.py
# writes NatChantMix_<Name>.wav to D:\Powerlifting Roblox Extras\Sounds\Shouts (ElevenLabs audio stays outside the repo)
# and listening files (the arena crowd, the chant fading in, two loops, the fade) to ...\Sounds\ChantListen.
import importlib.util
import os

import numpy as np
import soundfile as sf

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("make_chant_mix", os.path.join(_HERE, "make_chant_mix.py"))
CM = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(CM)
M, B = CM.M, CM.B
RATE, BAR, BEAT = CM.RATE, CM.BAR, CM.BEAT

# Each copy of a take is one more person: State stacks 14 of one take; here 18 of each of two takes.
CM.VOICES = 18
MIXES = {
    "ForTheWin": ("LiftOrLose", "LetsGo"),
    "Squat": ("SquatItUp", "StandItUp"),
    "Bench": ("PressItUp", "LockItOut"),
    "Deadlift": ("LiftItUp", "PickItUp"),
}


def chant_bar(phrase, seed):
    """Both takes of a phrase as two different crowds, lined up on their first word."""
    out = None
    first_at = 0.0
    for k, letter in enumerate("AB"):
        x, first = CM.take(CM.SHOUTS / "Raw" / f"NatChant_{phrase}_{letter}.mp3")
        voices = CM.crowd_of(x, seed + k * 17)
        if out is None:
            out, first_at = voices, first
            continue
        shift = int((first_at - first) * RATE)
        if shift >= 0:
            voices = np.concatenate([np.zeros((shift, 2)), voices])
        else:
            voices = voices[-shift:]
        size = max(len(out), len(voices))
        both = np.zeros((size, 2))
        both[:len(out)] += out
        both[:len(voices)] += voices
        out = both
    return out, first_at


def build(phrases):
    bars = CM.LOOP_BARS
    n = int(bars * BAR * RATE)
    left, lead = CM.beat_channel(500, bars)
    right, _ = CM.beat_channel(600, bars)
    beat = np.stack([left, right], axis=1)
    beat = np.stack([beat[:, 0] * 0.8 + beat[:, 1] * 0.2, beat[:, 1] * 0.8 + beat[:, 0] * 0.2], axis=1)
    chant = np.zeros_like(beat)
    for i, (bar, phrase) in enumerate(zip(CM.CHANT_BARS, phrases)):
        voices, first = chant_bar(phrase, 700 + i * 31)
        at = lead + int((bar * BAR - first) * RATE)
        end = min(len(chant), at + len(voices))
        chant[at:end] += voices[:end - at]
    beat = CM.fold(beat, n, lead)
    chant = CM.fold(chant, n, lead)
    loud = np.abs(chant).max(axis=1) > np.abs(chant).max() * 0.1
    chant *= 10 ** ((CM.rms_db(beat[loud]) + CM.CHANT_OVER_BEAT_DB - CM.rms_db(chant[loud])) / 20)
    dry = beat + chant
    wet = CM.fold(M.room(dry, 2.4, 0.5, seed=43, dark=4200), n)
    mix = M.band(wet, 70, 8000)
    hop = int(0.01 * RATE)
    last_rest = int(((bars - 1) * BAR + 3 * BEAT) * RATE)
    window = mix[last_rest + int(0.05 * RATE):last_rest + int((BEAT - 0.15) * RATE)].mean(axis=1)
    last_rest += int(0.05 * RATE)
    k = len(window) // hop
    level = np.convolve((window[:k * hop].reshape(k, hop) ** 2).mean(axis=1), np.ones(4), "valid")
    cut = last_rest + int(np.argmin(level)) * hop
    mix = np.concatenate([mix[cut:], mix[:cut]])
    return M.peak_to(mix, -3), cut / RATE


def main():
    CM.LISTEN.mkdir(exist_ok=True)
    bed_x = CM.bed()
    bed_level = CM.rms_db(bed_x * 0.4)
    for name, phrases in MIXES.items():
        path = CM.SHOUTS / f"NatChantMix_{name}.wav"
        mix, cut = build(phrases)
        sf.write(path, mix, RATE, subtype="PCM_16")
        # The same place over the arena crowd as the State chants (5 dB over the bed at 0.4): more people, not louder.
        volume = round(float(10 ** ((bed_level + 5 - CM.rms_db(mix)) / 20)), 2)
        CM.listening_file(f"Nat_{name}", mix, volume, bed_x)
        seam = np.abs(mix[:int(0.02 * RATE)]).max(), np.abs(mix[-int(0.02 * RATE):]).max()
        print(f"{path.name}: {len(mix) / RATE:.3f} s, join at {cut:.2f} s in, level {CM.rms_db(mix):.1f} dB, game volume "
              f"{volume}, first/last 20 ms peak {seam[0]:.3f}/{seam[1]:.3f}")


if __name__ == "__main__":
    main()
