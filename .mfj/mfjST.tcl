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
        StartIdx 0 TCLSimEnv "" TCLDfltSet "" TCLModTime "" TCLRegInfo ""
        TCLSTName "" TCLSTLbl "" TCLSTIdx "" TCLCMILst ""
        TCLVarName "" TCLVarVal ""
        TCLSWBIdx "" TCLSWBName "" TCLSWBVal "" TCLKeyNode "" TCLRunNode ""
        GTreeSTName "" GTreeSTLbl ""
        GTreeSWBIdx "" GTreeSWBName "" GTreeSWBVal ""
        GTreeLine0 "# Copyright (C) 1994-2016 Synopsys Inc."
        GTreeSTVer "" GTreeColMode ColMode GTreeNode4All !Node4All
        BatSTRoot "" BatSTVer "" BatSTLicn "" BatSTLib "" BatSTPDir ""
        BatCMILst "" BatSched "Local" BatMaxTmHr "" BatMaxMemGB ""
        BatRunNode "" BatEmail "" UpdateArr false
        UpdateTCL false UpdateGTree false UpdateBat false UpdateCMD false
        STDfltID {#if "@tool_label@" eq "(\S+)"}
        DfltSTHead "TCL environment variables for Sentaurus TCAD"
        DfltGTreeID {{swbtree v(\S+),} "simulation flow" "variables"
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

# mfjST::readTCL
    # Read ::SimArr(FVarSim) and ::SimArr(FVarEnv) and update the following
    # variables in arr:
    # TCLSimEnv TCLSTName TCLSTLbl TCLSTIdx TCLVarName TCLVarVal
    # TCLSWBName TCLSWBVal UpdateTCL
proc mfjST::readTCL {} {
    variable arr
    vputs "Reading the variable TCL files '$::SimArr(FVarEnv)' and\
        '$::SimArr(FVarSim)'..."
    if {[file isfile $::SimArr(FVarEnv)] && [file isfile $::SimArr(FVarSim)]} {
        set Inf [open $::SimArr(FVarEnv) r]
        set Lines ""
        vputs -v3 -i1 "Environment variables:"
        while {[gets $Inf Line] != -1} {

            # Read lines after reading an empty or comment line
            if {(![regexp {\S} $Line] || [string index $Line 0] eq "#")
                && [string length $Lines]} {
                if {[regexp {^mfj(DfltSet|ModTime|RegInfo|STName)$}\
                    [lindex $Lines 1] -> Var]} {
                    set arr(TCL$Var) [lindex $Lines 2]
                    vputs -v3 -i2 "arr(TCL$Var): \{$arr(TCL$Var)\}"
                } elseif {[lindex $Lines 1] eq "SimEnv"} {
                    set arr(TCLSimEnv) [lindex $Lines 2]
                    vputs -v3 -i2 "arr(TCLSimEnv): \{$arr(TCLSimEnv)\}"
                } else {
                    vputs -v3 -i2 "Unknown variable '[lindex $Lines 1]'!"
                }
                set Lines ""
            } else {
                append Lines " [string trim $Line]"
            }
        }
        close $Inf
        set VarName [list]
        set VarVal [list]
        set VarIdx 0
        set SwbName [list]
        set SwbVal [list]
        set SwbIdx 0
        set Lines ""
        set Inf [open $::SimArr(FVarSim) r]
        while {[gets $Inf Line] != -1} {

            # Read lines after reading an empty or comment line
            if {![regexp {\S} $Line] || [string index $Line 0] eq "#"} {

                # Extract tool label
                if {[regexp {^\s*#} $Line]
                    && [regexp -nocase $arr(STDfltID) $Line -> ToolLbl]} {
                    lappend arr(TCLSTLbl) $ToolLbl
                    lappend arr(TCLSTIdx) $VarIdx
                    lappend arr(TCLSWBIdx) $SwbIdx
                    vputs -v3 -i1 "ST tool label: '$ToolLbl'\tindex:\
                        '$VarIdx'\tSWB index: '$SwbIdx'"
                }
                if {[string length $Lines]} {
                    set Name [lindex $Lines 1]
                    set Tmp [lindex $VarName end]
                    if {[regexp -nocase \\w+<mfj> $Name]
                        || "$Name<mfj>" ne $Tmp} {
                        lappend VarName $Name
                        lappend VarVal [lindex $Lines 2]
                        incr VarIdx
                        vputs -v3 -i2 "$Name: \{[lindex $Lines 2]\}"
                        if {[regexp -nocase ^\\w+<mfj> $Name]
                            || [string index $::SimArr(Node4All) 0] ne "!"} {
                            lappend SwbName $Name
                            lappend SwbVal [lindex $Lines 2]
                            incr SwbIdx
                        }
                    }
                }
                set Lines ""
            } else {
                append Lines " [string trim $Line]"
            }
        }
        close $Inf
        set arr(TCLVarName) $VarName
        set arr(TCLVarVal) $VarVal
        set arr(TCLSWBName) $SwbName
        set arr(TCLSWBVal) $SwbVal
    } else {
        vputs -i1 "The variable TCL file '$::SimArr(FVarEnv)' or\
            '$::SimArr(FVarSim)' not found!"
        set arr(UpdateTCL) true
        set arr(UpdateCMD) true
    }
    vputs
}

# mfjST::readGTree
    # Read gtree.dat and update the following variables in arr:
    # GTreeLine0 GTreeSTVer GTreeColMode GTreeSTName GTreeSTLbl GTreeSWBIdx
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
                if {$arr(GTreeSTVer) eq "" && [regexp -nocase\
                    ^#\\s[lindex $arr(DfltGTreeID) 0] $Line\
                    -> arr(GTreeSTVer)]} {
                    vputs -v2 -i1 "ST version: '$arr(GTreeSTVer)'"
                }

                # Extract simulation flow
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(DfltGTreeID) 1] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(DfltGTreeID) 1]:"
                    set ReadFlow true
                    set VarIdx 0
                    set VarName [list]
                    set VarVal [list]
                }
                if {[regexp -nocase\
                    ^$::SimArr(Prefix)\\s[lindex $arr(DfltGTreeID) 2] $Line]} {
                    vputs -v2 -i1 "Found [lindex $arr(DfltGTreeID) 2]:"
                    set ReadFlow false
                    set ReadVar true
                    set mfjProc::arr(Indent1) 2
                    set GTree [buildTree $VarName $VarVal $arr(GTreeSWBIdx)\
                        ColMode]
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
                        vputs -i1 "The SWB setting file 'gtree.dat' is\
                            damaged!"
                        set arr(UpdateGTree) true
                        break
                    }

                    # Tools can be distinguished by the empty value
                    if {[lindex $Line 2] eq "" && [lindex $Line 3] eq ""} {
                        lappend arr(GTreeSTLbl) [lindex $Line 0]
                        lappend arr(GTreeSTName) [lindex $Line 1]
                        lappend arr(GTreeSWBIdx) $VarIdx
                        vputs -v3 -i2 "ST tool name: '[lindex $Line 1]'\tlabel:\
                            '[lindex $Line 0]'\tindex: '$VarIdx'"
                    } else {
                        lappend VarName [lindex $Line 1]
                        lappend VarVal [lindex $Line end]

                        # Decode values of swb variables, refer to the rules
                        # set out in 'updateGTree'
                        if {[llength [lindex $Line end]] == 1} {
                            lappend arr(GTreeSWBName) [lindex $Line 1]
                            set arr(GTreeNode4All) Node4All
                            set Val [lindex $Line end 0]
                            if {$Val eq "/0"} {
                                lappend arr(GTreeSWBVal) ""
                            } else {
                                set Val [string map {*: \{ :* \} :: " "} $Val]
                                lappend arr(GTreeSWBVal) $Val
                            }
                        } else {
                            lappend arr(GTreeSWBName) [lindex $Line 1]<mfj>
                            set Lst [list]
                            foreach Elm [lindex $Line end] {
                                if {$Elm eq "/0"} {
                                    lappend Lst ""
                                } else {
                                    lappend Lst [string map\
                                        {*: \{ :* \} :: " "} $Elm]
                                }
                            }
                            lappend arr(GTreeSWBVal) $Lst
                        }
                        incr VarIdx
                        vputs -v3 -i3 "[lindex $arr(GTreeSWBName) end]:\
                            \{[lindex $arr(GTreeSWBVal) end]\}"
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
        if {$arr(GTreeSTName) eq ""} {
            vputs -i1 "No tools found in 'gtree.dat'!"
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
                    if {[regexp {\-\-time=(\S+):00:00} $Line\
                        -> arr(BatMaxTmHr)]} {
                        vputs -v3 -i1 "Job scheduler: $arr(BatSched)"
                        vputs -v3 -i1 "Maximum walltime: $arr(BatMaxTmHr) hrs"
                    }
                    if {[regexp {\-\-mem=(\S+)GB} $Line\
                        -> arr(BatMaxMemGB)]} {
                        vputs -v3 -i1 "Maximum memory: $arr(BatMaxMemGB) GB"
                    }
                    if {[regexp {\-\-mail-user=(\S+)} $Line\
                        -> arr(BatEmail)]} {
                        vputs -v3 -i1 "Email: $arr(BatEmail)"
                    }
                }
                if {[regexp {\#PBS} $Line]} {
                    set arr(BatSched) PBS
                    if {[regexp {\-l walltime=(\S+):00:00} $Line\
                        -> arr(BatMaxTmHr)]} {
                        vputs -v3 -i1 "Job scheduler: $arr(BatSched)"
                        vputs -v3 -i1 "Maximum walltime: $arr(BatMaxTmHr) hrs"
                    }
                    if {[regexp {\-l mem=(\S+)gb} $Line\
                        -> arr(BatMaxMemGB)]} {
                        vputs -v3 -i1 "Maximum memory: $arr(BatMaxMemGB) GB"
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
    # and set arr(UpdateTCL) to be true if there is any difference
proc mfjST::tclvsFmt {} {
    variable arr

    # Create SwbName, SwbVal and SwbIdx for easier comparison
    if {[string index $::SimArr(Node4All) 0] ne "!"} {
        set SwbName $mfjIntrpr::arr(FmtVarName)
        set SwbVal $mfjIntrpr::arr(FmtVarVal)
        set SwbIdx $mfjIntrpr::arr(FmtSTIdx)
    } else {
        set SwbName [list]
        set SwbVal [list]
        set SwbIdx [list]
        set VarIdx 0
        set STIdx 0
        set Idx 0
        set FmtSTIdx $mfjIntrpr::arr(FmtSTIdx)
        set STLen [llength $FmtSTIdx]
        foreach Var $mfjIntrpr::arr(FmtVarName) Val $mfjIntrpr::arr(FmtVarVal) {

            # In case no variables between tools
            while {$STIdx < $STLen && [lindex $FmtSTIdx $STIdx] == $VarIdx} {
                lappend SwbIdx $Idx
                incr STIdx
            }
            if {[regexp ^\\w+<mfj>$ $Var]} {
                lappend SwbName $Var
                lappend SwbVal $Val
                incr Idx
            }
            incr VarIdx
        }

        # In case no variables or the rest tools have no variables
        while {$STIdx < $STLen && [lindex $FmtSTIdx $STIdx] == $VarIdx} {
            lappend SwbIdx $Idx
            incr STIdx
        }
    }

    # TCL related variables should be updated here
    set StartIdx $arr(StartIdx)
    if {!$arr(UpdateTCL)} {
        vputs "Comparing '$::SimArr(FVarEnv)' and '$::SimArr(FVarSim)' against\
            '$::SimArr(FVarFmt)'..."

        # Re-run all the tools for major changes
        if {$arr(TCLSimEnv) ne $mfjIntrpr::arr(FmtSimEnv)} {
            set arr(UpdateTCL) true
            set Msg "Environment variable 'SimEnv' has a value of\
                '$arr(TCLSimEnv)' different from '$mfjIntrpr::arr(FmtSimEnv)'!"
        } elseif {$arr(TCLDfltSet) ne $mfjIntrpr::arr(FmtDfltSet)} {
            set arr(UpdateTCL) true
            set Msg "Environment variable 'mfjDfltSet' has a value of\
                '$arr(TCLDfltSet)' different from\
                '$mfjIntrpr::arr(FmtDfltSet)'!"
        } elseif {$arr(TCLModTime) ne $mfjIntrpr::arr(FmtModTime)} {
            set arr(UpdateTCL) true
            set Msg "Environment variable 'mfjModTime' has a value of\
                '$arr(TCLModTime)' different from\
                '$mfjIntrpr::arr(FmtModTime)'!"
        } elseif {$arr(TCLRegInfo) ne $mfjIntrpr::arr(FmtRegInfo)} {
            set arr(UpdateTCL) true
            set Msg "Environment variable 'mfjRegInfo' has a value of\
                '$arr(TCLRegInfo)' different from\
                '$mfjIntrpr::arr(FmtRegInfo)'!"
        } else {
            if {[llength $arr(TCLSTLbl)]\
                != [llength $mfjIntrpr::arr(FmtSTLbl)]} {
                set arr(UpdateTCL) true
                set Msg "ST tool # '[llength $arr(TCLSTLbl)]' different\
                    from '[llength $mfjIntrpr::arr(FmtSTLbl)]'!"
            } else {
                foreach TLbl $arr(TCLSTLbl) FLbl $mfjIntrpr::arr(FmtSTLbl)\
                    TName $arr(TCLSTName) FName $mfjIntrpr::arr(FmtSTName)\
                    TIdx $arr(TCLSTIdx) FIdx $mfjIntrpr::arr(FmtSTIdx) {

                    # Case is sensitive
                    if {$TLbl ne $FLbl} {
                        set arr(UpdateTCL) true
                        set Msg "ST tool label '$TLbl' different from '$FLbl'!"
                        break
                    }
                    if {$TName ne $FName} {
                        set arr(UpdateTCL) true
                        set Msg "ST tool name '$TName' different from '$FName'!"
                        break
                    }
                    if {$TIdx != $FIdx} {

                        # Variables could be moved up, but not down
                        set arr(UpdateTCL) true
                        set Msg "ST tool index '$TIdx' different from '$FIdx'!"
                        break
                    }
                }
            }
        }

        if {!$arr(UpdateTCL)} {

            # Try to preserve as many cases in ::SimArr(FVarSim) as possible
            set DelVar [list]
            set IdxLst [list]
            foreach Var $arr(TCLVarName) {
                set Idx [lsearch -regexp $mfjIntrpr::arr(FmtVarName)\
                    (?i)^$Var$]
                if {$Idx == -1} {
                    lappend DelVar $Var
                } else {
                    if {[lindex $mfjIntrpr::arr(FmtVarName) $Idx] ne $Var} {
                        lset mfjIntrpr::arr(FmtVarName) $Idx $Var
                    }
                    lappend IdxLst $Idx
                }
            }
            if {[llength $DelVar]} {
                set arr(UpdateTCL) true
                set Msg "Deleted '[llength $DelVar]' simulation variables:\
                    $DelVar"
            }
            if {[llength $IdxLst] < [llength $mfjIntrpr::arr(FmtVarName)]} {
                set IdxLst [lsort -integer $IdxLst]
                set Idx 0
                set AddVar [list]
                foreach Var $mfjIntrpr::arr(FmtVarName) {
                    if {$Var eq [lindex $mfjIntrpr::arr(FmtVarName)\
                        [lindex $IdxLst $Idx]]} {
                        incr Idx
                    } else {
                        lappend AddVar $Var
                    }
                }
                set arr(UpdateTCL) true
                set Msg "Added '[llength $AddVar]' simulation variables:\
                    $AddVar"
            }
        }

        if {!$arr(UpdateTCL)} {

            # The tool index may be updated after comparison
            if {[llength $DelVar] == 0 && [llength $IdxLst]
                == [llength $mfjIntrpr::arr(FmtVarName)]} {
                set VarIdx 0
                foreach TVar $arr(TCLVarName) TVal $arr(TCLVarVal)\
                    FVal $mfjIntrpr::arr(FmtVarVal) {
                    if {$TVal ne $FVal} {
                        set arr(UpdateTCL) true
                        set Msg "Simulation variable '$TVar' has a value of\
                            '$TVal' different from '$FVal'!"
                        break
                    }
                    incr VarIdx
                }

                # Determine the changed variable belongs to which tool
                if {$arr(UpdateTCL)} {
                    set STIdx 0
                    foreach Idx $arr(TCLSTIdx) {
                        if {$VarIdx < $Idx} {
                            break
                        }
                        incr STIdx
                    }
                    set StartIdx [incr STIdx -1]
                }
            }
        }
        if {$arr(UpdateTCL)} {
            vputs -i1 "'$::SimArr(FVarEnv)' and '$::SimArr(FVarSim)' are\
                different from '$::SimArr(FVarFmt)'!"
            vputs -i2 $Msg
            vputs -v2 -i2 "ST starting tool index: '$StartIdx'"
        } else {
            set arr(StartIdx) [llength $arr(TCLSTIdx)]
            vputs -i1 "'$::SimArr(FVarEnv)' and '$::SimArr(FVarSim)' are\
                the same as '$::SimArr(FVarFmt)'!"
        }
        vputs
    }
    if {$arr(UpdateTCL)} {

        # Perform an efficient update of all related variables
        set arr(StartIdx) $StartIdx
        set arr(TCLSimEnv) $mfjIntrpr::arr(FmtSimEnv)
        set arr(TCLDfltSet) $mfjIntrpr::arr(FmtDfltSet)
        set arr(TCLModTime) $mfjIntrpr::arr(FmtModTime)
        set arr(TCLRegInfo) $mfjIntrpr::arr(FmtRegInfo)
        set arr(TCLSTName) $mfjIntrpr::arr(FmtSTName)
        set arr(TCLSTLbl) $mfjIntrpr::arr(FmtSTLbl)
        set arr(TCLSTIdx) $mfjIntrpr::arr(FmtSTIdx)
        set arr(TCLVarName) $mfjIntrpr::arr(FmtVarName)
        set arr(TCLVarVal) $mfjIntrpr::arr(FmtVarVal)
        set arr(TCLSWBName) $SwbName
        set arr(TCLSWBVal) $SwbVal
        set arr(TCLSWBIdx) $SwbIdx
    }
}

# mfjST::gtreevsTcl
    # Compare gtree.dat against the updated ::SimArr(FVarSim) and set
    # arr(UpdateGTree) to be true if there is any difference
proc mfjST::gtreevsTcl {} {
    variable arr

    if {!$arr(UpdateGTree)} {
        vputs "Comparing 'gtree.dat' and '$::SimArr(FVarSim)'..."
        if {$arr(GTreeColMode) ne $::SimArr(ColMode)} {
            set arr(UpdateGTree) true
            set Msg "SWB variable column combination '$arr(GTreeColMode)'\
                different from '$::SimArr(ColMode)'!"
        } elseif {$arr(GTreeSTVer) ne [lindex $arr(TCLSimEnv) 1]} {
            set arr(UpdateGTree) true
            set Msg "Sentaurus TCAD version '$arr(GTreeSTVer)' different\
                from '[lindex $arr(TCLSimEnv) 1]'!"
        } elseif {$arr(GTreeNode4All) ne $::SimArr(Node4All)} {
            set arr(UpdateGTree) true
            set Msg "SWB node arrangement for all variables\
                '$arr(GTreeNode4All)' different from '$::SimArr(Node4All)'!"
        } else {
            if {[llength $arr(GTreeSTLbl)] != [llength $arr(TCLSTLbl)]} {
                set arr(UpdateGTree) true
                set Msg "SWB tool # '[llength $arr(GTreeSTLbl)]' different\
                    from '[llength $arr(TCLSTLbl)]'!"
            } else {
                foreach GLbl $arr(GTreeSTLbl) TLbl $arr(TCLSTLbl)\
                    GName $arr(GTreeSTName) TName $arr(TCLSTName)\
                    GIdx $arr(GTreeSWBIdx) TIdx $arr(TCLSWBIdx) {

                    # Case is sensitive
                    if {$GLbl ne $TLbl} {
                        set arr(UpdateGTree) true
                        set Msg "ST tool label '$GLbl' different from '$TLbl'!"
                        break
                    }
                    if {$GName ne $TName} {
                        set arr(UpdateGTree) true
                        set Msg "ST tool name '$GName' different from '$TName'!"
                        break
                    }
                    if {$GIdx != $TIdx} {
                        set arr(UpdateGTree) true
                        set Msg "ST SWB index '$GIdx' different from '$TIdx'!"
                        break
                    }
                }
            }
        }

        if {$arr(UpdateGTree)} {

            # Major changes to gtree.dat so re-run is necessary
            set arr(StartIdx) 0
        } else {
            if {[llength $arr(GTreeSWBName)] != [llength $arr(TCLSWBName)]} {
                set arr(UpdateGTree) true
                set arr(StartIdx) 0
                set Msg "SWB variable # '[llength $arr(GTreeSWBName)]'\
                    different from '[llength $arr(TCLSWBName)]'!"
            } else {
                foreach GVar $arr(GTreeSWBName) TVar $arr(TCLSWBName)\
                    GVal $arr(GTreeSWBVal) TVal $arr(TCLSWBVal) {

                    # Case is insensitive
                    if {![string equal -nocase $GVar $TVar]} {
                        set arr(UpdateGTree) true
                        set Msg "ST variable '$GVar' different from '$TVar'!"
                        break
                    }
                    if {![string equal -nocase $GVal $TVal]} {
                        set arr(UpdateGTree) true
                        set Msg "ST variable '$GVar' has a value of '$GVal'\
                            different from '$TVal'!"
                        break
                    }
                }
            }
        }
        if {$arr(UpdateGTree)} {
            vputs -i1 "'gtree.dat' is different from '$::SimArr(FVarSim)'!"
            vputs -i2 $Msg
            vputs -v2 -i2 "ST starting tool index: '$arr(StartIdx)'"
        } else {
            vputs -i1 "'gtree.dat' is the same as '$::SimArr(FVarSim)'!"
        }
        vputs
    }
    if {$arr(UpdateGTree)} {

        # Perform an efficient update of all related variables
        set arr(GTreeSTVer) [lindex $arr(TCLSimEnv) 1]
        set arr(GTreeNode4All) $::SimArr(Node4All)
        set arr(GTreeColMode) $::SimArr(ColMode)
        set arr(GTreeSWBName) $arr(TCLSWBName)
        set arr(GTreeSWBVal) $arr(TCLSWBVal)
        set arr(GTreeSWBIdx) $arr(TCLSWBIdx)
        set arr(GTreeSTLbl) $arr(TCLSTLbl)
        set arr(GTreeSTName) $arr(TCLSTName)
    }
}

# mfjST::tclvsGtree
    # Compare ::SimArr(FVarEnv) and ::SimArr(FVarSim) against gtree.dat and
    # set arr(UpdateTCL) to be true if there is any difference
proc mfjST::tclvsGtree {} {
    variable arr

    if {!$arr(UpdateTCL)} {
        vputs "Comparing '$::SimArr(FVarSim)' and '$::SimArr(FVarEnv)' against\
            'gtree.dat'..."
        if {[lindex $arr(TCLSimEnv) 1] ne $arr(GTreeSTVer)} {
            set arr(UpdateTCL) true
            set Msg "Sentaurus TCAD version '[lindex $arr(TCLSimEnv) 1]'\
                different from '$arr(GTreeSTVer)'!"
        }
        if {!$arr(UpdateTCL)} {
            if {[llength $arr(TCLSTLbl)] != [llength $arr(GTreeSTLbl)]} {
                set arr(UpdateTCL) true
                set Msg "SWB tool # '[llength $arr(TCLSTLbl)]' different\
                    from '[llength $arr(GTreeSTLbl)]'!"
            } else {
                foreach TLbl $arr(TCLSTLbl) GLbl $arr(GTreeSTLbl)\
                    TName $arr(TCLSTName) GName $arr(GTreeSTName)\
                    TIdx $arr(TCLSWBIdx) GIdx $arr(GTreeSWBIdx) {

                    # Case is sensitive
                    if {$TLbl ne $GLbl} {
                        set arr(UpdateTCL) true
                        set Msg "ST tool label '$TLbl' different from '$GLbl'!"
                        break
                    }
                    if {$TName ne $GName} {
                        set arr(UpdateTCL) true
                        set Msg "ST tool name '$TName' different from '$GName'!"
                        break
                    }
                    if {$TIdx != $GIdx} {
                        set arr(UpdateTCL) true
                        set Msg "ST SWB index '$TIdx' different from '$GIdx'!"
                        break
                    }
                }
            }
        }
        if {!$arr(UpdateTCL)} {
            if {[llength $arr(TCLSWBName)] != [llength $arr(GTreeSWBName)]} {
                set arr(UpdateTCL) true
                set Msg "SWB variable # '[llength $arr(TCLSWBName)]'\
                    different from '[llength $arr(GTreeSWBName)]'!"
            } else {
                foreach TVar $arr(TCLSWBName) GVar $arr(GTreeSWBName)\
                    TVal $arr(TCLSWBVal) GVal $arr(GTreeSWBVal) {

                    # Case is insensitive
                    if {![string equal -nocase $TVar $GVar]} {
                        set arr(UpdateTCL) true
                        set Msg "ST variable '$TVar' different from '$GVar'!"
                        break
                    }
                    if {![string equal -nocase $TVal $GVal]} {
                        set arr(UpdateTCL) true
                        set Msg "ST variable '$GVar' has a value of '$TVal'\
                            different from '$GVal'!"
                        break
                    }
                }
            }
        }
        if {$arr(UpdateTCL)} {
            vputs -i1 "'$::SimArr(FVarSim)' and '$::SimArr(FVarEnv)' are\
                different from 'gtree.dat'!"
            vputs -i2 $Msg
        } else {
            vputs -i1 "'$::SimArr(FVarSim)' and '$::SimArr(FVarEnv)' are the\
                same as 'gtree.dat'!"
        }
        vputs
    }
    if {$arr(UpdateTCL)} {

        # Perform a smart update of TCL related variables
        if {$arr(TCLSimEnv) eq ""} {
            set arr(TCLSimEnv) [list Sentaurus $arr(GTreeSTVer)]
        } else {
            lset arr(TCLSimEnv) 1 $arr(GTreeSTVer)
        }
        set arr(TCLSWBName) $arr(GTreeSWBName)
        set arr(TCLSWBVal) $arr(GTreeSWBVal)
        set arr(TCLSWBIdx) $arr(GTreeSWBIdx)
        set arr(TCLSTName) $arr(GTreeSTName)
        set arr(TCLSTLbl) $arr(GTreeSTLbl)

        if {[llength $arr(TCLSTIdx)] != [llength $arr(TCLSWBIdx)]} {
            set arr(TCLVarName) $arr(GTreeSWBName)
            set arr(TCLVarVal) $arr(GTreeSWBVal)
            set arr(TCLSTIdx) $arr(TCLSWBIdx)
        } elseif {[llength $arr(GTreeSWBName)]} {

            # In case SWB variables are present, update arr(TCLVarName),
            # arr(TCLVarVal) and arr(TCLSTIdx) in two steps
            # 1: Remove SWB variables from the TCL variable list
            set TCLVarName $arr(TCLVarName)
            set TCLVarVal $arr(TCLVarVal)
            set TCLSTIdx $arr(TCLSTIdx)
            foreach Var $arr(GTreeSWBName) Val $arr(GTreeSWBVal) {

                # Extract variable name
                regexp {^(\w+)(<mfj>)?$} $Var -> Name
                set Idx [lsearch -regexp $TCLVarName (?i)^${Name}(<mfj>)?$]
                set Idx1 [incr Idx -1]
                set Idx2 [incr Idx 2]
                if {$Idx != -1} {
                    set TCLVarName [concat [lrange $TCLVarName 0 $Idx1]\
                        [lrange $TCLVarName $Idx2 end]]
                    set TCLVarVal [concat [lrange $TCLVarVal 0 $Idx1]\
                        [lrange $TCLVarVal $Idx2 end]]
                    set Lst [list]
                    foreach VarIdx $TCLSTIdx {
                        if {$Idx < $VarIdx} {
                            lappend Lst [incr VarIdx -1]
                        } else {
                            lappend Lst $VarIdx
                        }
                    }
                    set TCLSTIdx $Lst
                }
            }

            # 2: Append SWB variables to TCL variables for each tool
            set arr(TCLVarName) [list]
            set arr(TCLVarVal) [list]
            set Lst [lindex $TCLSTIdx 0]
            set VarIdx 0
            set SWBIdx 0
            set VarIdx1 0
            set SWBIdx1 0
            foreach VarIdx [lrange $TCLSTIdx 1 end]\
                SWBIdx [lrange $arr(GTreeSWBIdx) 1 end] {
                set arr(TCLVarName) [concat $arr(TCLVarName)\
                    [lrange $TCLVarName $VarIdx1 [expr $VarIdx-1]]\
                    [lrange $arr(GTreeSWBName) $SWBIdx1 [expr $SWBIdx-1]]]
                set arr(TCLVarVal) [concat $arr(TCLVarVal)\
                    [lrange $TCLVarVal $VarIdx1 [expr $VarIdx-1]]\
                    [lrange $arr(GTreeSWBVal) $SWBIdx1 [expr $SWBIdx-1]]]
                set VarIdx1 $VarIdx
                set SWBIdx1 $SWBIdx
                lappend Lst [incr VarIdx $SWBIdx]
            }
            set arr(TCLVarName) [concat $arr(TCLVarName)\
                [lrange $TCLVarName $VarIdx end]\
                [lrange $arr(GTreeSWBName) $SWBIdx end]]
            set arr(TCLVarVal) [concat $arr(TCLVarVal)\
                [lrange $TCLVarVal $VarIdx end]\
                [lrange $arr(GTreeSWBVal) $SWBIdx end]]
            set arr(TCLSTIdx) $Lst
        }
    }
}

# mfjST::arrvsGtree
    # Compare ::SimArr against gtree.dat and set arr(UpdateArr) to be true
    # if there is any difference
proc mfjST::arrvsGtree {} {
    variable arr

    vputs "Comparing '::SimArr' against 'gtree.dat'..."
    if {$::SimArr(ColMode) ne $arr(GTreeColMode)} {
        set arr(UpdateArr) true
        set Msg "SWB variable combination '$::SimArr(ColMode)'\
            different from '$arr(GTreeColMode)'!"
        set ::SimArr(ColMode) $arr(GTreeColMode)
    } elseif {$::SimArr(Node4All) ne $arr(GTreeNode4All)} {
        if {[string index $arr(GTreeNode4All) 0] ne "!"
            && ($arr(TCLVarName) eq ""
            || [llength $arr(TCLVarName)] == [llength $arr(GTreeSWBName)])} {
            set arr(UpdateArr) true
        } else {
            set arr(UpdateArr) true
        }
        if {$arr(UpdateArr)} {
            set Msg "SWB node arrangement for all variables\
                '$::SimArr(Node4All)' different from '$arr(GTreeNode4All)'!"
            set ::SimArr(Node4All) $arr(GTreeNode4All)
        }
    } else {

        # Go through each SWB variable and update the case in ::SimArr(VarName)
        foreach Elm $arr(GTreeSWBName) {

            # Extract variable name
            regexp {^(\w+)(<mfj>)?$} $Elm -> Name
            set Idx [lsearch -regexp $::SimArr(VarName) (?i)^$Name$]
            if {$Idx == -1} {

                # SWB variable not found
                set arr(UpdateArr) true
                lappend ::SimArr(VarName) $Name
                set Msg "SWB variable '$Name' added in '::Sim(VarName)' of\
                    of '11ctrlsim.tcl'!"
            } else {

                # Check whether the variable names are the same case
                if {[lindex $::SimArr(VarName) $Idx] ne $Name} {
                    set arr(UpdateArr) true
                    lset ::SimArr(VarName) $Idx $Name
                    set Msg "SWB variable '$Name' updated in\
                        '::SimArr(VarName)' of '11ctrlsim.tcl'!"
                }
            }
        }
    }
    if {$arr(UpdateArr)} {
        vputs -i1 "'::SimArr' is different from 'gtree.dat'!"
        vputs -i2 $Msg
    } else {
        vputs -i1 "'::SimArr' is the same as 'gtree.dat'!"
    }
    vputs
}

# mfjST::batchvsTcl
    # Compare ::SimArr(FSTBatch) against ::SimArr(FVarEnv), ::SimArr(FVarSim)
    # and mfjIntrpr::host. Update TCLKeyNode and set arr(UpdateBat) to be true
    # if there is any difference
proc mfjST::batchvsTcl {} {
    variable arr

    # Update arr(TCLKeyNode), arr(TCLRunNode) and arr(TCLCMILst)
    set arr(TCLKeyNode) [buildTree $arr(TCLSWBName) $arr(TCLSWBVal)\
        $arr(TCLSWBIdx) $::SimArr(ColMode) !NodeTree]
    if {$arr(UpdateTCL)} {
        if {$arr(StartIdx) == 0} {
            set arr(TCLRunNode) all
        } else {
            set arr(TCLRunNode) [string map {\{ ""  \} ""}\
                [lrange $arr(TCLKeyNode) $arr(StartIdx) end]]
        }
    } else {
        set arr(TCLRunNode) remaining
    }
    foreach Elm $arr(TCLModTime) {
        if {[regexp {(\w+)\.[cC]$} [lindex $Elm 0] -> Root]} {
            if {[glob -nocomplain $::SimArr(PMIDir)/$Root.so.*] eq ""} {
                lappend arr(TCLCMILst) [file tail [lindex $Elm 0]]
            }
        }
    }
    set STROOT [lsearch -inline -regexp [glob -nocomplain -directory\
        $mfjIntrpr::host(STPath) *] (?i)[lindex $arr(TCLSimEnv) 1]$]

    if {!$arr(UpdateBat)} {
        vputs "Comparing '$::SimArr(FSTBatch)' against\
            '$::SimArr(FVarEnv)', '$::SimArr(FVarSim)' and the host..."
        if {$arr(BatSTVer) ne [lindex $arr(TCLSimEnv) 1]} {

            # Sentaurus related variables are case-sensitive
            set arr(UpdateBat) true
            set Msg "Sentaurus version '$arr(BatSTVer)' different\
                from '[lindex $arr(TCLSimEnv) 1]'!"
        } elseif {$arr(BatSTRoot) ne $STROOT} {
            set arr(UpdateBat) true
            set Msg "Sentaurus root '$arr(BatSTRoot)' different from '$STROOT'!"
        } elseif {$arr(BatSTLicn) ne $mfjIntrpr::host(STLicn)} {
            set arr(UpdateBat) true
            set Msg "Sentaurus license '$arr(BatSTLicn)' different\
                from '$mfjIntrpr::host(STLicn)'!"
        } elseif {$arr(BatSTPDir) ne [pwd]} {
            set arr(UpdateBat) true
            set Msg "Sentaurus project directory '$arr(BatSTPDir)' different\
                from '[pwd]'!"
        } elseif {$arr(BatRunNode) ne $arr(TCLRunNode)} {
            set arr(UpdateBat) true
            set Msg "SWB to run nodes '$arr(BatRunNode)' different\
                from '$arr(TCLRunNode)'!"
        } elseif {$arr(BatCMILst) ne $arr(TCLCMILst)} {
            set arr(UpdateBat) true
            set Msg "CMI list '$arr(BatCMILst)' different\
                from '$arr(TCLCMILst)'!"
        } else {

            # SLURM partition or PBS queue is case sensitive
            if {$arr(BatSched) ne [lindex $arr(TCLSimEnv) 4]} {
                set arr(UpdateBat) true
                set Msg "Job scheduler '$arr(BatSched)' different\
                    from '[lindex $arr(TCLSimEnv) 4]'!"

            }
            if {$arr(BatSched) ne "Local"} {
                if {$arr(BatMaxTmHr) != [lindex $arr(TCLSimEnv) 5]} {
                    set arr(UpdateBat) true
                    set Msg "Maximum walltime '$arr(BatMaxTmHr)' hrs\
                        different from '[lindex $arr(TCLSimEnv) 5]'!"
                }
                if {$arr(BatMaxMemGB) != [lindex $arr(TCLSimEnv) 6]} {
                    set arr(UpdateBat) true
                    set Msg "Maximum memory '$arr(BatMaxMemGB)' GB\
                        different from '[lindex $arr(TCLSimEnv) 6]'!"
                }
                if {$arr(BatEmail) ne $mfjIntrpr::host(Email)} {

                    # Case sensitive
                    set arr(UpdateBat) true
                    set Msg "Email '$arr(BatEmail)' different\
                        from '$mfjIntrpr::host(Email)'!"
                }
            }
        }
        if {$arr(UpdateBat)} {
            vputs -i1 "'$::SimArr(FSTBatch)' is different from\
                '$::SimArr(FVarEnv)' or '$::SimArr(FVarSim)' or the host!"
            vputs -i2 $Msg
        } else {
            vputs -i1 "'$::SimArr(FSTBatch)' is the same as\
                '$::SimArr(FVarEnv)', '$::SimArr(FVarSim)' and the host!"
        }
        vputs
    }
    if {$arr(UpdateBat)} {
        set arr(BatEmail) $mfjIntrpr::host(Email)
        set arr(BatSTVer) [lindex $arr(TCLSimEnv) 1]
        set arr(BatSched) [lindex $arr(TCLSimEnv) 4]
        set arr(BatMaxTmHr) [lindex $arr(TCLSimEnv) 5]
        set arr(BatMaxMemGB) [lindex $arr(TCLSimEnv) 6]
        set arr(BatSTRoot) $STROOT
        set arr(BatSTLicn) $mfjIntrpr::host(STLicn)
        set arr(BatRunNode) $arr(TCLRunNode)
        set arr(BatCMILst) $arr(TCLCMILst)
        set arr(BatSTLib) $mfjIntrpr::host(STLib)
        set arr(BatSTPDir) [pwd]
    }
}

# mfjST::updateTCL
    # Update the variable TCL files ::SimArr(FVarEnv) and ::SimArr(FVarSim) if
    # arr(UpdateTCL) is true
proc mfjST::updateTCL {} {
    variable arr
    set Tab $mfjProc::arr(Tab)
    if {$arr(UpdateTCL)} {
        vputs "Updating the variable TCL files '$::SimArr(FVarEnv)' and\
            '$::SimArr(FVarSim)'..."
        if {[file isfile $::SimArr(FVarEnv)]} {
            vputs -v5 -i1 "Making a TCL file backup\
                '$::SimArr(FVarEnv).backup'..."
            file copy -force $::SimArr(FVarEnv) $::SimArr(FVarEnv).backup
        }
        set Ouf [open $::SimArr(FVarEnv).mfj w]
        vputs -v3 -i1 -n "Calculating the max length of environment variable\
            names... "
        set VarName {SimEnv DfltSet ModTime RegInfo STName}
        set MaxLen [calMaxVarLen $VarName]
        vputs -v3 -c '[incr MaxLen 3]'

        # Add at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]
        puts $Ouf "$::SimArr(Prefix) $arr(DfltSTHead)\n"

        # Output environment variables
        puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n" SimEnv\
            $arr(TCLSimEnv)] $Tab]
        foreach Elm [lrange $VarName 1 end] {
            puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n"\
                mfj$Elm $arr(TCL$Elm)] $Tab]
        }
        close $Ouf
        file rename -force $::SimArr(FVarEnv).mfj $::SimArr(FVarEnv)

        if {[file isfile $::SimArr(FVarSim)]} {
            vputs -v5 -i1 "Making a TCL file backup\
                '$::SimArr(FVarSim).backup'..."
            file copy -force $::SimArr(FVarSim) $::SimArr(FVarSim).backup
        }

        set Ouf [open $::SimArr(FVarSim).mfj w]
        vputs -v3 -i1 -n "Calculating the max length of simulation variable\
            names... "
        set MaxLen [calMaxVarLen $arr(TCLVarName)]
        vputs -v3 -c '$MaxLen'

        # Add at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]

        # Output simulation variables
        set Ptn [string map {(\\S+) %s} $arr(STDfltID)]
        set VarIdx 0
        set STIdx 0
        set STLen [llength $arr(TCLSTLbl)]
        foreach Var $arr(TCLVarName) Val $arr(TCLVarVal) {

            # In case no variables between tools
            while {$STIdx < $STLen
                && [lindex $arr(TCLSTIdx) $STIdx] == $VarIdx} {
                if {$STIdx} {
                    puts $Ouf "#endif\n"
                }
                puts $Ouf [format $Ptn\n [lindex $arr(TCLSTLbl) $STIdx]]
                incr STIdx
            }
            puts $Ouf [wrapText [format "set %-${MaxLen}s\{%s\}\n" $Var $Val]\
                $Tab]

            # Decrease MaxLen with 4 spaces and change it back afterwards
            if {[regexp ^(\\w+)<mfj>$ $Var -> Tmp]} {
                incr MaxLen -4
                puts $Ouf [wrapText [format "#if \"@%s@\" eq \"/0\"" $Tmp] $Tab]
                puts $Ouf [wrapText [format "set %-${MaxLen}s\{\}" $Tmp]\
                    ${Tab}$Tab]
                puts $Ouf [wrapText "#else" $Tab]
                puts $Ouf [wrapText [format "set %-${MaxLen}s\[string map\
                    \{*: \\{ :* \\} :: \" \"\} @%s@\]" $Tmp $Tmp] ${Tab}$Tab]
                puts $Ouf [wrapText "#endif\n" $Tab]
                incr MaxLen 4
            }
            incr VarIdx
        }

        # In case no variables or the rest tools have no variables
        while {$STIdx < $STLen && [lindex $arr(TCLSTIdx) $STIdx] == $VarIdx} {
            if {$STIdx} {
                puts $Ouf "#endif\n"
            }
            puts $Ouf [format $Ptn\n [lindex $arr(TCLSTLbl) $STIdx]]
            incr STIdx
        }
        if {$STLen} {
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
        if {[file isfile 11ctrlsim.tcl]} {
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
    # arr(GTreeSWBName) arr(GTreeSWBVal) arr(GTreeSTLbl) arr(GTreeSTName)
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
        puts $Ouf "# This file was generated by '[file tail [info script]]'"
        set Ptn [string map {(\\S+) %s} [lindex $arr(DfltGTreeID) 0]]
        set Tm [clock format [clock seconds] -format "%a %b %d %H:%M:%S %Y" ]
        puts $Ouf [format "# $Ptn $Tm" $arr(GTreeSTVer)]
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
        set STIdx 0
        set STLen [llength $arr(GTreeSTName)]
        set VarName [list]
        set VarVal [list]
        foreach Var $arr(GTreeSWBName) Val $arr(GTreeSWBVal) {

            # In case no variables between tools
            while {$STIdx < $STLen
                && [lindex $arr(GTreeSWBIdx) $STIdx] == $VarIdx} {
                set Lbl [lindex $arr(GTreeSTLbl) $STIdx]
                set Name [lindex $arr(GTreeSTName) $STIdx]
                puts $Ouf "$Lbl $Name \"\" {}"
                incr STIdx
            }

            # swb allowed characters: \w.:+/*-
            # swb can display illegal characters like [](){}<>
            # To renounce illegal characters, follow the rules below:
            # '*:' denotes '{', ':*' denotes '}', '::' denotes ' '
            # If the variable value is an empty string, replace it with '/0'
            if {[regexp ^(\\w+)<mfj>$ $Var -> Tmp]} {
                set Lst [list]
                foreach Elm $Val {
                    if {$Elm eq ""} {
                        lappend Lst /0
                    } else {
                        lappend Lst [string map {\{ *: \} :* " " ::} $Elm]
                    }
                }
                puts $Ouf "$Lbl $Tmp \"[llength $Lst]\" \{$Lst\}"
                lappend VarName $Tmp
                lappend VarVal $Lst
            } else {
                if {$Val eq ""} {
                    set Val /0
                } else {
                    set Val [string map {\{ *: \} :* " " ::} $Val]
                }
                puts $Ouf "$Lbl $Var \"1\" \{$Val\}"
                lappend VarName $Var
                lappend VarVal $Val
            }
            incr VarIdx
        }

        # In case no variables or the rest tools have no variables
        while {$STIdx < $STLen
            && [lindex $arr(GTreeSWBIdx) $STIdx] == $VarIdx} {
            set Lbl [lindex $arr(GTreeSTLbl) $STIdx]
            set Name [lindex $arr(GTreeSTName) $STIdx]
            puts $Ouf "$Lbl $Name \"\" {}"
            incr STIdx
        }

        vputs -v2 -i1 "Writing [lindex $arr(DfltGTreeID) 2]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(DfltGTreeID) 2]"
        vputs -v2 -i1 "Writing [lindex $arr(DfltGTreeID) 3]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(DfltGTreeID) 3]"
        foreach Var $VarName {
            puts $Ouf "scenario default $Var \"\""
        }

        vputs -v2 -i1 "Writing [lindex $arr(DfltGTreeID) 4]..."
        puts $Ouf "$::SimArr(Prefix) [lindex $arr(DfltGTreeID) 4]"
        set mfjProc::arr(Indent1) 2
        foreach Elm [buildTree $VarName $VarVal $arr(GTreeSWBIdx)\
            $arr(GTreeColMode)] {
            puts $Ouf $Elm
        }
        set mfjProc::arr(Indent1) 0
        close $Ouf
        file rename -force .mfj/gtree.dat.mfj gtree.dat
        vputs
    }
}

# mfjST::updateCMD
    # Replace SWB variables with TCL variables in all command files
proc mfjST::updateCMD {} {
    variable arr


    if {$arr(UpdateCMD)} {

    }
}

# mfjST::updatePP_Bat
    # If arr(UpdateBat) is true, update pre-processing file and batch file
    # with arr(BatSched) arr(BatPart) arr(BatQueue) arr(BatEmail)
    # arr(BatMaxTmHr) arr(BatMaxMemGB) arr(BatSTVer) arr(BatSTRoot)
    # arr(BatSTLicn) arr(TCLKeyNode)
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
                    puts $Ouf "#SBATCH --ntasks-per-node=4"
                    puts $Ouf "#SBATCH --mail-type=ALL"
                    puts $Ouf "#SBATCH --mail-user=$arr(BatEmail)\n"
                } elseif {$arr(BatSched) eq "PBS"} {
                    puts $Ouf "#PBS -N pbs"
                    puts $Ouf "#PBS -l walltime=$arr(BatMaxTmHr):00:00"
                    puts $Ouf "#PBS -l mem=$arr(BatMaxMemGB)gb"
                    if {[string equal -nocase $mfjIntrpr::host(ID) tyrion]} {
                        puts $Ouf "#PBS -l nodes=1:ppn=4"
                    } else {
                        puts $Ouf "#PBS -l ncpus=4"
                        puts $Ouf "#PBS -k oed"
                        puts $Ouf "#PBS -j oe"
                    }
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
                        | awk '\{if(NR==4) print \$3\}'`"
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
                    \"[join $arr(TCLRunNode) +]\" . "
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
    foreach Junk [glob -nocomplain slurm* pbs* n_tclResults_*] {
        file delete $Junk
        vputs -v5 -i2 "'$Junk' deleted"
    }
    if {$arr(StartIdx) == 0} {

        # Remove all old results
        foreach Junk [glob -nocomplain $::SimArr(EtcDir)/n*_*\
            $::SimArr(OutDir)/n*_*] {
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

    vputs -i1 "Disabling interactive mode if necessary..."
    foreach Lbl $arr(TCLSTLbl) Name $arr(TCLSTName) {

        # No preference file for 'sdevice'
        if {$Name eq "sdevice"} {
            continue
        }
        set Idx [lsearch -regexp $::SimArr(STTools) ^$Name$]
        set Suf [lindex $::SimArr(STSuffix) $Idx]
        set PrfFile $Lbl[file rootname $Suf].prf
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
            puts $Ouf "set WB_tool($Name,exec_mode) batch"
            if {$Name eq "sde"} {
                puts $Ouf "set WB_tool(sde,input,grid,user) 1\nset\
                    WB_tool(sde,input,boundary,user) 1"
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

    if {$arr(UpdateTCL)} {
        vputs "Recording Trial nodes and variables in\
            '$::SimArr(OutDir)/$::SimArr(FDOESum)'..."
        if {[file isfile $::SimArr(OutDir)/$::SimArr(FDOESum)]} {
            file copy -force $::SimArr(OutDir)/$::SimArr(FDOESum)\
                $::SimArr(OutDir)/$::SimArr(FDOESum).backup
        }
        set Ouf [open $::SimArr(OutDir)/$::SimArr(FDOESum) w]
        set MaxLen [llength [lindex $arr(TCLKeyNode) end]]
        puts $Ouf \n[lindex $arr(DfltDOEID) 0]
        puts $Ouf "Trial node,[join [lindex $arr(TCLKeyNode) end] ,]"
        puts $Ouf \n[lindex $arr(DfltDOEID) 1]
        set Ply 1
        set OldLen 1
        set StrLst [list]
        foreach Var $arr(TCLVarName) Val $arr(TCLVarVal) {
            if {[regexp ^(\\w+)<mfj> $Var -> Lst]} {
                set ValLen [llength $Val]
                if {[string index $::SimArr(ColMode) 0] ne "!"} {
                    if {$ValLen != $OldLen} {
                        set Ply [expr {$Ply*$ValLen}]
                        set OldLen $ValLen
                    }
                } else {
                    set Ply [expr {$Ply*$ValLen}]
                }
                for {set i 0} {$i < $MaxLen} {incr i} {
                    set Idx [expr {int($i*$Ply/$MaxLen)%$ValLen}]
                    if {$i == 0 || $Idx != int(($i-1)*$Ply/$MaxLen)%$ValLen} {
                        lappend Lst [list [lindex $Val $Idx]]
                    } else {
                        lappend Lst ""
                    }
                }
                lappend StrLst [join $Lst ,]
            } else {
                set Lst [list $Var $Val]
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
    }
    vputs
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
    # 1. Translate the formatted file to a TCL file for inclusion
    # 2. Compare TCL settings against gtree.dat and batch files
    # 3. Update the preprocess, batch, gtree.dat, GVar,  files
    # 4. Update all tool related files (command, parameter)
proc mfjST::fmt2swb {} {
    foreach Elm [list valPath readTCL tclvsFmt updateTCL readGTree\
        gtreevsTcl updateGTree readBatch batchvsTcl updatePP_Bat\
        updateDOESum miscTask] {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

# mfjST::swb2tcl
#   Translate changes in gtree.dat to the TCL file only
proc mfjST::swb2tcl {} {
  foreach Elm {readGTree readTCL tclvsGtree arrvsGtree updateTCL updateArr} {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

package provide mfjST $mfjST::version
