#!/usr/bin/tclsh

################################################################################
# This script is designed to randomly generate upright pyramids with a specified
# area from the origin (0, 0, 0). It first loads array 'SimArr' from
# 11ctrlsim.tcl and the size of the area can be adjusted by the 'Side' variable.
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
################################################################################

set FScript [info script]
if {$tcl_platform(platform) eq "unix" && ![file executable $FScript]} {
    exec chmod u+x $FScript
}

# Use 'file join'to resolve relative and absolute path of 'Dir'
set Dir [file dirname $FScript]
set Dir [file join [pwd] $Dir]

# Search for 11ctrlsim.tcl from upper directories
while {$Dir ne ""} {
    if {[file isfile $Dir/11ctrlsim.tcl]} {
        break
    } else {
        set Dir [file dirname $Dir]
    }
}

# Load 'SimArr' in 11ctrlsim.tcl
if {[file isfile $Dir/11ctrlsim.tcl]} {
    set inf [open $Dir/11ctrlsim.tcl r]
    set str [read $inf]
    close $inf
    if {[regexp {array set SimArr \{(.+)\};\#} $str -> tmp]} {
        array set SimArr [regsub -all {\s+} $tmp " "]
    } else {
        error "'SimArr' not found in '11ctrlsim.tcl'!"
    }
} else {
    error "'11ctrlsim.tcl' not found in '[file dirname $FScript]'!"
}

# Source general procedures to reduce lengthy embedded code
source $Dir/$SimArr(CodeDir)/$SimArr(FProc)
namespace import [file rootname $SimArr(FProc)]::*

set NPyr 700

# Square area side
set Side 2

# Base and slant angle
set LBase 0.5
set ASlant 54.74

set H [expr 0.5*$LBase*tan(asin(1)*$ASlant/90.)]
set Str "\{"
while {$NPyr > 0} {
    set X2 [expr $H*(1.-rand())]
    set Y [expr -$LBase+($Side+2*$LBase)*rand()]
    set Z [expr -$LBase+($Side+2*$LBase)*rand()]
    append Str "\{Gas P R p${H}_${Y}_${Z} p${X2}_${Y}_${Z} $ASlant\} "
    incr NPyr -1
}
append Str "\{Gas B K p0_0_0//${H}_${Side}_${Side}\} "
append Str "\{Silicon 180 $Side $Side\} "
append Str "\{Aluminum 1 $Side $Side\}\}"

set Brf $Dir/[file rootname $SimArr(FVarRaw)]-brief.txt
set Inf [open $Brf r]
set Buff [read $Inf]
close $Inf
regsub {RegGen.+FldAttr} $Buff\
    [wrapText "RegGen      $Str\n\nFldAttr"] Buff
set Ouf [open $Brf w]
puts $Ouf $Buff
close $Ouf
