;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;  Land model - v02 with flow directions
;;  Copyright (C) Andreas Angourakis (andros.spica@gmail.com)
;;  available at https://www.github.com/Andros-Spica/indus-village-model
;;  This model is a cleaner version of the Terrain Generator model v.2 (https://github.com/Andros-Spica/ProceduralMap-NetLogo)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

extensions [ csv ]

breed [ transectLines transectLine ]
breed [ flowHolders flowHolder ]

globals
[
  patchArea
  maxDist

  ; algorithm-style (GUI): style of algorithm to create land features "ranges" and "rifts".
  ; The algorithms styles available are: "NetLogo", using auxiliary agents and
  ; less parameters but with less control, and "C#", without agents and more
  ; parameters.

  ; do-fill-sinks (GUI): whether to apply algorithm to fill all drainage "sinks" (land units
  ;                      not on the edge of the map where there is no flow towards a neighbour).
  ;                      Those sinks are likely to have been created by land forming algorithms.

  ;;; parameters (copies) ===============================================================

  ;;;; elevation
  numRanges                  ; number of landforming features ("ranges", "rifts").
  numRifts

  rangeLength                ; maximum length, in land units, of landforming features.
  riftLength

  rangeElevation             ; the starting elevation of landforming features.
  riftElevation              ; These are also used as maximum and minimum elevation
                             ; for x,y, and valley slopes.

  featureAngleRange          ; the maximum change in features angle (direction every step)

  elevationSmoothStep        ; the level of smoothing applied to elevation.
                             ; 0 = none, 1 = values are equated to the mean of neighbours.
  smoothingNeighborhood      ; maximum distance to include land units in another's neihgbourhood.
                             ; Applied as a radius surrounding a land unit.

  xSlope                     ; the level of adjustment of elevation to x (West-East) and
                             ; y (North-South) slopes. 0 = no slope, 1 = no variation besides slopes.
  ySlope

  valleyAxisInclination      ; the level of inclination of the North-South valley.
                             ; 0 = centred, 1 = top-right to bottom-left diagonal.
  valleySlope                ; the level of adjustment of elevation to the North-South valley.
                             ; 0 = no valley, 1 = no variation besides valley.

  ;;;;; used when algorithm-style = "C#"
  numProtuberances           ; numDepressions: (approximated) number of distinct
  numDepressions             ; protuberances/depressions. Consider those are acheived by aglutinating
                             ; elevated and depressed land units.


  rangeAggregation           ; the minimum proximity required between
  riftAggregation            ; landform features, expressed as percentage of the map's maximum distance.

  elevationNoise              ; noise to be added/subtracted to elevation as the standard
                              ; deviation of a centred normal distribution.

  ;;;;; used when algorithm-style = "NetLogo"
  inversionIterations         ; the number of iterations all land units with neighbours
                              ; with opposite elevation sign (i.e., if elevation = 10, neighbours with elevation < 0)
                              ; have their elevation exchanged with one of those neighbours.

  ;;; variables ===============================================================
  seaLevel                    ; elevation considered as sea level for display purposes.

  landRatio                   ; the ratio of land units above seaLevel.
  elevationDistribution       ; the set or list containing the elevation of all land units
  minElevation                ; statistics on the elevation of land units.
  sdElevation
  maxElevation
]

patches-own
[
  elevation             ; average elevation above reference of the land unit (metres).
                        ; The reference is an arbitrary elevation from which all
                        ; algorithms will sculpt the terrain.

  flowDirection         ; the numeric code for the (main) direction of flow or 
                        ; drainage within the land unit. 
                        ; Following Jenson & Domingue (1988) convention:
                        ; NW = 64,   N = 128,        NE = 1,
                        ; W = 32,     <CENTRE>,   E = 2,
                        ; SW = 16,     S = 8,          SE = 4
                        
  receivesFlow          ; Boolean variable stating whether or not the land unit receives 
                        ; the flow of a neighbour.
]

breed [ mapSetters mapSetter ] ; used when algorithm-style = "NetLogo"

mapSetters-own [ numPoints ] ; the number of land units to be chained together as a "rift" or "range".

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to create-terrain

  clear-all

  set-parameters

  reset-timer

  ifelse (algorithm-style = "NetLogo")
  [
    set-landform-NetLogo
  ]
  [
    set-landform-Csharp
  ]

  set-xySlope

  set-valleySlope

  ;;; START - flow related procedures ;;;;;;;;;;;;;;;;;;;;;;;

  if (do-fill-sinks)
  [
    fill-sinks
  ]

  set-flow-directions

  ;;; END - flow related procedures ;;;;;;;;;;;;;;;;;;;;;;;

  set elevationDistribution [elevation] of patches

  set minElevation min [elevation] of patches

  set maxElevation max [elevation] of patches

  set sdElevation standard-deviation [elevation] of patches

  ;;; default seaLevel to minElevation (seaLevel afects patch color and landRatio measurement)
  set par_seaLevel (floor minElevation) - 1
  set seaLevel par_seaLevel

  set landRatio count patches with [elevation > seaLevel] / count patches

  paint-patches

  setup-patch-coordinates-labels "bottom" "left"

  setup-transect

  update-transects

  update-plots

end

to set-parameters

  random-seed randomSeed

  set patchArea 1 ; 10,000 m^2 = 1 hectare
  set maxDist (sqrt (( (max-pxcor - min-pxcor) ^ 2) + ((max-pycor - min-pycor) ^ 2)) / 2)

  ;parameters-check-1 ; in case you want to avoid zeros (optional)

  if (type-of-experiment = "user-defined")
  [
    ;;; load parameters from user interface
    set numProtuberances par_numProtuberances
    set numDepressions par_numDepressions

    set numRanges par_numRanges
    set rangeLength round ( par_rangeLength * maxDist)
    set rangeElevation par_rangeElevation
    set rangeAggregation par_rangeAggregation

    set numRifts par_numRifts
    set riftLength round ( par_riftLength * maxDist)
    set riftElevation par_riftElevation
    set riftAggregation par_riftAggregation

    set elevationNoise par_elevationNoise

    set featureAngleRange par_featureAngleRange

    set inversionIterations par_inversionIterations

    set elevationSmoothStep par_elevationSmoothStep
    set smoothingNeighborhood par_smoothingNeighborhood * maxDist

    set xSlope par_xSlope
    set ySlope par_ySlope

    set valleyAxisInclination par_valleyAxisInclination
    set valleySlope par_valleySlope
  ]

  if (type-of-experiment = "random") ; TODO
  [
    ;;; get random values within an arbitrary (reasonable) range of values
    ;;; this depends on what type and scale of terrain you want
    ;;; Here, our aim is to create inland/coastal, plain, small-scale terrains with a general flow running from N to S (e.g., 5km^2 Haryana, India)
    set numProtuberances 1 + random 10
    set numDepressions 1 + random 10

    set numRanges 1 + random 100
    set rangeLength round ( (random-float 100) * maxDist)
    set rangeElevation random-float 50
    set rangeAggregation random-float 1

    set numRifts 1 + random 100
    set riftLength round ( (random-float 100) * maxDist)
    set riftElevation -1 * random-float 50
    set riftAggregation random-float 1

    set elevationNoise random-float 5

    set featureAngleRange random-float 30

    set inversionIterations (random-float 2)

    set elevationSmoothStep 1 ; not randomised
    set smoothingNeighborhood 0.1 * maxDist ; not randomised

    set xSlope random-float 0.01 ; W depression
    set ySlope random-float 0.01 ; S depression

    set valleyAxisInclination random-float 1
    set valleySlope random-float 0.02 ; only valley (no ridges)
  ]
  if (type-of-experiment = "defined by experiment-number")
  [
    ;load-experiment
  ]

end

to parameters-check-1

  ;;; check if values were reset to 0 (comment out lines if 0 is a valid value)
  ;;; and set default values

  if (par_rangeElevation = 0)                     [ set par_rangeElevation                   15 ]
  if (par_riftElevation = 0)                     [ set par_riftElevation                    0 ]
  if (par_elevationNoise = 0)                      [ set par_elevationNoise                     1 ]

  if (par_numProtuberances = 0)                    [ set par_numProtuberances                   1 ]
  if (par_numDepressions = 0)                        [ set par_numDepressions                       1 ]

  if (par_inversionIterations = 0)                   [ set par_inversionIterations                  5 ]

  if (par_numRanges = 0)                        [ set par_numRanges                       1 ]
  if (par_rangeLength = 0)                      [ set par_rangeLength                   100 ]
  if (par_rangeAggregation = 0)                 [ set par_rangeAggregation                0.75 ]

  if (par_numRifts = 0)                         [ set par_numRifts                        1 ]
  if (par_riftLength = 0)                       [ set par_riftLength                    100 ]
  if (par_riftAggregation = 0)                  [ set par_riftAggregation                 0.9 ]

  if (par_elevationSmoothStep = 0)              [ set par_elevationSmoothStep             1 ]
  if (par_smoothingNeighborhood = 0)            [ set par_smoothingNeighborhood           0.1 ]

  if (par_xSlope = 0)                           [ set par_xSlope                          0.01 ]
  if (par_ySlope = 0)                           [ set par_ySlope                          0.025 ]
  if (par_valleyAxisInclination = 0)            [ set par_valleyAxisInclination           0.1 ]
  if (par_valleySlope = 0)                      [ set par_valleySlope                     0.02 ]

end

to parameters-to-default

  ;;; set parameters to a default value
  set par_rangeElevation                   15
  set par_riftElevation                    0
  set par_elevationNoise                     1

  set par_numProtuberances                   1
  set par_numDepressions                       1

  set par_inversionIterations                  5

  set par_numRanges                       1
  set par_rangeLength                   100
  set par_rangeAggregation                0.75

  set par_numRifts                        1
  set par_riftLength                    100
  set par_riftAggregation                 0.9

  set par_elevationSmoothStep             1
  set par_smoothingNeighborhood           0.1

  set par_xSlope                          0.01
  set par_ySlope                          0.025
  set par_valleyAxisInclination           0.1
  set par_valleySlope                     0.02

end

to set-landform-NetLogo ;[ numRanges rangeLength rangeElevation numRifts riftLength riftElevation inversionIterations smoothingNeighborhood elevationSmoothStep]

  ; Netlogo-like code
  ask n-of numRanges patches [ sprout-mapSetters 1 [ set numPoints random rangeLength ] ]
  ask n-of numRifts patches with [any? turtles-here = false] [ sprout-mapSetters 1 [ set numPoints (random riftLength) * -1 ] ]

  let steps sum [ abs numPoints ] of mapSetters
  repeat steps
  [
    ask one-of mapSetters
    [
      let sign 1
      let scale rangeElevation
      if ( numPoints < 0 ) [ set sign -1 set scale riftElevation ]
      ask patch-here [ set elevation scale ]
      set numPoints numPoints - sign
      if (numPoints = 0) [die]
      rt (random-exponential featureAngleRange) * (1 - random-float 2)
      forward 1
    ]
  ]

  smooth-elevation-all

  let depressedPatches patches with [elevation < 0]
  let elevatedPatches patches with [elevation > 0]

  repeat inversionIterations * count patches
  [
    if (any? depressedPatches AND any? elevatedPatches)
    [
      let p_depression max-one-of depressedPatches [ count neighbors with [elevation > 0] ]
      let p_protuberance  max-one-of elevatedPatches [ count neighbors with [elevation < 0] ]
      let temp [elevation] of p_depression
      ask p_depression [ set elevation [elevation] of p_protuberance ]
      ask p_protuberance [ set elevation temp ]
      set depressedPatches depressedPatches with [pxcor != [pxcor] of p_depression AND pycor != [pycor] of p_depression]
      set elevatedPatches elevatedPatches with [pxcor != [pxcor] of p_protuberance AND pycor != [pycor] of p_protuberance]
    ]
  ]

  smooth-elevation-all

end

to set-landform-Csharp ;[ elevationNoise numProtuberances numRanges rangeLength rangeElevation rangeAggregation numDepressions numRifts riftLength riftElevation riftAggregation smoothingNeighborhood elevationSmoothStep]

  ; C#-like code
  let p1 0
  let sign 0
  let len 0
  let elev 0
  let numRiftsToDo numRifts
  let numRangesToDo numRifts

  let protuberances n-of numProtuberances patches
  let depressions n-of numDepressions patches

  let maxDistBetweenRanges (1.1 - rangeAggregation) * maxDist
  let maxDistBetweenRifts (1.1 - riftAggregation) * maxDist

  repeat (numRanges + numRifts)
  [
    set sign -1 + 2 * (random 2)
    if (numRangesToDo = 0) [ set sign -1 ]
    if (numRiftsToDo = 0) [ set sign 1 ]

    ifelse (sign = -1)
    [
      set numRiftsToDo numRiftsToDo - 1
      set len riftLength - 2
      set elev riftElevation
      ;ifelse (any? patches with [elevation < 0]) [set p0 one-of patches with [elevation < 0]] [set p0 one-of patches]
      set p1 one-of patches with [ distance one-of depressions < maxDistBetweenRifts ]
    ]
    [
      set numRangesToDo numRangesToDo - 1
      set len rangeLength - 2
      set elev rangeElevation
      set p1 one-of patches with [ distance one-of protuberances < maxDistBetweenRanges ]
    ]

    draw-elevation-pattern p1 len elev
  ]

  smooth-elevation-all

  ask patches
  [
    set elevation elevation + random-normal 0 elevationNoise
  ]

  smooth-elevation-all

end

to draw-elevation-pattern [ p1 len elev ]

  let p2 0
  let xDirection 0
  let yDirection 0
  let directionAngle 0

  ask p1 [ set elevation elev set p2 one-of neighbors ]
  set xDirection ([pxcor] of p2) - ([pxcor] of p1)
  set yDirection ([pycor] of p2) - ([pycor] of p1)
  ifelse (xDirection = 1 AND yDirection = 0) [ set directionAngle 0 ]
  [ ifelse (xDirection = 1 AND yDirection = 1) [ set directionAngle 45 ]
    [ ifelse (xDirection = 0 AND yDirection = 1) [ set directionAngle 90 ]
      [ ifelse (xDirection = -1 AND yDirection = 1) [ set directionAngle 135 ]
        [ ifelse (xDirection = -1 AND yDirection = 0) [ set directionAngle 180 ]
          [ ifelse (xDirection = -1 AND yDirection = -1) [ set directionAngle 225 ]
            [ ifelse (xDirection = 0 AND yDirection = -1) [ set directionAngle 270 ]
              [ if (xDirection = 1 AND yDirection = -1) [ set directionAngle 315 ]]
            ]
          ]
        ]
      ]
    ]
  ]

  repeat len
  [
    set directionAngle directionAngle + (random-exponential featureAngleRange) * (1 - random 2)
    set directionAngle directionAngle mod 360

    set p1 p2
    ask p2
    [
      set elevation elev
      if (patch-at-heading-and-distance directionAngle 1 != nobody) [ set p2 patch-at-heading-and-distance directionAngle 1 ]
    ]
  ]

end

to smooth-elevation-all

  ask patches
  [
    smooth-elevation
  ]

end

to smooth-elevation

  let smoothedElevation mean [elevation] of patches in-radius smoothingNeighborhood
  set elevation elevation + (smoothedElevation - elevation) * elevationSmoothStep

end

to set-xySlope

  ask patches
  [
    set elevation (1 - xSlope) * elevation + (xSlope * (rangeElevation - riftElevation) * (pxcor - min-pxcor) / world-width)

    set elevation (1 - ySlope) * elevation + (ySlope * (rangeElevation - riftElevation) * (pycor - min-pycor) / world-height)
  ]

end

to set-valleySlope

  ; bend terrain as a valley (valleySlope > 0) or a ridge (valleySlope < 0) following a North-South pattern
  ask patches
  [
    let xValley (world-width / 2) + valleyAxisInclination * (pycor - (world-height / 2))
    set elevation (1 - valleySlope) * elevation + (valleySlope * (rangeElevation - riftElevation) * abs (xValley - pxcor))
  ]

end

;=======================================================================================================
;;; START of algorithms based on:
;;; Huang, P., Lee, K.T. A simple depression-filling method for raster and irregular elevation datasets.
;;; J Earth Syst Sci 124, 1653–1665 (2015). https://doi.org/10.1007/s12040-015-0641-2
;=======================================================================================================

to fill-sinks

  while [ count patches with [is-sink] > 0 ]
  [
    ask patches with [is-sink]
    [
      ;print (word "before: " elevation)
      set elevation [elevation] of min-one-of neighbors [elevation] + 1E-1
      ; the scale of this "small number" (1E-1) regulates how fast will be the calculation
      ; and how distorted will be the depressless DEM
      ;print (word "after: " elevation)
    ]
  ]

end

to-report is-sink ; ego = patch

  let thisPatch self

  report (not is-at-edge) and (elevation < min [elevation] of neighbors);count neighbors with [elevation < [elevation] of thisPatch] = 0)

