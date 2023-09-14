#!/usr/bin/tclsh

################################################################################
# This script is designed to start/stop simulation. When the script is running,
# it checks whether a previous instance is still running. If it is, wait till
# it ends. If the job is running (locally or by a job scheduler), stop it. If
# no job is running, carry out the following four steps:
#   1. Convert the raw variable file (case insensitive) to a formatted file
#   2. Convert the formatted file to simulator specific files
#   3. Start preprocessing for the simulator
#   4. Submit the job locally or to a job scheduler
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com). Only Sentaurus is supported
# now. Other simulators will be supported in future.
#
# Other notes:
#   Node4All: Node arrangement for all variables even if not multiple levels
#   ColMode: If adjacent variables have the same multiple levels, one parent
#       node has only one child node
#   FullSchenk: Select whether to calculate BGN using full Schenk model or not
#   TrapDLN: Default # of levels in Sentaurus is 13
#   Use braces to suppress string substitution so '\' is literally '\'
################################################################################
array set SimArr {
    Time "" Append false Inverse false
    0Raw2Fmt true 1Fmt2Sim true 2PreProc true 3Batch true
    FVarRaw 10variables.txt FVarFmt .mfj/variables.txt
    FIntrpr .mfj/mfjIntrpr.tcl FProc .mfj/mfjProc.tcl FGrm .mfj/mfjGrm.tcl
    FVarSim .mfj/varSim.tcl FVarEnv .mfj/varEnv.tcl FSave 12savetpl.tcl
    FLoad 13loadtpl.tcl FSTPP .mfj/preproc.sh FSTBatch .mfj/batch.sh
    FPPOut .mfj/preproc.out FBatOut .mfj/batch.out FInfo .mfj/.siminfo
    FLock .mfj/lock FDOESum DOESummary.csv
    MDBDir 01mdb OptDir 02opt ExpDir 03exp PMIDir 04code EtcDir 05etc
    OutDir 06out TplDir 07tpl
    DfltYMax 2.0 LatFac 0.8 GasThx 0.1 Node4All !Node4All ColMode ColMode
    FullSchenk !FullSchenk TrapDLN 100  EdgeEx 10 IntfEx 0.001
    NThread 4 BitSize {64 80 128 256} Digits {5 5 6 10}
    RhsMin {1e-10 1e-12 1e-15 1e-25} Iter {10 12 15 20}
    ModTime "" RegInfo "" RegLvl 0 RegMat "" RegIdx "" DimLen "" MatDB ""
    ConLst "" ConLen "" VarLen ""
    VarName {SimEnv RegGen FldAttr IntfAttr GopAttr OtrAttr ModPar VarVary GetFld PPAttr}
    Prefix "# ---" ESuffix {unsw.edu.au unsw.edu.au}
    BIDLst {{c\d} {(\w+/)?\w+/\w+(/[\deE.+-]+)?} {S\w*} {M\w*} {W\w*}}
    DIDLst {{M\w*} {O\w*}}
    OIDLst {{Spec\w*} {Mono\w*} {Inci\w*}}
    FST .mfj/mfjST.tcl FSTStat .status STHosts {katana tyrion}
    STPaths {/srv/scratch/z3505796/apps/sentaurus
        /share/scratch/z3505796/apps/sentaurus}
    STLicns {27105@license1.restech.unsw.edu.au
        27105@licence.eng.unsw.edu.au}
    STLib {/srv/scratch/z3505796/apps/sentaurus/sharedlib
        /share/scratch/z3505796/apps/sentaurus/sharedlib}
    STTools {sde sdevice svisual inspect sprocess}
    STSuffix {_dvs.cmd _des.cmd _vis.tcl _ins.cmd _fps.cmd}
    STDfltID {ST settings: Tool_label = (\S+) Tool_name = (\S+)}
};# End of 'SimArr'

set FScript [info script]
if {![file executable $FScript]} {
    exec chmod u+x $FScript
}

# Ensure 'pwd' is the directory of the script
cd [file dirname $FScript]

# Keep waiting in case the previous script is still running
if {[file isfile $SimArr(FLock)]} {
    set PID [exec cat $SimArr(FLock)]
    set Lock false
    foreach Elm [split [exec ps -ef] \n] {
        if {[lindex $Elm 1] == $PID} {
            set Lock true
            break
        }
    }

    # Wait until the file lock is removed
    if {$Lock} {
        while {[file isfile $SimArr(FLock)]} {
            after 100
        }
    } else {
        file delete $SimArr(FLock)
    }
}

