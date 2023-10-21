################################################################################
# This namespace is designed to group procedures for enabling the interaction
# between a variable TXT file and Sentaurus TCAD.
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
################################################################################

package require Tcl 8.4

namespace eval mfjST {
    variable version 2.0

    # Define a big array to handle all data exchange
    variable arr
    array set arr {
        StartIdx -1 Tcl|VarLst "" TclRsvd|VarLst "" TclEnv|VarLst ""
        TclST|VarLst "" Tcl|STLst "" TclWB|STLst "" TclWB|VarLst ""
        TclKeyNode "" TclRunNode "" TclCMILst "" GTr|VarLst "" GTr|STLst ""
        GTreeLine0 "# Copyright (C) 1994-2016 Synopsys Inc."
        GTreeSTVer "" GTreeColMode ColMode GTreeNode4All !Node4All
        BatSTRoot "" BatSTVer "" BatSTLicn "" BatSTLib "" BatSTPDir ""
        BatCMILst "" BatSched "Local" BatMaxTmHr "" BatMaxMemGB "" BatMaxCPU ""
        BatRunNode "" BatEmail "" UpdateArr false
        UpdateTcl false UpdateGTree false UpdateBat false UpdateCMD false
        STDfltID {#if "@tool_label@" eq "(\S+)"}
        DfltSTHead "Tcl environment variables for Sentaurus TCAD"
        DfltGTreeID {{swbtree v(\S+)} "simulation flow" "variables"
            "scenarios and parameter specs" "simulation tree"}
        DfltDOEID {"# Trial node list for output files"
            "# Input variables and values for each trial"
            "# Key input and output variables and values for each trial"}
    }
}

# mfjST::valPath
    # Validate project path according to Sentaurus Workbench User Guide (Ch 2)
    # No characters for path: / \ ~ * ? $ ! " < > : [ ] { } = | ; <tab> <space>
    # No characters for name: , @ # ( ) ' ` + & ^ %
proc mfjST::valPath {} {
    vputs -n "Validating Sentaurus TCAD project full path '[pwd]'... "
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

        # No multiple levels in ::SimArr(FVarEnv)
        set Inf [open $::SimArr(FVarEnv) r]
        set Lines ""
        set LineIdx 0
        set Flg true
        vputs -v3 -i1 "Reserved variables:"
        while {[gets $Inf Line] != -1} {

            # Read lines after reading an empty or comment line
            if {![regexp {\S} $Line] || [regexp {^\s*#} $Line]} {
                if {[llength $Lines] == 3} {
                    set Var [lindex $Lines 1]
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
                    set Val [lindex $Lines 2]
                    set arr(TclVal|$Var) $Val
                    set arr(TclLvl|$Var) 1
                    vputs -v3 -i2 "$Var: \{$arr(TclVal|$Var)\}"
                    set Lines ""
                } elseif {[llength $Lines] > 0} {
                    error "unknown command '$Lines' at line '$LineIdx'!"
                }
            } else {
                append Lines " [string trim $Line]"
            }
            incr LineIdx
        }
        close $Inf

        if {[info exists arr(TclVal|mfjSTLst)]} {
            set arr(Tcl|STLst) $arr(TclVal|mfjSTLst)
        } else {
            error "variable 'mfjSTLst' missing in '$::SimArr(FVarEnv)'!"
        }
        set Idx 0
        set LineIdx 0
        set Lines ""
        set WBFlg true
        set Inf [open $::SimArr(FVarSim) r]
        while {[gets $Inf Line] != -1} {

            # Read lines after reading an empty or comment line
            if {![regexp {\S} $Line] || [regexp {^\s*#} $Line]} {

                # Extract tool label
                if {[regexp {^\s*#} $Line]
                    && [regexp -nocase $arr(STDfltID) $Line -> Lbl]} {
                    set Tool [lindex $arr(Tcl|STLst) $Idx]
                    if {$WBFlg} {
                        if {$Tool eq "sprocess"
                            && [string equal -nocase Process\
                            [lindex $arr(TclVal|SimEnv) 3]]} {
                            set WBFlg false
                        }
                        lappend arr(TclWB|STLst) $Tool
                        set arr(TclWB$Tool|VarLst) [list]
                    }
                    set arr(TclLbl|$Tool) $Lbl
                    set arr(Tcl$Tool|VarLst) [list]
                    vputs -v3 -i1 "ST tool: '$Tool'\tlabel: '$Lbl'"
                    incr Idx
                }
                if {[lindex $Lines 0] eq "set"} {
                    if {[regexp {^(\w+)<(\d+)>$} [lindex $Lines 1]\
                        -> Var Len]} {
                        if {$WBFlg} {
                            lappend arr(TclWB|VarLst) $Var
                            lappend arr(TclWB$Tool|VarLst) $Var
                        }
                        lappend arr(Tcl|VarLst) $Var
                        lappend arr(TclST|VarLst) $Var
                        lappend arr(Tcl$Tool|VarLst) $Var
                        set arr(TclVal|$Var) [lindex $Lines 2]
                        set arr(TclLvl|$Var) $Len
                        vputs -v3 -i2 "$Var<$Len>: '\{$arr(TclVal|$Var)\}'"
                    } else {
                        set Var [lindex $Lines 1]
                        if {$Var ne [lindex $arr(Tcl|VarLst) end]} {
                            lappend arr(Tcl|VarLst) $Var
                            lappend arr(TclST|VarLst) $Var
                            lappend arr(Tcl$Tool|VarLst) $Var
                            set arr(TclVal|$Var) [lindex $Lines 2]
                            set arr(TclLvl|$Var) 1
                            vputs -v3 -i2 "$Var: '\{$arr(TclVal|$Var)\}'"
                        }
                    }
                }
                set Lines ""
            } else {
                append Lines " [string trim $Line]"
            }
            incr LineIdx
        }
        close $Inf
        vputs -v3 -i1 "Found [llength $arr(Tcl|VarLst)] simulation variables!"
    } else {
        vputs -i1 "The variable Tcl file '$::SimArr(FVarEnv)' or\
            '$::SimArr(FVarSim)' not found!"
        set arr(UpdateTcl) true
        set arr(UpdateCMD) true
    }
    vputs
}

# mfjST::readGTree
    # Read gtree.dat and update the following variables in arr:
    # GTreeLine0 GTreeSTVer GTreeColMode GTr|STLst GTreeSTLbl GTreeSWBIdx
    # GTreeSWBName GTreeSWBVal GTreeNode4All UpdateGTree
proc mfjST::readGTree {} {
    variable arr
    vputs "Reading the SWB setting file 'gtree.dat'..."
    if {[file isfile gtree.dat]} {
        set Inf [open gtree.dat r]
        set ReadFlow false
        set ReadVar false
        set ReadScen false
        set ReadTree false

        # Keep the content of the first line
        gets $Inf Line
        set arr(GTreeLine0) $Line
        while {[gets $Inf Line] != -1} {

            # Skip blank lines
            if {![regexp {\S} $Line]} {
                continue
            }
            if {[regexp {^\s*#} $Line]} {

                # Extract Sentaurus TCAD version
                if {$arr(GTreeSTVer) eq ""} {
                    regexp -nocase ^#\\s[lindex $arr(DfltGTreeID) 0] $Line\
                        -> arr(GTreeSTVer)
                }

                # Extract simulation flow
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(DfltGTreeID) 1] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(DfltGTreeID) 1]:"
                    set ReadFlow true
                    set VarIdx 0
                    set VarName [list]
                    set VarVal [list]
                    set IdxLst [list]
                }
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(DfltGTreeID) 2] $Line]} {
                    vputs -v2 -i1 "ST version: '$arr(GTreeSTVer)'"
                    vputs -v2 -i1 "Found [lindex $arr(DfltGTreeID) 2]:"
                    set ReadFlow false
                    set ReadVar true
                    set mfjProc::arr(Indent1) 2
                    set GTree [buildTree $VarName $VarVal $IdxLst ColMode]
                    set mfjProc::arr(Indent1) 0
                    vputs -v2 -i1 "SWB node arrangement for all variables:\
                        '$arr(GTreeNode4All)'"
                }
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(DfltGTreeID) 3] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(DfltGTreeID) 3]:"
                    set ReadVar false
                    set ReadScen true
                }
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(DfltGTreeID) 4] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(DfltGTreeID) 4].\
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
                        set arr(UpdateGTree) true
                        break
                    }

                    # Tools can be distinguished by the empty value
                    if {[lindex $Line 3] eq ""} {
                        if {[regexp {\-rel\s+(\S+)} [lindex $Line 2] -> Tmp]} {
                            set arr(GTreeSTVer) $Tmp
                        }
                        set Tool [lindex $Line 1]
                        lappend arr(GTr|STLst) $Tool
                        set arr(GTrLbl|$Tool) [lindex $Line 0]
                        set arr(GTr$Tool|VarLst) [list]
                        lappend IdxLst $VarIdx
                        vputs -v3 -i2 "ST tool: '$Tool'\tlabel:\
                            '[lindex $Line 0]'"
                    } else {
                        lappend VarName [lindex $Line 1]
                        lappend VarVal [lindex $Line end]
                        set Var [lindex $Line 1]
                        lappend arr(GTr$Tool|VarLst) $Var
                        lappend arr(GTr|VarLst) $Var
                        set arr(GTrLvl|$Var) [llength [lindex $Line end]]

                        # Decode values of swb variables, refer to the rules
                        # set out in 'updateGTree'
                        if {$arr(GTrLvl|$Var) == 1} {
                            set arr(GTreeNode4All) Node4All
                            set Val [lindex $Line end]
                            if {$Val eq "/0"} {
                                set arr(GTrVal|$Var) ""
                            } else {
                                set arr(GTrVal|$Var) [string map\
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
                            set arr(GTrVal|$Var) $Lst
                        }
                        incr VarIdx
                        vputs -v3 -i3 "$Var<$arr(GTrLvl|$Var)>:\
                            \{$arr(GTrVal|$Var)\}"
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
                    set Txt2 [lrange [lindex $GTree $Idx] 0 3]
                    vputs -v3 -o [format "%-39s $Txt2" $Txt1]
                    if {$Txt1 ne $Txt2} {
                        set arr(GTreeColMode) !ColMode
                        break
                    }
                    incr Idx
                }
            }
        }
        close $Inf
        if {$arr(GTr|STLst) eq ""} {
            vputs -i1 "No ST tools found in 'gtree.dat'!"
            set arr(UpdateGTree) true
        }
        if {!$arr(UpdateGTree)} {
            if {[llength $GTree] != $Idx} {
                set arr(GTreeColMode) !ColMode
            }
        }
        vputs -v2 -i1 "SWB variable column combination: $arr(GTreeColMode)"
    } else {
        vputs -i1 "The SWB setting file 'gtree.dat' not found!"
        set arr(UpdateGTree) true
    }
    vputs
}

