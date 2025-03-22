#!/usr/bin/tclsh

################################################################################
# This script is designed to start/stop simulation. Once the script is executed,
# it checks whether a previous instance is still running. If so, wait till it
# ends. If a batch is running (locally or by a job scheduler), kill the job.
# If no batch job is running, carry out the following four steps:
#   1. Convert the raw variable file (case insensitive) to a formatted file
#   2. Convert the formatted file to simulator-compatible files
#   3. Start preprocessing to generate command files for the simulator
#   4. Run the batch job locally or submit it to a job scheduler
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com). Only Sentaurus is supported
# now. Other simulators will be supported in future.
#
# Other notes:
#   HideVar: Hide variables from Sentaurus Workbench unless they have multiple
#       levels.
#   OneChild: If adjacent variables have the same multiple levels, one parent
#       node has only one child node. Disable it to enable full permutation.
#   FullSchenk: Select whether to calculate BGN using full Schenk model or not,
#       which is still experimenting
#   TrapDLN: Default # of levels in Sentaurus is 13
#   Add or modify an element in ST|Hosts, ST|Paths, ST|Licns, and Email|Sufx to
#       suit your settings. Set Email to override Email|Sufx. For ST|Hosts, Only
#       the first letter of a host name matters
#   In Tcl, use braces to suppress string substitution so '\' is literally '\'
################################################################################
array set SimArr {
    Email "" Time "" Append false Inverse false
    0Raw2Fmt true 1Fmt2Sim true 2PreProc true 3Batch true
    FVarRaw 10variables.txt FVarFmt variables.txt
    FIntrpr mfjIntrpr.tcl FProc mfjProc.tcl FGrm mfjGrm.tcl FST mfjST.tcl
    FVarSim varSim.tcl FVarEnv varEnv.tcl FSave 12savetpl.tcl
    FLoad 13loadtpl.tcl FSTPP preproc.sh FSTBatch batch.sh
    FInfo siminfo FLock lock FSTStat .status FDOESum DOESummary.csv
    CodeDir .mfj MDBDir 01mdb OptDir 02opt ExpDir 03exp PMIDir 04code
    EtcDir 05etc OutDir 06out TplDir 07tpl
    SameDev SameDev HideVar HideVar OneChild OneChild DfltYMax 2.0 LatFac 0.8
    GasThx 0.1 TrapDLN 100 EdgeEx 10 IntfEx 0.001 FullSchenk !FullSchenk
    NThread 4 BitSize {64 80 128 256} Digits {5 5 6 10}
    RhsMin {1e-10 1e-12 1e-15 1e-25} Iter {10 12 15 20}
    ModTime "" RegInfo "" RegLvl 0 RegMat "" RegIdx "" RegX "" RegY ""
    RegZ "" MatDB "" ConLst "" ConLen 0 VarLen 0
    VarName {SimEnv RegGen FldAttr IntfAttr GopAttr DfltAttr ProcSeq ModPar
        VarVary GetFld PPAttr}
    BIDLst {{c\d} {(\w+/)?\w+/\w+(/[\deE.+-]+)?} {S\w*} {M\w*} {W\w*}}
    DIDLst {{M\w*} {N\w*} {O\w*}}
    OIDLst {{Spec\w*} {Mono\w*} {Inci\w*}}
    QIDLst {{Cal\w*} {Dep\w*} {Dif\w*} {Etc\w*} {Imp\w*} {Ini\w*} {Mas\w*}
        {Sel\w*} {Tra\w*} {Wri\w*}}
    Prefix "# ---"
    Email|Sufx {unsw.edu.au unsw.edu.au}
    ST|Hosts {katana tyrion}
    ST|Paths {/srv/scratch/z3505796/apps/sentaurus
        /share/scratch/z3505796/apps/sentaurus}
    ST|Licns {27020@license2e.restech.unsw.edu.au
        27105@licence.eng.unsw.edu.au}
    ST|Tools {sde sdevice svisual inspect sprocess}
    sde|Sufx _dvs.cmd sdevice|Sufx _des.cmd svisual|Sufx _vis.tcl
    inspect|Sufx _ins.cmd sprocess|Sufx _fps.cmd
    STDfltID {Tool_label = (\S+) Tool_name = (\S+)}
};# End of 'SimArr'

# The script is designed to work properly in the project directory
# Make the project directory as the working directory
set FScript [info script]
cd [file dirname $FScript]
set FScript [file tail $FScript]
set WD [pwd]

# Ensure it is executable under unix platform
if {$tcl_platform(platform) eq "unix" && ![file executable $FScript]} {
    exec chmod u+x $FScript
}

