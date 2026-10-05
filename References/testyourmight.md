# Test Your Might — Reference

## Reference Video
https://www.youtube.com/watch?v=7ciam3sbOCE

## Which Lift Uses This

**Bench Press, Phase 1.**

Relevant stat: **Start Control**

> **Corrected.** This document previously assigned this mechanic to Squat Control.
> That was wrong and the two references had been swapped. The Squat's first phase is
> the Fisch-style control mechanic in `FischeGame.md`; this Test Your Might mechanic
> is the Bench's first phase. The current source of truth is:
>
> | Lift | Phase 1 | Phase 2 |
> |---|---|---|
> | Squat | Fisch-style Control | Depth timing check |
> | Bench | **Test Your Might (this file)** | Press timing check |
> | Deadlift | Typing | Lockout timing check |

## Purpose

This video is the reference for the rapid-input power mechanic used as the Bench
Press's first phase.

The mechanic should represent the lifter building explosive drive off the chest.

## The Mechanic As Implemented

A **circular** progress meter. The player's ring starts at the outer edge (0%) and
contracts inward as progress builds; decay pushes it back out. The inner success
circle is 100%.

**Reaching the inner circle is the single authoritative completion condition.** The
same value that drives the ring's radius is the value the pass is tested against, so
the player can never finish the circle and then be told they lacked something else.
The only way to lose the phase is to run out of the time budget.

The mashing is interrupted two or three times by a **HOLD**:

```
MASH!  ->  GET READY TO HOLD  ->  HOLD!  ->  MASH!  ->  ...  ->  inner circle = PASS
```

| During HOLD the player... | Result |
|---|---|
| presses and keeps it held | progress preserved, decay paused |
| does nothing | progress slips outward |
| keeps spam clicking | progress lost per click, past a short grace |

A hold has **no deadline and no press budget**. It ends when the input has been held
continuously for the required duration, and persists until then. A legitimate
continuous hold therefore always succeeds, however late it starts. There is no
"failed hold" outcome.

Holds are triggered by **progress**, not by the clock — they fire when the ring
crosses set fractions of the way in. A clock-based schedule could not work: at the
input ceiling the circle fills in about a second on a light attempt, so any hold
placed late enough to be fair to a normal player would arrive after a fast player had
already finished.

Once the inner circle is reached the phase passes immediately and nothing further is
processed.

> **Superseded prototypes.** This file previously described a *vertical* meter with
> no interruption at all. A later prototype used fixed-length **STOP** windows that
> failed the phase outright if violated. Both are gone. STOP became HOLD because
> losing progress is a fairer punishment than losing the lift, and because an
> instant failure made one mistimed reaction click fatal.

## What Difficulty Changes

Higher attempt difficulty makes the phase harder through:

- a longer climb to 100% (more accepted inputs needed)
- faster decay, so hesitation costs more
- more holds, and longer required holds
- a longer designed active window, so the effort must be sustained

The inner circle is the **same size on every attempt**. Difficulty lives in how hard
the ring is to move, not in where the finish line sits. An earlier version drew a
smaller target for harder attempts; that was dropped because it split the player's
attention between "how far in am I" and "how small is my target".

Difficulty is NOT expressed primarily as a demand for faster clicking. An earlier
balance pass required roughly 8.5 inputs per second at a 110% attempt, which tests
the player's hand rather than the character. The current model keeps the required
band at roughly 2.75–6.25 inputs per second across 80–110%.

## What Start Control Changes

Higher Start Control:

- increases the progress gained per accepted input
- reduces decay
- lengthens the warning before a hold
- reduces the progress lost to clicks during a hold

It does **not** reduce the number of holds, shorten the required hold duration,
lower the completion threshold or shorten the duration. That is what guarantees the
phase can never become automatic: however trained the lifter, they still have to
cross the same circle within the same time and still have to hold just as long.

## Input

Rapid repeated input, plus a sustained hold. On PC this is the mouse.

Input is routed through one abstract action rather than a hardcoded mouse button, so
mobile, tablet and console can be added as bindings rather than as a rewrite. Both
the press **and the release** are reported, because telling a continuous hold from a
burst of clicks is impossible without knowing when the input went back up.

There is a **useful input ceiling**. Inputs arriving faster than it are discarded for
scoring, on both client and server. A discarded press still counts as the input being
*down*, so the ceiling limits what mashing pays, not what the button is doing. The
ceiling is fixed first and every threshold is derived beneath it, so no attempt can
become a speed contest beyond it.

## Important

`GAME_DESIGN.md` is the source of truth for stat formulas and difficulty scaling.
`PowerPhaseConfig.luau` holds the actual balance values, which are PROVISIONAL.

A basic repeated-click autoclicker satisfies zero holds, so it cannot finish the
phase. **This is not the same as being automation-proof, and the mechanic must not be
described as cheat-proof.** The client has to know a hold is active in order to draw
the instruction, so automation that reads that state can issue one press and hold.
Any telegraphed mechanic has this property. See `PowerPhaseService.luau` for the full
statement.

If the reference is unclear, ask rather than inventing the missing behaviour.