end

;=======================================================================================================
;;; START of algorithms based on:
;;; Jenson, S. K., & Domingue, J. O. (1988).
;;; Extracting topographic structure from digital elevation data for geographic information system analysis.
;;; Photogrammetric engineering and remote sensing, 54(11), 1593-1600.
;;; ===BUT used elsewhere, such as in the algorithms based on:
;;; Huang, P., Lee, K.T. A simple depression-filling method for raster and irregular elevation datasets.
;;; J Earth Syst Sci 124, 1653–1665 (2015). https://doi.org/10.1007/s12040-015-0641-2
;=======================================================================================================

to-report get-drop-from [ aPatch ] ; ego = patch

  ; "Distance- weighted drop is calculated by subtracting the neighbor’s value from the center cell’s value
  ; and dividing by the distance from the center cell, √2 for a corner cell and one for a noncorner cell." (p. 1594)

  report ([elevation] of aPatch - elevation) / (distance aPatch)

end

to-report is-at-edge ; ego = patch

  report (pxcor = min-pxcor or pxcor = max-pxcor or pycor = min-pycor or pycor = max-pycor)

end

to-report has-flow-direction-code ; ego = patch

  if (member? flowDirection [ 1 2 4 8 16 32 64 128 ]) [ report true ]

  report false

