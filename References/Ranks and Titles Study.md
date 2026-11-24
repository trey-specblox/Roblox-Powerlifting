# Ranks and Titles Study

Studied 2026-11-23 for GAME_DESIGN §41 (the user: "research games with ranks and titles ... pay attention to the ui ...
pictures for UI ... how they claim their titles ... how the games let the player know they got a title ... how the
players equip titles ... a rewarding feel, like sound effects, vfx ... how a title separates you from another player ...
how do the games make titles appear wanted and give them stature").

**How it was studied:** two research passes over written sources (official patch notes and dev posts, wikis, guide
sites, the Roblox DevForum, player forums), plus the fwjelaa vault notes on name tags, notifications, juice and season
passes. **Not watched:** videos. No written source gives the exact frames or sounds of a rank-up screen, so every
timing below is our own choice, to be checked by the user in Studio. Several big wikis (Fandom, Pro Game Guides,
Sportskeeda) refused automated reading, so some Roblox details come from smaller guide sites.

## Roblox games

| Game | What it does | What we take |
|---|---|---|
| **Sol's RNG** | Titles from achievements, equipped in a "Leaderboard Titles" tab with progress shown. Rarer rolls get **more dramatic cutscenes**; the top tier has its own cutscene and music. Only extremely rare rolls are announced to the whole server. Players can set a rarity cutoff below which cutscenes are skipped. | The moment grows with rarity; global announcements only for rare things; one equip screen with progress |
| **Pet Simulator 99** | 40 named ranks ("Noob" to "Herald"), each with a **reward path** claimed as it fills; ranks unlock slots and zones. Rare hatches light up global chat; the hourly biggest hatch is named on every server. | A visible reward path with a claim button; a cap that rises with updates |
| **Blox Fruits** | Titles by rarity colour (Common white, Uncommon light blue, Rare purple, Legendary gold), shown by your name; equipped only at a hidden NPC; no unlock notification. | The rarity colours; NOT the hidden equip spot or the silent unlock |
| **Bee Swarm** | Every badge category reuses the same 5 tier words (Cadet to Grandmaster), each tier with a reward. | Learn the ladder once (our levels I to V on every name) |
| **BedWars, RIVALS** | Bronze to Diamond/Onyx with III/II/I sub-tiers, then single named top tiers; a rank badge picture on the profile; rewards fixed to the season's peak. | Sub-tiers below, one grand look at the top |
| **The Strongest Battlegrounds** | Titles are "nameplate flexes" by leaderboard position, reset monthly. | Titles as a flex others see |
| **Strongman Simulator** | Ranks climb from a joke ("Baby Noob") to an aspiration ("Mega Tank"). | Our "Fresh Chalk" to "Strength God" already does this |
| **Sailor Piece** | Titles give stat buffs, so everyone wears the same best one. | Titles stay cosmetic (ours are) |
| **DevForum** | Overhead tags are BillboardGuis; animated ones tween a UIGradient; big tags "get in the way of seeing things"; custom tags ignore the Show Names setting. | Small client-side tags, distance-limited (and the user's no-clutter rule) |

## Other games

| Game | What it does | What we take |
|---|---|---|
| **Valorant** | A colour "clarity pass" so ranks are easy to tell apart; the top rank renamed because the old name confused players; the act badge fills with your best wins and its border evolves. | Every rank must be easy to tell apart at a glance |
| **League of Legends** | Each tier crest has its own theme and material; players asked for "a focal gemstone ... more shine" at the top; rank shows on the profile, banner, lobby border and loading screen. Taking away an earned border caused anger. | Materials that get grander; never take a look away |
| **Overwatch 2** | Rank once updated only every 7 wins and players hated it; it now shows a progress bar and the reasons after every match. Titles under the name on the versus screen. | Show progress after EVERY meet, with reasons |
| **Rocket League** | Title colour says where it came from (Grand Champion red, Supersonic Legend white). | Colour by tier |
| **Apex Legends** | Badges others see on your banner; only the hardest ranked badge is animated. | Animate only the top |
| **Destiny 2** | Titles from finished collections, shown under the name; "gilding" turns a title gold and adds a counter. Legacy titles that can't be earned any more become the most prestigious. | "2x State Champion" as one title with a count |
| **World of Warcraft** | Titles by the name, from achievements; achievement pop-ups announced to guild and nearby players; guilds complained about 50 to 100 pop-ups a day. | Never spam ceremonies |
| **Clash Royale / Clash of Clans** | The Trophy Road spreads rewards along a road ("the further you progress, the better"); each arena is a floor you can't fall below. | Our rank never goes down; the road shows rewards ahead |
| **Fortnite and battle passes** | Locked rewards stay visible; a special reward at the end of each page. | Show the next rewards greyed out |
| **Duolingo** | A full-screen animated results reveal; a clear promotion line on the board. | The full-screen moment for big steps |
| **Deadlock** | Players said its fun rank names ("Ritualist", "Oracle") had **no clear order**, and two ranks looked alike. The fix they asked for: plain, cool materials low on the ladder, warm, shiny ones high. | **Our biggest risk**: 12 fun names need a material ladder to show the order |
| **CS2** | Rating colours follow the item-rarity order players already know (grey, light blue, blue, purple, pink, red, gold). | Use colours players already read as rarity |

## What this means for our game (the plan)

1. **Every rank name gets a picture, its own material, in a clear order** (the Deadlock lesson): from plain and cool to
   warm, shiny and glowing. Proposed: Fresh Chalk = white chalk, Plate Loader = black rubber, Bar Bender = raw iron,
   Gym Regular = blue steel, Iron Addict = bronze, Platform Pro = silver, Big Total = gold, Plate Crusher = platinum,
   Meet Monster = emerald, Iron Titan = ruby, Record Breaker = diamond, Strength God = glowing cosmic (the only animated
   one, with a slow shimmer). **Levels I to V add pips on the same picture** (one to five small plates), so a new
   level is a small step and a new NAME is a whole new picture.
2. **Show progress after every meet** (Overwatch): a bar to the next rank, the GL points gained, and the kilograms it
   means at your bodyweight ("+6 kg on your total for Big Total II").
3. **Two sizes of moment** (Sol's RNG, WoW): a **new level is a small toast** (about 1.5 s, sound, never blocks the
   screen); a **new name is a full ceremony** (about 3 s, any tap skips): the screen dims, the old emblem cracks, the
   new one slams in with rays and a shake, the name and level appear, then a **CLAIM** button collects the crate,
   coins and luck boost with coins flying to the counter. Sound: a rising swell into a heavy hit, then a crowd roar
   (real meets are loud, never a hush).
4. **A rank road** (Trophy Road, Pet Simulator 99): every name in order with its picture, your spot marked, the next
   ranks and their rewards shown ahead (locked ones greyed), and a **CLAIM** for anything waiting, with a red dot on
   the button while something waits.
5. **Titles screen** (Sol's RNG, Destiny, Overwatch): grouped Feats / Clubs / Meets; **locked titles shown** with how
   to earn them and a progress bar where it counts up (best total 412 / 500 kg); a preview of your nameplate before
   you equip; one tap to equip; NEW tags; "2x" counts for meet titles. Title text in the rarity colours players know:
   Common white, Rare blue, Epic purple, Legendary gold with a slow shimmer.
6. **Others see it, but small** (DevForum, the user's no-clutter rule): over other players' heads a small emblem,
   their name and their title line, only within a short distance and only for the nearest players, made on each
   player's own screen; your rank in the player list. Never big boards over heads.
7. **Announce only the rare** (Sol's RNG, Pet Simulator 99): a server-wide chat line only for reaching the high names
   and the Legendary titles; never for every level.
8. **Never take an earned look away** (League of Legends): a rank never goes down (already decided), and new ranks are
   only ever added on top.
9. **Titles stay cosmetic** (Sailor Piece): no stats on titles.

## Pitfalls to avoid

- Fun names with no visible order; two ranks that look alike (Deadlock, Valorant).
- Hidden or slow progress (Overwatch's old system).
- Ceremony spam (WoW).
- A hidden or awkward equip spot, or a silent unlock (Blox Fruits).
- Big overhead tags that block the view (DevForum; the user's rule).
- Titles with stats (Sailor Piece).
- Taking away an earned look (League of Legends).

## Sources

Roblox: bloxodes.com (Pet Simulator 99 ranks, RIVALS ranks, The Strongest Battlegrounds titles); biggames.io (Pet
Simulator 99 updates 9, 60, 79); allthings.how (RIVALS ranked, Sol's RNG auras); techwiser.com (Sol's RNG
achievements); ofzenandcomputing.com (Blox Fruits titles, Bee Swarm badges); droidgamers.com (Anime Rangers X titles);
sailorpiece.org (titles); devforum.roblox.com (gradient chat tags, nametag systems, Show Names setting).
Other games: playvalorant.com (launch ranks); wiki.leagueoflegends.com (Rank); leagueoflegends.com (progression and
identity changes); overwatch.blizzard.com (competitive update); epicgames.com (Rocket League titles); help.ea.com (Apex
ranked); destinypedia.com (Triumph); warcraft.wiki.gg (Feats of Strength); us.forums.blizzard.com (guild achievement
spam); gamedeveloper.com (battle passes); supercell.com (Trophy Road); duolingo.deconstructoroffun.com (leagues);
forums.playdeadlock.com (rank titles and colours); oneesports.gg (CS2 rating colours).
