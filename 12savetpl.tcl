#!/usr/bin/tclsh

################################################################################
# This script is designed to save relevant simulation files from its project
# directory as a template archive (.tgz) to incubate new simulations later. It
# reads configuration in array 'SimArr' from 11ctrlsim.tcl and uses file lists
# defined in 'mfjModTime' to conprehensive and timestamped backups.

# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)

# Key Features
#     Configuration-Driven: Reads SimArr array from 11ctrlsim.tcl for project
#         settings
#     Timestamped Archives: Creates uniquely named archives with timestamps
#     Intelligent File Collection: Gathers files from multiple directories
#     Case-Insensitive Path Handling: Cross-platform path resolution
#     Duplicate Removal: Uses lsort -unique to avoid duplicate files
#     Error Recovery: Cleans up partial archives on tar failure

# Processing Flow
# 1. Start script and define mputs for multi-channel output
#     - ./12savetpl.tcl [optional path to save template]
# 2. Initialization
#     - Set working directory to script location
#     - Define output file and backup if it exists
# 3. Configuration loading
#     - Load SimArr from 11ctrlsim.tcl using regexp
#     - Source SimArr(FVarEnv) for mfjModTime
#     - Get file list from mfjModTime and error if not found
# 4. Template name resolution
#     - If no argument, use SimArr(TplDir) with timestamp
#     - Remove .tgz extension if present
#     - Normalize path by removing . and .. and resolving case-insensitive paths
#     - Create: [path]/[name]_[timestamp].tgz
# 5. Temporary directory creation
#     - Create temp directory for saving files
#     - Structure mirrors project directory
# 6. File collection and copying
# Source 1: mfjModTime files
#     - First elements from each list entry
# Source 2: Core project files
#     - 10variables[-brief].txt, 11ctrlsim.tcl, 11ctrlsim.mfj
#     - FSave, FLoad, README.md, gtooldb.tcl
# Source 3: Directory globs
#     - OutDir: *.csv, *.plx
#     - PMIDir: *.[cC], *.so.*
#     - ModDir: *.tcl, *.sh
# Source 4: Project root directory files
#     - *.out, n*_OG1D.plx, v*.plt, pbs.*
# Final processing
#     - Use lsort -unique to avoid duplicates
#     - Copy files to temp directory, creating subdirectories as needed
# 7. Archive creation
#     - Change to parent directory of temp directory
#     - Create Tar/GZip archive with tar -czf
#     - On success, delete temp directory
#     - On failure, delete partial archive and report error
# 8. Completion
#     - Output success message and exit
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

# The script is designed to work properly in the project directory
# Make the project directory as the working directory
set FScript [info script]
cd [file dirname $FScript]
set WD [pwd]

# Define the output file
set FOut [file rootname [file tail $FScript]].out
if {[file isfile $FOut] && [file size $FOut]} {
    file copy -force $FOut $FOut.backup
}
set Ouf [open $FOut w]
mputs $Ouf "\n[clock format [clock seconds] -format "%Y-%b-%d %A %H:%M:%S"]\
    \t'$tcl_platform(user)@[exec hostname]' on '$tcl_platform(platform)'\
    platform"
mputs $Ouf "Simulation project directory: '$WD'"

