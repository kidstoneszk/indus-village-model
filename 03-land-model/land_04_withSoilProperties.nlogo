;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;  Land model - v03 with flow accumulation
;;  Copyright (C) Andreas Angourakis (andros.spica@gmail.com)
;;  available at https://www.github.com/Andros-Spica/indus-village-model
;;  Based on the 'Terrain Builder - waterFlow' template by same author
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
  ;;; constants
  patchArea
  maxDist

  ;;; table inputs
  ;;;;; hydrologic Soil Groups table
  soil_textureTypes                           ; Types of soil according to % of sand, silt and clay (ternary diagram) established by USDA
  soil_hydrologicSoilGroups                   ; USDA classification of soils according to water infiltration (A, B, C, and D) per each texture type

  ;;;;; run off curve number table
  soil_runOffCurveNumberTable                 ; table (list of lists) with run off curve numbers of Hydrologic Soil Group (columns) combination of cover type-treatment-hydrologic condition

  ;;;;; Field Capacity and Water Holding capacity table
  soil_fieldCapacity                   ; field capacity (% soil volume) per texture type
  soil_minWaterHoldingCapacity         ; minimum and maximum water holding capacity (in/ft) per texture type
  soil_maxWaterHoldingCapacity
  soil_intakeRate                      ; intake rate (mm/hour) per texture type

  ;;; parameters (modified copies of interface input) ===============================================================

  ;;;; elevation
  numContinents
  numOceans

  numRanges
  rangeLength
  rangeElevation
  rangeAggregation

  numRifts
  riftLength
  riftElevation
  riftAggregation

  featureAngleRange
  continentality
  elevationNoise
  seaLevel
  elevationSmoothStep
  smoothingNeighborhood

  xSlope
  ySlope

  valleyAxisInclination
  valleySlope

  ;;;; water flow accumulation
  riverFlowAccumulationAtStart

  ;;;; soil
  soil_minDepth                          ; minimum soil depth
  soil_maxDepth                          ; maximum soil depth
  soil_erosionRate_depth                 ; rate of increase in soil depth depending on flowAccumulation
  soil_depthNoise                        ; random variation in soil depth (standard deviation)

  soil_min%sand                          ; minimum percentage of sand (within the represented area)
  soil_max%sand                          ; maximum percentage of sand (within the represented area)
  soil_erosionRate_%sand                 ; rate of decrease of % sand depending on flowAccumulation
  soil_min%silt                          ; minimum percentage of silt (within the represented area)
  soil_max%silt                          ; maximum percentage of silt (within the represented area)
  soil_erosionRate_%silt                 ; rate of increase of % silt depending on flowAccumulation
  soil_min%clay                          ; minimum percentage of clay (within the represented area)
  soil_max%clay                          ; maximum percentage of clay (within the represented area)
  soil_erosionRate_%clay                 ; rate of increase of % clay depending on flowAccumulation
  soil_textureNoise                      ; random variation in the proportion of sand/silt/clay (standard deviation of every component previous to normalisation)

  ;;; variables ===============================================================
  landOceanRatio
  elevationDistribution
  minElevation
  sdElevation
  maxElevation
  maxFlowAccumulation
]

patches-own
[
  elevation             ; in metres (m)
  flowDirection
  receivesFlow
  flowAccumulationState
  flowAccumulation

  ;;; soil conditions
  p_soil_depth          ; in milimeters (mm)

  p_soil_%sand          ; percentage of sand fraction in soil
  p_soil_%silt          ; percentage of silt fraction in soil
  p_soil_%clay          ; percentage of clay fraction in soil
  p_soil_textureType          ; soil texture type according to sand-silt-clay proportions, under USDA convention
  p_soil_hydrologicSoilGroup  ; USDA simplification of soil texture types into four categories

  p_soil_coverTreatmentAndHydrologicCondition  ; the type of combination of cover, treatment and hydrologic condition used to estimate runoff curve number (see "runOffCurveNumberTable.csv")
  p_soil_runOffCurveNumber                     ; runoff curve number (0=full retention to 100=full impermeability)

  ; Soil water capacities:
  ; ___ saturation
  ;  |
  ;  |  gravitational water
  ;  |  (rapid drainage)
  ;  |
  ; --- field capacity
  ;  |
  ;  |  water holding capacity or available soil moisture or capilary water
  ;  |  (slow drainage)
  ; --- permanent wilting point
  ;  |
  ;  |  unavailable soil moisture or hydroscopic water
  ;  |  (no drainage)
  ; --- oven dry

  p_soil_fieldCapacity              ; Field Capacity (% soil volume)
  p_soil_waterHoldingCapacity       ; Water Holding Capacity (% soil volume)
  p_soil_wiltingPoint               ; Wilting Point (% soil volume)

  p_soil_deepDrainageCoefficient    ; fraction of soil water above field capacity drained per day (%)
]

breed [ mapSetters mapSetter ]