end

to-report get-flow-direction-encoding [ x y ]

  if (x = -1 and y = -1) [ report 16 ] ; Southwest
  if (x = -1 and y = 0) [ report 32 ]  ; West
  if (x = -1 and y = 1) [ report 64 ]  ; Northwest

  if (x = 0 and y = -1) [ report 8 ]   ; South
  if (x = 0 and y = 1) [ report 128 ]  ; North

  if (x = 1 and y = -1) [ report 4 ]   ; Southeast
  if (x = 1 and y = 0) [ report 2 ]    ; East
  if (x = 1 and y = 1) [ report 1 ]    ; Northeast

end

to-report get-patch-in-flow-direction [ neighborEncoding ] ; ego = patch

  ; 64 128 1
  ; 32  x  2
  ; 16  8  4

  if (neighborEncoding = 16) [ report patch (pxcor - 1) (pycor - 1) ]
  if (neighborEncoding = 32) [ report patch (pxcor - 1) (pycor) ]
  if (neighborEncoding = 64) [ report patch (pxcor - 1) (pycor + 1) ]

  if (neighborEncoding = 8) [ report patch (pxcor) (pycor - 1) ]
  if (neighborEncoding = 128) [ report patch (pxcor) (pycor + 1) ]

  if (neighborEncoding = 4) [ report patch (pxcor + 1) (pycor - 1) ]
  if (neighborEncoding = 2) [ report patch (pxcor + 1) (pycor) ]
  if (neighborEncoding = 1) [ report patch (pxcor + 1) (pycor + 1) ]

  report nobody

