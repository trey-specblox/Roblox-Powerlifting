## MECHANIC ASSIGNMENT — CURRENT SOURCE OF TRUTH

Each lift has its own first phase. All three converge on the same reusable timing
skill check as their second phase.

| Lift | Phase 1 | Phase 2 | Phase 1 stat | Phase 2 stat |
|---|---|---|---|---|
| Squat | Fisch-style Control (`References/FischeGame.md`) | Depth timing check (`References/DBD.md`) | Squat Control | Depth Awareness |
| Bench | Test Your Might power (`References/testyourmight.md`) | Press timing check (`References/DBD.md`) | Start Control | Press Power |
| Deadlift | Fluid Typing pull (`References/TypingGame.md`) | Lockout timing check (`References/DBD.md`) | **none** -- see section 34.6 | Lockout |

The Fisch-style control mechanic is **Squat-only**. The Test Your Might mechanic is
**Bench-only**. The timing check is shared by all three, which is why it was built
once and is driven entirely from per-phase configuration.

> **This table is a correction.** `testyourmight.md` and `FischeGame.md` were
> originally swapped: Test Your Might was assigned to Squat Control and the
> Fisch-style mechanic to the Bench. Sections 7 and 9 below, and both reference
> files, have been corrected to match this table. Where anything in this document
> still disagrees, this table wins.

> **One exception, and it is the only one: `Pull Strength` is removed as a
> trainable stat -- see sections 34.6 and 34.9.** The Deadlift's Phase 1 has **no**
> technique stat and no replacement is created for it. Where this table and section
> 34 disagree about `Pull Strength`, **section 34 wins**.
>
> **Phase 1 itself is unaffected and is still required.** The competition Deadlift
> remains a **two-phase** lift: the typing pull still gates the attempt and failing
> it is still a NO LIFT. Only its *stat* is removed, and its difficulty is rebased
> on attempt intensity and player execution alone (section 34.9).
>
> The field is still live in code. Removing it is checkpoint 9 in section 34.14 and
> must happen in the same change as the Deadlift typing retune (section 34.9).

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
**[REMOVED -- see section 34.6]** Pull Strength
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

Relevant Stat: **none.** ~~Pull Strength~~ is removed -- see section 34.6.

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

**[OBSOLETE -- SUPERSEDED BY SECTIONS 34.6 AND 34.9]** Pull Strength increases
progress per character, reduces sag and reduces the mistake penalty, so a trained
lifter needs FEWER keystrokes rather than faster ones. It never reduces the
threshold, the window or the cue content, so the pull can never become automatic.

> **`PullStrength` is removed and no replacement typing progression stat is
> created** (sections 34.6, 34.9). The paragraph above is retained only as the
> record of what the three typing curves were originally shaped by.
>
> **Deadlift typing is now an active skill mechanic whose reward is strictly
> cosmetic currency** (section 34.9). Cosmetic currency can never raise
> Competition Number, technique stats or any lifting modifier.
>
> **The mechanic itself is unchanged, and it is still Phase 1 of a competition
> Deadlift** -- the rising bar, the continuous cue line, the sag, the mistake stall
> and the lockout threshold all stand, and **failing the pull is still a NO LIFT**.
> The competition Deadlift remains a **two-phase** lift (section 34.9): typing
> pull, then the Lockout skill check, which still uses the `Lockout` technique
> stat.
>
> Only what **scales** this phase changes: it must be **rebased on attempt
> difficulty / intensity and the player's own execution alone**, with no trainable
> stat and no replacement for one. That rebase is **[PROVISIONAL]** -- no curve
> exists yet -- and it is checkpoint 9 in section 34.14, which must ship in the
> same change as the schema migration that drops the field.

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
> **The "how much" is now answered in section 34.** Training EV rates exist:
> `BaseRate = 1.00 EV per hour` under the per-lift diminishing-efficiency function
> `H(t)`, against a **4.00 EV account-wide daily cap** (section 34.4). They are
> **[PROVISIONAL]**, no longer [TBD].
>
> **Training is now the ONLY source of Competition Number** (section 34.2).
> Dailies, login rewards and purchases do not award it either. It is delivered by
> Auto-Train at an **eligible gym training station**, on **one manually selected
> lift** at a time (section 34.3).

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

> **Cosmetic currency is confirmed, and constrained -- see section 34.9.** It is
> **strictly cosmetic**: it can never increase Competition Number, technique stats
> or any lifting modifier, and **AFK training awards none of it**. Its rate and
> daily cap are **[TBD]**.



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
Squat Control / Depth Awareness / Start Control / Press Power / Lockout

> **Five trainable technique stats, not six -- see section 34.6.** `Pull Strength`
> is removed and no replacement is created. The Deadlift has one trainable
> technique stat, and that asymmetry is accepted.

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

Rules in this document carry one of six status markers. The first four are the
original vocabulary; §34 added the last two for the approved Step 5 design.

- **[FROZEN]** — architecture. Changing it changes the design.
- **[TUNABLE]** — a balance constant. Expected to move after playtesting.
- **[TBD]** — not yet decided. Must be approved before implementation.
- **[OBSOLETE]** — superseded. Retained for audit only; **never implement it**.
  Obsolete text is struck through or labelled in place, never silently deleted.
- **[FINAL]** — an approved **mechanic or rule**. Same force as [FROZEN]; the
  separate word records that it was decided at the Step 5 design review rather
  than being original architecture.
- **[PROVISIONAL]** — an approved mechanic's **unvalidated number**. Same force as
  [TUNABLE], and deliberately louder: it has never run in a real game, it **will**
  move, and it must be implemented as named configuration rather than inlined.

> **A [FINAL] mechanic may carry [PROVISIONAL] numbers, and most of §34 does.**
> The mechanic is settled; the magnitude is not. **Never read a [FINAL] heading as
> freezing the figures beneath it** — each figure carries its own marker.

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
| `BaseProgressRate` | **0.00482389** | **[TUNABLE]** — single config constant. **This is the value in the code today.** A **[PROVISIONAL]** Step 5 recalibration to **0.01113418** is proposed in §34.11 and is **not implemented** |

**[FROZEN]** The soft cap is asymptotic. There is **no hard strength cap** at any
PP. Progression slows without limit and never reaches zero.

`BaseProgressRate` means: one unit-quality attempt grants **0.4824% of that
lift's Progression Reference**, before the soft cap.

> **Two numbers exist, and only one of them is implemented.**
>
> | | Value | Status |
> |---|---|---|
> | **In the code today** | **0.00482389** | **[TUNABLE]** — live, and the 0.4824% above follows from it |
> | **Proposed for Step 5** | **0.01113418** | **[PROVISIONAL]** — a calibration candidate (§34.11). **Not implemented. Not frozen.** |
>
> Under the candidate the same sentence would read **1.1134%**. Nothing else moves:
> **the formula above, the 21 frozen Progression References (§29.2b) and the Hill
> curve are identical under either value.** `BaseProgressRate` enters as a single
> multiplier, which is exactly why recalibrating it stays a one-line change
> (§29.15).

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

> **⚠ SUPERSEDED IN PART BY SECTION 33, AND THE WHOLE CHANNEL LIST IS NOW
> SUPERSEDED BY SECTION 34.** Meet attempts no longer grant CN (§33.3), the failure
> credit is zero (§33.6), and under §34.2 **every channel except gym-station
> training is removed** -- dailies included. The obsolete rows are **kept, not
> deleted**, because the meet EV figures are the historical basis of §29.9's
> capacity and of the §29.13 / §29.14 calculations, which must stay auditable.
> Each row's status is marked individually.
>
> ~~The daily and AFK rows survive; only their **shares** change (§29.6).~~ They do
> not survive, and there are no shares left to move: there is exactly **one** CN
> channel (§34.2).

**[FROZEN]** EV is reference-independent. Kilograms follow from §29.3.

| Event | EV | Status |
|---|---|---|
| Successful attempt | = intensity factor | **[OBSOLETE as a MEET reward]** — no longer a CN source. Retained as the EV *shape* a training event may reuse |
| Failed attempt | = intensity factor x **0.20** | **[OBSOLETE]** — superseded by section 33.6. Zero EV, zero CN, no Scale increase |
| Full 9-attempt meet (Normal strategy) | ~5.658 (~1.886 per lift) | **[OBSOLETE as a CN figure]** — historical reference only |
| **Compete Daily** | ~~0.3948 to EACH active S/B/D lift~~ | **[OBSOLETE]** — superseded by §34.2. Daily quests award **no CN** |
| **Daily Set completion** | ~~0.1974 to EACH active S/B/D lift~~ | **[OBSOLETE]** — superseded by §34.2. The bonus survives; its CN component does not |
| AFK training | ~~0.2591 per hour~~ | **[OBSOLETE RATE]** — superseded by §34.4. The channel became the *only* channel, so the rate was re-derived from scratch rather than retuned |
| **Gym station training** | **1.00 EV/hour x `H(t)`**, capped at **4.00 EV/day account-wide** | **[PROVISIONAL]** — the **only** CN source. §34.2, §34.3, §34.4 |

> **Daily wording is deliberately explicit.** Both daily rewards are **per lift**,
> not a total to be divided. A completed Daily Set awards 0.1974 EV to Squat,
> 0.1974 EV to Bench and 0.1974 EV to Deadlift — 0.5922 EV in total. The
> alternative reading (0.1974 total, 0.0658 each) yields only a 15.6% daily share
> and misses the 20% target. **[FULLY OBSOLETE under §34.2]** — daily quests now
> award no CN at all, so there is no per-lift reading left to get right. Retained
> only as the record of what these figures once meant.

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

> Still true, and now trivially so for meets. **The question of whether a 60%
> floor should also apply to training EV is RESOLVED, and the answer is that it
> cannot apply:** station training is **time-based** (§34.4), so a training hour has
> no relative intensity to compare against a floor. The rule survives as a meet
> rule with nothing left to govern.

### 29.6 Source distribution target — **[OBSOLETE — RESOLVED BY SECTION 34.2]**

> **⚠ DO NOT BALANCE AGAINST THIS TABLE.**
>
> **✅ The replacement distribution is RESOLVED, and it is trivial: one channel,
> 100% (§34.2).** Gym-station training is not merely the dominant CN source, it is
> the only one, so there is no longer a distribution to balance at all. The
> questions this section left open are answered at the foot of this notice.
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
> The four questions this section raised are now **answered** (§34.2, §34.4,
> §34.11):
>
> - *What share does training take?* — **100%.** It is the only channel.
> - *Do the daily and AFK absolute EV values stay?* — **No.** The daily values are
>   removed with the channel; the AFK rate was re-derived from scratch, not
>   retuned, because it went from carrying 15% of CN to carrying all of it.
> - *Is `BaseProgressRate` re-solved, or do the training rates absorb the gap?* —
>   **`BaseProgressRate` is re-solved.** Candidate **0.01113418**, [PROVISIONAL]
>   (§34.11). It remains one global constant.
> - *Does §29.13's pacing target still stand?* — The **shape** stands; the anchor
>   moved. §34.11 anchors on **combined-CN Record Potential Ratio** rather than on
>   single-lift PP, because the approved endgame target is an elite three-lift
>   total. Both tables in this section remain outputs and remain stale.

**[OBSOLETE PLAYER MODEL — "meets/week" is no longer a CN variable]** For the
**reference engaged player** (~5 days/week, ~5 meets/week, ~70% daily completion,
~60% Training Energy use):

| Source | Share | EV/week per lift |
|---|---|---|
| Meets | **0%** — channel removed; was 65% | — *(was 9.430)* |
| Dailies | **0%** — channel **removed** by §34.2; was 20% | — *(was 2.902)* |
| AFK, as a side channel | **0%** — absorbed into station training; was 15% | — *(was 2.176)* |
| **Gym station training** | **100%** (§34.2) | **up to 28.00 EV/week across all three lifts** -- 4.00 EV/day account-wide, §34.4 |

~~**[FROZEN] hierarchy: MEETS > DAILIES > AFK.**~~ **[OBSOLETE]** — meets are no
longer a CN channel, so the hierarchy is void. The percentages were always a
balancing target, not a guarantee for any individual player.

### 29.7 Daily architecture

