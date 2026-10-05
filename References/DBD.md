# Skill Check — Reference

## Reference Video
https://www.youtube.com/watch?v=G1zOTjYRXdE

## Purpose

This video is a reference for the timing-based Skill Check minigame used throughout RPF.

Study the referenced minigame and use it as inspiration for the core interaction.

## What I Want From the Reference

Pay attention specifically to:

- How the indicator/needle moves
- How the player activates the skill check
- How the single target zone works
- How timing determines the result
- How success is communicated
- How failure is communicated
- How speed changes the difficulty
- How zone size changes the difficulty

## RPF Implementation

The same underlying Skill Check system should be reusable across multiple lifts.

It will be used for things such as:

### Squat
Depth Awareness / achieving legal depth.

### Bench
Press Power / press execution.

### Deadlift
Lockout / completing the lift.

Each use can have different difficulty settings and visual presentation while sharing the same underlying system.

Relevant player stats should affect:

- Needle speed
- Target-zone size
- Reaction window

Higher relevant stats should make execution easier.

Higher calculated lift difficulty should make execution harder.

GAME_DESIGN.md is the source of truth for formulas and stat scaling.

## Important

Build this as a reusable minigame system rather than creating three completely separate copies of the same mechanic.

This reference is inspiration and should not be copied exactly.

If you cannot access or properly understand the reference video, tell me instead of guessing.