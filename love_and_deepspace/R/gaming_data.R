# --------------------------------------------------------------------------------------------------
# This is based on Love and Deepspace since I play this casually in my free time

# Context: 

# I am using one battle type: Bounty Hunt. 
# Bounty Hunt has 5 wanderer types (enemies you have to defeat)
# Each Wanderer has different rewards but the overall goal is to get a 3 star pass based on:
# Stage cleared
# HP no less than 50%
# Win in 90 sec
# Each wanderer has 9 stage levels to clear

# I am using R as synthetic data of "millions of players over 12 months" 
# to generate the log the game servers would have collected
# but in this case I am using 200 players because this is just a mockup.
# --------------------------------------------------------------------------------------------------




library(tidyverse)
library(randomNames)
set.seed(100)

# ------------------------- Players table -----------------------------------------------------------
n_players <- 200

players <- tibble(
  player_id = sample(100000:999999, n_players, replace = FALSE),
  username = randomNames(n_players, which.names = "first", gender = 1),
  region = sample(c("Americas", "Europe", "Asia", "Oceania"), n_players, replace = TRUE),
  join_date = sample(seq(as.Date("2025-01-01"), 
                             as.Date("2026-01-01"), 
                             by = "day"), 
                         n_players, 
                         replace = TRUE)
)
# ---------------------------------------------------------------------------------------------------




# ----------------------------------- Helper Function -----------------------------------------------

# Instructions for function random_player_event_dates()
# Enter the number of rows you want to generate
# Enter the last date of signup/join recorded in your players table
# Example: function random_player_signup_dates(2000, 2026-01-01)

# Note event refers to any thing the player does once they join the game
# Hence why this function exists. 
# We don't want a player having a hunt or wish date before sign up ...

random_player_event_dates <- function(n, activity_cutoff){
  picked <- tibble(player_id = sample(players$player_id, n, replace = TRUE)) # one column "table"; this is for picking "who"
  
  picked <- left_join(picked, select(players, 
                                     player_id, 
                                     join_date), 
                      by = "player_id") # adds extra necessary columns
  
  #n days added to the join_date to find an appropriate date
  picked <- mutate(picked,
                   #runif() = random decimals in a range (0 to cutoff day; it could be 92, depends on the player's join_date)
                   #eg., the min is 0, join_date + 0 is appropriate since a user can have event happening on the same day they joined
                   #also floor is to get rid of decimal (just keep whole numbers) also this is intentional because I want to keep zero in my range
                   event_date = join_date + floor(runif(n, 0, as.numeric(activity_cutoff - join_date) + 1)) #just add 1 to make up for the rounded down value
  )
  select(picked, 
         player_id, 
         event_date)
}
# --------------------------------------------------------------------------------------------------------




# ---------------------------------- Bounty Hunt Table (type of battle in L&D) ---------------------------

n_hunts <- 2000 #random hunts regardless of "wanderer hunt stage" and "stage level" per wanderer 
end_date <- as.Date("2026-01-01")

# Doing this in steps so it easy to follow the table structure 

# 1. get players + valid dates from the helper function
hunts <- random_player_event_dates(n_hunts, end_date)
  
# 2. okay so the hunts table has the generic name from our function so let's fix that?
hunts <- rename(hunts, hunt_date = event_date)  

# 3. Adding the additional columns now 
hunts <- mutate(hunts,
  hunt_id = sample(1000:9999, n_hunts, replace = FALSE),
  wanderer = sample(c("Mr. Beanie", "Heartbreaker", "Pumpkin Magus", "Lemonette", "Snoozer"), n_hunts, replace = TRUE),
  stage = sample(1:9, n_hunts, replace = TRUE),
  companion = sample(c("Xavier", "Zayne", "Rafayel", "Sylus", "Caleb"), n_hunts, replace = TRUE),
  cleared = sample(c(TRUE, FALSE), n_hunts, replace = TRUE, prob = c(0.80,0.20)),
  clear_secs = round(runif(n_hunts, 30, 150)), #just random timing I picked
  hp_left_pct = round(runif(n_hunts, 0, 100)),
  stars = cleared + (cleared & hp_left_pct >= 50) + (cleared & clear_secs <= 90) #this works because you get 1s or 0s
)

