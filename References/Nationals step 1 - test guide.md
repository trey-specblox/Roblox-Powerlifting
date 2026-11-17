# Nationals step 1 — test guide (2026-11-17)

What step 1 does: every 2 hours, every player holding a Nationals spot who signed up, **in any server**, is sent into **one Nationals server**. For now they arrive in the **State arena with NATIONALS written on it**. That arena is a **temporary stand-in**: your own Nationals arena, built from your photos, replaces it later. The meet itself (classes, titles, x5 pot, Worlds spot) is step 2.

It is **not live for players yet** (`NationalsConfig.Live = false` in `src/shared/Config/NationalsConfig.luau`). In the real game, **only you (admin)** see the NATIONALS row, and test Nationals come **every 10 minutes** and need only **1 lifter**.

## What I already tested in Studio (passed)

- Signing up without a spot is refused ("0 / 10 toward nationals in 59 kg").
- With the spot (admin panel, NATIONALS PLACINGS 10), signing up works, and the row counts "1 SIGNED UP".
- A player **lifting in a Local meet** got the 30-second warning, was **pulled out of the meet**, and was walked into the arena: "YOU ARE AT NATIONALS · 59 kg · 1 LIFTER".
- While the arena hosts Nationals, the State meet can't be joined there.
- LEAVE goes back to the gym, and the arena says STATE again.
- With 2 lifters needed and only 1 signed up: "Not enough lifters … (1 of 2)", and you stay signed up for the next one.
- TAKE OFF removes your name.

**Studio can't test the real thing**: moving players between servers. That part needs the live game.

## Live test (you, about 15 minutes)

1. Commit and **publish** (File > Publish to Roblox).
2. On the Creator Dashboard, check that the place's **Max Players is at least 40**. A Nationals server can't hold more players than that.
3. Join the real game. Open **ADMIN > PLAYER STATS**, and set **NATIONALS PLACINGS** to **10** for yourself.
4. Press **M** (MEETS). The last row should say **NATIONALS · x5 · TEST** with a countdown. Press **SIGN UP**.
   - Expected: "You're signed up for Nationals (your class)…", and the row turns yellow.
5. Optional, to test the pull-out: sign up for a Local meet and start it from ADMIN > START A MEET NOW.
6. Wait for the countdown (at most 10 minutes). 30 seconds before: "Nationals starts in 30 seconds!"
7. At the start: "GATHERING LIFTERS…", then "Taking you there now", then **Roblox's teleport loading screen**.
8. You should arrive **in the State arena with NATIONALS banners**, and the row should say **YOU ARE AT NATIONALS**.
9. Press **LEAVE** on that row. You should be teleported back into a normal server.

If two of you test (a second account also needs NATIONALS PLACINGS 10, set from your admin panel while they're in your server), sign up **in different servers**. You should both land in the **same** Nationals server.

## If something goes wrong

Tell me what the screen said at each step. Where it stopped is the useful clue:
- Stuck on "GATHERING" for over a minute: the shared list (MemoryStore) isn't answering.
- "The Nationals server couldn't be opened": reserving the server failed.
- "Couldn't get you to Nationals (…)": the teleport failed. The text in brackets is Roblox's reason.
- You land in a normal-looking gym but never reach the arena: the Nationals server couldn't read who it's for.

## Costs

No Robux. MemoryStore and reserved servers are free within Roblox's limits; this uses a tiny fraction of them. A Nationals server is one more server running for about 30–40 minutes once the meet exists.
