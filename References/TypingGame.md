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

## RPF Implementation

When the Deadlift begins, the player receives a phrase to type.

The player must correctly type the phrase while the lift progresses.

Difficulty can potentially affect:

- Phrase length
- Time available
- Error tolerance
- Required typing speed
- Recovery from mistakes

After completing the typing portion, the player proceeds to the Deadlift Lockout Skill Check.

The Lockout portion should use the reusable system described in:

`References/skillcheck.md`

GAME_DESIGN.md determines the actual difficulty and stat calculations.

## Phrase Content

Use original RPF/gym-themed phrases rather than automatically copying quotations from the reference.

Phrase content should be stored separately from the actual typing-minigame logic so more phrases can easily be added later.

## Important

The reference is for understanding the gameplay interaction.

Do not copy unrelated visuals, sounds, text, or other systems.

If you cannot access or properly understand the reference video, tell me instead of guessing.