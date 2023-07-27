#!/usr/bin/tclsh

################################################################################
# This script is designed to save the current project settings. It first loads
# SimArr from 11ctrlsim.tcl and then saves relevant files to a subfolder in
# SimArr(TplDir)
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
################################################################################

# define mputs to output to multiple channels (stdout and file)
proc mputs args {
    if {[llength $args] == 0} {
        error "wrong # args: should be \"mputs ?-n? ?channelId? string\""
    } elseif {[llength $args] == 1} {
        if {$args eq "-n"} {
            error "wrong # args: should be \"mputs ?-n? ?channelId? string\""
        } else {
            puts $args
        }
    } else {
        if {[lindex $args 0] eq "-n"} {
            foreach Elm [concat stdout [lrange $args 1 end-1]] {
                puts -nonewline $Elm [lindex $args end]
            }
        } else {
            foreach Elm [concat stdout [lrange $args 0 end-1]] {
                puts $Elm [lindex $args end]
            }
        }
    }
}

# Ensure 'pwd' is the directory of the script
cd [file dirname [info script]]

# Define the output file
set FOut [file rootname [file tail [info script]]].out
if {[file isfile $FOut] && [file size $FOut]} {
    file copy -force $FOut $FOut.backup
}
set Ouf [open $FOut w]
mputs $Ouf "\n[clock format [clock seconds] -format "%Y-%b-%d %A %H:%M:%S"]\
    \t'$::env(USER)@$::env(HOSTNAME)'"
mputs $Ouf "Simulation project directory: '[pwd]'"

# Load 'SimArr' in 11ctrlsim.tcl
if {![file isfile 11ctrlsim.tcl]} {
    mputs $Ouf "'11ctrlsim.tcl' missing in directory '[file tail [pwd]]'!"
    close $Ouf
    error "'11ctrlsim.tcl' missing in directory '[file tail [pwd]]'!"
} else {
    set Inf [open 11ctrlsim.tcl r]
    set Str [read $Inf]
    close $Inf
    if {[regexp {array set SimArr \{(.+)\};\#} $Str -> Tmp]} {
        array set SimArr $Tmp
    } else {
        mputs $Ouf "'SimArr' not found in '11ctrlsim.tcl'!"
        close $Ouf
        error "'SimArr' not found in '11ctrlsim.tcl'!"
    }
}

# Get mfjModTime from SimArr(FVarEnv)
if {[file isfile $SimArr(FVarEnv)]} {
    source $SimArr(FVarEnv)
} else {
    mputs $Ouf "'$SimArr(FVarEnv)' missing in directory '[pwd]'!"
    close $Ouf
    error "'$SimArr(FVarEnv)' missing in directory '[pwd]'!"
}



# If SimArr(TplDir) found at index 0, skip it
set argv [file split [lindex [string map {\{ {} \} {}} $argv] 0]]
if {[string equal -nocase $SimArr(TplDir) [lindex $argv 0]]} {
    set argv [lrange $argv 1 end]
}
if {[llength $argv]} {
    lset argv end [lindex $argv end]_[clock format [clock seconds] -format\
        "%Y-%m-%d_%H-%M-%S"]
    if {[llength $argv] > 1} {

        # Directory names should be case-insensitive
        set Path $SimArr(TplDir)
        set Idx 0
        foreach Elm [lrange $argv 0 end-1] {
            set Flg false
            foreach Dir [glob -nocomplain -directory $Path -types d *] {
                if {[string equal -nocase [file tail $Dir] $Elm]} {
                    set Flg true
                    break
                }
            }
            if {$Flg} {
                lset argv $Idx [file tail $Dir]
                append Path /[file tail $Dir]
            } else {
                break
            }
            incr Idx
        }
    }

    # 'eval': concat elements, interpret the string and return result
    set SubDir [eval file join $argv]
} else {
    set SubDir [clock format [clock seconds] -format "%Y-%m-%d_%H-%M-%S"]
}
set TmpDir $SimArr(TplDir)/$SubDir
mputs $Ouf "Saving key files to a temp directory './$TmpDir'..."
file mkdir $TmpDir

# Create a list of files for saving
set FLst [list]
foreach Elm $mfjModTime {
    lappend FLst [lindex $Elm 0]
}
set FBrf [file rootname $SimArr(FVarRaw)]-brief.txt
set FLst [concat $FLst $SimArr(FVarRaw) $FBrf 11ctrlsim.tcl 11ctrlsim.mfj\
    $SimArr(FSave)  $SimArr(FLoad) README.md gtooldb.tcl\
    [glob -nocomplain -directory $::SimArr(OutDir) *.csv *.plx]\
    [glob -nocomplain -directory $::SimArr(PMIDir) {*.[cC]} *.so.*]\
    [glob -nocomplain *.out n*_OG1D.plx v*.plt pbs.*]]
foreach Elm [glob -nocomplain .mfj/*.tcl] {
    lappend FLst $Elm
}

set Cnt 0
set Tab [string repeat " " 4]
foreach Elm [lsort -unique $FLst] {
    mputs $Ouf [format "%s%04d %s -> %s" $Tab [incr Cnt] $Elm $Elm]
    set Dir [file dirname $Elm]
    if {$Dir ne "." && ![file isdirectory $TmpDir/$Dir]} {
        file mkdir $TmpDir/$Dir
    }
    if {[catch {file copy $Elm $TmpDir/$Elm} ErrMsg]} {
        mputs $Ouf $ErrMsg
        close $Ouf
        error $ErrMsg
    }
}

# Go to the upper directory and create a Tar/GZip archive
cd [file dirname $TmpDir]
set Dir [file tail $TmpDir]
mputs $Ouf "\nCreate a Tar/GZip archive './$TmpDir.tgz'"

# Delete files if "tar: file changed as we read it" error occurs
if {[catch {exec tar -czf $Dir.tgz $Dir} ErrMsg]} {
    mputs $Ouf $ErrMsg
    mputs $Ouf "Remove the temp directory: './$TmpDir'"
    exec rm -fr $Dir
    mputs $Ouf "\Remove the Tar/GZip archive: './$TmpDir.tgz'"
    exec rm -fr $Dir.tgz
    mputs $Ouf "\nSimulation not saved! Try again!\n"
    close $Ouf
    exit 1
} else {
    mputs $Ouf "Remove the temp directory: './$TmpDir'"
    exec rm -fr $Dir
    mputs $Ouf "Done!\n"
    close $Ouf
    exit 0
}
