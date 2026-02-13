;extensions [ rnd ]

patches-own [
  tipo        ;; obstaculo, vacio, salida
  zona        ;; interior, exterior

  S           ;; static Floor Field
  D           ;; dynamic Floor Field
  k           ;; número de agentes que se mueven a la celda al mismo tiempo

  f
  parent
]

turtles-own [
  destino

  posibles_destinos
  probs_transicion

]

globals [
  celda_salida
  tiempo_evacuacion
  finalizo_evacuacion?
]


to setup
  clear-all

  ;; se crea el espacio
  ask patches [
    set tipo "vacio"
    set zona "exterior"
  ]

  ask patches with [
    (abs pxcor = round (max-pxcor * 0.7) and abs pycor <= round (max-pycor * 0.7)) or
    (abs pxcor <= round (max-pxcor * 0.7) and abs pycor = round (max-pycor * 0.7))
  ][ set tipo "obstaculo" ]

  ask patches with [
    (abs pxcor <= round (max-pxcor * 0.7) and abs pycor <= round (max-pycor * 0.7)) or
    (abs pxcor <= round (max-pxcor * 0.7) and abs pycor <= round (max-pycor * 0.7))
  ][ set zona "interior" ]

  set celda_salida one-of patches with [ pycor = round (max-pycor * 0.7) - 1 and pxcor = 0 ]
  ask celda_salida [
    set tipo "salida"
    ask patch-at 0 1 [
      set tipo "vacio"
      set zona "exterior"
    ]
    ask neighbors4 [
      set tipo "vecino salida"
    ]
  ]

  if ESTRUCTURA = "con obstáculo" [
    ask patch 0 (round (max-pycor * 0.7) - 2) [
      set tipo "obstaculo"
    ]
  ]


  ;; se inicializan los floor fields
  ask patches with [ zona = "interior" and (tipo = "vacio" or tipo = "vecino salida")][
    set S obtener_long_ruta_A_star self celda_salida
    set D 0
  ]

  ;; se crean los agentes
  create-turtles NUMERO_AGENTES [
;    set shape "circle"
    set color sky
    set size 1
    move-to one-of patches with [ zona = "interior" and (tipo = "vacio" or tipo = "vecino salida") and not any? other turtles-here ]
    set destino nobody
  ]

  set finalizo_evacuacion? false

  colorear_celdas

  reset-ticks
end

to colorear_celdas
  if COLOREAR_POR = "Tipo" [
    ask patches [
      if tipo = "obstaculo" [ set pcolor gray ]
      if tipo = "salida" [ set pcolor lime ]
      if tipo = "vacio" or tipo = "vecino salida" [
        if zona = "interior" [ set pcolor gray + 2 ]
      ]
    ]
  ]
  if COLOREAR_POR = "Dynamic Floor Field" [
    ask patches [ set pcolor scale-color red D 0 10 ]
  ]
  if COLOREAR_POR = "Static Floor Field" [
    ask patches [ set pcolor scale-color yellow S 0 100 ]
  ]

end