# Keep waiting in case the previous script is still running
set FLock $SimArr(CodeDir)/$SimArr(FLock)
if {[file isfile $FLock]} {
    set Inf [open $FLock r]
    gets $Inf PID
    close $Inf
    set Lock false
    if {$tcl_platform(platform) eq "unix"} {
        set Lst [split [exec ps -ef] \n]
    } else {
        set Lst [split [exec tasklist] \n]
    }
    foreach Elm $Lst {
        if {[lindex $Elm 1] == $PID} {
            set Lock true
            break
        }
    }

    # Wait until the file lock is removed
    if {$Lock} {
        while {[file isfile $FLock]} {
            after 100
        }
    } else {
        file delete $FLock
    }
}

# Create a file lock to prevent running another '11simctrl.tcl'
set Ouf [open $FLock w]
puts $Ouf [pid]
close $Ouf

# Load key files
foreach Elm [list $SimArr(FProc) $SimArr(FIntrpr) $SimArr(FST) $SimArr(FGrm)] {
    set Elm $SimArr(CodeDir)/$Elm
    if {![file isfile $Elm]} {
        error "Key file '$Elm' missing in directory '[file tail $WD]'!"
    } else {
        source $Elm
    }
}
namespace import [file rootname $SimArr(FProc)]::*

# Create directories if not present
foreach Elm [list $SimArr(MDBDir) $SimArr(OptDir) $SimArr(ExpDir)\
    $SimArr(PMIDir) $SimArr(EtcDir) $SimArr(OutDir) $SimArr(TplDir)] {
    if {![file isdirectory $Elm]} {
        file mkdir $Elm
    }
}

# Make SimArr(FSave) and SimArr(FLoad) executable
foreach Elm [list $SimArr(FSave) $SimArr(FLoad)] {
    if {[file isfile $Elm]} {
        if {$tcl_platform(platform) eq "unix" && ![file executable $Elm]} {
            exec chmod u+x $Elm
        }
    } else {
        error "'$Elm' missing in directory '[file tail $WD]'!"
    }
}

# Define log files (mfjProc::arr(FOut) and mfjProc::arr(FLog))
set mfjProc::arr(FOut) [file rootname $FScript].out
set mfjProc::arr(FLog) [file rootname $FScript].mfj

# Process command-line arguments if any. Update variables MaxVerb in
# mfjProc::arr and FVarRaw in mfjIntrpr::arr and variables Raw2Fmt, TXT2Sim,
# PreProc and Batch in Steps. Usage is prompted for other arguments
    # -a        Set append mode instead of clearing output files
    # -f file   Read another variable file
    # -i        Inverse mode, SWB to variable file
    # -v #      Alter the default verbocity value
    # -r #      Run the # step in Steps
    # -t #      Run to the # step in Steps (Including the # step)
set argv [string map {\{ {} \} {}} $argv]
while {[llength $argv]} {
    switch -glob -- [lindex $argv 0] {
        -[aA] {
            set SimArr(Append) true
            set argv [lrange $argv 1 end]
        }
        -[fF] {
            set SimArr(FVarRaw) [lindex $argv 1]
            set argv [lrange $argv 2 end]
        }
        -[iI] {
            set SimArr(Inverse) true
            set argv [lrange $argv 1 end]
        }
        -[vV] {
            set mfjProc::arr(MaxVerb) [lindex $argv 1]
            set argv [lrange $argv 2 end]
        }
        -[rR] {
            set Tmp [lindex $argv 1]
            if {[regexp {^[0-3]$} $Tmp]} {
                for {set i 0} {$i < 4} {incr i} {
                    if {$i != $Tmp} {
                        set Key [lindex [array get SimArr ${i}*] 0]
                        set SimArr($Key) false
                    }
                }
            }
            set argv [lrange $argv 2 end]
        }
        -[tT] {
            set Tmp [lindex $argv 1]
            if {[regexp {^[0-3]$} $Tmp]} {
                for {set i 3} {$i > $Tmp} {incr i -1} {
                    set Key [lindex [array get SimArr ${i}*] 0]
                    set SimArr($Key) false
                }
            }
            set argv [lrange $argv 2 end]
        }
        default {
            if {$tcl_platform(platform) eq "unix"} {
                vputs -w "Usage: ./$FScript \[-a\] \[-f file\] \[-v #\]\
                    \[-r #\] \[-t #\]\n"
            } else {
                vputs -w "Usage: $FScript \[-a\] \[-f file\] \[-v #\]\
                    \[-r #\] \[-t #\]\n"
            }
            exit 1
        }
    }
}

