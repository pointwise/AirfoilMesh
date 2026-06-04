#############################################################################
#
# (C) 2026 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################


# ===============================================
# AIRFOIL MESH GENERATOR v3.0
# ===============================================
# Enhanced version supporting multiple airfoil formats:
#   - NACA 4-Series (generated)
#   - Selig format (.dat or .txt files)
#   - Lednicer format (.dat or .txt files)
#   - IGES files (.igs, .iges)
#   - Segment files (.dat)
#   - DBA files (.dba)
#
# Original by Travis Carrigan
# Enhanced v2.0 -- multi-format support by Sam Salehian
#          v3.0 -- added IGES/Segment/DBA import, removed unicode characters
#

# Load Pointwise Glyph package and Tk
package require PWI_Glyph 2.4
pw::Script loadTk

# AIRFOIL GUI CREATION
# -----------------------------------------------
wm title . "Airfoil Mesh Generator"

set labelWidth 20
set entryWidth 10
set buttonWidth 10

# Make column 0 expand so all frames share the same width
grid columnconfigure . 0 -weight 1

# Create geometry information frame
grid [ttk::frame .geom -padding "5 5 5 5"] -column 0 -row 0 -sticky nwes
grid columnconfigure .geom 0 -weight 1

# Default NACA airfoil
set naca 0012
set imported 0
set importedFormat ""
set formatChoice "Auto Detect"
set teCutoff 99
set bluntTE 0
set fname "Browse for airfoil data file..."
set geomMode "naca"

# Procedure to enable/disable widgets based on geometry mode
proc updateGeomMode { } {
  if {$::geomMode eq "naca"} {
    .geom.lf.nacae configure -state normal
    .geom.lf.gob configure -state normal
    .geom.lf.geomb configure -state disabled
    .geom.lf.formate configure -state disabled
    .geom.lf.teblunt configure -state disabled
    .geom.lf.tee configure -state disabled
  } else {
    .geom.lf.nacae configure -state disabled
    .geom.lf.gob configure -state disabled
    .geom.lf.geomb configure -state normal
    .geom.lf.formate configure -state readonly
    .geom.lf.teblunt configure -state normal
    updateBluntTE
  }
}

proc updateBluntTE { } {
  if $::bluntTE {
    .geom.lf.tee configure -state normal
  } else {
    .geom.lf.tee configure -state disabled
  }
}

grid [labelframe .geom.lf -text "1. Generate or Import Geometry" -font {-slant italic} -padx 5 -pady 5] -sticky ew

# Radio buttons
grid [ttk::radiobutton .geom.lf.rnaca -text "NACA 4-Series" -variable geomMode -value "naca" \
  -command updateGeomMode] -column 0 -row 0 -sticky w
grid [ttk::radiobutton .geom.lf.rimport -text "Import Geometry" -variable geomMode -value "import" \
  -command updateGeomMode] -column 0 -row 1 -sticky w

# NACA widgets
grid [ttk::entry .geom.lf.nacae -width $entryWidth -textvariable naca] -column 1 -row 0 -sticky e
grid [ttk::button .geom.lf.gob -text "Create" -width $buttonWidth -command {
    cleanGeom
    airfoilGen
}] -column 2 -row 0 -sticky e

# Import widgets -- File Format and Make TE Blunt first, then Browse
grid [ttk::label .geom.lf.formatl -text "File Format" -width $labelWidth] -column 0 -row 2 -sticky w
grid [ttk::combobox .geom.lf.formate -width $entryWidth -textvariable formatChoice -state disabled \
  -values [list "Auto Detect" "Selig" "Lednicer" "IGES" "Segment"]] -column 1 -row 2 -sticky e
grid [ttk::checkbutton .geom.lf.teblunt -text "Close/Blunt TE" -variable bluntTE -state disabled \
  -command updateBluntTE] -column 0 -row 3 -sticky w
grid [ttk::label .geom.lf.tel -text "Chord %" -width $entryWidth] -column 1 -row 3 -sticky e
grid [ttk::entry .geom.lf.tee -width [expr $entryWidth/2] -textvariable teCutoff -state disabled] \
  -column 2 -row 3 -sticky e
