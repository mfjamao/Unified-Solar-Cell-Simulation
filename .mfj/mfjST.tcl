################################################################################
# This namespace is designed to group procedures for enabling the interaction
# between the formatted variable file, ::SimArr(FVarFmt) and Sentaurus Work
# Bench (SWB) files:
#   gtree.dat, gvars.dat, ::SimArr(FVarEnv), ::SimArr(FVarSim), ::SimArr(FSTPP),
#   ::SimArr(FSTBatch)
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
################################################################################

package require Tcl 8.4

namespace eval mfjST {
    variable version 2.0

    # Define a big array to handle all data exchange
    variable arr
    array set arr {
        StartIdx -1 Tcl|KeyNode "" Tcl|RunNode "" Tcl|CMILst ""
        Tcl|VarLst "" TclRsvd|VarLst "" TclEnv|VarLst "" TclST|VarLst ""
        TclSWB|VarLst "" Tcl|STLst "" TclSWB|STLst ""
        Tcl|Title {#if "@tool_label@" eq "(\S+)"}
        Tcl|EnvHead "Tcl environment variables for Sentaurus TCAD"
        SWB|VarLst "" SWB|STLst "" SWB|STVer "" SWB|OneChild OneChild
        SWB|HideVar !HideVar
        SWB|Head "# Copyright (C) 1994-2016 Synopsys Inc."
        SWB|KeyID {{swbtree v(\S+)} "simulation flow" "variables"
            "scenarios and parameter specs" "simulation tree"}
        Bat|STRoot "" Bat|STVer "" Bat|STLicn "" Bat|STSLib "" Bat|STPDir ""
        Bat|CMILst "" Bat|Sched "Local" Bat|MaxTime "" Bat|MaxMem ""
        Bat|MaxCPU "" Bat|RunNode "" Bat|Email "" UpdateArr false
        UpdateTcl false UpdateSWB false UpdateBat false updateCmd false
        DOE|Title {"# Trial node list for output files"
            "# Input variables and values for each trial"
            "# Key input and output variables and values for each trial"}
    }
}

# mfjST::validatePath
    # Validate the current project path according to SWB User Guide (Ch. 2)
    # No characters for path: / \ ~ * ? $ ! " < > : [ ] { } = | ; <tab> <space>
    # No characters for name: , @ # ( ) ' ` + & ^ %
proc mfjST::validatePath {} {
    vputs -n "Validating the current SWB project full path '[pwd]'... "
    foreach Elm [lrange [file split [pwd]] 1 end] {
        foreach Var {` ~ ! @ # $ % ^ & * ( ) = + \[ \] \{ \} \\ | ; : ' \"
            , < > ? \ } {
            if {[string match \\$Var $Elm]} {
                error "forbidden character '$Var' found in '$Elm'!"
            }
        }
    }
    vputs -c 'OK'
    vputs
}

# mfjST::readTcl
    # Read ::SimArr(FVarSim) and ::SimArr(FVarEnv) and update the corresponding
    # variables in arr
proc mfjST::readTcl {} {
    variable arr
    vputs "Reading the variable Tcl files '$::SimArr(FVarEnv)' and\
        '$::SimArr(FVarSim)'..."
    if {[file isfile $::SimArr(FVarEnv)] && [file isfile $::SimArr(FVarSim)]} {

        # No multiple levels in ::SimArr(::SimArr(FVarEnv))
        set Inf [open $::SimArr(FVarEnv) r]
        set Lines [split [read $Inf] \n]
        close $Inf
        set Flg true
        set Str ""
        vputs -v3 -i1 "Reserved variables:"
        foreach Line $Lines {
            set Line [string trimleft $Line]

            # Analyse string after reading an empty or comment line
            if {$Line eq "" || [string index $Line 0] eq "#"} {
                if {[llength $Str] == 3} {
                    set Var [lindex $Str 1]
                    if {[regexp {^mfj\w+$} $Var]} {
                        lappend arr(TclRsvd|VarLst) $Var
                    } else {
                        if {$Flg} {
                            vputs -v3 -i1 "Environment variables:"
                            set Flg false
                        }
                        lappend arr(TclEnv|VarLst) $Var
                        lappend arr(Tcl|VarLst) $Var
                    }
                    set Val [lindex $Str 2]
                    set arr(TclVal|$Var) $Val
                    set arr(TclLvl|$Var) 1
                    vputs -v3 -i2 "$Var: \{$arr(TclVal|$Var)\}"
                    set Str ""
                }
            } else {
                append Str " [string trim $Line]"
            }
        }

        if {[info exists arr(TclVal|mfjSTLst)]} {
            set arr(Tcl|STLst) $arr(TclVal|mfjSTLst)
        } else {
            error "variable 'mfjSTLst' missing in '$::SimArr(FVarEnv)'!"
        }
        set Inf [open $::SimArr(FVarSim) r]
        set Lines [split [read $Inf] \n]
        close $Inf
        set Idx 0
        set WBFlg true
        set Str ""
        foreach Line $Lines {
            set Line [string trimleft $Line]

            # Analyse string after reading an empty or comment line
            if {$Line eq "" || [string index $Line 0] eq "#"} {

                # Extract tool label
                if {[string index $Line 0] eq "#"
                    && [regexp -nocase $arr(Tcl|Title) $Line -> Lbl]} {
                    set Tool [lindex $arr(Tcl|STLst) $Idx]
                    if {$WBFlg} {
                        if {$Tool eq "sprocess"
                            && [string equal -nocase Process\
                            [lindex $arr(TclVal|SimEnv) 3]]} {
                            set WBFlg false
                        }
                        lappend arr(TclSWB|STLst) $Tool
                        set arr(TclWB$Tool|VarLst) [list]
                    }
                    set arr(TclLbl|$Tool) $Lbl
                    set arr(Tcl$Tool|VarLst) [list]
                    vputs -v3 -i1 "Sentaurus tool: '$Tool'\tlabel: '$Lbl'"
                    incr Idx
                } elseif {[lindex $Str 0] eq "set"} {
                    if {[regexp {^(\w+)<(\d+)>$} [lindex $Str 1]\
                        -> Var Len]} {
                        if {$WBFlg} {
                            lappend arr(TclSWB|VarLst) $Var
                            lappend arr(TclWB$Tool|VarLst) $Var
                        }
                        lappend arr(Tcl|VarLst) $Var
                        lappend arr(TclST|VarLst) $Var
                        lappend arr(Tcl$Tool|VarLst) $Var
                        set arr(TclVal|$Var) [lindex $Str 2]
                        set arr(TclLvl|$Var) $Len
                        vputs -v3 -i2 "$Var<$Len>: '\{$arr(TclVal|$Var)\}'"
                    } else {
                        set Var [lindex $Str 1]
                        if {$Var ne [lindex $arr(Tcl|VarLst) end]} {
                            lappend arr(Tcl|VarLst) $Var
                            lappend arr(TclST|VarLst) $Var
                            lappend arr(Tcl$Tool|VarLst) $Var
                            set arr(TclVal|$Var) [lindex $Str 2]
                            set arr(TclLvl|$Var) 1
                            vputs -v3 -i2 "$Var: '\{$arr(TclVal|$Var)\}'"
                        }
                    }
                    set Str ""
                }
            } else {
                append Str " $Line"
            }
        }
        vputs -i1 "'[llength $arr(Tcl|VarLst)]' variables found!"
    } else {
        vputs -i1 "The variable Tcl file '$::SimArr(FVarEnv)' or\
            '$::SimArr(FVarSim)' not found!"
        set arr(UpdateTcl) true
        set arr(updateCmd) true
    }
    vputs
}

# mfjST::ReadSWB
    # Read gtree.dat and update the following variables in arr:
    # SWB|Head SWB|STVer SWB|OneChild SWB|STLst SWB|VarLst SWB|HideVar
proc mfjST::ReadSWB {} {
    variable arr
    vputs "Reading Sentaurus Work Bench(SWB) setting file 'gtree.dat'..."
    if {[file isfile gtree.dat]} {
        set Inf [open gtree.dat r]
        set Lines [split [read $Inf] \n]
        close $Inf
        set ReadFlow false
        set ReadVar false
        set ReadScen false
        set ReadTree false

        # Keep the content of the first line
        set arr(SWB|Head) [lindex $Lines 0]
        foreach Line [lrange $Lines 1 end] {

            # Skip blank lines
            if {![regexp {\S} $Line]} {
                continue
            }
            if {[string index $Line 0] eq "#"} {

                # Extract Sentaurus TCAD version
                if {$arr(SWB|STVer) eq ""} {
                    regexp -nocase ^#\\s[lindex $arr(SWB|KeyID) 0] $Line\
                        -> arr(SWB|STVer)
                }

                # Extract simulation flow
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(SWB|KeyID) 1] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(SWB|KeyID) 1]:"
                    set ReadFlow true
                    set VarIdx 0
                    set VarName [list]
                    set VarVal [list]
                    set IdxLst [list]
                }
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(SWB|KeyID) 2] $Line]} {
                    vputs -v2 -i1 "ST version: '$arr(SWB|STVer)'"
                    vputs -v2 -i1 "Found [lindex $arr(SWB|KeyID) 2]:"
                    set ReadFlow false
                    set ReadVar true
                    set mfjProc::arr(Indent1) 2
                    set GTr [buildTree $VarName $VarVal $IdxLst OneChild]
                    set mfjProc::arr(Indent1) 0
                    vputs -v2 -i1 "Variables visable to SWB:\
                        '$arr(SWB|HideVar)'"
                }
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(SWB|KeyID) 3] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(SWB|KeyID) 3]:"
                    set ReadVar false
                    set ReadScen true
                }
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(SWB|KeyID) 4] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(SWB|KeyID) 4].\
                        Try column mode..."
                    set ReadScen false
                    set ReadTree true
                    set Idx 0
                    vputs -v3 -o [format "%-39s Column" Original]
                }
            } else {
                if {$ReadFlow} {
                    if {[llength $Line] != 4} {
                        vputs -i1 "The SWB setting file 'gtree.dat' is damaged!"
                        set arr(UpdateSWB) true
                        break
                    }

                    # Tools can be distinguished by the empty value
                    if {[lindex $Line 3] eq ""} {
                        if {[regexp {\-rel\s+(\S+)} [lindex $Line 2] -> Tmp]} {
                            set arr(SWB|STVer) $Tmp
                        }
                        set Tool [lindex $Line 1]
                        lappend arr(SWB|STLst) $Tool
                        set arr(SWBLbl|$Tool) [lindex $Line 0]
                        set arr(SWB$Tool|VarLst) [list]
                        lappend IdxLst $VarIdx
                        vputs -v3 -i2 "Sentaurus tool: '$Tool'\tlabel:\
                            '[lindex $Line 0]'"
                    } else {
                        set Var [lindex $Line 1]
                        lappend VarName $Var
                        lappend VarVal [lindex $Line end]
                        lappend arr(SWB$Tool|VarLst) $Var
                        lappend arr(SWB|VarLst) $Var
                        set arr(SWBLvl|$Var) [llength [lindex $Line end]]

                        # Decode values of swb variables, refer to the rules
                        # set out in procedure 'UpdateSWB'
                        if {$arr(SWBLvl|$Var) == 1} {
                            set arr(SWB|HideVar) !HideVar
                            set Val [lindex $Line end]
                            if {$Val eq "/0"} {
                                set arr(SWBVal|$Var) ""
                            } else {
                                set arr(SWBVal|$Var) [string map\
                                    {*: \{ :* \} :: " "} $Val]
                            }
                        } else {
                            set Lst [list]
                            foreach Elm [lindex $Line end] {
                                if {$Elm eq "/0"} {
                                    lappend Lst ""
                                } else {
                                    lappend Lst [string map\
                                        {*: \{ :* \} :: " "} $Elm]
                                }
                            }
                            set arr(SWBVal|$Var) $Lst
                        }
                        incr VarIdx
                        vputs -v3 -i3 "$Var<$arr(SWBLvl|$Var)>:\
                            \{$arr(SWBVal|$Var)\}"
                    }
                }
                if {$ReadVar} {

                    # Do nothing as no particular usage of variables
                }
                if {$ReadScen} {

                    # Do nothing as no particular usage of scenarios
                    # and parameter specs
                }
                if {$ReadTree} {
                    set Txt1 [lrange $Line 0 3]
                    set Txt2 [lrange [lindex $GTr $Idx] 0 3]
                    vputs -v3 -o [format "%-39s $Txt2" $Txt1]
                    if {$Txt1 ne $Txt2} {
                        set arr(SWB|OneChild) !OneChild
                        break
                    }
                    incr Idx
                }
            }
        }
        if {$arr(SWB|STLst) eq ""} {
            vputs -i1 "No ST tools found in 'gtree.dat'!"
            set arr(UpdateSWB) true
        }
        if {!$arr(UpdateSWB)} {
            if {[llength $GTr] != $Idx} {
                set arr(SWB|OneChild) !OneChild
            }
        }
        vputs -v2 -i1 "SWB variable permutation: $arr(SWB|OneChild)"
    } else {
        vputs -i1 "The SWB setting file 'gtree.dat' not found!"
        set arr(UpdateSWB) true
    }
    vputs
}

# mfjST::readBatch
    # Read settings from ::SimArr(FSTBatch) only and update
    # Bat|STRoot Bat|STVer Bat|STLicn Bat|Email Bat|Sched BatPart BatQueue
    # Bat|MaxTime Bat|MaxMem Bat|RunNode UpdateBat
proc mfjST::readBatch {} {
    variable arr
    set FSTPP $::SimArr(CodeDir)/$::SimArr(FSTPP)
    set FSTBatch $::SimArr(CodeDir)/$::SimArr(FSTBatch)
    vputs "Reading batch file '$FSTBatch'..."
    if {[file isfile $FSTPP] && [file isfile $FSTBatch]} {

        # Extract the previous CMI list
        set Inf [open $FSTPP r]
        set Buff [read $Inf]
        close $Inf
        regexp cd\\s$::SimArr(PMIDir)(\.+)cd\\s $Buff -> Str

        # Convert the matched string to list
        while {[info exists Str] && [llength $Str]} {
            lappend arr(Bat|CMILst) [lindex $Str 2]
            set Str [lrange $Str 3 end]
        }

        set Inf [open $FSTBatch r]
        set Lines [split [read $Inf] \n]
        close $Inf
        foreach Line $Lines {
            if {[regexp ^# $Line]} {
                if {[regexp {\#SBATCH} $Line]} {
                    set arr(Bat|Sched) SLURM

                    # '-' needs to be escaped to avoid interpretation as switch
                    if {[regexp {\-\-time=(\d+):00:00} $Line\
                        -> arr(Bat|MaxTime)]} {
                        vputs -v3 -i1 "Job scheduler: $arr(Bat|Sched)"
                        vputs -v3 -i1 "Maximum walltime: $arr(Bat|MaxTime) hrs"
                    }
                    if {[regexp {\-\-mem=(\d+)GB} $Line\
                        -> arr(Bat|MaxMem)]} {
                        vputs -v3 -i1 "Maximum memory: $arr(Bat|MaxMem) GB"
                    }
                    if {[regexp {\-\-ntasks-per-node=(\d+)} $Line\
                        -> arr(Bat|MaxCPU)]} {
                        vputs -v3 -i1 "Maximum CPUs: $arr(Bat|MaxCPU)"
                    }
                    if {[regexp {\-\-mail-user=(\S+)} $Line\
                        -> arr(Bat|Email)]} {
                        vputs -v3 -i1 "Email: $arr(Bat|Email)"
                    }
                }
                if {[regexp {\#PBS} $Line]} {
                    set arr(Bat|Sched) PBS
                    if {[regexp {\-l walltime=(\d+):00:00} $Line\
                        -> arr(Bat|MaxTime)]} {
                        vputs -v3 -i1 "Job scheduler: $arr(Bat|Sched)"
                        vputs -v3 -i1 "Maximum walltime: $arr(Bat|MaxTime) hrs"
                    }
                    if {[regexp {\-l mem=(\d+)gb} $Line\
                        -> arr(Bat|MaxMem)]} {
                        vputs -v3 -i1 "Maximum memory: $arr(Bat|MaxMem) GB"
                    }
                    if {[regexp {\-l ncpus=(\d+)} $Line -> arr(Bat|MaxCPU)]} {
                        vputs -v3 -i1 "Maximum CPUs: $arr(Bat|MaxCPU)"
                    }
                    if {[regexp {\-M (\S+)} $Line -> arr(Bat|Email)]} {
                        vputs -v3 -i1 "Email: $arr(Bat|Email)"
                    }
                }
            } else {
                if {[regexp {^\s*STROOT=(\S+)} $Line -> arr(Bat|STRoot)]} {
                    vputs -v3 -i1 "Sentaurus root: $arr(Bat|STRoot)"
                }
                if {[regexp {^\s*STRELEASE=(\S+)} $Line -> arr(Bat|STVer)]} {
                    vputs -v3 -i1 "Sentaurus version: $arr(Bat|STVer)"
                }
                if {[regexp {^\s*LM_LICENSE_FILE=(\S+)} $Line\
                    -> arr(Bat|STLicn)]} {
                    vputs -v3 -i1 "Sentaurus license: $arr(Bat|STLicn)"
                }
                if {[regexp {^\s*LD_LIBRARY_PATH=(\S+)} $Line\
                    -> Tmp]} {
                    set arr(Bat|STSLib) [lindex [split $Tmp :] end]
                    vputs -v3 -i1 "Sentaurus shared libraries: $arr(Bat|STSLib)"
                }
                if {[regexp {^cd\s+(\S+)$} $Line -> arr(Bat|STPDir)]} {
                    vputs -v3 -i1 "Sentaurus project dirctory: $arr(Bat|STPDir)"
                }
                if {[regexp {^\s*\$STROOT/bin/gsub -verbose -e \"(\S+)\"} $Line\
                    -> arr(Bat|RunNode)]} {
                    set arr(Bat|RunNode) [split $arr(Bat|RunNode) +]
                    vputs -v3 -i1 "SWB node list: $arr(Bat|RunNode)"
                }
            }
        }
        if {$arr(Bat|Sched) eq "Local"} {
            vputs -v3 -i1 "Job scheduler: N/A"
        }
    } else {
        vputs -i1 "'$FSTPP' or '$FSTBatch' not found!"
        set arr(UpdateBat) true
    }
    vputs
}

# mfjST::tclvsFmt
    # Compare ::SimArr(FVarEnv) and ::SimArr(FVarSim) against ::SimArr(FVarFmt).
    # Update arr(StartIdx)
    # and set arr(UpdateTcl) to be true if there is any difference
proc mfjST::tclvsFmt {} {
    variable arr

    # Tcl related variables should be updated here
    if {!$arr(UpdateTcl)} {
        vputs "Comparing '$::SimArr(FVarEnv)' and '$::SimArr(FVarSim)' against\
            '$::SimArr(FVarFmt)'..."

        # Check reserved and environment variables
        set Msg "'$::SimArr(FVarEnv)' is different from '$::SimArr(FVarFmt)'!"
        foreach Tool {Rsvd Env} Str {Reserved Environment} {

            # Variables for a tool may have a different sequence
            foreach Var $arr(Tcl$Tool|VarLst) {
                if {[lsearch -exact $mfjIntrpr::arr(Fmt$Tool|VarLst)\
                    $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "$Str variable '$Var' in\
                        '$::SimArr(FVarFmt)' removed!"
                    continue
                }
                if {$arr(TclVal|$Var) ne $mfjIntrpr::arr(FmtVal|$Var)} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "$Str variable '$Var' has a value of\
                        '$arr(TclVal|$Var)' different from\
                        '$mfjIntrpr::arr(FmtVal|$Var)'!"
                }
            }
            foreach Var $mfjIntrpr::arr(Fmt$Tool|VarLst) {
                if {[lsearch -exact $arr(Tcl$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "$Str variable '$Var' in\
                        '$::SimArr(FVarFmt)' added!"
                }
            }
        }

        # Check ST Tools and variables
        set Msg "'$::SimArr(FVarSim)' is different from '$::SimArr(FVarFmt)'!"

        # Tools should have the same sequence
        if {$arr(Tcl|STLst) ne $mfjIntrpr::arr(Fmt|STLst)} {
            if {!$arr(UpdateTcl)} {
                set arr(UpdateTcl) true
                vputs -i1 $Msg
            }
            vputs -i2 "ST tools '$arr(Tcl|STLst)' different from\
                '$mfjIntrpr::arr(Fmt|STLst)'!"
        }
        if {$arr(UpdateTcl)} {
            set arr(StartIdx) 0
        }

        set STIdx 0
        set Flg true
        foreach Tool $arr(Tcl|STLst) {
            if {$arr(TclLbl|$Tool) ne $mfjIntrpr::arr(FmtLbl|$Tool)} {
                if {!$arr(UpdateTcl)} {
                    set arr(UpdateTcl) true
                    vputs -i1 $Msg
                }
                vputs -i2 "ST tool label '$arr(TclLbl|$Tool)' different\
                    from '$mfjIntrpr::arr(FmtLbl|$Tool)'!"
            }

            # Variables for a tool may have a different sequence
            foreach Var $arr(Tcl$Tool|VarLst) {
                if {[lsearch -exact $mfjIntrpr::arr(Fmt$Tool|VarLst)\
                    $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    if {$Flg && $STIdx > 0 && $arr(StartIdx) == -1} {
                        set arr(StartIdx) [expr $STIdx-1]
                        set Flg false
                    }
                    vputs -i2 "Simulation variable '$Var' of '$Tool' removed!"
                    continue
                }
                if {$arr(TclVal|$Var) ne $mfjIntrpr::arr(FmtVal|$Var)} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    if {$Flg && $STIdx > 0 && $arr(StartIdx) == -1} {
                        set arr(StartIdx) [expr $STIdx-1]
                        set Flg false
                    }
                    vputs -i2 "Simulation variable '$Var' has a value of\
                        '$arr(TclVal|$Var)' different from\
                        '$mfjIntrpr::arr(FmtVal|$Var)'!"
                }
            }
            foreach Var $mfjIntrpr::arr(Fmt$Tool|VarLst) {
                if {[lsearch -exact $arr(Tcl$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    if {$Flg && $STIdx > 0 && $arr(StartIdx) == -1} {
                        set arr(StartIdx) [expr $STIdx-1]
                        set Flg false
                    }
                    vputs -i2 "Simulation variable '$Var' of '$Tool' added!"
                }
            }
            incr STIdx
        }

        if {$arr(UpdateTcl)} {
            if {$arr(StartIdx) == -1} {
                set arr(StartIdx) 0
            }
            vputs -v2 -i2 "ST starting tool index: '$arr(StartIdx)'"
        } else {
            set arr(StartIdx) [llength $arr(Tcl|STLst)]
            vputs -v2 -i2 "ST starting tool index: '$arr(StartIdx)'"
            vputs -i1 "'$::SimArr(FVarEnv)' and '$::SimArr(FVarSim)' are\
                the same as '$::SimArr(FVarFmt)'!"
        }
        vputs
    }
    if {$arr(UpdateTcl)} {

        # Perform an efficient update of all related variables
        set arr(TclRsvd|VarLst) $mfjIntrpr::arr(FmtRsvd|VarLst)
        set arr(TclEnv|VarLst) $mfjIntrpr::arr(FmtEnv|VarLst)
        set arr(Tcl|VarLst) $mfjIntrpr::arr(Fmt|VarLst)
        foreach Var [concat $arr(TclRsvd|VarLst) $arr(Tcl|VarLst)] {
            set arr(TclVal|$Var) $mfjIntrpr::arr(FmtVal|$Var)
            set arr(TclLvl|$Var) $mfjIntrpr::arr(FmtLvl|$Var)
        }
        set arr(Tcl|STLst) $mfjIntrpr::arr(Fmt|STLst)
        set arr(TclST|VarLst) $mfjIntrpr::arr(FmtST|VarLst)
        set arr(TclSWB|STLst) [list]
        set arr(TclSWB|VarLst) [list]
        set WBFlg true
        foreach Tool $arr(Tcl|STLst) {
            set arr(TclLbl|$Tool) $mfjIntrpr::arr(FmtLbl|$Tool)
            set arr(Tcl$Tool|VarLst) $mfjIntrpr::arr(Fmt$Tool|VarLst)
            if {$WBFlg} {

                # Skip the rest tools after 'sprocess' for process simulation
                if {$Tool eq "sprocess" && [string equal -nocase Process\
                    [lindex $arr(TclVal|SimEnv) 3]]} {
                    set WBFlg false
                }
                lappend arr(TclSWB|STLst) $Tool
                set arr(TclWB$Tool|VarLst) [list]
                foreach Var $arr(Tcl$Tool|VarLst) {

                    # SWB variables: 1) HideVar is false; 2) Level > 1
                    if {$arr(TclLvl|$Var) == 1
                        && [string index $::SimArr(HideVar) 0] eq "!"
                        || $arr(TclLvl|$Var) > 1} {
                        lappend arr(TclWB$Tool|VarLst) $Var
                        lappend arr(TclSWB|VarLst) $Var
                    }
                }
            }
        }
    }
}

# mfjST::SWBvsTcl
    # Compare gtree.dat against the updated ::SimArr(FVarSim) and set
    # arr(UpdateSWB) to be true if there is any difference
proc mfjST::SWBvsTcl {} {
    variable arr

    if {!$arr(UpdateSWB)} {
        vputs "Comparing 'gtree.dat' against '$::SimArr(FVarSim)'..."
        set Msg "'gtree.dat' is different from '$::SimArr(FVarSim)'!"
        if {$arr(SWB|OneChild) ne $::SimArr(OneChild)} {
            if {!$arr(UpdateSWB)} {
                set arr(UpdateSWB) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB variable permutation '$arr(SWB|OneChild)'\
                different from '$::SimArr(OneChild)'!"
        }
        if {$arr(SWB|STVer) ne [lindex $arr(TclVal|SimEnv) 1]} {
            if {!$arr(UpdateSWB)} {
                set arr(UpdateSWB) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus TCAD version '$arr(SWB|STVer)' different\
                from '[lindex $arr(TclVal|SimEnv) 1]'!"
        }
        if {$arr(SWB|HideVar) ne $::SimArr(HideVar)} {
            if {!$arr(UpdateSWB)} {
                set arr(UpdateSWB) true
                vputs -i1 $Msg
            }
            set Msg "Variables visable to SWB?\
                '$arr(SWB|HideVar)' different from '$::SimArr(HideVar)'!"
        }

        # Check SWB tools and variables. Tools should have the same sequence
        if {$arr(SWB|STLst) ne $arr(TclSWB|STLst)} {
            if {!$arr(UpdateSWB)} {
                set arr(UpdateSWB) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB tools '$arr(SWB|STLst)' different from\
                '$arr(TclSWB|STLst)'!"
        }
        foreach Tool $arr(SWB|STLst) {
            if {$arr(SWBLbl|$Tool) ne $arr(TclLbl|$Tool)} {
                if {!$arr(UpdateSWB)} {
                    set arr(UpdateSWB) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "SWB tool label '$arr(SWBLbl|$Tool)' different\
                    from '$arr(TclLbl|$Tool)'!"
            }

            # Variables for a tool may have a different sequence
            foreach Var $arr(SWB$Tool|VarLst) {
                if {[lsearch -exact $arr(TclWB$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateSWB)} {
                        set arr(UpdateSWB) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool'\
                        removed!"
                    continue
                }
                if {$arr(SWBVal|$Var) ne $arr(TclVal|$Var)} {
                    if {!$arr(UpdateSWB)} {
                        set arr(UpdateSWB) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' has a value of\
                        '$arr(SWBVal|$Var)' different from '$arr(TclVal|$Var)'!"
                }
            }
            foreach Var $arr(TclWB$Tool|VarLst) {
                if {[lsearch -exact $arr(SWB$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateSWB)} {
                        set arr(UpdateSWB) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool' added!"
                }
            }
        }
        if {$arr(UpdateSWB)} {
            vputs -v2 -i2 "ST starting tool index: '$arr(StartIdx)'"
        } else {
            vputs -i1 "'gtree.dat' is the same as '$::SimArr(FVarSim)'!"
        }
        vputs
    }
    if {$arr(UpdateSWB)} {

        # Perform an efficient update of all related variables
        set arr(SWB|STVer) [lindex $arr(TclVal|SimEnv) 1]
        set arr(SWB|HideVar) $::SimArr(HideVar)
        set arr(SWB|OneChild) $::SimArr(OneChild)
        set arr(SWB|STLst) $arr(TclSWB|STLst)
        set arr(SWB|VarLst) $arr(TclSWB|VarLst)
        foreach Tool $arr(SWB|STLst) {
            set arr(SWBLbl|$Tool) $arr(TclLbl|$Tool)
            set arr(SWB$Tool|VarLst) $arr(TclWB$Tool|VarLst)
            foreach Var $arr(SWB$Tool|VarLst) {
                set arr(SWBVal|$Var) $arr(TclVal|$Var)
                set arr(SWBLvl|$Var) $arr(TclLvl|$Var)
            }
        }
    }
}

# mfjST::TclvsSWB
    # Compare ::SimArr(FVarEnv) and ::SimArr(FVarSim) against gtree.dat and
    # set arr(UpdateTcl) to be true if there is any difference
proc mfjST::TclvsSWB {} {
    variable arr

    # In cace of big difference:
    #   a) SWB tools are different
    #   b) ::SimArr(FVarSim) is not present
    if {!$arr(UpdateTcl)} {
        vputs "Comparing '$::SimArr(FVarSim)' against 'gtree.dat'..."

        # Check ST Tools and variables. Tools should have the same sequence
        set Msg "'$::SimArr(FVarSim)' is different from 'gtree.dat'!"
        if {$arr(TclSWB|STLst) ne $arr(SWB|STLst)} {
            if {!$arr(UpdateTcl)} {
                set arr(UpdateTcl) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB tools '$arr(TclSWB|STLst)' different from\
                '$arr(SWB|STLst)'!\n"
        }
    }
    if {$arr(UpdateTcl)} {

        # Perform a efficient update of Tcl related variables
        set arr(TclSWB|STLst) $arr(SWB|STLst)
        set VarLst [list]
        foreach Tool $arr(TclSWB|STLst) {
            set arr(TclLbl|$Tool) $arr(SWBLbl|$Tool)
            set arr(Tcl$Tool|VarLst) $arr(SWB$Tool|VarLst)
            set VarLst [concat $VarLst $arr(Tcl$Tool|VarLst)]
            foreach Var $arr(Tcl$Tool|VarLst) {
                set arr(TclVal|$Var) $arr(SWBVal|$Var)
                set arr(TclLvl|$Var) $arr(SWBLvl|$Var)
            }
        }
        set arr(Tcl|VarLst) $VarLst
        set Len [llength $arr(TclSWB|STLst)]
        set arr(Tcl|STLst) [concat $arr(TclSWB|STLst)\
            [lrange $arr(Tcl|STLst) $Len end]]
        foreach Tool [lrange $arr(Tcl|STLst) $Len end] {
            set Lst [list]
            foreach Var $arr(Tcl$Tool|VarLst) {
                if {[lsearch -exact $VarLst $Var] == -1} {
                    lappend Lst $Var
                }
            }
            set arr(Tcl$Tool|VarLst) $Lst
        }
    }

    # No big changes but small changes in SWB, limited to workbench variables
    if {!$arr(UpdateTcl)} {
        foreach Tool $arr(TclSWB|STLst) {
            if {$arr(SWBLbl|$Tool) ne $arr(TclLbl|$Tool)} {
                if {!$arr(UpdateTcl)} {
                    set arr(UpdateTcl) true
                    vputs -i1 $Msg
                }
                set arr(TclLbl|$Tool) $arr(SWBLbl|$Tool)
                vputs -v3 -i2 "SWB tool label '$arr(TclLbl|$Tool)'\
                    different from '$arr(SWBLbl|$Tool)'!"
            }

            # Variables for a tool may have a different sequence
            # Most likely variables and their values are modified in SWB
            # Update Tcl$Tool|VarLst as well
            foreach Var $arr(TclWB$Tool|VarLst) {
                if {[lsearch -exact $arr(SWB$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }

                    # Not SWB variable anymore, multi-Level -> single Level
                    # Take the first value as default
                    if {$arr(TclLvl|$Var) > 1} {
                        set arr(TclVal|$Var) [lindex $arr(TclVal|$Var) 0]
                        set arr(TclLvl|$Var) 1
                    }
                    vputs -v3 -i2 "SWB variable '$Var' of '$Tool' removed!"
                    continue
                }
                if {$arr(SWBVal|$Var) ne $arr(TclVal|$Var)} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    set arr(TclVal|$Var) $arr(SWBVal|$Var)
                    set arr(TclLvl|$Var) $arr(SWBLvl|$Var)
                    vputs -v3 -i2 "SWB variable '$Var' has a value of\
                        '$arr(TclVal|$Var)' different from\
                        '$arr(SWBVal|$Var)'!"
                }
            }
            foreach Var $arr(SWB$Tool|VarLst) {
                if {[lsearch -exact $arr(TclWB$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    if {[lsearch -exact $arr(Tcl$Tool|VarLst) $Var] == -1} {
                        lappend arr(Tcl$Tool|VarLst) $Var
                    }
                    set arr(TclVal|$Var) $arr(SWBVal|$Var)
                    set arr(TclLvl|$Var) $arr(SWBLvl|$Var)
                    vputs -v3 -i2 "SWB variable '$Var' of '$Tool' added!"
                }
            }
        }
    }
    if {!$arr(UpdateTcl)} {
        vputs -i1 "'$::SimArr(FVarSim)' is the same as 'gtree.dat'!\n"
    }
}

# mfjST::arrvsSWB
    # Compare ::SimArr against gtree.dat and set arr(UpdateArr) to be true
    # if there is any difference
proc mfjST::arrvsSWB {} {
    variable arr

    if {!$arr(UpdateArr)} {
        vputs "Comparing '::SimArr' against 'gtree.dat'..."
        set Msg "'::SimArr' is different from 'gtree.dat'!"
        if {$::SimArr(OneChild) ne $arr(SWB|OneChild)} {
            if {!$arr(UpdateArr)} {
                set arr(UpdateArr) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB variable permutation '$::SimArr(OneChild)'\
                different from '$arr(SWB|OneChild)'!"
            set ::SimArr(OneChild) $arr(SWB|OneChild)
        }
        if {$::SimArr(HideVar) ne $arr(SWB|HideVar)} {
            if {!$arr(UpdateArr)} {
                set arr(UpdateArr) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Variables visable to SWB?\
                '$::SimArr(HideVar)' different from '$arr(SWB|HideVar)'!"
            set ::SimArr(HideVar) $arr(SWB|HideVar)
        }

        # Go through each SWB variable and update the case in ::SimArr(VarName)
        foreach Var $arr(SWB|VarLst) {

            # Extract variable name
            set Idx [lsearch -regexp $::SimArr(VarName) (?i)^$Var$]
            if {$Idx == -1} {

                # SWB variable not found
                if {!$arr(UpdateArr)} {
                    set arr(UpdateArr) true
                    vputs -i1 $Msg
                }
                lappend ::SimArr(VarName) $Var
                vputs -v3 -i2 "SWB variable '$Var' added in '::SimArr(VarName)'\
                    of '11ctrlsim.tcl'!"
            } else {

                # Check whether the variable names are the same case
                if {[lindex $::SimArr(VarName) $Idx] ne $Var} {
                    if {!$arr(UpdateArr)} {
                        set arr(UpdateArr) true
                        vputs -i1 $Msg
                    }
                    lset ::SimArr(VarName) $Idx $Var
                    vputs -v3 -i2 "SWB variable '$Var' updated in\
                        '::SimArr(VarName)' of '11ctrlsim.tcl'!"
                }
            }
        }
        if {!$arr(UpdateArr)} {
            vputs -i1 "'::SimArr' is the same as 'gtree.dat'!"
        }
        vputs
    }
}

# mfjST::batchvsTcl
    # Compare ::SimArr(FSTBatch) against ::SimArr(FVarEnv), ::SimArr(FVarSim).
    # Update Tcl|KeyNode and set arr(UpdateBat) to be true if there is any
    # difference
proc mfjST::batchvsTcl {} {
    variable arr

    # Update arr(Tcl|KeyNode), arr(Tcl|RunNode) and arr(Tcl|CMILst)
    set VarName [list]
    set VarVal [list]
    set IdxLst [list]
    set VarIdx 0
    foreach Tool $arr(TclSWB|STLst) {
        lappend IdxLst $VarIdx
        foreach Var $arr(TclWB$Tool|VarLst) {
            lappend VarName $Var
            lappend VarVal $arr(TclVal|$Var)
            incr VarIdx
        }
    }
    set arr(Tcl|KeyNode) [buildTree $VarName $VarVal $IdxLst\
        $::SimArr(OneChild) !NodeTree]
    if {$arr(UpdateTcl)} {
        if {$arr(StartIdx) == 0} {
            set arr(Tcl|RunNode) all
        } else {
            set arr(Tcl|RunNode) [string map {\{ ""  \} ""}\
                [lrange $arr(Tcl|KeyNode) $arr(StartIdx) end]]
        }
    } else {
        set arr(Tcl|RunNode) remaining
    }
    foreach Elm $arr(TclVal|mfjModTime) {
        if {[regexp {(\w+)\.[cC]$} [lindex $Elm 0] -> Root]} {
            if {[glob -nocomplain $::SimArr(PMIDir)/$Root.so.*] eq ""} {
                lappend arr(Tcl|CMILst) [file tail [lindex $Elm 0]]
            }
        }
    }
    set STROOT [lsearch -inline -regexp [glob -nocomplain -directory\
        $mfjIntrpr::arr(Host|STPath) *] (?i)[lindex $arr(TclVal|SimEnv) 1]$]

    if {!$arr(UpdateBat)} {
        vputs "Comparing '$::SimArr(FSTBatch)' against\
            '$::SimArr(FVarEnv)', '$::SimArr(FVarSim)' and the host..."
        set Msg "'$::SimArr(FSTBatch)' is different from '$::SimArr(FVarEnv)'!"
        if {$arr(Bat|STVer) ne [lindex $arr(TclVal|SimEnv) 1]} {

            # Sentaurus related variables are case-sensitive
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus version '$arr(Bat|STVer)' different\
                from '[lindex $arr(TclVal|SimEnv) 1]'!"
        }
        if {$arr(Bat|STRoot) ne $STROOT} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus root '$arr(Bat|STRoot)' different\
                from '$STROOT'!"
        }

        # SLURM partition or PBS queue is case sensitive
        if {$arr(Bat|Sched) ne [lindex $arr(TclVal|SimEnv) 4]} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Job scheduler '$arr(Bat|Sched)' different\
                from '[lindex $arr(TclVal|SimEnv) 4]'!"

        }
        if {$arr(Bat|Sched) ne "Local"} {
            if {$arr(Bat|MaxTime) != [lindex $arr(TclVal|SimEnv) 5]} {
                if {!$arr(UpdateBat)} {
                    set arr(UpdateBat) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Maximum walltime '$arr(Bat|MaxTime)' hrs\
                    different from '[lindex $arr(TclVal|SimEnv) 5]'!"
            }
            if {$arr(Bat|MaxMem) != [lindex $arr(TclVal|SimEnv) 6]} {
                if {!$arr(UpdateBat)} {
                    set arr(UpdateBat) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Maximum memory '$arr(Bat|MaxMem)' GB\
                    different from '[lindex $arr(TclVal|SimEnv) 6]'!"
            }
            if {$arr(Bat|MaxCPU) != [lindex $arr(TclVal|SimEnv) 7]} {
                if {!$arr(UpdateBat)} {
                    set arr(UpdateBat) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Maximum CPUs '$arr(Bat|MaxCPU)'\
                    different from '[lindex $arr(TclVal|SimEnv) 7]'!"
            }
        }

        set Msg "'$::SimArr(FSTBatch)' is different from the host!"
        if {$arr(Bat|STLicn) ne $mfjIntrpr::arr(Host|STLicn)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus license '$arr(Bat|STLicn)' different\
                from '$mfjIntrpr::arr(Host|STLicn)'!"
        }
        if {$arr(Bat|STSLib) ne $mfjIntrpr::arr(Host|STSLib)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus shared libraries '$arr(Bat|STSLib)'\
                different from '$mfjIntrpr::arr(Host|STSLib)'!"
        }
        if {$arr(Bat|Sched) ne "Local"
            && $arr(Bat|Email) ne $mfjIntrpr::arr(Host|Email)} {

            # Case sensitive
            set arr(UpdateBat) true
            set Msg "Email '$arr(Bat|Email)' different\
                from '$mfjIntrpr::arr(Host|Email)'!"
        }
        if {$arr(Bat|STPDir) ne [pwd]} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus project directory '$arr(Bat|STPDir)'\
                different from '[pwd]'!"
        }

        set Msg "'$::SimArr(FSTBatch)' is different from '$::SimArr(FVarSim)'!"
        if {$arr(Bat|RunNode) ne $arr(Tcl|RunNode)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB to run nodes '$arr(Bat|RunNode)' different\
                from '$arr(Tcl|RunNode)'!"
        }
        if {$arr(Bat|CMILst) ne $arr(Tcl|CMILst)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "CMI list '$arr(Bat|CMILst)' different\
                from '$arr(Tcl|CMILst)'!"
        }
        if {!$arr(UpdateBat)} {
            vputs -i1 "'$::SimArr(FSTBatch)' is the same as\
                '$::SimArr(FVarEnv)', '$::SimArr(FVarSim)' and the host!"
        }
        vputs
    }
    if {$arr(UpdateBat)} {
        set arr(Bat|STVer) [lindex $arr(TclVal|SimEnv) 1]
        set arr(Bat|Sched) [lindex $arr(TclVal|SimEnv) 4]
        set arr(Bat|MaxTime) [lindex $arr(TclVal|SimEnv) 5]
        set arr(Bat|MaxMem) [lindex $arr(TclVal|SimEnv) 6]
        set arr(Bat|MaxCPU) [lindex $arr(TclVal|SimEnv) 7]
        set arr(Bat|STRoot) $STROOT
        set arr(Bat|Email) $mfjIntrpr::arr(Host|Email)
        set arr(Bat|STLicn) $mfjIntrpr::arr(Host|STLicn)
        set arr(Bat|STSLib) $mfjIntrpr::arr(Host|STSLib)
        set arr(Bat|STPDir) [pwd]
        set arr(Bat|RunNode) $arr(Tcl|RunNode)
        set arr(Bat|CMILst) $arr(Tcl|CMILst)
    }
}

# mfjST::updateTcl
    # Update the variable Tcl files ::SimArr(FVarEnv) and ::SimArr(FVarSim) if
    # arr(UpdateTcl) is true
proc mfjST::updateTcl {} {
    variable arr
    set Tab $mfjProc::arr(Tab)
    if {$arr(UpdateTcl)} {
        vputs "Updating the variable Tcl files '$::SimArr(FVarEnv)' and\
            '$::SimArr(FVarSim)'..."
        if {[file isfile $::SimArr(FVarEnv)]} {
            vputs -v5 -i1 "Making a Tcl file backup\
                '$::SimArr(FVarEnv).backup'..."
            file copy -force $::SimArr(FVarEnv) $::SimArr(FVarEnv).backup
        }
        set Ouf [open $::SimArr(FVarEnv).mfj w]
        vputs -v3 -i1 -n "Calculating the max length of environment variable\
            names... "
        set MaxLen [calMaxVarLen [concat $arr(TclRsvd|VarLst)\
            $arr(TclEnv|VarLst)]]

        # Add at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]
        vputs -v3 -c '$MaxLen'
        puts $Ouf "$::SimArr(Prefix) $arr(Tcl|EnvHead)\n"

        # Output environment variables
        foreach Tool {Rsvd Env} {
            foreach Var $arr(Tcl$Tool|VarLst) {
                puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n"\
                    $Var $arr(TclVal|$Var)] $Tab]
            }
        }
        close $Ouf
        file rename -force $::SimArr(FVarEnv).mfj $::SimArr(FVarEnv)

        if {[file isfile $::SimArr(FVarSim)]} {
            vputs -v5 -i1 "Making a Tcl file backup '$::SimArr(FVarSim).backup'..."
            file copy -force $::SimArr(FVarSim) $::SimArr(FVarSim).backup
        }

        set Ouf [open $::SimArr(FVarSim).mfj w]
        vputs -v3 -i1 -n "Calculating the max length of simulation variable\
            names... "
        set MaxLen [calMaxVarLen $arr(TclST|VarLst)]

        # Add at least one space between a variable and its value
        # Assuming a maximum of 999 values, which consume <=5 characters
        set MaxLen [expr {int(ceil(($MaxLen+6.)/4.))*4}]
        vputs -v3 -c '$MaxLen'

        # Output simulation variables
        set Ptn [string map {(\\S+) %s} $arr(Tcl|Title)]
        set STIdx 0
        foreach Tool $arr(Tcl|STLst) {
            if {$STIdx} {
                puts $Ouf "#endif\n"
            }
            puts $Ouf [format $Ptn\n $arr(TclLbl|$Tool)]
            foreach Var $arr(Tcl$Tool|VarLst) {
                if {$arr(TclLvl|$Var) == 1
                    && [string index $::SimArr(HideVar) 0] ne "!"} {
                    puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n"\
                        $Var $arr(TclVal|$Var)] $Tab]
                }

                # SWB variables: 1) HideVar is false; 2) Level > 1
                if {$arr(TclLvl|$Var) == 1
                    && [string index $::SimArr(HideVar) 0] eq "!"
                    || $arr(TclLvl|$Var) > 1} {
                    set Val $arr(TclVal|$Var)
                    if {$arr(TclLvl|$Var) > 1} {
                        set Val \{[join $Val \}\n\{]\}
                    }
                    puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n"\
                        $Var<$arr(TclLvl|$Var)> $Val] $Tab]

                    # Decrease MaxLen with 4 spaces and revert it afterwards
                    incr MaxLen -4
                    puts $Ouf [wrapText [format "#if \"@%s@\" eq \"/0\"" $Var]\
                        $Tab]
                    puts $Ouf [wrapText [format "set %-${MaxLen}s\{\}" $Var]\
                        ${Tab}$Tab]
                    puts $Ouf [wrapText "#else" $Tab]
                    puts $Ouf [wrapText [format "set %-${MaxLen}s\[string map\
                        \{*: \\{ :* \\} :: \" \"\} @%s@\]" $Var $Var]\
                        ${Tab}$Tab]
                    puts $Ouf [wrapText "#endif\n" $Tab]
                    incr MaxLen 4
                }
            }
            incr STIdx
        }
        if {[llength $arr(Tcl|STLst)]} {
            puts $Ouf "#endif"
        }
        close $Ouf
        file rename -force $::SimArr(FVarSim).mfj $::SimArr(FVarSim)
        vputs
    }
}

# mfjST::updateArr
    # Update keys OneChild, HideVar, and VarName in ::SimArr if
    # arr(UpdateArr) is true
proc mfjST::updateArr {} {
    variable arr
    if {$arr(UpdateArr)} {
        vputs "Updating keys OneChild, HideVar, and VarName in ::SimArr..."
        if {![file isfile 11ctrlsim.tcl]} {
            error "'11ctrlsim.tcl' missing in directory '[file tail [pwd]]'!"
        }
        file copy -force 11ctrlsim.tcl 11ctrlsim.tcl.backup
        set Inf [open 11ctrlsim.tcl r]
        set Buff [read $Inf]
        close $Inf
        regsub HideVar\\s+\\S+\\s+OneChild\\s+\\S+\\s+DfltYMax $Buff\
            "HideVar $::SimArr(HideVar) OneChild $::SimArr(OneChild) DfltYMax"\
            Buff
        regsub {VarName\s+\{[^\}]+\}} $Buff [wrapText\
            "VarName \{$::SimArr(VarName)\}" $mfjProc::arr(Tab)] Buff

        set Ouf [open 11ctrlsim.tcl w]
        puts -nonewline $Ouf $Buff
        close $Ouf
        vputs
    }
}

# mfjST::UpdateSWB
    # If arr(UpdateSWB) is true, update the SWB setting file 'gtree.dat'
    # with arr(SWB|Head) arr(SWB|OneChild) arr(SWB|STVer) arr(SWB|HideVar)
    # arr(SWB|VarLst) arr(SWB|STLst)
proc mfjST::UpdateSWB {} {
    variable arr

    if {$arr(UpdateSWB)} {
        vputs "Updating the SWB setting file 'gtree.dat'..."
        if {[file isfile gtree.dat]} {
            vputs -v5 -i1 "Making a SWB setting file backup\
                'gtree.dat.backup'..."
            file copy -force gtree.dat gtree.dat.backup
        }

        vputs -v2 -i1 "Writing the file head..."
        set Ouf [open gtree.dat.mfj w]
        set Tm [clock format [clock seconds] -format "%a %b %d %H:%M:%S %Y" ]
        puts $Ouf "# $Tm, generated by '[file tail [info script]]'"
        set Ptn [string map {(\\S+) %s} [lindex $arr(SWB|KeyID) 0]]
        puts $Ouf [format "# $Ptn" $arr(SWB|STVer)]
        if {[string index $arr(SWB|HideVar) 0] eq "!"} {
            puts $Ouf "# All variables are visable to SWB"
        } else {
            puts $Ouf "# Only multiple-level variables are visable to SWB"
        }
        if {[string index $arr(SWB|OneChild) 0] ne "!"} {
            puts $Ouf "# Node tree permutation: OneChild mode"
        } else {
            puts $Ouf "# Node tree permutation: Full permutation"
        }

        vputs -v2 -i1 "Writing [lindex $arr(SWB|KeyID) 1]..."
        puts $Ouf "\n$::SimArr(Prefix) [lindex $arr(SWB|KeyID) 1]"
        set VarIdx 0
        set VarName [list]
        set VarVal [list]
        set IdxLst [list]
        foreach Tool $arr(SWB|STLst) {
            set Lbl $arr(SWBLbl|$Tool)
            puts $Ouf "$Lbl $Tool \"-rel [lindex $arr(TclVal|SimEnv) 1]\" {}"
            lappend IdxLst $VarIdx
            foreach Var $arr(SWB$Tool|VarLst) {
                lappend VarName $Var

                # swb allowed characters: \w.:+/*-
                # swb can display illegal characters like [](){}<>
                # To renounce illegal characters, follow the rules below:
                # '*:' denotes '{', ':*' denotes '}', '::' denotes ' '
                # If a variable value is an empty string, replace it with '/0'
                if {$arr(SWBLvl|$Var) > 1} {
                    set Lst [list]
                    foreach Elm $arr(SWBVal|$Var) {
                        if {$Elm eq ""} {
                            lappend Lst /0
                        } else {
                            lappend Lst [string map {\{ *: \} :* " " ::} $Elm]
                        }
                    }
                    lappend VarVal $Lst
                    puts $Ouf "$Lbl $Var \"$arr(SWBLvl|$Var)\" \{$Lst\}"
                } else {
                    if {$arr(SWBVal|$Var) eq ""} {
                        set Val /0
                    } else {
                        set Val [string map {\{ *: \} :* " " ::}\
                            $arr(SWBVal|$Var)]
                    }
                    puts $Ouf "$Lbl $Var \"1\" \{$Val\}"
                    lappend VarVal $Val
                }
                incr VarIdx
            }
        }

        vputs -v2 -i1 "Writing [lindex $arr(SWB|KeyID) 2]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(SWB|KeyID) 2]"
        vputs -v2 -i1 "Writing [lindex $arr(SWB|KeyID) 3]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(SWB|KeyID) 3]"
        foreach Var $arr(SWB|VarLst) {
            puts $Ouf "scenario default $Var \"\""
        }

        vputs -v2 -i1 "Writing [lindex $arr(SWB|KeyID) 4]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(SWB|KeyID) 4]"
        set mfjProc::arr(Indent1) 2
        foreach Elm [buildTree $VarName $VarVal $IdxLst $arr(SWB|OneChild)] {
            puts $Ouf $Elm
        }
        set mfjProc::arr(Indent1) 0
        close $Ouf
        file rename -force gtree.dat.mfj gtree.dat
        vputs
    }
}

# mfjST::updateCmd
    # Replace SWB variables with Tcl variables in all command files
proc mfjST::updateCmd {} {
    variable arr


    if {$arr(updateCmd)} {

    }
}

# mfjST::updatePP_Bat
    # If arr(UpdateBat) is true, update pre-processing file and batch file
    # with arr(Bat|Sched) arr(BatPart) arr(BatQueue) arr(Bat|Email)
    # arr(Bat|MaxTime) arr(Bat|MaxMem) arr(Bat|STVer) arr(Bat|STRoot)
    # arr(Bat|STLicn) arr(Tcl|KeyNode)
    # arr(Bat|RunNode) keeps its original value for miscTask
proc mfjST::updatePP_Bat {} {
    variable arr

    if {$arr(UpdateBat)} {
        set FSTPP $::SimArr(CodeDir)/$::SimArr(FSTPP)
        set FSTBatch $::SimArr(CodeDir)/$::SimArr(FSTBatch)
        vputs "Updating '$FSTPP' and '$FSTBatch'..."
        foreach Elm [list FSTPP FSTBatch] {
            upvar 0 $Elm Alias
            if {[file exists $Alias]} {

                # 'file copy' overwrites file permission, different from 'cp'
                file copy -force $Alias $Alias.backup
                if {$::tcl_platform(platform) eq "unix"} {
                    exec chmod u-x $Alias.backup
                }
            }
            set Ouf [open $Alias.mfj w]
            puts $Ouf "#!/bin/bash\n"
            if {$Elm eq "FSTBatch"} {
                if {$arr(Bat|Sched) eq "SLURM"} {
                    puts $Ouf "#SBATCH --time=$arr(Bat|MaxTime):00:00"
                    puts $Ouf "#SBATCH --mem=$arr(Bat|MaxMem)GB"
                    puts $Ouf "#SBATCH --ntasks-per-node=$arr(Bat|MaxCPU)"
                    puts $Ouf "#SBATCH --mail-type=ALL"
                    puts $Ouf "#SBATCH --mail-user=$arr(Bat|Email)\n"
                } elseif {$arr(Bat|Sched) eq "PBS"} {
                    puts $Ouf "#PBS -N pbs"
                    puts $Ouf "#PBS -l walltime=$arr(Bat|MaxTime):00:00"
                    puts $Ouf "#PBS -l mem=$arr(Bat|MaxMem)gb"
                    puts $Ouf "#PBS -l ncpus=$arr(Bat|MaxCPU)"
                    puts $Ouf "#PBS -k oed"
                    puts $Ouf "#PBS -j oe"
                    puts $Ouf "#PBS -m bea"
                    puts $Ouf "#PBS -M $arr(Bat|Email)\n"
                }
            }
            puts $Ouf "STROOT=$arr(Bat|STRoot)"
            puts $Ouf "export STROOT"
            puts $Ouf "STRELEASE=$arr(Bat|STVer)"
            puts $Ouf "export STRELEASE"
            puts $Ouf "STROOT_LIB=$arr(Bat|STRoot)/tcad/current/lib"
            puts $Ouf "export STROOT_LIB"
            puts $Ouf "\[\[ -z \$LM_LICENSE_FILE \]\] && \{"
            puts $Ouf "    LM_LICENSE_FILE=$arr(Bat|STLicn)"
            puts $Ouf "    export LM_LICENSE_FILE\n\}"
            if {$arr(Bat|STSLib) ne ""} {
                if {[info exists ::env(LD_LIBRARY_PATH)]} {
                    set Tmp $::env(LD_LIBRARY_PATH)
                    if {![regexp $arr(Bat|STSLib) $Tmp]} {
                        puts $Ouf "LD_LIBRARY_PATH=$Tmp:$arr(Bat|STSLib)"
                        puts $Ouf "export LD_LIBRARY_PATH"
                    }
                } else {
                    puts $Ouf "LD_LIBRARY_PATH=$arr(Bat|STSLib)"
                    puts $Ouf "export LD_LIBRARY_PATH"
                }
            }
            puts $Ouf "\[\[ -z \$STDB \]\] && \{"
            puts $Ouf "    \[\[ -d ~/STDB \]\] || mkdir ~/STDB"
            puts $Ouf "    STDB=~/STDB && export STDB\n\}\n"
            if {$Elm eq "FSTPP"} {
                if {[llength $arr(Bat|CMILst)]} {
                    puts $Ouf "GCCVer=`\$STROOT/bin/cmi -a\
                        | awk '\{if(NR==4) print \$4\}'`"
                    puts $Ouf "GCCInt=`echo \$GCCVer\
                        | awk -F. '\{print \$1\$2\$3\}'`"
                    puts $Ouf "CMIVer=`\$STROOT/bin/cmi -a\
                        | awk '\{if(NR==20) print \$3\}'`"
                    puts $Ouf "CMIInt=`echo \$CMIVer\
                        | awk -F. '\{print \$1\$2\$3\}'`"
                    puts $Ouf "\[\[ \$CMIInt -gt \$GCCInt \]\] && \{"
                    puts $Ouf "    echo -e \"\\nerror: gcc version '\$GCCVer'\
                        is lower than required '\$CMIVer'!\\n\""
                    puts $Ouf "    exit 1\n\}\n"
                    puts $Ouf "cd $::SimArr(PMIDir)"
                    foreach File $arr(Bat|CMILst) {
                        puts $Ouf "    \$STROOT/bin/cmi -O $File"
                    }
                    puts $Ouf "cd ..\n"
                }
                if {$arr(StartIdx) == 0} {
                    puts $Ouf "\$STROOT/bin/gcleanup -default ."
                    puts $Ouf "\$STROOT/bin/spp -verbose -i ."
                } else {
                    puts $Ouf "\$STROOT/bin/spp -verbose -i ."
                }
            } else {
                puts $Ouf "cd $arr(Bat|STPDir)"
                puts $Ouf "\$STROOT/bin/gsub -verbose -e\
                    \"[join $arr(Tcl|RunNode) +]\" . "
            }
            close $Ouf
            file rename -force $Alias.mfj $Alias

            # Default file permission 'rw', also depending on 'umask' setting
            if {$::tcl_platform(platform) eq "unix"} {
                exec chmod u+x $Alias
            }
        }
        vputs
    }
}

# mfjST::miscTask
proc mfjST::miscTask {} {
    variable arr

    vputs "Performing miscellaneous tasks before launching Sentaurus..."

    # 'swb' needs .project to determine whether it is a swb project
    if {![file isfile .project]} {
        vputs -v5 -i2 "'.project' file not found! Creating..."
        close [open .project w]
    }
    if {$arr(UpdateSWB)} {
        vputs -i1 "Clearing the SWB output variable file 'gvars.dat'..."
        if {[file isfile gvars.dat]} {
            vputs -v5 -i2 "Making a SWB variable file backup\
                'gvars.dat.backup'..."
            file copy -force gvars.dat gvars.dat.backup
        }
        close [open gvars.dat w]
    }

    vputs -i1 "Clearing junk files from the previous run if any..."
    foreach Junk [glob -nocomplain slurm* pbs* n_tclResults_* *_crash_*\
        *.restech.*] {
        file delete $Junk
        vputs -v5 -i2 "'$Junk' deleted"
    }
    if {$arr(StartIdx) == 0} {

        # Remove all old results
        foreach Junk [glob -nocomplain $::SimArr(EtcDir)/n*_*\
            $::SimArr(OutDir)/n*_* *_n*_des.plt] {
            file delete $Junk
            vputs -v5 -i2 "'$Junk' deleted"
        }
    } else {

        # Manually remove unwanted old nodes files and results here
        foreach Node $arr(Bat|RunNode) {
            if {[string is integer -strict $Node]} {
                foreach Junk [glob -nocomplain pp${Node}_* n${Node}_*\
                    *_n${Node}_* $::SimArr(EtcDir)/n${Node}_*\
                    $::SimArr(OutDir)/n${Node}_*] {
                    file delete $Junk
                    vputs -v5 -i2 "'$Junk' deleted"
                }
            }
        }
    }

    vputs -i1 "Disable interactive mode if necessary..."
    foreach Tool $arr(Tcl|STLst) {
        set CmdFile $arr(TclLbl|$Tool)$::SimArr($Tool|Sufx)

        # Skip preference file check for 'sdevice'
        if {$Tool eq "sdevice"} {
            continue
        }
        set PrfFile [file rootname $CmdFile].prf
        if {[file isfile $PrfFile]} {
            set Inf [open $PrfFile r]
            set Buff [read $Inf]
            close $Inf
            set UpdatePrf false
            if {[regsub "interactive" $Buff "batch" Buff]} {
                set UpdatePrf true
            }
            if {$UpdatePrf} {
                vputs -v5 -i2 "Forcing '$PrfFile' to batch model..."
                file copy -force $PrfFile $PrfFile.backup
                set Ouf [open $PrfFile w]
                puts $Ouf $Buff
                close $Ouf
            }
        } else {
            vputs -v5 -i2 "'$PrfFile' not found! Creating..."
            set Ouf [open $PrfFile w]
            puts $Ouf "set WB_tool($Tool,exec_mode) batch"
            if {$Tool eq "sde"} {
                puts $Ouf "set WB_tool(sde,input,grid,user) 1"
                puts $Ouf "set WB_tool(sde,input,boundary,user) 1"
            } elseif {$Tool eq "sprocess"} {
                puts $Ouf "set WB_tool(sprocess,parallel,activate) 1"
            } elseif {$Tool eq "svisual"} {
                puts $Ouf "set WB_tool(svisual,exec_dependency) strict"
                puts $Ouf "set WB_tool(svisual,parallel,activate) 1"
            }
            close $Ouf
        }
    }
    vputs
}

# mfjST::updateDOESum
    # Update ::SimArr(FDOESum) and store a copy of ::SimArr(FVarRaw)-brief.txt
proc mfjST::updateDOESum {} {
    variable arr

    if {$arr(UpdateTcl)} {
        set FDOESum $::SimArr(OutDir)/$::SimArr(FDOESum)
        vputs "Recording Trial nodes and variables in '$FDOESum'..."
        if {[file isfile $FDOESum]} {
            file copy -force $FDOESum $FDOESum.backup
        }
        set Ouf [open $FDOESum w]
        set MaxLen [llength [lindex $arr(Tcl|KeyNode) end]]
        puts $Ouf \n[lindex $arr(DOE|Title) 0]
        puts $Ouf "Trial node,[join [lindex $arr(Tcl|KeyNode) end] ,]"
        puts $Ouf \n[lindex $arr(DOE|Title) 1]
        set Ply 1
        set OldLen 1
        set StrLst [list]
        foreach Var $arr(TclST|VarLst) {
            if {$arr(TclLvl|$Var) > 1} {
                set ValLen $arr(TclLvl|$Var)
                if {[string index $::SimArr(OneChild) 0] ne "!"} {
                    if {$ValLen != $OldLen} {
                        set Ply [expr {$Ply*$ValLen}]
                        set OldLen $ValLen
                    }
                } else {
                    set Ply [expr {$Ply*$ValLen}]
                }
                set Lst $Var
                for {set i 0} {$i < $MaxLen} {incr i} {
                    set Idx [expr {int($i*$Ply/$MaxLen)%$ValLen}]
                    if {$i == 0 || $Idx != int(($i-1)*$Ply/$MaxLen)%$ValLen} {
                        lappend Lst [lindex $arr(TclVal|$Var) $Idx]
                    } else {
                        lappend Lst ""
                    }
                }
                lappend StrLst [join $Lst ,]
            } else {
                set Lst [list $Var $arr(TclVal|$Var)]
                for {set i 1} {$i < $MaxLen} {incr i} {
                    lappend Lst ""
                }
            }
            puts $Ouf [join $Lst ,]
        }
        puts $Ouf \n[lindex $arr(DOE|Title) 2]

        # Also show variables with multiple values in the output section
        if {[llength $StrLst]} {
            puts $Ouf [join $StrLst \n]
        }
        close $Ouf

        set FVarBrf [file rootname $::SimArr(FVarRaw)]-brief.txt
        vputs -i1 "Copying '$FVarBrf' to '$::SimArr(OutDir)'..."
        file copy -force $FVarBrf $::SimArr(OutDir)
        vputs
    }
}

# mfjST::updateStopSWB
proc mfjST::updateStopSWB {} {
    variable arr
}

# mfjST::updateSWB2TXT
proc mfjST::updateSWB2TXT {} {
    variable arr
}

# mfjST::fmt2swb
    # Do all the heavy lifting here by performing many small tasks. Mainly:
    # 1. Translate the formatted file to a Tcl file for inclusion
    # 2. Compare Tcl settings against gtree.dat and batch files
    # 3. Update the preprocess, batch, gtree.dat, gvar.dat files
    # 4. Update all tool related files (command, parameter)
proc mfjST::fmt2swb {} {
    foreach Elm [list validatePath readTcl tclvsFmt updateTcl ReadSWB\
        SWBvsTcl UpdateSWB readBatch batchvsTcl updatePP_Bat\
        updateDOESum miscTask] {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

# mfjST::swb2tcl
#   Translate changes in gtree.dat to the Tcl file only
proc mfjST::swb2tcl {} {
  foreach Elm {ReadSWB readTcl TclvsSWB arrvsSWB updateTcl updateArr} {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

package provide mfjST $mfjST::version