select(hunts, hunt_id, player_id, hunt_date, everything())
# ----------------------------------------------------------------------------------------------------------------------------




# ---------------------------- Wishes Table ----------------------------------------------------------------------------------

# A "wish" is the game's gacha pull: the player spends currency and receives a
# random Memory (character card) at one of three rarity tiers — 3-star (common),
# 4-star (uncommon), or 5-star (rare).

# The odds are low: a 5-star has a 1% base chance per wish. To stop unlucky
# players from getting nothing, the game uses a PITY system:
#   - after 60 wishes without pulling a 5-star, the chance climbs each wish
#     until a 5-star is guaranteed at wish 70
#   - a 4-star is guaranteed at least every 10 wishes
#   - pulling a card resets that card's counter

# This section simulates that mechanic, so rarity is not drawn independently —
# each wish depends on how many wishes the player has gone without a "hit".

# Step-by_step of wishes table

# --- Step 1
# Each player pulls a different amount. Real gacha spending is long-tailed —
# most players pull a little, a few "whales" pull a lot — so we draw from a
# skewed distribution rather than an even spread.
player_pull_counts <- tibble(
  player_id = players$player_id,
  n_pulls   = round(rlnorm(nrow(players), meanlog = 2.5, sdlog = 1.1))
)

# NOTE
# I just picked these two numbers by trying them and checking the result looked like a real game.
# meanlog = 2.5 controls where most players sit. 
# sdlog = 1.1 controls how extreme whales get.




# --- Step 2
# Keep everyone in a sensible range: at least 1 pull, cap at 400
player_pull_counts <- mutate(player_pull_counts,
                             n_pulls = pmin(pmax(n_pulls, 1), 400)
)
# First pmax looks a row then compares it to 1, 
# then it picks the bigger value. Then another requirement is wrapped in to check if that number is over 400. 
# pmin will pick 400 if that row has a number higher.


# *** Check Stats *** / just testing the distribution here :)
summary(player_pull_counts$n_pulls)
sum(player_pull_counts$n_pulls)




# --- Step 3
# Pity Simulation Function

# Return: character vector of rarities, one per wish, in order
# Parameters: n = how many wishes this player makes
# Purpose: simulates one player's wishes using the game's pity rules
simulate_wishes <- function(n) {
  
  # somewhere to store each result
  results <- character(n) # holds text, since the results are "3-star", "4-star", "5-star".
  
  # Pity counters: both starting at zero since the player hasn't tried pulling yet
  since_5star <- 0 # how many wishes since their last 5-star
  since_4star <- 0 # how many wishes since their last 4-star
  
  for (i in 1:n) {
    
    # 5-star chance: flat 1% until 60, then climbs 10 points per wish
    if (since_5star < 60) {
      chance_5 <- 0.01
    } else {
      chance_5 <- min(0.01 + (since_5star - 59) * 0.10, 1)
    }
    # Explanation: 
    # After 60 wishes without a 5-star, each subsequent wish adds roughly 10 percentage points until it reaches 100% at wish 70.
    # If they've gone fewer than 60 wishes without a 5-star: flat 1% (0.01). Nothing special happening.
    # If they're at 60 or more: soft pity. 
    # since_5star - 59 gives how far past the threshold they are — at 60 that's 1, 
    # at 61 it's 2, and so on. 
    # Multiply by 0.10 and add the base 1%:
    
    # min(..., 1) caps it at 1, since a probability can't exceed 100%. 
    # That's hard pity — guaranteed.
    
    
    pull <- runif(1)   # one random number between 0 and 1 
    # This is the actual pull. The random draw that decides *what* this wish gives you.
    
    
    # The odds define a "win zone" from 0 up to chance_5.
    # A random draw between 0 and 1 either lands in that zone (hit) or not.
    # Bigger odds = bigger zone = more hits.
    if (pull < chance_5) {
      results[i]  <- "5-star"
      since_5star <- 0
      since_4star <- 0
      
      
      # Not a 5-star, so check for a 4-star. 
      # Two ways to get one: the guarantee fired (9 misses, so this is the 10th), 
      # or the draw landed in the 7% zone.
    } else if (since_4star >= 9 || pull < 0.07) {
      results[i]  <- "4-star"
      since_5star <- since_5star + 1 # but bump the 5-star counter since they still didn't get a 5-star.
      since_4star <- 0 # reset the 4-star counter since you got a "hit"
      # The game's actual rule is that 4-star pulls don't affect 5-star pity.
      
      
      # Missed both. 
      # Store "3-star" and bump both counters, since they went another wish without either tier.
    } else {
      results[i]  <- "3-star"
      since_5star <- since_5star + 1
      since_4star <- since_4star + 1
    }
  }
  
  results
}


