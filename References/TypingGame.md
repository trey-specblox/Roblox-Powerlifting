# Deadlift Typing — Reference

## Reference Video
https://www.youtube.com/shorts/VHWM80RmkVo

## Purpose

This reference demonstrates the style of typing minigame I want used during the Deadlift.

The player will type a displayed phrase while their character performs the pull.

## What I Want From the Reference

Pay attention specifically to:

- How text is presented
- How the player's typed characters are displayed
- How correct characters are indicated
- How incorrect characters are indicated
- How mistakes are handled
- How the timer works
- How completion is detected
- How difficulty can affect typing

## RPF Implementation — Fluid Typing Pull

Relevant stat: **Pull Strength**

A vertical bar rises from the floor toward lockout. **One authoritative progress
value** drives its height, and the bar reaching lockout IS the pass — there is
deliberately no second requirement behind a visually completed bar.

The player types a **continuous line of short powerlifting cues**, left to right,
the way they would type any words:

```
   BRACE DRIVE PULL HIPS LOCK GRIP
   ^^^^^^^^^^^^|
   done        current (highlighted in place, same size)
```

- completed characters are dimmed green
- the current character carries a highlight and an underline cursor, and stays
  the same size as the rest of the line
- upcoming characters fade with distance, so the eye is pulled forward
- the line scrolls to keep the current character at a fixed point, so it never
  reflows or runs out of room

**Spaces are rendered but never typed.** Word boundaries advance on their own, so
the line reads as words while the player types one unbroken stream. That also
keeps the spacebar free for the lockout that follows.

The player can read several characters or words ahead and type fluidly at normal
speed. Nothing throttles, debounces or stalls input.

> **Superseded presentations.** This document previously described typing a
> displayed *phrase*, and then a **giant single character** reacted to one key at
> a time. Both were discarded: the phrase version tested reading rather than
> typing, and the giant character capped a fluent player at the speed they could
> read one letter. The giant-token idea is kept for a future **controller**
> vocabulary, where a prompt genuinely is one button at a time and there is
> nothing to read ahead to.

### The progress model

```
correct token  ->  progress += progressPerToken
wrong token    ->  progress -= mistakePenalty, plus a ~0.12s slip stall
no input       ->  progress -= sagPerSecond, continuously

progress >= completionThreshold  ->  PASSED, terminal
budget expires                   ->  NO LIFT
```

After a mistake the **expected character does not change**, so a wrong key never
cascades into the rest of the cue — the player simply has to hit the right one.
Progress reaching zero is a bad position, not a loss; running out of time is the
only way to fail.

Once passed, progress freezes, sag stops and no further input is processed.

### Cues are headroom, not a script

Completion is by **progress**, never by reaching the end of the text. More cues
are generated than a pull needs, so a player fighting the sag can never run out
of characters to type.

Cues contain **no spaces**, which keeps the spacebar free for the Lockout press
one second later.

## What Difficulty Changes

Difficulty scales through the **amount of typing**, not its speed:

| | 80% | 100% | 110% |
|---|---|---|---|
| Characters to lockout | 9 | 18 | 24 |
| Sag per second | 2.0 | 2.6 | 4.1 |
| Mistake penalty | 2.0 | 4.0 | 6.0 |
| Window | 8.0s | 10.0s | 12.0s |
| **Required rate** | 1.59/s | 2.40/s | 3.00/s |
| **WPM equivalent** | 19 | 29 | 36 |

Average adult typing is around 40 WPM and a slow typist manages 20, so even a
110% pull sits under what a modest typist can do. **This is deliberately not a
typing-speed test.**

**DO NOT RAISE THE TOP-END REQUIRED RATE.** If character-first reading makes 110%
feel too demanding in play, the approved levers are the WINDOW and the SAG.

## What Pull Strength Changes

Higher Pull Strength:

- increases progress gained per correct character
- reduces the bar's sag
- reduces the mistake penalty

A trained lifter needs **fewer keystrokes, not faster ones**. At a 110% pull:

| Pull Strength | Characters | WPM |
|---|---|---|
| 0 | 24 | 36 |
| 10,000 | 18 | 24 |
| max | 17 | 22 |

It does **not** reduce the completion threshold, the time window or the cue
content. That is what guarantees the pull never becomes automatic: seventeen
characters still have to be typed correctly against a live sag.

## Input

Tokens are **abstract**, not keyboard letters. The authoritative simulation
compares strings and never asks which vocabulary produced them, so controller and
touch vocabularies can be added later without touching it. Only the keyboard
vocabulary (A-Z) is built.

### PC capture is text entry, not key presses

A hidden, focused one-pixel TextBox receives the typing, and tokens come from the
**text** it reports. Each change is read, the box is cleared immediately, and the
character is uppercased — so `i` and `I` both yield `I`, and Caps Lock is
irrelevant.

**This is load-bearing, not stylistic.** Reading individual keys does not work for
the whole alphabet: Roblox's built-in controls claim some letters, and a listener
or keybind competing for them loses. In testing, plain `i` and plain `o` never
reached the game while every other letter did, and holding Shift bypassed it.
Four attempts at the key-event layer failed — an EnumItem-keyed table,
`KeyCode.Name`, `KeyCode.Value`, and claiming all 26 letters through
ContextActionService above the built-in priority. Text entry sidesteps the contest
because the OS delivers it rather than it being contended for.

If anyone later "simplifies" this back to `UserInputService.InputBegan` or
ContextActionService keybinds, those two letters will silently stop working.

### Paste

Typing changes the text one character at a time; a paste delivers the clipboard in
a single change. Any change carrying more than two characters is treated as bulk
insertion and only its first character is accepted, so pasting a cue yields one
character rather than a finished pull. The allowance is two so an engine hitch
coalescing two real keystrokes costs nothing.

This does **not** make automation impossible and is not claimed to. A script
typing one character at a time at a human rate is indistinguishable from a human;
this only removes the trivial clipboard shortcut.

## Lockout

After the pull, a **1.0 second** transition, then the Deadlift Lockout timing
check, using the reusable system described in `References/DBD.md`.

Single yellow target, no Perfect zone. Relevant stat: **Lockout**.

```
Pull  FAIL -> NO LIFT, and Lockout never begins
Pull  PASS -> 1.0s transition -> Lockout
Lockout FAIL -> NO LIFT
Lockout PASS -> GOOD LIFT
```

## Cue Content

Use original RPF/gym-themed cues rather than copying quotations from the
reference. A-Z only: no spaces, digits, punctuation or apostrophes.

Cue content is stored in `TypingContentConfig.luau`, separately from the
minigame logic, so adding a cue is adding a string to a list.

## Important

The reference is for understanding the gameplay interaction.

Do not copy unrelated visuals, sounds, text, or other systems.

If you cannot access or properly understand the reference video, tell me instead of guessing.