> **✅ RESOLVED BY SECTION 34.2 — the "Compete" pillar awards no Competition
> Number.** The three options once open here are moot. **Daily quests are not a CN
> source**, so whether completing Compete requires entering a meet no longer
> affects CN at all, and the section 33.3 loophole it threatened cannot open.
>
> Compete awards placement, prestige and economy rewards. Its former CN allocation
> is **not relocated to the Develop pillar** -- it is removed. The only CN channel
> is gym-station training (§34.2, §34.3).
>
> The **Daily Set completion** bonus survives as a daily reward and **loses its CN
> component** for the same reason. It remains a consistency reward for engaging all
> three pillars, paid in other currencies.

**[FROZEN]** Three daily pillars, three different reward types:

| Daily | Awards |
|---|---|
| **Compete** | ~~CN progression~~ — **no CN** (§34.2). Placement, prestige, economy |
| **Develop** | Technique / Muscle |
| **World** | economy (money, items) |
| **Daily Set completion** | ~~additional CN consistency bonus~~ — **no CN** (§34.2). A consistency reward in other currencies |

**[FROZEN] Cooking and trading never grant Squat/Bench/Deadlift CN directly.**
The Set bonus is a *consistency* reward for engaging all three pillars, not
economy activity converting into strength.

**[FROZEN] Daily Set distribution:** awarded to all three lifts of the **currently
active build**, **one claim per account per day**. Build slots cannot duplicate it;
switching build before claiming only chooses the destination, and because R2 makes
the gain PP-equivalent regardless of class, that choice is cosmetic.

### 29.8 AFK progression and Training Energy

> **⚠ SUPERSEDED AS A CN THROTTLE BY SECTION 34. THE WHOLE OF §29.8 IS NOW
> HISTORICAL.** Two approved decisions remove its job:
>
> - **§34.1 decision 2** -- the CN limit is a **4.00 EV account-wide daily cap**,
>   not a minute allowance.
> - **§34.3** -- there is **no hard daily training-hour limit at all**. A player may
>   stand at the station indefinitely. What runs out is EV, not time.
>
> A 120-minute allowance and "no hour limit" cannot both be live rules, so the
> allowance is the one that goes. Within-day pacing is handled instead by the
> per-lift diminishing-efficiency function `H(t)` (§34.4), which **slows** a lift
> rather than stopping it.
>
> **The field is still persisted in the player schema**, so its fate is an open
> implementation decision: retire it in a later schema version, or give it a
> different job. **[TBD]** -- §34.13 item 8. Do **not** quietly repurpose it.
>
> Everything below is retained unchanged as the record of the original model. The
> one rule that is **not** superseded is called out in place.

**[FROZEN — HISTORICAL]** Training Energy limits **passive AFK CN only**.

**[FROZEN — STILL LIVE] Training Energy never limits Muscle.** Muscle progresses
independently and continues when Training Energy is empty. This rule survives
§34's supersession intact, whatever becomes of the resource itself.

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
> **Section 34 did NOT resolve this, and the 4.00 EV daily cap must not be
> confused with it.** They are different scopes doing different jobs:
>
> | | Scope | Period | Quantity |
> |---|---|---|---|
> | **§34.1 daily CN cap** | whole account | per day | **4.00 EV** |
> | **These three budgets** | one per lift | per week | **9.43 EV** each |
>
> The daily cap bounds how much CN a day can produce. These pools were built to
> bound how hard one lift could be farmed within a week, and that is still
> attached to nothing. **[TBD]** -- §34.13 item 7. Note also that the "rehome to
> training" option below refers to a Training Energy overlap that §34 has since
> superseded (§29.8), so only two of the three options there are still live as
> written.
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
>
> **§34.11 now carries the approved pacing projection, and it is anchored
> differently.** This section measures single-lift **Progression Proximity**;
> §34.11 measures **combined-CN Record Potential Ratio** against the class total
> benchmark, because the approved endgame target is an elite three-lift total
> rather than any one lift. Both tables below remain outputs of the old channel mix
> and remain stale. Use §34.11 for pacing; use this section for the *shape* of the
> curve and for the class-spread reasoning, which are unaffected.

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
> §29.6 and §33.9 are settled -- **both now are** (§34.2, §34.4), so this table is
> ready to be re-authored. Three things to carry into the replacement:
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
>
> **§34 supplies the replacement independent variable: station hours per day.** It
> also bounds the spread by construction rather than by a logarithmic brake -- the
> **4.00 EV account-wide daily cap** (§34.1) means the most dedicated player cannot
> exceed **1.00x** the capped rate however long they stand there, and §34.4's
> accrual curve sets the rest of the table: one hour is 0.25x a full day, two hours
> 0.50x, four hours 0.85x. "Meet spammer" has no successor, because meets no longer
> produce CN at all. This table still needs re-authoring on that key.

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
| **`BaseProgressRate`** | solved from an **assumed** success-probability curve; the single largest uncertainty in the model. **Re-solved against the single-channel model: candidate 0.01113418, [PROVISIONAL]** (§34.11) |
| ~~Failure credit (0.20)~~ | **[OBSOLETE]** — superseded by section 33.6. A failed attempt is worth zero. The original note, retained for the record: sensitivity testing showed 0.30 inverts optimal play toward reckless spam; keep <= 0.20. **The code constant `ProgressionConfig.FailureCredit` has been removed** (§33.12 step 2) |
| I-A intensity factors | depend on real pass rates. **No live system uses them**: meets award no CN (§33.3) and station training is time-based, not intensity-scored (§34.4). Retained for any future relative-intensity EV channel; nothing to calibrate until one exists |
| `h` = 0.75, `m` = 5 | `m` = 6 is the lever for a harsher elite grind; affects only players past PP 110%. **Unaffected by section 33** — the Hill curve still reads `PP = CN / ProgressionReference` |
| Competition Budget capacity, regen, `k` | ~~depends on observed meets/week~~ — **[TBD]** whether this system survives at all (§29.9) |
| Training Energy max and regen | ~~depends on observed AFK behaviour~~ — **[SUPERSEDED as a CN throttle]** by §34.1 decision 2 and §34.3. Still persisted; retire it or re-task it. **[TBD]** (§29.8, §34.13 item 8) |
| ~~Daily EV values~~ | **[OBSOLETE]** — daily quests award no CN (§34.2). Nothing left to calibrate |
| ~~65/20/15 source split~~ | **[OBSOLETE]** — a target, not a guarantee, and now a target for a channel mix that no longer exists. **Requires recalibration** (§29.6) |
| **Scale Challenge Ratio curve and cap** | **[TBD]** — new in section 33.4. No values exist |
| **Station training EV rates** | **[PROVISIONAL]** — `BaseRate` 1.00 EV/hour, `FullRateHours` 2.00, `K` 2.00, `DailyCapEV` 4.00. Section 34.4. Not validated in a running game |
| **AFK technique rates** | **[PROVISIONAL]** — 2.00 raw points/hour, 6.00 raw/day account-wide. Section 34.7 |
| **Meet technique rates** | **[PROVISIONAL]** — 4.00 raw per successful attempt, 60.00 raw/day account-wide. **Blocked on meet duration, which does not exist** (section 34.8) |
| **Cosmetic currency rate and cap** | **[TBD]** — new in section 34.9. No values exist |
| ~~**Starting Competition Scale**~~ | **DECIDED, NOT A CONSTANT TO TUNE** — unproven, stored as `0` (section 33.8). Implemented in schema v4 |

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
> `ProgressionConfig.FailureCredit = 0.20` has been removed (§33.12 step 2).

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

> **The pipeline above is still correct; only its trigger moved** — see §33.9 and
> §34.2. **Three entries do not carry over**, because station training is
> time-based rather than attempt-based (§34.4):
>
> - **Attempt intensity** -- there is no attempt. The station's analogue is the
>   per-lift diminishing-efficiency function `H(t)`.
> - **Success/failure** -- an undefined concept for training, and deliberately so
>   (§33.9). Nothing is passed or failed at a station.
> - **Competition Budget** -- **[TBD]** (§29.9, §34.13 item 7).
>
> **Raw EV, Progression Percentage, the Hill soft cap and `CompetitionNumberReward`
> all carry over unchanged.** That is the half of the pipeline worth keeping.

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
> **§34 is authoritative over this section on the training channel.** This section
> established that training is where CN comes from and left *how much* open.
> §34 answers it, and also narrows the channel further than this section did:
> dailies and AFK-as-a-side-channel are gone too, and **gym-station training is the
> only CN source**. Where §33.9 and §34.2 differ, **§34 wins**.
>
> **Do NOT implement these systems merely because they are documented here.** The
> Scale challenge curve and cap and the fate of the Competition Budget are still
> **[TBD]** and must be approved before implementation. The starting Scale and the
> migration backfill are **decided and implemented** (schema v4), and the training
> EV rates are now **[PROVISIONAL]** in §34.4. See §33.11 and §33.12.

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
| **Competition Number (CN)** | the strength the character has **developed through training**, in kg | **gym-station training only** — §34.2 | **physical difficulty**, attempt selection, display, Progression Proximity |
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

> **Implemented.** The code constant `ProgressionConfig.FailureCredit` has been
> **removed**, together with the dev-probe assertions that depended on it
> (§33.12 step 2). It was read by nothing in production, so no gameplay path
> changed.
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

#### The stored representation — DECIDED AND IMPLEMENTED

**[FROZEN] A Scale is a weight number only.** One number per lift, in kilograms.
No meet, class, date or other proof metadata is stored. If a future feature wants
to show a player *where* a Scale came from, that is a separate record and a
separate decision; it is not needed to satisfy §33.7.

**[FROZEN] UNPROVEN is stored as `0`.** A lift that has never been successfully
made in an eligible meet holds exactly `0`, exposed as
`PlayerProfileSchema.UNPROVEN_SCALE`.

`0` is safe as a sentinel because a Scale is a weight that was actually loaded on
a bar and lifted, and 0 kg is not a liftable weight, so it can never collide with
a legitimate value. Any value above `0` is a real achievement.

A sentinel is used rather than an absent field because a DataStore stores JSON and
a Lua table cannot hold a nil value — `{ Squat = nil }` *is* `{}`. After a save and
load, "absent" and "never written" are indistinguishable, so a fixed-shape record
with an explicit `0` is the only representation that survives the round trip.

> **`0` IS NOT A PROVEN 0 KG LIFT, AND IT IS NOT 25 KG.** §33.4 may eventually
> have the Scale challenge modifier substitute 25 kg when no Scale exists. That
> substitution would belong to the calculation and **must never be written back to
> storage** — writing it would fabricate a successful meet attempt. A fallback is
> not an achievement, not a record, and not a persisted Scale.

**[FROZEN] New players and migrated v3 players both start UNPROVEN.**

| | Competition Number | Competition Scale |
|---|---|---|
| **New lifter** | 25 kg per lift, from `StartingValuesConfig` | `0` — unproven |
| **Migrated v3 lifter** | whatever they trained, preserved exactly | `0` — unproven |

A migrating player's Scale is **never** inferred from their Competition Number.
Someone who trained a 182.5 kg squat and never competed has proven nothing, and
copying the trained number would hand them an achievement they did not earn and
silently remove a mechanic from their account. No profile in the DataStore
contains a record of a successful meet attempt, because no meet system has ever
existed, so there is no data from which a Scale could honestly be derived.

#### Class scoping is DEFERRED, and that deferral has a deadline

**[FROZEN] Competition Scale is stored flat today, mirroring Competition Number**,
because the Weight-Class Build Slot system does not exist and §33.8 above forbids
inventing a `builds` map ahead of it. The two fields sit together under one note in
the schema and migrate into `builds[classKey]` together or not at all.

Keying Scale by weight class while CN stays flat was considered and **rejected**:
it would give the profile two different answers to "which build is this", and the
only class key derivable today is the player's *current* bodyweight class, whereas
§29.11 makes the authoritative class for a meet the **weigh-in snapshot**. Writing
under the wrong key would be a silent, permanent error.

