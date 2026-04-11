#!/usr/bin/tclsh

################################################################################
# This script is designed to load a saved template (.tgz archive) to overwrite
# files in the project directory where the script resides. If intelligently
# handles file versioning, preserves specific configuration settings, and
# maintains a log of all operations.

# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)

# Key Features
#     Intelligent File Overwrite: Skips replacement if target files are
#         identical or newer
#     Configuration Preservation: Maintains specific settings in 11ctrlsim.tcl
#     Template Management: Automatically organizes templates in 07tpl/ directory
#     Comprehensive Logging: Creates detailed .out log file with timestamps
#     Cross-Platform Support: Works on both Unix and Windows platforms
#     Auto Template Discovery: Searches multiple locations for template files

# Processing Flow
# 1. Start script
#     - ./13loadtpl.tcl xxx[.tgz]
# 2. Initialization
#     - Set working directory to script location
#     - Create log file with timestamp and user info
#     - Backup existing log file if exists
# 3. Template file resolution
#     - If no argument, search for *.tgz in current directory
#     - Search for xxx.tgz in `pwd` and 07tpl (depth-first directory traversal)
#     - Case-insensitive search for absolute paths
# 4. Template organization
#     - Move/copy to 07tpl/ (create if not exists) if not already there
#     - Update path references to 07tpl/ for subsequent operations
# 5. Extract template
#     - Extract to a temporary directory using tar -xzf
#     - List files in the archive for reference
#     - Determine root directory from the archive structure
# 6. Load key files
# Phase 1: Minimum load
#     - Always copy 10variables-brief.txt, backup if exists
#     - Update modification time to now
# Phase 2: Special handling for 11ctrlsim.tcl
#     - Check file timestamps to decide on copying
#     - If copying, preserve specific settings (ST|Hosts, ST|Paths, ST|Licns,
#         Email|Sufx, Email, IndexWise, SameDev, HideVar) in the target file
#     - Only copy if source is newer than target, otherwise skip
#     - Make executable on Unix if not already
# Phase 3: Optional load
#     - Depth-first directory traversal to copy all regular files
#     - Skip 10variables-brief.txt and 11ctrlsim.tcl
#     - Skip if target is same or newer, backup if copying
#     - Create necessary subdirectories for target files
# 7. Cleanup
#     - Remove temporary directory
#     - Log completion message
#     - Exit with status 0
################################################################################

# define mputs to output to multiple channels
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

# Search the project directory in case of no argument
if {![llength $argv]} {
    set argv [glob -nocomplain *.tgz]
    if {![llength $argv]} {
        if {$tcl_platform(platform) eq "unix"} {
            mputs $Ouf "\nArgument missing! Usage:\
                ./[file tail $FScript] xxx.tgz\n"
        } else {
            mputs $Ouf "\nArgument missing! Usage:\
                [file tail $FScript] xxx.tgz\n"
        }
        close $Ouf
        exit 1
    }
}

# Flatten the argument list and accept the first argument only
set argv [lindex [string map {\{ {} \} {}} $argv] 0]

# Append the extension .tgz if no extension
if {[file extension $argv] eq ""} {
    append argv .tgz
}
set Tab [string repeat " " 4]

