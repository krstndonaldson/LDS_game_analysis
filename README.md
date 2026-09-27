# Love and Deepspace — Synthetic Dataset & SQL Analysis

A relational dataset I built from scratch in R and analyzed in MySQL, modelled on Love and Deepspace — a mobile game I play. 
I built this to utilize SQL using data applicable to real life. 

## Background (Very Simplified)

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

## The data (csv files)
| Table	| Rows | What it holds |
|---|---|---|
[`players`](data/players.csv)	| 200	| player_id, username, region, join_date |
[`hunts`](data/hunts.csv)	| 2,000 |	 a single Bounty Hunt attempt —> wanderer, stage, companion, cleared, hp_left_pct, clear_secs, stars |
[`wishes`](data/wishes.csv) |	4,733 |	one wish per player —> rarity, pool, currency, wish_number |

Note: each row in hunts is one attempt at a Bounty Hunt stage — one fight, by one player.
All three tables are linked by player_id.