> **⚠ CLASS SCOPING MUST EXIST BEFORE ANY MEET AWARDS SCALE**
>
> The flat shape does not *enforce* the rule that a Scale proven in one class is
> not proof in another. That confusion is **unreachable today**, because nothing
> writes Scale at all — but it becomes reachable the moment meets can raise it.
>
> **§33.12 step 7 is blocked on this.** The meet wiring must key the raise off the
> meet's weigh-in snapshot (§29.11), never off current bodyweight, and the
> weight-class build system must exist by then. This is a hard prerequisite, not a
> preference.

> **Implemented in schema version 4.** See §33.12 step 3.


### 33.9 Where Competition Number now comes from

> **✅ ANSWERED IN FULL BY SECTION 34. Read §34 for the live rules; this subsection
> is now the bridge to it.** The two things it left open are both settled:
>
> | This section said | §34 says |
> |---|---|
> | Training is the **primary** CN source; dailies and AFK remain sources on their existing terms | Gym-station training is the **only** CN source. Dailies, logins and purchases award **none** (§34.2) |
> | The training EV rates are **[TBD]** and no value exists | `BaseRate` 1.00 EV/hour under `H(t)`, capped at 4.00 EV/day account-wide -- **[PROVISIONAL]** (§34.4) |

**[FROZEN] Training is the source of Competition Number.** Section 12's training
matrix is unchanged and still correct — Competition Squat builds the Squat CN,
Competition Bench builds the Bench CN, Competition Deadlift builds the Deadlift
CN, and the variations build technique stats.

**[FINAL] It is the *only* source**, and it is delivered by Auto-Train at an
eligible gym training station on one manually selected lift (§34.2, §34.3).

**[PROVISIONAL] The training EV rates now exist** — §34.4. They are balancing
candidates, not validated balance, and must be implemented as named configurable
constants.

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
equivalent of the meet-attempt converter that was never built.

> **Implemented in checkpoint 5B.5 — see §34.12, "The training progression
> award".** The write lives on `PlayerDataService` as
> `awardTrainingProgression(player, lift, elapsedSeconds)`. It takes observed
> station **seconds**, not EV and not kilograms, and derives both itself. The
> earlier reserved name `awardProgression(player, lift, effectiveEV)` was
> **not** built: accepting EV from a caller would let it skip `H(t)` and the
> daily allowance.

Two inputs did **not** carry over cleanly. One is now resolved:

- **Success / failure -- RESOLVED, and the answer is that there is no such notion.**
  Station training is **time-based** (§34.4): an hour at the station yields
  `BaseRate x H(t)` EV and there is nothing to pass or fail. A failed *training
  set* is not a concept this design has, and none should be invented. Success and
  failure belong to **meets**, where failure earns zero (§33.6, §34.8).
- **Competition Budget -- RESOLVED FOR TRAINING: station EV bypasses it.**
  Approved as checkpoint 5B.5 decision A (§34.12). Training neither spends the
  three per-lift pools nor is scaled by them; the 4.00 EV daily allowance is its
  only throttle. The `CompetitionNumberReward` engine gained a budget-free
  entry point, `calculateTrainingAward`, for this; the budgeted `calculate` is
  unchanged. **The fate of the budget itself is still [TBD]** (§29.9, §33.10,
  §34.13 item 7) — this decision says only that training does not use it.

**[FROZEN] `BaseProgressRate` remains a single configurable constant** (§29.15),
so rescaling stays a one-line change. **It has been re-solved** against the
single-channel model: candidate **0.01113418**, **[PROVISIONAL]** (§34.11).


### 33.10 What this leaves unresolved in section 29

Three section 29 systems are left without a settled role. Each is marked in place;
collected here so the list is in one spot.

| System | Where | Status |
|---|---|---|
| **The three Competition Budgets** | §29.9 | **[TBD]** — the system exists to throttle meet-derived CN and now throttles nothing. Rehome to training, repoint at Scale, or retire. Note that the consumption rule "proportional to the CN actually awarded" does **not** survive being repointed at Scale, because a Scale increase is a kilogram jump and not an EV amount. The pools are already persisted, so leaving them attached to nothing is the one outcome to avoid. |
| **Training Energy scope** | §29.8 | **SUPERSEDED as a CN throttle, FATE [TBD]** — §34.1 decision 2 replaces it with a 4.00 EV account-wide daily cap, and §34.3 removes any hard training-hour limit. The 120-minute allowance is therefore not a live rule. The **field is still persisted**, so it must be retired in a later schema version or given a different job — §34.13 item 8. Its **[FROZEN]** rule that it never limits Muscle is unaffected. |
| **Channel distribution and everything derived from it** | §29.6, §29.13, §29.14 | **RESOLVED by §34.2** — there is one channel at 100%, so there is no distribution to balance. `BaseProgressRate` has been re-solved against it (candidate 0.01113418, §34.11) and §34.11 carries the approved pacing projection. The §29.13 and §29.14 **tables remain stale outputs** and still need re-authoring; the pacing *target* survives in a re-anchored form. |

**Unchanged and still fully authoritative**, for the avoidance of doubt: §29.1,
§29.2, §29.2b, §29.3, §29.4, §29.11, §29.12, and the whole of §31 and §32 except
the two items marked in place. **§34 does not disturb any of them** — it specifies
the EV producer only.

**Two further §29 systems were superseded by §34 after this list was written**, and
are marked in place: §29.5's channel table and §29.7's "Compete" pillar CN award,
both removed by §34.2.


### 33.11 Open design questions — [TBD]

Collected so none is lost. None of these should be answered by implementation
choice. **Section 34 closed items 5, 7 and 8 and opened nine more of its own --
see §34.13.**

1. **What stops maximum-risk meet strategy?** With failures costing zero (§33.6)
   and Scale being a maximum (§33.7), the optimal meet strategy is to attempt the
   heaviest weight with any chance of succeeding. This **inverts** §29.5's frozen
   note that conservative play should out-earn aggressive play. Existing brakes:
   three attempts per lift, the no-lowering rule, bomb-out consequences, entry
   costs, and placement money. Whether those suffice, or whether Scale needs a
   per-meet increment cap, is undecided.
2. **The Scale challenge curve, its cap, and what it modifies** (§33.4). Including
   its behaviour at ratio <= 1.00 and with an absent Scale.
3. ~~**The starting Competition Scale**~~ — **DECIDED** (§33.8): unproven, stored
   as `0`. Implemented in schema v4.
4. ~~**The migration backfill for existing players**~~ — **DECIDED** (§33.8):
   unproven, never inferred from Competition Number. Implemented in schema v4.
5. ~~**Training EV rates**, and the replacement channel distribution they belong
   to~~ — **DECIDED** (§34.2, §34.4). One channel at 100%; `BaseRate` 1.00 EV/hour
   under `H(t)`, 4.00 EV/day account-wide. **[PROVISIONAL]** values, not [TBD].
6. **The fate of the Competition Budget** (§29.9, §33.10).
7. ~~**Training Energy's scope**~~ — **DECIDED as a throttle** (§34.1 decision 2,
   §34.3): it no longer limits CN, and there is no hard training-hour limit. Its
   **fate as a persisted field remains [TBD]** — §34.13 item 8.
8. ~~**The "Compete" daily pillar**~~ — **DECIDED** (§34.2): it awards **no CN**, and
   neither does the Daily Set completion bonus. The question of whether completing
   it requires a meet no longer affects CN.
9. **What "eligible meet" includes** for the purpose of raising Scale (§33.7).
10. ~~**What a stored Scale records**~~ — **DECIDED** (§33.8): a per-lift weight
    number only, no proof metadata. Implemented in schema v4.
11. **Scale across weight classes.** CN translates between classes by RP
    Preservation (§29.11). Translating Scale would mean inventing a lift that never
    happened; not translating it means a class change resets proven strength.
    Undecided, and **blocks §33.12 step 7** — see the class-scoping deadline in
    §33.8.
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

**Steps 1 to 4 and 5A are done, and step 5B is in progress. Steps 6 onward are
not implemented.** The original note here
read "nothing in this section is implemented", which was true when it was written
and is no longer. The step table below is the current status.

Current repository reality, verified:

- There is **no meet system**. The only meet code is two pure modules,
  `AttemptRules` and `MeetTotal`, neither of which is used by any live system. So
  **no production code has ever awarded Competition Number for a meet**, and
  §33.3 requires no code change to become true.
- `CompetitionNumberReward` has **zero** production callers. It is exercised only
  by a dev probe that defaults to disabled.
- `PlayerDataService` exposes **one** Competition Number writer,
  `awardTrainingProgression` (checkpoint 5B.5), which takes station seconds and
  derives EV and kilograms itself. Its only caller is the gym training rack of
  5B.6, and there is still no arbitrary-kilogram writer.
- **Competition Scale is STORED and RAISABLE, but unreachable from gameplay**
  (schema version 4, steps 3 and 4). The field, its type, the `UNPROVEN_SCALE`
  sentinel, the v3 to v4 migration, two read accessors and the monotone
  `raiseCompetitionScale` all exist. **Nothing calls the raise** — it is internal
  to `ProfileOperations`, which only the gateway and a disabled dev probe require,
  and `PlayerDataService` exposes no Scale writer at all. So every Competition
  Scale in existence is still `0`.
- `ProgressionConfig.FailureCredit = 0.20` has been **removed**, with the dev-probe
  assertions that read it (step 2 below). It was read by nothing in production.
- Physical difficulty already divides by Competition Number, so §33.4's frozen
  half is **already how the game behaves**.

Suggested sequencing, smallest safe steps first. Each leaves the game playable and
none should begin without the decisions it depends on:

| # | Step | Status / blocked on |
|---|---|---|
| 1 | This documentation revision | **DONE** |
| 2 | Remove `FailureCredit` from config together with the probe section that asserts it | **DONE** — constant removed from `ProgressionConfig`, 7 obsolete probe checks removed, two stale comments in `CompetitionBudget` and `ProfileOperations` corrected. No production path touched |
| 3 | Add Competition Scale to the player schema as a stored but unread field, with a migration | **DONE** — schema v4: `competitionScale` per lift, `UNPROVEN_SCALE = 0`, `migrations[3]`, two read accessors, no writer. Validated in memory and against a real DataStore on a disposable key |
| 4 | A pure, monotone `raiseCompetitionScale` operation, with no callers | **DONE** — on `ProfileOperations`, internal, zero production callers. See the operation contract below |
| 5A | **Define** the training CN channel | **DONE** — approved and documented as **section 34**. The §33.9 rates and the §29.6 distribution that blocked this are both resolved |
| 5B | **Implement** the training CN channel | **IN PROGRESS** — 5B.1 to 5B.5 done; 5B.6 implemented (revised), awaiting Studio verification. Checkpoints in §34.14 |
| 6 | Implement the Scale challenge modifier | §33.4 curve, cap and target |
| 7 | Wire meets to raise Scale | a meet system existing; §33.7 eligibility; **and the weight-class build system, per the class-scoping deadline in §33.8** |
| 8 | Resolve the Competition Budget | §29.9 |

> Step 7 must be built on `MeetTotal.bestSuccessful`, which already computes
> "the heaviest successful attempt on one lift" — the exact input §33.7 needs.
> There is no reason to write a second one.

#### The Competition Scale raise operation — step 4, implemented

```
ProfileOperations.raiseCompetitionScale(data, lift, provenKg)
    --> (outcome, resultingScaleKg?)
```

Pure and deterministic: no clock, no `Player`, no ProfileStore, no randomness, and
no timestamp parameter. It implements §33.7's `New Scale = max(Old Scale, proven)`
and nothing else.

| Outcome | When | Second return |
|---|---|---|
| `"Raised"` | valid input, strictly heavier than stored | the new Scale |
| `"Unchanged"` | valid input, at or below stored | the Scale that still stands |
| `"Rejected"` | input or stored value unusable; **nothing is written** | `nil` |

**`"Unchanged"` is a success, not a failure.** A lifter opening at 150 kg who has
already proven 180 kg made a legal lift that simply does not move their best. A
meet handler needs to tell that apart from a malformed request — one is routine,
the other is a bug worth alerting on.

Rejected inputs: an unknown lift, zero (the `UNPROVEN` sentinel, and no bar is
loaded to 0 kg), negatives, `NaN`, either infinity, and non-numbers. A **corrupt
stored Scale is refused rather than repaired**, because the operation cannot know
whether the corrupt value was higher than the incoming proof; repair belongs to
`migrations[3]`, which runs on every load.

