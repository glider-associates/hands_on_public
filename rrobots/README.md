# How to setup
```
brew install sdl2
bundle install
```

# How to play
```
RUBYLIB=lib bundle exec ./bin/rrobots --resolution=1500,1500 tanks/samples/simple.rb tanks/samples/simple.rb
```

# Team battle rule
```
1. Leader robot's energy is 2.0 times.
2. Bot's energy is 1.5 times, but they don't have radar.
   So you need to tell them information from other Robot.
```

# Based on
https://github.com/logankoester/rrobots

# Study
## Set my robot
```
ex > export MY_ROBOT=tanks/my_robot.rb
```

## Entry level (700x700)
1. Win 9 games in 10 games against Simple
   Need to turn gun effectively.
2. Win 9 games in 10 games against Shooter
   Need move to avoid getting hit.
3. Win 9 games in 10 games against QuickShooter
   Need move to avoid getting hit.

```
1. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/simple --no-gui
2. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/shooter --no-gui
3. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/quick_shooter --no-gui
```


## Basic level(700x700)
10. Get 4500 score in 10 games against Aiming
   Need move complicatedly.
11. Get 4500 score in 10 games against Wall
   Need to aim uniform speed liner moving targets.
12. Get 4500 score in 10 games against Circle
   Need to aim uniform acceleration moving targets.
13. Get 4500 score in 10 games against Swing
   Need to aim patterned moving targets.

```
10. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/aiming --no-gui
11. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/wall --no-gui
12. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/circle --no-gui
13. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/swing --no-gui
```

## Advansed level(700x700)
20. Get 4500 score in 10 games against WallShooter
21. Get 4500 score in 10 games against CircleShooter
22. Get 4500 score in 10 games against SwingShooter

```
20. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/wall_shooter --no-gui
21. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/circle_shooter --no-gui
22. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/swing_shooter --no-gui
```

## Master1(1000x1000)
23. Get 5500 score in 10 games against WallShooter, CircleShooter and SwingShooter

```
23. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=1000,1000 $MY_ROBOT tanks/samples/wall_shooter tanks/samples/circle_shooter tanks/samples/swing_shooter --no-gui
```

## Master2(700x700)
31. Get 4000 score in 10 games against WallWithAiming
32. Get 4000 score in 10 games against CircleWithAiming
33. Get 4000 score in 10 games against SiwingWithAiming

```
30. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/wall_with_aiming --no-gui
31. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/circle_with_aiming --no-gui
32. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/swing_with_aiming --no-gui
```

## Master3(1000x1000)
34. Get 5000 score in 10 games against WallWithAiming, CircleWithAiming and SwingWithAiming

```
34. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=1000,1000 $MY_ROBOT tanks/samples/wall_with_aiming tanks/samples/circle_with_aiming tanks/samples/swing_with_aiming --no-gui
```

## Master4(700x700)
50. Get 4000 score in 10 games against RandomCrawler

```
50. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/samples/random_crawler --no-gui
```

## Master5(1000x1000)
60. Get 2500 score in 10 games against Reaction

```
60. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=1000,1000 $MY_ROBOT tanks/samples/reaction --no-gui
```

## Battle royale(3000x3000)
100. Get 7000 score in 10 games against All sample robots

```
100. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=3000,3000 $MY_ROBOT tanks/samples/simple tanks/samples/shooter tanks/samples/quick_shooter tanks/samples/wall_shooter tanks/samples/circle_shooter tanks/samples/swing_shooter tanks/samples/wall_with_aiming tanks/samples/circle_with_aiming tanks/samples/swing_with_aiming tanks/samples/reaction tanks/samples/random_crawler --no-gui
```

## Team1(2000x2000)
200. Get 7000 score in 10 games against All sample robots

```
200. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=2000,2000 $MY_ROBOT $MY_ROBOT2 $MY_ROBOT3 tanks/samples/circle_shooter tanks/samples/swing_shooter tanks/samples/wall_shooter --teams=3 --no-gui
```

## Ace1(1500x1500)
300. Get 6000 score in 10 games using 3 unit (robots or bots) team against circle_shooter, swing_shooter and wall_shooter team.

```
300. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=1500,1500 $MY_ROBOT tanks/samples/circle_shooter tanks/samples/swing_shooter tanks/samples/wall_shooter --teams=1 --no-gui
```

# Team2(2000x2000)
400. Win by score in 10 games using 3 unit (robots or bots) team against circle_aiming, swing_aiming and wall_aiming team.
401. Win by score in 10 games using 3 unit (robots or bots) team against 3 random_crawlers team.

```
400. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=2000,2000 $MY_ROBOT $MY_ROBOT1 $MY_ROBOT2 tanks/samples/circle_with_aiming tanks/samples/swing_with_aiming tanks/samples/wall_with_aiming --teams=3 --no-gui
402. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=2000,2000 $MY_ROBOT $MY_ROBOT1 $MY_ROBOT2 tanks/samples/random_crawler tanks/samples/random_crawler tanks/samples/random_crawler --teams=3 --no-gui
```

## Nightmare1(700x700)
500. Win by score in 10 games against Kubota (勝てるもんなら勝ってみろ！！)

