# Bench Control — Reference

## Reference Video
https://www.youtube.com/shorts/YBfUzL3bfTA

## Purpose

This video is a reference for the control/balance minigame I want used during the Bench Press.

The mechanic should represent the lifter controlling and stabilizing the bar.

## What I Want From the Reference

Pay attention specifically to:

- How the player controls the indicator
- How the safe area works
- How the indicator attempts to leave the safe area
- How player input corrects its movement
- How momentum feels
- How the danger/failure areas work
- How long the player must maintain control
- How difficulty changes the experience

## RPF Implementation

This mechanic represents controlling the bar during the Bench Press.

The player's Start Control stat should influence how difficult maintaining control is.

Higher Start Control can affect:

- Larger safe zone
- Slower unwanted movement
- Better stability
- Better recovery
- More forgiving control

Higher calculated lift difficulty should do the opposite.

The mechanic should feel increasingly unstable as the player's attempt approaches or exceeds their capabilities.

GAME_DESIGN.md is the source of truth for the actual difficulty calculations.

## Important

Use the reference for the interaction concept.

Do not copy unrelated fishing mechanics, artwork, sounds, UI, or themes.

Convert the concept into something that visually and mechanically represents controlling a barbell during a bench press.

If you cannot access or properly understand the reference video, tell me instead of guessing.