grid configure [entry .geom.lf.browse -width [expr $labelWidth+$entryWidth+1] \
  -text fname -state disabled] -columnspan 2 -row 4 -sticky e
grid [ttk::button .geom.lf.geomb -text "Browse" -width $buttonWidth -state disabled -command {
  set types {
    {{Data Files}    {.dat} }
    {{Text Files}    {.txt} }
    {{IGES Files}    {.igs} }
    {{IGES Files}    {.iges}}
    {{DBA Files}     {.dba} }
    {{All Files}     *      }
  }
  set fname [tk_getOpenFile -title "Select Airfoil Data File" -filetypes $types]
  if {[file readable $fname]} {
    set entryWidthBrowse [expr $labelWidth+$entryWidth+1]
    set fileLength [string length $fname]
    set xv [expr $fileLength-$entryWidthBrowse]
    if {$xv<0} { set xv 0 }
    .geom.lf.browse xview $xv
    cleanGeom

    # Determine import method from format choice and file extension
    set ext [string tolower [file extension $fname]]
    set useDbImport 0
    set dbImportType ""

    if {$formatChoice eq "IGES"} {
      set useDbImport 1
      set dbImportType "IGES"
    } elseif {$formatChoice eq "Segment"} {
      set useDbImport 1
      set dbImportType "Segment"
    } elseif {$formatChoice eq "Selig" || $formatChoice eq "Lednicer"} {
      set useDbImport 0
    } else {
      # Auto Detect -- decide by extension
      if {$ext eq ".igs" || $ext eq ".iges"} {
        set useDbImport 1
        set dbImportType "IGES"
      } elseif {$ext eq ".dba"} {
        set useDbImport 1
        set dbImportType ""
      }
    }

    if {$useDbImport} {
      # Import via pw::Database import
      if {$dbImportType ne ""} {
        set importOk [expr {![catch {pw::Database import -type $dbImportType $fname} result]}]
      } else {
        set importOk [expr {![catch {pw::Database import $fname} result]}]
      }
      if {!$importOk} {
        puts "Error importing file: $result"
        set fname "Browse for airfoil data file..."
        set imported 0
        set importedFormat ""
      } else {
        set imported 1
        if {$dbImportType ne ""} {
          set importedFormat $dbImportType
        } else {
          set importedFormat [string toupper [string range $ext 1 end]]
        }
        puts "Successfully imported $importedFormat file"
        # Close trailing edge if requested
        if $::bluntTE {
          closeImportedTE
        }
        pw::Display resetView
      }
    } else {
      # Try Selig/Lednicer coordinate parser
      if {[catch {loadAirfoilFromFile $fname $formatChoice} result]} {
        # If Auto Detect failed, try Segment import as fallback
        if {$formatChoice eq "Auto Detect"} {
          if {[catch {pw::Database import -type Segment $fname} result2]} {
            puts "Error loading airfoil: $result"
            set fname "Browse for airfoil data file..."
            set imported 0
            set importedFormat ""
          } else {
            set imported 1
            set importedFormat "Segment"
            puts "Successfully imported Segment file"
            if $::bluntTE {
              closeImportedTE
            }
            pw::Display resetView
          }
        } else {
          puts "Error loading airfoil: $result"
          set fname "Browse for airfoil data file..."
          set imported 0
          set importedFormat ""
        }
      } else {
        set imported 1
        puts "Successfully loaded airfoil in $importedFormat format"
      }
    }
  } else {
    puts "Can't read airfoil data file."
    set fname "Browse for airfoil data file..."
    set imported 0
    set importedFormat ""
  }
}] -column 2 -row 4 -sticky e

# Default boundary layer parameters
set initds 0.0001
set cellgr 1.1
set bldist 0.5
set numpts 100

# Create mesh information frame
grid [ttk::frame .mesh -padding "5 5 5 5"] -column 0 -row 1 -sticky nwes
grid columnconfigure .mesh 0 -weight 1