end

to set-flow-directions

  ask patches
  [
    ifelse (is-at-edge)
    [
      ifelse ( pxcor = min-pxcor )
      [ set flowDirection 32 ] ; west
      [
        ifelse ( pxcor = max-pxcor )
        [ set flowDirection 2 ] ; east
        [
          ifelse ( pycor = min-pycor )
          [ set flowDirection 8 ] ; south
          [ set flowDirection 128 ] ; north
        ]
      ]
    ]
    [
      set-flow-direction
    ]
  ]

end

to set-flow-direction ; ego = patch

  let thisPatch self

  let downstreamPatch max-one-of neighbors [get-drop-from thisPatch]
  set flowDirection get-flow-direction-encoding ([pxcor] of downstreamPatch - pxcor) ([pycor] of downstreamPatch - pycor)

end

;=======================================================================================================
;;; END of algorithms based on:
;;; Jenson, S. K., & Domingue, J. O. (1988).
;;; Extracting topographic structure from digital elevation data for geographic information system analysis.
;;; Photogrammetric engineering and remote sensing, 54(11), 1593-1600.
;;; ===BUT used in the algorithms based on:
;;; Huang P C and Lee K T 2015
;;; A simple depression-filling method for raster and irregular elevation datasets
;;; J. Earth Syst. Sci. 124 1653–65
;=======================================================================================================

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DISPLAY ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to paint-patches

  ask patches
  [
    if (display-mode = "terrain")
    [
      let elevationGradient 0
      ifelse (elevation < seaLevel)
      [
        let normSubElevation (-1) * (seaLevel - elevation)
        let normSubMinElevation (-1) * (seaLevel - minElevation) + 1E-6
        set elevationGradient 20 + (200 * (1 - normSubElevation / normSubMinElevation))
        set pcolor rgb 0 0 elevationGradient
      ]
      [
        let normSupElevation elevation - seaLevel
        let normSupMaxElevation maxElevation - seaLevel + 1E-6
        set elevationGradient 100 + (155 * (normSupElevation / normSupMaxElevation))
        set pcolor rgb (elevationGradient - 100) elevationGradient 0
      ]
    ]
    ;;; other modes of display can be added here
  ]

  display-flows

end

