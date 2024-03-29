globals
[
  grid-x-inc               ;; the amount of patches in between two roads in the x direction
  grid-y-inc               ;; the amount of patches in between two roads in the y direction
  acceleration             ;; the constant that controls how much a car speeds up or slows down by if
                           ;; it is to accelerate or decelerate
  num-cars-stopped         ;; the number of cars that are stopped during a single pass thru the go procedure

  ;; patch agentsets
  intersections ;; agentset containing the patches that are intersections
  origins       ;; agentset containing the patches that are origins
  destinations  ;; agentset containing the patches that are destinations
  roads         ;; agentset containing the patches that are roads
  speed-limit   ;; patch/tick speed limit
  grid-size-x   ;; width of the network
  grid-size-y   ;; height of the network
                ;; simplified for now to be equal to grid-size slider
]

turtles-own
[
  id          ;; id of the car, coming from python
  speed       ;; the speed of the turtle
  stopped_patch;; the patch that the turtle stopped on (to avoid stopping twice)
  stopped?    ;; if the agent has stopped at the stop sighn or not
  origin      ;; the patch origin of the agent at the edge
  destination ;; the patch destination of the agent at the edge
  main_route  ;; the main_route that does not change by the episode
  route       ;; a string list of "U" "R" "D" depending on the origin and destination
  wait-time   ;; the amount of time since the last time a turtle has moved
  direction   ;; direction of the turtle: "south", "north", "east", "west"
  last_turn   ;; the patch of the last turn (used to avoid the agent turn twice in one intersection)
  turning?     ;; True if the car is turning in the next intersection, False if not
  removed_route? ;; true if the agent is dropping the first direction; false if not
  started?    ;; true if the car has started driving, false if it is still waiting
  in_network? ;; true if the car is inside the square networ, false if it is out
  travel_time ;; travel time of the agent from origin to destination
  start_time  ;; the time that the car starts from the origin each time
  prev_int_x  ;; my_column of previous intersection
  prev_int_y  ;; my_row of previous intersection
  link_on     ;; string representation of two tuples that identify the link
  data        ;; this is the concatenation of id, speed, and link-on of the agent to be transported to python
  iteration   ;; the iteration of the agents, incremented everytime it comes back to the origin
  distance_travelled ;; the distance travelled in "block" unit

]

patches-own
[
  intersection?   ;; true if the patch is at the intersection of two roads
  intersection_id ;; unique if of the interseciton (-1 for non-intersections)
  origin?         ;; true if the pacth is an origin
  destination?    ;; true if the patch is a destination
  my-row          ;; the row of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  my-column       ;; the column of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  directions      ;; empty list for non-road patches and possible combinations of ["north", "south", "east", "west"]
]


;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;

;; Initialize the display by giving the global and patch variables initial values.
;; Create num-cars of turtles if there are enough road patches for one turtle to
;; be created per road patch. Set up the plots.
to setup
  ca
  setup-globals

  ;; First we ask the patches to draw themselves and set up a few variables
  setup-patches

  set-default-shape turtles "car"

  if (num-cars > count roads)
  [
    user-message (word "There are too many cars for the amount of "
                       "road.  Either increase the amount of roads "
                       "by increasing the GRID-SIZE-X or "
                       "GRID-SIZE-Y sliders, or decrease the "
                       "number of cars by lowering the NUMBER slider.\n"
                       "The setup has stopped.")
    stop
  ]
end

to finish-setup
  ;; give the turtles an initial speed
  ask turtles [ set-car-speed ]

  reset-ticks
end

;; Initialize the global variables to appropriate values
to setup-globals
  set num-cars-stopped 0
  set grid-size-x grid-size
  set grid-size-y grid-size
  set grid-x-inc floor((world-width) / grid-size-x)
  set grid-y-inc floor((world-height) / grid-size-y)

  ;; don't make acceleration 0.1 since we could get a rounding error and end up on a patch boundary
  set acceleration 0.099
  set speed-limit 0.5 ;; just looked better than 1.0
end