grid [labelframe .mesh.lf2 -text "2. Mesh Parameters" -font {-slant italic} -padx 5 -pady 5] -sticky ew
grid [ttk::label .mesh.lf2.initdsl -text "Initial Cell Height" -width $labelWidth] -column 0 -row 0 -sticky w
grid [ttk::entry .mesh.lf2.initdse -width $entryWidth -textvariable initds] -column 1 -row 0 -sticky e
grid [ttk::label .mesh.lf2.cellgrl -text "Cell Growth Rate" -width $labelWidth] -column 0 -row 1 -sticky w
grid [ttk::entry .mesh.lf2.cellgre -width $entryWidth -textvariable cellgr] -column 1 -row 1 -sticky e
grid [ttk::label .mesh.lf2.numlayerl -text "Height" -width $labelWidth] -column 0 -row 2 -sticky w
grid [ttk::entry .mesh.lf2.numlayere -width $entryWidth -textvariable bldist] -column 1 -row 2 -sticky e
grid [ttk::label .mesh.lf2.cellarl -text "Points Around Airfoil" -width $labelWidth] -column 0 -row 3 -sticky w
grid [ttk::entry .mesh.lf2.cellare -width $entryWidth -textvariable numpts] -column 1 -row 3 -sticky e
grid [ttk::button .mesh.lf2.gob -text "Mesh" -width $buttonWidth -command {
  cleanGrid
  airfoilMesh
}] -column 2 -row 3 -sticky e 

# Close GUI
grid [ttk::frame .close -padding "5 0 5 5"] -column 0 -row 2 -sticky nwes
grid anchor .close e
grid [ttk::button .close.gob -text "Close" -width $buttonWidth -command exit] -column 0 -row 0 -sticky e

foreach w [winfo children .geom] {grid configure $w -padx 5 -pady 5}
foreach w [winfo children .geom.lf] {grid configure $w -padx 5 -pady 5}
foreach w [winfo children .mesh] {grid configure $w -padx 5 -pady 5}
foreach w [winfo children .mesh.lf2] {grid configure $w -padx 5 -pady 5}
foreach w [winfo children .close] {grid configure $w -padx 17 -pady 0}

focus .geom.lf.nacae
::tk::PlaceWindow . widget

# ===============================================
# FILE READING AND FORMAT DETECTION
# ===============================================

# Return parsed numeric pair from a line when present.
# Returns {} if line is not a 2-number data line.
# Handles forms like "0.123 0.456", "61 61", "61. 61." (trailing dot),
# and "-.0046700" (no leading zero before decimal point).
proc getNumericPairFromLine { line } {
  set re_num {([+-]?(?:[0-9]*\.?[0-9]+|[0-9]+\.)(?:[eE][+-]?[0-9]+)?)}
  set re_pair "^\\s*${re_num}\\s+${re_num}\\s*$"
  if {[regexp $re_pair $line match x y]} {
    return [list [expr {double($x)}] [expr {double($y)}]]
  }
  return {}
}

# Identify Lednicer-style count headers like "61 61" or "61. 61.".
proc isLikelyCountHeaderLine { line } {
  set pair [getNumericPairFromLine $line]
  if {[llength $pair] != 2} {
    return 0
  }

  set a [lindex $pair 0]
  set b [lindex $pair 1]

  # Count headers are typically integer-valued and larger than coordinate ranges.
  if {abs($a - round($a)) > 1.0e-9 || abs($b - round($b)) > 1.0e-9} {
    return 0
  }
  if {$a <= 2 || $b <= 2} {
    return 0
  }

  return 1
}

proc averageYValue { coords } {
  set sumY 0.0
  set n [llength $coords]
  if {$n == 0} {
    return 0.0
  }

  foreach pt $coords {
    set sumY [expr {$sumY + [lindex $pt 1]}]
  }

  return [expr {$sumY / double($n)}]
}

proc getTrailingEdgePoint { coords } {
  if {[llength $coords] == 0} {
    return {0 0}
  }

  set tePt [lindex $coords 0]
  set maxX [lindex $tePt 0]

  foreach pt $coords {
    set x [lindex $pt 0]
    if {$x > $maxX} {
      set maxX $x
      set tePt $pt
    }
  }

  return $tePt
}