to go
  if not any? turtles [ stop ]

  ifelse any? turtles with [ zona = "interior" ]
  [ set tiempo_evacuacion tiempo_evacuacion + 1 ]
  [ set finalizo_evacuacion? true ]

  ;; 1. calcular las probabilidades de transición
  ask turtles with [ zona = "interior" ][
    ifelse VECINDAD = "moore"
    [ set posibles_destinos (list (patch-at 0 0) (patch-at 0 1) (patch-at 1 1) (patch-at 1 0) (patch-at 1 -1) (patch-at 0 -1) (patch-at -1 -1) (patch-at -1 0) (patch-at -1 1)) ]
    [ set posibles_destinos (list (patch-at 0 0) (patch-at 0 1) (patch-at 1 0) (patch-at 0 -1) (patch-at -1 0)) ]
    let transitable (map [_p -> ifelse-value ([zona] of _p = "interior" and [tipo] of _p != "obstaculo") [1] [0] ] posibles_destinos)
    set probs_transicion []
    (foreach posibles_destinos transitable [
      [_p t] ->
      let ocup 0
      if any? other [turtles-here] of _p [ set ocup 1 ]
      let prob exp (( - k_s * [S] of _p ) + ( k_d * [D] of _p)) * (1 - ocup) * t
      set probs_transicion lput prob probs_transicion
    ])
    let N 1 / (sum probs_transicion)
    set probs_transicion map [ prob -> prob * N ] probs_transicion
    if tipo = "vecino salida" [
      let p_00 item 0 probs_transicion
      set probs_transicion replace-item 0 probs_transicion ((beta * p_00) + (1 - beta))
      foreach (range 1 (length posibles_destinos))[
        i ->
        let p_ij item i probs_transicion
        set probs_transicion replace-item i probs_transicion (beta * p_ij)
      ]
    ]
    ;; se aplica el efecto del giro
    let angulos_giro (map [_p -> angulo_relativo_orientacion _p] posibles_destinos)
    let tau_pij (map [[prob a] -> (tau a) * prob ] probs_transicion angulos_giro)
    foreach (range 1 (length posibles_destinos))[
      i ->
      set probs_transicion replace-item i probs_transicion (item i tau_pij)
    ]
    set probs_transicion replace-item 0 probs_transicion ((item 0 tau_pij) + (1 - sum tau_pij))

    ;; se cambia la prob de transición de los que están en la salida
    if tipo = "salida" [
      set posibles_destinos (list (patch-at 0 1))
      set probs_transicion (list alpha)
    ]
  ]

  ;; 2. mover a los agentes y resolver conflictos
  ask patches [ set k 0 ]
  ask turtles with [ zona = "interior" ] [
;    let pares (map list posibles_destinos probs_transicion)
;    set destino first (rnd:weighted-one-of-list pares [[par] -> last par ])
    set destino (weighted-one-of-list posibles_destinos probs_transicion)
    ask destino [ set k k + 1 ]
  ]
  ask patches with [ k > 0 ][
    let phi 0
    if frictional_function = "mu" [
      ifelse k >= 2
      [ set phi mu ]
      [ set phi 0 ]
    ]
    if frictional_function = "xi" [
      set phi 1 - ((1 - xi) ^ k) - (k * xi * (1 - xi) ^ (k - 1))
    ]

    if random-float 1.0 >= phi [
      ask one-of turtles with [ destino = myself ][
        set D D + 1
        face destino
        move-to destino
      ]
    ]
  ]

  ;; 3. animar a los que ya evacuación
  ask turtles with [ zona = "exterior" ][
    set destino patch-at 0 1
    ifelse destino != nobody
    [ move-to destino ]
    [ die ]
  ]

  ;; difusión y decaimiento de Dynamic floor field
  ask patches with [ D >= 1 ] [
    repeat D [
      if random-float 1 < d_alpha [ set D D - 1 ]
      if random-float 1.0 < d_delta [
        set D D - 1
        ask one-of neighbors4 with [ tipo != "obstaculo" ][
          set D D + 1
        ]
      ]
    ]
  ]

  colorear_celdas

  tick
end

to-report angulo_relativo_orientacion [_p]
  ifelse _p != patch-here [
    let delta_heading (towards _p) - heading
    (ifelse
      delta_heading > 180  [ set delta_heading delta_heading - 360 ]
      delta_heading < -180 [ set delta_heading delta_heading + 180 ])
    report delta_heading
  ][
    report 0
  ]
end

to-report tau [a]
  let radianes a * (2 * pi) / 360
  report exp (- eta * abs (radianes) )
end


to-report obtener_long_ruta_A_star [inicio final]
  let open (patch-set inicio)
  let closed nobody

  while [count open != 0][
    let current min-one-of open [f]
    set closed (patch-set closed current)

    if current = final [ report obtener_longitud_ruta_A_star inicio final ]

    set open open with [ not member? self (patch-set current)]

    ask current [
      ask neighbors with [ tipo != "obstaculo" ][
        if member? self closed [stop]
        let tentative_g_cost ([g_cost inicio] of myself) + distance myself
        if tentative_g_cost < g_cost inicio or not member? self open [
          set f tentative_g_cost + h_cost final
          set parent current
          set open (patch-set open self)
        ]
      ]
    ]
  ]
end

to-report obtener_longitud_ruta_A_star [inicio final]
  let celda_actual final
  let longitud 0

  while [celda_actual != inicio][
    let padre_celda_actual [parent] of celda_actual
    ask celda_actual [ set longitud longitud +  distance padre_celda_actual ]
    set celda_actual padre_celda_actual
  ]
  report longitud
end

to-report g_cost [inicio]
  report distance inicio
end

to-report h_cost [final]
  report distance final
end