**[FROZEN] SECURITY RESTRICTION — it does not verify that a meet happened.**

It receives a kilogram number and a lift name. It cannot know whether that weight
was ever on a bar, whether the attempt was judged a good lift, whether the meet was
eligible, or which weight class the lifter was in. **It is a low-level data
transformation, not proof of an achievement.**

Everything it does not check is the caller's responsibility, and only one kind of
caller may ever exist: a **server-authoritative meet-result handler** that has
already established all four of —

1. the attempt was taken in a meet this server was running;
2. the attempt was judged a **GOOD LIFT** (§33.6 — a failure may never raise Scale
   at any weight). `MeetTotal.bestSuccessful` is the correct source because it
   filters on `result == "GoodLift"`, so a failed attempt cannot reach the raise
   through it;
3. the meet was **eligible** under §33.7 — Solo and Official both qualify, what
   else does is **[TBD]**;
4. **the weight class matches the build being credited** — see the class-scoping
   prerequisite in §33.8.

**[FROZEN] No client, RemoteEvent, dev trigger or existing gameplay system may
reach it.** A client-supplied weight arriving here would let a player write their
own proven strength. It is deliberately **not exposed on `PlayerDataService`**, so
the gateway every gameplay system actually uses has no path to it, and
`ProfileOperations` lives in `ServerScriptService` and creates no remotes.

**[FROZEN] It must keep zero production callers until class-scoped build storage
exists.** Flat per-lift storage cannot express "proven in the 83 kg class", so a
raise written today would credit the player's only build whatever class they
weighed in at. That is unreachable while nothing calls it, and becomes reachable
the moment a meet does — which is why step 7 is gated on §33.8.


## 34. Training, AFK Gym Stations and Technique Progression — APPROVED STEP 5 DESIGN

> **This section is authoritative where it disagrees with sections 3, 11, 12, 28,
> 29 or 33.** It answers the questions section 33 deliberately left open: where
> training Competition Number comes from, how much of it there is, how technique
> is trained, and what the station does once a daily allowance is exhausted.
>
> **It does not supersede section 29's mathematics.** The 21 frozen Progression
> References (§29.2b), `PP = CN / ProgressionReference` (§29.2), the Hill soft cap
> (§29.3), R2 reference normalization (§29.4) and RP Preservation on class change
> (§29.11) are all **unchanged**. Only the EV **producer** is specified here.
>
> **Status discipline — read this before implementing anything below.** Every rule
> carries one of three markers:
>
> | Marker | Meaning |
> |---|---|
> | **[FINAL]** | Approved. Implement as written. Do not re-open without a decision. |
> | **[PROVISIONAL]** | A balancing candidate. Not validated in a running game, and it **will** move. Implement only as a named, configurable constant — never inlined, never assumed stable. |
> | **[TBD]** | No approved value exists. **Must not be implemented.** |
>
> A [PROVISIONAL] number is safe to build *against* and unsafe to build *into*.
>
> These map onto the document-wide legend in §29: **[FINAL] carries the force of
> [FROZEN]** and **[PROVISIONAL] carries the force of [TUNABLE]**. The distinct
> words exist to mark which review approved a rule, not to create a new tier.
>
> **A [FINAL] heading does not freeze the numbers under it.** Where a mechanic is
> approved but its constants are not — which is most of this section — the
> heading says so and each figure is marked in place.

### 34.1 The approved decision set — [FINAL]

These five decisions override every earlier proposal in this document, including
proposals made during the section 29 and section 33 audits.

| # | Decision | Overrides |
|---|---|---|
| 1 | **Auto-Train CN efficiency is 100%.** There is **no** AFK discount — not 55%, not any other figure. | the proposed AFK efficiency discount |
| 2 | **The daily CN progression cap is 4.00 EV, shared across the whole account.** | §29.8's 120-minute Training Energy allowance as a CN throttle |
| 3 | **There is no per-lift EV cap.** The proposed 4.20 per-lift cap is **removed**; the account-wide cap is the only authority. | the proposed dual-cap model |
| 4 | **Squat and Bench AFK technique splits 80% primary / 20% secondary.** Deliberate, even though the secondary develops slowly. | the proposed 70/30 split |
| 5 | **The configured 74 kg total-record benchmark stays at 891.5 kg.** | the proposal to adjust it to close the pacing window |

**Decision 1 is the one with teeth.** A discount below roughly 95% would make the
4.00 EV daily cap **unreachable**, because efficiency multiplies the hourly rate
while the cap stays fixed: at 55% a full day of training on one lift tops out
around 2.3 EV. A discount would therefore not *slow* the CN economy, it would
**halve** it and turn the cap into decoration. Auto-Train at a station **is** the
intended training system, not a lesser substitute for a faster manual one, so it
runs at full rate.

**Decision 3 removes a cap that could never have fired anyway.** With one lift per
station and an account cap of 4.00 EV, a per-lift ceiling of 4.20 EV is
unreachable by construction. Keeping it would have left a constant in the config
that no test could ever exercise.

**Decision 5 is a rule about process, not about one number.** Record values are
balancing *inputs*, not outputs. They are never adjusted to make a progression
target land where a simulation would prefer. The consequence — one weight class
sitting outside the pacing window — is documented honestly in §34.11 instead of
being tuned away.

### 34.2 Competition Number has exactly one source — [FINAL]

**[FINAL]** Competition Number is awarded **only** by training at an eligible gym
training station.

**[FINAL]** Specifically prohibited as CN sources:

- **meets** of every type — already absolute under §33.3
- **daily quests**, including the Compete pillar and the Daily Set completion bonus
- **login rewards** and login streaks
- **purchases** of any kind, Robux or in-game currency
- cooking, trading, jobs, and every other economy activity

> **This closes three open questions at once.**
>
> - **§29.7's "Compete" pillar [TBD] is resolved: it awards no CN.** The three ways
>   out listed there are moot. Compete awards placement, prestige and economy
>   rewards; its former CN allocation is not relocated, it is removed.
> - **§29.5's Compete Daily (0.3948 EV per lift) and Daily Set (0.1974 EV per lift)
>   rows are [OBSOLETE].** Both were quest rewards.
> - **§29.6's replacement channel distribution is resolved trivially.** There is no
>   distribution left to balance. Training is not merely the dominant channel; it is
>   the **only** channel, at 100% of CN.

**[FINAL] The Daily Set completion bonus survives as a daily reward and loses its
CN component.** §29.7's frozen rule that cooking and trading never grant CN
directly is unaffected, and is now a special case of the general rule above.

**[FINAL] No offline progression.** CN accrues only while the player is connected
and at the station. A disconnect stops accrual; it does not bank, refund or
back-pay it. That is what makes the station a place in the world rather than an
idle timer.

### 34.3 The gym training station — [FINAL]

| Rule | Detail |
|---|---|
| Where | **An eligible gym training rack only.** Every rack is a **universal** station (§34.12, checkpoint 5B.6). Auto-Train runs nowhere else in the world. |
| Offline | **Never.** §34.2. |
| Daily training-hour limit | **None.** A player may stand at the station indefinitely. The limits are on **EV and technique points**, not on hours. |
| Selection | The player holds E at a rack and **manually selects** in the Training Selection menu either **Competition Number for ONE lift** (Squat, Bench or Deadlift) or **Technique** for one lift with a primary stat (§34.7). |
| What is trained | **Only** what is selected: the selected lift's CN, or (from 5B.7) the selected technique stats. |
| Automatic rotation | **Never.** The station does not rotate between lifts or change mode on its own, at the cap, at a daily reset, or on any other trigger. |
| End of CN for the day | When the **account** reaches 4.00 EV. |
| What happens then | **Free players: training STOPS.** No more CN, no technique, no change of mode or lift. The rack stays occupied and shows "Daily CN Limit Reached — Training Stopped." The player may **manually** select Technique to keep training. *(Revised in 5B.6: the earlier automatic switch to technique is now a **future Game Pass** feature only, §34.12.)* |
| At the next daily reset | CN can be earned again, but a session stopped at the cap **waits for the player to press Start**, and a manually selected technique mode is **never overridden**. *(Revised in 5B.6: CN no longer resumes automatically.)* |
| Changing selection | Permitted at any time, manually, by the player, through the rack menu. |
| What a change never does | **Changing lifts, technique stats, stations or servers never resets either daily allowance.** §34.12. |
| Accounting | **Server-authoritative** timestamps and allowance accounting. §34.12. |

**[FINAL] "No automatic rotation" and "no hard hour limit" are a deliberate pair.**
Removing the hour limit is what makes a long session worth standing through;
forbidding automatic rotation is what keeps a long session a **choice** rather
than a schedule the game runs on the player's behalf. Together they put the whole
CN allocation decision in the player's hands, which is the point of §34.10.

### 34.4 Per-lift diminishing efficiency — H(t) — [PROVISIONAL]

**[PROVISIONAL]** Within a single day, a lift's CN efficiency decays with the
hours already spent **on that lift** today:

```
H(t) = 1 / (1 + max(0, t - FullRateHours) / K)

    t              = hours of station CN training on THIS lift today
    FullRateHours  = 2.00      full efficiency for the first two hours
    K              = 2.00      harmonic softness
    BaseRate       = 1.00      EV per hour at H = 1
    DailyCapEV     = 4.00      account-wide (section 34.1, decision 2)
```

Cumulative EV on one lift is the integral of that rate:

```
EV(t) = BaseRate * t                                     for t <= 2
EV(t) = BaseRate * (2 + K * ln(1 + (t - 2) / K))         for t >  2
```

**[PROVISIONAL] Time for a single lift to exhaust the 4.00 EV daily cap:**

```
t* = 2 + K * (e^((DailyCapEV / BaseRate - 2) / K) - 1)
   = 2 + 2 * (e - 1)
   = 5.4366 hours
```

| Hour | H(t) | EV this hour | Cumulative EV | % of the daily cap |
|---|---|---|---|---|
| 1 | 1.0000 | 1.0000 | 1.0000 | 25.0% |
| 2 | 1.0000 | 1.0000 | 2.0000 | **50.0%** |
| 3 | 0.6667 | 0.8109 | 2.8109 | 70.3% |
| 4 | 0.5000 | 0.5754 | 3.3863 | 84.7% |
| 5 | 0.4000 | 0.4463 | 3.8326 | 95.8% |
| 5.4366 | 0.3679 | 0.1674 | **4.0000** | **100.0%** |

**The shape is the useful part, and it is strongly front-loaded.** The first two
hours deliver **half** the daily cap. Four hours deliver **84.7%**. The final
0.44 hours deliver **4.2%**. A player with one hour to spare collects a quarter of
a full day's progression; a player who stands there the whole 5.44 hours is
collecting a thin tail. That is the intended relationship between session length
and reward, and it is why no hard hour limit is needed.

> **Why the harmonic form rather than an exponential or a cliff.** It is the same
> model as §29.9's Competition Budget overflow, for the same reason: it never
> hard-zeroes, so a player at the keyboard is never told their time is worth
> literally nothing, while the marginal rate still falls fast enough — 36.8% of
> the opening rate by the time the cap is reached — that grinding one lift all day
> is poor value. Reusing a shape already proven elsewhere in this document is
> deliberate.

**[FINAL] H(t) is scoped per lift and the cap is scoped per account.** These are
different scopes on purpose, and §34.10 is the consequence.

**[PROVISIONAL] `FullRateHours`, `K` and `BaseRate` are candidates, not settled
balance.** Note in particular that `BaseRate = 1.00 EV/hour` is **3.86x** §29.5's
old AFK figure of 0.2591 EV/hour. The old rate was calibrated for a background
trickle worth 15% of CN and this one carries 100% of it, so the two are not
comparable and the old figure is **[OBSOLETE]** rather than merely retuned.

### 34.5 The station state machine

> **Revised in checkpoint 5B.6.** The original machine switched to technique
> **automatically** at the CN cap and back to CN at the reset. For **free**
> players that is replaced: training **stops** at the cap and every change of
> mode is **manual**. The automatic CN-to-technique switch survives only as a
> **future Game Pass** feature (§34.12) and is not implemented.