# Clear log files by default
if {!$SimArr(Append)} {
    vputs -n -w ""
}
vputs "\n[clock format [clock seconds] -format "%Y-%b-%d %A %H:%M:%S"]\
    \t'$tcl_platform(user)@[exec hostname]' on '$tcl_platform(platform)' platform"
vputs -n "Tcl: [info nameofexecutable], version: [info tclversion], >= 8.4? "
if {[info tclversion] >= 8.4} {
    vputs -c "Yes!"
} else {
    vputs "Tcl version 8.4 or above is required!"
    exit 1
}

# Inverse mode, SWB to variable file
if {$SimArr(Inverse)} {

    # Read gtree.dat and update SimArr(FVarEnv) and SimArr(FVarSim) if necessary
    mfjST::swb2tcl

    # Update SimArr(FVarFmt) and SimArr(FVarRaw) if necessary
    mfjIntrpr::tcl2Raw
    exit 0
}

# Determine simulator and job scheduler. Default: Sentaurus Local
set FInfo $SimArr(CodeDir)/$SimArr(FInfo)
if {[file isfile $FInfo]} {
    set Inf [open $FInfo r]
    gets $Inf Line
    close $Inf
    set InfoLst [split $Line |]
} else {
    set InfoLst {Sentaurus Local}
}
vputs "Checking project '[file tail $WD]' status:"
vputs -i1 -n "Simulator: '[lindex $InfoLst 0]'; Status: "
set StatLst [list [clock seconds] [exec hostname] $tcl_platform(user) unknown\
    [pid]]
if {[lindex $InfoLst 0] eq "Sentaurus"} {
    if {[file isfile $SimArr(FSTStat)]} {
        set Inf [open $SimArr(FSTStat) r]
        gets $Inf Line
        close $Inf
        set StatLst [split $Line |]
    } else {
        set Ouf [open $SimArr(FSTStat) w]
        puts $Ouf [join $StatLst |]
        close $Ouf
    }
}
vputs -c '[lindex $StatLst 3]'\n

# After preprocessing, the status is set to 'ready'. The status will be updated
# to 'running' when the project is running. Yet, it typically requires some
# queue time before a scheduler completes arrangement of desired resources.
set Queue false
set BatOut ""
set FSTBatch $SimArr(CodeDir)/$SimArr(FSTBatch)
set FSTBatchOut [file rootname $FSTBatch].out
if {[file isfile $FSTBatchOut]} {
    set Inf [open $FSTBatchOut r]
    while {[gets $Inf Line] != -1} {
        set BatOut $Line
    }
    close $Inf
}
if {[lindex $InfoLst 0] eq "Sentaurus" && [lindex $StatLst 3] eq "ready"} {
    if {[lindex $InfoLst 1] eq "PBS" && [regexp {^\d+\.[^\d]+} $BatOut]} {
        set Queue true
    } elseif {[lindex $InfoLst 1] eq "SLURM" && [regexp {job \d+$} $BatOut]} {
        set Queue true
    }
}

# Stop the previous batch if it is running or queuing
if {$tcl_platform(platform) eq "unix"} {
    set FNull /dev/null
    set FSO /dev/stdout
} elseif {$tcl_platform(platform) eq "windows"} {
    set FNull Null
    set FSO CON
}
if {[lindex $InfoLst 0] eq "Sentaurus"
    && ([lindex $StatLst 3] eq "running" || $Queue)} {
    if {[lindex $InfoLst 1] eq "SLURM"} {
        vputs -i1 "Stop the previous batch managed by 'SLURM'...\n"
        if {[regexp {Submitted batch job (\d+)$} $BatOut -> BID]} {
            vputs -i2 "Cancelling SLURM batch: $BID\n"
            if {[catch {exec scancel $BID >$FNull 2>@1} Err]} {
                vputs -i2 "failed to stop '$BID': $Err\n"
            } else {
                vputs -i2 "Batch cancelled successfully!\n"
            }
        } else {
            vputs -i2 "SLURM batch ID not found! Forcibly update\
                $SimArr(FSTStat)\n"
        }
    } elseif {[lindex $InfoLst 1] eq "PBS"} {
        vputs -i1 "Stop the previous batch managed by 'PBS'...\n"
        if {[regexp {^(\d+)\.[^\d]+} $BatOut -> BID]} {
            vputs -i2 "Deleting PBS batch: $BID\n"
            if {[catch {exec qdel $BID >$FNull 2>@1} Err]} {
                vputs -i2 "failed to stop '$BID': $Err\n"
            } else {
                vputs -i2 "Batch deleted successfully!\n"
            }
        } else {
            vputs -i2 "PBS batch ID not found! Forcibly update\
                $SimArr(FSTStat)\n"
        }
    } else {
        vputs -i1 "Stop the previous batch at the current node...\n"
        set PID [lindex $StatLst 4]
        if {[string is integer -strict $PID]} {
            vputs -i2 "Killing PID: $PID\n"
            if {($tcl_platform(platform) eq "unix"
                && [catch {exec kill $PID >$FNull 2>@1} Err])
                || ($tcl_platform(platform) eq "windows"
                && [catch {exec taskkill /pid $PID >$FNull 2>@1} Err])} {
                vputs -i2 "Failed to kill '$PID': $Err\n"
            } else {
                vputs -i2 "PID killed successfully!\n"
            }
        } else {
            vputs -i2 "PID not found! Forcibly update $SimArr(FSTStat)\n"
        }
    }
    after 1000
    lset StatLst 3 aborted
    set Ouf [open $SimArr(FSTStat) w]
    puts $Ouf [join $StatLst |]
    close $Ouf
    close [open $FSTBatchOut w]
    vputs -i2 "Project status was changed to 'aborted'. Bye :)\n"

    # Remove the file lock
    file delete $FLock
    exit 0
}

