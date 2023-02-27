#!/usr/bin/tclsh

################################################################################
# This script is designed to load a saved project from the subfolder 'TplDir' to
# overwrite the current project. If the target files are the same or newer,
# they are not updated. Regardless the modification time, 10variables-brief.txt
# will be updated. Special treatment is applied to 11ctrlsim.tcl so that
# settings of STHosts, STPaths, STLicns, STLib and ESuffix are still preserved
# in the target file.
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
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

if {![llength $argv]} {

    # Try the current directory
    set argv [glob -nocomplain *.tar.gz]
    if {![llength $argv]} {
        mputs $Ouf "\nArgument missing! Usage: [info script] xxx.tar.gz\n"
        close $Ouf
        exit 1
    }
}

# Only process one Tar/GZip file
set argv [lindex [string map {\{ {} \} {}} $argv] 0]
set Tab [string repeat " " 4]

# Check 'TplDir' and create it if not present
set TplDir 07tpl
if {![file isdirectory $TplDir]} {
    file mkdir $TplDir
}

# Locate the archive file and move it to 'TplDir' if not
set Flg false
if {[file isfile $argv]} {
    set Flg true
} elseif {[file isfile $TplDir/$argv]} {
    set argv $TplDir/$argv
    set Flg true
} else {

    # Search the file under 'TplDir'
    foreach Elm [exec find $TplDir -type f] {
        if {[string equal -nocase [file tail $Elm] [file tail $argv]]} {
            set argv $Elm
            set Flg true
            break
        }
    }

    # Search the file from the current project directory
    if {!$Flg} {
        foreach Elm [exec find -type f] {
            if {[string equal -nocase [file tail $Elm] [file tail $argv]]} {
                set argv $Elm
                set Flg true
                break
            }
        }
    }
}

if {$Flg} {
    mputs $Ouf "Located the Tar/GZip file: './$argv'"
    if {[lindex [file split $argv] 0] ne $TplDir} {
        mputs $Ouf "${Tab}Move '$argv' to './$TplDir'!"
        file copy -force $argv $TplDir/[file tail $argv]
        file delete $argv
        set argv $TplDir/[file tail $argv]
    }
} else {
    mputs $Ouf "\n'$argv' not found!\n"
    close $Ouf
    exit 1
}

# Unpack the archive file
set TmpDir [string range $argv 0 end-7]
mputs $Ouf "Extract it to a temp directory './$TmpDir'"
exec tar -xzf $argv -C [file dirname $argv]

mputs $Ouf "Loading key simulation files to '[pwd]'..."

# Minimum load: 10variables-brief.txt
set Cnt 0
set FStr 10variables-brief.txt
mputs -n $Ouf [format "%s%04d $FStr -> $FStr" $Tab [incr Cnt]]
if {[file isfile $FStr]} {
    file copy -force $FStr $FStr.backup
}
if {[catch {file copy -force $TmpDir/$FStr $FStr} ErrMsg]} {
    mputs $Ouf $ErrMsg
    close $Ouf
    error $ErrMsg
} else {
    mputs $Ouf ": Copied!"

    # Update the modification time to now so it is the latest
    file mtime $FStr [clock seconds]
}

# Special treatment for loading 11ctrlsim.tcl
# Preserve settings of STHosts, STPaths, STLicns, STLib and ESuffix in 'SimArr'
set FStr 11ctrlsim.tcl
mputs -n $Ouf [format "%s%04d $FStr -> $FStr" $Tab [incr Cnt]]
if {[file isfile $FStr]} {
    if {[file mtime $TmpDir/$FStr] == [file mtime $FStr]} {
        mputs $Ouf ": Same, skipped!"
    } elseif {[file mtime $TmpDir/$FStr] < [file mtime $FStr]} {
        mputs $Ouf ": Target newer, skipped!"
    } else {
        file copy -force $FStr $FStr.backup
        foreach Elm [list $TmpDir/$FStr $FStr] Tmp {Str Txt} {
            set Inf [open $Elm r]
            set $Tmp [read $Inf]
            close $Inf
        }
        foreach Elm {STHosts STPaths STLicns STLib ESuffix} {

            # Both REs work, yet the 2nd RE is more generetic than the 1st
            if {[regexp $Elm\\s+\\\{(\[\\w./@\\n\ -\]+)\\\} $Str -> Val]} {
                set TgtArr($Elm) $Val
            }
            if {[regexp $Elm\\s+\\\{(\[^\\\}\]+)\\\} $Txt -> Val]} {
                set ElmArr($Elm) $Val
            }

            # Preserve the settings in the target 11ctrlsim.tcl
            if {$TgtArr($Elm) ne $SrcArr($Elm)} {
                regsub $Elm\\s+\\\{\[^\\\}\]+\\\} $Txt\
                    "$Elm \{$TgtArr($Elm)\}" Txt
            }
        }
        set Tmp [open $FStr w]
        puts -nonewline $Tmp $Txt
        close $Tmp
        mputs $Ouf ": Copied!"
    }
} else {
    if {[catch {file copy $TmpDir/$FStr $FStr} ErrMsg]} {
        mputs $Ouf $ErrMsg
        close $Ouf
        error $ErrMsg
    } else {
        mputs $Ouf ": Copied!"
    }
}

# Make sure 11ctrlsim.tcl is executable
if {![file executable $FStr]} {
    exec chmod u+x $FStr
}

# Optional load: Only copy the missing or newer regular files
set Len [string length $TmpDir]
incr Len
foreach Src [exec find $TmpDir -type f] {

    # remove the prefix "TmpDir/"
    set Dst [string range $Src $Len end]

    # Skip 10variables-brief.txt, 11ctrlsim.tcl
    if {[file tail $Dst] eq "11ctrlsim.tcl"
        || [file tail $Dst] eq "10variables-brief.txt"} {
        continue
    }
    mputs -n $Ouf [format "%s%04d %s -> %s" $Tab [incr Cnt] $Dst $Dst]
    if {[file isfile $Dst]} {
        if {[file mtime $Src] == [file mtime $Dst]} {
            mputs $Ouf ": Same, skipped!"
            continue
        } elseif {[file mtime $Src] < [file mtime $Dst]} {
            mputs $Ouf ": Target newer, skipped!"
            continue
        } else {
            file copy -force $Dst $Dst.backup
        }
    }

    # Make subdirectories if necessary
    set Dir [file dirname $Dst]
    if {$Dir ne "." && ![file isdirectory $Dir]} {
        file mkdir $Dir
    }
    if {[catch {file copy -force $Src $Dst} ErrMsg]} {
        mputs $Ouf $ErrMsg
        close $Ouf
        error $ErrMsg
    } else {
        mputs $Ouf ": Copied!"
    }
}

mputs $Ouf "\nRemove the temp directory: './$TmpDir'"
cd [file dirname $TmpDir]
exec rm -fr [file tail $TmpDir]
mputs $Ouf "Done!\n"
close $Ouf
exit 0
