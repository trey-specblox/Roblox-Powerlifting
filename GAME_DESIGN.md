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
Lockout
+ typing/execution component 
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
The player completes the Squat Control minigame.

Reference: `References/testyourmight.md`

Relevant Stat: Squat Control
See references/testyourmight.md for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 


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
success-zone size
perfect-zone size
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

### Bar Control Phase
The player must stabilize and control the bar.

Reference: `References/FischeGame.md`

Relevant Stat: Start Control
See references/Fischegame.md for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 


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
success zone
perfect zone
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
Phase 1 — Typing challenge
Players type recognizable original/parody gym phrases or game-created motivational lines while pulling.
See references/TypingGame.md for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 



Difficulty can influence:
phrase length
available time
error tolerance

Phase 2 — Lockout
At the top:
LOCKOUT SKILL CHECK
Lockout stat controls:
success-zone size
perfect-zone size
needle speed
reaction window
Failure means:
NO LIFT
See references/DBD.md for the visual/mechanical reference and implementation direction for this minigame. Read that file before designing or implementing this mechanic. If the reference is unclear or inaccessible, ask me rather than inventing the missing behavior. 

12. Training
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
Your game actually has several progression systems:
LIFT PROGRESSION
Forecasted S/B/D

TECHNIQUE PROGRESSION
Control / Depth / Start Control / Press / Lockout

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

Read GAME_DESIGN.md.

This document was copied from Google Docs, so its Markdown formatting may be messy.

Reformat GAME_DESIGN.md into clean, well-organized Markdown WITHOUT changing, removing, summarizing, or inventing any of my game-design ideas.

Your job is formatting only.

Organize the existing content using:
- Clear headings
- Subheadings
- Bullet points
- Tables where appropriate
- Code blocks for formulas where helpful
- Consistent terminology

Preserve all formulas, numbers, mechanics, notes, and reference-file paths exactly in meaning.

Do not redesign or balance the game yet.

If something is unclear, leave the original information intact rather than guessing what I meant.