# Truncate a surface coordinate list at a given X location.
# Points beyond cutoffX are removed; an interpolated point is inserted
# at the boundary crossing.
proc truncateSurfaceAtX { coords cutoffX } {
  set result {}
  set n [llength $coords]

  for {set i 0} {$i < $n} {incr i} {
    set pt [lindex $coords $i]
    set x [lindex $pt 0]
    set y [lindex $pt 1]
    set inside [expr {$x <= $cutoffX}]

    if {$i > 0} {
      set prevPt [lindex $coords [expr {$i - 1}]]
      set prevX [lindex $prevPt 0]
      set prevY [lindex $prevPt 1]
      set prevInside [expr {$prevX <= $cutoffX}]

      if {$inside != $prevInside} {
        set frac [expr {($cutoffX - $prevX) / ($x - $prevX)}]
        set interpY [expr {$prevY + $frac * ($y - $prevY)}]
        lappend result [list $cutoffX $interpY]
      }
    }

    if {$inside} {
      lappend result $pt
    }
  }

  return $result
}

proc splitSeligCoordinateSequence { coords } {
  set n [llength $coords]
  if {$n < 4} {
    error "Selig data needs at least 4 coordinate points"
  }

  set startX [lindex [lindex $coords 0] 0]
  set endX [lindex [lindex $coords end] 0]

  set minX $startX
  set maxX $startX
  set minIdx 0
  set maxIdx 0

  for {set i 1} {$i < $n} {incr i} {
    set x [lindex [lindex $coords $i] 0]
    if {$x < $minX} {
      set minX $x
      set minIdx $i
    }
    if {$x > $maxX} {
      set maxX $x
      set maxIdx $i
    }
  }

  set tol 1.0e-6
  set splitIdx -1

  if {abs($startX - $maxX) <= $tol && abs($endX - $maxX) <= $tol} {
    set splitIdx $minIdx
  } elseif {abs($startX - $minX) <= $tol && abs($endX - $minX) <= $tol} {
    set splitIdx $maxIdx
  } elseif {$minIdx > 0 && $minIdx < ($n - 1)} {
    set splitIdx $minIdx
  } elseif {$maxIdx > 0 && $maxIdx < ($n - 1)} {
    set splitIdx $maxIdx
  } else {
    error "Could not split Selig coordinate sequence into upper/lower surfaces"
  }

  set branch1 [lrange $coords 0 $splitIdx]
  set branch2 [lrange $coords $splitIdx end]

  if {[llength $branch1] < 2 || [llength $branch2] < 2} {
    error "Invalid Selig split: one surface has too few points"
  }

  set avg1 [averageYValue $branch1]
  set avg2 [averageYValue $branch2]
  if {$avg1 >= $avg2} {
    return [list $branch1 $branch2]
  }

  return [list $branch2 $branch1]
}

# Detect airfoil file format by analyzing the file content
proc detectAirfoilFormat { filename } {
  set fp [open $filename r]
  set lines {}

  # Read first 5 lines to analyze format
  for {set i 0} {$i < 5 && ![eof $fp]} {incr i} {
    lappend lines [gets $fp]
  }
  close $fp

  if {[llength $lines] < 2} {
    error "File is too short to determine format"
  }

  # Analyze first non-empty lines after title.
  set dataLines {}
  for {set i 1} {$i < [llength $lines]} {incr i} {
    set candidate [string trim [lindex $lines $i]]
    if {$candidate eq ""} {
      continue
    }
    lappend dataLines $candidate
  }

  if {[llength $dataLines] == 0} {
    error "No numeric data lines found"
  }

  set firstData [lindex $dataLines 0]
  if {[isLikelyCountHeaderLine $firstData]} {
    return "Lednicer"
  }

  if {[llength [getNumericPairFromLine $firstData]] == 2} {
    return "Selig"
  }

  error "Cannot determine airfoil file format"
}

# Parse Selig format airfoil file
# Returns: list of {upper_coords lower_coords}
proc parseSeligFile { filename } {
  set fp [open $filename r]
  set title [gets $fp]
  set coords {}

  while {![eof $fp]} {
    set line [gets $fp]
    if {[string trim $line] eq ""} continue

    # Skip Lednicer-style count header lines if they appear in mixed datasets.
    if {[isLikelyCountHeaderLine $line]} {
      continue
    }

    set pair [getNumericPairFromLine $line]
    if {[llength $pair] == 2} {
      lappend coords $pair
    }
  }
  close $fp

  return [splitSeligCoordinateSequence $coords]
}

