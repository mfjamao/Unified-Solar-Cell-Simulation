#!/usr/bin/tclsh

# Load 'SimArr' in 11ctrlsim.tcl
if {![file isfile 11ctrlsim.tcl]} {
    error "'11ctrlsim.tcl' missing in directory '[file tail [pwd]]'!"
} else {
    set Inf [open 11ctrlsim.tcl r]
    set Str [read $Inf]
    close $Inf
    if {[regexp {array set SimArr \{(.+)\};\#} $Str -> Tmp]} {
        array set SimArr [regsub -all {\s+} $tmp " "]
    } else {
        error "'SimArr' not found in '11ctrlsim.tcl'!"
    }
}

# Load key files
foreach Elm [list $SimArr(FProc) $SimArr(FIntrpr) $SimArr(FST) $SimArr(FGrm)] {
    if {![file isfile $Elm]} {
        error "Key file '$Elm' missing in directory '[file tail [pwd]]'!"
    } else {
        source $Elm
    }
}
namespace import mfjProc::*

# Define and clear log files
set FScript [file rootname [info script]]
set mfjProc::arr(FOut) $FScript.out
set mfjProc::arr(FLog) $FScript.mfj
vputs -n -w ""

vputs "\n[clock format [clock seconds] -format "%Y-%b-%d %A %H:%M:%S"]\
    \t'$::env(USER)@$::env(HOSTNAME)'"
vputs -n "TCL: [info nameofexecutable], version: [info tclversion], >= 8.4? "
if {[info tclversion] >= 8.4} {
    vputs "Yes!"
} else {
    vputs -c "\nTCL version 8.4 or above is required!\n"
    exit 1
}

# Read gtree.dat and update ::SimArr(FVarEnv) and ::SimArr(FVarSim) if necessary
mfjST::swb2tcl

# Update ::SimArr(FVarFmt) and ::SimArr(FVarRaw) if necessary
mfjIntrpr::tcl2Raw

exit 0