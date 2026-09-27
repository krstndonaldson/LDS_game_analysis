CREATE DATABASE love_and_deepspace;
USE love_and_deepspace; -- set as default db

-- Check the import: row counts should match the R output
SELECT COUNT(*) FROM players; -- expect 200
SELECT COUNT(*) FROM hunts;   -- expect 2000
SELECT COUNT(*) FROM wishes;  -- expect 4733

-- Preview Tables
SELECT * FROM players LIMIT 5;
SELECT * FROM hunts LIMIT 5;
SELECT * FROM wishes LIMIT 5;

-- Players in Asia, newest signup first - e.g. targeting invites for a regional event
SELECT player_id, username, join_date
FROM players
WHERE region = 'Asia'
ORDER BY join_date DESC;

-- Hunts with 3-stars on Snoozer, fastest clear first 
-- leaderboard / difficulty tuning / spotting suspicious clears
SELECT hunt_id, wanderer, stars, clear_secs
FROM hunts
WHERE stars = 3 AND wanderer = 'Snoozer'
ORDER BY clear_secs;

-- How many hunts were cleared?
SELECT cleared, COUNT(*) AS n
FROM hunts
GROUP BY cleared;

-- Top 10 most active players
SELECT player_id,
	COUNT(*) AS total_hunts
FROM hunts
GROUP BY player_id
ORDER BY total_hunts DESC
LIMIT 10;

-- Hunt volume by month
SELECT MONTH(hunt_date) AS month, 
	COUNT(*) AS hunts
FROM hunts
GROUP BY MONTH(hunt_date)
ORDER BY month;

-- How star ratings are distributed overall
SELECT stars, COUNT(*) AS n_hunts,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM hunts), 1) AS pct
FROM hunts
GROUP BY stars
ORDER BY stars;

-- Clear times bucketed
SELECT CASE
         WHEN clear_secs < 60  THEN 'under 60s'
         WHEN clear_secs < 90  THEN '60-89s'
         WHEN clear_secs < 120 THEN '90-119s'
         ELSE '120s+'
       END AS time_bucket,
       COUNT(*) AS n_hunts
FROM hunts
GROUP BY time_bucket
ORDER BY n_hunts DESC;

-- How many wishes landed at each rarity?
SELECT rarity, COUNT(*) AS n_wishes
FROM wishes
GROUP BY rarity
ORDER BY rarity;

-- Do the simulated rates match the game's published rates?
SELECT rarity,
       COUNT(*) AS n_wishes,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM wishes), 2) AS pct
FROM wishes
GROUP BY rarity
ORDER BY rarity;

-- Pull type distribution
WITH player_totals AS(
	SELECT player_id, 
		COUNT(*) AS total_wishes,
		CASE WHEN COUNT(*) >= 60 THEN 'heavy' ELSE 'light' END AS puller_type
FROM wishes
GROUP BY player_id
)
SELECT puller_type, COUNT(*) AS players
FROM player_totals
GROUP BY puller_type
ORDER BY puller_type;

-- Do heavy pullers actually get a better 5 star rate?
WITH player_totals AS (
  SELECT player_id,
         CASE WHEN COUNT(*) >= 60 THEN 'heavy' ELSE 'light' END AS puller_type
  FROM wishes
  GROUP BY player_id
)
SELECT pt.puller_type,
       COUNT(*) AS wishes_pulled,
       SUM(w.rarity = '5-star') AS five_stars, -- test if true; add all 1s if true
       ROUND(SUM(w.rarity = '5-star') * 100.0 / COUNT(*), 2) AS five_star_pct
FROM wishes w
JOIN player_totals pt ON w.player_id = pt.player_id
GROUP BY pt.puller_type
ORDER BY puller_type;

-- Number each player's wishes and show the running count
SELECT player_id, wish_number, rarity,
       COUNT(*) OVER (PARTITION BY player_id) AS total_wishes_by_player
FROM wishes
ORDER BY player_id, wish_number
LIMIT 20;

-- Only show wishes that hit 4 or 5 star, with what came before
SELECT player_id, wish_number, rarity, previous_rarity
FROM (
  SELECT player_id, wish_number, rarity,
         LAG(rarity) OVER (PARTITION BY player_id ORDER BY wish_number) AS previous_rarity
  FROM wishes
) t
WHERE rarity IN ('4-star', '5-star')
LIMIT 20;

-- How many wishes between each 5-star?
SELECT player_id, wish_number,
       wish_number - LAG(wish_number) OVER (PARTITION BY player_id ORDER BY wish_number) AS wishes_since_last_5star
FROM wishes
WHERE rarity = '5-star'
ORDER BY player_id, wish_number;


-- Validation that pity simulation is fixed with correct wish dates
SELECT MAX(wishes_since_last_5star) FROM (
  SELECT wish_number - LAG(wish_number) OVER (PARTITION BY player_id ORDER BY wish_number) AS wishes_since_last_5star
  FROM wishes
  WHERE rarity = '5-star'
) t;