# Check the existence of 'TplDir' and create it if not present
set TplDir 07tpl
if {![file isdirectory $TplDir]} {
    file mkdir $TplDir
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

# Locate the template file: For the absolute path, resolve the correct case
# for the path; For the relative path, search for it under TplDir, WD, ...
set Flg false
set FTpl [file tail $argv]
if {[file isfile $argv]} {
    set Flg true
} elseif {[file isfile $TplDir/$argv]} {
    set argv $TplDir/$argv
    set Flg true
} elseif {[file pathtype $argv] eq "absolute"} {
    set DirLst [file split [file dirname $argv]]
    set Path [lindex $DirLst 0]
    foreach Elm [lrange $DirLst 1 end] {
        set Str [lsearch -inline -regexp [glob -nocomplain -tails\
            -directory $Path -type d *] (?i)^$Elm$]
        if {$Str eq ""} break
        set Path [file join $Path $Str]
    }

    # if parent directories match, check file match
    if {[string equal -nocase $Path [file dirname $argv]]} {
        set Str [lsearch -inline -regexp [glob -nocomplain -tails\
            -directory $Path -type f *] (?i)^$FTpl$]
        if {$Str ne ""} {
            set argv [file join $Path $Str]
            set Flg true
        }
    }
} else {

    # Search for the template by visiting all files under the project directory
    # Ignore its relative path. Use the depth-first traversal technique with
    # the following order: TplDir, WD, ...
    set DirLst [glob -nocomplain -tails -directory "" -type d *]
    set Idx [lsearch -exact $DirLst $TplDir]
    set DirLst [concat [lrange $DirLst $Idx $Idx] {{}}\
        [lrange $DirLst 0 [incr Idx -1]] [lrange $DirLst [incr Idx 2] end]]
    while {[llength $DirLst]} {
        set Str [lsearch -inline -regexp [glob -nocomplain -tails\
            -directory [lindex $DirLst 0] -type f *] (?i)$FTpl$]
        if {$Str ne ""} {
            set argv [lindex $DirLst 0]/$Str
            set Flg true
            break
        }
        set DirLst [concat [glob -nocomplain -directory [lindex $DirLst 0]\
            -type d *] [lrange $DirLst 1 end]]
    }
}

if {$Flg} {

    # If absolute path: Change to the path relative to the project if possible
    if {[regexp ^$WD/ $argv]} {
        set argv [string range $argv [string length $WD/] end]
    }
    mputs $Ouf "Located the template file: '$argv'"

    # If the template is under WD, move it to 'TplDir' if not
    if {[lindex [file split $argv] 0] ne $TplDir
        && [file pathtype $argv] eq "relative"} {
            mputs $Ouf "${Tab}Move '$argv' to '$TplDir'!"
            set FTpl $TplDir/[file tail $argv]
            file copy -force $argv $FTpl
            file delete $argv
            set argv $FTpl
    }

    # If the template is elsewhere, copy it to 'TplDir'
    if {[file pathtype $argv] eq "absolute"} {
        mputs $Ouf "${Tab}Copy '$argv' to '$TplDir'!"
        set FTpl $TplDir/[file tail $argv]
        file copy -force $argv $FTpl
        set argv $FTpl
    }
} else {
    mputs $Ouf "\n'$argv' not found!\n"
    close $Ouf
    exit 1
}

# Extract the correct directory from the archive instead of the file name
# List the archive files and the first is the relative directory with '/'
set FLst [exec tar -tzf $argv]
set TmpDir [file dirname $argv]/[string range [lindex $FLst 0] 0 end-1]

# Unpack the archive file
mputs $Ouf "Extract it to a temp directory '$TmpDir'"
exec tar -xzf $argv -C [file dirname $argv]

mputs $Ouf "Loading key simulation files to '$WD'..."

# Minimum load: 10variables-brief.txt
set Cnt 0
set FStr 10variables-brief.txt
set FSrc $TmpDir/$FStr
mputs -n $Ouf [format "%s%04d $FSrc -> $FStr" $Tab [incr Cnt]]
if {[file isfile $FStr]} {
    file copy -force $FStr $FStr.backup
}
if {[catch {file copy -force $FSrc $FStr} ErrMsg]} {
    mputs $Ouf $ErrMsg
    close $Ouf
    error $ErrMsg
} else {
    mputs $Ouf ": Copied!"

    # Update the modification time to now so it is the latest
    file mtime $FStr [clock seconds]
}

# Special treatment for loading 11ctrlsim.tcl
set FStr 11ctrlsim.tcl
set FSrc $TmpDir/$FStr
mputs -n $Ouf [format "%s%04d $FSrc -> $FStr" $Tab [incr Cnt]]
if {[file isfile $FStr]} {
    if {[file mtime $FSrc] == [file mtime $FStr]} {
        mputs $Ouf ": Same, skipped!"
    } elseif {[file mtime $FSrc] < [file mtime $FStr]} {
        mputs $Ouf ": Target newer, skipped!"
    } else {
        file copy -force $FStr $FStr.backup
        foreach Elm [list $FSrc $FStr] FTmp {Src Tgt} {
            set Inf [open $Elm r]
            set $FTmp [read $Inf]
            close $Inf
        }

        # Preserve the following settings in the target 11ctrlsim.tcl
        # ST|Hosts ST|Paths ST|Licns Email|Sufx Email IndexWise SameDev HideVar
        foreach Elm {ST\\|Hosts ST\\|Paths ST\\|Licns Email\\|Sufx} {

            # Both REs work, yet the 2nd RE is more generetic than the 1st
            if {[regexp ($Elm\\s+\\\{\[\\w./@\\n\ -\]+\\\}) $Src -> Val]} {
                set SrcArr($Elm) $Val
            }
            if {[regexp ($Elm\\s+\\\{\[^\\\}\]+\\\}) $Tgt -> Val]} {
                set TgtArr($Elm) $Val
            }
            if {$TgtArr($Elm) ne $SrcArr($Elm)} {
                regsub $Elm\\s+\\\{\[^\\\}\]+\\\} $Src $TgtArr($Elm) Src
            }
        }
        foreach Elm {Email IndexWise SameDev HideVar FullSchenk} {
            regexp ($Elm\\s+\\S+) $Tgt -> Val
            regsub $Elm\\s+\\S+ $Src $Val Src
        }
        set FTmp [open $FStr w]
        puts -nonewline $FTmp $Src
        close $FTmp
        mputs $Ouf ": Copied!"
    }
} else {
    if {[catch {file copy $FSrc $FStr} ErrMsg]} {
        mputs $Ouf $ErrMsg
        close $Ouf
        error $ErrMsg
    } else {
        mputs $Ouf ": Copied!"
    }
}