to display-flows

  if (not any? flowHolders)
  [
    ask patches [ sprout-flowHolders 1 [ set hidden? true ] ]
  ]

  ifelse (show-flows)
  [
    ask patches ;with [ has-flow-direction-code ]
    [
      let flowDirectionHere flowDirection
      let nextPatchInFlow get-patch-in-flow-direction flowDirection

      ask one-of flowHolders-here
      [
        ifelse (nextPatchInFlow != nobody)
        [
          if (link-with one-of [flowHolders-here] of nextPatchInFlow = nobody)
          [ create-link-with one-of [flowHolders-here] of nextPatchInFlow ]

          ask link-with one-of [flowHolders-here] of nextPatchInFlow
          [
            set hidden? false
            set color 95
          ]
        ]
        [
          set hidden? false
          set color 95
          set heading get-angle-in-flow-direction flowDirection
        ]
      ]
    ]
  ]
  [
    ask flowHolders
    [
      set hidden? true
      ask my-links [ set hidden? true ]
    ]
  ]

end

to-report get-angle-in-flow-direction [ neighborEncoding ]

  ; 64 128 1
  ; 32  x  2
  ; 16  8  4

  if (neighborEncoding = 16) [ report 225 ]
  if (neighborEncoding = 32) [ report 270 ]
  if (neighborEncoding = 64) [ report 315 ]

  if (neighborEncoding = 8) [ report 180 ]
  if (neighborEncoding = 128) [ report 0 ]

  if (neighborEncoding = 4) [ report 135 ]
  if (neighborEncoding = 2) [ report 90 ]
  if (neighborEncoding = 1) [ report 45 ]

  report nobody

end

to refresh-view

  update-plots

  paint-patches

end

to refresh-view-after-seaLevel-change

  set seaLevel par_seaLevel

  set landRatio count patches with [elevation > seaLevel] / count patches

  update-plots

  paint-patches

end

to setup-patch-coordinates-labels [ XcoordPosition YcoordPosition ]

  let xspacing floor (world-width / patch-size)
  let yspacing floor (world-height / patch-size)

  ifelse (XcoordPosition = "bottom")
  [
    ask patches with [ pycor = min-pycor + 1 ]
    [
      if (pxcor mod xspacing = 0)
      [ set plabel (word pxcor) ]
    ]
  ]
  [
    ask patches with [ pycor = max-pycor - 1 ]
    [
      if (pxcor mod xspacing = 0)
      [ set plabel (word pxcor) ]
    ]
  ]

  ifelse (YcoordPosition = "left")
  [
    ask patches with [ pxcor = min-pxcor + 1 ]
    [
      if (pycor mod yspacing = 0)
      [ set plabel (word pycor) ]
    ]
  ]
  [
    ask patches with [ pycor = max-pycor - 1 ]
    [
      if (pycor mod yspacing = 0)
      [ set plabel (word pycor) ]
    ]
  ]

end

to setup-transect

  ask patches with [ pxcor = xTransect ]
  [
    sprout-transectLines 1 [ set shape "line" set heading 0 set color white ]
  ]

  ask patches with [ pycor = yTransect ]
  [
    sprout-transectLines 1 [ set shape "line" set heading 90 set color white ]
  ]

  if (not show-transects)
  [
    ask transectLines [ set hidden? true ]
  ]

end

to update-transects

  ifelse (show-transects)
  [
    ask transectLines
    [
      ifelse (heading = 0) [ set xcor xTransect ] [ set ycor yTransect ]
      set hidden? false
    ]
  ]
  [
    ask transectLines [ set hidden? true ]
  ]

end

to plot-horizontal-transect

  foreach (n-values world-width [ j -> min-pxcor + j ])
  [
    x ->
    plotxy x ([elevation] of patch x yTransect)
  ]
  plot-pen-up

end

to plot-sea-level-horizontal-transect

  foreach (n-values world-width [ j -> min-pxcor + j ])
  [
    x ->
    plotxy x seaLevel
  ]
  plot-pen-up

end

to plot-vertical-transect

  foreach (n-values world-height [ j -> min-pycor + j ])
  [
    y ->
    plotxy ([elevation] of patch xTransect y) y
  ]
  plot-pen-up

end

to plot-sea-level-vertical-transect

  foreach (n-values world-height [ j -> min-pycor + j ])
  [
    y ->
    plotxy seaLevel y
  ]
  plot-pen-up

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; FILE HANDLING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to export-random-terrain

  set type-of-experiment "random"

  set randomSeed randomSeed + 1 ; this allows for creating multiple terrains when executing this procedure continuosly

  create-terrain

  export-terrain

end

to export-terrain

  set show-transects false

  update-transects

  ;;; build a file name as unique to this setting as possible
  let filePath (word "terrains//terrain_" type-of-experiment "_w=" world-width "_h=" world-height "_a=" algorithm-style "_fill-sinks=" do-fill-sinks "_seed=" randomSeed)

  if (type-of-experiment = "user-defined") [ set filePath (word filePath "_" random 9999) ]
  ;if (type-of-experiment = "defined by expNumber") [set filePath (word filePath "_" expNumber) ]

  print filePath print length filePath ; de-bug print

;;; check that filePath does not exceed 100 (not common in this context)
  if (length filePath > 100) [ print "WARNING: file path may be too long, depending on your current directory. Decrease length of file name or increase the limit." set filePath substring filePath 0 100 ]

  let filePathCSV (word filePath ".csv")

  let filePathPNG (word filePath ".png")

  export-view filePathPNG
  export-world filePathCSV

end

