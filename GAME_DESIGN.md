## MECHANIC ASSIGNMENT — CURRENT SOURCE OF TRUTH

Each lift has its own first phase. All three converge on the same reusable timing
skill check as their second phase.

| Lift | Phase 1 | Phase 2 | Phase 1 stat | Phase 2 stat |
|---|---|---|---|---|
| Squat | Fisch-style Control (`References/FischeGame.md`) | Depth timing check (`References/DBD.md`) | Squat Control | Depth Awareness |
| Bench | Test Your Might power (`References/testyourmight.md`) | Press timing check (`References/DBD.md`) | Start Control | Press Power |
| Deadlift | Fluid Typing pull (`References/TypingGame.md`) | Lockout timing check (`References/DBD.md`) | Pull Strength | Lockout |

The Fisch-style control mechanic is **Squat-only**. The Test Your Might mechanic is
**Bench-only**. The timing check is shared by all three, which is why it was built
once and is driven entirely from per-phase configuration.

> **This table is a correction.** `testyourmight.md` and `FischeGame.md` were
> originally swapped: Test Your Might was assigned to Squat Control and the
> Fisch-style mechanic to the Bench. Sections 7 and 9 below, and both reference
> files, have been corrected to match this table. Where anything in this document
> still disagrees, this table wins.

Failing either phase of a lift is a NO LIFT and the second phase does not run.

---

1. Game Vision

RPF is a progression-focused Roblox powerlifting RPG/simulator built around the real concepts of Squat, Bench Press, Deadlift, weight classes, training, meets, equipment, records and competition.
The goal isn't simply:
click → gain strength → rebirth.
The player should actually have to perform their lifts.
A player's performance comes from three things:
CHARACTER PROGRESSION
        +
PLAYER SKILL
        +
POWERLIFTING STRATEGY
        ↓
PERFORMANCE
A highly developed character should make lifting easier, but a skilled player should still perform better than an unskilled player with identical stats.
The long-term fantasy is:
NEW LIFTER
    ↓
TRAIN
    ↓
LOCAL MEETS
    ↓
IMPROVE TOTAL
    ↓
EQUIPMENT / MONEY / COSMETICS
    ↓
NATIONALS
    ↓
WORLDS
    ↓
RECORD CHASING
    ↓
ELITE / ENDGAME LIFTER

2. Core Gameplay Loop TRAIN
  ↓
Increase lift-specific stats
  ↓
TEST COMP MAXES
  ↓
Establish forecasted S/B/D
  ↓
ENTER MEET
  ↓
Choose attempts
  ↓
Perform lifting minigames
  ↓
Build total / Sheffield-style performance
  ↓
Earn rewards
  ↓
Buy equipment / food / cosmetics
  ↓
Improve character
  ↓
Enter harder competitions
The important design principle is that training and competition aren't the same activity.
Training develops the character.
Competition tests the character and the player controlling them.
3. The Three Competition Numbers

> **See section 29 for the finalized progression specification.** Player-facing
> terminology is now **Competition Number**, not "Forecasted". The `Forecasted`
> naming below and in code is retained only until the implementation rename.
>
> **See section 33 for Competition Scale.** A second per-lift quantity now sits
> beside Competition Number: Scale is the heaviest weight the lifter has actually
> **proven** in competition, while CN is what training has built. The physical
> difficulty formula below is **unchanged** — it still divides by Competition
> Number. Scale adds a separate, capped challenge modifier on top of it, and
> **meets no longer increase CN at all**.

Every player should have three major performance values:
Forecasted Squat
Forecasted Bench
Forecasted Deadlift
Squat:    210 kg
Bench:    140 kg
Deadlift: 250 kg

Forecasted Total:
600 kg
These represent approximately what the character is capable of under competition conditions.
Training changes these numbers.
The player then chooses actual attempts during competition.
Base physical intensity
Physical Intensity =
Attempt Weight / Forecasted Max
Forecasted Squat = 200 kg
Attempt = 180 kg

180 / 200 = 0.90
That's a 90% attempt. 

But: 
Attempt = 210 kg

210 / 200 = 1.05
Now they're attempting 105% of their expected capability.
That should dramatically increase difficulty.
Execution Difficulty
Each lift then evaluates the relevant technical stats.
Squat: 
Control
Depth Awareness

Bench:
Start Control
Press Power
Deadlift:
Pull Strength
Lockout
Modifier layer
Then modifiers influence the result:
Height / Leverages
Equipment
Coach
Origin trait
Clan

Therefore conceptually: 
Attempt Intensity
       ↓
Base Difficulty
       +
Execution Difficulty
       ↓
Modifiers
       ↓
FINAL MINIGAME DIFFICULTY
       ↓
0–100
Your scale works well as the universal language of the game:
Difficulty
Classification
0–10
Extremely Easy
10–20
Beginner
20–35
Easy
35–50
Moderate
50–65
Hard
65–80
Very Hard
80–90
Expert
90–97
Extremely Difficult
97–100
Near Maximum

Then every minigame translates this number differently.
For example:
Difficulty 20
→ slow target
→ large zones
→ generous timing

Difficulty 95
→ extremely fast target
→ tiny zones
→ small reaction window
should become a centralized progression curve.
That allows enormous stat numbers without players immediately becoming perfect.
Claude should eventually build something like: 
Stat
 ↓
Progression Curve
 ↓
Effective Stat
 ↓
Minigame Modifier
rather than scattering those numbers across scripts. 
7. Squat
Competition Squat
Purpose:
Establish/improve the player's forecasted squat.
## Squat

### Control Phase
The player completes the Squat Control minigame: a Fisch-style control mechanic.

Reference: `References/FischeGame.md`

Relevant Stat: Squat Control

> **Corrected.** This section previously pointed at `References/testyourmight.md`.
> The two mechanic references had been swapped. The Squat's first phase is the
> Fisch-style control mechanic; Test Your Might belongs to the Bench. See the
> mechanic assignment table at the top of this document.

See `References/FischeGame.md` for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior.


### Depth Phase
The player completes a timing Skill Check to achieve legal depth.

Reference: `References/DBD.md`

Relevant Stat: Depth Awareness

Player attempts to keep an indicator inside a moving target.
Control influences:
target movement speed
target size
stability
reaction time
required successful actions
Your proposed baseline can begin around:
Difficulty 20 → 100 px/sec
Difficulty 50 → 180 px/sec
Difficulty 80 → 280 px/sec
Difficulty 95 → 400 px/sec
These should be configuration values, not permanently hardcoded assumptions.
Depth check
A Dead-by-Daylight- style circular skill check.(Check (skillcheck) for reference and direction) https://www.youtube.com/watch?v=G1zOTjYRXdE 
See references/DBD.mdfor the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 

Depth Awareness influences:
target-zone size
needle speed
reaction window
Failure can result in:
HIGH SQUAT / RED LIGHT
rather than simply making the character fall over.
That's important because it teaches actual powerlifting concepts.
8. Each variation of lifts players will be able to train those specific variations for the stat.
. Squat Training Variations
Competition Squat (Stat: Forecasted squat PR)
Primary purpose:
Forecasted Squat ↑
Pause Squat (Stat: Control)
Primary:
Control ↑
Secondary effect:
Makes the control challenge more manageable during future squats.
Tempo Squat (Stat: depth Awareness)
Primary:
Depth Awareness ↑
Training should make future depth skill checks more forgiving.
That gives each exercise a reason to exist.
9. Bench Press
Bench should feel mechanically different from squat.
Primary stats:
Bench Forecasted Pr
Start Control
Press Power
Start Control mechanic
## Bench Press

### Power Phase (Test Your Might)
The player builds explosive drive off the chest through rapid repeated input.

Reference: `References/testyourmight.md`

Relevant Stat: Start Control

> **Corrected.** This section previously described a Fisch-style "Bar Control Phase"
> and pointed at `References/FischeGame.md`. The two mechanic references had been
> swapped. The Bench's first phase is the Test Your Might rapid-input power
> mechanic; the Fisch-style control mechanic belongs to the Squat and is Squat-only.
> See the mechanic assignment table at the top of this document.
>
> The stat is unchanged: Start Control still drives the Bench's first phase.

A **circular** progress meter. The player's ring starts at the outer edge and
contracts inward as progress builds; decay pushes it back out. The inner success
circle is 100% complete, and **reaching it is the single authoritative completion
condition** — there is no separate "power" requirement to satisfy afterwards.

The mashing is interrupted two or three times by a **HOLD**. The instruction changes
from `MASH!` to `HOLD!` and the player must press and keep the input held:

- holding correctly **preserves** progress (decay pauses)
- not holding lets progress **slip outward**
- continuing to spam click **costs** progress

A hold has no deadline and no press budget. It ends when the input has been held
continuously for the required duration, so a legitimate continuous hold can never
fail. Holds are triggered by **progress**, not by the clock, so every player meets
every hold on the way in however fast they mash, and no hold can arrive after the
circle is already complete.

Once the inner circle is reached the phase passes immediately, progress freezes, and
no further decay, hold or input is processed.

This phase tests explosive repeated input plus one deliberate mode switch; the Press
phase below provides the precision timing, so this one does not duplicate it. There
is no moving indicator and no strike zone.

> **Superseded.** An earlier prototype used a *vertical* meter with no hold, and a
> later one used fixed STOP windows that failed the phase outright. Both are gone.
> The hold replaced STOP because a punishment of lost progress is fairer than an
> instant loss, and the circle replaced the bar because the inner target reads as a
> finish line.

See `References/testyourmight.md` for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior.


### Press Phase
The player completes a timing Skill Check.

See references/DBD.txt for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 


Relevant Stat: Press Power


BAR
 ↓

Player maintains control of the bar.
Higher Start Control: 
larger safe area
slower instability
better recovery
slower danger movement
Press command
Then transition into a timing/skill check.
Press Power determines:
target-zone size
needle speed
reaction window
This also gives you room to represent commands:
START
PRESS
RACK
10. Bench Variations
Competition Bench (Bench Forecasted Pr)
Improves:
Forecasted Bench
Paused Bench (Press Power)
Improves:
Press Power
and/or competition pause execution.
Slingshot Bench (Bench Control)
Improves:
Start Control
and makes the balance portion more forgiving during training.
11. Deadlift
Deadlift should have its own identity.
Your unusual idea here could actually make it memorable.
Phase 1 — Fluid Typing pull

Relevant Stat: Pull Strength

A vertical bar rises from the floor toward lockout, driven by ONE authoritative
progress value. The bar reaching lockout IS the pass; there is no second
requirement behind a visually completed bar.

The player types a CONTINUOUS LINE of short original powerlifting cues, left to
right, the way they would type any words. Completed characters dim green, the
current one carries a highlight and cursor at normal size, and upcoming ones fade
ahead. The line scrolls to keep the cursor in place. Spaces are rendered but never
typed, so word boundaries advance on their own and the spacebar stays free for the
lockout. Each correct character raises the bar; the bar sags continuously, so
hesitation costs height.

    correct character -> bar rises
    wrong character   -> no advance, bar drops, ~0.12s slip stall,
                         and the expected character does NOT change
    no input          -> continuous sag

    bar reaches lockout -> PASS, terminal
    budget expires      -> NO LIFT

Difficulty scales through the AMOUNT of typing rather than its speed: 9 characters
at 80% against 24 at 110%, with sag and mistake cost roughly doubling. The
required rate only moves from 19 to 36 WPM, under what a modest typist manages.
This is deliberately not a typing-speed test.

Pull Strength increases progress per character, reduces sag and reduces the
mistake penalty, so a trained lifter needs FEWER keystrokes rather than faster
ones. It never reduces the threshold, the window or the cue content, so the pull
can never become automatic.