**Two kinds of state, kept apart on purpose.** The **allowances** — EV and
technique spent today, per-lift hours — are persisted, day-keyed account
counters (§34.12); they are never session state, so a server change, a lift
switch or a rejoin can neither lose nor duplicate them. The **rack session** —
which rack, which selection, whether it is stopped — lives only while the player
holds the rack (5B.6 decision 10) and is never trusted for an amount.

```
      player holds E at a free rack, server checks presence
                             |
                             v
    +-------------------- SELECTING --------------------+
    |  menu open, rack reserved, nothing earned         |
    +---------------------------------------------------+
           |  Start: CN, one lift        |  Start: Technique, lift + primary
           v                             v
    +---- TRAINING: CN ----+     +---- TRAINING: TECHNIQUE -----------+
    |  SELECTED lift only  |     |  Squat / Bench: 80% primary,       |
    |  BaseRate * H(t)     |     |    20% the other stat              |
    |  toward 4.00 EV      |     |  Deadlift: 100% Lockout            |
    |  ACCOUNT cap         |     |  toward 6.00 raw/day ACCOUNT cap   |
    +----------------------+     |  (earns from 5B.7; 5B.6 shows      |
           |                     |   "available in Step 5B.7")        |
  account EV reaches 4.00        +------------------------------------+
           |
           v
    +------------------ STOPPED AT CN CAP --------------------+
    |  FREE players: no CN, no technique, mode unchanged      |
    |  "Daily CN Limit Reached — Training Stopped."           |
    |  rack stays occupied until the player leaves or stops   |
    +---------------------------------------------------------+
           |  the player MANUALLY presses Start
           |  (Technique any time; CN again after the UTC reset)
           v
       TRAINING with the newly chosen selection
```

| Transition | Trigger | What carries over |
|---|---|---|
| Selecting to Training | the player presses Start | nothing is credited for the time spent choosing |
| CN to Stopped | account CN EV reaches **4.00** | the selection is left exactly as chosen; nothing switches |
| Stopped to Training | the player presses Start: Technique at any time, CN once the UTC reset has restored the allowance | per-lift hours and both allowances, unchanged |
| any selection to another | the player changes lift, mode or primary stat | the old selection is credited up to now; **nothing resets** |
| leaving | Stop, death, respawn, leaving range, disconnect, or the server changes | the rack session ends; the persisted counters are untouched |

**[FINAL] CN eligibility is derived, never stored.** The rack reads the
account's spent-today counter and computes whether CN can be earned. There is no
stored "capped" field and no event that can be missed:

| Case | Behaviour |
|---|---|
| The player changes the selected CN lift **mid-session** | The target changes immediately. **Neither allowance resets.** H(t) for the newly selected lift reflects **that lift's** hours today — see §34.10. |
| The 4.00 EV cap is reached **during a server update or shutdown** | Eligibility is a function of `spentToday >= 4.00`, so whichever server the player lands on computes the same answer, and Start CN is refused there too. |
| A **daily reset** lands while the player is at a rack | The next read sees a new server-stamped day key and both allowances reset to zero. A stopped session stays stopped until the player presses Start; a technique selection stays technique. **The reset never changes a selection.** |
| The player **changes server** | The rack session is lost by design (the player re-selects); the allowances live in the profile, so nothing is lost or duplicated. |

### 34.6 Exactly five trainable technique stats — [FINAL]

**[FINAL]** There are **five** trainable technique stats, and no others:

| Lift | Trainable technique stats |
|---|---|
| **Squat** | `SquatControl`, `DepthAwareness` |
| **Bench** | `StartControl`, `PressPower` |
| **Deadlift** | `Lockout` — **one only** |

**[FINAL] `PullStrength` is not a trainable stat.** It is removed from the design.

**[FINAL] No replacement stat is created for it.** The Deadlift has one trainable
technique stat and that asymmetry is accepted. Inventing a sixth stat to restore
symmetry would reintroduce the thing being removed under a new name.

> **The code still contains `PullStrength`, and that is correct for now.** Verified
> live in five places:
>
> | File | What it holds |
> |---|---|
> | `PlayerProfileSchema.luau` | the `technique.PullStrength` type field, the template default, and the v1 and v2 migration repair steps |
> | `StartingValuesConfig.luau` | `PullStrength = 0`, the starting value |
> | `TypingPhaseConfig.luau` | `techniqueStat = "PullStrength"` and the three curves it drives -- progress per character, sag, and the mistake penalty |
> | `PlayerDataProbe.server.luau` | migration and preservation assertions that read the field |
> | *(read path)* `LiftAttemptService.luau` | reads it by name out of the technique snapshot |
>
> Removing it is a **later implementation checkpoint** (§34.14) and requires four
> things in one change:
>
> 1. a **schema migration** dropping the field, and the starting value with it;
> 2. **Deadlift typing difficulty retuned** independently of it (§34.9);
> 3. the dev-probe assertions that read it updated or removed;
> 4. the design-document references in the mechanic-assignment table, §3, §11 and
>    §28 brought into line.
>
> It must **not** be deleted from code as part of documenting this decision.
> `LiftAttemptService` reads the technique snapshot with an `or 0` fallback, so an
> absent `PullStrength` would silently read as the curve's base anchor rather than
> raising an error — meaning a partial removal would **quietly** retune the
> Deadlift instead of failing loudly. That is precisely why the retune has to be
> deliberate and in the same checkpoint.

### 34.7 AFK technique specialization — [FINAL rule, PROVISIONAL rates]

**[FINAL] Technique is trained only when the player MANUALLY selects it** at a
rack: a lift, and for the Squat or Bench a primary stat. *(Revised in 5B.6: it
no longer starts automatically at the CN cap. Automatic CN-to-technique fallback
is a future Game Pass feature only, §34.12.)* **Whether technique can also be
earned before the day's CN cap is reached is [TBD] for checkpoint 5B.7**; in
5B.6 it can be selected at any time but earns nothing.

**[FINAL]** Distribution:

| Selected lift | Player choice | Award |
|---|---|---|
| **Squat** | `SquatControl` **or** `DepthAwareness` as primary | **80%** to primary, **20%** to the other Squat stat |
| **Bench** | `StartControl` **or** `PressPower` as primary | **80%** to primary, **20%** to the other Bench stat |
| **Deadlift** | none — there is one stat | **100%** to `Lockout` |

**[FINAL] The 80 / 20 split is deliberate, and the secondary develops slowly.**
This was chosen with the consequence known: at 20% of a 6.00 raw/day allowance the
secondary receives 1.20 raw points a day, and on the log-space technique curve
that is a small effective gain even over a season. The decision is that AFK
technique should express a **clear** specialization, and that the secondary's job
is to not be frozen at zero rather than to keep pace. Players who want balanced
technique have the right tool for it, and it is meets (§34.8), not the station.

**[PROVISIONAL] Candidate AFK technique rates:**

| Parameter | Candidate |
|---|---|
| Rate | **2.00 raw technique points per hour**, total across the split |
| Daily allowance | **6.00 raw technique points**, **account-wide** |
| Time to exhaust | **3.00 hours** |
| Fractional awards | **required** — see below |

**[FINAL] Fractional raw technique awards must be preserved.** 80 / 20 of a 6.00
allowance is 4.80 and 1.20. Rounding to integers would discard up to 20% of the
secondary's daily award and would make the split silently wrong. The technique
curve is continuous over raw points, so storing a non-integer costs nothing.

**[FINAL]** After the technique allowance is exhausted, **no further AFK technique
progression is earned until the next daily reset.** The technique session stops
earning: it does not fall back to CN, overflow into another stat, or continue at a
reduced rate.

### 34.8 Meets remain the main technique progression activity — [PROVISIONAL]

**[FINAL] Meets must remain the primary source of technique progression.** This is
the counterweight that stops the game being solved by standing still. CN is
AFK-only, so technique is where active play has to pay better.

**[PROVISIONAL] Candidate meet technique rates:**

| Parameter | Candidate |
|---|---|
| Per **successful eligible** lift attempt | **4.00 raw technique points** |
| Daily cap | **60.00 raw meet-technique points**, account-wide |
| Failed attempt | **zero** |
| Bare participation, bombing, an empty entry | **zero** |

**[FINAL] Zero technique for failed attempts and for empty participation.** This
mirrors §33.6 and closes a farm: an award for merely entering is an award for
bombing out quickly and re-entering, which pays better per hour than competing
properly. Awarding only on a good lift makes the fastest technique route also the
honest one.

> **⚠ These values must be tested against real meet duration before
> implementation.** Meet duration **does not exist anywhere in this document or in
> the code**, and the whole active-versus-AFK ratio depends on it. 4.00 points per
> successful attempt is 36.00 for a 9-for-9 meet, and the 60.00 daily cap binds
> partway into a second one — but whether that is generous or stingy is unknowable
> until a meet takes a measurable number of minutes. **[TBD]** — §34.13.

**[FINAL] Meets award no Competition Number.** §33.3, restated here because this
is the section that gives meets a progression reward, and the two must not be
allowed to blur.

**[FINAL] Official meet totals and records come from successful eligible lifting
performances.** They are **never** derived from combined Competition Number, from
summed Competition Scales, or from any historical high-water mark. §31 and §32
remain authoritative. See §34.11 for why this has to be stated explicitly.

### 34.9 Deadlift typing and cosmetic currency — [FINAL mechanic, PROVISIONAL numbers]

**[FINAL] The competition Deadlift remains a TWO-PHASE lift.** Removing
`PullStrength` removes a **stat**, not a phase.

| Phase | Mechanic | Required for a good lift? | Trainable stat | Difficulty scales with |
|---|---|---|---|---|
| **1** | Typing-based pull (§11) | **Yes** | **none** | attempt difficulty / intensity, and real player execution |
| **2** | Lockout skill check (§11) | **Yes** | **`Lockout`** | attempt difficulty, and effective `Lockout` |

**[FINAL] Phase 1 is still required for a successful Deadlift.** Failing it is a
NO LIFT and Phase 2 does not run, exactly as before. Nothing about removing the
stat makes the pull optional, automatic or skippable.

**[FINAL] Phase 1 uses no trainable stat, and no replacement is created.** Its
difficulty is rebased on **attempt difficulty / intensity plus the player's own
execution** — nothing else (§34.6).

**[FINAL] Phase 1 may reward cosmetic currency**, under a separately balanced
reward system.

**[FINAL] Phase 2 is unchanged.** It uses the `Lockout` technique stat, which is
one of the five trainable stats (§34.6), and it is still required to complete the
lift.

> **The resulting asymmetry, stated plainly so nobody has to discover it later.**
> Squat Phase 1 scales with `SquatControl`; Bench Phase 1 scales with
> `StartControl`. **Deadlift Phase 1 scales with no trainable stat at all** — only
> with the weight on the bar and the player at the keyboard.
>
> The Deadlift's character progression therefore lives entirely in two places:
> **Competition Number**, which sets the attempt's physical difficulty (§33.4),
> and **`Lockout`**, which governs Phase 2. Both are fully intact.
>
> This is a deliberate consequence of the five-stat decision, not an oversight.
> The typing pull is the game's one pure player-skill gate, and §1's premise that
> character progression and player skill are **separate** inputs is what makes
> that acceptable.

**[FINAL] Cosmetic currency is strictly cosmetic:**

| Rule | Status |
|---|---|
| Cannot increase Competition Number | **[FINAL]** |
| Cannot increase any technique stat | **[FINAL]** |
| Cannot increase any lifting modifier or lifting performance | **[FINAL]** |
| AFK training awards **none** of it | **[FINAL]** — §34.3 |
| No `PullStrength`, and no replacement trainable typing stat | **[FINAL]** — §34.6 |

**Why cosmetic-only is load-bearing.** Typing speed is a real-world player
attribute that the character cannot train and that no in-game progression should
be able to buy. Paying it in strength or technique would make a fast typist
permanently stronger than a slow one with the same character, which contradicts
§1's premise that character progression and player skill are separate inputs.
Paying it in cosmetics rewards the skill without pricing it into competition.

**[PROVISIONAL] Two quantities are approved in direction and uncalibrated in
magnitude. Neither may be implemented until it is calibrated:**