to import-terrain

  clear-all

  ;;; load a terrain from the "terrains" folder
  ;;; corresponding to the random seed given as a parameter in the interface

  ;;; build a unique file name according to the user setting
  let filePath (word "terrains//terrain_" type-of-experiment "_w=" world-width "_h=" world-height "_a=" algorithm-style "_fill-sinks=" do-fill-sinks "_seed=" randomSeed)

  if (type-of-experiment = "user-defined") [ set filePath (word filePath "_" date-and-time) ]
  ;if (type-of-experiment = "defined by expNumber") [set filePath (word filePath "_" expNumber) ]

  ;;; check that filePath does not exceed 100 (not common in this context)
  if (length filePath > 100) [ print "WARNING: file path may be too long, depending on your current directory. Decrease length of file name or increase the limit." set filePath substring filePath 0 100 ]

  set filePath (word filePath ".csv")

  ifelse (not file-exists? filePath)
  [ print (word "WARNING: could not find '" filePath "'") ]
  [
    file-open filePath

    while [not file-at-end?]
    [
      let thisLine csv:from-row file-read-line

      if (item 0 thisLine = "GLOBALS")
      [
        ;;; read and set basic NetLogo globals
        let globalNames csv:from-row file-read-line
        let globalValues csv:from-row file-read-line

        ;;; apply world dimensions
        resize-world (item 0 globalValues) (item 1 globalValues) (item 2 globalValues) (item 3 globalValues)

        ;;; read relevant globals searching for specific names
        foreach (n-values length(globalValues) [j -> j])
        [
          globalIndex ->

          if (item globalIndex globalNames = "algorithm-style") [ set algorithm-style read-from-string item globalIndex globalValues ]
          if (item globalIndex globalNames = "display-mode") [ set display-mode read-from-string item globalIndex globalValues ]
          if (item globalIndex globalNames = "do-fill-sinks") [ set do-fill-sinks item globalIndex globalValues ]

          if (item globalIndex globalNames = "numprotuberances") [ set numProtuberances item globalIndex globalValues ]
          if (item globalIndex globalNames = "numdepressions") [ set numDepressions item globalIndex globalValues ]

          if (item globalIndex globalNames = "numranges") [ set numRanges item globalIndex globalValues ]
          if (item globalIndex globalNames = "rangelength") [ set rangeLength item globalIndex globalValues ]
          if (item globalIndex globalNames = "rangeelevation") [ set rangeElevation item globalIndex globalValues ]
          if (item globalIndex globalNames = "rangeaggregation") [ set rangeAggregation item globalIndex globalValues ]

          if (item globalIndex globalNames = "numrifts") [ set numRifts item globalIndex globalValues ]
          if (item globalIndex globalNames = "riftlength") [ set riftLength item globalIndex globalValues ]
          if (item globalIndex globalNames = "riftelevation") [ set riftElevation item globalIndex globalValues ]
          if (item globalIndex globalNames = "riftaggregation") [ set riftAggregation item globalIndex globalValues ]

          if (item globalIndex globalNames = "featureanglerange") [ set featureAngleRange item globalIndex globalValues ]
          if (item globalIndex globalNames = "inversionIterations") [ set inversionIterations item globalIndex globalValues ]
          if (item globalIndex globalNames = "elevationnoise") [ set elevationNoise item globalIndex globalValues ]
          if (item globalIndex globalNames = "sealevel") [ set seaLevel item globalIndex globalValues ]
          if (item globalIndex globalNames = "elevationsmoothstep") [ set elevationSmoothStep item globalIndex globalValues ]
          if (item globalIndex globalNames = "smoothingneighborhood") [ set smoothingNeighborhood item globalIndex globalValues ]

          if (item globalIndex globalNames = "xslope") [ set xSlope item globalIndex globalValues ]
          if (item globalIndex globalNames = "yslope") [ set ySlope item globalIndex globalValues ]

          if (item globalIndex globalNames = "valleyaxisinclination") [ set valleyAxisInclination item globalIndex globalValues ]
          if (item globalIndex globalNames = "valleyslope") [ set valleySlope item globalIndex globalValues ]

        ]
      ]

      if (item 0 thisLine = "TURTLES")
      [
        set thisLine csv:from-row file-read-line ;;; skip variable names
        set thisLine csv:from-row file-read-line ;;; first row of data

        ;;; create a auxiliar turtles
        while [ length thisLine > 1 ]
        [
          if (item 8 thisLine = "{breed flowholders}")
          [
            create-flowHolders 1
            [
              set xcor item 3 thisLine
              set ycor item 4 thisLine
              set hidden? item 9 thisLine
              if (xcor = max-pxcor or xcor = min-pxcor or ycor = max-pycor or ycor = min-pycor)
              [
                set color item 1 thisLine
                set heading item 2 thisLine
                set shape read-from-string item 5 thisLine
              ]
            ]
          ]
          set thisLine csv:from-row file-read-line
        ]
      ]

      if (item 0 thisLine = "PATCHES")
      [
        let patchVarsNames csv:from-row file-read-line ;;; save variable names
        set thisLine csv:from-row file-read-line ;;; first row of data

        ;;; load patch variables per each patch
        while [ length thisLine > 1 ]
        [
          ask patch (item 0 thisLine) (item 1 thisLine)
          [
            let colorRGBValues read-from-string (item 2 thisLine)
            set pcolor rgb (item 0 colorRGBValues) (item 1 colorRGBValues) (item 2 colorRGBValues)

            set elevation item 5 thisLine
            set flowdirection item 6 thisLine
            set receivesflow item 7 thisLine
          ]
          set thisLine csv:from-row file-read-line
        ]
      ]

      if (item 0 thisLine = "LINKS")
      [
        set thisLine csv:from-row file-read-line ;;; skip variable names

        set thisLine csv:from-row file-read-line ;;; first row of data

        ;;; create links
        while [ length thisLine > 1 ]
        [
          let flowHolderEnd1 flowHolder get-flowHolder-who-from-link-data (item 0 thisLine)
          let flowHolderEnd2 flowHolder get-flowHolder-who-from-link-data (item 1 thisLine)

          ask flowHolderEnd1
          [
            create-link-with flowHolderEnd2
            [
              set color item 2 thisLine
              set thickness item 7 thisLine
            ]
          ]
          set thisLine csv:from-row file-read-line
        ]
      ]
    ]
    file-close
  ]