mapSetters-own [ points ]

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

  set-flow-accumulations

  ;;; END - flow related procedures ;;;;;;;;;;;;;;;;;;;;;;;

  ;;; START - soil related procedures ;;;;;;;;;;;;;;;;;;;;;;;

  load-hydrologic-soil-groups-table

  load-runoff-curve-number-table

  load-soil-water-table

  setup-soil-conditions

  ;;; END - soil related procedures ;;;;;;;;;;;;;;;;;;;;;;;

  set landOceanRatio count patches with [elevation > seaLevel] / count patches
  set elevationDistribution [elevation] of patches
  set minElevation min [elevation] of patches
  set maxElevation max [elevation] of patches
  set sdElevation standard-deviation [elevation] of patches

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

  ;parameters-check-1

  if (type-of-experiment = "user-defined")
  [
    ;;; load parameters from user interface
    set numContinents par_numContinents
    set numOceans par_numOceans

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

    set continentality par_continentality * count patches

    set elevationSmoothStep par_elevationSmoothStep
    set smoothingNeighborhood par_smoothingNeighborhood * maxDist

    set seaLevel par_seaLevel

    set xSlope par_xSlope
    set ySlope par_ySlope

    set valleyAxisInclination par_valleyAxisInclination
    set valleySlope par_valleySlope

    set riverFlowAccumulationAtStart par_riverFlowAccumulationAtStart

    set soil_minDepth par_soil_minDepth
    set soil_maxDepth par_soil_maxDepth
    set soil_erosionRate_depth par_soil_erosionRate_depth
    set soil_depthNoise par_soil_depthNoise

    set soil_min%sand par_soil_min%sand
    set soil_max%sand par_soil_max%sand
    set soil_erosionRate_%sand par_soil_erosionRate_%sand

    set soil_min%silt par_soil_min%silt
    set soil_max%silt par_soil_max%silt
    set soil_erosionRate_%silt par_soil_erosionRate_%silt

    set soil_min%clay par_soil_min%clay
    set soil_max%clay par_soil_max%clay
    set soil_erosionRate_%clay par_soil_erosionRate_%clay

    set soil_textureNoise par_soil_textureNoise
  ]

  if (type-of-experiment = "random") ; TODO
  [
    ;;; get random values within an arbitrary (reasonable) range of values
    ;;; this depends on what type and scale of terrain you want
    ;;; Here, our aim is to create inland/coastal, plain, small-scale terrains with a general flow running from N to S (e.g., 5km^2 Haryana, India)
    set numContinents 1 + random 10
    set numOceans 1 + random 10

    set numRanges 1 + random 100
    set rangeLength round ( (random-float 100) * maxDist)
    set rangeElevation random-float 20
    set rangeAggregation random-float 1

    set numRifts 1 + random 100
    set riftLength round ( (random-float 100) * maxDist)
    set riftElevation 0;-1 * random-float 1
    set riftAggregation random-float 1

    set elevationNoise random-float 1

    set featureAngleRange random-float 30

    set continentality (random-float 2) * count patches

    set elevationSmoothStep 1 ; not randomised
    set smoothingNeighborhood 0.1 * maxDist ; not randomised

    set seaLevel 0 ; riftElevation + (random-float (rangeElevation - riftElevation))

    set xSlope random-float 0.01 ; W depression
    set ySlope random-float 0.01 ; S depression

    set valleyAxisInclination random-float 1
    set valleySlope random-float 0.02 ; only valley (no ridges)

    set riverFlowAccumulationAtStart random 1E6

    set soil_minDepth 50 + random-float 250
    set soil_maxDepth soil_minDepth + random-float 300
    set soil_erosionRate_depth random-float 0.1
    set soil_depthNoise random-float 50

    set soil_min%sand random-float 100
    set soil_max%sand soil_min%sand + random-float (100 - soil_min%sand)
    set soil_erosionRate_%sand random-float 0.1;(1 + random 2) / (1 + random 2)

    set soil_min%silt random-float 100
    set soil_max%silt soil_min%silt + random-float (100 - soil_min%silt)
    set soil_erosionRate_%silt random-float 0.1;(1 + random 2) / (1 + random 2)

    set soil_min%clay random-float 100
    set soil_max%clay soil_min%clay + random-float (100 - soil_min%clay)
    set soil_erosionRate_%clay random-float 0.1; (1 + random 2) / (1 + random 2)

    set soil_textureNoise random-float 10
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

  if (par_numContinents = 0)                    [ set par_numContinents                   1 ]
  if (par_numOceans = 0)                        [ set par_numOceans                       1 ]

  if (par_continentality = 0)                   [ set par_continentality                  5 ]

  if (par_numRanges = 0)                        [ set par_numRanges                       1 ]
  if (par_rangeLength = 0)                      [ set par_rangeLength                   100 ]
  if (par_rangeAggregation = 0)                 [ set par_rangeAggregation                0.75 ]

  if (par_numRifts = 0)                         [ set par_numRifts                        1 ]
  if (par_riftLength = 0)                       [ set par_riftLength                    100 ]
  if (par_riftAggregation = 0)                  [ set par_riftAggregation                 0.9 ]

  if (par_seaLevel = 0)                         [ set par_seaLevel                        0 ]
  if (par_elevationSmoothStep = 0)              [ set par_elevationSmoothStep             1 ]
  if (par_smoothingNeighborhood = 0)            [ set par_smoothingNeighborhood           0.1 ]

  if (par_xSlope = 0)                           [ set par_xSlope                          0.01 ]
  if (par_ySlope = 0)                           [ set par_ySlope                          0.025 ]
  if (par_valleyAxisInclination = 0)            [ set par_valleyAxisInclination           0.1 ]
  if (par_valleySlope = 0)                      [ set par_valleySlope                     0.02 ]

  if (par_riverFlowAccumulationAtStart = 0)     [ set par_riverFlowAccumulationAtStart  1E6 ]

  if (par_soil_minDepth = 0)                    [ set par_soil_minDepth                300 ]
  if (par_soil_maxDepth = 0)                    [ set par_soil_maxDepth                500 ]
  if (par_soil_erosionRate_depth = 0)          [ set par_soil_erosionRate_depth        0.04 ]
  if (par_soil_depthNoise = 0)                  [ set par_soil_depthNoise               50 ]

  if (par_soil_min%sand = 0)                    [ set par_soil_min%sand                 60 ]
  if (par_soil_max%sand = 0)                    [ set par_soil_max%sand                 90 ]
  if (par_soil_erosionRate_%sand = 0)          [ set par_soil_erosionRate_%sand        0.04 ]

  if (par_soil_min%silt = 0)                    [ set par_soil_min%silt                 40 ]
  if (par_soil_max%silt = 0)                    [ set par_soil_max%silt                 70 ]
  if (par_soil_erosionRate_%silt = 0)          [ set par_soil_erosionRate_%silt        0.02 ]

  if (par_soil_min%clay = 0)                    [ set par_soil_min%clay                  0 ]
  if (par_soil_max%clay = 0)                    [ set par_soil_max%clay                 50 ]
  if (par_soil_erosionRate_%clay = 0)          [ set par_soil_erosionRate_%clay        0.01 ]

  if (par_soil_textureNoise = 0)                [ set par_soil_textureNoise              5 ]

end

to parameters-to-default

  ;;; set parameters to a default value
  set par_rangeElevation                   15
  set par_riftElevation                    0
  set par_elevationNoise                     1

  set par_numContinents                   1
  set par_numOceans                       1

  set par_continentality                  5

  set par_numRanges                       1
  set par_rangeLength                   100
  set par_rangeAggregation                0.75

  set par_numRifts                        1
  set par_riftLength                    100
  set par_riftAggregation                 0.9

  set par_seaLevel                        0
  set par_elevationSmoothStep             1
  set par_smoothingNeighborhood           0.1

  set par_xSlope                          0.01
  set par_ySlope                          0.025
  set par_valleyAxisInclination           0.1
  set par_valleySlope                     0.02

  set par_riverFlowAccumulationAtStart  1E6

  set par_soil_minDepth                    300
  set par_soil_maxDepth                    500
  set par_soil_erosionRate_depth            2
  set par_soil_depthNoise                    0.04

  set par_soil_min%sand                     60
  set par_soil_max%sand                     90
  set par_soil_erosionRate_%sand            0.04

  set par_soil_min%silt                     40
  set par_soil_max%silt                     70
  set par_soil_erosionRate_%silt            0.02

  set par_soil_min%clay                      0
  set par_soil_max%clay                     50
  set par_soil_erosionRate_%clay            0.01

  set par_soil_textureNoise 5

end

to set-landform-NetLogo ;[ numRanges rangeLength rangeElevation numRifts riftLength riftElevation continentality smoothingNeighborhood elevationSmoothStep]

  ; Netlogo-like code
  ask n-of numRanges patches [ sprout-mapSetters 1 [ set points random rangeLength ] ]
  ask n-of numRifts patches with [any? turtles-here = false] [ sprout-mapSetters 1 [ set points (random riftLength) * -1 ] ]

  let steps sum [ abs points ] of mapSetters
  repeat steps
  [
    ask one-of mapSetters
    [
      let sign 1
      let scale maxElevation
      if ( points < 0 ) [ set sign -1 set scale minElevation ]
      ask patch-here [ set elevation scale ]
      set points points - sign
      if (points = 0) [die]
      rt (random-exponential featureAngleRange) * (1 - random-float 2)
      forward 1
    ]
  ]

  smooth-elevation-all

  let underWaterPatches patches with [elevation < 0]
  let aboveWaterPatches patches with [elevation > 0]

  repeat continentality
  [
    if (any? underWaterPatches AND any? aboveWaterPatches)
    [
      let p_ocean max-one-of underWaterPatches [ count neighbors with [elevation > 0] ]
      let p_land  max-one-of aboveWaterPatches [ count neighbors with [elevation < 0] ]
      let temp [elevation] of p_ocean
      ask p_ocean [ set elevation [elevation] of p_land ]
      ask p_land [ set elevation temp ]
      set underWaterPatches underWaterPatches with [pxcor != [pxcor] of p_ocean AND pycor != [pycor] of p_ocean]
      set aboveWaterPatches aboveWaterPatches with [pxcor != [pxcor] of p_land AND pycor != [pycor] of p_land]
    ]
  ]

  smooth-elevation-all

end

to set-landform-Csharp ;[ elevationNoise numContinents numRanges rangeLength rangeElevation rangeAggregation numOceans numRifts riftLength riftElevation riftAggregation smoothingNeighborhood elevationSmoothStep]

  ; C#-like code
  let p1 0
  let sign 0
  let len 0
  let elev 0

  let continents n-of numContinents patches
  let oceans n-of numOceans patches

  let maxDistBetweenRanges (1.1 - rangeAggregation) * maxDist
  let maxDistBetweenRifts (1.1 - riftAggregation) * maxDist

  repeat (numRanges + numRifts)
  [
    set sign -1 + 2 * (random 2)
    if (numRanges = 0) [ set sign -1 ]
    if (numRifts = 0) [ set sign 1 ]

    ifelse (sign = -1)
    [
      set numRifts numRifts - 1
      set len riftLength - 2
      set elev minElevation
      ;ifelse (any? patches with [elevation < 0]) [set p0 one-of patches with [elevation < 0]] [set p0 one-of patches]
      set p1 one-of patches with [ distance one-of oceans < maxDistBetweenRifts ]
    ]
    [
      set numRanges numRanges - 1
      set len rangeLength - 2
      set elev maxElevation
      set p1 one-of patches with [ distance one-of continents < maxDistBetweenRanges ]
    ]

    draw-elevation-pattern p1 len elev
  ]

  smooth-elevation-all

  ask patches with [elevation = 0]
  [
    set elevation random-normal 0 elevationNoise
  ]

  smooth-elevation-all

end

to draw-elevation-pattern [ p1 len elev ]

  let p2 0
  let x-direction 0
  let y-direction 0
  let directionAngle 0

  ask p1 [ set elevation elev set p2 one-of neighbors ]
  set x-direction ([pxcor] of p2) - ([pxcor] of p1)
  set y-direction ([pycor] of p2) - ([pycor] of p1)
  ifelse (x-direction = 1 AND y-direction = 0) [ set directionAngle 0 ]
  [ ifelse (x-direction = 1 AND y-direction = 1) [ set directionAngle 45 ]
    [ ifelse (x-direction = 0 AND y-direction = 1) [ set directionAngle 90 ]
      [ ifelse (x-direction = -1 AND y-direction = 1) [ set directionAngle 135 ]
        [ ifelse (x-direction = -1 AND y-direction = 0) [ set directionAngle 180 ]
          [ ifelse (x-direction = -1 AND y-direction = -1) [ set directionAngle 225 ]
            [ ifelse (x-direction = 0 AND y-direction = -1) [ set directionAngle 270 ]
              [ ifelse (x-direction = 1 AND y-direction = -1) [ set directionAngle 315 ]
                [ if (x-direction = 1 AND y-direction = 0) [ set directionAngle 360 ] ]
              ]
            ]
          ]
        ]
      ]
    ]
  ]

  repeat len
  [
    set directionAngle directionAngle + (random-exponential featureAngleRange) * (1 - random-float 2)
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
    ifelse (pxcor < (world-height / 2))
    [
      set elevation elevation - (xSlope * (elevation - riftElevation) * ((world-width / 2) - pxcor))
    ]
    [
      set elevation elevation + (xSlope * (rangeElevation - elevation) * (pxcor - (world-width / 2)))
    ]
    ifelse (pycor < (world-width / 2))
    [
      set elevation elevation - (ySlope * (elevation - riftElevation) * ((world-height / 2) - pycor))
    ]
    [
      set elevation elevation + (ySlope * (rangeElevation - elevation) * (pycor - (world-height / 2)))
    ]
  ]

end

to set-valleySlope

  ; bend terrain as a valley (valleySlope > 0) or a ridge (valleySlope < 0) following a North-South pattern
  ask patches
  [
    let xValley (world-width / 2) + valleyAxisInclination * (pycor - (world-height / 2))
    set elevation elevation + (valleySlope * (rangeElevation - elevation) * abs (xValley - pxcor))
  ]

  ; find which edge has the lower average elevation
  let highestEdge patches with [pycor = max-pycor] ; north
  if (mean [elevation] of highestEdge < mean [elevation] of patches with [pycor = min-pycor])
  [ set highestEdge patches with [pycor = min-pycor] ] ; south

  ; give an arbitrarily, ridiculously high value (riverFlowAccumulationAtStart) of flowAccumulation to the lowest patch at that edge
  ; assign it an inward flowDirection (set-flowDirection will not overwrite this)
  ask min-one-of highestEdge [elevation] ; a patch at the bottom of the valley
  [
    set flowAccumulation riverFlowAccumulationAtStart
    let downstreamPatch min-one-of neighbors with [not is-at-edge] [elevation]
    set flowDirection get-flow-direction-encoding ([pxcor] of downstreamPatch - pxcor) ([pycor] of downstreamPatch - pycor)
  ]

end

;=======================================================================================================
;;; START of algorithms based on:
;;; Huang P C and Lee K T 2015
;;; A simple depression-filling method for raster and irregular elevation datasets
;;; J. Earth Syst. Sci. 124 1653–65
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
;;; Huang P C and Lee K T 2015
;;; A simple depression-filling method for raster and irregular elevation datasets
;;; J. Earth Syst. Sci. 124 1653–65
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

to-report flow-direction-is [ centralPatch ]

  if (flowDirection = get-flow-direction-encoding ([pxcor] of centralPatch - pxcor) ([pycor] of centralPatch - pycor))
  [ report true ]

  report false

end

to-report get-flow-direction-encoding [ x y ]

  if (x = -1 and y = -1) [ report 16 ]
  if (x = -1 and y = 0) [ report 32 ]
  if (x = -1 and y = 1) [ report 64 ]

  if (x = 0 and y = -1) [ report 8 ]
  if (x = 0 and y = 1) [ report 128 ]

  if (x = 1 and y = -1) [ report 4 ]
  if (x = 1 and y = 0) [ report 2 ]
  if (x = 1 and y = 1) [ report 1 ]

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

to-report flow-direction-is-loop ; ego = patch

  let thisPatch self
  let dowstreamPatch get-patch-in-flow-direction flowDirection
  ;print (word "thisPatch: " thisPatch "dowstreamPatch: " dowstreamPatch)

  if (dowstreamPatch != nobody)
  [ report [flow-direction-is thisPatch] of dowstreamPatch ]

  report false

end

to set-flow-directions

  ask patches with [ flowDirection = 0 ]
  [
    ifelse (is-at-edge)
    [
      if ( pxcor = min-pxcor ) [ set flowDirection 32 ] ; west
      if ( pxcor = max-pxcor ) [ set flowDirection 2 ] ; east
      if ( pycor = min-pycor ) [ set flowDirection 8 ] ; south
      if ( pycor = max-pycor ) [ set flowDirection 128 ] ; north
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

to set-flow-accumulations

  ; From Jenson, S. K., & Domingue, J. O. (1988), p. 1594
  ; "FLOW ACCUMULATION DATA SET
  ; The third procedure of the conditioning phase makes use of the flow direction data set to create the flow accumulation data set,
  ; where each cell is assigned a value equal to the number of cells that flow to it (O’Callaghan and Mark, 1984).
  ; Cells having a flow accumulation value of zero (to which no other cells flow) generally correspond to the pattern of ridges.
  ; Because all cells in a depressionless DEM have a path to the data set edge, the pattern formed by highlighting cells
  ; with values higher than some threshold delineates a fully connected drainage network. As the threshold value is increased,
  ; the density of the drainage network decreases. The flow accumulation data set that was calculated for the numeric example
  ; is shown in Table 2d, and the visual example is shown in Plate 1c."

  ; identify patches that receive flow and those that do not (this makes the next step much easier)
  ask patches
  [
    set receivesFlow false
    set flowAccumulationState "start"
    ;set pcolor red
  ]

  ask patches with [has-flow-direction-code]
  [
    let patchInFlowDirection get-patch-in-flow-direction flowDirection
    if (patchInFlowDirection != nobody)
    [
      ask patchInFlowDirection
      [
        set receivesFlow true
        set flowAccumulationState "pending"
        ;set pcolor yellow
      ]
    ]
  ]

  let maxIterations 100000 ; just as a safety measure, to avoid infinite loop
  while [count patches with [flowAccumulationState = "pending" and not flow-direction-is-loop] > 0 and maxIterations > 0 and count patches with [flowAccumulationState = "start"] > 0 ]
  [
    ask one-of patches with [flowAccumulationState = "start"]
    [
      let downstreamPatch get-patch-in-flow-direction flowDirection
      let nextFlowAccumulation flowAccumulation + 1

      set flowAccumulationState "done"
      ;set pcolor orange

      if (downstreamPatch != nobody)
      [
        ask downstreamPatch
        [
          set flowAccumulation flowAccumulation + nextFlowAccumulation
          if (count neighbors with [
            get-patch-in-flow-direction flowDirection = downstreamPatch and
            (flowAccumulationState = "pending" or flowAccumulationState = "start")
            ] = 0
          )
          [
            set flowAccumulationState "start"
            ;set pcolor red
          ]
        ]
      ]
    ]

    set maxIterations maxIterations - 1
  ]

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

to setup-soil-conditions

  ; set maximum flow accumulation as a reference excluding the flow entering through the river
  set maxFlowAccumulation max [flowAccumulation] of patches with [flowAccumulation < riverFlowAccumulationAtStart]

  ask patches
  [
    setup-soil-depth

    setup-soil-texture

    setup-soil-coverAndTreatment

    setup-soil-soilWaterProperties
  ]

end

to setup-soil-depth

  set p_soil_depth clampMinMax (
    get-soil-depth (flowAccumulation / maxFlowAccumulation)
    + (random-normal 0 soil_depthNoise))
    0 100

end

to-report get-soil-depth [ relativeFlowAccumulation ]

  ;;; Following the same rationale of soil texture, soil depth is positively related to flow accumulation.
  ;;; Soil particles are derived from the parent geological material, eroded by environmental factors, and assumingly accumulate more downhill following the flow path.
  report soil_minDepth + (soil_maxDepth - soil_minDepth) * (get-value-in-sigmoid relativeFlowAccumulation soil_erosionRate_depth)

end

to setup-soil-texture

  ;;; assign % of sand, silt and clay according to flowAccumulation, min/max, and noise parameters
  ;;; NOTE: %sand decrease with flowAccumulation while %silt and %clay increase
  ;;; useful reference: https://www.earthonlinemedia.com/ebooks/tpe_3e/soil_systems/soil__development_soil_forming_factors.html

  set p_soil_%sand clampMinMax (
    get-soil-%sand (flowAccumulation / maxFlowAccumulation)               ; as function of flowAccumulation
    + (random-normal 0 soil_textureNoise))   ; add some random variation
    0 100                                    ; clampMinMax <value> 0 100 -- keeps value within range of 0-100, after adding normal noise

  set p_soil_%silt clampMinMax (
    get-soil-%silt (flowAccumulation / maxFlowAccumulation)
    + (random-normal 0 soil_textureNoise))
    0 100

  set p_soil_%clay clampMinMax (
    get-soil-%clay (flowAccumulation / maxFlowAccumulation)
    + (random-normal 0 soil_textureNoise))
    0 100

  ;;; normalise values to sum up 100 %
  let total p_soil_%sand + p_soil_%silt + p_soil_%clay

  set p_soil_%sand 100 * p_soil_%sand / total
  set p_soil_%silt 100 * p_soil_%silt / total
  set p_soil_%clay 100 * p_soil_%clay / total

  ;;; get soil texture type according to sand/silt/clay composition
  set p_soil_textureType get-soil-texture-type (p_soil_%sand) (p_soil_%silt) (p_soil_%clay)

  ;;; get hydrologic soil group
  set p_soil_hydrologicSoilGroup item (position p_soil_textureType soil_textureTypes) soil_hydrologicSoilGroups

end

;;; NOTE on soil texture formation:
;;; it might be possible to reduce the number of parameters related to soil texture by:
;;; - using a single erosion curve parameter (must consult with pedologist)

to-report get-soil-%sand [ relativeFlowAccumulation ]

  ;;; %sand is negatively related to flow accumulation. Sand is the coarser fraction of particles derived from the parent geological material
  ;;; that will assumingly erode progressively into finer particles down the flow path through physical and chemical processes.
  report soil_min%sand + (soil_max%sand - soil_min%sand) * (1 - get-value-in-sigmoid relativeFlowAccumulation soil_erosionRate_%sand)

end

to-report get-soil-%silt [ relativeFlowAccumulation ]

  ;;; %silt is positively related to flow accumulation. Silt is the intermediate, finer fraction of particles derived from sand and, ultimately,
  ;;; the parent geological material. Thus, silt is being accumulated through the erosion of sand by environmental factors, assumingly following the flow path.
  report soil_min%silt + (soil_max%silt - soil_min%silt) * (get-value-in-sigmoid relativeFlowAccumulation soil_erosionRate_%silt)

end

to-report get-soil-%clay [ relativeFlowAccumulation ]

  ;;; %clay is positively related to flow accumulation. Clay is the finest fraction of particles derived from sand, silt, and, ultimately,
  ;;; the parent geological material. Thus, clay is being accumulated through the erosion of coarser particles by environmental factors, assumingly following the flow path.
  report soil_min%clay + (soil_max%clay - soil_min%clay) * (get-value-in-sigmoid relativeFlowAccumulation soil_erosionRate_%clay)

end

to-report get-soil-texture-type [ %sand %silt %clay ]

  ;;; based on ternary plot classification by the United States Department of Agriculture (USDA)

  if ((%sand > 85) and (%silt <= 15) and (%clay <= 10)) [ report "Sand" ]

  if ((%sand > 70 and %sand <= 90) and (%silt <= 30) and (%clay <= 15)) [ report "Loamy sand" ]

  if ((%sand > 42.5 and %sand <= 85) and (%silt <= 50) and (%clay <= 20)) [ report "Sandy loam" ]

  if ((%sand > 45) and (%silt <= 27.5) and (%clay > 20 and %clay <= 35)) [ report "Sandy clay loam" ]

  if ((%sand > 45) and (%silt <= 20) and (%clay > 35 and %clay <= 55)) [ report "Sandy clay" ]

  if ((%sand <= 45) and (%silt <= 40) and (%clay > 40)) [ report "Clay" ]

  if ((%sand <= 20) and (%silt > 40 and %silt <= 60) and (%clay > 40 and %clay <= 60)) [ report "Silty clay" ]

  if ((%sand <= 20) and (%silt > 40 and %silt <= 72.5) and (%clay > 27.5 and %clay <= 40)) [ report "Silty clay loam" ]

  if ((%sand <= 50) and (%silt > 50 and %silt <= 87.5) and (%clay <= 27.5)) [ report "Silt loam" ]

  if ((%sand <= 20) and (%silt > 80) and (%clay <= 12.5)) [ report "Silt" ]

  if ((%sand > 20 and %sand <= 45) and (%silt > 15 and %silt <= 52.5) and (%clay > 27.5 and %clay <= 40)) [ report "Clay loam" ]

  if ((%sand > 22.5 and %sand <= 52.5) and (%silt > 27.5 and %silt <= 50) and (%clay > 7 and %clay <= 27.5)) [ report "Loam" ]

  report ""

end

to setup-soil-coverAndTreatment

  set p_soil_coverTreatmentAndHydrologicCondition get-coverTreatmentAndHydrologicCondition 1

end

to setup-soil-soilWaterProperties

  set p_soil_runOffCurveNumber get-runOffCurveNumber p_soil_coverTreatmentAndHydrologicCondition p_soil_hydrologicSoilGroup

  set p_soil_fieldCapacity get-fieldCapacity p_soil_textureType

  set p_soil_WaterHoldingCapacity get-waterHoldingCapacity p_soil_textureType

  set p_soil_wiltingPoint get-wiltingPoint

  set p_soil_deepDrainageCoefficient get-deepDrainageCoefficient p_soil_textureType

end

to-report get-coverTreatmentAndHydrologicCondition [ index ]

  report item index (item 0 soil_runOffCurveNumberTable)

end

to-report get-runOffCurveNumber [ coverTreatmentAndHydrologicCondition hydrologicSoilGroup ]

  report (
    item
    (position coverTreatmentAndHydrologicCondition (item 0 soil_runOffCurveNumberTable))            ; selecting row
    (item (1 + position hydrologicSoilGroup (list "A" "B" "C" "D")) soil_runOffCurveNumberTable)    ; selecting column (skip column with coverTreatmentAndHydrologicCondition)
    )

end

to-report get-waterHoldingCapacity [ textureType ]

  let minWHC (item (position textureType soil_textureTypes) soil_minWaterHoldingCapacity)
  let maxWHC (item (position textureType soil_textureTypes) soil_maxWaterHoldingCapacity)

  report (minWHC + random-float (maxWHC - minWHC)) * 2.54 / 30.48 ; converted from in/ft to cm/cm

end

to-report get-fieldCapacity [ textureType ]

  report item (position textureType soil_textureTypes) soil_fieldCapacity

end

to-report get-wiltingPoint

  report (p_soil_fieldCapacity - p_soil_WaterHoldingCapacity)

end

to-report get-deepDrainageCoefficient [ textureType ]

  ; get intake rate (mm/hour) of the given texture type
  let intakeRate item (position textureType soil_textureTypes) soil_intakeRate

  ; return daily intake rate as approximation of deep drainage coefficient
  report 24 * intakeRate

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; DISPLAY ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to paint-patches

  let min%sand min [p_soil_%sand] of patches
  let max%sand max [p_soil_%sand] of patches
  let min%silt min [p_soil_%silt] of patches
  let max%silt max [p_soil_%silt] of patches
  let min%clay min [p_soil_%clay] of patches
  let max%clay max [p_soil_%clay] of patches

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
    if (display-mode = "soil texture")
    [
      ;;; red: sand, green: silt, blue: clay
      set pcolor rgb
        (240 * ((p_soil_%sand - min%sand) / (max%sand - min%sand)))
        (240 * ((p_soil_%silt - min%silt) / (max%silt - min%silt)))
        (240 * ((p_soil_%clay - min%clay) / (max%clay - min%clay)))
      ;;; with range fixed at 0-100
;      set pcolor rgb
;        (240 * (p_soil_%sand / 100))
;        (240 * (p_soil_%silt / 100))
;        (240 * (p_soil_%clay / 100))

    ]
    if (display-mode = "soil texture group")
    [
      ;;; this order corresponds to an approximation to the soil texture palette (red: sand, green: silt, blue: clay)
      let soilTextureGroups (list
        "Sand"             "Loamy sand"        "Sandy loam"     ; red         orange  brown
        "Loam"             "Silt loam"         "Silt"           ; yellow      green   lime
        "Silty clay loam"  "Silty clay"        "Clay"           ; turquoise   cyan    sky
        "Clay loam"        "Sandy clay"        "Sandy clay loam"; blue        violet  magenta
      )

      set pcolor 15 + 10 * (position (
        get-soil-texture-type (p_soil_%sand) (p_soil_%silt) (p_soil_%clay)
        ) soilTextureGroups)
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
      let flowAccumulationHere flowAccumulation

      ask one-of flowHolders-here
      [
        ifelse (nextPatchInFlow != nobody)
        [
          if (link-with one-of [flowHolders-here] of nextPatchInFlow = nobody)
          [ create-link-with one-of [flowHolders-here] of nextPatchInFlow ]

          ask link-with one-of [flowHolders-here] of nextPatchInFlow
          [
            set hidden? false
            let multiplier 1E100 ^ (1 - flowAccumulationHere / (max [flowAccumulation] of patches)) / 1E100
            set color 92 + (5 * multiplier)
            set thickness 0.4 * ( 1 - ((color - 92) / 5))
          ]
        ]
        [
          set hidden? false
          let multiplier 1E100 ^ (1 - flowAccumulationHere / (max [flowAccumulation] of patches)) / 1E100
          set color 92 + (5 * multiplier)
          if (color <= 97) [ set shape "line half" ]
          if (color < 95) [ set shape "line half 1" ]
          if (color < 93) [ set shape "line half 2" ]
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

to-report get-soilVariable-per-flowAccumulation [ soilVariableName ]

  let stepInSequence 1;maxFlowAccumulation / 100
  let lengthOfSequence maxFlowAccumulation
  let sequence (list)

  if (soilVariableName = "Depth")
  [
    foreach (n-values lengthOfSequence [ j -> j + stepInSequence ])
    [
      i ->
      set sequence lput (get-soil-depth i) sequence
    ]
  ]
  if (soilVariableName = "Sand")
  [
    foreach (n-values lengthOfSequence [ j -> j + stepInSequence ])
    [
      i ->
      set sequence lput (get-soil-%sand i) sequence
    ]
  ]
  if (soilVariableName = "Silt")
  [
    foreach (n-values lengthOfSequence [ j -> j + stepInSequence ])
    [
      i ->
      set sequence lput (get-soil-%silt i) sequence
    ]
  ]
  if (soilVariableName = "Clay")
  [
    foreach (n-values lengthOfSequence [ j -> j + stepInSequence ])
    [
      i ->
      set sequence lput (get-soil-%clay i) sequence
    ]
  ]

  report sequence

end

to plot-table [ values ]

  let j 0
  foreach values
  [
    i ->
    plotxy j i
    set j j + 1
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

          if (item globalIndex globalNames = "numcontinents") [ set numContinents item globalIndex globalValues ]
          if (item globalIndex globalNames = "numoceans") [ set numOceans item globalIndex globalValues ]

          if (item globalIndex globalNames = "numranges") [ set numRanges item globalIndex globalValues ]
          if (item globalIndex globalNames = "rangelength") [ set rangeLength item globalIndex globalValues ]
          if (item globalIndex globalNames = "rangeelevation") [ set rangeElevation item globalIndex globalValues ]
          if (item globalIndex globalNames = "rangeaggregation") [ set rangeAggregation item globalIndex globalValues ]

          if (item globalIndex globalNames = "numrifts") [ set numRifts item globalIndex globalValues ]
          if (item globalIndex globalNames = "riftlength") [ set riftLength item globalIndex globalValues ]
          if (item globalIndex globalNames = "riftelevation") [ set riftElevation item globalIndex globalValues ]
          if (item globalIndex globalNames = "riftaggregation") [ set riftAggregation item globalIndex globalValues ]

          if (item globalIndex globalNames = "featureanglerange") [ set featureAngleRange item globalIndex globalValues ]
          if (item globalIndex globalNames = "continentality") [ set continentality item globalIndex globalValues ]
          if (item globalIndex globalNames = "elevationnoise") [ set elevationNoise item globalIndex globalValues ]
          if (item globalIndex globalNames = "sealevel") [ set seaLevel item globalIndex globalValues ]
          if (item globalIndex globalNames = "elevationsmoothstep") [ set elevationSmoothStep item globalIndex globalValues ]
          if (item globalIndex globalNames = "smoothingneighborhood") [ set smoothingNeighborhood item globalIndex globalValues ]

          if (item globalIndex globalNames = "xslope") [ set xSlope item globalIndex globalValues ]
          if (item globalIndex globalNames = "yslope") [ set ySlope item globalIndex globalValues ]

          if (item globalIndex globalNames = "valleyaxisinclination") [ set valleyAxisInclination item globalIndex globalValues ]
          if (item globalIndex globalNames = "valleyslope") [ set valleySlope item globalIndex globalValues ]

          if (item globalIndex globalNames = "riverflowaccumulationatstart") [ set riverFlowAccumulationAtStart item globalIndex globalValues ]

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
            set flowaccumulationstate read-from-string item 8 thisLine
            set flowaccumulation item 9 thisLine
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

;;; IMPORT TABLES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to load-hydrologic-soil-groups-table

  ;;; this procedure loads the values of the hydrologic soil groups table
  ;;; the table contains:
  ;;;   1. two lines of headers with comments (metadata, to be ignored)
  ;;;   2. two lines with statements mapping the different types of data, if more than one
  ;;;   3. the header of the table with the names of variables
  ;;;   4. remaining rows containing row name and values

  let hydrologicSoilGroupTable csv:from-file "hydrologicSoilGroupTable.csv"

  ;;;==================================================================================================================
  ;;; mapping coordinates (row or columns) in lines 3 and 4 (= index 2 and 3) -----------------------------------------
  ;;; NOTE: always correct raw mapping coordinates (start at 1) into list indexes (start at 0)

  ;;; line 3 (= index 2), row indexes
  let textureTypesRowRange (list ((item 1 (item 2 hydrologicSoilGroupTable)) - 1) ((item 3 (item 2 hydrologicSoilGroupTable)) - 1))

  ;;; line 4 (= index 3), row indexes
  ;;; Types of soil according to % of sand, silt and clay (ternary diagram) established by USDA
  let textureTypeColumn (item 1 (item 3 hydrologicSoilGroupTable)) - 1

  ;;; USDA classification of soils according to water infiltration (A, B, C, and D; see reference in csv file)
  let HydrologycSoilGroupsColumn (item 3 (item 3 hydrologicSoilGroupTable)) - 1

  ;;;==================================================================================================================
  ;;; extract data---------------------------------------------------------------------------------------

  ;;; read variables (list of lists, matrix: texture types x hydrologic soil groups)
  let hydrologicSoilGroupsData sublist hydrologicSoilGroupTable (item 0 textureTypesRowRange) (item 1 textureTypesRowRange + 1)

  ;;; extract type of texture
  set soil_textureTypes map [row -> item textureTypeColumn row ] hydrologicSoilGroupsData

  ;;; extract hydrologic soil group
  set soil_hydrologicSoilGroups map [row -> item HydrologycSoilGroupsColumn row ] hydrologicSoilGroupsData

end

to load-runoff-curve-number-table

  ;;; this procedure loads the values of the run off curve number table
  ;;; the table contains:
  ;;;   1. two lines of headers with comments (metadata, to be ignored)
  ;;;   2. two lines with statements mapping the different types of data, if more than one
  ;;;   3. the header of the table with the names of variables
  ;;;   4. remaining rows containing row name and values

  let runOffCurveNumberTable csv:from-file "runOffCurveNumberTable.csv"

  ;;;==================================================================================================================
  ;;; mapping coordinates (row or columns) in lines 3 and 4 (= index 2 and 3) -----------------------------------------
  ;;; NOTE: always correct raw mapping coordinates (start at 1) into list indexes (start at 0)

  ;;; line 3 (= index 2), row indexes
  let typesOfCoverRowRange (list ((item 1 (item 2 runOffCurveNumberTable)) - 1) ((item 3 (item 2 runOffCurveNumberTable)) - 1))

  ;;; line 4 (= index 3), row indexes
  ;;; types of soil cover
  let coverTypeColumn (item 1 (item 3 runOffCurveNumberTable)) - 1

  ;;; types of soil treatment (if applies)
  let TreatmentColumn (item 3 (item 3 runOffCurveNumberTable)) - 1

  ;;; types of soil hydrologic condition (if applies)
  let HydrologicConditionColumn (item 5 (item 3 runOffCurveNumberTable)) - 1

  ;;; Columns holding data for the four Hydrologic soil groups: value 8 and 10 (=item 7 and 9)
  let HydrologycSoilGroupsColumns (list ((item 7 (item 3 runOffCurveNumberTable)) - 1) ((item 9 (item 3 runOffCurveNumberTable)) - 1) )

  ;;; line 5 (= index 4), row indexes
  ;;; extract names of Hydrologic Soil Groups
  ;set soil_namesOfHydrologicSoilGroups (sublist (item 4 runOffCurveNumberTable) (item 0 HydrologycSoilGroupsColumns) ((item 1 HydrologycSoilGroupsColumns) + 1))

  ;;;==================================================================================================================
  ;;; extract data---------------------------------------------------------------------------------------

  ;;; read variables (list of lists, matrix: cover types-treatment-condition x hydrologic soil groups)
  let runOffCurveNumberData sublist runOffCurveNumberTable (item 0 typesOfCoverRowRange) (item 1 typesOfCoverRowRange + 1) ; select only those rows corresponding to data on types of cover

  ;;; extract cover, treatment and hydrologic condition
  let coverTreatmentAndHydrologicCondition (
    map [row -> (word (item coverTypeColumn row) " | " (item TreatmentColumn row) " | " (item HydrologicConditionColumn row) ) ] runOffCurveNumberData
    )

  ;;; extract curve number table
  set soil_runOffCurveNumberTable extract-subtable runOffCurveNumberData (item 0 HydrologycSoilGroupsColumns) (item 1 HydrologycSoilGroupsColumns)

  ;;; combine with cover-treatment-hydrologic condition
  set soil_runOffCurveNumberTable fput coverTreatmentAndHydrologicCondition soil_runOffCurveNumberTable

end

to load-soil-water-table

  ;;; this procedure loads the values of the soil water table
  ;;; the table contains:
  ;;;   1. two lines of headers with comments (metadata, to be ignored)
  ;;;   2. two lines with statements mapping the different types of data, if more than one
  ;;;   3. the header of the table with the names of variables
  ;;;   4. remaining rows containing row name and values

  let soilWaterTable csv:from-file "soilWaterTable.csv"

  ;;;==================================================================================================================
  ;;; mapping coordinates (row or columns) in lines 3 and 4 (= index 2 and 3) -----------------------------------------
  ;;; NOTE: always correct raw mapping coordinates (start at 1) into list indexes (start at 0)

  ;;; line 3 (= index 2), row indexes
  let textureTypesRowRange (list ((item 1 (item 2 soilWaterTable)) - 1) ((item 3 (item 2 soilWaterTable)) - 1))

  ;;; line 4 (= index 3), row indexes
  ;;; Types of soil according to % of sand, silt and clay (ternary diagram) established by USDA
  let textureTypeColumn (item 1 (item 3 soilWaterTable)) - 1

  ;;; values of field capacity (%) per texture type
  let fieldCapacityColumn (item 3 (item 3 soilWaterTable)) - 1

  ;;; values of minimum and maximum water holding capacity (in/ft) per texture type
  let minWaterHoldingCapacityColumn (item 5 (item 3 soilWaterTable)) - 1
  let maxWaterHoldingCapacityColumn (item 7 (item 3 soilWaterTable)) - 1

  ;;; values of intake rate (mm/hour) per texture type
  let intakeRateColumn (item 9 (item 3 soilWaterTable)) - 1

  ;;;==================================================================================================================
  ;;; extract data---------------------------------------------------------------------------------------

  ;;; read variables (list of lists, matrix: texture types x soil water variables)
  let soilWaterData sublist soilWaterTable (item 0 textureTypesRowRange) (item 1 textureTypesRowRange + 1)

  ;;; types of texture must be exactly the same that is extracted from the Hydrologic Soil Group table

  ;;; extract field capacity
  set soil_fieldCapacity map [row -> item fieldCapacityColumn row ] soilWaterData

  ;;; extract water holding capacity
  set soil_minWaterHoldingCapacity map [row -> item minWaterHoldingCapacityColumn row ] soilWaterData
  set soil_maxWaterHoldingCapacity map [row -> item maxWaterHoldingCapacityColumn row ] soilWaterData

  ;;; extract intake rate
  set soil_intakeRate map [row -> item intakeRateColumn row ] soilWaterData

end

to-report extract-subtable [ table startColumnIndex endColumnIndex ]

  let subtable (list)
  let columnsCount ((endColumnIndex + 1) - startColumnIndex)
  foreach n-values columnsCount [ j -> j ]
  [
    i ->
    let columnIndex startColumnIndex + i
    set subtable lput (map [row -> item columnIndex row ] table) subtable
  ]
  report subtable

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; numeric generic functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report clamp01 [ value ]
  report min (list 1 (clampMin0 value))
end

to-report clampMin0 [ value ]
  report (max (list 0 value))
end

to-report clampMinMax [ value minValue maxValue ]
  report min (list maxValue (max (list minValue value)))
end

to-report get-value-in-sigmoid [ xValue shapeParameter ]

  report 1 - e ^ (-1 * shapeParameter * xValue)

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

MONITOR
574
412
675
457
NIL
landOceanRatio
4
1
11

SLIDER
448
166
643
199
par_seaLevel
par_seaLevel
round min (list minElevation par_riftElevation)
round max (list maxElevation par_rangeElevation)
0.0
1
1
m
HORIZONTAL

SLIDER
15
169
187
202
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
208
105
390
138
par_elevationSmoothStep
par_elevationSmoothStep
0
1
1.0
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
3.0
1
0
Number

INPUTBOX
251
426
352
486
par_continentality
5.0
1
0
Number

MONITOR
410
458
508
503
sdElevation
precision sdElevation 4
4
1
11

MONITOR
507
458
589
503
minElevation
precision minElevation 4
4
1
11

MONITOR
583
458
670
503
maxElevation
precision maxElevation 4
4
1
11

INPUTBOX
14
202
102
262
par_numRanges
1.0
1
0
Number

INPUTBOX
101
202
193
262
par_rangeLength
100.0
1
0
Number

INPUTBOX
14
262
101
322
par_numRifts
1.0
1
0
Number

INPUTBOX
101
262
193
322
par_riftLength
100.0
1
0
Number

SLIDER
15
103
187
136
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
442
204
650
237
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
136
187
169
par_rangeElevation
par_rangeElevation
0
500
15.0
1
1
m
HORIZONTAL

MONITOR
412
412
497
457
NIL
count patches
0
1
11

SLIDER
11
496
165
529
par_rangeAggregation
par_rangeAggregation
0
1
0.75
0.01
1
NIL
HORIZONTAL

SLIDER
166
496
320
529
par_riftAggregation
par_riftAggregation
0
1
0.9
.01
1
NIL
HORIZONTAL

INPUTBOX
15
427
122
487
par_numContinents
1.0
1
0
Number

INPUTBOX
122
427
214
487
par_numOceans
1.0
1
0
Number

SLIDER
208
138
389
171
par_smoothingNeighborhood
par_smoothingNeighborhood
0
.1
0.1
.01
1
NIL
HORIZONTAL

MONITOR
502
412
567
457
maxDist
precision maxDist 4
4
1
11

MONITOR
226
170
375
207
smoothing neighborhood size
(word (count patches with [ distance patch 0 0 < smoothingNeighborhood ] - 1) \" patches\")
0
1
9

PLOT
708
639
1205
759
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
19
357
185
402
algorithm-style
algorithm-style
"NetLogo" "C#"
1

TEXTBOX
41
416
191
434
used when algorithm-style = C#
9
0.0
1

TEXTBOX
228
415
394
440
used when algorithm-style = Netlogo
9
0.0
1

SLIDER
13
322
193
355
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
208
273
404
306
par_ySlope
par_ySlope
-0.1
0.1
0.025
0.001
1
NIL
HORIZONTAL

SWITCH
442
122
562
155
show-flows
show-flows
0
1
-1000

CHOOSER
423
67
570
112
display-mode
display-mode
"terrain" "soil texture" "soil texture group"
2

SLIDER
208
240
404
273
par_xSlope
par_xSlope
-0.1
0.1
0.01
0.001
1
NIL
HORIZONTAL

BUTTON
574
96
646
129
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

TEXTBOX
167
87
238
112
ELEVATION
11
0.0
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

SWITCH
487
261
604
294
do-fill-sinks
do-fill-sinks
0
1
-1000

SLIDER
208
308
403
341
par_valleyAxisInclination
par_valleyAxisInclination
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
208
341
403
374
par_valleySlope
par_valleySlope
-0.1
0.1
0.02
0.001
1
NIL
HORIZONTAL

INPUTBOX
454
311
634
371
par_riverFlowAccumulationAtStart
1000000.0
1
0
Number

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

SLIDER
16
739
239
772
par_soil_min%sand
par_soil_min%sand
0
par_soil_max%sand - 1
60.0
1.0
1
%
HORIZONTAL

SLIDER
16
771
239
804
par_soil_max%sand
par_soil_max%sand
par_soil_min%sand + 1
100.0
90.0
1.0
1
%
HORIZONTAL

SLIDER
15
802
239
835
par_soil_erosionRate_%sand
par_soil_erosionRate_%sand
0.0
0.1
0.04
0.001
1
NIL
HORIZONTAL

SLIDER
251
739
467
772
par_soil_min%silt
par_soil_min%silt
0
par_soil_max%silt - 1
40.0
1.0
1
%
HORIZONTAL

SLIDER
250
771
466
804
par_soil_max%silt
par_soil_max%silt
par_soil_min%silt + 1
100.0
70.0
1.0
1
%
HORIZONTAL

SLIDER
250
804
467
837
par_soil_erosionRate_%silt
par_soil_erosionRate_%silt
0.0
0.1
0.02
0.001
1
NIL
HORIZONTAL

SLIDER
474
740
693
773
par_soil_min%clay
par_soil_min%clay
0
par_soil_max%clay - 1
0.0
1.0
1
%
HORIZONTAL

SLIDER
474
772
694
805
par_soil_max%clay
par_soil_max%clay
par_soil_min%clay + 1
100.0
50.0
1.0
1
%
HORIZONTAL

SLIDER
474
805
695
838
par_soil_erosionRate_%clay
par_soil_erosionRate_%clay
0.0
0.1
0.01
0.001
1
NIL
HORIZONTAL

SLIDER
163
879
358
912
par_soil_textureNoise
par_soil_textureNoise
0.0
20.0
5.0
1.0
1
%
HORIZONTAL

TEXTBOX
326
721
409
739
SOIL TEXTURE
11
0.0
1

PLOT
704
763
1247
913
Erosion curves of soil formation
flow accumulation
% of soil
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"sand" 1.0 0 -2674135 true "" "plot-table get-soilVariable-per-flowAccumulation \"Sand\""
"silt" 1.0 0 -10899396 true "" "plot-table get-soilVariable-per-flowAccumulation \"Silt\""
"clay" 1.0 0 -13345367 true "" "plot-table get-soilVariable-per-flowAccumulation \"Clay\""

MONITOR
15
837
243
874
SAND parameters
(word \"MIN = \" (precision soil_min%sand 2) \", MAX = \" (precision soil_max%sand 2) \", erosion curve = \" (precision soil_erosionRate_%sand 2))
17
1
9

MONITOR
243
837
471
874
SILT parameters
(word \"MIN = \" (precision soil_min%silt 2) \", MAX = \" (precision soil_max%silt 2) \", erosion curve = \" (precision soil_erosionRate_%silt 2))
17
1
9

MONITOR
470
837
697
874
CLAY parameters
(word \"MIN = \" (precision soil_min%clay 2) \", MAX = \" (precision soil_max%clay 2) \", erosion curve = \" (precision soil_erosionRate_%clay 2))
17
1
9

MONITOR
363
874
534
919
soil_textureNoise
precision soil_textureNoise 4
17
1
11

TEXTBOX
168
564
318
582
SOIL DEPTH
11
0.0
1

SLIDER
13
584
191
617
par_soil_minDepth
par_soil_minDepth
0
par_soil_maxDepth - 1
300.0
1
1
mm
HORIZONTAL

SLIDER
13
617
191
650
par_soil_maxDepth
par_soil_maxDepth
par_soil_minDepth + 1
600
500.0
1
1
mm
HORIZONTAL

SLIDER
191
584
393
617
par_soil_erosionRate_depth
par_soil_erosionRate_depth
0
0.1
2.0
0.01
1
NIL
HORIZONTAL

SLIDER
191
617
393
650
par_soil_depthNoise
par_soil_depthNoise
0
100
0.04
1
1
mm
HORIZONTAL

MONITOR
63
658
347
695
depth parameters
(word \"MIN = \" (precision soil_minDepth 2) \", MAX = \" (precision soil_maxDepth 2) \", erosion curve = \" (precision soil_erosionRate_depth 2) \", depth noise = \" (precision soil_depthNoise 2))
17
1
9

PLOT
397
561
702
711
Erosion curve of soil formation (soil depth)
flow accumulation
mm
0.0
10.0
0.0
10.0
true
false
"set-plot-y-range (round soil_minDepth - 1) (round soil_maxDepth + 1)" "set-plot-y-range (round soil_minDepth - 1) (round soil_maxDepth + 1)"
PENS
"default" 1.0 0 -16777216 true "" "plot-table get-soilVariable-per-flowAccumulation \"Depth\""

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
