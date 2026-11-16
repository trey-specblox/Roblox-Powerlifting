"""Time-reversed copy of a stretch of an exported animation (.rbxmx KeyframeSequence), e.g. the lifter racking the bar
as his own set-up played backwards: the squat walk-out reversed walks the bar back into the rack, sets it in the J-cups,
dips out from under it and steps back (user 2026-11-15: "the lifter HAS to unrack, and rack the bar themselves").

    python art/scripts/reverse_animation.py <in.rbxmx> <out.rbxmx> <name> <from_s> <to_s> [speed]

Keeps every keyframe between from_s and to_s, played from to_s back to from_s, starting at 0, optionally faster
(speed 1.2 = 20% quicker). Poses are copied as they are; only the times change (and the sequence's name). Read-only on
the input. Prints where a moment of the input lands in the output: out_t = (to_s - in_t) / speed.
"""
import re
import sys


def main():
    src, dst, name, t_from, t_to = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5])
    speed = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
    text = open(src, encoding="utf-8").read()
    head, *frames = text.split('<Item class="Keyframe"')
    # Each keyframe chunk ends with its own closing "</Item>" (the keyframe); the last one also carries the sequence's
    # closing "</Item></roblox>": keep that aside for the end.
    closing = "</Item></roblox>"
    last = frames[-1].rstrip()
    if not last.endswith(closing):
        sys.exit("Unexpected file ending: " + last[-60:])
    frames[-1] = last[: -len(closing)] + "\n"
    kept = []
    for chunk in frames:
        t = float(re.search(r'<float name="Time">([-0-9.eE]+)</float>', chunk).group(1))
        if t_from - 1e-6 <= t <= t_to + 1e-6:
            new_t = (t_to - t) / speed
            chunk = re.sub(r'<float name="Time">[-0-9.eE]+</float>', '<float name="Time">%.4f</float>' % new_t, chunk, count=1)
            kept.append((new_t, chunk))
    kept.sort(key=lambda kv: kv[0])
    head = re.sub(r'(<string name="Name">)[^<]*(</string>)', r'\g<1>%s\g<2>' % name, head, count=1)
    head = re.sub(r'<bool name="Loop">true</bool>', '<bool name="Loop">false</bool>', head)
    out = head + "".join('<Item class="Keyframe"' + c for _, c in kept) + closing
    open(dst, "w", encoding="utf-8").write(out)
    print("REVERSED %s: %d keyframes, %.2f s (input %.2f..%.2f at x%.2f)" % (
        name, len(kept), (t_to - t_from) / speed, t_from, t_to, speed))


if __name__ == "__main__":
    main()