```
500. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=700,700 $MY_ROBOT tanks/kubota --no-gui
```

## Nightmare2(1000x1000)
600. Win by score in 20 games against Kubota (勝てるもんなら勝ってみろ！！)

```
600. RUBYLIB=lib bundle exec ./bin/rrobots --match=20 --resolution=1000,1000 $MY_ROBOT tanks/kubota --no-gui
```
# Ace2(1500x1500)
700. Win by score in 10 games against circle_aiming, reaction and random_crawler team.
701. Win by score in 10 games against circle_aiming, swing_aiming and wall_aiming team.
702. Win by score in 10 games against 3 random_crawlers team.

```
700. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=1500,1500 $MY_ROBOT tanks/samples/reaction tanks/samples/random_crawler --teams=1 --no-gui
701. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=1500,1500 $MY_ROBOT tanks/samples/circle_with_aiming tanks/samples/swing_with_aiming tanks/samples/wall_with_aiming --teams=1 --no-gui
702. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=1500,1500 $MY_ROBOT tanks/samples/random_crawler tanks/samples/random_crawler tanks/samples/random_crawler --teams=1 --no-gui
```

## Hell(1500x1500)
777. Win score in 20 games against KubotaAdvance

```
777. RUBYLIB=lib bundle exec ./bin/rrobots --match=20 --resolution=1500,1500 $MY_ROBOT tanks/kubota_advance --no-gui
```

## Team(2000x2000)
```
999. RUBYLIB=lib bundle exec ./bin/rrobots --match=10 --resolution=2000,2000 $MY_ROBOT $MY_ROBOT1 $MY_ROBOT2 tanks/kubota_advance tanks/kubota_advance_bot tanks/kubota_advance_bot --teams=3 --no-gui
```



# Robot interface
## Definitions
* **battlefield_height** - the height of the battlefield
* **battlefield_width** - the width of the battlefield
* **size** - your robots radius, if x <= size you hit the left wall

## Global attributes
* **time** - ticks since match start
* **num_robots** - number of living robots
* **gui** - true if GUI enabled
* **round** - the number of rounds of matches

## Robot status
* **energy** - your remaining energy (if this drops below 0 you are dead)
* **speed** - your speed (-8..8)
* **gun_heading** - the heading of your gun, 0 pointing east, 90 pointing north, 180 pointing west, 270 pointing south
* **gun_heat** - your gun heat, if this is above 0 you can't shoot
* **heading** - your robots heading, 0 pointing east, 90 pointing north, 180 pointing west, 270 pointing south
* **radar_heading** - the heading of your radar, 0 pointing east, 90 pointing north, 180 pointing west, 270 pointing south
* **x** - your x coordinate, 0...battlefield_width
* **y** - your y coordinate, 0...battlefield_height

## Robot actions
* **accelerate** - accelerate (max speed is 8, max accelerate is 1/-1, negativ speed means moving backwards)
* **fire** - fires a bullet in the direction of your gun, power is 0.1 - 3, this power is taken from your energy
* **turn** - turns the robot (and the gun and the radar), max 10 degrees per tick
* **turn_gun** - turns the gun (and the radar), max 30 degrees per tick
* **turn_radar** - turns the radar, max 60 degrees per tick

## Robot auto & callback I/F
* **enable_callbacks** - Enable callback I/F
* **enable_callbacks** - Enable callback I/F
* **scanned** - Callback with `events['robot_scanned']` when scanned some robots
* **crashed_into_enemy** - Callback with `events['crash_into_enemy']` when crashed into enemies
* **crashed_into_wall** - Callback with `events['crash_into_wall']` when crashed into wall
* **hit** - Callback with `events['hit']` when hit my bullets
* **got_hit** - Callback with `events['crash']` when got hit by someone's bullets
* **turned** - Callback when finished `auto_turn`
* **accelerated** - Callback when finished `auto_accelerate`
* **stopped** - Callback when finished `auto_stop`
* **gun_turned** - Callback when finished `auto_turn_gun`
* **radar_turned** - Callback when finished `auto_turn_radar`
* **auto_turn** - Turn the robot by specified angle automatically, will callback `turned` when finished
* **auto_accelerate** - Accelerate robot during specified ticks, will callback `accelerated` when finished
* **auto_stop** - Stop robot automatically, will callback `stopped` when finished
* **auto_turn_gun** - Turn the gun by specified angle automatically, will callback `gun_turned` when finished
* **auto_turn_radar** - Turn the radar by specified angle automatically, will callback `radar_turned` when finished

## Team
* **team** - Your team number
* **team_members** - Your team member names
* **name** - Your robot name
* **team_message** - Send message to team_members, it will be recieved them as events['robot_scanned'].

## Robot storage
* **durable_context** - durable context among all matches

## Robot colors
* **font_color** - ['white', 'blue', 'yellow', 'red', 'lime']
* **body_color** - ['white', 'blue', 'yellow', 'red', 'lime']
* **turrent_color** - ['white', 'blue', 'yellow', 'red', 'lime']
* **radar_color** - ['white', 'blue', 'yellow', 'red', 'lime']