# Parse Lednicer format airfoil file
# Returns: list of {upper_coords lower_coords}
proc parseLednicerFile { filename } {
  set fp [open $filename r]
  set title [gets $fp]

  # Find the first valid Lednicer point-count line after title.
  set countsLine ""
  while {![eof $fp]} {
    set candidate [string trim [gets $fp]]
    if {$candidate eq ""} {
      continue
    }
    if {[isLikelyCountHeaderLine $candidate]} {
      set countsLine $candidate
      break
    }
  }

  if {$countsLine eq ""} {
    close $fp
    error "Invalid Lednicer format: point-count header not found"
  }

  set countPair [getNumericPairFromLine $countsLine]
  set nUpper [expr {int(round([lindex $countPair 0]))}]
  set nLower [expr {int(round([lindex $countPair 1]))}]

  set upperCoords {}
  set lowerCoords {}

  # Read upper surface points
  for {set i 0} {$i < $nUpper} {incr i} {
    if {[eof $fp]} {
      break
    }
    set line [gets $fp]
    set pair [getNumericPairFromLine $line]
    if {[llength $pair] == 2} {
      lappend upperCoords $pair
    } else {
      incr i -1
    }
  }

  # Read lower surface points
  for {set i 0} {$i < $nLower} {incr i} {
    if {[eof $fp]} {
      break
    }
    set line [gets $fp]
    set pair [getNumericPairFromLine $line]
    if {[llength $pair] == 2} {
      lappend lowerCoords $pair
    } else {
      incr i -1
    }
  }

  close $fp

  return [list $upperCoords $lowerCoords]
}

# Load airfoil from file (format-agnostic)
proc loadAirfoilFromFile { filename { formatChoice "Auto Detect" } } {
  # Detect format unless user selected one explicitly.
  if {$formatChoice eq "Selig" || $formatChoice eq "Lednicer"} {
    set format $formatChoice
  } else {
    set format [detectAirfoilFormat $filename]
  }
  set ::importedFormat $format

  # Parse file based on detected format
  if {$format eq "Selig"} {
    set coordData [parseSeligFile $filename]
  } elseif {$format eq "Lednicer"} {
    set coordData [parseLednicerFile $filename]
  } else {
    error "Unknown format: $format"
  }

  set upperCoords [lindex $coordData 0]
  set lowerCoords [lindex $coordData 1]

  if {[llength $upperCoords] == 0 || [llength $lowerCoords] == 0} {
    error "No coordinate data found in file"
  }

  # Create airfoil geometry from coordinates
  airfoilFromCoordinates $upperCoords $lowerCoords
}

# Create airfoil geometry from coordinate lists
proc airfoilFromCoordinates { upperCoords lowerCoords } {
  # Detect sharp trailing edge and truncate to create thick TE
  set teUpper [getTrailingEdgePoint $upperCoords]
  set teLower [getTrailingEdgePoint $lowerCoords]
  set teDist [expr {hypot([lindex $teUpper 0] - [lindex $teLower 0], \
    [lindex $teUpper 1] - [lindex $teLower 1])}]

  if $::bluntTE {
    set teCutoff $::teCutoff
    # Find chord extents
    set allCoords [concat $upperCoords $lowerCoords]
    set minX [lindex [lindex $allCoords 0] 0]
    set maxX $minX
    foreach pt $allCoords {
      set px [lindex $pt 0]
      if {$px < $minX} {set minX $px}
      if {$px > $maxX} {set maxX $px}
    }
    set chord [expr {$maxX - $minX}]
    set cutoffX [expr {$minX + $chord * $teCutoff / 100.0}]

    set upperCoords [truncateSurfaceAtX $upperCoords $cutoffX]
    set lowerCoords [truncateSurfaceAtX $lowerCoords $cutoffX]
    puts [format "Sharp TE detected: truncated at %.1f%% chord to create thick TE" $teCutoff]
  }

  # Create upper airfoil surface
  set airUpper [pw::Application begin Create]
    set airUpperPts [pw::SegmentSpline create]

    foreach coord $upperCoords {
      set x [lindex $coord 0]
      set y [lindex $coord 1]
      $airUpperPts addPoint [list $x $y 0]
    }

    set airUpperCurve [pw::Curve create]
    $airUpperCurve addSegment $airUpperPts
  $airUpper end

  # Create lower airfoil surface
  set airLower [pw::Application begin Create]
    set airLowerPts [pw::SegmentSpline create]

    foreach coord $lowerCoords {
      set x [lindex $coord 0]
      set y [lindex $coord 1]
      $airLowerPts addPoint [list $x $y 0]
    }

    set airLowerCurve [pw::Curve create]
    $airLowerCurve addSegment $airLowerPts
  $airLower end

  # Create trailing edge connector
  set teUpper [getTrailingEdgePoint $upperCoords]
  set teLower [getTrailingEdgePoint $lowerCoords]
  set airTrail [pw::Application begin Create]
    set airTrailPts [pw::SegmentSpline create]
    $airTrailPts addPoint [list [lindex $teUpper 0] [lindex $teUpper 1] 0]
    $airTrailPts addPoint [list [lindex $teLower 0] [lindex $teLower 1] 0]
    set airTrailCurve [pw::Curve create]
    $airTrailCurve addSegment $airTrailPts
  $airTrail end

  # Zoom to airfoil
  pw::Display resetView
}