end

to-report get-flowHolder-who-from-link-data [ linkDataEntry ]

  let str remove "{" linkDataEntry
  set str remove "f" str
  set str remove "l" str
  set str remove "o" str
  set str remove "w" str
  set str remove "h" str
  set str remove "d" str
  set str remove "e" str
  set str remove "r" str
  set str remove " " str
  report read-from-string remove "}" str

end
@#$#@#$#@
GRAPHICS-WINDOW
728
43
1204
520
-1
-1
9.36
1
10
1
1
1
0
0
0
1
0
49
0
49
0
0
1
ticks
30.0

BUTTON
9
10
76
57
create
create-terrain
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

TEXTBOX
167
93
238
118
ELEVATION
11
0.0
1

TEXTBOX
10
367
315
543
---------- used when algorithm-style = C# -------------------------------------------\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|                                                                                                  |\n|___________________________________________________________|
9
0.0
1

TEXTBOX
322
427
488
452
used when algorithm-style = NetLogo
9
0.0
1

MONITOR
559
368
660
413
land ratio
landRatio
4
1
11

SLIDER
489
224
684
257
par_seaLevel
par_seaLevel
round min (list minElevation par_riftElevation)
round max (list maxElevation par_rangeElevation)
24.0
1
1
m
HORIZONTAL

SLIDER
15
175
187
208
par_elevationNoise
par_elevationNoise
0
(par_rangeElevation - par_riftElevation) / 2
1.0
1
1
m
HORIZONTAL

SLIDER
14
217
196
250
par_elevationSmoothStep
par_elevationSmoothStep
0
1
0.0
0.01
1
NIL
HORIZONTAL

INPUTBOX
80
10
156
70
randomSeed
4.0
1
0
Number

INPUTBOX
345
438
468
498
par_inversionIterations
0.0
1
0
Number

MONITOR
563
456
661
501
sdElevation
precision sdElevation 4
4
1
11

MONITOR
526
411
608
456
minElevation
precision minElevation 4
4
1
11

MONITOR
602
411
689
456
maxElevation
precision maxElevation 4
4
1
11

INPUTBOX
307
106
395
166
par_numRanges
0.0
1
0
Number

INPUTBOX
308
226
400
286
par_rangeLength
0.0
1
0
Number

INPUTBOX
308
165
395
225
par_numRifts
0.0
1
0
Number

INPUTBOX
308
286
400
346
par_riftLength
0.0
1
0
Number

SLIDER
15
109
187
142
par_riftElevation
par_riftElevation
-500
0
0.0
1
1
m
HORIZONTAL

BUTTON
483
262
691
295
refresh after changing sea level
refresh-view-after-seaLevel-change
NIL
1
T
OBSERVER
NIL
3
NIL
NIL
1

SLIDER
15
142
187
175
par_rangeElevation
par_rangeElevation
0
500
0.0
1
1
m
HORIZONTAL

MONITOR
525
156
610
201
NIL
count patches
0
1
11

SLIDER
32
468
186
501
par_rangeAggregation
par_rangeAggregation
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
32
501
186
534
par_riftAggregation
par_riftAggregation
0
1
0.0
.01
1
NIL
HORIZONTAL

INPUTBOX
14
380
137
440
par_numProtuberances
0.0
1
0
Number

INPUTBOX
154
380
270
440
par_numDepressions
0.0
1
0
Number

SLIDER
14
250
195
283
par_smoothingNeighborhood
par_smoothingNeighborhood
0
.1
0.0
.01
1
NIL
HORIZONTAL

MONITOR
615
156
680
201
maxDist
precision maxDist 4
4
1
11

