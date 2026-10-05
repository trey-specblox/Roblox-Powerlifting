# Fisch-style Control — Reference

## Reference Video
https://www.youtube.com/shorts/YBfUzL3bfTA

## Which Lift Uses This

**Squat, Phase 1.**

Relevant stat: **Squat Control**

> **Corrected.** This document previously assigned this mechanic to the Bench Press
> and its Start Control stat, and was titled "Bench Control". That was wrong and the
> two references had been swapped. The Bench's first phase is the Test Your Might
> mechanic in `testyourmight.md`; this Fisch-style control mechanic is the Squat's
> first phase. The current source of truth is:
>
> | Lift | Phase 1 | Phase 2 |
> |---|---|---|
> | Squat | **Fisch-style Control (this file)** | Depth timing check |
> | Bench | Test Your Might | Press timing check |
> | Deadlift | Typing | Lockout timing check |
>
> This mechanic is **Squat-only** for now. It is not currently used by any other
> lift.

## Purpose

This video is the reference for the control/balance mechanic used as the Squat's
first phase.

The mechanic represents the lifter controlling and stabilising the bar through the
squat.

## The Mechanic As Implemented

A success marker travels vertically along a track. The player holds a white bar
under it by clicking: each click pushes the bar upward, and gravity pulls it down
between clicks, so the bar has momentum rather than teleporting.

While the marker is inside the bar a progress meter fills; while it is outside, the
meter drains. A full meter passes the phase, an empty meter fails it.

## What Difficulty Changes

Higher attempt difficulty makes the phase harder through:

- faster marker movement
- more frequent marker retargeting
- a longer required hold

## What Squat Control Changes

Higher Squat Control:

- reduces how often the marker retargets
- shortens the required hold duration

It does **not** slow the marker down. That is what guarantees the phase can never
become automatic: however trained the lifter, they still have to track a marker
moving at the full speed the weight demands.

## Input

Repeated clicking, with momentum. On PC this is the mouse.

Input is routed through one abstract impulse action rather than a hardcoded mouse
button, so mobile, tablet and console can be added as bindings rather than as a
rewrite.

## Important

Use the reference for the interaction concept. Do not copy unrelated fishing
mechanics, artwork, sounds, UI or themes.

`GAME_DESIGN.md` is the source of truth for difficulty calculations.
`ControlPhaseConfig.luau` holds the actual balance values, which are PROVISIONAL.

If the reference is unclear, ask rather than inventing the missing behaviour.