# Close trailing edge on imported CAD geometry (IGES/Segment/DBA)
# Finds the two TE endpoints (highest X) and creates a closing curve.
proc closeImportedTE { } {
  set dbEnts [pw::Database getAll]
  if {[llength $dbEnts] < 2} {
    puts "Need at least 2 database curves to close TE"
    return
  }

  # Collect all curve endpoints
  set allPts {}
  foreach db $dbEnts {
    lappend allPts [$db getXYZ -arc 0.0]
    lappend allPts [$db getXYZ -arc 1.0]
  }

  # Sort by X descending to find TE endpoints
  set allPts [lsort -real -decreasing -index 0 $allPts]

  # Find two highest-X points that are not coincident
  set tePt1 [lindex $allPts 0]
  set tePt2 ""

  for {set i 1} {$i < [llength $allPts]} {incr i} {
    set pt [lindex $allPts $i]
    set dist [expr {sqrt(([lindex $tePt1 0]-[lindex $pt 0])**2 + \
      ([lindex $tePt1 1]-[lindex $pt 1])**2 + \
      ([lindex $tePt1 2]-[lindex $pt 2])**2)}]
    if {$dist > 1.0e-10} {
      set tePt2 $pt
      break
    }
  }

  if {$tePt2 eq ""} {
    puts "TE is already closed"
    return
  }

  # Verify tePt2 is actually near the TE (within 5% chord of max X)
  set maxX [lindex $tePt1 0]
  set minX [lindex [lindex $allPts end] 0]
  set chord [expr {$maxX - $minX}]
  if {$chord > 0 && ($maxX - [lindex $tePt2 0]) > 0.05 * $chord} {
    puts "TE appears to be already closed"
    return
  }

  # Create TE closing curve
  set creator [pw::Application begin Create]
    set seg [pw::SegmentSpline create]
    $seg addPoint $tePt1
    $seg addPoint $tePt2
    set crv [pw::Curve create]
    $crv addSegment $seg
  $creator end

  set gap [expr {sqrt(([lindex $tePt1 0]-[lindex $tePt2 0])**2 + \
    ([lindex $tePt1 1]-[lindex $tePt2 1])**2 + \
    ([lindex $tePt1 2]-[lindex $tePt2 2])**2)}]
  puts [format "Trailing edge closed (gap = %.6f)" $gap]
}

