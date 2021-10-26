globals[
        price ;price of good
        population ;total number of citizens
        #_sellers ;number of active sellers in market
        #_demanders ;number of consumers with effective demand
        #_init_consumers ;number of potential consumers
        force_size ;size of initial police force
        poor_incarcerated
        lower_middle_incarcerated
        upper_middle_incarcerated
        rich_incarcerated
        poor
        lower_middle
        upper_middle
        consumption_time ;time it takes a consumer to consume a purchase
        gov_stipend ;;abstract form of income paid to citizens each turn
        ]

breed [LEAs LEA]
breed [citizens citizen]

citizens-own[income
       consumer_condition
       possession
       seller_possession
       remaining_possession
       incarcerated
       incarcerated_as ;variable that states what class agent was incarcerated as: 0 = poor, 1 = lower middle, 2 = upper middle, 3 = rich
       jail_term
       risk_aversion
       threshold ;value at which citizen is willing to become buyer/seller
       ESD ;effective seller demand (aspiring seller)
       ECD ;effective consumer demand (aspiring possessor)
       ]


to setup
  clear-all
  set price 13
  set gov_stipend 1
  set consumption_time 5
  set poor_incarcerated 0
  set lower_middle_incarcerated 0
  set upper_middle_incarcerated 0
  set rich_incarcerated 0
  set poor 400
  set lower_middle 500
  set upper_middle 600
  setup-citizens
  setup-LEA
  reset-ticks
end


to Go
  move-turtles ;causes agents to move around environment
  ;distribute-stipends ;stipends are paid to non-incarcerated citizens
  perform-transactions ;transactions are completed
  update-market ;update changes in agent states/update price
  perform-arrests ;arrests are made by LEA
  release-prisoners
  perform-census
  modify-force
  tick
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Population of LEAs created based on user   ;;
;; defined variable "LEA Density"             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-LEA
  set force_size (LEA_Density / 100) * Citizen_Density ;;number of LEAs
  create-LEAs force_size
  ask LEAs [set shape "LEA"]
  ask LEAs [setxy random-xcor random-ycor]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sets up citizen variables, by default makes;;