# *** Testing *** /
test <- simulate_wishes(200)
table(test)

# positions of 5-stars — none should exceed 70
# the 5-stars landed on wishes 35, 98, 108 and 170.
diff(which(test == "5-star"))
# All under 70, so the hard pity ceiling held.




#--- Step 4
# ---- Part 1: Building Wishes that generate obtaining memories (an item) 

# 1. run the simulation for each player, giving each one their own wish sequence
# map() runs simulate_wishes() once per player, passing that player's n_pulls.
# Each player's row now holds their whole sequence of rarities bundled in one cell.
# unnest() unpacks those bundles into real rows 
# example: a player with 12 pulls becomes 12 rows, each carrying their player_id.
wishes <- player_pull_counts |>
  mutate(rarity = map(n_pulls, simulate_wishes)) |>
  unnest(rarity)

# *** Testing *** /
nrow(wishes) 




# 2. number each player's wishes in order
# Drop n_pulls — it's the same number repeated on every row of that player, 
# so it's redundant once the rows exist.
# wish number per player? which wish in their sequence this was.
wishes <- wishes |>
  group_by(player_id) |>
  mutate(wish_number = row_number()) |>
  ungroup() |>
  select(-n_pulls)

# *** Testing *** /
head(wishes, 15)




# 3. Give each wish a date. 
wishes <- left_join(wishes,
                    select(players, player_id, join_date),
                    by = "player_id")

end_date <- as.Date("2026-01-01")
wishes <- mutate(wishes,
                 # n() = number of rows currently in the table, so this works without
                 # hardcoding the row count
                 wish_date = join_date + floor(runif(n(), 0, as.numeric(end_date - join_date) + 1))
)




# 4. The dates came out random, so wish 1 could be dated after wish 20. Fix this:
# The simulation produced each player's wishes in order, so keep that order and
# sort the dates to match. Wish 1 is both the first pull and the earliest date.
wishes <- wishes |>
  group_by(player_id) |>
  mutate(wish_date = sort(wish_date),
         wish_number = row_number()) |>
  ungroup() |>
  select(-join_date)

head(wishes)


# ---- Part 2: the pool and currency columns.

# 5. Assign the wish pool. Rippling Echo is the novice pool — only available
#    for a player's first 50 wishes — so it's restricted by wish_number rather
#    than assigned at random.
wishes <- mutate(wishes,
                 wish_id = sample(10000:99999, n(), replace = FALSE),
                 pool = if_else(
                   wish_number <= 50 & runif(n()) < 0.35,
                   "Rippling Echo",
                   sample(c("XSpace Echo", "Limited"), n(), replace = TRUE, prob = c(0.40, 0.60))
                 ),
                 # Only Limited pools consume Deepspace Wishes; the rest use Empyrean.
                 currency = if_else(pool == "Limited", "Deepspace Wish", "Empyrean Wish")
)
                 




# 6. put wish_id first
wishes <- select(wishes, wish_id, player_id, wish_date, wish_number, everything())
# --------------------------------------------------------------------------------------------------------

# --------------------------------------------------- END ------------------------------------------------