| Quantity | Status |
|---|---|
| The **typing difficulty rebase** — how Phase 1's character count, sag and mistake penalty derive from attempt intensity alone | **[PROVISIONAL]** — the approach is approved; **no curve exists yet**. Checkpoint 9, §34.14 |
| The **cosmetic currency reward quantities** — per-attempt award, rate and daily cap | **[PROVISIONAL]** — the approach is approved; **no value exists yet**. Checkpoint 11, §34.14 |

**§12's note that Deadlift training yields cosmetic currency is consistent with
this and survives.**

### 34.10 The manual lift-selection tradeoff — [FINAL mechanic, PROVISIONAL figures]

> **What is [FINAL] here and what is not.** Path independence, and the existence of
> a time-for-concentration tradeoff, are **[FINAL]**: they are properties of the
> Hill formula and of `H(t)`'s per-lift scoping, not balance choices, and they hold
> whatever the constants turn out to be.
>
> **Every day count and hour count in this section is [PROVISIONAL].** All of them
> are outputs of `BaseProgressRate = 0.01113418` (§34.11) and of `H(t)`'s three
> candidate parameters (§34.4). When those move, these move.

**[FINAL] Rotation order is mathematically irrelevant. The hours are not.**

The progression derivative is

```
d(CN_i) / d(E_i) = Reference_i * BaseProgressRate * Hill(CN_i / Reference_i)
```

whose right-hand side is a function of **`CN_i` alone**. A lift's CN therefore
depends only on the **cumulative EV that lift has received**, never on when it
arrived. This is the same path-independence property §29.9 proves for the
Competition Budget, and it has three consequences worth stating plainly:

| Consequence | Detail |
|---|---|
| **There is no ordering to discover** | A daily Squat → Bench → Deadlift rotation gives **identical** results to a perfectly even split at every multiple of three days. Verified: 872.5 kg combined at day 75 by both routes, 83 kg class. |
| **Between the multiples, rotation is very slightly behind** | Worst case **5.63 kg, or 0.65%**, at the one-day remainder. The over-fed lift converts its surplus EV at a worse Hill rate than the two under-fed lifts lose — a small concavity penalty, not a design problem. |
| **There is no schedule exploit** | No rotation pattern beats any other at equal cumulative EV per lift. The CN channel cannot be gamed by sequencing. |

**[FINAL] What the player is actually trading is time, not progression rate.**
Because `H(t)` is per lift while the cap is per account (§34.4), the hours needed
to reach the 4.00 EV cap depend on how many lifts the day is spread across.

**[PROVISIONAL] The hour figures below** follow from `FullRateHours`, `K` and
`BaseRate`, all three of which are candidates (§34.4). The **direction** is final;
the **magnitudes** are not:

| Allocation | Hours to exhaust 4.00 EV | Where the EV lands |
|---|---|---|
| One lift all day | **5.4366 h** | 4.00 EV to one lift |
| Two lifts, 2.00 h each | **4.0000 h** | 2.00 EV to each |
| Three lifts, 1.33 h each | **4.0000 h** | 1.33 EV to each |

**Any split that keeps every lift at or under two hours reaches the cap in exactly
4.00 hours.** Concentrating on one lift costs **1.44 extra hours** for the same
4.00 EV. That is the tradeoff: a player who wants everything in one lift pays for
it in wall-clock time at the station, and a balanced trainer is rewarded with a
36% shorter day. No specialization penalty is applied to the CN itself.

> **⚠ Confirm this is intended.** It follows directly from H(t) being per lift and
> the cap being per account, and it is a pleasing result — soft anti-specialization
> pressure that costs the specialist nothing in progression. But it does mean the
> **fastest** route to the daily cap is to switch lifts at the two-hour mark, which
> is worth knowing before the station UI is designed. The alternative, making H(t)
> account-wide, would make all allocations cost 5.44 hours and remove the tradeoff
> entirely. **[TBD]** if the per-lift scoping is not what was wanted.

**[FINAL] Specialization is correctly priced with no artificial penalty.**
Verified across all seven classes: the optimal uneven allocation beats an even
split by **under 2% in every class** (1.7% to 2.1%), because `Hill` falls roughly
as the fifth power of Progression Proximity and so crashes a concentrated lift's
own marginal yield. A pure single-lift trainer plateaus around **517 kg of an
890 kg total** — that is arithmetic, not a punishment. A lifter who cannot bench
cannot total.

**Strategy comparison — days for combined CN to reach 100% of the total-record
benchmark:**

| Class | Rotate S-B-D | S-S-B-D | D-D-S-B | 7 days Squat, then B, D | Pure single lift |
|---|---|---|---|---|---|
| 59 kg | **64** | 68 | 64 | 108 | **never** |
| 66 kg | **80** | 84 | 82 | 132 | never |
| 74 kg | **96** | 100 | 98 | 154 | never |
| 83 kg | **80** | 86 | 84 | 134 | never |
| 93 kg | **78** | 82 | 80 | 126 | never |
| 105 kg | **76** | 80 | 80 | 122 | never |
| 120 kg | **68** | 70 | 72 | 108 | never |

**The real risk in a manual-selection design is forgetting, not min-maxing.** A
mild skew costs 2 to 6 days. Leaving one lift selected for a week before switching
costs **44 to 58 days** — a 1.6x to 1.7x slowdown. That is not an exploit; it is a
**usability trap**, and it falls hardest on the casual player who checks in weekly
rather than daily. See §34.13.

### 34.11 CN calibration — the approved projection — [PROVISIONAL]

**[FINAL] What is preserved:**

- the existing **21 frozen lift references** (§29.2b), FitVersion 1
- the existing **Hill curve**, `h = 0.75`, `m = 5` (§29.3)
- **one global `BaseProgressRate`** (§29.15) — a single configurable constant
- **training-only** CN progression (§34.2)
- **no artificial specialization penalty** (§34.10)
- **no per-class multiplier or per-class Hill correction**

**[PROVISIONAL] Candidate `BaseProgressRate = 0.01113418`. NOT FINAL, AND NOT
IMPLEMENTED.**

| | Value | Status |
|---|---|---|
| **In the code today** | **0.00482389** | **[TUNABLE]** — live in the progression config, unchanged by this section (§29.3) |
| **Proposed for Step 5** | **0.01113418** | **[PROVISIONAL]** — a calibration candidate. Not implemented, not frozen, and expected to move |

Adopting the candidate changes **nothing structural**: not the §29.3 formula, not
the 21 frozen Progression References (§29.2b), not the Hill curve, not `h` or
`m`. It is one multiplier, and every number in this section scales with it.

With the configured 74 kg total-record benchmark retained at 891.5 kg (§34.1
decision 5), the manual Squat → Bench → Deadlift rotation reaches 100% Record
Potential Ratio in **64 to 96 days** across the seven classes:

| Class | Day 30 | Day 60 | Day 75 | Day 90 | Day 120 | 95% RPR | **100% RPR** | 105% RPR |
|---|---|---|---|---|---|---|---|---|
| 59 kg | 433 | 663 | 730 | 781 | 856 | 56 | **64** | 70 |
| 66 kg | 456 | 703 | 774 | 828 | 908 | 70 | **80** | 90 |
| 74 kg | 481 | 745 | 822 | 880 | 965 | 84 | **96** | 110 |
| 83 kg | 507 | 790 | 873 | 935 | 1026 | 72 | **80** | 92 |
| 93 kg | 535 | 838 | 926 | 993 | 1090 | 68 | **78** | 88 |
| 105 kg | 567 | 893 | 988 | 1059 | 1163 | 68 | **76** | 86 |
| 120 kg | 605 | 958 | 1060 | 1137 | 1249 | 62 | **68** | 76 |

*(Combined CN in kg, three lifts summed. RPR is combined CN divided by the class
total-record benchmark in `ReferenceRecordConfig`.)*

Per-lift CN at day 90:

| Class | Squat | Bench | Deadlift | Combined | RPR |
|---|---|---|---|---|---|
| 59 kg | 276.4 | 191.6 | 313.3 | 781.3 | 116.7% |
| 66 kg | 297.5 | 203.2 | 327.8 | 828.5 | 105.9% |
| 74 kg | 320.9 | 215.7 | 343.3 | 879.8 | 98.7% |
| 83 kg | 346.1 | 229.0 | 359.6 | 934.7 | 105.0% |
| 93 kg | 373.1 | 243.0 | 376.5 | 992.7 | 107.0% |
| 105 kg | 404.3 | 259.0 | 395.5 | 1058.8 | 108.0% |
| 120 kg | 441.7 | 277.8 | 417.5 | 1137.0 | 113.7% |

**[FINAL] The DECISION is approved: accept this projection and keep the 74 kg
benchmark at 891.5 kg. [PROVISIONAL] The completion times themselves are not
approved balance** — they are simulation output and move with `BaseProgressRate`.
Six of seven classes
land inside the 60 to 90 day contention window. **The 74 kg class sits outside it
at 96 days**, because its configured total benchmark of 891.5 kg is the lowest
sum-of-three-to-total ratio in the table (1.011 against 1.040 to 1.067 elsewhere).
Per decision 5 this is **not** corrected by changing the record, by adding a
per-class multiplier, or by re-solving the formula. It is a known, bounded,
documented deviation of six days.

> **Why `BaseProgressRate` should not be retuned to hide it.** Re-solving the
> constant so the slowest class lands at exactly 90 days gives `B` near 0.01188
> and a 60 to 90 day window — but it reaches that by making **every other class**
> faster to compensate for one benchmark value. That is curve-fitting to a single
> data point, and it would have to be undone the moment the 74 kg benchmark is
> ever revisited. The honest 64 to 96 day range is the better record.

**[FINAL] Record-contender CN potential and an achieved meet total are separate
concepts.** Summing the three Competition Numbers gives a lifter's **potential** —
"this character could contend at this total". It is **never** a total, a record, or
a result. An official total comes from three successful eligible attempts under
§31 and §32, and nothing else. The RPR column above measures potential, which is
why a class can exceed 100% long before any player has set anything.

> **Three summable-looking per-lift quantities now exist** — Competition Number,
> Competition Scale, and the best successful attempts of a single meet — and only
> the third of them produces an official total.
>
> **[FROZEN] An official meet total is the best successful Squat, Bench and
> Deadlift attempts from the SAME eligible meet** (§31, §32, and what `MeetTotal`
> computes). **Historical Competition Scales must never be substituted for it.** A
> Scale is a high-water mark that may have been set in three different meets months
> apart, so summing three Scales describes a total nobody ever lifted.
>
> **This is NOT a prohibition on a cosmetic display, and it resolves nothing that
> was open.** §33.8 permits a player-facing "Proven Total" as a clearly-labelled
> **cosmetic curiosity**, and whether to have one at all is still **[TBD]** (§33.8,
> §33.11 item 12). That question is untouched here. The rule above governs what
> counts as an **official** total, not what may be shown on a profile.

### 34.12 Server-side allowance accounting and safeguards — [FINAL]

**[FINAL]** All allowance accounting is **server-authoritative**. The client may
request to start training, to change lift, or to change technique primary; it
never supplies elapsed time, accrued EV, technique points, or a day boundary.

**[FINAL] FIVE counters are persisted: two account-wide allowances and three
per-lift training-time accumulators.** All five are server-authoritative and
day-keyed.

**The two account-wide allowances:**

```
cnAllowance = {
    spentToday      = <number>,   -- EV spent today, 0.00 to 4.00
    dayKey          = <string>,   -- SERVER-stamped day identifier
    lastUpdatedUnix = <number>,   -- SERVER clock
}

techniqueAllowance = {
    spentToday      = <number>,   -- raw technique points today, 0.00 to 6.00
    dayKey          = <string>,
    lastUpdatedUnix = <number>,
}
```

**[FINAL] The three per-lift training-time accumulators are REQUIRED.** `H(t)`
(§34.4) is scoped **per lift**, so `t` cannot be derived from either account
allowance. Three separate daily accumulators are needed:

```
trainingTimeToday = {
    Squat    = <number>,          -- hours of station CN training on Squat today
    Bench    = <number>,          -- hours on Bench today
    Deadlift = <number>,          -- hours on Deadlift today

    dayKey          = <string>,   -- SERVER-stamped, shared by all three
    lastUpdatedUnix = <number>,   -- SERVER clock
}
```