# Load array 'SimArr' from 11ctrlsim.tcl
if {[file isfile 11ctrlsim.tcl]} {
    set Inf [open 11ctrlsim.tcl r]
    set Buff [read $Inf]
    close $Inf
    if {[regexp {array\s+set\s+SimArr\s+\{(.+)\};\#} $Buff -> Tmp]} {
        array set SimArr $Tmp
    } else {
        mputs $Ouf "'SimArr' not found in '11ctrlsim.tcl'!"
        close $Ouf
        error "'SimArr' not found in '11ctrlsim.tcl'!"
    }
} else {
    mputs $Ouf "'11ctrlsim.tcl' missing in directory '[file tail $WD]'!"
    close $Ouf
    error "'11ctrlsim.tcl' missing in directory '[file tail $WD]'!"
}

# Get mfjModTime from SimArr(FVarEnv)
if {[file isfile $SimArr(FVarEnv)]} {
    source $SimArr(FVarEnv)
} else {
    mputs $Ouf "'$SimArr(FVarEnv)' missing in directory '$WD'!"
    close $Ouf
    error "'$SimArr(FVarEnv)' missing in directory '$WD'!"
}

# Flatten the argument list and accept the first argument only
set argv [lindex [string map {\{ {} \} {}} $argv] 0]
if {[llength $argv]} {

    # Remove extension .tgz if present
    if {[file extension $argv] eq ".tgz"} {
        set argv [string range 0 end-4]
    }

    # Remove . and .. from path
    set DirLst [file split $argv]
    if {[lindex $DirLst 0] eq ".."} {
        set Path [file dirname $WD]
        set DirLst [lrange $DirLst 1 end]
    } else {
        set Path ""
    }
    foreach Elm $DirLst {
        if {$Elm eq ".."} {
            set Path [file dirname $Path]
        } elseif {$Elm ne "."} {
            set Path [file join $Path $Elm]
        }
    }
    set argv $Path

    # Path should be case-insensitive
    if {[file pathtype $argv] eq "absolute"} {
        set DirLst [file split [file dirname $argv]]
        set Path [lindex $DirLst 0]
        foreach Elm [lrange $DirLst 1 end] {
            set Str [lsearch -inline -regexp [glob -nocomplain -tails\
                -directory $Path -type d *] (?i)^$Elm$]
            if {$Str eq ""} {
                set Path [file join $Path $Elm]
            } else {
                set Path [file join $Path $Str]
            }
        }

        # Change to the path relative to the project if possible
        if {[regexp ^$WD/ $Path]} {
            set Path [string range $Path [string length $WD/] end]
        }
    } else {

        # Path should be relative to SimArr(TplDir)
        set DirLst [file split $argv]

        # If SimArr(TplDir) found at index 0, remove redundancy
        if {[string equal -nocase $SimArr(TplDir) [lindex $DirLst 0]]} {
            set DirLst [lrange $DirLst 1 end]
            set argv [eval file join $DirLst]
        }
        set Path $SimArr(TplDir)
        foreach Elm [lrange $DirLst 0 end-1] {
            set Str [lsearch -inline -regexp [glob -nocomplain -tails\
                -directory $Path -type d *] (?i)^$Elm$]
            if {$Str eq ""} {
                set Path [file join $Path $Elm]
            } else {
                set Path [file join $Path $Str]
            }
        }
    }
    set TmpDir [file join $Path [file tail $argv]_[clock format\
        [clock seconds] -format "%Y%m%d%H%M%S"]]
} else {
    set TmpDir $SimArr(TplDir)/[clock format [clock seconds]\
        -format "%Y%m%d%H%M%S"]
}

mputs $Ouf "Saving key files to a temp directory '$TmpDir'..."
file mkdir $TmpDir

# Create a list of files for saving
set FLst [list]
foreach Elm $mfjModTime {
    lappend FLst [lindex $Elm 0]
}
set FBrf [file rootname $SimArr(FVarRaw)]-brief.txt
set FLst [concat $FLst $SimArr(FVarRaw) $FBrf 11ctrlsim.tcl 11ctrlsim.mfj\
    $SimArr(FSave) $SimArr(FLoad) README.md gtooldb.tcl\
    [glob -nocomplain -directory $::SimArr(OutDir) *.csv *.plx]\
    [glob -nocomplain -directory $::SimArr(PMIDir) {*.[cC]} *.so.*]\
    [glob -nocomplain -directory $::SimArr(ModDir) *.tcl *.sh]\
    [glob -nocomplain *.out n*_OG1D.plx v*.plt pbs.*]]

set Cnt 0
set Tab [string repeat " " 4]
foreach Elm [lsort -unique $FLst] {
    mputs $Ouf [format "%s%04d %s -> %s" $Tab [incr Cnt] $Elm $Elm]
    set Dir [file dirname $Elm]
    if {![file isdirectory $TmpDir/$Dir]} {
        file mkdir $TmpDir/$Dir
    }
    if {[catch {file copy $Elm $TmpDir/$Elm} ErrMsg]} {
        mputs $Ouf $ErrMsg
        close $Ouf
        error $ErrMsg
    }
}

# Go to the upper directory of TmpDir and create a Tar/GZip archive
cd [file dirname $TmpDir]
set Dir [file tail $TmpDir]
mputs $Ouf "\nCreate a Tar/GZip archive '$TmpDir.tgz'"

# Delete files if "tar: file changed as we read it" error occurs
if {[catch {exec tar -czf $Dir.tgz $Dir} ErrMsg]} {
    mputs $Ouf $ErrMsg
    mputs $Ouf "\Remove the Tar/GZip archive: '$TmpDir.tgz'"
    file delete $Dir.tgz
    mputs $Ouf "\nTar/GZip failed! Try Tar/GZip manually!\n"
    close $Ouf
    exit 1
} else {
    mputs $Ouf "Remove the temp directory: '$TmpDir'"
    file delete -force $Dir
    mputs $Ouf "Done!\n"
    close $Ouf
    exit 0
}