;; Make the patches have appropriate colors, set up the roads and intersections agentsets,
;; and initialize the traffic lights to one setting
to setup-patches
  ;; initialize the patch-owned variables and color the patches to a base-color
  ask patches
  [
    set intersection? false
    set intersection_id -1
    set my-row -1
    set my-column -1
    set pcolor brown + 3
    set directions []
  ]

  ;; initialize the global variables that hold patch agentsets
  set roads patches with
    [(floor((pxcor + max-pxcor) mod grid-x-inc) = grid-x-inc - 2) or
     (floor((pxcor + max-pxcor) mod grid-x-inc) = grid-x-inc - 1) or
     (floor((pycor + max-pycor) mod grid-y-inc) = grid-y-inc - 2) or
     (floor((pycor + max-pycor) mod grid-y-inc) = grid-y-inc - 1)]

  ask roads with [(floor((pxcor + max-pxcor) mod grid-x-inc) = grid-x-inc - 2)][set directions lput "south" directions]
  ask roads with [(floor((pxcor + max-pxcor) mod grid-x-inc) = grid-x-inc - 1)][set directions lput "north" directions]
  ask roads with [(floor((pycor + max-pycor) mod grid-y-inc) = grid-y-inc - 2)][set directions lput "east" directions]
  ;ask roads with [(floor((pycor + max-pycor) mod grid-y-inc) = grid-y-inc - 1)][set directions lput "west" directions]

  set intersections roads with
      [((floor((pxcor + max-pxcor) mod grid-x-inc) = grid-x-inc - 2) or
        (floor((pxcor + max-pxcor) mod grid-x-inc) = grid-x-inc - 1)) and
       ((floor((pycor + max-pycor) mod grid-y-inc) = grid-y-inc - 2) or
        (floor((pycor + max-pycor) mod grid-y-inc) = grid-y-inc - 1))]
  ask roads [ set pcolor white ]
  setup-intersections

  set origins roads with
      [(pxcor = min-pxcor and member? "east" directions)]
       ;(pycor = min-pycor and member? "north" directions) or
       ;(pxcor = max-pycor and member? "west" directions) or
       ;(pycor = max-pycor and member? "south" directions)
  setup-origins

  set destinations roads with
      [(pxcor = max-pxcor and member? "east" directions)]
       ;(pycor = min-pycor and member? "north" directions) or
       ;(pxcor = max-pycor and member? "west" directions) or
       ;(pycor = max-pycor and member? "south" directions)
  setup-destinations
end

;; Give the intersections appropriate values for the intersection?, my-row, and my-column
;; patch variables.
to setup-intersections
  ask intersections
  [
    set intersection? true
    ifelse max [intersection_id] of neighbors > -1 [
      set intersection_id max [intersection_id] of neighbors
    ][
      set intersection_id max [intersection_id] of intersections + 1
    ]
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
    set pcolor red
  ]
end

;; Color the origins accordingly and give them a appropriate index in my-row
to setup-origins
  ask origins
  [
    set origin? true
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
    set pcolor blue
  ]
end

;; Color the destinations accordingly and give them an appropriate index in my-row
to setup-destinations
  ask destinations
  [
    set destination? true
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
    set pcolor green
  ]
end

to-report get-route [o d]
  let delta_x [my-column] of d - [my-column] of o
  let delta_y [my-row] of d - [my-row] of o
  let r n-values (delta_x - 1) ["east"]
  ifelse delta_y > 0 [
    set r (sentence r n-values delta_y ["north"])
  ][
    set r (sentence r n-values abs(delta_y) ["south"])
  ]
  report (sentence (shuffle r) "east")
end

;; Initialize the turtle variables to appropriate values and place the turtle on an empty road patch.
to setup-cars
  crt num-cars [
    set origin one-of origins
    set destination one-of destinations
    set main_route get-route origin destination
    initialize_car
  ]
end

;; this function sets up each car with, and it runs from python
to setup-car-python [car_id o_y d_y r] ; o_y is the row of the origin
                                        ; d_y is the row of the destination
                                        ; r is the list of the directions or the route
  crt 1 [
    set origin one-of origins with [my-row = o_y]
    set destination one-of destinations with [my-row = d_y]
    set main_route lput "east" r
    set id car_id
    initialize_car
  ]