> **Superseded presentations.** This section first described typing "recognizable
> original/parody gym phrases or game-created motivational lines", then a giant
> single character reacted to one key at a time. Both are gone. The phrase version
> tested reading rather than typing; the giant character capped a fluent player at
> the speed they could read one letter. The giant-token idea is kept for a future
> controller vocabulary, where a prompt genuinely is one button at a time.
>
> PC input is captured as text entry rather than key presses, because Roblox's
> built-in controls claim some letters and a keybind competing for them loses.
> See References/TypingGame.md.
See references/TypingGame.md for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 



Difficulty influences:
characters required (9 at 80%, 24 at 110%)
available time
bar sag rate
mistake penalty

It does NOT influence required typing speed beyond the 19-36 WPM band.

Phase 2 — Lockout
At the top:
LOCKOUT SKILL CHECK
Lockout stat controls:
target-zone size
needle speed
reaction window
Failure means:
NO LIFT
See references/DBD.md for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 

12. Training

> **Training is now the PRIMARY source of Competition Number.** Under section 33,
> meets no longer grant CN, so the "Primary progression" column below is no longer
> one progression channel among several — it is the main one. The matrix itself is
> unchanged and still correct: Competition Squat/Bench/Deadlift build the
> corresponding Competition Number, and the variations build technique stats.
>
> What this section still does **not** specify is **how much**. There are no
> training EV rates anywhere in this document. **[TBD]** — see section 33.9.

Training should therefore have a clear matrix.
Exercise
Primary progression
Competition Squat
Forecasted Squat
Pause Squat
Control
Tempo Squat
Depth Awareness
Competition Bench
Forecasted Bench
Paused Bench
Press Power
Slingshot Bench
Start Control
Competition Deadlift
Forecasted Deadlift
Block Deadlifts
Setup practice
Lockout / execution
You gain cosmetic currency through training this.



13. Bodyweight & Weight Classes

> **The gains rule below is SUPERSEDED by section 29.** Competition Number gains
> do NOT accelerate below a target bodyweight and do NOT slow as the player
> approaches it. Under R2, reward magnitude scales with the class Progression
> Reference, so every class progresses at the same PP rate. Muscle determines
> bodyweight and physical size only -- never lift strength.

Your current proposed classes:
59
66
74
83
93
105
120
120+
Bodyweight becomes strategically meaningful.
Higher bodyweight can provide:
Once the weight class threshold gets passed, Forecasted stats ( Forecasted Bench, Squat, Deadlift) Gains increase. Slowly decreases the closer they are to desired Bodyweight. 
Ex: at 53Kgs User’s Gains will be drastically increased to lessen the time needed to get to desired weight class. Lets say 59kg. Forecasted Lifts will increase slower and slower to prevent players from having a ridiculous Record
but moves the player into a stronger weight class.
Therefore gaining weight isn't automatically optimal.

14. World-Record Scaling

> **Refined by section 29.** "Record Percentage" has since split into TWO distinct
> quantities: **Progression Proximity** (CN / Progression Reference), which drives
> difficulty and progression, and **Actual Record Proximity** (CN / real world
> record), which drives prestige and record eligibility. The real record sits
> between PP 81.7% and PP 99.5%, so PP 100% is NOT the world record. Records do
> live in a configuration table, as suggested: `ReferenceRecordConfig.luau`.

This is one of your more interesting concepts.
The game's difficulty can consider:
Player performance
÷
reference performance for weight class
Call it something generic internally such as:
Record Percentage
If the game's reference record is 300 kg and someone attempts:
150 kg = 50%
270 kg = 90%
300 kg = 100%
315 kg = 105%
difficulty rises dramatically as the player approaches record-level performance.
I'd make the records a configuration table, because records and your balancing targets can change.

15. Meet Structure

> **"Progression" in the reward list below no longer includes Competition Number.**
> Under section 33, meets grant Competition Scale, technique, placement, prestige,
> currency and items — never CN. See section 33.3.

Local Meets
Entry-level competition.
Players learn:
attempt selection
commands
judging
totals
weight classes
Rewards:
Currency
Progression
Equipment chance
Titles
Cosmetics
After:
10 local victories
the player unlocks Nationals under your current design.
I would test whether wins or qualifying performance feels better later. Requiring wins can become frustrating if experienced players repeatedly dominate new players.

16. Nationals
Scheduled approximately:
Every hour
Current requirements:
Local progression requirement
Minimum 3 competitors
Potential rewards:
National Champion title
Higher equipment drop chance
Currency
Rare cosmetics
Worlds qualification
I'd reconsider permanently banning National champions from local meets. You could instead create divisions or prevent them from earning local progression rewards, because locking players out of content permanently can hurt replayability.
17. Worlds
Major server event.
Your idea:
5 National Champions present
→ special Worlds event
could be really cool because players would notice something unusual happening in the server.
Give it a major presentation:
Arena lights
↓
Announcements
↓
Walkouts
↓
Competitor introductions
↓
Attempt selection
↓
Squat
↓
Bench
↓
Deadlift
↓
Final standings
Rewards could include:
exclusive singlets
titles
rare equipment
cosmetic bars/plates
aura cosmetics
reduced future entry fees
18. Meet Presentation / Aura
This deserves its own progression category.
Players customize:
Walkout song
Deadlift bar
Plates
Aura
Singlet
Title
Entrance animation
These are excellent monetization/cosmetic opportunities because they don't inherently require selling competitive power.
19. Equipment
Functional equipment:
Knee sleeves
Belt
Wrist wraps
Rare/mythic equipment:
Knee wraps
Squat suit
Bench shirt
Novelty singlets
But Claude should separate:
EQUIPMENT STATS
from:
EQUIPMENT APPEARANCE
That lets you rebalance equipment without rebuilding models.
20. Character Height / Leverages
Neutral zone:
5'5" – 5'9"
No major leverage modifier.
Short builds
Advantages:
Squat leverage ↑
Bench leverage ↑
Early muscle gain ↑
Tradeoffs:
Earlier diminishing returns
Deadlift lockout difficulty ↑
Tall builds
Early disadvantages:
Squat leverage ↓
Bench leverage ↓
Early muscle gain ↓
Later advantages:
Higher long-term size potential
Deadlift lockout advantage
The important goal is:
height changes playstyle rather than creating one objectively superior height.
21. Origin Traits
Lifter Origin / Archetype
For example:
Japanese School
→ bench execution bonus

Nigerian School
→ deadlift execution bonus

French School
→ squat control bonus

American School
→ increased meet/career earnings

22. Coaches
Coaches specialize in disciplines.
For example:
Squat Coach
Bench Coach
Deadlift Coach
Effects might include:
+training efficiency
+specific stat progression
If you're using real lifters' names/likenesses commercially, I'd get permission rather than assuming you can build them into the game.
23. Economy
Your current base:
Local/meet rewards
Jobs
Cooking
Trading
Selling
Equipment
Cosmetics
is enough for an actual economy.
The important part is establishing currency sources and sinks.
Sources
Meet rewards
Retail job
Selling food
Trading
Quests
Sinks
Food
Ingredients
Meet entry fees
Equipment
Cosmetics
Cooking
Rerolls
Upgrades
Without enough sinks, inflation will eventually destroy the player economy.
24. Retail Center
This should be an actual social hub.
Players can:
Work
Cook
Sell
Buy
Trade
Socialize
That means your world isn't just:
GYM → GYM → GYM.
You now have a reason for players to gather.
25. Cooking
I like the idea of scalable meals, Your rough steak system:
1 steak    → +1%
2          → +2%
5          → +5%
10         → +10%
25         → +24%
50         → +45%
100        → +80%
250        → +150%
500        → +250%
The higher the count of steaks are put in, the longer it takes to cook but the steak becomes larger and larger. creates a funny macro/economic system, 
Players Can sit and AFK on this.
26. Trading
Trading should be server-authoritative from day one.
Never let clients decide:
what they own
what another player owns
whether an item transferred
currency transferred
trade completion
Server validates everything.
This matters because valuable rare equipment will make trading an exploit target.

27. World Layout
Now we're at the part related to your Claude question.
I would structure your first map approximately like:
                NATIONAL/WORLDS
                       │
                       │
LOCAL MEET ───── CENTRAL PLAZA ───── RETAIL CENTER
                       │
                       │
                 STARTER GYM
                       │
                 TRAINING AREA
Your Starter Gym contains:
Squat racks
Bench stations
Deadlift platforms
Warm-up area
Locker area
NPC coach area
Comp max testing
Local meet venue:
Competition platform
Judges
Audience seating
Scoreboard
Warmup room
Attempt board
Awards area
Retail center:
Food shop
Cooking stations
Player market
Trading area
Equipment store
Job area
That already gives you three visually distinct environments.

28. Progression Layers

> **Lift progression is now TWO layers, not one.** See section 33.

Your game actually has several progression systems:
LIFT PROGRESSION
Forecasted S/B/D
(trained capability — Competition Number)

PROVEN PROGRESSION
Competition Scale S/B/D
(demonstrated capability — raised only by a successful eligible meet attempt)

TECHNIQUE PROGRESSION
Squat Control / Depth Awareness / Start Control / Press Power / Pull Strength / Lockout

CAREER PROGRESSION
Local → National → Worlds

ECONOMIC PROGRESSION
Money → food → equipment → trading

COLLECTION PROGRESSION
Equipment / cosmetics

SOCIAL PROGRESSION
Titles / rankings / rare items

PLAYER-SKILL PROGRESSION
Actually becoming better at minigames
That combination is what could make the game much deeper than a standard Roblox lifting simulator.

---

## 29. Competition Number Progression — FINAL SPECIFICATION

> **⚠ PARTIALLY SUPERSEDED BY SECTION 33**
>
> **Section 33 revises where Competition Number comes from.** Meets no longer
> grant CN. Training does. Where this section and section 33 disagree about the
> **source** of CN, **section 33 wins**.
>
> What section 33 does **not** touch, and what therefore remains fully
> authoritative in this section:
>
> | Still authoritative | Where |
> |---|---|
> | Terminology (CN, Competition Total) | 29.1 |
> | The three quantities — CN, Progression Reference, Real World Record | 29.2 |
> | The frozen Progression Reference table, FitVersion 1 | **29.2b** |
> | `PP = CN / ProgressionReference` and the Hill soft cap | 29.3 |
> | R2 reference normalization | 29.4 |
> | Weight class and build interactions, RP Preservation | 29.11 |
> | Internal precision and the "never discard fractional progression" rule | 29.12 (plus one new **[TBD]** row for Scale) |
>
> What section 33 supersedes or sends back for recalibration — each marked
> individually below:
>
> | Changed | Where | How |
> |---|---|---|
> | Attempt EV and failure credit | 29.5 | superseded |
> | 65 / 20 / 15 source split | 29.6 | **requires recalibration** |
> | The "Compete" daily pillar | 29.7 | **[TBD]** |
> | The "meets never stop paying" rationale | 29.8 | superseded |
> | The three Competition Budgets | 29.9 | **[TBD]** — subject removed |
> | Solo vs Official CN parity | 29.10 | superseded; replaced by Scale eligibility |
> | Pacing target (P4) | 29.13 | **requires recalibration** |
> | Archetype rates | 29.14 | **requires recalibration** |
> | Failure credit as a tunable | 29.15 | obsolete |
>
> The arithmetic in this section was never wrong. Only its **inputs** changed.

This section supersedes any earlier statement in this document about how
Forecasted / Competition Numbers grow. Where sections 3, 12, 13 or 14 disagree
with this section, **this section wins** — except where section 33 overrides it,
as tabulated above.

Rules in this document carry one of four status markers:

- **[FROZEN]** — architecture. Changing it changes the design.
- **[TUNABLE]** — a balance constant. Expected to move after playtesting.
- **[TBD]** — not yet decided. Must be approved before implementation.
- **[OBSOLETE]** — superseded. Retained for audit only; **never implement it**.
  Obsolete text is struck through or labelled in place, never silently deleted.