# Create a file lock to prevent running another '11simctrl.tcl'
exec echo [pid] > $SimArr(FLock)

# Load key files
foreach Elm [list $SimArr(FProc) $SimArr(FIntrpr) $SimArr(FST) $SimArr(FGrm)] {
    if {![file isfile $Elm]} {
        error "Key file '$Elm' missing in directory '[file tail [pwd]]'!"
    } else {
        source $Elm
    }
}
namespace import mfjProc::*

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
        if {![file executable $Elm]} {
            exec chmod u+x $Elm
        }
    } else {
        error "'$Elm' missing in directory '[file tail [pwd]]'!"
    }
}

# Define log files (mfjProc::arr(FOut) and mfjProc::arr(FLog))
set FScript [file rootname [file tail $FScript]]
set mfjProc::arr(FOut) $FScript.out
set mfjProc::arr(FLog) $FScript.mfj

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
            if {[regexp {^\d$|^[1-9]\d+$} $Tmp] && $Tmp < 4} {
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
            if {[regexp {^\d$|^[1-9]\d+$} $Tmp] && $Tmp < 4} {
                for {set i [incr Tmp]} {$i < 4} {incr i} {
                    set Key [lindex [array get SimArr ${i}*] 0]
                    set SimArr($Key) false
                }
            }
            set argv [lrange $argv 2 end]
        }
        default {
            vputs -w "Usage: $FScript.tcl \[-a\] \[-f file\] \[-v #\]\
                \[-r #\] \[-t #\]\n"
            exit 1
        }
    }
}

# Clear log files by default
if {!$SimArr(Append)} {
    vputs -n -w ""
}
vputs "\n[clock format [clock seconds] -format "%Y-%b-%d %A %H:%M:%S"]\
    \t'$::env(USER)@$::env(HOSTNAME)'"
vputs -n "TCL: [info nameofexecutable], version: [info tclversion], >= 8.4? "
if {[info tclversion] >= 8.4} {
    vputs -c "Yes!"
} else {
    vputs "TCL version 8.4 or above is required!"
    exit 1
}

# Determine simulator and job scheduler. Default: Sentaurus Local
if {[file isfile $SimArr(FInfo)]} {
    set InfoLst [split [exec cat $SimArr(FInfo)] |]
} else {
    set InfoLst {Sentaurus Local}
}
vputs -n "Checking [lindex $InfoLst 0] project '[file tail [pwd]]' status: "
set StatLst [list [clock seconds] $::env(HOSTNAME) $::env(USER) unknown [pid]]
if {[lindex $InfoLst 0] eq "Sentaurus"} {
    if {[file isfile $SimArr(FSTStat)]} {
        set StatLst [split [exec cat $SimArr(FSTStat)] |]
    } else {
        exec echo [join $StatLst |] > $SimArr(FSTStat)
    }
}
vputs -c '[lindex $StatLst 3]'\n

# After preprocessing, the status is set to 'ready'. The status will be updated
# to 'running' when the project is running. Yet, it typically requires some
# queue time before a scheduler completes arrangement of desired resources.
set Queue false
if {[file isfile $SimArr(FBatOut)]} {
    set BatOut [exec head -1 $SimArr(FBatOut)]
} else {
    set BatOut ""
}
if {[lindex $InfoLst 0] eq "Sentaurus" && [lindex $StatLst 3] eq "ready"} {
    if {[lindex $InfoLst 1] eq "PBS" && [regexp {^\d+\.[^\d]+} $BatOut]} {
        set Queue true
    } elseif {[lindex $InfoLst 1] eq "SLURM" && [regexp {job \d+$} $BatOut]} {
        set Queue true
    }
}