MONITOR
48
283
197
320
smoothing neighborhood size
(word (count patches with [ distance patch 0 0 < smoothingNeighborhood ] - 1) \" patches\")
0
1
9

PLOT
323
510
697
630
Elevation per patch
m
NIL
0.0
10.0
0.0
10.0
true
false
"set-histogram-num-bars 100\nset-plot-x-range (round min [elevation] of patches - 1) (round max [elevation] of patches + 1)" "set-histogram-num-bars 100\nset-plot-x-range (round min [elevation] of patches - 1) (round max [elevation] of patches + 1)"
PENS
"default" 1.0 1 -16777216 true "" "histogram [elevation] of patches"
"pen-1" 1.0 1 -2674135 true "" "histogram n-values plot-y-max [j -> seaLevel]"

CHOOSER
322
365
506
410
algorithm-style
algorithm-style
"NetLogo" "C#"
1

SLIDER
17
323
197
356
par_featureAngleRange
par_featureAngleRange
0
360
0.0
1
1
º
HORIZONTAL

SLIDER
15
588
211
621
par_ySlope
par_ySlope
-0.1
0.1
0.0
0.001
1
NIL
HORIZONTAL

CHOOSER
543
66
681
111
display-mode
display-mode
"terrain"
0

SLIDER
15
555
211
588
par_xSlope
par_xSlope
-0.1
0.1
0.0
0.001
1
NIL
HORIZONTAL

BUTTON
573
113
645
146
refresh
refresh-view
NIL
1
T
OBSERVER
NIL
2
NIL
NIL
1

PLOT
708
514
1204
634
Horizontal transect
pxcor
m
0.0
10.0
0.0
10.0
true
false
"" "clear-plot\nset-plot-x-range (min-pxcor - 1) (max-pxcor + 1)\nset-plot-y-range (round min [elevation] of patches - 1) (round max [elevation] of patches + 1)"
PENS
"default" 1.0 0 -16777216 true "" "plot-horizontal-transect"
"pen-1" 1.0 0 -13345367 true "" "plot-sea-level-horizontal-transect"
"pen-2" 1.0 0 -2674135 true "" "plotxy xTransect plot-y-max plotxy xTransect plot-y-min"

SLIDER
698
39
731
517
yTransect
yTransect
min-pycor
max-pycor
0.0
1
1
NIL
VERTICAL

SLIDER
725
12
1211
45
xTransect
xTransect
min-pxcor
max-pxcor
0.0
1
1
NIL
HORIZONTAL

PLOT
1203
36
1363
521
vertical transect
m
pycor
0.0
10.0
0.0
10.0
true
false
"" "clear-plot\nset-plot-y-range (min-pycor - 1) (max-pycor + 1)\nset-plot-x-range (round min [elevation] of patches - 1) (round max [elevation] of patches + 1)"
PENS
"default" 1.0 0 -16777216 true "" "plot-vertical-transect"
"pen-1" 1.0 0 -13345367 true "" "plot-sea-level-vertical-transect"
"pen-2" 1.0 0 -2674135 true "" "plotxy  plot-x-max yTransect plotxy plot-x-min yTransect"

BUTTON
1230
579
1330
612
update transects
update-transects\nupdate-plots
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1220
545
1345
578
show-transects
show-transects
0
1
-1000

SLIDER
15
623
210
656
par_valleyAxisInclination
par_valleyAxisInclination
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
15
656
210
689
par_valleySlope
par_valleySlope
-0.1
0.1
0.0
0.001
1
NIL
HORIZONTAL

CHOOSER
393
14
527
59
type-of-experiment
type-of-experiment
"random" "user-defined" "defined by expNumber"
0

BUTTON
159
13
269
46
NIL
export-terrain
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
272
13
380
46
import-terrain
import-terrain\nsetup-patch-coordinates-labels \"bottom\" \"left\"\nsetup-transect\nupdate-transects\nupdate-plots
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
171
50
367
83
export-random-terrain (100x)
repeat 100 [ export-random-terrain ]
NIL
1
T
OBSERVER
NIL
9
NIL
NIL
1

BUTTON
536
21
688
54
parameters to default
parameters-to-default
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
186
108
251
145
NIL
riftElevation
2
1
9

MONITOR
186
142
262
179
NIL
rangeElevation
2
1
9

MONITOR
186
173
261
210
NIL
elevationNoise
2
1
9

MONITOR
196
215
296
252
NIL
elevationSmoothStep
2
1
9

MONITOR
194
250
306
287
NIL
smoothingNeighborhood
2
1
9

MONITOR
395
117
454
154
NIL
numRanges
0
1
9

MONITOR
396
175
453
212
NIL
numRifts
0
1
9

MONITOR
401
237
467
274
NIL
rangeLength
0
1
9

MONITOR
400
301
457
338
NIL
riftLength
0
1
9

MONITOR
198
322
302
359
NIL
featureAngleRange
0
1
9

MONITOR
215
552
281
589
NIL
xSlope
4
1
9

MONITOR
217
589
281
626
NIL
ySlope
4
1
9

MONITOR
217
626
318
663
NIL
valleyAxisInclination
4
1
9

MONITOR
216
663
317
700
NIL
valleySlope
4
1
9

MONITOR
15
427
105
464
NIL
numProtuberances
0
1
9

MONITOR
154
425
238
462
NIL
numDepressions
0
1
9

MONITOR
188
466
285
503
NIL
rangeAggregation
4
1
9

MONITOR
189
503
272
540
NIL
riftAggregation
4
1
9

SWITCH
471
312
572
345
do-fill-sinks
do-fill-sinks
0
1
-1000

SWITCH
572
312
676
345
show-flows
show-flows
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

this version creates rivers over the terrain generated by v1 algorithms and derives the soil moisture of patches from rivers and meters below sea level. Rivers are formed by one or more streams which start at random patches and move from patch to patch towards the least elevation. There are two algorithms implementing the movement of streams: choosing only among neighbors (`river-algorithm = "least neighbor"`), favouring connections between basins, or neighbors *AND* the patch considered (`river-algorithm = "absolute downhill"`), producing 'stump' rivers more often. Every time a stream is formed, the elevation of the patches involved is depressed by a quantity (`par_waterDepression`) and then smoothed, together with that of neighboring patches. A passing stream will add 1 unit of `water` to a patch while patches below sea level have `water` units proportional to their depth. The amount of `water` of patches is converted to units of `moisture` and then moisture is distributed to other 'dry' patches using NetLogo's primitive `diffuse` (NOTE: not ideal because it does not account for the difference in elevation). 

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

line half 1
true
0
Line -7500403 true 150 0 150 300
Rectangle -7500403 true true 135 0 165 150

line half 2
true
0
Line -7500403 true 150 0 150 300
Rectangle -7500403 true true 120 0 180 150

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
NetLogo 6.0.4
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