;; every citizen type III. Once all citizens  ;;
;; have been set to III, setup consumer method;;
;; is called to setup type I citizens.        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-citizens
  set population Citizen_Density - ((LEA_Density / 100) * Citizen_Density) ;number of citizens
  create-citizens population
  ask citizens [setxy random-xcor random-ycor]
  ask citizens [set shape "iii"]
  ask citizens [set incarcerated false]
  ask citizens [set consumer_condition false]
  ask citizens [set possession false]
  ask citizens [set seller_possession false]
  ask citizens [set ECD false]
  ask citizens [set ESD false]
  ask citizens [set threshold random-normal 0 30] ;threshold is assigned based on random normal distribution, with median of 10 and SD of 20
  ask citizens [set remaining_possession 0]
  ask citizens [set risk_aversion random-float 1.0] ;random value between 0-1, representing agent's aversion to risk
  ask citizens [set jail_term 0]
  ask citizens [setup-income]
  setup-consumers
  setup-sellers
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sets up incomes of citizens based on     ;;
;; normal distribution, with a mean of      ;;
;; 500 and a standard deviation of 150      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-income
  let m 500
  let s 150
  let x random-normal m s;
  set income x
  ;show income
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates population of type I-c consumers ;;
;; based on user-defined "consumption %".   ;;
;; These citizens are NOT possessors upon   ;;
;; initialization, but have potential to    ;;
;; become I-a                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-consumers
  let _count 0
  set #_init_consumers (Consumption_Rate / 100) * (Citizen_Density - ((LEA_Density / 100) * Citizen_Density)) ;calculates number of type I citizens
  loop[
    ;if count is greater than the number of agents who are potential consumers...stop loop
    if _count >= #_init_consumers - 1 [stop]
    ask citizen _count [set consumer_condition true] ;makes cons_num citizens type I
    ask citizen _count [set ECD true] ;makes cons_num citizens type I
    set _count _count + 1
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates population of type II-a sellers by;;
;; randomly selecting n agents to be initial ;;
;; sellers, where n is equal to the number of;;
;; consumer-citizens (I-c) divided by 4.     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-sellers
  let _count 0
  loop[
    if _count >= (#_init_consumers / 4) [stop]
    ask one-of citizens [
      set seller_possession true
      set shape "ii-a"
      ]
    set _count _count + 1

  ]
  set #_sellers _count
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All agents move one space every turn in  ;;
;; random 360-degree direction              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to move-turtles
  ask turtles[
    right random 360
    forward 1
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All non-incarcerated agents recieve a gov;;
;; stipend each turn, in the amount set by  ;;
;; global variable                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to distribute-stipends
  ask citizens[
    if incarcerated = false [set income income + gov_stipend]
  ]
  set poor poor + gov_stipend
  set lower_middle lower_middle + gov_stipend
  set upper_middle upper_middle + gov_stipend
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Transactions between agents occur, income;;
;; levels are updated and appropriate state ;;
;; changes are completed.                   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to perform-transactions
  ask citizens with [ECD][
        if any? (citizens-on neighbors) with [seller_possession]
        [
          let seller one-of (citizens-on neighbors) with [seller_possession]
          set possession true
          set income income - price
          set ECD false
          set remaining_possession consumption_time
          ask seller [set income income + price]
        ]
    ]
  ask citizens with [ESD][
    if any? (citizens-on neighbors) with [seller_possession]
    [
      let seller one-of (citizens-on neighbors) with [seller_possession]
      set seller_possession true
      set shape "ii-a"
      set ESD false
      set income income - price
      ask seller [set income income + price]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Price is updated, agents make transition ;;
;; states based on new market information   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to update-market
  transform-demand
  transform-supply
  set #_demanders 0
  set #_sellers 0
  ask citizens[if (ECD = true) [set #_demanders #_demanders + 1]]
  ask citizens[if (seller_possession = true) [set #_sellers #_sellers + 1]]
  set price price + 0.005 * (#_demanders - #_sellers)

  ;Possessors consume drug over t turns
  ask citizens with [possession]
  [ ifelse (remaining_possession <= 0)
    [set possession false
      ifelse (seller_possession = true)
      [set shape "ii-a"]
      [set shape "iii"]
    ]
    [set remaining_possession remaining_possession - 1]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Performs variable transformations to  ;;
;; modify changes of states in citizens. ;;
;; See demand state diagram for details. ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to transform-demand
   ask citizens[
     ifelse (threshold < (60 - 0.5 * price - risk_aversion * (0.5 * LEA_Density + 0.1 * Possessor_Jail_Term)))
       [
         ifelse (possession = true or seller_possession = true)
           [
             set ECD false
           ]

           [
             ifelse (incarcerated = true)
               [
                 set ECD false
               ]
               [
                 ifelse (consumer_condition = true)
                   [
                     set ECD true
                   ]
                   [
                     set ECD false
                   ]
               ]
           ]
       ]
       [
        set ECD false
       ]
     ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Performs variable transformations to  ;;
;; modify changes of states in citizens. ;;
;; See supply state diagram for details. ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to transform-supply
  ask citizens[
    ifelse (threshold < -30 +  2.5 * price - 0.04 * income - risk_aversion * (0.5 * LEA_Density + 0.1 * Seller_Jail_Term) )
      [
        ifelse (seller_possession = true)
          [
            set ESD false
          ]
          [
            ifelse (incarcerated = true)
            [
              set ESD false
            ]
            [
              set ESD true
             ; set seller_possession true
              ;set shape "ii-a"
            ]
          ]
      ]
      [
        set ESD false
        set seller_possession false
        ifelse (possession = true)
          [set shape "i-a"]
          [set shape "iii"]
      ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All LEAs check patch that they occupy for;;
;; possessing citizens. If citizen(s) is    ;;
;; caught possessing, punishment is assigned;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to perform-arrests
  ask LEAs[
    if any? (citizens-on neighbors) with [possession or seller_possession]
    [
      let arrestee one-of (citizens-on neighbors) with [possession or seller_possession]
      ask arrestee [set incarcerated true]

      ;if arrestee is a possessor xor seller, jail term is assigned appropriately. If both, arrestee recieves harshest punishment
      ask arrestee [ if (possession = true and seller_possession = true) [ifelse (Seller_Jail_Term > Possessor_Jail_Term) [set jail_term Seller_Jail_Term][set jail_term Possessor_Jail_Term]]
                     if (possession = true and seller_possession = false) [set jail_term Possessor_Jail_Term]
                     if (possession = false and seller_possession = true) [set jail_term Seller_Jail_Term]
      ]
      ask arrestee [set possession false]
      ask arrestee [set seller_possession false]
      ask arrestee[hide-turtle]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Prisoners are relasesed if jail term=0. ;;
;; Jail term is decremented by 1 each turn ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to release-prisoners
  ask citizens with [incarcerated]
      [
        ifelse (jail_term <= 0)
        [
          set incarcerated false
          set shape "iii"
          set hidden? false
        ]
        [
          set jail_term jail_term - 1
          if income >= 50 [set income income - 10]
        ]
     ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Poll of prison population is completed  ;;
;; to determine class incarceration rates  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to perform-census
  set poor_incarcerated 0
  set lower_middle_incarcerated 0
  set upper_middle_incarcerated 0
  set rich_incarcerated 0
  ask citizens with [incarcerated]
  [
    if (income < poor) [set poor_incarcerated poor_incarcerated + 1]
    if ((poor <= income) and (income < lower_middle)) [set lower_middle_incarcerated lower_middle_incarcerated + 1]
    if ((lower_middle <= income) and (income < upper_middle)) [set upper_middle_incarcerated upper_middle_incarcerated + 1]
    if (income >= upper_middle) [set rich_incarcerated rich_incarcerated + 1]
  ]
end

to modify-force
  if (force_size != (LEA_Density / 100) * Citizen_Density)
  [
   ifelse (force_size < (LEA_Density / 100) * Citizen_Density)
   [create-LEAs ((LEA_Density / 100) * Citizen_Density - force_size)
     set force_size (force_size + (LEA_Density / 100) * Citizen_Density - force_size)
    ask LEAs [set shape "LEA" setxy random-xcor random-ycor]
    ]
   [
     ask LEAs [die]
     set force_size (LEA_Density / 100) * Citizen_Density ;;number of LEAs
     create-LEAs force_size
     ask LEAs [set shape "LEA"]
     ask LEAs [setxy random-xcor random-ycor]
   ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
216
10
665
480
16
16
13.303030303030303
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
6
282
74
327
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
235
73
279
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
671
255
1241
479
Class Incarceration Rate
time
total
0.0
10.0
0.0
50.0
true
true
"" ""
PENS
"Poor" 1.0 0 -14070903 true "" "plot poor_incarcerated"
"Lower-Middle" 1.0 0 -14439633 true "" "plot lower_middle_incarcerated"
"Upper-Middle" 1.0 0 -7500403 true "" "plot upper_middle_incarcerated"
"Rich" 1.0 0 -2674135 true "" "plot rich_incarcerated"
"Total" 1.0 0 -16514813 true "" "plot rich_incarcerated + upper_middle_incarcerated + lower_middle_incarcerated + poor_incarcerated"

SLIDER
20
10
191
43
Citizen_Density
Citizen_Density
1
500
482
1
1
NIL
HORIZONTAL

SLIDER
20
45
192
78
LEA_Density
LEA_Density
0
100
3
1
1
NIL
HORIZONTAL

SLIDER
20
80
191
113
Possessor_Jail_Term
Possessor_Jail_Term
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
20
115
192
148
Seller_Jail_Term
Seller_Jail_Term
0
100
25
1
1
NIL
HORIZONTAL

MONITOR
91
283
202
328
Total Incarceration
poor_incarcerated + rich_incarcerated + upper_middle_incarcerated + lower_middle_incarcerated
17
1
11

SLIDER
20
150
193
183
Consumption_Rate
Consumption_Rate
0
100
50
1
1
NIL
HORIZONTAL

PLOT
6
335
210
479
Income Distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-histogram-num-bars 10\nset-plot-x-range 0 (precision (max [income] of citizens) 0)\nset-plot-pen-interval ((max [income] of citizens) / 10)"
PENS
"default" 10.0 1 -16777216 true "" "histogram ([income] of citizens)"

PLOT
671
10
1240
250
Price and Consumption
Time
Price (x 10) & Consumption
0.0
10.0
0.0
12.0
true
true
"" ""
PENS
"Price" 1.0 0 -16777216 true "" "plot Price * 10"
"Consumption" 1.0 0 -15040220 true "" "let consumption 0\nask citizens [if (possession)\n [set consumption consumption + 1]\n] \nplot consumption"

MONITOR
91
235
202
280
Price
Price
2
1
11

BUTTON
6
191
73
233
Go Once
Go\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

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

i-a
false
0
Circle -10899396 true false 110 5 80
Polygon -10899396 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -10899396 true false 127 79 172 94
Polygon -10899396 true false 195 90 240 150 225 180 165 105
Polygon -10899396 true false 105 90 60 150 75 180 135 105

i-b
false
10
Circle -7500403 true false 110 5 80
Polygon -7500403 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true false 127 79 172 94
Polygon -10899396 true false 195 90 240 150 225 180 165 105
Polygon -10899396 true false 105 90 60 150 75 180 135 105

i-c
false
8
Circle -7500403 true false 110 5 80
Polygon -7500403 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -10899396 true false 127 79 172 94
Polygon -7500403 true false 195 90 240 150 225 180 165 105
Polygon -7500403 true false 105 90 60 150 75 180 135 105

ii-a
false
0
Circle -1184463 true false 110 5 80
Polygon -1184463 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -1184463 true false 127 79 172 94
Polygon -1184463 true false 195 90 240 150 225 180 165 105
Polygon -1184463 true false 105 90 60 150 75 180 135 105

ii-b
false
7
Circle -7500403 true false 110 5 80
Polygon -7500403 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true false 127 79 172 94
Polygon -1184463 true false 195 90 240 150 225 180 165 105
Polygon -1184463 true false 105 90 60 150 75 180 135 105

iii
false
2
Circle -7500403 true false 110 5 80
Polygon -7500403 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true false 127 79 172 94
Polygon -7500403 true false 195 90 240 150 225 180 165 105
Polygon -7500403 true false 105 90 60 150 75 180 135 105

lea
false
0
Circle -2674135 true false 110 5 80
Polygon -2674135 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -2674135 true false 127 79 172 94
Polygon -2674135 true false 195 90 240 150 225 180 165 105
Polygon -2674135 true false 105 90 60 150 75 180 135 105

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.1
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