# ===============================================
# AIRFOIL GENERATION PROCEDURE (NACA)
# ===============================================
proc airfoilGen { } {
  # AIRFOIL INPUTS
  # -----------------------------------------------
  # m = maximum camber 
  # p = maximum camber location 
  # t = maximum thickness
  set m [expr {[string index $::naca 0]/100.0}]  
  set p [expr {[string index $::naca 1]/10.0}] 
  set a [string index $::naca 2]
  set b [string index $::naca 3]
  set c "$a$b"
  scan $c %d c
  set t [expr {$c/100.0}]

  # GENERATE AIRFOIL COORDINATES
  # -----------------------------------------------
  # Initialize Arrays
  set x {}
  set xu {}
  set xl {}
  set yu {}
  set yl {}
  set yc {0}
  set yt {}

  # Airfoil step size
  set ds 0.001

  # Check if airfoil is symmetric or cambered
  if {$m == 0 && $p == 0 || $m == 0 || $p == 0} {set symm 1} else {set symm 0}

  # Get x coordinates
  for {set i 0} {$i < [expr {1+$ds}]} {set i [expr {$i+$ds}]} {lappend x $i}

  # Calculate mean camber line and thickness distribution
  foreach xx $x {

    # Mean camber line definition for symmetric geometry
    if {$symm == 1} {lappend yc 0}

    # Mean camber line definition for cambered geometry
    if {$symm == 0 && $xx <= $p} {
      lappend yc [expr {($m/($p**2))*(2*$p*$xx-$xx**2)}]
    } elseif {$symm == 0 && $xx > $p} {
      lappend yc [expr {($m/((1-$p)**2)*(1-2*$p+2*$p*$xx-$xx**2))}]
    }

    # Thickness distribution
    lappend yt [expr {($t/0.20)*(0.29690*sqrt($xx)-0.12600*$xx- \
      0.35160*$xx**2+0.28430*$xx**3-0.10150*$xx**4)}]

    # Theta
    set dy [expr {[lindex $yc end] - [lindex $yc end-1]}]
    set th [expr {atan($dy/$ds)}]

    # Upper x and y coordinates
    lappend xu [expr {$xx-[lindex $yt end]*sin($th)}]
    lappend yu [expr {[lindex $yc end]+[lindex $yt end]*cos($th)}]

    # Lower x and y coordinates
    lappend xl [expr {$xx+[lindex $yt end]*sin($th)}]
    lappend yl [expr {[lindex $yc end]-[lindex $yt end]*cos($th)}]

  }

  # GENERATE AIRFOIL GEOMETRY
  # -----------------------------------------------
  # Create upper airfoil surface
  set airUpper [pw::Application begin Create]
    set airUpperPts [pw::SegmentSpline create]

    for {set i 0} {$i < [llength $x]} {incr i} {
      $airUpperPts addPoint [list [lindex $xu $i] [lindex $yu $i] 0]
    }

    set airUpperCurve [pw::Curve create]
    $airUpperCurve addSegment $airUpperPts
  $airUpper end

  # Create lower airfoil surface
  set airLower [pw::Application begin Create]
    set airLowerPts [pw::SegmentSpline create]

    for {set i 0} {$i < [llength $x]} {incr i} {
      $airLowerPts addPoint [list [lindex $xl $i] [lindex $yl $i] 0]
    }

    set airLowerCurve [pw::Curve create]
    $airLowerCurve addSegment $airLowerPts
  $airLower end

  # Create flat trailing edge
  set airTrail [pw::Application begin Create]
    set airTrailPts [pw::SegmentSpline create]
    $airTrailPts addPoint [list [lindex $xu end] [lindex $yu end] 0]
    $airTrailPts addPoint [list [lindex $xl end] [lindex $yl end] 0]
    set airTrailCurve [pw::Curve create]
    $airTrailCurve addSegment $airTrailPts
  $airTrail end

  # Zoom to airfoil
  pw::Display resetView
}