# mfjST::readBatch
    # ::SimArr(FSTPP) and ::SimArr(FSTBatch) should exist
    # Read settings from ::SimArr(FSTBatch) only and update
    # BatSTRoot BatSTVer BatSTLicn BatEmail BatSched BatPart BatQueue
    # BatMaxTmHr BatMaxMemGB BatRunNode UpdateBat
proc mfjST::readBatch {} {
    variable arr
    vputs "Reading batch file '$::SimArr(FSTBatch)'..."
    if {[file isfile $::SimArr(FSTPP)] && [file isfile $::SimArr(FSTBatch)]} {

        # Extract the previous CMI list
        set Inf [open $::SimArr(FSTPP) r]
        set Buff [read $Inf]
        close $Inf
        regexp cd\\s$::SimArr(PMIDir)(\.+)cd\\s $Buff -> Str

        # Convert the matched string to list
        while {[info exists Str] && [llength $Str]} {
            lappend arr(BatCMILst) [lindex $Str 2]
            set Str [lrange $Str 3 end]
        }

        set Inf [open $::SimArr(FSTBatch) r]
        while {[gets $Inf Line] != -1} {
            if {[regexp ^# $Line]} {
                if {[regexp {\#SBATCH} $Line]} {
                    set arr(BatSched) SLURM

                    # '-' needs to be escaped to avoid interpretation as switch
                    if {[regexp {\-\-time=(\d+):00:00} $Line\
                        -> arr(BatMaxTmHr)]} {
                        vputs -v3 -i1 "Job scheduler: $arr(BatSched)"
                        vputs -v3 -i1 "Maximum walltime: $arr(BatMaxTmHr) hrs"
                    }
                    if {[regexp {\-\-mem=(\d+)GB} $Line\
                        -> arr(BatMaxMemGB)]} {
                        vputs -v3 -i1 "Maximum memory: $arr(BatMaxMemGB) GB"
                    }
                    if {[regexp {\-\-ntasks-per-node=(\d+)} $Line\
                        -> arr(BatMaxCPU)]} {
                        vputs -v3 -i1 "Maximum CPUs: $arr(BatMaxCPU)"
                    }
                    if {[regexp {\-\-mail-user=(\S+)} $Line\
                        -> arr(BatEmail)]} {
                        vputs -v3 -i1 "Email: $arr(BatEmail)"
                    }
                }
                if {[regexp {\#PBS} $Line]} {
                    set arr(BatSched) PBS
                    if {[regexp {\-l walltime=(\d+):00:00} $Line\
                        -> arr(BatMaxTmHr)]} {
                        vputs -v3 -i1 "Job scheduler: $arr(BatSched)"
                        vputs -v3 -i1 "Maximum walltime: $arr(BatMaxTmHr) hrs"
                    }
                    if {[regexp {\-l mem=(\d+)gb} $Line\
                        -> arr(BatMaxMemGB)]} {
                        vputs -v3 -i1 "Maximum memory: $arr(BatMaxMemGB) GB"
                    }
                    if {[regexp {\-l ncpus=(\d+)} $Line -> arr(BatMaxCPU)]} {
                        vputs -v3 -i1 "Maximum CPUs: $arr(BatMaxCPU)"
                    }
                    if {[regexp {\-M (\S+)} $Line -> arr(BatEmail)]} {
                        vputs -v3 -i1 "Email: $arr(BatEmail)"
                    }
                }
            } else {
                if {[regexp {^STROOT=(\S+)} $Line -> arr(BatSTRoot)]} {
                    vputs -v3 -i1 "Sentaurus root: $arr(BatSTRoot)"
                }
                if {[regexp {^STRELEASE=(\S+)} $Line -> arr(BatSTVer)]} {
                    vputs -v3 -i1 "Sentaurus version: $arr(BatSTVer)"
                }
                if {[regexp {^\s+LM_LICENSE_FILE=(\S+)} $Line\
                    -> arr(BatSTLicn)]} {
                    vputs -v3 -i1 "Sentaurus license: $arr(BatSTLicn)"
                }
                if {[regexp {^\s+LD_LIBRARY_PATH=(\S+)} $Line\
                    -> arr(BatSTLib)]} {
                    vputs -v3 -i1 "Sentaurus shared libraries: $arr(BatSTLib)"
                }
                if {[regexp {^cd\s+(\S+)$} $Line -> arr(BatSTPDir)]} {
                    vputs -v3 -i1 "Sentaurus project dirctory: $arr(BatSTPDir)"
                }
                if {[regexp {^\$STROOT/bin/gsub -verbose -e \"(\S+)\"} $Line\
                    -> arr(BatRunNode)]} {
                    set arr(BatRunNode) [split $arr(BatRunNode) +]
                    vputs -v3 -i1 "SWB node list: $arr(BatRunNode)"
                }
            }
        }
        close $Inf
        if {$arr(BatSched) eq "Local"} {
            vputs -v3 -i1 "Job scheduler: N/A"
        }
    } else {
        vputs -i1 "Batch file '$::SimArr(FSTBatch)' not found!"
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
        set arr(TclWB|STLst) [list]
        set arr(TclWB|VarLst) [list]
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
                lappend arr(TclWB|STLst) $Tool
                set arr(TclWB$Tool|VarLst) [list]
                foreach Var $arr(Tcl$Tool|VarLst) {

                    # SWB variables: 1) Node4All is true; 2) Level > 1
                    if {$arr(TclLvl|$Var) == 1
                        && [string index $::SimArr(Node4All) 0] ne "!"
                        || $arr(TclLvl|$Var) > 1} {
                        lappend arr(TclWB$Tool|VarLst) $Var
                        lappend arr(TclWB|VarLst) $Var
                    }
                }
            }
        }
    }
}

# mfjST::gtreevsTcl
    # Compare gtree.dat against the updated ::SimArr(FVarSim) and set
    # arr(UpdateGTree) to be true if there is any difference
proc mfjST::gtreevsTcl {} {
    variable arr

    if {!$arr(UpdateGTree)} {
        vputs "Comparing 'gtree.dat' against '$::SimArr(FVarSim)'..."
        set Msg "'gtree.dat' is different from '$::SimArr(FVarSim)'!"
        if {$arr(GTreeColMode) ne $::SimArr(ColMode)} {
            if {!$arr(UpdateGTree)} {
                set arr(UpdateGTree) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB variable column combination '$arr(GTreeColMode)'\
                different from '$::SimArr(ColMode)'!"
        }
        if {$arr(GTreeSTVer) ne [lindex $arr(TclVal|SimEnv) 1]} {
            if {!$arr(UpdateGTree)} {
                set arr(UpdateGTree) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus TCAD version '$arr(GTreeSTVer)' different\
                from '[lindex $arr(TclVal|SimEnv) 1]'!"
        }
        if {$arr(GTreeNode4All) ne $::SimArr(Node4All)} {
            if {!$arr(UpdateGTree)} {
                set arr(UpdateGTree) true
                vputs -i1 $Msg
            }
            set Msg "SWB node arrangement for all variables\
                '$arr(GTreeNode4All)' different from '$::SimArr(Node4All)'!"
        }

        # Check SWB tools and variables. Tools should have the same sequence
        if {$arr(GTr|STLst) ne $arr(TclWB|STLst)} {
            if {!$arr(UpdateGTree)} {
                set arr(UpdateGTree) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB tools '$arr(GTr|STLst)' different from\
                '$arr(TclWB|STLst)'!"
        }
        foreach Tool $arr(GTr|STLst) {
            if {$arr(GTrLbl|$Tool) ne $arr(TclLbl|$Tool)} {
                if {!$arr(UpdateGTree)} {
                    set arr(UpdateGTree) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "SWB tool label '$arr(GTrLbl|$Tool)' different\
                    from '$arr(TclLbl|$Tool)'!"
            }

            # Variables for a tool may have a different sequence
            foreach Var $arr(GTr$Tool|VarLst) {
                if {[lsearch -exact $arr(TclWB$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateGTree)} {
                        set arr(UpdateGTree) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool'\
                        removed!"
                    continue
                }
                if {$arr(GTrVal|$Var) ne $arr(TclVal|$Var)} {
                    if {!$arr(UpdateGTree)} {
                        set arr(UpdateGTree) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' has a value of\
                        '$arr(GTrVal|$Var)' different from '$arr(TclVal|$Var)'!"
                }
            }
            foreach Var $arr(TclWB$Tool|VarLst) {
                if {[lsearch -exact $arr(GTr$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateGTree)} {
                        set arr(UpdateGTree) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool' added!"
                }
            }
        }
        if {$arr(UpdateGTree)} {
            set arr(StartIdx) 0
            vputs -v2 -i2 "ST starting tool index: '$arr(StartIdx)'"
        } else {
            vputs -i1 "'gtree.dat' is the same as '$::SimArr(FVarSim)'!"
        }
        vputs
    }
    if {$arr(UpdateGTree)} {

        # Perform an efficient update of all related variables
        set arr(StartIdx) 0
        set arr(GTreeSTVer) [lindex $arr(TclVal|SimEnv) 1]
        set arr(GTreeNode4All) $::SimArr(Node4All)
        set arr(GTreeColMode) $::SimArr(ColMode)
        set arr(GTr|STLst) $arr(TclWB|STLst)
        set arr(GTr|VarLst) $arr(TclWB|VarLst)
        foreach Tool $arr(GTr|STLst) {
            set arr(GTrLbl|$Tool) $arr(TclLbl|$Tool)
            set arr(GTr$Tool|VarLst) $arr(TclWB$Tool|VarLst)
            foreach Var $arr(GTr$Tool|VarLst) {
                set arr(GTrVal|$Var) $arr(TclVal|$Var)
                set arr(GTrLvl|$Var) $arr(TclLvl|$Var)
            }
        }
    }
}

# mfjST::tclvsGtree
    # Compare ::SimArr(FVarEnv) and ::SimArr(FVarSim) against gtree.dat and
    # set arr(UpdateTcl) to be true if there is any difference
proc mfjST::tclvsGtree {} {
    variable arr

    # Assumption: Changes in Sentaurus workbench are related to workbench
    # variables.
    if {!$arr(UpdateTcl)} {
        vputs "Comparing '$::SimArr(FVarSim)' against 'gtree.dat'..."

        # Check ST Tools and variables. Tools should have the same sequence
        set Msg "'$::SimArr(FVarSim)' is different from 'gtree.dat'!"
        if {$arr(TclWB|STLst) ne $arr(GTr|STLst)} {
            if {!$arr(UpdateTcl)} {
                set arr(UpdateTcl) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB tools '$arr(TclWB|STLst)' different from\
                '$arr(GTr|STLst)'!"
        }
        foreach Tool $arr(TclWB|STLst) {
            if {$arr(GTrLbl|$Tool) ne $arr(TclLbl|$Tool)} {
                if {!$arr(UpdateTcl)} {
                    set arr(UpdateTcl) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "SWB tool label '$arr(TclLbl|$Tool)' different\
                    from '$arr(GTrLbl|$Tool)'!"
            }

            # Variables for a tool may have a different sequence
            foreach Var $arr(TclWB$Tool|VarLst) {
                if {[lsearch -exact $arr(GTr$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool'\
                        removed!"
                    continue
                }
                if {$arr(GTrVal|$Var) ne $arr(TclVal|$Var)} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' has a value of\
                        '$arr(TclVal|$Var)' different from '$arr(GTrVal|$Var)'!"
                }
            }
            foreach Var $arr(GTr$Tool|VarLst) {
                if {[lsearch -exact $arr(TclWB$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateTcl)} {
                        set arr(UpdateTcl) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool' added!"
                }
            }
        }
        if {!$arr(UpdateTcl)} {
            vputs -i1 "'$::SimArr(FVarSim)' is the same as 'gtree.dat'!"
        }
        vputs
    }
    if {$arr(UpdateTcl)} {

        vputs -v3 -i1 "Perform a smart update of Tcl related variables"
        set arr(TclWB|STLst) $arr(GTr|STLst)
        set VarLst [list]
        foreach Tool $arr(TclWB|STLst) {
            set arr(TclLbl|$Tool) $arr(GTrLbl|$Tool)
            set arr(Tcl$Tool|VarLst) $arr(GTr$Tool|VarLst)
            set VarLst [concat $VarLst $arr(Tcl$Tool|VarLst)]
            foreach Var $arr(Tcl$Tool|VarLst) {
                set arr(TclVal|$Var) $arr(GTrVal|$Var)
                set arr(TclLvl|$Var) $arr(GTrLvl|$Var)
            }
        }
        set Len [llength $arr(TclWB|STLst)]
        set arr(Tcl|STLst) [concat $arr(TclWB|STLst)\
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
}

# mfjST::arrvsGtree
    # Compare ::SimArr against gtree.dat and set arr(UpdateArr) to be true
    # if there is any difference
proc mfjST::arrvsGtree {} {
    variable arr

    if {!$arr(UpdateArr)} {
        vputs "Comparing '::SimArr' against 'gtree.dat'..."
        set Msg "'::SimArr' is different from 'gtree.dat'!"
        if {$::SimArr(ColMode) ne $arr(GTreeColMode)} {
            if {!$arr(UpdateArr)} {
                set arr(UpdateArr) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB variable combination '$::SimArr(ColMode)'\
                different from '$arr(GTreeColMode)'!"
            set ::SimArr(ColMode) $arr(GTreeColMode)
        }
        if {$::SimArr(Node4All) ne $arr(GTreeNode4All)} {
            if {!$arr(UpdateArr)} {
                set arr(UpdateArr) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB node arrangement for all variables\
                '$::SimArr(Node4All)' different from '$arr(GTreeNode4All)'!"
            set ::SimArr(Node4All) $arr(GTreeNode4All)
        }

        # Go through each SWB variable and update the case in ::SimArr(VarName)
        foreach Var $arr(GTr|VarLst) {

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
    # Update TclKeyNode and set arr(UpdateBat) to be true if there is any
    # difference
proc mfjST::batchvsTcl {} {
    variable arr

    # Update arr(TclKeyNode), arr(TclRunNode) and arr(TclCMILst)
    set VarName [list]
    set VarVal [list]
    set IdxLst [list]
    set VarIdx 0
    foreach Tool $arr(TclWB|STLst) {
        lappend IdxLst $VarIdx
        foreach Var $arr(TclWB$Tool|VarLst) {
            lappend VarName $Var
            lappend VarVal $arr(TclVal|$Var)
            incr VarIdx
        }
    }
    set arr(TclKeyNode) [buildTree $VarName $VarVal $IdxLst\
        $::SimArr(ColMode) !NodeTree]
    if {$arr(UpdateTcl)} {
        if {$arr(StartIdx) == 0} {
            set arr(TclRunNode) all
        } else {
            set arr(TclRunNode) [string map {\{ ""  \} ""}\
                [lrange $arr(TclKeyNode) $arr(StartIdx) end]]
        }
    } else {
        set arr(TclRunNode) remaining
    }
    foreach Elm $arr(TclVal|mfjModTime) {
        if {[regexp {(\w+)\.[cC]$} [lindex $Elm 0] -> Root]} {
            if {[glob -nocomplain $::SimArr(PMIDir)/$Root.so.*] eq ""} {
                lappend arr(TclCMILst) [file tail [lindex $Elm 0]]
            }
        }
    }
    set STROOT [lsearch -inline -regexp [glob -nocomplain -directory\
        $mfjIntrpr::arr(Host|STPath) *] (?i)[lindex $arr(TclVal|SimEnv) 1]$]

    if {!$arr(UpdateBat)} {
        vputs "Comparing '$::SimArr(FSTBatch)' against\
            '$::SimArr(FVarEnv)', '$::SimArr(FVarSim)' and the host..."
        set Msg "'$::SimArr(FSTBatch)' is different from '$::SimArr(FVarEnv)'!"
        if {$arr(BatSTVer) ne [lindex $arr(TclVal|SimEnv) 1]} {

            # Sentaurus related variables are case-sensitive
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus version '$arr(BatSTVer)' different\
                from '[lindex $arr(TclVal|SimEnv) 1]'!"
        }
        if {$arr(BatSTRoot) ne $STROOT} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus root '$arr(BatSTRoot)' different\
                from '$STROOT'!"
        }

        # SLURM partition or PBS queue is case sensitive
        if {$arr(BatSched) ne [lindex $arr(TclVal|SimEnv) 4]} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Job scheduler '$arr(BatSched)' different\
                from '[lindex $arr(TclVal|SimEnv) 4]'!"

        }
        if {$arr(BatSched) ne "Local"} {
            if {$arr(BatMaxTmHr) != [lindex $arr(TclVal|SimEnv) 5]} {
                if {!$arr(UpdateBat)} {
                    set arr(UpdateBat) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Maximum walltime '$arr(BatMaxTmHr)' hrs\
                    different from '[lindex $arr(TclVal|SimEnv) 5]'!"
            }
            if {$arr(BatMaxMemGB) != [lindex $arr(TclVal|SimEnv) 6]} {
                if {!$arr(UpdateBat)} {
                    set arr(UpdateBat) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Maximum memory '$arr(BatMaxMemGB)' GB\
                    different from '[lindex $arr(TclVal|SimEnv) 6]'!"
            }
            if {$arr(BatMaxCPU) != [lindex $arr(TclVal|SimEnv) 7]} {
                if {!$arr(UpdateBat)} {
                    set arr(UpdateBat) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Maximum CPUs '$arr(BatMaxCPU)'\
                    different from '[lindex $arr(TclVal|SimEnv) 7]'!"
            }
        }

        set Msg "'$::SimArr(FSTBatch)' is different from the host!"
        if {$arr(BatSTLicn) ne $mfjIntrpr::arr(Host|STLicn)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus license '$arr(BatSTLicn)' different\
                from '$mfjIntrpr::arr(Host|STLicn)'!"
        }
        if {$arr(BatSTLib) ne $mfjIntrpr::arr(Host|STLib)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus shared libraries '$arr(BatSTLib)'\
                different from '$mfjIntrpr::arr(Host|STLib)'!"
        }
        if {$arr(BatSched) ne "Local"
            && $arr(BatEmail) ne $mfjIntrpr::arr(Host|Email)} {

            # Case sensitive
            set arr(UpdateBat) true
            set Msg "Email '$arr(BatEmail)' different\
                from '$mfjIntrpr::arr(Host|Email)'!"
        }
        if {$arr(BatSTPDir) ne [pwd]} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "Sentaurus project directory '$arr(BatSTPDir)'\
                different from '[pwd]'!"
        }

        set Msg "'$::SimArr(FSTBatch)' is different from '$::SimArr(FVarSim)'!"
        if {$arr(BatRunNode) ne $arr(TclRunNode)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "SWB to run nodes '$arr(BatRunNode)' different\
                from '$arr(TclRunNode)'!"
        }
        if {$arr(BatCMILst) ne $arr(TclCMILst)} {
            if {!$arr(UpdateBat)} {
                set arr(UpdateBat) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "CMI list '$arr(BatCMILst)' different\
                from '$arr(TclCMILst)'!"
        }
        if {!$arr(UpdateBat)} {
            vputs -i1 "'$::SimArr(FSTBatch)' is the same as\
                '$::SimArr(FVarEnv)', '$::SimArr(FVarSim)' and the host!"
        }
        vputs
    }
    if {$arr(UpdateBat)} {
        set arr(BatSTVer) [lindex $arr(TclVal|SimEnv) 1]
        set arr(BatSched) [lindex $arr(TclVal|SimEnv) 4]
        set arr(BatMaxTmHr) [lindex $arr(TclVal|SimEnv) 5]
        set arr(BatMaxMemGB) [lindex $arr(TclVal|SimEnv) 6]
        set arr(BatMaxCPU) [lindex $arr(TclVal|SimEnv) 7]
        set arr(BatSTRoot) $STROOT
        set arr(BatEmail) $mfjIntrpr::arr(Host|Email)
        set arr(BatSTLicn) $mfjIntrpr::arr(Host|STLicn)
        set arr(BatSTLib) $mfjIntrpr::arr(Host|STLib)
        set arr(BatSTPDir) [pwd]
        set arr(BatRunNode) $arr(TclRunNode)
        set arr(BatCMILst) $arr(TclCMILst)
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
        puts $Ouf "$::SimArr(Prefix) $arr(DfltSTHead)\n"

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
            vputs -v5 -i1 "Making a Tcl file backup\
                '$::SimArr(FVarSim).backup'..."
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
        set Ptn [string map {(\\S+) %s} $arr(STDfltID)]
        set STIdx 0
        foreach Tool $arr(Tcl|STLst) {
            if {$STIdx} {
                puts $Ouf "#endif\n"
            }
            puts $Ouf [format $Ptn\n $arr(TclLbl|$Tool)]
            foreach Var $arr(Tcl$Tool|VarLst) {
                if {$arr(TclLvl|$Var) == 1
                    && [string index $::SimArr(Node4All) 0] eq "!"} {
                    puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n"\
                        $Var $arr(TclVal|$Var)] $Tab]
                }

                # SWB variables: 1) Node4All is true; 2) Level > 1
                if {$arr(TclLvl|$Var) == 1
                    && [string index $::SimArr(Node4All) 0] ne "!"
                    || $arr(TclLvl|$Var) > 1} {
                    puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n"\
                        $Var<$arr(TclLvl|$Var)> $arr(TclVal|$Var)] $Tab]

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
    # Update keys ColMode, Node4All, and VarName in ::SimArr if
    # arr(UpdateArr) is true
proc mfjST::updateArr {} {
    variable arr
    if {$arr(UpdateArr)} {
        vputs "Updating keys ColMode, Node4All, and VarName in ::SimArr..."
        if {![file isfile 11ctrlsim.tcl]} {
            error "'11ctrlsim.tcl' missing in directory '[file tail [pwd]]'!"
        }
        file copy -force 11ctrlsim.tcl 11ctrlsim.tcl.backup
        set Inf [open 11ctrlsim.tcl r]
        set Str [read $Inf]
        close $Inf

        foreach Elm {ColMode Node4All} {
            regsub $Elm\\s+\\S+ $Str "$Elm $::SimArr($Elm)" Str
        }
        regsub {VarName\s+\{[^\}]+\}} $Str\
            "VarName \{$::SimArr(VarName)\}" Str

        set Ouf [open 11ctrlsim.tcl w]
        puts -nonewline $Ouf $Str
        close $Ouf
        vputs
    }
}

# mfjST::updateGTree
    # If arr(UpdateGTree) is true, update the SWB setting file 'gtree.dat'
    # with arr(GTreeLine0) arr(GTreeColMode) arr(GTreeSTVer) arr(GTreeNode4All)
    # arr(GTreeSWBName) arr(GTreeSWBVal) arr(GTreeSTLbl) arr(GTr|STLst)
proc mfjST::updateGTree {} {
    variable arr

    if {$arr(UpdateGTree)} {
        vputs "Updating the SWB setting file 'gtree.dat'..."
        if {[file isfile gtree.dat]} {
            vputs -v5 -i1 "Making a SWB setting file backup\
                'gtree.dat.backup'..."
            file copy -force gtree.dat gtree.dat.backup
        }

        vputs -v2 -i1 "Writing the file head..."
        set Ouf [open .mfj/gtree.dat.mfj w]
        set Tm [clock format [clock seconds] -format "%a %b %d %H:%M:%S %Y" ]
        puts $Ouf "# $Tm, generated by '[file tail [info script]]'"
        set Ptn [string map {(\\S+) %s} [lindex $arr(DfltGTreeID) 0]]
        puts $Ouf [format "# $Ptn" $arr(GTreeSTVer)]
        if {[string index $arr(GTreeNode4All) 0] ne "!"} {
            puts $Ouf "# Node arrangement for all variables"
        } else {
            puts $Ouf "# Node arrangement for multiple-level variables"
        }
        if {[string index $arr(GTreeColMode) 0] ne "!"} {
            puts $Ouf "# Node tree combination: Column mode"
        } else {
            puts $Ouf "# Node tree combination: Full combination"
        }

        vputs -v2 -i1 "Writing [lindex $arr(DfltGTreeID) 1]..."
        puts $Ouf "\n$::SimArr(Prefix) [lindex $arr(DfltGTreeID) 1]"
        set VarIdx 0
        set VarName [list]
        set VarVal [list]
        set IdxLst [list]
        foreach Tool $arr(GTr|STLst) {
            set Lbl $arr(GTrLbl|$Tool)
            puts $Ouf "$Lbl $Tool \"-rel [lindex $arr(TclVal|SimEnv) 1]\" {}"
            lappend IdxLst $VarIdx
            foreach Var $arr(GTr$Tool|VarLst) {
                lappend VarName $Var

                # swb allowed characters: \w.:+/*-
                # swb can display illegal characters like [](){}<>
                # To renounce illegal characters, follow the rules below:
                # '*:' denotes '{', ':*' denotes '}', '::' denotes ' '
                # If a variable value is an empty string, replace it with '/0'
                if {$arr(GTrLvl|$Var) > 1} {
                    set Lst [list]
                    foreach Elm $arr(GTrVal|$Var) {
                        if {$Elm eq ""} {
                            lappend Lst /0
                        } else {
                            lappend Lst [string map {\{ *: \} :* " " ::} $Elm]
                        }
                    }
                    lappend VarVal $Lst
                    puts $Ouf "$Lbl $Var \"$arr(GTrLvl|$Var)\" \{$Lst\}"
                } else {
                    if {$arr(GTrVal|$Var) eq ""} {
                        set Val /0
                    } else {
                        set Val [string map {\{ *: \} :* " " ::}\
                            $arr(GTrVal|$Var)]
                    }
                    puts $Ouf "$Lbl $Var \"1\" \{$Val\}"
                    lappend VarVal $Val
                }
                incr VarIdx
            }
        }

        vputs -v2 -i1 "Writing [lindex $arr(DfltGTreeID) 2]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(DfltGTreeID) 2]"
        vputs -v2 -i1 "Writing [lindex $arr(DfltGTreeID) 3]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(DfltGTreeID) 3]"
        foreach Var $arr(GTr|VarLst) {
            puts $Ouf "scenario default $Var \"\""
        }

        vputs -v2 -i1 "Writing [lindex $arr(DfltGTreeID) 4]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(DfltGTreeID) 4]"
        set mfjProc::arr(Indent1) 2
        foreach Elm [buildTree $VarName $VarVal $IdxLst $arr(GTreeColMode)] {
            puts $Ouf $Elm
        }
        set mfjProc::arr(Indent1) 0
        close $Ouf
        file rename -force .mfj/gtree.dat.mfj gtree.dat
        vputs
    }
}

# mfjST::updateCMD
    # Replace SWB variables with Tcl variables in all command files
proc mfjST::updateCMD {} {
    variable arr


    if {$arr(UpdateCMD)} {

    }
}

# mfjST::updatePP_Bat
    # If arr(UpdateBat) is true, update pre-processing file and batch file
    # with arr(BatSched) arr(BatPart) arr(BatQueue) arr(BatEmail)
    # arr(BatMaxTmHr) arr(BatMaxMemGB) arr(BatSTVer) arr(BatSTRoot)
    # arr(BatSTLicn) arr(TclKeyNode)
    # arr(BatRunNode) keeps its original value for miscTask
proc mfjST::updatePP_Bat {} {
    variable arr

    if {$arr(UpdateBat)} {
        vputs "Updating '$::SimArr(FSTPP)' and '$::SimArr(FSTBatch)'..."
        foreach Elm [list FSTPP FSTBatch] {
            if {[file exists $::SimArr($Elm)]} {

                # 'file copy' overwrites file permission, different from 'cp'
                file copy -force $::SimArr($Elm) $::SimArr($Elm).backup
                exec chmod u-x $::SimArr($Elm).backup
            }
            set Ouf [open $::SimArr($Elm).mfj w]
            puts $Ouf "#!/bin/bash\n"
            if {$Elm eq "FSTBatch"} {
                if {$arr(BatSched) eq "SLURM"} {
                    puts $Ouf "#SBATCH --time=$arr(BatMaxTmHr):00:00"
                    puts $Ouf "#SBATCH --mem=$arr(BatMaxMemGB)GB"
                    puts $Ouf "#SBATCH --ntasks-per-node=$arr(BatMaxCPU)"
                    puts $Ouf "#SBATCH --mail-type=ALL"
                    puts $Ouf "#SBATCH --mail-user=$arr(BatEmail)\n"
                } elseif {$arr(BatSched) eq "PBS"} {
                    puts $Ouf "#PBS -N pbs"
                    puts $Ouf "#PBS -l walltime=$arr(BatMaxTmHr):00:00"
                    puts $Ouf "#PBS -l mem=$arr(BatMaxMemGB)gb"
                    puts $Ouf "#PBS -l ncpus=$arr(BatMaxCPU)"
                    puts $Ouf "#PBS -k oed"
                    puts $Ouf "#PBS -j oe"
                    puts $Ouf "#PBS -m bea"
                    puts $Ouf "#PBS -M $arr(BatEmail)\n"
                }
            }
            puts $Ouf "STROOT=$arr(BatSTRoot)"
            puts $Ouf "export STROOT"
            puts $Ouf "STRELEASE=$arr(BatSTVer)"
            puts $Ouf "export STRELEASE"
            puts $Ouf "STROOT_LIB=$arr(BatSTRoot)/tcad/current/lib"
            puts $Ouf "export STROOT_LIB"
            puts $Ouf "\[\[ -z \$LM_LICENSE_FILE \]\] && \{"
            puts $Ouf "    LM_LICENSE_FILE=$arr(BatSTLicn)"
            puts $Ouf "    export LM_LICENSE_FILE\n\}"
            if {$arr(BatSTLib) ne ""} {
                if {[info exists ::env(LD_LIBRARY_PATH)]} {
                    set Tmp $::env(LD_LIBRARY_PATH)
                    if {![regexp $arr(BatSTLib) $Tmp]} {
                        puts $Ouf "LD_LIBRARY_PATH=$Tmp:$arr(BatSTLib)"
                        puts $Ouf "export LD_LIBRARY_PATH"
                    }
                } else {
                    puts $Ouf "LD_LIBRARY_PATH=$arr(BatSTLib)"
                    puts $Ouf "export LD_LIBRARY_PATH"
                }
            }
            puts $Ouf "\[\[ -z \$STDB \]\] && \{"
            puts $Ouf "    \[\[ -d ~/STDB \]\] || mkdir ~/STDB"
            puts $Ouf "    STDB=~/STDB && export STDB\n\}\n"
            if {$Elm eq "FSTPP"} {
                if {[llength $arr(BatCMILst)]} {
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
                    foreach File $arr(BatCMILst) {
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
                puts $Ouf "cd $arr(BatSTPDir)"
                puts $Ouf "\$STROOT/bin/gsub -verbose -e\
                    \"[join $arr(TclRunNode) +]\" . "
            }
            close $Ouf
            file rename -force $::SimArr($Elm).mfj $::SimArr($Elm)

            # Default file permission 'rw', also depending on 'umask' setting
            exec chmod u+x $::SimArr($Elm)
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
    if {$arr(UpdateGTree)} {
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
        foreach Node $arr(BatRunNode) {
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

    vputs -i1 "Check command files and disable interactive mode if necessary..."
    foreach Tool $arr(Tcl|STLst) {
        set Idx [lsearch -exact $::SimArr(STTools) $Tool]
        set Suf [lindex $::SimArr(STSuffix) $Idx]
        set CmdFile $arr(TclLbl|$Tool)$Suf
        if {![file isfile $CmdFile]} {
            error "command file $CmdFile missing!"
        }

        # Check sdevice.par and skip preference file check for 'sdevice'
        if {$Tool eq "sdevice"} {
            if {![file isfile sdevice.par]} {
                error "parameter file sdevice.par missing!"
            }
            continue
        }
        set PrfFile $arr(TclLbl|$Tool)[file rootname $Suf].prf
        if {[file isfile $PrfFile]} {
            set Inf [open $PrfFile r]
            set UpdatePrf false
            set Lines [list]
            while {[gets $Inf Line] != -1} {
                if {[regsub "interactive" $Line "batch" Line]} {
                    set UpdatePrf true
                }
                lappend Lines $Line
            }
            close $Inf
            if {$UpdatePrf} {
                vputs -v5 -i2 "Forcing '$PrfFile' to batch model..."
                file copy -force $PrfFile $PrfFile.backup
                set Ouf [open $PrfFile w]
                foreach Line $Lines {
                    puts $Ouf $Line
                }
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
    # Update ::SimArr(FDOESum) and store a copy of ::SimArr(FVarRaw)]-brief.txt
proc mfjST::updateDOESum {} {
    variable arr

    if {$arr(UpdateTcl)} {
        vputs "Recording Trial nodes and variables in\
            '$::SimArr(OutDir)/$::SimArr(FDOESum)'..."
        if {[file isfile $::SimArr(OutDir)/$::SimArr(FDOESum)]} {
            file copy -force $::SimArr(OutDir)/$::SimArr(FDOESum)\
                $::SimArr(OutDir)/$::SimArr(FDOESum).backup
        }
        set Ouf [open $::SimArr(OutDir)/$::SimArr(FDOESum) w]
        set MaxLen [llength [lindex $arr(TclKeyNode) end]]
        puts $Ouf \n[lindex $arr(DfltDOEID) 0]
        puts $Ouf "Trial node,[join [lindex $arr(TclKeyNode) end] ,]"
        puts $Ouf \n[lindex $arr(DfltDOEID) 1]
        set Ply 1
        set OldLen 1
        set StrLst [list]
        foreach Var $arr(TclST|VarLst) {
            if {$arr(TclLvl|$Var) > 1} {
                set ValLen $arr(TclLvl|$Var)
                if {[string index $::SimArr(ColMode) 0] ne "!"} {
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
        puts $Ouf \n[lindex $arr(DfltDOEID) 2]

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
    # 3. Update the preprocess, batch, gtree.dat, GVar,  files
    # 4. Update all tool related files (command, parameter)
proc mfjST::fmt2swb {} {
    foreach Elm [list valPath readTcl tclvsFmt updateTcl readGTree\
        gtreevsTcl updateGTree readBatch batchvsTcl updatePP_Bat\
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
  foreach Elm {readGTree readTcl tclvsGtree arrvsGtree updateTcl updateArr} {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

package provide mfjST $mfjST::version