# Make sure 11ctrlsim.tcl is executable
if {$tcl_platform(platform) eq "unix" && ![file executable $FStr]} {
    exec chmod u+x $FStr
}

# Optional load: Only copy the missing or newer regular files
set Len [string length $TmpDir]
incr Len

# Manually assign .mfj to the directory list
set DirLst [list $TmpDir $TmpDir/.mfj]
while {[llength $DirLst]} {
    foreach Elm [glob -nocomplain -tails -directory [lindex $DirLst 0]\
        -type f *] {

        # Skip 10variables-brief.txt, 11ctrlsim.tcl
        if {$Elm eq "10variables-brief.txt" || $Elm eq "11ctrlsim.tcl"} continue
        set FSrc [lindex $DirLst 0]/$Elm

        # remove the prefix "TmpDir/"
        set FTgt [string range $FSrc $Len end]
        mputs -n $Ouf [format "%s%04d %s -> %s" $Tab [incr Cnt] $FSrc $FTgt]
        if {[file isfile $FTgt]} {
            if {[file mtime $FSrc] == [file mtime $FTgt]} {
                mputs $Ouf ": Same, skipped!"
                continue
            } elseif {[file mtime $FSrc] < [file mtime $FTgt]} {
                mputs $Ouf ": Target newer, skipped!"
                continue
            } else {
                file copy -force $FTgt $FTgt.backup
            }
        }

        # Make subdirectories if necessary
        set Dir [file dirname $FTgt]
        if {$Dir ne "." && ![file isdirectory $Dir]} {
            file mkdir $Dir
        }

        if {[catch {file copy -force $FSrc $FTgt} ErrMsg]} {
            mputs $Ouf $ErrMsg
            close $Ouf
            error $ErrMsg
        } else {
            mputs $Ouf ": Copied!"
        }

    }
    set DirLst [concat [glob -nocomplain -directory [lindex $DirLst 0]\
        -type d *] [lrange $DirLst 1 end]]
}

mputs $Ouf "\nRemove the temp directory: '$TmpDir'"
file delete -force $TmpDir
mputs $Ouf "Done!\n"
close $Ouf
exit 0
