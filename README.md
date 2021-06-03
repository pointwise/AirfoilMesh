# AirfoilMesh
Copyright 2021 Cadence Design Systems, Inc. All rights reserved worldwide.

A Glyph script for generating NACA 4-series airfoil geometries and boundary layer meshes.

![AirfoilMeshGUI](https://raw.github.com/pointwise/AirfoilMesh/master/ScriptImage.png)

## Generating or Importing Geometry
This script provides a way to generate NACA 4-Series airfoil geometries within Pointwise without relying on external coordinate files. Simply input the 4 digits defining a NACA 4-Series airfoil and click CREATE. However, the script does support the ability to import external airfoil coordinates from a segment file. The only requirement is that the airfoil should consist of three segments, the upper surface, lower surface, and trailing edge. In the current implementation, this script only handles airfoils with a finite trailing edge.

### NACA 4-Series Geometry Description
* The 1st digit is the maximum camber
* The 2nd digit is the maximum camber location 
* The 3rd and 4th digits represent the maximum thickness

### Notes
* All digits are a percentage of the chord length
* Maximum thickness occurs at 30% of the chord
* Chord length fixed to a unit length
* All airfoils have a flat trailing edge

### Example, NACA 2412
* Maximum camber is 2% of the chord
* Maximum camber located at 40% of the chord
* Maximum thickness is 12% of the chord (located at 30% of the chord)

## Boundary Layer Meshing
This script also automates the mesh generation process within Pointwise by asking the user to provide common boundary layer parameters. Assuming a unit length for the airfoil, the parameters are factors of the chord length. Once the boundary layer parameters have been selected, click MESH to generate a high quality structured O-grid topology using Pointwise's normal hyperbolic extrusion tool. Note that while the user has the ability to adjust common boundary layer parameters, more advanced parameters can be found within the attached Glyph script.  

### Boundary layer parameters
* Initial cell height in the boundary layer
* Cell growth/inflation rate
* The maximum boundary layer distance
* The number of points around the airfoil, excluding the trailing edge

## Disclaimer
This file is licensed under the Cadence Public License Version 1.0 (the "License"), a copy of which is found in the LICENSE file, and is distributed "AS IS." 
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE. 
Please see the License for the full text of applicable terms.