# Convert the raw file to a formatted TXT file containing variable lists
if {$SimArr(0Raw2Fmt)} {
    set SimArr(Time) [clock seconds]
    vputs "Checking host settings and converting '$SimArr(FVarRaw)' to\
        '$SimArr(FVarFmt)'...\n"
    set mfjProc::arr(Indent2) 1
    mfjIntrpr::raw2Fmt

    # Update FInfo if necessary
    set Lst [list [lindex $mfjIntrpr::arr(FmtVal|SimEnv) 0]\
        [lindex $mfjIntrpr::arr(FmtVal|SimEnv) 4] [file mtime $SimArr(FVarRaw)]\
        [file mtime $FScript]]
    if {$InfoLst ne $Lst} {
        set InfoLst $Lst
        set Ouf [open $FInfo w]
        puts $Ouf [join $InfoLst |]
        close $Ouf
    }
    vputs "Processing time = [expr [clock seconds]-$::SimArr(Time)] s\n"
    set mfjProc::arr(Indent2) 0
}

# Pass variable lists to the selected simulator
if {$SimArr(1Fmt2Sim)} {
    set SimArr(Time) [clock seconds]
    set mfjProc::arr(Indent2) 1
    if {!$SimArr(0Raw2Fmt)} {
        vputs -i-1 "Checking host settings and reading '$SimArr(FVarFmt)'...\n"
        mfjIntrpr::readHost
        mfjIntrpr::readFmt
    }
    if {[lindex $InfoLst 0] eq "Sentaurus"} {
        vputs -i-1 "Preparing relevant files for 'Sentaurus TCAD'...\n"
        mfjST::fmt2swb
    }
    vputs "Processing time = [expr [clock seconds]-$SimArr(Time)] s\n"
    set mfjProc::arr(Indent2) 0
}

# Perform preprocess
if {$SimArr(2PreProc) && [lindex $InfoLst 0] eq "Sentaurus"} {
    vputs "Preprocessing with 'Sentaurus Workbench spp'...\n"
    set FSTPP $SimArr(CodeDir)/$SimArr(FSTPP)
    set FSTPPOut [file rootname $FSTPP].out
    close [open $FSTPPOut w]
    if {[catch {exec $FSTPP >$FSO | tee -a $FSTPPOut\
        $mfjProc::arr(FOut) $mfjProc::arr(FLog)} Err]} {
        vputs -c "\nfailed in preprocessing: $Err\n"
        exit 1
    }
}

# Run trials at the current node or summit them to a job scheduler
if {$SimArr(3Batch) && [lindex $InfoLst 0] eq "Sentaurus"} {
    vputs "Running single/multiple trials with 'Sentaurus Workbench gsub'...\n"
    close [open $FSTBatchOut w]
    if {[lindex $InfoLst 1] eq "SLURM"} {
        vputs -i1 "Hand over the simulation job to SLURM...\n"
        exec sbatch $FSTBatch >$FSO\
            | tee -a $FSTBatchOut $mfjProc::arr(FOut) $mfjProc::arr(FLog)
    } elseif {[lindex $InfoLst 1] eq "PBS"} {
        vputs -i1 "Hand over the simulation job to PBS...\n"
        exec qsub $FSTBatch >$FSO\
            | tee -a $FSTBatchOut $mfjProc::arr(FOut) $mfjProc::arr(FLog)
    } else {
        vputs -i1 "Run the simulation job at the current node...\n"
        exec $FSTBatch >$FSO\
            | tee -a $FSTBatchOut $mfjProc::arr(FOut) $mfjProc::arr(FLog) &
    }
}

# Remove the file lock
file delete $FLock
exit 0