### 29.1 Terminology

| Player-facing term | Meaning |
|---|---|
| **Competition Number (CN)** | What the character can lift under competition conditions, in kg |
| **Competition Total** | Squat CN + Bench CN + Deadlift CN |

**[FROZEN] Player-facing terminology is "Competition Number", never "Forecasted".**

> **Migration note.** The profile schema and existing code still use
> `Forecasted` (`PlayerProfileSchema.ProfileData.forecasted`,
> `StartingValuesConfig.Forecasted`, `DifficultyResolver`'s `forecastedMax`).
> This naming is **flagged for a safe rename during implementation** and must
> not be renamed piecemeal — it is load-bearing for the difficulty engine and
> would need a schema migration. Until then, `Forecasted` in code means
> Competition Number.

### 29.2 The three quantities — do not confuse them

| Quantity | Definition | Used for |
|---|---|---|
| **Competition Number (CN)** | the character's capability, in kg | attempt selection, display |
| **Progression Reference** | the frozen M2 allometric reference, §29.2b | the denominator of PP |
| **Real World Record** | the actual record from `ReferenceRecordConfig` | prestige, record eligibility |

```
Progression Proximity   PP  = CN / ProgressionReference(lift, class)
Actual Record Proximity ARP = CN / RealWorldRecord(lift, class)
```

**[FROZEN]** PP drives difficulty and progression. ARP drives prestige and
record eligibility. **PP 100% is NOT the world record** — the real record sits
between PP 81.7% and PP 99.5% depending on class and lift.


### 29.2b The frozen Progression Reference table — FitVersion 1

**[FROZEN]** Lives in `src/shared/Config/ProgressionReferenceConfig.luau`.

**This is a progression-normalization table. It is NOT a world record table.**
`ReferenceRecordConfig` holds the real records and drives prestige; this holds
progression references and drives pacing. They are different quantities with
different jobs.

| Class | Squat | Bench | Deadlift |
|---|---|---|---|
| 59 kg | 294.2668 | 202.0288 | 334.4681 |
| 66 kg | 317.3189 | 214.5675 | 350.2647 |
| 74 kg | 342.7050 | 228.1653 | 367.1538 |
| 83 kg | 370.2130 | 242.6723 | 384.9150 |
| 93 kg | 399.6555 | 257.9609 | 403.3666 |
| 105 kg | 433.6515 | 275.3345 | 424.0275 |
| 120 kg | 474.4075 | 295.8054 | 447.9851 |

> **Displayed to four decimals for readability.** The config stores the full
> derived double precision, deliberately unrounded, because PP feeds a
> fifth-power curve and rounding would move it in the fourth significant digit.
> `295.8054` is the 120 kg Bench **Progression Reference**; do not confuse it
> with `291.5`, which is the 120+ kg Bench **real world record** and belongs
> only in `ReferenceRecordConfig`.

#### Provenance

```
reference = Coefficient x bodyweight ^ Exponent

            Exponent                Coefficient           RawCoefficient
Squat       0.67269077281080014     18.945475535859227    18.8512194386659
Bench       0.53706504721053849     22.612599532213689    22.500099037028548
Deadlift    0.41160160566320991     62.440908240461866    62.130256955683457

HeadroomMultiplier = 1.005
```

Fitted from the real records in `ReferenceRecordConfig`, capped classes only,
using the **class upper bounds** 59 / 66 / 74 / 83 / 93 / 105 / 120 as the
bodyweight x-values. The exponent is a least-squares fit on `log(WR)` against
`log(bodyweight)` per lift; `RawCoefficient = max(WR / bodyweight^Exponent)` so
the curve sits at or above every real record; `Coefficient = RawCoefficient x
HeadroomMultiplier`.

The headroom exists so no real record sits at exactly PP 100%. Because `k` is
fitted to the maximum, exactly one class per lift is pinned near the reference —
**74 kg Squat, 66 kg Bench and 83 kg Deadlift all land at PP 99.5%** — and their
records are therefore the hardest to reach. Accepted and frozen; see §29.13.

#### Changing these values

**[FROZEN] A change to a real world record does NOT change this table.** If
these were derived live from `ReferenceRecordConfig`, then a record being broken
in the real world would silently move every existing player's PP, shift their
Hill soft-cap position and re-pace their character retroactively. That must not
happen.

So:

- Production runtime treats the frozen literals as **authoritative**.
- Load-time validation checks **structure only**: all 21 values present, finite,
  above zero, and strictly ascending with class per lift.
- Load-time validation deliberately does **not** re-derive from
  `ReferenceRecordConfig` and compare, because real records may legitimately be
  updated and that must never fail startup or alter progression.
- A **dev-only** provenance check (`deriveFromProvenance`, exercised by
  `CompetitionNumberRewardProbe`) confirms the literals still match the recorded
  fit. It compares against the stored coefficients, not live records.
- **Changing the table at all is an explicit progression-version decision**:
  bump `FIT_VERSION`, and understand that every existing player's pacing moves.

#### 120+ kg is deliberately absent

The unlimited class has no upper bodyweight bound, so the allometric fit has no
x-value to evaluate at — the formula is **undefined** there, not merely
unspecified. Its progression basis must be unbounded while becoming
increasingly difficult, which is a different system, and no finalized rule for
it exists in this document.

Three things it must **not** be:

- an extrapolation of this fit
- the 120+ real world record used as a progression reference
- the C3 capped-class export formula, which is a **translation** rule between
  classes and not a **growth** rule within one

The reward engine returns an explicit `UnsupportedClass` result for 120+ and
must never fall back to the 120 kg reference.
### 29.3 The core formula

```
Hill(PP) = 1 / (1 + (PP / 0.75)^5)

dCN = ProgressionReference x BaseProgressRate x EV x Hill(PP) x BudgetMultiplier
```

| Constant | Value | Status |
|---|---|---|
| `h` (Hill midpoint) | 0.75 | **[TUNABLE]** — recalibrate from telemetry |
| `m` (Hill exponent) | 5 | **[TUNABLE]** |
| `BaseProgressRate` | **0.00482389** | **[TUNABLE]** — single config constant |

**[FROZEN]** The soft cap is asymptotic. There is **no hard strength cap** at any
PP. Progression slows without limit and never reaches zero.

`BaseProgressRate` means: one unit-quality attempt grants **0.4824% of that
lift's Progression Reference**, before the soft cap.

### 29.4 R2 — reference normalization

**[FROZEN]** Reward magnitude scales with the destination build's Progression
Reference, **per lift**:

```
BaseRawReward = ProgressionReference(lift, class) x BaseProgressRate
```

Normalization is **per lift**, using that lift and class's own reference. There
is no combined SBD progression value.

Consequences, all verified:

- Every class and lift reaches a given PP milestone in **the same calendar time**
  (spread 1.03x-1.25x, caused only by differing starting PP).
- Weight class is about identity, records, body size, competition and headroom —
  **not progression speed**.
- Heavier lifts move in larger kilogram increments, which matches real lifting.
- Class switching is **exactly progression-neutral**: the reference ratio that
  inflates the reward is the same ratio that deflates it under RP Preservation,
  so the round trip multiplier is exactly 1.0000.

**The Hill input is never normalized.** It remains `PP = CN / ProgressionReference`.

### 29.5 EV — what each event is worth

> **⚠ SUPERSEDED IN PART BY SECTION 33.** Meet attempts no longer grant CN
> (§33.3) and the failure credit is zero (§33.6). The obsolete rows are **kept,
> not deleted**, because the meet EV figures are the historical basis of §29.9's
> capacity and of the §29.13 / §29.14 calculations, which must stay auditable
> while they are recalibrated. The daily and AFK rows survive; only their
> **shares** change (§29.6). Each row's status is marked individually.

**[FROZEN]** EV is reference-independent. Kilograms follow from §29.3.

| Event | EV | Status |
|---|---|---|
| Successful attempt | = intensity factor | **[OBSOLETE as a MEET reward]** — no longer a CN source. Retained as the EV *shape* a training event may reuse |
| Failed attempt | = intensity factor x **0.20** | **[OBSOLETE]** — superseded by section 33.6. Zero EV, zero CN, no Scale increase |
| Full 9-attempt meet (Normal strategy) | ~5.658 (~1.886 per lift) | **[OBSOLETE as a CN figure]** — historical reference only |
| **Compete Daily** | **0.3948 to EACH active S/B/D lift** | **[TUNABLE]** — still a CN source; **share requires recalibration**, and whether "Compete" means a meet is **[TBD]** (§29.7) |
| **Daily Set completion** | **0.1974 to EACH active S/B/D lift** | **[TUNABLE]** — still a CN source; **share requires recalibration** |
| AFK training | **0.2591 per hour** | **[TUNABLE]** — still a CN source; **share requires recalibration** |
| **Training session** | **[TBD]** | **the new primary CN source** — no rate exists in this document yet. See §33.9 |

> **Daily wording is deliberately explicit.** Both daily rewards are **per lift**,
> not a total to be divided. A completed Daily Set awards 0.1974 EV to Squat,
> 0.1974 EV to Bench and 0.1974 EV to Deadlift — 0.5922 EV in total. The
> alternative reading (0.1974 total, 0.0658 each) yields only a 15.6% daily share
> and misses the 20% target. *(The per-lift rule stands; the 20% target itself is
> obsolete — §29.6.)*

#### Intensity factors (I-A) — **[TUNABLE]**

| Relative intensity | Factor |
|---|---|
| <= 60% | **0.00** |
| 75% | 0.35 |
| 85% | 0.70 |
| 90% | 0.90 |
| 95-100% | 1.00 |
| 105% | 1.10 |
| 110%+ | 1.20 (capped) |

~~**[FROZEN] Aggressive lifting does not need to be CN-optimal.**~~ **[OBSOLETE
FOR MEETS]** Safe and normal attempts give better reliable CN; aggressive attempts
exist for PR, record, victory and prestige upside. Verified: Conservative beats
Aggressive by 21% in CN, and this is intended.

> **⚠ The 21% figure measured meet-derived CN, so it is obsolete — and the
> incentive it balanced has INVERTED.** Meet strategy is now scored against
> **Competition Scale**, a maximum raised only by success, while failure costs
> **zero** (§33.6). Both sides of the old expected-value trade are gone, and the
> optimal meet strategy becomes "attempt the heaviest weight with any chance of
> succeeding". Whether the existing brakes suffice is **[TBD]** (§33.11).
>
> This affects **meet** strategy only. The original reasoning may still hold for
> training, scored against trained CN rather than Scale.

**[FROZEN]** Nothing at or below 60% relative intensity awards CN.

> Still true, and now trivially so for meets. Whether a 60% floor should also
> apply to **training** EV is **[TBD]** (§33.9).

### 29.6 Source distribution target — **[OBSOLETE, REQUIRES RECALIBRATION]**

> **⚠ DO NOT BALANCE AGAINST THIS TABLE.**
>
> **The 65 / 20 / 15 split is obsolete.** It is retained as the historical record
> of what `BaseProgressRate` was solved against, and because §29.13 and §29.14
> are derived from it and must be re-derived with it.
>
> Meets contributed the **65%** row and now contribute nothing. By the table's own
> figures the two surviving channels sum to 5.078 of 14.508 EV/week per lift —
> **about 35% of what the constant was calibrated for**. That shows the size of
> the hole; it is **not** a new target.
>
> A replacement distribution **[TBD]** must be approved before any CN value is
> re-tuned, and must answer:
>
> - What share does **training** take as the new primary channel? (§33.9)
> - Do the daily and AFK absolute EV values stay, with only shares moving?
> - Is `BaseProgressRate` re-solved, or do the training rates absorb the gap?
> - Does §29.13's pacing target still stand as the anchor, or does it move too?

**[OBSOLETE PLAYER MODEL — "meets/week" is no longer a CN variable]** For the
**reference engaged player** (~5 days/week, ~5 meets/week, ~70% daily completion,
~60% Training Energy use):

| Source | Share | EV/week per lift |
|---|---|---|
| Meets | **0%** — channel removed; was 65% | — *(was 9.430)* |
| Dailies | **[OBSOLETE SHARE]** — channel survives; was 20% | 2.902 |
| AFK | **[OBSOLETE SHARE]** — channel survives; was 15% | 2.176 |
| Training | **[TBD]** — new primary channel | **[TBD]** |

~~**[FROZEN] hierarchy: MEETS > DAILIES > AFK.**~~ **[OBSOLETE]** — meets are no
longer a CN channel, so the hierarchy is void. The percentages were always a
balancing target, not a guarantee for any individual player.

### 29.7 Daily architecture

> **⚠ The "Compete" pillar needs a decision — [TBD].** If completing it requires
> **entering a meet**, then it awards CN for a meet, which section 33.3 forbids.
> If it means training, it is misnamed. Three ways out, none chosen:
>
> - **Compete stops awarding CN** and awards placement/prestige/economy instead,
>   with its CN moved to the Develop pillar.
> - **Compete is renamed** to reflect that it is a training objective.
> - **Compete keeps CN as a daily-completion reward**, on the grounds that the CN
>   is paid for *completing the daily*, not for the attempts inside the meet.
>
> The third reading is the narrowest and preserves the most existing design, but
> it is the one most likely to be read later as a loophole in section 33.3, so it
> needs to be stated explicitly if it is chosen. See section 33.11.
>
> The **Daily Set completion** bonus is unaffected either way: it is a consistency
> reward for engaging all three pillars, not a competition reward.

**[FROZEN]** Three daily pillars, three different reward types:

| Daily | Awards |
|---|---|
| **Compete** | CN progression — **[TBD]**, see the notice above |
| **Develop** | Technique / Muscle |
| **World** | economy (money, items) |
| **Daily Set completion** | additional CN consistency bonus |

**[FROZEN] Cooking and trading never grant Squat/Bench/Deadlift CN directly.**
The Set bonus is a *consistency* reward for engaging all three pillars, not
economy activity converting into strength.

**[FROZEN] Daily Set distribution:** awarded to all three lifts of the **currently
active build**, **one claim per account per day**. Build slots cannot duplicate it;
switching build before claiming only chooses the destination, and because R2 makes
the gain PP-equivalent regardless of class, that choice is cosmetic.

### 29.8 AFK progression and Training Energy

**[FROZEN]** Training Energy limits **passive AFK CN only**.

**[FROZEN] Training Energy never limits Muscle.** Muscle progresses
independently and continues when Training Energy is empty.

| Parameter | Baseline | Status |
|---|---|---|
| Maximum capacity | **120 minutes** | **[TUNABLE]** |
| Regeneration | **5 min/hour** (full in 24 h) | **[TUNABLE]** |
| Regenerates online and offline | yes | **[FROZEN]** |
| Consumption | 1 minute capacity = 1 minute AFK CN training | **[FROZEN]** |
| At zero | **AFK CN stops** | **[FROZEN]** |

Available per week: 840 minutes (14 hours). The reference player uses ~60%.

**[OBSOLETE RATIONALE]** **Why AFK stops but meets never do:** meets are active
play, and a player at the keyboard must never be told their effort is worth
nothing. AFK is passive, and a hard allowance is what holds the intended ratio.
Target: 100% Training Energy utilization ~= **0.25x** the reference active total
rate, so AFK-only progression is ~4x slower.

> **⚠ The paragraph above is obsolete and its 0.25x target requires
> recalibration.** The comparison was AFK against **meets**, which no longer award
> CN. The principle survives and points elsewhere: the active channel that must
> never be throttled to nothing is now **training**.
>
> - **0.25x** was defined against a "reference active total rate" that was 65%
>   meets. That denominator is gone, so the figure must be re-derived with §29.6.
> - Whether **training** should be limited by Training Energy at all is now a live
>   question. Training was a minor channel when this was written and is the
>   primary one now, so capping it at 120 minutes a day is a far larger decision
>   than capping a background trickle. **[TBD]** — §33.10.
>
> The Training Energy parameters in the table above are **not** superseded. Only
> the ratio they were calibrated to produce is.

**Player-facing explanation:**

> **Training Energy** — your gym stamina for background training. 2 hours
> maximum, fully recovered every day, and it refills whether you are online or
> not. *Background training only.*

### 29.9 The three Competition Budgets

> **⚠ THIS SYSTEM HAS LOST ITS SUBJECT — [TBD]**
>
> Every rule here exists to **throttle meet-derived CN**, so as written these
> pools now throttle nothing. Nothing below is *wrong*, but it is the largest open
> question section 33 creates: the pools are **already persisted** (schema v3) and
> already have a specified presentation, so leaving them attached to nothing is
> the one outcome to avoid.
>
> Three options, none chosen:
>
> | Option | What it means |
> |---|---|
> | **Rehome to training** | Throttle the new primary CN channel. Needs a rename, a recalibrated capacity (9.43 EV is currently defined as "five meets"), and a ruling on overlap with Training Energy, which would become a second throttle on one channel. |
> | **Repoint at Competition Scale** | Throttle how fast Scale rises. **The consumption rule does not survive this**: "proportional to the CN actually awarded" has no quantity to track, because a Scale increase is a kilogram jump, not an EV amount. A new basis would have to be designed. |
> | **Retire** | Accept an unthrottled training channel and deprecate the three pools in a later schema version. |
>
> **Everything below is retained unchanged**, because the harmonic overflow model,
> path independence and the per-lift-pool reasoning are proven and worth reusing
> wherever the pools land. The anti-specialization argument below was about *meet*
> farming; whether a squat-only **trainer** needs the same correction has not been
> examined. See §33.10.

**[FROZEN]** There are **three separate pools**: Squat, Bench and Deadlift.

Each pool is **account-wide for that lift** and shared across:

- all weight-class build slots (59 kg Squat and 120 kg Squat draw the same pool)
- Solo Meets and Official Meets

Each pool is **NOT** per weight class, **NOT** per build slot, and **NOT** shared
between the three lifts.

| Parameter | Baseline | Status |
|---|---|---|
| Capacity (each pool) | **9.43 EV** (= 5 meets) | **[TUNABLE]** |
| Regeneration | **0.0561 EV/hour** (9.43/week) | **[TUNABLE]** |
| `k` (overflow softness) | **3** | **[TUNABLE]** |

**[FROZEN]** Full-rate allowance, then **harmonic diminishing overflow**:

```
BudgetMultiplier = 1 / (1 + overflowMeets / k)     where overflowMeets = overflow / 1.886
```

| Meet # in a week | Multiplier |
|---|---|
| 1-5 | 1.000 |
| 6 | 0.750 |
| 7 | 0.600 |
| 8 | 0.500 |
| 10 | 0.375 |

**[FROZEN] Active meet progression is never hard-zeroed.** The 30th meet of a week
still pays 10.7%. 1000 meets/week would yield ~3.2x the reference rate, not 200x.

**[FROZEN] Budget consumption is proportional to the CN actually awarded**, not to
meets or attempts counted. Consequences, all verified:

- Bombing a meet consumes almost nothing — **no double punishment**.
- EV per unit of budget is **identical** whether an attempt succeeds or fails, so
  there is **no reason to fail on purpose**. Failing only wastes wall-clock time.
- Leaving halfway or disconnecting consumes exactly what was earned; no refund is
  needed and none is given.
- Repeated sub-60% openers award nothing and therefore consume nothing.

> **⚠ All four consequences above are MEET-SPECIFIC and therefore obsolete as
> stated.** They are retained because the *property* that produced them — that
> consumption tracks the reward and nothing else — is the reason the model has no
> exploitable ratio, and that property should be carried into wherever the pools
> are rehomed.
>
> Two of them die outright rather than relocating:
>
> - **"No reason to fail on purpose"** was proved from the failure credit being a
>   constant fraction of the success. With the credit removed (§33.6), a failure
>   earns zero and consumes zero. The conclusion still holds, but trivially and
>   for a different reason.
> - **"Bombing consumes almost nothing"** no longer protects anything, because
>   bombing a meet now has no CN consequence to be protected from.

**Why three pools and not one:** with a single shared pool, a squat-only player
earns 3x the squat progression of a full powerlifter per unit of budget. Per-lift
pools invert that: a squat-only player doing **six times** the meets reaches 1.82x
squat while their bench and deadlift sit at 0.35x. Specializing becomes a trade,
and a bad one.

**Player-facing presentation — [FROZEN]:** per-lift freshness state, **not three
resource bars**.

| State | Budget remaining | Meaning |
|---|---|---|
| **FRESH** | > 60% | full progression |
| **WORKED** | 20-60% | still good |
| **FATIGUED** | < 20% | reduced progression from here |

> **Fatigued** — you have competed this lift a lot recently. It still progresses,
> just more slowly. Recovers over the next day or two.

### 29.10 Solo vs Official meets

**[FROZEN]** Basic strength progression is **never population-gated**.

> **⚠ The CN row is superseded; the FROZEN principle above SURVIVES, applied to a
> different quantity.** Under section 33 the quantity that governs meet challenge
> is **Competition Scale**, and Scale is **raisable in Solo meets** (§33.7), so
> basic strength progression stays un-population-gated for exactly the reason
> given below the table. Solo still cannot establish an official World Record;
> section 31 is unchanged and remains authoritative on records.

| | Solo / Qualifying | Official multiplayer |
|---|---|---|
| Full 9-attempt S/B/D format | yes | yes |
| Attempt selection and 2.5 kg rules | yes | yes |
| **Build CN progression** — **[OBSOLETE]**, was "full rate / full rate" | **none** | **none** |
| **Competition Scale raise** (§33.7) | **yes** | **yes** |
| Technique progression | yes | yes |
| Personal records | yes | yes |
| Bomb-out consequences | yes | yes |
| Competition Budget consumed | **[TBD]** (§29.9) | **[TBD]** (§29.9) |
| **Official victories** | no | yes |
| **Placing** | no | yes |
| **Leaderboard / record eligibility** (§31, via Worlds only) | no | yes |
| **Prestige / career history** | no | yes |
| **Nationals qualification** | no | yes |

~~Solo grants **full** CN rather than a reduced rate deliberately:~~ **[OBSOLETE
as a CN rule — but this is the argument that now justifies Solo raising Scale]** a
reduced rate would make waiting for players optimal and would punish
low-population servers. Multiplayer is desirable because everything prestigious is
multiplayer-only, not because progression requires it.

**[FROZEN]** Account-wide rewards (currency, items) must **never** reuse the
build-CN relative-intensity formula, because a fresh low-CN build reaches 100%
relative intensity and ~100% Hill efficiency at trivial absolute weight. The
actual currency/item formula belongs to economy design and is **not specified
here**; raw absolute kilograms is explicitly **not** frozen, since it would create
a heavier-class economic advantage.

### 29.11 Weight class and build interactions

**[FROZEN]**

- Progression is **build-scoped**. Each weight-class build has its own CN.
- Saved lighter builds **restore exactly**.
- First-time downward translations follow the frozen transition architecture
  (RP Preservation: `CN_new = CN_old x ref_new / ref_old`).
- Meet entry takes a **weigh-in snapshot** (`weighInKg`, `meetClass`, `meetBuild`)
  frozen until the meet resolves.
- Bodyweight above 120 kg is **cosmetic**; it confers no additional progression.
- Muscle determines **bodyweight and physical size only** — never lift strength.

### 29.12 Display precision — four separate concepts

> **Competition Scale is the fourth concept**, added by section 33. Its precision
> is **[TBD]**: Scale is not a derived decimal like CN but a copy of a weight
> actually loaded on a bar, so it is already a legal 2.5 kg value and may need no
> rounding rule at all — which is a decision to confirm, not an assumption. See
> section 33.8. Nothing else in this subsection is affected.

**[FROZEN]** These must not be conflated:

| Concept | Precision |
|---|---|
| **Internal CN** | full decimal precision |
| **Main player-facing CN** | **nearest 0.5 kg** |
| **Legal meet attempts** | **2.5 kg increments** |
| **Competition Scale** | **[TBD]** — see the notice above |

**[FROZEN] Fractional progression is never discarded** merely because it is not
currently visible. Small passive and daily gains accumulate internally.

**[FROZEN]** Do not show repeated `+0.0 kg`. Aggregate small gains into meaningful
feedback:

```
Background Training: +0.5 kg
Today's Squat Progress: +1.0 kg
```

For scale, one AFK hour at PP 100% on a 59 kg bench is ~0.048 kg — individually
invisible at any sane display precision, but ~0.7 kg across a week of full
utilization.

### 29.13 Pacing target (P4)

> **⚠ REQUIRES RECALIBRATION**
>
> **Every time below was computed with meets supplying 65% of EV** (§29.6), so all
> of them are now too fast by the same factor and must be re-derived once the
> replacement distribution is approved. Keep two things separate:
>
> - **The TARGET may well stand** — "PP 60% in roughly 8 weeks" describes how the
>   game should *feel*, and section 33 does not argue against it. Whether it stays
>   the **[FROZEN]** anchor is a decision (§29.6).
> - **The TABLE does not stand** — it is output, produced *by* `BaseProgressRate`
>   against the old channel mix, so it moves automatically when either is re-solved.
>
> The **1.76x class spread** is a *reference-table* property, not a channel
> property: the spread is unaffected and only the absolute months move.

**[FROZEN — target only; see the notice above for the table]** The reference
engaged player reaches **PP 60% in approximately 8 weeks**. This is the baseline
against which `BaseProgressRate` is solved.

| PP | Time | | PP | Time |
|---|---|---|---|---|
| 20% | 1.8 wk | | 90% | 3.9 mo |
| 40% | 4.7 wk | | 95% | 4.6 mo |
| **60%** | **8.0 wk** | | 100% | 5.4 mo |
| 75% | 2.6 mo | | 110% | 7.5 mo |
| 85% | 3.4 mo | | 125% | 12.7 mo |
| | | | 150% | **2.58 yr** |

**Record-level CN** (reaching the number, not successfully lifting it) arrives at
**3.2 to 5.6 months** depending on class and lift — a 1.76x spread. The three
hardest are **66 kg Bench, 74 kg Squat and 83 kg Deadlift**, whose records sit at
PP 99.5% because they bound the M2 `k`-fit. This variation is **accepted and
frozen**; no per-class Hill correction coefficient is applied.

Reaching record-level CN is **not** the same as setting the record. Execution still
decides whether the lift is made.

### 29.14 Archetype rates — verified

> **⚠ REQUIRES RECALIBRATION — THE INDEPENDENT VARIABLE IS GONE**
>
> **Every row below is keyed on meets per week**, and meets no longer produce CN.
> This table needs **re-authoring against training volume**, not re-tuning, once
> §29.6 and §33.9 are settled. Three things to carry into the replacement:
>
> - **"Meet spammer"** loses its meaning. Whether a "training spammer" needs the
>   same logarithmic brake depends on §29.9, and the answer is not obviously yes —
>   training is bounded by real time in a way that queueing meets is not.
> - **"Squat-only specialist"** justified the three separate budget pools. Whether
>   the same pressure exists for a trainer has not been examined (§29.9).
> - **"Only the meet channel is unbounded"** is now false. Which channel, if any,
>   is unbounded is **[TBD]**.
>
> The **spread** is the part worth preserving: the intent was that the most
> dedicated player lands near 1.5x the reference and not 10x. That is unaffected.

Per-lift progression rate relative to the reference player:

| Archetype | Meets/wk — **[OBSOLETE KEY]** | Rate |
|---|---|---|
| Casual | 2 | 0.45x |
| **Reference** | **5** | **1.00x** |
| Hardcore | 10 | 1.48x |
| AFK-heavy | 1 | 0.52x |
| Meet spammer | 30 | 1.47x |
| Squat-only specialist | 15 | 1.53x squat / **0.35x** bench+deadlift |
| Dailies-only | 0 | 0.29x |

~~Channel ceilings: dailies cap at **0.29x**, AFK caps at **0.25x**. Only the meet
channel is unbounded, and it is logarithmic.~~ **[OBSOLETE]** — the dailies and
AFK ceilings were expressed relative to a reference rate that included meets, so
both figures move even though neither channel changed.

### 29.15 Constants expected to be recalibrated after playtesting

| Constant | Why |
|---|---|
| **`BaseProgressRate`** | solved from an **assumed** success-probability curve; the single largest uncertainty in the model. **Now also requires re-solving against the post-section-33 channel mix** (§29.6) |
| ~~Failure credit (0.20)~~ | **[OBSOLETE]** — superseded by section 33.6. A failed attempt is worth zero. The original note, retained for the record: sensitivity testing showed 0.30 inverts optimal play toward reckless spam; keep <= 0.20. **The code constant `ProgressionConfig.FailureCredit` is deliberately NOT removed yet** — see section 33.12 |
| I-A intensity factors | depend on real pass rates. Still needed wherever relative-intensity EV is used; **which system that is, is now [TBD]** (§33.9) |
| `h` = 0.75, `m` = 5 | `m` = 6 is the lever for a harsher elite grind; affects only players past PP 110%. **Unaffected by section 33** — the Hill curve still reads `PP = CN / ProgressionReference` |
| Competition Budget capacity, regen, `k` | ~~depends on observed meets/week~~ — **[TBD]** whether this system survives at all (§29.9) |
| Training Energy max and regen | depends on observed AFK behaviour. **Scope now [TBD]**: it may need to govern active training rather than only passive AFK (§29.8) |
| Daily EV values | depends on observed completion rates |
| ~~65/20/15 source split~~ | **[OBSOLETE]** — a target, not a guarantee, and now a target for a channel mix that no longer exists. **Requires recalibration** (§29.6) |
| **Scale Challenge Ratio curve and cap** | **[TBD]** — new in section 33.4. No values exist |
| **Training EV rates** | **[TBD]** — new in section 33.9. No values exist |
| **Starting Competition Scale** | **[TBD]** — new in section 33.8 |

**[FROZEN] `BaseProgressRate` must remain a single configurable constant.** Real
playtest success rates will require recalibration, and it enters the formula as one
multiplier so rescaling is a one-line change.

## 30. Competition Rewards

> **Scope.** The preamble below was written for §30, §31 and §32 together, which
> were designed as one approved system. Only numbering and heading depth were
> normalized to match this document's conventions — **no rule was changed,
> reinterpreted or removed**.

This section defines the intended competition reward hierarchy, World Record lifecycle,
Worlds qualification system, and monthly Sheffield-style championship.

These are GAME DESIGN RULES.

Do NOT implement these systems merely because they are documented here.
Exact economy values, equipment probabilities, meet schedules, and some edge cases
remain TBD and must be approved before implementation.


### 30.1 Competition Reward Philosophy

> **⚠ Category 1 is superseded by section 33.** Competitions award **Competition
> Scale**, never Competition Number. Only category 1 changed; categories 2 to 5
> are unchanged and approved, and this subsection's core principle — that these
> rewards must not all share one calculation — is untouched.

Competitions provide multiple distinct reward categories:

1. **Competition Scale progression** (§33.7) — **[was "Competition Number
   progression"]**
2. Money
3. Equipment / item reward opportunities
4. Placement / prestige
5. World Record progression where eligible

These rewards must NOT all use the same calculation.

~~Competition Number represents the strength the player demonstrated.~~
**[SUPERSEDED]** — that is now the definition of **Competition Scale**. Under
section 33: **Competition Number** is the strength the player **trained**;
**Competition Scale** is the strength the player **demonstrated**.

Money and equipment should reward competitive success, placement, meet size,
and overall meet performance.

World Records and Sheffield qualification are separate prestige/endgame systems.


---

### 30.2 Competition Number Rewards — ⚠ SUPERSEDED BY SECTION 33

> **⚠ THIS ENTIRE SUBSECTION IS OBSOLETE AS A CN RULE**
>
> **Meets do not award Competition Number.** Section 33.3 is authoritative. Every
> statement below that attaches CN to a meet attempt is superseded.
>
> It is **retained rather than deleted** because it is the clearest written record
> of the previous model, and because three of its rules survive the change intact
> and are called out in place below:
>
> | Rule | Fate |
> |---|---|
> | All 9 attempts contribute individually toward **CN** | **superseded** — they contribute toward **Competition Scale** instead, and only the heaviest success counts |
> | Successful attempts receive full intensity-based EV | **superseded as a meet rule** |
> | `FailureCredit = 0.20` | **superseded** — zero (§33.6) |
> | 3/3 yields more progression than 1/3 | **superseded** — Scale is a maximum, so 3/3 and 1/3 at the same heaviest weight are worth exactly the same |
> | No flat CN bonus for going 3/3 | **survives** — and now trivially, since there is no CN at all |
> | Placement does not multiply progression | **survives, and extends to Scale** |
> | Player count does not multiply progression | **survives, and extends to Scale** |
>
> The old model rewarded **consistency across attempts**; the new model rewards
> **the single best attempt**. That is the source of the open strategy question in
> §33.11.

~~All three attempts on Squat, Bench, and Deadlift contribute individually toward
Competition Number progression.~~ **[SUPERSEDED]**

~~A full meet therefore contains up to 9 progression-producing attempts:~~
**[SUPERSEDED]** — a meet contains up to 9 **Scale-eligible** attempts, of which
only the heaviest success per lift has any effect (§33.7).

- Squat Attempt 1
- Squat Attempt 2
- Squat Attempt 3
- Bench Attempt 1
- Bench Attempt 2
- Bench Attempt 3
- Deadlift Attempt 1
- Deadlift Attempt 2
- Deadlift Attempt 3

~~Successful attempts receive their full intensity-based EV.~~ **[SUPERSEDED]**

~~Failed attempts receive the currently frozen failure credit:~~

~~FailureCredit = 0.20~~

> **[OBSOLETE — zero, per §33.6.]** The code constant
> `ProgressionConfig.FailureCredit = 0.20` is deliberately still present and is
> scheduled for removal in a later increment (§33.12).

~~Therefore, a player who successfully completes 3/3 attempts on a lift will generally
receive more progression than a player who completes only 1/3 at comparable intensities.~~
**[SUPERSEDED]** — see the fate table above.

However, attempt difficulty still matters.

**A player must not receive a flat CN bonus simply for going 3/3.** *(Survives.)*

~~Higher-intensity successful attempts should naturally produce greater progression through
the existing EV system.~~ **[SUPERSEDED as a meet rule]** — no meet attempt
produces CN at any intensity.

~~Competition Number progression remains governed by:~~ **[SUPERSEDED — this is
the governing list for TRAINING-driven CN, not for meets]**

- Attempt intensity
- Success/failure
- Raw EV
- Competition Budget
- Progression Percentage
- Hill soft-cap
- CompetitionNumberReward

> **The pipeline above is still correct; only its trigger moved** — see §33.9.
> The two entries that do not carry over cleanly are **Success/failure** (an
> undefined concept for training) and **Competition Budget** (**[TBD]**, §29.9).

**Placement does NOT directly multiply Competition Number progression.**

**Player count does NOT directly multiply Competition Number progression.**

This prevents players from gaining additional permanent strength merely because they
entered a weak field or a large field.

> **Both rules SURVIVE and extend to Competition Scale**: Scale is set by the
> weight on the bar and nothing else, so a weak or large field changes a player's
> money and prestige but never their proven strength (§33.7).


---

### 30.3 Money / Prize Pot

Competition money rewards should use a meet-level Prize Pot.

The Prize Pot increases based on the number of legitimate participating players.

Conceptually:

Prize Pot =
Base Meet Pot
+ Player Count Contribution

Higher-tier meets may have larger base pots and/or stronger player-count scaling.

Exact values are TBD.

Placement determines how the Prize Pot is distributed.

Higher placement receives a larger share.

First place should receive the largest reward.

Money may also include smaller performance-based bonuses.

Examples may include:

- 9/9 performance
- exceptional total
- record performance
- other approved meet accomplishments

However, placement should remain a major component of competition money rewards.


#### Qualified Player Count

Not every player who joins a server should increase the Prize Pot.

Only legitimate meet participants should count.

A player must satisfy server-authoritative participation requirements before they
contribute toward the Prize Pot.

This exists to prevent alternate-account / fake-player Prize Pot inflation.

Exact qualification requirements are TBD.


---

### 30.4 Equipment / Item Rewards

Competitions may provide opportunities to receive lift-improvement equipment.

Examples include:

- Knee Sleeves
- Wrist Wraps
- Belt

Equipment should NOT roll independently after every successful attempt.

Instead, equipment rewards should primarily occur at the end of the competition.

Equipment reward chance and/or reward quality may scale from:

- Placement
- Overall meet performance
- Successful attempts
- Meet tier
- Other approved competitive accomplishments

Exact item pools, rarity tiers, probabilities, and equipment effects are TBD.

Going 9/9 should generally be more rewarding than performing poorly, but players should
not be encouraged to intentionally choose trivial attempts merely to farm item rolls.

Placement should meaningfully improve competition rewards.


---

## 31. World Record System


### 31.1 Worlds is the only World Record gateway

A player may ONLY establish or increase a Pending / Unofficial World Record through a
valid performance at a designated Worlds meet.

Performances from:

- Local meets
- Qualifying meets
- Training
- Normal competitions
- Debug systems
- Other non-Worlds activities

must NEVER update the Pending World Record leaderboard.

Even if a player lifts more than the current World Record outside Worlds, the World Record
leaderboard does not change.

Worlds is the exclusive gateway into the World Record system.


---

### 31.2 Total World Record determines Sheffield qualification

Sheffield qualification is based on TOTAL.

Individual Squat, Bench, and Deadlift World Records do NOT qualify a player for Sheffield.

Each weight class tracks a Total World Record.

The Total World Record must represent an actual meet total achieved by one player.

DO NOT calculate Total World Record by adding separate Squat, Bench, and Deadlift records
that may belong to different players.


---

### 31.3 Official World Record

Each weight class has an Official Total World Record.

The Official World Record is FROZEN throughout the active monthly cycle.

It does NOT immediately change when somebody exceeds it at Worlds.

Instead, qualifying performances enter the Pending / Unofficial World Record system.

The frozen Official World Record serves as the established standard for that monthly
cycle and as the denominator for Sheffield scoring.


---

### 31.4 Pending / Unofficial World Record

During the monthly Worlds qualification window, players compete to establish the highest
Pending Total World Record in their weight class.

Example:

Official 83 kg Total WR = 800 kg

Worlds results:

Player A = 810 kg
Player B = 820 kg
Player C = 825 kg

Pending 83 kg WR becomes:

825 kg

The Official WR remains:

800 kg

until the monthly Sheffield cycle is completed.

If another player later totals 827.5 kg at a valid Worlds meet before the cutoff:

Pending WR = 827.5 kg

This creates an active monthly race between players in each weight class.


---

### 31.5 World Record ties

Multiple players may hold the same highest Pending Total World Record.

Example:

Player A = 825 kg
Player B = 825 kg

Both players are recognized as tied Pending WR holders.

Both qualify for Sheffield.

Do NOT resolve Sheffield qualification ties by:

- who achieved the result first
- bodyweight
- timestamp
- arbitrary player ID
- random selection

If multiple players legitimately share the highest qualifying Total, all tied players
qualify.


---

## 32. Monthly Sheffield Championship


### 32.1 Monthly cycle

The intended high-level monthly lifecycle is:

Official WR Snapshot
        ↓
Worlds Qualification Window
        ↓
Players challenge Pending Total WRs
        ↓
Worlds cutoff
        ↓
Pending WRs freeze
        ↓
Highest Total holder(s) from each class qualify
        ↓
Sheffield Championship
        ↓
New Official WRs are established
        ↓
Next monthly cycle begins

The exact calendar dates/times are TBD.


---

### 32.2 Sheffield qualification

At the Worlds cutoff:

The player(s) holding the highest valid Pending Total WR in each eligible weight class
qualify for Sheffield.

Qualification is PLAYER-BASED and TOTAL-BASED.

Individual lift World Records do not independently grant qualification.

If multiple players are tied for the highest qualifying Total in a class, every tied
player qualifies.


---

### 32.3 Worlds cutoff

Once the monthly Worlds qualification window closes:

Pending WR leaderboards freeze for that cycle.

Additional Worlds results cannot modify that cycle's Sheffield qualification.

Players cannot enter after the cutoff and retroactively qualify for the already scheduled
Sheffield event.

A new qualification period begins only when the next monthly cycle begins.


---

### 32.4 Sheffield scoring baseline

Sheffield uses the Official Total World Record that existed BEFORE the current monthly
Worlds qualification cycle.

This value is frozen for the entire Sheffield event.

A player's own Worlds qualification performance must NOT increase their Sheffield
denominator.

The denominator must not change during Sheffield.


#### Sheffield Score

For each competitor:

SheffieldRatio =
SheffieldMeetTotal / FrozenOfficialClassTotalWR

SheffieldPercent =
SheffieldRatio * 100

Example:

Frozen 59 kg Official Total WR = 700 kg

Player Sheffield Total = 721 kg

721 / 700 = 1.03

Sheffield Percent = 103%


Another competitor:

Frozen 120 kg Official Total WR = 1000 kg

Player Sheffield Total = 1020 kg

1020 / 1000 = 1.02

Sheffield Percent = 102%


The 59 kg competitor wins:

103% > 102%

even though the 120 kg competitor lifted more absolute weight.


---

### 32.5 Sheffield winner

The Sheffield winner is determined by who achieves the highest percentage relative to
their frozen class Official Total World Record.

Conceptually:

Winner =
MAX(
    SheffieldMeetTotal / FrozenOfficialClassTotalWR
)

This allows lifters from different weight classes to compete against one another through
relative record performance rather than raw kilograms.


---

### 32.6 World Record update after Sheffield

Official World Records update AFTER Sheffield.

For each weight class:

NewOfficialWR =
MAX(
    PreviousOfficialWR,
    HighestValidWorldsPendingTotal,
    HighestValidSheffieldTotalForThatClass
)

A player performing worse at Sheffield must NOT erase a stronger valid Worlds result.

Example:

Previous Official WR = 800 kg

Worlds Pending WR = 825 kg

Sheffield Total = 815 kg

New Official WR = 825 kg


Example:

Previous Official WR = 800 kg

Worlds Pending WR = 825 kg

Sheffield Total = 832.5 kg

New Official WR = 832.5 kg


After the update, this value becomes the frozen Official WR for the next monthly cycle.


---

### 32.7 Authoritative weight class

World Record performances must belong to the player's legitimate meet weight class.

At authoritative meet entry / weigh-in, freeze:

- weighInKg
- meetClass
- meetBuild

World Record eligibility must use this frozen meet state.

Changing bodyweight or build state after meet entry must not move a result into another
weight class.


---

### 32.8 World Record data separation

There are multiple record/reference concepts in this game and they MUST remain separate.


#### Progression Reference

The frozen FitVersion progression reference used for Competition Number progression.

This must NOT change because players break World Records.


#### Official Player World Record

The frozen monthly Total WR established by player competition.

Used as the Sheffield scoring baseline for the appropriate cycle.


#### Pending / Unofficial World Record

The highest eligible Worlds Total achieved during the active monthly qualification
window.

Used for Sheffield qualification.


#### Live Historical Records

Historical player achievements / record history may be stored separately for prestige,
leaderboards, profiles, and event history.


NEVER automatically derive or modify ProgressionReferenceConfig from player World Records.


---

### 32.9 Sheffield rewards

Sheffield should be one of the highest-value competitive events in the game.

Potential reward categories include:

- Very large money rewards
- Rare / exclusive equipment
- Exclusive cosmetics
- Titles
- Trophies
- Permanent championship history
- Prestige / profile recognition

Exact values and reward pools are TBD.

The Sheffield champion should receive exceptional rewards.

However, Sheffield should NOT provide an enormous permanent Competition Number multiplier
that causes the current champion to snowball uncontrollably into future championships.

> **Section 33 strengthens this rule rather than contradicting it.** Under section
> 33.3 no meet grants Competition Number at all, so the Sheffield CN multiplier is
> not merely "not enormous" — it is **zero**. Read this rule as a floor that has
> since been exceeded, never as permission for a small CN multiplier.
>
> Sheffield may of course still raise **Competition Scale** through its attempts,
> on exactly the same terms as any other eligible meet (§33.7), and all its money,
> equipment, cosmetic, title, trophy and prestige rewards are unaffected.


---

### 32.10 First-cycle bootstrap

The first monthly cycle requires an initial Official Total WR baseline for every eligible
weight class.

The exact bootstrap source has NOT yet been finalized.

Possible approaches include using a fixed developer-approved reference baseline.

DO NOT automatically assume or implement a bootstrap source until explicitly approved.


---

### 32.11 Implementation status

DESIGN DIRECTION FROZEN:

- Worlds is the only gateway for Pending WRs.
- Sheffield qualification uses Total WR only.
- Official WR stays frozen during the monthly cycle.
- Worlds creates/challenges Pending WRs.
- Highest Pending Total holder(s) per class qualify.
- Exact ties all qualify.
- Worlds qualification freezes at cutoff.
- Sheffield uses the PRE-CYCLE Official Total WR as its denominator.
- Sheffield winner is highest percentage above/relative to their class baseline.
- Official WR updates AFTER Sheffield.
- New Official WR preserves the strongest valid Worlds or Sheffield result.
- Player count scales normal competition Prize Pots.
- Placement scales money/equipment rewards.
- ~~CN progression remains based on individual attempt performance, not placement/player count.~~
  **[SUPERSEDED BY SECTION 33.3]** — meets do not advance CN at all. The rule's
  intent survives and transfers to **Competition Scale**: a Scale increase is
  based on the weight actually lifted, never on placement or player count (§33.7).
- Progression References and player World Records remain completely separate.
- **Competition Scale is a third separate quantity** and must never be used to
  construct an official Total (§33.8). Section 31.2's prohibition on summing
  separate lift records applies to Scale with full force, because three per-lift
  Scales may come from three different meets.

TBD / REQUIRES FUTURE DESIGN APPROVAL:

- Exact monthly schedule
- Exact Worlds eligibility requirements
- Exact Sheffield scheduling/hosting flow
- Initial first-cycle WR baselines
- Prize Pot formula
- Placement payout percentages
- Minimum participation requirement for Prize Pot contribution
- Equipment drop rates
- Equipment rarity tiers
- Equipment effects
- Sheffield reward amounts
- Record-history retention rules
- Handling disconnected/no-show Sheffield qualifiers
- Exact handling of 120+ record/scoring behavior

---

## 33. Competition Number and Competition Scale — REVISED PROGRESSION MODEL

> **This section is authoritative where it disagrees with sections 3, 12, 15, 28,
> 29 or 30.** Section 29's mathematics, its frozen Progression Reference table
> (§29.2b) and its weight-class rules (§29.11) are **not** superseded — only the
> question of *where Competition Number comes from*, and the addition of a second
> per-lift quantity.
>
> **Do NOT implement these systems merely because they are documented here.** The
> Scale challenge curve and cap, the starting Scale, the migration backfill, the
> training EV rates and the fate of the Competition Budget are all **[TBD]** and
> must be approved before implementation. See §33.11 and §33.12.

The design principle in one line:

> **Training builds strength potential. Competition proves that strength.**

Under the previous model these were the same number, and meets were its largest
single source — a meet both demonstrated strength *and* created it. That made the
game's most dramatic moment into a progression faucet, and it meant a player's
capability number could rise without them ever having stood over a loaded bar and
made the lift.

The revised model separates the two.


### 33.1 The two quantities

**[FROZEN]**

| Quantity | What it is | How it changes | What it drives |
|---|---|---|---|
| **Competition Number (CN)** | the strength the character has **developed through training**, in kg | training (and dailies / AFK — §33.9) | **physical difficulty**, attempt selection, display, Progression Proximity |
| **Competition Scale** | the heaviest weight the character has **successfully proven in competition**, per lift, in kg | a successful eligible meet attempt, and nothing else | the **Scale challenge modifier** (§33.4) |

Both are **per lift**: Squat, Bench and Deadlift each have their own CN and their
own Scale.

They answer two different questions:

```
Competition Number   "what can this lifter do?"        <- training answers this
Competition Scale    "what has this lifter done?"      <- competition answers this
```

**[FROZEN] Scale is never a cap on CN, and CN is never a cap on Scale.** They move
independently. A player may train CN far above their Scale — that is the normal
state of a lifter who has been training and has not yet competed — and the gap is
not a defect to be corrected.

> **Reading note.** CN and Scale are the *second* and *third* quantities a reader
> must keep apart. §29.2 already distinguishes **Competition Number**, the
> **Progression Reference** and the **Real World Record**. Competition Scale is a
> fourth, separate thing, and in particular it is **not** a record: a record is a
> ranked, contested, Worlds-gated claim (§31), while a Scale is a private per-lift
> high-water mark that every player has.


### 33.2 The training-to-competition loop

```
      TRAIN                          COMPETE
        |                               |
        v                               v
  Competition Number  ------------>  choose an attempt
  (trained capability)               (legal, CN-supported)
        |                               |
        | drives physical difficulty    | if the lift is GOOD
        |                               v
        |                        Competition Scale
        |                      (proven capability)
        |                               |
        |                               | drives the Scale
        |                               | challenge modifier
        +-------------> MEET <-----------+
                      challenge
```

The intended player experience:

- **Training is how you get stronger.** It is the only thing that raises CN, and
  CN is what makes the bar easier to handle. A player who wants a heavier squat
  trains squats.
- **Competing is how you prove it.** A meet converts trained capability into
  demonstrated capability. Nothing about competing makes the character stronger.
- **The first attempt at a new weight is the hard one.** A weight far above
  anything the lifter has proven carries the Scale challenge modifier on top of
  its physical difficulty. Once proven, it stops being unfamiliar territory.
- **Nothing is gated behind grinding.** A lifter who has trained a 200 kg squat
  may walk into a meet and attempt 200 kg on their first ever attempt (§33.5).


### 33.3 Meets never increase Competition Number

**[FROZEN]** A meet **never** increases Competition Number — not during it, not
on completion, and not as a reward for placing, winning, qualifying or setting a
record.

This covers every meet type without exception: Solo, Qualifying, Local, Nationals,
Worlds and the monthly Sheffield Championship.

Specifically prohibited:

- CN for a successful attempt
- CN for a failed attempt
- CN for a completed meet, a total, or going 9/9
- CN for placement, victory, meet size or field strength
- CN for a World Record, a Pending WR, or a Sheffield win
- a CN **multiplier** awarded by any of the above

**Why this rule is absolute.** A partial version of it would be unenforceable. If
any competition outcome advanced CN even slightly, then CN would again become
farmable by competing, the Competition Budget would have to return to throttle it,
and the distinction this section exists to create would blur back into the model it
replaced. The rule is easier to hold at zero than at "small".

**What meets still award:** Competition Scale (§33.7), technique progression,
placement, prestige and career history, currency and the prize pot, equipment and
item chances, titles, cosmetics, Nationals and Worlds qualification, and World
Record eligibility where §31 permits. Sections 30, 31 and 32 remain authoritative
for all of those.

> Supersedes: §29.5 attempt rows, §29.6 meet share, §29.10 CN parity row, §30.1
> category 1, §30.2 in full, §32.11's CN bullet.


### 33.4 The two difficulty roles

**[FROZEN] Physical difficulty is unchanged.** It still divides by Competition
Number, exactly as sections 3, 14 and 29 specify, and exactly as
`DifficultyResolver` already implements:

```
Physical Difficulty = Attempt Weight / Competition Number
```

This is the single most important compatibility statement in this section. The
difficulty engine, the `IntensityConfig` curve and all four minigame phase
services keep their existing meaning. **Trained strength is still what makes the
bar manageable.**

**[FROZEN] Competition Scale adds a SEPARATE challenge modifier**, on top of
physical difficulty and never in place of it:

```
Scale Challenge Ratio = Attempt Weight / Competition Scale
```

Worked example:

```
Squat Competition Number = 200 kg
Squat Competition Scale  = 100 kg
Attempt                  = 200 kg

Physical Difficulty  ->  200 / 200 = 1.00   (a 100% attempt for this lifter)
Scale Challenge      ->  200 / 100 = 2.00   (twice anything they have proven)
```

The lifter is physically equal to the weight — their training says so — but they
have never demonstrated anything like it in competition, and the attempt carries a
modifier reflecting that.

**[FROZEN] constraints on the modifier**, whatever curve is eventually chosen:

- It must be **moderate**. It is a flavour of competitive pressure, not a second
  difficulty system. It must never dominate physical difficulty.
- It must be **capped**. An uncapped ratio is unbounded — a lifter with a very low
  Scale and a well-trained CN can produce a ratio of 5, 10 or more — and an
  unbounded modifier would make §33.5 meaningless in practice.
- It must **not** feed the `IntensityConfig` base-difficulty curve. That curve is
  anchored on 0.50 to 1.10 of CN and saturates near 100 past ~130%; routing a
  Scale ratio of 2.00 through it would read as "Near Maximum" regardless of the
  actual attempt and would destroy the difficulty signal.
- It must **never** make an attempt impossible. A player may always attempt what
  their CN and the legal attempt rules allow (§33.5).

**[TBD] The exact curve, the cap, and the shape of its effect are NOT decided.**
No values are specified here and none should be inferred. The open questions:

| Question | Status |
|---|---|
| The curve mapping Scale Challenge Ratio to a modifier | **[TBD]** |
| The cap value | **[TBD]** |
| What the modifier actually modifies — base difficulty, effective technique, a minigame parameter, or a new channel | **[TBD]** |
| Behaviour at ratio <= 1.00, i.e. a weight at or below proven Scale — neutral, or an easing bonus | **[TBD]** |
| Behaviour when Scale is absent or zero | **[TBD]**, and blocked on §33.8 |
| Whether the modifier is shown to the player as its own number or folded into the displayed difficulty | **[TBD]** |

> **Implementation note, not a design rule.** `DifficultyResolver.resolve` asserts
> its denominator is above zero, and the attempt flow rejects a non-positive
> Competition Number. Any modifier that divides by Scale needs the same guarantee,
> which is why the starting-Scale decision (§33.8) blocks this one.


### 33.5 Attempt eligibility — no Scale milestones

**[FROZEN]** A player may immediately attempt any weight supported by their
trained Competition Number and the existing legal attempt rules, **however far
above their Competition Scale it is**.

**[FROZEN] There are no intermediate Scale milestones.** The game must never
require a lifter to prove 110 kg, then 120 kg, then 130 kg on the way to 200 kg. A
player who has trained a 200 kg squat and never competed may open at, or work up
to, 200 kg in their first meet.

The rules that **do** bound an attempt are unchanged:

- the **legal attempt rules** of §15 and Group C — three attempts per lift, never
  below a weight already attempted, 2.5 kg minimum increments, a failed weight may
  be repeated
- the **attempt percentage bounds** applied server-side relative to Competition
  Number
- **physical difficulty**, which rises steeply past 100% of CN and is the real
  deterrent against absurd attempts

Scale is **not** on that list. It changes how hard an attempt feels, never whether
it is allowed.

**Why no milestones.** Milestones would turn proving strength into a grind, and
they would reintroduce exactly the treadmill this model is meant to avoid: because
raising Scale requires succeeding at or above current Scale, a milestone system
would force every lifter through a fixed ladder of high-intensity attempts
regardless of how strong they actually are. The design intent is that training is
the grind and competing is the payoff, not both.


### 33.6 Failed attempts earn nothing

**[FROZEN]** A failed attempt yields:

- **zero** progression EV
- **zero** Competition Number gain
- **no** Competition Scale increase

**[FROZEN] The old failure credit is removed.** `FailureCredit = 0.20` is
**[OBSOLETE]**. Players must not permanently progress merely for attempting and
failing a weight.

> The code constant `ProgressionConfig.FailureCredit` is **deliberately retained
> for now** and is scheduled for removal in a later increment (§33.12). It is read
> by nothing in production — only by a dev probe that defaults to disabled — so it
> is inert, but it must be removed together with the probe section that asserts it,
> not before.
>
> Previously affected text: §29.5 EV table, §29.15 recalibration list, §30.2.

**A consequence that needs attention, not a rule.** The previous model's safety
against reckless play came from failures being worth a constant fraction of
successes, which made the EV-per-budget ratio identical either way (§29.9). With
the credit at zero *and* Scale defined as a maximum (§33.7), a failed meet attempt
costs nothing but time, and only the single heaviest success matters. Both sides of
that balance have been removed. See §33.11, question 1.


### 33.7 Raising Competition Scale

**[FROZEN]**

```
New Scale = max(Old Scale, Heaviest Successful Eligible Meet Attempt)
```

Properties, all frozen:

- **Monotone.** Scale **never decreases**. A poor meet, a bomb-out, a bad day or a
  long absence leaves it exactly where it was. Proven strength stays proven.
- **Success only.** A failed attempt cannot raise it, at any weight (§33.6).
- **Heaviest only.** Only the single heaviest successful attempt is considered.
  Going 3/3 and going 1/3 give the identical Scale when the heaviest made lift is
  the same.
- **Per lift.** A squat raises the Squat Scale and touches nothing else.
- **Not multiplied by anything.** Placement, player count, field strength, meet
  tier and prestige do not scale a Scale increase. It is the weight that was on the
  bar, full stop. This extends the surviving rules of §30.2 to the new quantity.

**[FROZEN] Solo meets may raise Competition Scale.**

This preserves §29.10's frozen principle that basic strength progression is
**never population-gated**, and it preserves it for the same reason the original
rule gave: if Scale could only be raised in Official meets, waiting for other
players would become optimal and low-population servers would be punished.

**[FROZEN] Solo results cannot establish an official World Record.** Section 31 is
unchanged and remains the only authority on records: Worlds is the sole gateway for
Pending World Records, and Official records update only after Sheffield. A
solo-raised Scale is a private high-water mark with no record standing whatsoever.

> The two rules above are deliberately asymmetric, and the asymmetry is the point.
> Scale is **personal** — it describes one lifter's own history and needs no
> witnesses. A record is **contested** — it is a ranked claim against every other
> player and requires the full Worlds pipeline. One is not evidence for the other.

**[TBD] What "eligible" means precisely.** Solo and Official meets are in. Whether
the following count has not been decided: practice or warm-up modes, training
sessions styled as meets, meets abandoned or disconnected part-way, meets
subsequently voided for rule violations, and any future tutorial meet. The
principle to apply is that an eligible attempt is one taken under full competition
conditions and judged.


### 33.8 Competition Scale data rules

**[FROZEN] Scale is per lift**: three values, Squat, Bench and Deadlift.

**[FROZEN] Scale ultimately belongs to the weight-class build**, alongside
Competition Number. A Scale is a weight proven *by a particular build in a
particular class*, so it travels with that build. Section 29.11's build and
weight-class architecture governs it, and the `competitionNumber` field's existing
note about moving into a future `builds[classKey]` map applies equally to Scale.

> Until the Weight-Class Build Slot system exists, Scale — like CN — describes the
> player's only build. No `builds` map should be invented for it ahead of that
> system.

**[FROZEN] Competition Scale must NEVER be used to construct an official Total.**

Section 31.2 already prohibits calculating a Total World Record by adding separate
Squat, Bench and Deadlift records. That prohibition applies to Scale **with full
force and for exactly the reason it was written**: three per-lift Scales may have
been proven in three different meets, possibly months apart, possibly in different
weight classes, so summing them produces precisely the fictional total §31.2
forbids. An official Total must represent one lifter's three best lifts **in a
single meet**, which is what `MeetTotal` computes from a meet's own attempt
history.

A player-facing "Proven Total" display, if one is ever wanted, is a **cosmetic
curiosity** and must be labelled clearly enough that it can never be mistaken for a
competition total or a record. **[TBD]** whether to have one at all.

**[TBD] The starting Competition Scale for a brand-new lifter.** No value is
specified. The options and their consequences:

| Option | Consequence |
|---|---|
| Equal to starting CN | The first attempt at 100% of CN carries a Scale ratio of 1.00, so a new lifter meets no Scale modifier at all until they attempt above their CN. Simplest, and the gentlest onboarding. |
| A fixed value below starting CN | A new lifter meets the modifier immediately, which teaches the mechanic early but front-loads difficulty on a player who has nothing else working in their favour. |
| Absent / zero — "never proven" | The most honest representation, and the only one that makes "unproven" a real state the UI can show. Requires an explicit rule for what the modifier does with no Scale (§33.4), since a ratio is undefined. |

**[TBD] The migration backfill for existing players.** No player profile currently
holds any meet history, because the meet system is not implemented, so **there is
no data from which an existing player's Scale can be derived**. This must be an
explicit decision, not a default:

| Option | Consequence |
|---|---|
| Scale = current CN (grandfather) | Nothing changes for existing players; they meet the modifier only when attempting above CN. Hands out proven strength that was never proven. |
| Scale = the new-lifter starting value | Consistent with new accounts, but an established player with a well-trained CN would suddenly face the maximum Scale modifier on every attempt. |
| Scale = absent / "never proven" | Honest, and consistent with the fact that nobody has competed yet. Depends on the §33.4 rule for an absent Scale. |

**[TBD] What a stored Scale records.** The minimum that satisfies §33.7 is one
number per lift. A richer record — the weight plus the weight class, meet and date
it was proven in — would support showing a player where their Scale came from, and
would align with §32.7's authoritative weight class. Retrofitting it later is a
second schema migration, so it is worth deciding once.

> Persistence is **not yet implemented**. No schema field exists. See §33.12.


### 33.9 Where Competition Number now comes from

**[FROZEN] Training is the primary source of Competition Number.** Section 12's
training matrix is unchanged and still correct — Competition Squat builds the
Squat CN, Competition Bench builds the Bench CN, Competition Deadlift builds the
Deadlift CN, and the variations build technique stats. Dailies and AFK training
remain CN sources on their existing terms (§29.5, §29.7, §29.8).

**[TBD] The training EV rates.** No training EV value exists anywhere in this
document, and none is invented here. This is the single largest gap the revised
model creates, because training must now carry the share meets used to carry. It
cannot be settled without §29.6's replacement distribution.

#### The existing reward engine is reusable — for training, not for meets

**The `CompetitionNumberReward` engine does not need to be replaced.** It was built
to take an authoritative EV value and knows nothing about meets, attempts, success
or failure — converting an event into EV was deliberately left to the caller. That
decision is what makes it survive this change untouched.

Reusable **as-is**, with no modification:

| Component | Why it carries over |
|---|---|
| `ProgressionReferenceConfig` — the 21 frozen literals, FitVersion 1 (§29.2b) | A progression-normalization table. Never had anything to do with meets. |
| `PP = CN / ProgressionReference` (§29.2) | CN is still trained capability and PP is still its normalization against the class reference. Unchanged in meaning. |
| `Hill(PP) = 1 / (1 + (PP / 0.75)^5)` (§29.3) | A soft cap on trained progression. Unchanged. |
| R2 reference normalization (§29.4) | Reference-independent and source-independent. Every class still progresses at the same PP rate. |
| `dCN = Reference x BaseProgressRate x EV x Hill(PP)` (§29.3) | The arithmetic is correct; only the EV **producer** changes. |
| RP Preservation on class change (§29.11) | Untouched. |

What is actually needed is **a training event to EV converter** — the training-side
equivalent of the meet-attempt converter that was never built. The reserved
`awardProgression(player, lift, effectiveEV)` operation described in
`PlayerDataService` is the correct home for the write, and it already derives
kilograms from EV rather than accepting them, so no caller can get the magnitude
wrong.

Two inputs do **not** carry over cleanly and need design:

- **Success / failure.** A meaningful notion of a failed *training* set, if there
  is to be one, is undefined. **[TBD]**
- **Competition Budget.** Whether training EV passes through the budget at all is
  **[TBD]** (§29.9, §33.10).

**[FROZEN] `BaseProgressRate` remains a single configurable constant** (§29.15), so
whatever the new channel mix turns out to be, rescaling stays a one-line change.
**It must be re-solved** against that mix (§29.6).


### 33.10 What this leaves unresolved in section 29

Three section 29 systems are left without a settled role. Each is marked in place;
collected here so the list is in one spot.

| System | Where | Status |
|---|---|---|
| **The three Competition Budgets** | §29.9 | **[TBD]** — the system exists to throttle meet-derived CN and now throttles nothing. Rehome to training, repoint at Scale, or retire. Note that the consumption rule "proportional to the CN actually awarded" does **not** survive being repointed at Scale, because a Scale increase is a kilogram jump and not an EV amount. The pools are already persisted, so leaving them attached to nothing is the one outcome to avoid. |
| **Training Energy scope** | §29.8 | **[TBD]** — it was written to limit *passive AFK* CN while active play went unthrottled. Training is now the primary active channel, and whether a 120-minute daily allowance should govern it is a materially larger decision than the one originally made. Its **[FROZEN]** rule that it never limits Muscle is unaffected. |
| **Channel distribution and everything derived from it** | §29.6, §29.13, §29.14 | **Requires recalibration** — the 65 / 20 / 15 split, the PP-to-time pacing table and the archetype rate table were all computed with meets as the dominant channel. The pacing *target* may well stand; the *tables* are outputs and will move. |

**Unchanged and still fully authoritative**, for the avoidance of doubt: §29.1,
§29.2, §29.2b, §29.3, §29.4, §29.11, §29.12, and the whole of §31 and §32 except
the two items marked in place.


### 33.11 Open design questions — [TBD]

Collected so none is lost. None of these should be answered by implementation
choice.

1. **What stops maximum-risk meet strategy?** With failures costing zero (§33.6)
   and Scale being a maximum (§33.7), the optimal meet strategy is to attempt the
   heaviest weight with any chance of succeeding. This **inverts** §29.5's frozen
   note that conservative play should out-earn aggressive play. Existing brakes:
   three attempts per lift, the no-lowering rule, bomb-out consequences, entry
   costs, and placement money. Whether those suffice, or whether Scale needs a
   per-meet increment cap, is undecided.
2. **The Scale challenge curve, its cap, and what it modifies** (§33.4). Including
   its behaviour at ratio <= 1.00 and with an absent Scale.
3. **The starting Competition Scale** (§33.8).
4. **The migration backfill for existing players** (§33.8).
5. **Training EV rates**, and the replacement channel distribution they belong to
   (§33.9, §29.6).
6. **The fate of the Competition Budget** (§29.9, §33.10).
7. **Training Energy's scope** now that training is the primary channel (§29.8).
8. **The "Compete" daily pillar** — does it award CN, and does completing it
   require entering a meet? (§29.7)
9. **What "eligible meet" includes** for the purpose of raising Scale (§33.7).
10. **What a stored Scale records** — a bare number, or weight plus class, meet and
    date (§33.8).
11. **Scale across weight classes.** CN translates between classes by RP
    Preservation (§29.11). Translating Scale would mean inventing a lift that never
    happened; not translating it means a class change resets proven strength.
    Undecided, and interacts with §33.8's build scoping.
12. **Scale display precision and presentation** (§29.12), including whether an
    "unproven" state is shown and whether a cosmetic Proven Total exists at all.

#### Risks the confirmed rules already resolved

Recorded because they were live concerns during the audit and should not be
re-raised as though open:

- **CN becoming gameplay-irrelevant** — resolved by §33.4. Physical difficulty
  still divides by CN, so training still directly determines how manageable the
  bar is.
- **A forced ladder of proving weights** — resolved by §33.5. No milestones.
- **Difficulty-curve saturation** — resolved by §33.4's rule that the Scale ratio
  must not feed the `IntensityConfig` base-difficulty curve, together with the cap.
- **Population-gated progression** — resolved by §33.7. Solo meets may raise Scale.
- **A runaway feedback loop between Scale and success** — substantially damped,
  because Scale now drives only a moderate capped modifier rather than the
  difficulty denominator itself. A lucky heavy success still permanently reduces
  that modifier, but the benefit is bounded by the cap, and CN remains the main
  driver of difficulty.


### 33.12 Implementation status

**NOTHING IN THIS SECTION IS IMPLEMENTED. This is a documentation-only revision.**

Current repository reality, verified:

- There is **no meet system**. The only meet code is two pure modules,
  `AttemptRules` and `MeetTotal`, neither of which is used by any live system. So
  **no production code has ever awarded Competition Number for a meet**, and
  §33.3 requires no code change to become true.
- `CompetitionNumberReward` has **zero** production callers. It is exercised only
  by a dev probe that defaults to disabled.
- `PlayerDataService` exposes **no** Competition Number writer at all. The write
  path is deliberately closed pending `awardProgression`.
- **Competition Scale does not exist** in any form: no schema field, no type, no
  config, no code.
- `ProgressionConfig.FailureCredit = 0.20` is **still present**, intentionally. It
  is read only by a disabled dev probe.
- Physical difficulty already divides by Competition Number, so §33.4's frozen
  half is **already how the game behaves**.

Suggested sequencing, smallest safe steps first. Each leaves the game playable and
none should begin without the decisions it depends on:

| # | Step | Blocked on |
|---|---|---|
| 1 | This documentation revision | — (done) |
| 2 | Remove `FailureCredit` from config together with the probe section that asserts it | nothing; §33.6 is frozen |
| 3 | Add Competition Scale to the player schema as a stored but unread field, with a migration | §33.8 starting value and backfill |
| 4 | A pure, monotone `raiseCompetitionScale` operation, with no callers | step 3 |
| 5 | Define and implement the training CN channel | §33.9 training EV rates, §29.6 distribution |
| 6 | Implement the Scale challenge modifier | §33.4 curve, cap and target |
| 7 | Wire meets to raise Scale | a meet system existing; §33.7 eligibility |
| 8 | Resolve the Competition Budget | §29.9 |

> Step 4 should be built on `MeetTotal.bestSuccessful`, which already computes
> "the heaviest successful attempt on one lift" — the exact input §33.7 needs.
> There is no reason to write a second one.