end

;; initizlizes car parameters
to initialize_car ;; turtle procedure
  set route main_route
  set direction "east"
  set started? False
  set in_network? False
  set turning? False
  set removed_route? False
  set speed 0
  set stopped? False
  set stopped_patch Nobody
  set wait-time 0
  move-to origin
  set last_turn patch-here
  set heading 90 ;; to the east
  set travel_time 0
  set start_time 0
  set prev_int_x 0
  set prev_int_y [my-row] of origin
  set link_on "NA"
  set iteration 0
  set distance_travelled -1

  set data (word id "_" xcor "_" ycor "_" stopped? "_" link_on "_"
                 speed "_" direction "_" (0 - start_time) "_" 0 "_"
                 removed_route? "_" travel_time "_" iteration)
  ht
  record-data
end


;; Find a road patch without any turtles on it and place the turtle there.
to put-on-empty-road  ;; turtle procedure
  move-to one-of roads with [not any? turtles-on self]
end

;; set link-on varibale to the string representation of the link
to set-link-on ;; turtle proceudre
  ifelse direction = "east" [set link_on (word "(" prev_int_x "," prev_int_y "),(" (prev_int_x + 1) "," prev_int_y ")")][
    ifelse direction = "north" [set link_on (word "(" prev_int_x "," prev_int_y "),(" prev_int_x "," (prev_int_y + 1) ")")]
      [set link_on (word "(" prev_int_x "," prev_int_y "),(" prev_int_x "," (prev_int_y - 1) ")")]
  ]
end

;; this function updates the remaining route of an agent coming from python
;; it does not impact the original route (next iteration)
to update_remaining_route [new_route]
    set route lput "east" new_route
end

;; this function updates the original route of an agent (will be taken in the next iteration)
;; it does not impact the remaining route in this iteration
to update_original_route [new_route]
    set main_route lput "east" new_route
end
;;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Run the simulation
to go
  set num-cars-stopped 0

  ;; set the turtles speed for this time thru the procedure, move them forward their speed,
  ;; record data for plotting, and set the color of the turtles to an appropriate color
  ;; based on their speed
  ask turtles
  [
    if not started? [
      if not any? ((turtles-on patch-here) with [started?])[
        set started? True
        st
      ]
    ]


    if started? [
      if not in_network? [
        if intersection? and
        my-row = [my-row] of origin and
        my-column = [my-column] of origin and
        direction = "east" [
          set in_network? True
          set start_time ticks
          set distance_travelled 0
          set prev_int_x 0
          set prev_int_y [my-row] of origin
        ]
      ]

      if in_network? [
        set-link-on
      ]

      set-car-speed
      check_to_turn
      fd speed
      if in_network? [
        set distance_travelled distance_travelled + speed
      ]
      turn
      record-data

      if in_network?[
        if intersection? and
        my-row = [my-row] of destination and
        my-column = ([my-column] of destination - 1) and
        last_turn = intersection_id [
          set in_network? False
          set travel_time ticks - start_time
          set link_on "NA"
          set distance_travelled -1
          set route main_route
          set direction "east"
          set iteration iteration + 1
        ]
      ]
    ]

    if patch-here = destination [
      set started? False
      set turning? False
      set speed 0
      set stopped? False
      move-to origin
      set last_turn patch-here
      set heading 90 ;; to the east
      ht
    ]

    set data (word id "_" xcor "_" ycor "_" stopped? "_" link_on "_"
                   speed "_" direction "_" (ticks - start_time) "_" (distance_travelled / grid-x-inc) "_"
                   removed_route? "_" travel_time "_" iteration)
  ]

  tick
end



;; set the turtles' speed based on whether they are at a red traffic light or the speed of the
;; turtle (if any) on the patch in front of them
to set-car-speed  ;; turtle procedure
  ifelse ([pcolor] of patch-ahead 1 = red) and (pcolor = white) and (not stopped?) and stopped_patch != patch-here
  [ set speed 0
    set stopped? True
    set stopped_patch patch-here
  ]
  [
    set stopped? False
    set-speed
  ]