Each lift's accumulator feeds `H(t)` for **that lift and nothing else**. The
account-wide daily CN allowance remains **4.00 EV** and is **not** per lift.

| Counter | Scope | Cap |
|---|---|---|
| `cnAllowance.spentToday` | **whole account** | **4.00 EV/day** — **[FINAL]** |
| `techniqueAllowance.spentToday` | **whole account** | **6.00 raw/day** — [PROVISIONAL], §34.7 |
| `trainingTimeToday.Squat` | **that lift only** | **uncapped** — it shapes `H(t)`, it never stops training |
| `trainingTimeToday.Bench` | **that lift only** | uncapped |
| `trainingTimeToday.Deadlift` | **that lift only** | uncapped |

**[FINAL] Switching the selected lift preserves everything.** It does **not**
reset:

- the account-wide **EV** already spent today;
- the account-wide **technique points** already spent today;
- **any** of the three per-lift time accumulators, including the one belonging to
  the lift just left.

A player who trains Squat for two hours, switches to Bench, and later switches
back to Squat resumes Squat at **`t` = 2.00**, not at `t` = 0. **Returning to a
lift does not restore its full efficiency, and leaving a lift does not forfeit the
time already banked against it.** Switching is a choice about where the next EV
goes, never a way to re-open a lift's full-rate window.

**[FINAL] None of the five counters is scoped to a build slot, a weight class, a
station or a server.** They are account state, day-keyed, and nothing else.

**[FINAL] All five are persisted and must be safe across:**

| Event | Required behaviour |
|---|---|
| **A reconnect** | every counter reloads from the profile at the value it held. No reset, no re-grant, no back-pay for the time offline (§34.2) |
| **A server change** | identical for the allowances, because none of them lives in session state (§34.5). The new server reads the same five counters and derives the same CN eligibility and the same `H(t)` for every lift; only the rack selection must be chosen again |
| **A daily reset** | a new server-stamped `dayKey` zeroes **all five** on the next read — the two allowances **and** all three time accumulators. `H(t)` returns to full efficiency for every lift |
| **A mid-session shutdown or crash** | the counters were already written on each tick, so nothing is lost beyond the unwritten remainder of the tick in progress |

**[FINAL] CN lift selection stays manual.** None of this changes §34.3: the
station never rotates on its own, and the per-lift accumulators exist to **price**
the player's own choice (§34.10), never to make it for them.

**[FINAL] Computed on read.** A station recomputes the current allowance state
from the persisted counters on every read, rather than reacting to events. This is
what delivers the §34.5 transition guarantees, and it is the mechanism behind the
central rule:

> **[FINAL] Changing the selected lift, the technique primary, the station or the
> server NEVER resets either daily allowance.** There is nothing to reset, because
> neither counter is scoped to any of those things.

**[FINAL] Required safeguards:**

| Safeguard | Why |
|---|---|
| The **day key is stamped by the server**, never derived from a client clock or a client-supplied date | a client-chosen day boundary is an unlimited allowance |
| **Elapsed time is ACTIVE, server-observed station time**, measured by the station from its own session-local record of when it last ticked that player — **never** derived from `lastUpdatedUnix` | a client-reported duration is a client-reported reward; and `lastUpdatedUnix` is an **audit stamp** of the last write, so a profile loaded after three days offline carries a three-day-old stamp — measuring from it would credit offline time (§34.2). Losing the session-local record on a server change credits less, never more |
| **Presence at the station is verified server-side** | §34.3 is otherwise unenforceable |
| **Elapsed time is attributed only to the lift selected at that moment**, server-side | otherwise a client could bank hours against a lift it was not training and reset `H(t)` at will |
| All five counters are **rolled over by comparing the stored `dayKey` to the server's current one**, never by a scheduled job | a missed timer must not hand out a second day's allowance, and a rollover must happen even if nobody was online when the day turned |
| Accrual is **clamped to the remaining allowance** before it is written | a long tick near the cap must not overshoot 4.00 EV |
| The CN write goes through the single operation `awardTrainingProgression(player, lift, elapsedSeconds)` | it derives EV from the allowance and kilograms from EV, so no caller can get either magnitude wrong — §33.9 and "The training progression award" below |
| **No RemoteEvent, RemoteFunction or dev trigger may write CN, Scale or technique directly** | the §33.12 security boundary, applied to the training channel |
| Technique is stored as a **float** | §34.7's fractional awards |
| A **monotonic** server clock source is used for elapsed time where available | a backwards clock step must not create negative elapsed time |

**[FINAL] Allowances are never granted retroactively.** A player who was offline
across a daily reset gets a fresh allowance for the current day and nothing for
the days missed. Allowances do not stack, bank or roll over.

#### The training progression award — checkpoint 5B.5

**Three decisions approved for checkpoint 5B.5:**

| # | Decision | Status |
|---|---|---|
| A | **Training EV bypasses the Competition Budget entirely.** It neither spends the three per-lift pools nor is scaled by them. The 4.00 EV daily allowance is the only throttle on training. The budget data is preserved untouched; its own fate stays **[TBD]** (§34.13 item 7) | **[FINAL]** |
| B | **The operation is `awardTrainingProgression(player, lift, elapsedSeconds)`.** The caller never supplies earned EV, kilograms or a timestamp. EV comes from the allowance plan (`TrainingAllowance`, `TrainingEfficiency`); kilograms from the §29.3 formula; the clock is `os.time()` read inside the gateway | **[FINAL]** |
| C | **A weight class with no configured Progression Reference — including 120+ — rejects the whole update.** No CN is awarded and no allowance is spent, not even a pending day rollover | **[FINAL]** |

**The award formula is §29.3's without the budget stage:**

```
earnedEV = the allowance plan's EV: H(t) per lift, clamped to the 4.00 EV account cap,
           split at UTC midnight
deltaCN  = ProgressionReference x BaseProgressRate x earnedEV x Hill(PP before the award)
```

It uses the **live** `BaseProgressRate` (0.00482389). The §34.11 candidate is
**not** activated by this checkpoint.

**[FINAL] One write, all or nothing.** The allowance debit and the CN award are
made together, in one synchronous update to the same profile table, with no
yield between validation and mutation. A rejected update changes nothing: no CN,
no counter, no stamp. Because both land in the same profile, a crash before the
next save loses both together and can never keep one without the other.

| Outcome | Meaning | Written |
|---|---|---|
| `Awarded` | EV was earned and bought CN | CN and all three accounting records |
| `NoProgress` | valid, but nothing earned — cap spent, or zero or negative elapsed time | the accounting records only (rollover and audit stamp); **CN unchanged** |
| `ClockWentBackward` | a stored day key is later than the interval's start | **nothing** |
| `Rejected` | bad lift, time, elapsed time, bodyweight, class, CN or accounting data, or a failed invariant | **nothing** |

**Elapsed time must be at most one day per call** and finite. Each call is a
separate interval; the station of 5B.6 owns the tick period and a tighter
per-tick bound.

**Implementation:** `ProfileOperations.applyTrainingProgression` (pure, tested
by `TrainingProgressionProbe`), wrapped by `PlayerDataService.awardTrainingProgression`.
**It had no caller in 5B.5.** Since 5B.6 its only caller is the gym training
station below; no remote or other timer invokes it.

#### The gym training racks — checkpoint 5B.6 (revised)

**Revised design approved for checkpoint 5B.6.** It replaces the first,
uncommitted 5B.6 implementation (four prompts per station, no GUI, automatic
technique phase). Nothing from that version shipped; the replaced decisions are
listed below so no contradictory rule survives.

| # | Decision | Status |
|---|---|---|
| 1 | **Every rack is a universal training station.** Same menu, same rules, no per-rack scripts. Racks are registered through the CollectionService tag `GymTrainingStation` plus a `StationId` attribute, so the gym can grow to many racks and placeholders can be swapped for models without touching progression code | **[FINAL]** |
| 2 | **One ProximityPrompt per rack, hold E** (0.5 s, configurable) to open the **Training Selection menu**. The server checks presence and availability **before** authorizing the menu, and a free rack is **reserved** for the player while the menu is open | **[FINAL]**; hold time **[PROVISIONAL]** |
| 3 | The menu offers two clearly separate categories: **Competition Number** (Squat / Bench / Deadlift) and **Technique Stats** (Squat Control or Depth Awareness; Start Control or Press Power; Lockout). The player **manually** chooses; the rack never rotates lifts or changes mode on its own | **[FINAL]** |
| 4 | **One player per rack; one rack per player** | **[FINAL]** |
| 5 | **Free players STOP at the 4.00 EV daily CN cap.** No more CN, **no technique points**, no change of mode or lift. The rack stays occupied and shows **"Daily CN Limit Reached — Training Stopped."** The player must manually select Technique Stats to keep training | **[FINAL]** |
| 6 | At the **UTC reset** CN becomes available again (as `TrainingAllowance` already specifies), but a session stopped at the cap **stays stopped until the player presses Start**, and a manually selected technique mode is **never overridden** | **[FINAL]** |
| 7 | Technique can be **selected** in 5B.6 but earns **nothing** until 5B.7. The menu and sign say so ("rewards are available in Step 5B.7"); the time is discarded | **[FINAL]** for 5B.6 |
| 8 | A small purpose-built remote interface (`TrainingRemotes`): one client-to-server request event and one server-to-client state event. See the security model below | **[FINAL]** |
| 9 | **Presence is verified server-side** on menu authorization, on every request and on every tick. The character is **not** anchored | **[FINAL]** |
| 10 | The selection is remembered **only while the player holds the rack**. No schema change, no cross-session persistence | **[FINAL]** for 5B.6 |
| 11 | **Roblox's idle kick is accepted.** It ends accrual like any disconnect. No offline progression and no anti-idle workaround. Whether multi-hour idle training needs a different answer before release is open | **[FINAL]** for 5B.6; release question **[TBD]** |
| 12 | **Two temporary placeholder racks** (plain Parts near spawn). Real models come after 5B.7 | **[FINAL]** for 5B.6 |
| 13 | Lift attempts stay **independent** of the racks | **[FINAL]** for 5B.6 |
| 14 | Tick **10 s**, at most **30 s** credited per tick, **12 stud** presence radius, **1 s** selection cooldown, **8 requests per 4 s** spam limit | **[PROVISIONAL]** — `TrainingStationConfig` |

**Decisions replaced from the first 5B.6 implementation:**

| Replaced | By |
|---|---|
| Four prompts per station (Train Squat / Bench / Deadlift / Stop) | one hold-E prompt that opens a menu (decision 2) |
| "No RemoteEvents, no client code, no selection UI" | a temporary ScreenGui and a two-event remote interface (decision 8) |
| At the cap the station **automatically** enters a technique phase and displays it | free players **stop** at the cap (decision 5); automatic fallback is a future Game Pass feature, below |
| After the UTC reset, CN resumes automatically on the same lift | the stopped session waits for the player to press Start (decision 6) |
| 1 s **lift-switch** cooldown | 1 s **selection** cooldown covering lift, mode and primary stat |

**The session.** Holding E at a free rack reserves it in **Selecting**. Start
Training moves it to **Training** (CN or Technique). CN training that hits the
cap moves to **StoppedAtCNCap**. Close hides the menu: from Selecting it frees
the rack; while Training or Stopped the rack stays the player's. Stop Training
credits the interval so far (if the player is still present) and frees the rack.

**How a tick works.** One server loop measures every occupant each tick with
`os.clock()` from that player's previous tick, **moves the tick start forward
before anything else** (so the same seconds can never be counted twice, and time
spent Selecting or Stopped is never paid later), clamps the interval to the
per-tick maximum, and reads CN eligibility from the saved allowance record **at
the end of the interval**. Only a Training session in CN mode calls
`awardTrainingProgression`; the gateway itself caps the partial tick at 4.00 EV
and splits a UTC midnight. If CN is capped — before the call, or because that
call reached the cap — the session becomes StoppedAtCNCap.