to-report weighted-one-of-list [elements weights]
  ; Calcula la suma total de los pesos
  let total-weight sum weights

  ; Genera un número aleatorio entre 0 y total-weight
  let random-value random-float total-weight

  ; Inicializa la suma acumulada
  let cumulative-sum 0

  ; Recorre los elementos y sus pesos
  foreach elements [
    element ->
      let weight first weights  ; Toma el peso correspondiente
      set cumulative-sum cumulative-sum + weight  ; Actualiza la suma acumulada

      ; Si el valor aleatorio cae en el rango de este peso, reporta el elemento
      if random-value < cumulative-sum [
        report element
      ]

      ; Elimina el primer peso de la lista de pesos
      set weights but-first weights
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
215
20
623
429
-1
-1
16
1
8
1
1
1
0
0
0
1
-12
12
-12
12
1
1
1
ticks
30

BUTTON
10
241
200
274
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
26
200
59
NUMERO_AGENTES
numero_agentes
0
200
200
10
1
NIL
HORIZONTAL

SLIDER
640
100
815
133
k_s
k_s
0
10
10
.1
1
NIL
HORIZONTAL

SLIDER
640
135
815
168
k_d
k_d
0
10
0
0.1
1
NIL
HORIZONTAL

SLIDER
640
170
815
203
beta
beta
0
1
0.97
0.01
1
NIL
HORIZONTAL

SLIDER
640
65
815
98
mu
mu
0
1
0.23
0.01
1
NIL
HORIZONTAL

BUTTON
10
281
200
314
NIL
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

SLIDER
640
205
815
238
alpha
alpha
0
1
1
0.01
1
NIL
HORIZONTAL

SLIDER
640
240
815
273
d_alpha
d_alpha
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
641
275
816
308
d_delta
d_delta
0
1
0.3
0.01
1
NIL
HORIZONTAL

CHOOSER
640
20
815
65
frictional_function
frictional_function
"mu" "xi"
1

SLIDER
10
66
200
99
xi
xi
0
1
0.3
0.05
1
NIL
HORIZONTAL

TEXTBOX
15
106
195
186
xi: AGRESIVIDAD\n(probabilidad de no ceder el paso a otro agente que quiere ir a la misma celda que yo)
12
0
1

SLIDER
640
310
815
343
eta
eta
0
1
0.09
0.01
1
NIL
HORIZONTAL

MONITOR
10
326
200
371
NIL
tiempo_evacuacion
17
1
11

CHOOSER
10
181
200
226
ESTRUCTURA
estructura
"sin obstáculo" "con obstáculo"
0

CHOOSER
640
345
815
390
VECINDAD
vecindad
"moore" "von neumann"
0

CHOOSER
640
390
815
435
COLOREAR_POR
colorear_por
"Tipo" "Dynamic Floor Field" "Static Floor Field"
0
@#$#@#$#@
## ¿QUÉ ES ESTE MODELO?

Este modelo simula la evacuación de un grupo de pesonas de un edificio cerrado con 
una sola salida. El modelo está basado en el modelo de [Yanagisawa et al. (2009)](https://link.aps.org/doi/10.1103/PhysRevE.80.036110).

Este es un modelo de evacuación de "Floor Field" donde cada celda tiene una probabilidad de transición que depende de un "Static Floor Field" dado por la distancia de la celda a la salida y un "Dynamic Floor Field" que es un rastro del camino que dejan otros agentes al moverse (en el modelo de Yanagisawa et al. (2009) el campo dinámico se ignora).

## ¿CÓMO FUNCIONA?

En cada iteración cada agente calcula la probabilidad de transición hacia cada una de sus vecinas. Luego a partir de dichas probabilidades los agentes eligen una celda hacia la que desean mover. Posteriormente se identifica si hay "conflictos", es decir, si hay celdas hacia las que más de un agente quiere moverse. En caso de que no haya conflictos el agente se mueve a la celda que elige. Cuando hay conflictos pueden ocurrir dos cosas: (1) ningúno de los agentes se mueve (simulando que hay un atasque) o (2) se mueve sólo úno de los agentes a la celda que desea y los otros se quedan en la suya (el agente que se mueve se elige al azar).


## ¿CÓMO USARLO?

- **NUMERO_AGENTES**: número de personas a simular
- **xi**: parámetro de agresividad que determina la probabilidad de no ceder el paso a otro agente que se quiere mover a la misma celda que yo (solo aplica cuando se usa la frictional_function = xi)
- **ESTRUCTURA**: determina si poner un obstáculo o no
- **frictional_function**: función para determinar el efecto de la fricción entre agentes (mu, ignora el efecto del número de individuos en un conflicto; xi, considera el efecto del número de individuos en un conflicto)
- **mu**: probabilidad de que ningún agente avance cuando hay un conflicto (solo aplica cuando se usa la frictional_function = mu)
- **k_s**: peso del "Static Floor Field"
- **k_d**: peso del "Dynamic Floor Field"
- **beta**: parámetro de "bootleneck", que representa la velocidad de los agnetes que están en celdas vecinas a la salida
- **alpha**: probabilidad de que un agente que esta en la celda de salida salga
- **d_alpha**: difusión de señal en el "Dynamic Floor Field"
- **d_delta**: decaimiento de señal en el "Dynamic Floor Field"
- **eta**: parámetro del efecto del cambio en la inercia por el giro
- **vecindad**: vecindad en la que se pueden mover los agentes
- **COLOREAR_POR**: determina que incluye la visualización


## CRÉDITOS Y REFERENCIAS

- Yanagisawa, Daichi, Ayako Kimura, Akiyasu Tomoeda, Ryosuke Nishi, Yushi Suma, Kazumichi Ohtsuka, and Katsuhiro Nishinari. “Introduction of Frictional and Turning Function for Pedestrian Outflow with an Obstacle.” Physical Review E 80, no. 3 (September 15, 2009): 036110. [ https://doi.org/10.1103/PhysRevE.80.036110](https://doi.org/10.1103/PhysRevE.80.036110).






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
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0
-0.2 0 0 1
0 1 1 0
0.2 0 0 1
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@

@#$#@#$#@