# ===============================================
# BOUNDARY LAYER MESH GENERATION PROCEDURE
# ===============================================
proc airfoilMesh { } {
  # BOUNDARY LAYER INPUTS
  # -----------------------------------------------
  # initDs = initial cell height
  # cellGr = cell growth rate
  # blDist = boundary layer height
  # numPts = number of points around airfoil
  set initDs $::initds
  set cellGr $::cellgr
  set blDist $::bldist
  set numPts $::numpts

  if {$blDist <= 0} {
    error "Boundary Layer Height must be greater than zero"
  }

  # CONNECTOR CREATION, DIMENSIONING, AND SPACING
  # -----------------------------------------------
  # Get all database entities
  set dbEnts [pw::Database getAll]

  if { [llength $dbEnts] < 3 && ! $::bluntTE } {
    error "No trailing edge detected.\
      Enable 'Make TE Blunt' and re-import the airfoil before meshing."
  }

  # Get the curve length of all db curves
  foreach db $dbEnts {
    lappend crvLength [$db getLength 1.0]
  }

  # Find trailing edge from minimum curve length
  if {[lindex $crvLength 0] < [lindex $crvLength 1]} {
    set min 0
  } else {
    set min 1
  }

  if {[lindex $crvLength $min] < [lindex $crvLength 2]} {
    set min $min
  } else {
    set min 2
  }

  set dbTe [lindex $dbEnts $min]

  # Get upper and lower surfaces
  foreach db $dbEnts {
    if {$db != $dbTe} {
      lappend upperLower $db
    }
  }

  # Find y values at 50 percent length of upper and lower surfaces
  set y1 [lindex [[lindex $upperLower 0] getXYZ -arc 0.5] 1]
  set y2 [lindex [[lindex $upperLower 1] getXYZ -arc 0.5] 1]

  # Determine upper and lower surface db entities
  if {$y1 < $y2} {
    set dbLower [lindex $upperLower 0]
    set dbUpper [lindex $upperLower 1]
  } else {
    set dbLower [lindex $upperLower 1]
    set dbUpper [lindex $upperLower 0]
  }

  # Create connectors on database entities
  set upperSurfCon [pw::Connector createOnDatabase $dbUpper]
  set lowerSurfCon [pw::Connector createOnDatabase $dbLower]
  set trailSurfCon [pw::Connector createOnDatabase $dbTe]
  set cons [list $upperSurfCon $lowerSurfCon $trailSurfCon]

  # Calculate main airfoil connector dimensions
  set conDim [expr int($numPts/2)]

  # Dimension upper and lower airfoil surface connectors
  $upperSurfCon setDimension $conDim
  $lowerSurfCon setDimension $conDim

  # Set leading and trailing edge connector spacings
  set ltDs [expr 10*$initDs]

  set upperSurfConDis [$upperSurfCon getDistribution 1]
  set lowerSurfConDis [$lowerSurfCon getDistribution 1]

  $upperSurfConDis setBeginSpacing $ltDs
  $upperSurfConDis setEndSpacing $ltDs
  $lowerSurfConDis setBeginSpacing $ltDs
  $lowerSurfConDis setEndSpacing $ltDs

  set trailSurfConLen [$trailSurfCon getLength -arc 1]
  set teDim [expr int($trailSurfConLen/(10*$initDs))+2]
  $trailSurfCon setDimension $teDim

  # Check for degenerate trailing edge (sharp/closed TE creates a pole)
  set teLen [$trailSurfCon getLength -arc 1]
  if {$teLen < 1.0e-10} {
    # Clean up the connectors we just created
    pw::Entity delete -force $cons
    error "Trailing edge has zero length (sharp TE creates a pole).\
      Enable 'Make TE Blunt' and re-import the airfoil before meshing."
  }

  # Create edges for structured boundary layer extrusion
  set afEdge [pw::Edge createFromConnectors -single $cons]
  set afDom [pw::DomainStructured create]
  $afDom addEdge $afEdge

  # Extrude boundary layer using normal hyperbolic extrusion method
  set afExtrude [pw::Application begin ExtrusionSolver $afDom]
    $afDom setExtrusionSolverAttribute NormalInitialStepSize $initDs
    $afDom setExtrusionSolverAttribute SpacingGrowthFactor $cellGr
    $afDom setExtrusionSolverAttribute NormalMarchingVector {0 0 -1}
    $afDom setExtrusionSolverAttribute NormalKinseyBarthSmoothing 3
    $afDom setExtrusionSolverAttribute NormalVolumeSmoothing 0.3
    $afDom setExtrusionSolverAttribute StopAtHeight $blDist
    $afExtrude run 1000
  $afExtrude end

  # Reset view
  pw::Display resetView
}

# ===============================================
# UTILITY PROCEDURES
# ===============================================

# PROCEDURE TO DELETE ANY EXISTING GRID ENTITIES
proc cleanGrid { } {
  set grids [pw::Grid getAll -type pw::Connector]

  if [llength $grids] {
    foreach grid $grids {$grid delete -force}
  }
}

# PROCEDURE TO DELETE ANY EXISTING GEOMETRY
proc cleanGeom { } {
  cleanGrid    

  set dbs [pw::Database getAll]
    
  if {[llength $dbs]>0} {
    foreach db $dbs {$db delete -force}
  }
}

# END SCRIPT

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
