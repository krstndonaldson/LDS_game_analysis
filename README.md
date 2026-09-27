# Love and Deepspace — Synthetic Dataset & SQL Analysis

A relational dataset I built from scratch in R and analyzed in MySQL, modelled on Love and Deepspace — a mobile game I play. 
I built this to utilize SQL using data applicable to real life. 


# Background (Very Simplified)

Love and Deepspace is a mobile game where players collect Memories — character cards that unlock story content and boost combat stats. 
Memories are obtained by making a wish (gacha pulling mechanism), which costs in-game currency and returns a random card at one of three rarity tiers: 
- 3-star (common)
- 4-star (uncommon)
- 5-star (rare).
  
The odds are low: a 5-star has a 1% base chance per wish. 
To stop unlucky players from getting nothing, the game uses a pity system:
- After 60 wishes without pulling a 5-star, the odds climb with each wish until a 5-star is guaranteed at wish 70.
- A 4-star is guaranteed at least every 10 wishes. Pulling a card resets its counter.

Players also fight bosses in Bounty Hunt. The highest clear (win) is 3 stars: 
- one star for clearing
- one for finishing with at least 50% HP
- and one for clearing in under 90 seconds.


# The data (csv files)
| Table	| Rows | What it holds |
|---|---|---|
[`players`](love_and_deepspace/data/players.csv)	| 200	| player_id, username, region, join_date |
[`hunts`](love_and_deepspace/data/hunts.csv)	| 2,000 |	 a single Bounty Hunt attempt —> wanderer, stage, companion, cleared, hp_left_pct, clear_secs, stars |
[`wishes`](love_and_deepspace/data/wishes.csv) |	4,733 |	one wish per player —> rarity, pool, currency, wish_number |

Note: each row in hunts is one attempt at a Bounty Hunt stage — one fight, by one player.

All three tables are linked by player_id.


# How it was built

Everything is generated in [`gaming_data.R`](love_and_deepspace/R/gaming_data.R) with set.seed() so the dataset is reproducible.
Considerations made when building this data:

**Activity can't predate signup:** 
> A helper function takes each player's signup date and generates event dates on or after it, so nobody has a hunt or wish recorded before they joined.

**Wish (pull) counts follow a whale distribution:** 
> Real gacha spending is long-tailed — most players pull a little, a few pull enormously — so pull counts are drawn from a log-normal distribution rather than an even spread. The median player makes about 12 wishes; the heaviest hit the 400 cap.

**Pity is actually simulated:** 
> Rather than drawing rarities independently at the published rates, each player's wishes are generated in sequence with counters tracking how long they've gone without each tier. The 5-star chance stays at 1% until wish 60, then climbs 10 points per wish to a guaranteed hit at 70.


# Findings
The advertised 5-star rate only applies to heavy spenders.

Across all wishes, the observed 5-star rate was 1.52% — below the game's published 2.1%. Splitting players by volume explains the gap:
| Group | Players | 5-star rate |
|---|---|---|
| 60+ wishes | 17 (8.5%) | 2.09% |
| Under 60 wishes | 183 (91.5%) | 1.10% |