| Event | Behaviour |
|---|---|
| Manual switch (lift, mode or primary) | whatever was running is credited up to now to the **old** selection, then the new one starts. Per-lift hours are never reset |
| Start CN while capped | refused with the cap message; the current selection is untouched |
| Stop Training | the interval so far is credited if the player is still present, then the rack frees |
| Close | frees an unused reservation; otherwise only hides the menu |
| Death, respawn, leaving range, disconnect | the occupancy ends with **no credit** for the unfinished interval |
| A second player at an occupied rack | refused |
| One player at a second rack | refused until they stop at the first |
| A whole-update rejection (e.g. the 120+ class) | refused at reservation by a zero-second gateway check; mid-session it ends the occupancy |

**Security model.** A client may only **request**: Start with `{ mode, lift,
primary? }`, Stop, or Close. It never sends a station id (the server knows which
rack the player holds), a position, a duration, a timestamp, EV, CN or a Game
Pass entitlement; a request with **any** extra field or argument is refused, not
ignored. The server validates the mode, the lift and that the primary stat
belongs to that lift (`PullStrength` is never accepted), checks presence itself,
applies a per-player rate limit and the selection cooldown, and measures all
time with its own clock. There is **no remote that reaches
`awardTrainingProgression`**; the tick is its only caller. The menu is opened
only by the server.

#### Future Game Pass — automatic technique fallback — NOT IMPLEMENTED

> **Nothing in this subsection exists in the game.** No purchase, no
> MarketplaceService check, no entitlement and no automatic switching is
> implemented. It is recorded so the 5B.6 stop rule is understood as the
> **free** behaviour, not the only one.

| Rule | Detail | Status |
|---|---|---|
| What it unlocks | When a pass owner's CN training reaches the 4.00 EV daily cap, the rack **automatically** switches to technique training on the **same lift**, using a **primary stat the player configured in advance** | **[TBD]** — later checkpoint |
| Example | Selected CN Squat, preferred primary Depth Awareness → at the cap: 80% Depth Awareness, 20% Squat Control | design intent |
| Conditions | Only while the player is still connected and occupying a valid rack. No offline progression | **[FINAL]** when built |
| What it never does | It never raises the 4.00 EV cap, never changes the progression rate or H(t), and never grants technique beyond the normal technique allowance | **[FINAL]** when built |
| Ownership | Checked on the **server** only; a client-reported entitlement is never trusted | **[FINAL]** when built |

**Implementation:** `TrainingStationRules` (pure, tested by
`TrainingStationProbe`), `TrainingStationService` (prompt, menu authorization,
request validation, presence, the tick), `TrainingRemotes`,
`TrainingStationConfig`, the client `TrainingMenuController`, and the temporary
`PlaceholderStations`.

### 34.13 What section 34 does NOT settle

Recorded so none of it is lost, and so none of it is answered by an implementation
choice:

| # | Open item | Status |
|---|---|---|
| 1 | **Meet duration.** Unspecified in this document and absent from the code. It blocks the active-versus-AFK reward ratio and therefore the validation of every §34.8 number. | **[TBD]** — highest-value missing decision |
| 2 | **The Deadlift typing difficulty rebase**, and the **cosmetic currency reward quantities** for it (§34.9). The two-phase structure and the cosmetic-only rule are **[FINAL]**; both sets of numbers are **[PROVISIONAL]** and do not exist yet. | **[PROVISIONAL]**, no values |
| 3 | **The forgetfulness mitigation.** §34.10 shows weekly switching costs 44 to 58 days. Candidates: a persistent indicator of which lift is selected and for how long; a one-tap switch at the station; or an **opt-in**, player-configured rotating routine — which would not violate §34.3, since what is forbidden is the station rotating on its own, not the player choosing a rotation. | **[TBD]** |
| 4 | **Whether H(t)'s per-lift scoping is intended**, given the 4.00 h versus 5.44 h result in §34.10. | **[TBD]** |
| 5 | **How a meet's technique award is split** across a lift's two stats — evenly, or weighted by which phase the attempt tested. | **[TBD]** |
| 6 | **Whether 8.44 hours is an intended full daily cycle** (§34.14). Four hours already yields 84.7% of the CN cap. | **[TBD]** |
| 7 | **The fate of the three Competition Budgets** (§29.9). The 4.00 EV daily cap does **not** resolve them and must not be confused with them: the cap is a daily account ceiling, the budgets are three persisted weekly per-lift pools with a 9.43 EV capacity. They are still attached to nothing. **Training does not use them** — 5B.5 decision A (§34.12) — so that much is settled; what they are for is not. | **[TBD]** — §33.12 step 8 |
| 8 | **The fate of Training Energy** (§29.8). Superseded as a CN throttle by decision 2 and by "no hard daily training-hour limit", but still persisted in the schema. Retire it, or give it a different job. | **[TBD]** |
| 9 | Everything still open in **§33.11** — the Scale challenge curve and cap, maximum-risk meet strategy, eligible-meet definition, Scale across weight classes, and Scale display. | **[TBD]** |

**Not open, for the avoidance of doubt:** the five decisions in §34.1, the single
CN source in §34.2, the station rules in §34.3, the two-phase Deadlift and the
five-stat set in §34.6 and §34.9, the 80/20 split in §34.7, the zero-for-failure
rule in §34.8, and the accounting model in §34.12.

**And, equally for the avoidance of doubt, NOT FROZEN.** Every constant below is
**[PROVISIONAL]** or **[TBD]**, must be implemented as named configuration, and is
expected to move:

| Constant | Candidate | Where |
|---|---|---|
| `BaseProgressRate` | 0.01113418 | §34.11 — the code still holds 0.00482389 |
| `BaseRate`, `FullRateHours`, `K` | 1.00 EV/h, 2.00 h, 2.00 | §34.4 |
| AFK technique rate and daily cap | 2.00 raw/h, 6.00 raw/day | §34.7 |
| Meet technique award and daily cap | 4.00 raw, 60.00 raw/day | §34.8 — also blocked on meet duration |
| Deadlift typing difficulty rebase | **no curve exists** | §34.9 |
| Cosmetic currency rate and cap | **no value exists** | §34.9 |
| Every day count and every hour count | — | §34.4, §34.10, §34.11 |

**The 4.00 EV daily CN cap is the one number in §34 that is [FINAL]**, because it
was approved as a design decision rather than derived as a calibration (§34.1
decision 2).

### 34.14 Implementation dependencies and recommended checkpoints

**Station occupancy per full daily cycle, for reference:**

| Phase | Hours |
|---|---|
| CN, one lift, 0 to 4.00 EV | **5.4366** |
| CN, split across two or more lifts, none over 2 h | **4.0000** |
| Technique, 6.00 raw at 2.00/hour | **3.0000** |
| **Full cycle, concentrated** | **8.4366** |
| **Full cycle, split** | **7.0000** |

**Recommended checkpoints, smallest safe step first.** These refine §33.12 step 5
and add the steps this section creates. Each leaves the game playable, and none
should begin before the decisions it depends on:

| # | Checkpoint | Depends on |
|---|---|---|
| 5B.1 | Add the two day-keyed allowance records to the player schema with a migration, written by nothing | nothing — §34.12 shape is [FINAL] |
| 5B.2 | Add the **training EV config**: `BaseRate`, `FullRateHours`, `K`, `DailyCapEV`, and the technique rate and cap, all as named constants | 5B.1; values are [PROVISIONAL] by design |
| 5B.3 | Implement `H(t)` and the cumulative-EV integral as a pure, tested module | 5B.2 |
| 5B.4 | Implement the derived-phase allowance reader — spend, clamp, day-key rollover — pure and tested | 5B.1, 5B.2 |
| 5B.5 | Implement `awardTrainingProgression(player, lift, elapsedSeconds)` on the data gateway, server-only, no remote, budget-free — **DONE**, verified in Studio; see §34.12 | 5B.1, 5B.3, 5B.4; §33.9 |
| 5B.6 | Wire the universal gym training racks: hold-E Training Selection menu, server-validated requests, presence check, manual CN lift selection, the accrual tick, **stop at the CN cap** for free players — **IMPLEMENTED (revised design)** with placeholder racks, awaiting Studio verification; see §34.12 | 5B.3, 5B.4, 5B.5; §34.13 item 4 |
| 5B.7 | Technique rewards for the manually selected technique mode, the 80/20 award path, float-stored. Decide whether technique may earn before the CN cap | 5B.4, 5B.6 |
| later | **Game Pass:** automatic CN-to-technique fallback with a player-configured primary stat (§34.12). Never raises a cap or a rate | 5B.7; a monetization decision |
| 6 | The Scale challenge modifier | §33.4 curve, cap and target — still **[TBD]** |
| 7 | Wire meets to raise Scale | a meet system; §33.7 eligibility; **and the class-scoped build system** per §33.8 |
| 8 | Resolve the Competition Budget | §29.9, §34.13 item 7 |
| 9 | **Remove `PullStrength`** — schema-version migration, `TypingPhaseConfig` rebase, test updates, and the §3 / §11 / §28 / mechanic-table documentation. **See the migration requirements below** | §34.6, §34.9. Must be **one controlled change**, because a partial removal degrades silently |
| 10 | Meet technique awards | §34.8; blocked on meet duration, §34.13 item 1 |
| 11 | Cosmetic currency for Deadlift typing | §34.9; blocked on §34.13 item 2 |

> **Checkpoint 9 is the one with a trap in it.** `PullStrength` is read through
> `attempt.techniqueSnapshot[techniqueStatName] or 0`
> (`LiftAttemptService.luau:173`), and `TechniqueCurve.toEffective(0)` returns the
> curve's base anchor of **10** rather than raising an error -- verified: its assert
> accepts `raw >= 0`, and `TechniqueConfig.EffectivenessCurve` has an explicit
> `{ x = 0, y = 10 }` anchor.
>
> So a migration that drops the field **without** rebasing the typing curves
> produces a Deadlift that still runs, never errors, and is quietly wrong -- every
> lifter silently pinned to the weakest technique the curve can express. That is
> the worst possible failure mode: no crash, no log line, no test failure, and a
> real balance change. The schema change and the rebase must ship together.

#### The `PullStrength` removal — migration requirements

**Do not implement any of this now.** This is the specification for checkpoint 9.

The intended game has exactly five technique stats (§34.6, §34.9). Removing the
sixth is a **schema-version migration**, not a field deletion, and the schema's
own rule is what makes that distinction load-bearing:

> **A migration step must exist for every historical version gap.** `migrate()`
> warns and abandons the profile at its old version if it finds no step for a gap,
> so a missing entry is not a harmless omission — it strands the save.

| # | Requirement |
|---|---|
| 1 | **Preserve a migration step for every historical version gap.** The chain must stay unbroken for the oldest profile the DataStore can still hold |
| 2 | **Do NOT simply delete `migrations[1]`.** It is the version-1-to-2 step, and its *purpose* was to add `PullStrength`, so that purpose disappears — but **the step itself must remain**, as a no-op if nothing else, or every version-1 save is abandoned at version 1 |
| 3 | **Audit and remove obsolete `PullStrength` references from the historical migration bodies** where strict typing and schema correctness require it. Once the `ProfileData` field and the starting-value entry are gone, any surviving reference to them is a `--!strict` type error, so the historical bodies **must** be edited. Edit the **references**; never edit the **version boundaries** |
| 4 | **Preserve valid conversion of historical profiles through the full version chain.** A version-1 profile must still arrive at the new current version with everything else intact: Competition Number, Competition Scale, the five surviving technique stats, the Competition Budgets and their timestamps, Training Energy, bodyweight and meta |
| 5 | **Add a new forward migration that removes the obsolete `PullStrength` field** from profiles that still carry it. Dropping it from the template is **not** sufficient — a saved profile keeps whatever was written to it, so the field must be explicitly removed |
| 6 | **Update the migration tests to validate a final five-stat profile.** The dev probe currently asserts the opposite in several places, including that the version-1 step adds the field at 0. Those assertions become false **by design** and must be retargeted to assert the field is **absent** after migration |
| 7 | **Rebase Deadlift typing difficulty in the same controlled checkpoint** (§34.9), before the removal is treated as complete |

**The order inside the checkpoint matters, and doing part of it is worse than
doing none of it.** The new forward migration is what makes the removal real for
existing saves. The historical-body audit is what makes the code compile. The
rebase is what stops the removal from silently changing gameplay. A checkpoint
that ships any two of the three leaves the game running and wrong, which is the
one outcome the §34.6 note exists to prevent.