# Stop the previous batch if it is running or queuing
if {[lindex $InfoLst 0] eq "Sentaurus"
    && ([lindex $StatLst 3] eq "running" || $Queue)} {
    if {[lindex $InfoLst 1] eq "SLURM"} {
        vputs -i1 "Stop the previous batch managed by 'SLURM'...\n"
        if {[regexp {Submitted batch job (\d+)$} $BatOut -> BID]} {
            vputs -i2 "Cancelling SLURM batch: $BID\n"
            if {[catch {exec scancel $BID >/dev/null 2>@1}]} {
                vputs -i2 "Failed! Maybe batch no longer active\n"
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
            if {[catch {exec qdel $BID >/dev/null 2>@1}]} {
                vputs -i2 "Failed! Maybe batch no longer active\n"
            } else {
                vputs -i2 "Batch deleted successfully!\n"
            }
        } else {
            vputs -i2 "PBS batch ID not found! Forcibly update\
                $SimArr(FSTStat)\n"
        }
    } else {
        vputs -i1 "Stop the previous batch at the current node...\n"
        if {[string is integer -strict [lindex $StatLst 4]]} {
            vputs -i2 "Killing PID: [lindex $StatLst 4]\n"
            if {[catch {exec kill [lindex $StatLst 4] >/dev/null 2>@1}]} {
                vputs -i2 "Failed! Maybe PID no longer active\n"
            } else {
                vputs -i2 "PID killed successfully!\n"
            }
        } else {
            vputs -i2 "PID not found! Forcibly update $SimArr(FSTStat)\n"
        }
    }
    after 1000
    lset StatLst 3 aborted
    exec echo [join $StatLst |] > $SimArr(FSTStat)
    exec true > $SimArr(FBatOut)
    vputs -i2 "Project status was changed to 'aborted'. Bye :)\n"

    # Remove the file lock
    file delete $SimArr(FLock)
    exit 0
}

# Convert the raw file to a formatted TXT file containing variable lists
if {$SimArr(0Raw2Fmt)} {
    set SimArr(Time) [clock seconds]
    vputs "Checking host settings and converting '$SimArr(FVarRaw)' to\
        '$SimArr(FVarFmt)'...\n"
    set mfjProc::arr(Indent2) 1
    mfjIntrpr::raw2Fmt
    set mfjProc::arr(Indent2) 0

    # Update SimArr(FInfo) if necessary
    set Lst [list [lindex $mfjIntrpr::arr(FmtSimEnv) 0]\
        [lindex $mfjIntrpr::arr(FmtSimEnv) 4]]
    if {$InfoLst ne $Lst} {
        set InfoLst $Lst
        exec echo [join $InfoLst |] > $SimArr(FInfo)
    }
    vputs -i1 "Processing time = [expr [clock seconds]-$::SimArr(Time)] s\n"
}

# Pass variable lists to the selected simulator
if {$SimArr(1Fmt2Sim)} {
    set SimArr(Time) [clock seconds]
    if {!$SimArr(0Raw2Fmt)} {
        vputs "Checking host settings and reading '$SimArr(FVarFmt)'...\n"
        set mfjProc::arr(Indent2) 1
        mfjIntrpr::readHost
        mfjIntrpr::readFmt
        set mfjProc::arr(Indent2) 0
    }
    if {[lindex $InfoLst 0] eq "Sentaurus"} {
        vputs "Preparing relevant files for 'Sentaurus TCAD'...\n"
        set mfjProc::arr(Indent2) 1
        mfjST::fmt2swb
    }
    set mfjProc::arr(Indent2) 0
    vputs -i1 "Processing time = [expr [clock seconds]-$SimArr(Time)] s\n"
}

# Perform preprocess
if {$SimArr(2PreProc) && [lindex $InfoLst 0] eq "Sentaurus"} {
    vputs "Preprocessing with 'Sentaurus Workbench spp'...\n"
    exec true > $SimArr(FPPOut)
    if {[catch {exec $SimArr(FSTPP) >/dev/stdout\
        | tee -a $SimArr(FPPOut) $mfjProc::arr(FOut) $mfjProc::arr(FLog)}\
        ErrMsg]} {
        vputs -c "\nerror: $ErrMsg\n"
        exit 1
    }
}

# Run trials at the current node or summit them to a job scheduler
if {$SimArr(3Batch) && [lindex $InfoLst 0] eq "Sentaurus"} {
    vputs "Running single/multiple trials with 'Sentaurus Workbench gsub'...\n"
    exec true > $SimArr(FBatOut)
    if {[lindex $InfoLst 1] eq "SLURM"} {
        vputs -i1 "Hand over the simulation job to SLURM...\n"
        exec sbatch $SimArr(FSTBatch) >/dev/stdout\
            | tee -a $SimArr(FBatOut) $mfjProc::arr(FOut) $mfjProc::arr(FLog)
    } elseif {[lindex $InfoLst 1] eq "PBS"} {
        vputs -i1 "Hand over the simulation job to PBS...\n"
        exec qsub $SimArr(FSTBatch) >/dev/stdout\
            | tee -a $SimArr(FBatOut) $mfjProc::arr(FOut) $mfjProc::arr(FLog)
    } else {
        vputs -i1 "Run the simulation job at the current node...\n"
        exec $SimArr(FSTBatch) >/dev/stdout\
            | tee -a $SimArr(FBatOut) $mfjProc::arr(FOut) $mfjProc::arr(FLog) &
    }
}

# Remove the file lock
file delete $SimArr(FLock)
exit 0