end

;; set the speed variable of the car to an appropriate value (not exceeding the
;; speed limit) based on whether there are cars on the patch in front of the car
to set-speed ;; turtle procedure
  ;; get the turtles on the patch in front of the turtle
  let turtles-ahead turtles-on patch-ahead 1
  if patch-ahead 2 != nobody [
    set turtles-ahead (turtle-set turtles-ahead turtles-on patch-ahead 2)
  ]

  ;; if there are turtles in front of the turtle, slow down
  ;; otherwise, speed up
  ifelse any? turtles-ahead
  [
    ifelse any? (turtles-ahead with [ direction != [direction] of myself ])
    [
      set speed 0
    ]
    [
      set speed [speed] of min-one-of turtles-ahead [distance myself]
      slow-down
    ]
  ]
  [ speed-up ]
end

;; decrease the speed of the turtle
to slow-down  ;; turtle procedure
  ifelse speed <= 0  ;;if speed < 0
  [ set speed 0 ]
  [ set speed speed - acceleration ]
  if speed < 0 [set speed 0] ;;;; NO NEGATIVE SPEED
end

;; increase the speed of the turtle
to speed-up  ;; turtle procedure
  ifelse speed > speed-limit
  [ set speed speed-limit ]
  [ set speed speed + acceleration ]
  if speed > speed-limit [set speed speed-limit] ;;; NO SPEED GREATER THAN SPEED LIMIT
end


;; check if the agent needs to and can take a turn
to check_to_turn
    set removed_route? False
    if intersection? and
       last_turn != intersection_id and
       speed > distance patch-here and
       member? (item 0 route) directions
    [
      let current_direction direction
      set direction item 0 route
      set route remove-item 0 route
      set removed_route? True
      set last_turn intersection_id
      set prev_int_x my-column
      set prev_int_y my-row
      if current_direction != direction [
        set speed distance patch-here
        set turning? True
      ]
    ]
end

;; take a turn
to turn
  if turning? [
    set turning? False
    ifelse direction = "north" [
      set heading 0
    ][
      ifelse direction = "east" [
        set heading 90
      ][
        ifelse direction = "south" [
          set heading 180
        ]
        [
          set heading 270
        ]
      ]
    ]
  ]
end


;; keep track of the number of stopped turtles and the amount of time a turtle has been stopped
;; if its speed is 0
to record-data  ;; turtle procedure
  ifelse speed = 0
  [
    set num-cars-stopped num-cars-stopped + 1
    set wait-time wait-time + 1
  ]
  [ set wait-time 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
296
10
932
667
19
19
16.0541
1
12
1
1
1
0
0
1
1
-19
19
-19
19
1
1
1
ticks
30.0

PLOT
10
545
290
665
Average Wait Time of Cars
Time
Average Wait
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [wait-time] of turtles"

PLOT
10
290
290
410
Average Speed of Cars
Time
Average Speed
0.0
100.0
0.0
0.0
true
false
"set-plot-y-range 0 speed-limit" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [speed] of turtles"

SLIDER
7
10
197
43
grid-size
grid-size
1
9
5
1
1
NIL
HORIZONTAL

SLIDER
8
47
196
80
num-cars
num-cars
1
100
100
1
1
NIL
HORIZONTAL

PLOT
9
418
290
538
Stopped Cars
Time
Stopped Cars
0.0
100.0
0.0
100.0
true
false
"set-plot-y-range 0 num-cars" ""
PENS
"default" 1.0 0 -16777216 true "" "plot num-cars-stopped"

BUTTON
203
48
288
81
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
204
11
288
44
Setup
setup\nsetup-cars\nfinish-setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
10
91
290
286
Average Travel Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [travel_time] of turtles"

@#$#@#$#@
MULTIAGENT ROUTING SIMULATOR
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 180 15 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 285 165 285 225 285 225 15 180 15
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
