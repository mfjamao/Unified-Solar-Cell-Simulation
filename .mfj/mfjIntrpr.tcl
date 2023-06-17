################################################################################
# This namespace is designed to group procedures for converting a raw variable
# file to a formatted variable TXT file. In the raw variable file, everything
# except grammar is case insensitive. In the formatted file, however, everything
# is case sensitive.
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
################################################################################

package require Tcl 8.4

namespace eval mfjIntrpr {
    variable version 1.0

    # Define an array specific to the host
    variable host
    array set host {
        ID "" User "" Email "" ESuffix "" JobSched "" STPath "" STLicn ""
        STLib "" AllSTVer ""
    }

    # Define a big array to handle all data exchange
    variable arr
    array set arr {
        Head "" Tail "" RawVarName "" RawVarVal ""
        RawVarCmnt "" RawVarCmnt1 "" RawVarCmnt2 "" RawVarGLst ""
        RawVarGStr "" RawSTLbl "" RawSTName "" RawSTIdx ""
        BrfVarName "" BrfVarVal ""
        FmtSimEnv "" FmtDfltSet "" FmtModTime "" FmtRegInfo ""
        FmtSTLbl "" FmtSTName "" FmtSTIdx "" FmtVarName "" FmtVarVal ""
        UpdateRaw false UpdateBrf false UpdateFmt false
        RGLvlLen 1 RegGen ""
    }
}

# mfjIntrpr::readRaw
#     Read ::SimArr(FVarRaw) and update the following variables in arr:
#     RawVarName RawVarVal RawVarCmnt RawVarCmnt1 RawVarCmnt2 RawVarGLst
#     RawVarGStr RawSTLbl RawSTName RawSTIdx Tail
#     It is safer to assign value to a global variable
#     Strictly treat each line as a string to preserve the original format
#     Trim the trailing blank lines
#     Use 'str2List' to properly convert a string to a list
proc mfjIntrpr::readRaw {} {
    variable arr
    vputs "Reading the raw variable file '$::SimArr(FVarRaw)'..."
    if {[catch {iFileExists ::SimArr(FVarRaw)}]} {
        error "'$::SimArr(FVarRaw)' missing in directory '[file tail [pwd]]'!"
    }

    # Set the following indentation as 2 (8 spaces)
    set mfjProc::arr(Indent1) 2
    foreach Elm [list ReadCmnt ReadGrm ReadVar UpdateVar ReadHead ReadTail\
        ReadTool UpdateTool] {
        upvar 0 $Elm Alias
        set Alias false
    }

    # It is safer to assign values to global variables
    foreach Elm [list VarName VarVal VarCmnt VarCmnt1 VarCmnt2 VarGStr\
        VarGLst STLbl STName STIdx Cmnt1 Cmnt2] {
        upvar 0 $Elm Alias
        set Alias ""
    }

    # Read all lines to memory as the variable file is small
    set Inf [open $::SimArr(FVarRaw) r]
    set Lines [split [read $Inf] \n]
    close $Inf

    # Strictly treat each line as a string only insted of a list
    set LineIdx 0
    set LineEnd [llength $Lines]
    incr LineEnd -1

    # Offset Idx to -1 to match ::SimArr(FVarFmt)
    set Idx -1
    foreach Line $Lines {

        # Remove right side spaces for each line
        set Line [string trimright $Line]

        # Three scenarios: ID line, comment line, and other lines
        if {[regexp -nocase {^\s*<(HEAD|COMMENT|GRAMMAR|VAR|TOOL|TAIL)>(.+)}\
            $Line -> ID Str]} {
            switch -regexp -- $ID {
                (?i)HEAD {
                    if {$arr(Head) eq ""} {
                        vputs -v2 -i-1 "Reading the file head..."
                        set ReadHead true
                        set HStr $Str
                    }
                }
                (?i)COMMENT {
                    set ReadCmnt true
                    set Cmnt $Str

                    # The 1st <COMMENT>
                    if {[llength $VarName] == 0} {
                        if {$arr(Head) eq ""} {
                            if {$ReadHead} {
                                set ReadHead false
                                set arr(Head) [string trim $HStr]
                                vputs -v3 -c <HEAD>$arr(Head)\n
                                vputs -v2 -i-1 "Reading simulation variables..."
                            } else {

                                # No <HEAD> found, update the variable file
                                set arr(Head) "--- Describe your simulation"
                                set arr(UpdateRaw) true
                            }
                        }
                    } else {;# The rest <COMMENT>

                        # Deal with the previous <TOOL> or <VAR>
                        if {$ReadTool} {
                            set ReadTool false
                            set UpdateTool true
                        } elseif {$ReadVar} {;# VarStr is dealt later
                            set ReadVar false
                            set UpdateVar true
                        } else {
                            error "variable missing before line [incr LineIdx]!"
                        }
                    }
                }
                (?i)GRAMMAR {
                    set ReadGrm true
                    set GrmStr $Str

                    # Deal with the previous <COMMENT>
                    if {$ReadCmnt} {
                        set ReadCmnt false
                        lappend VarCmnt [string trim $Cmnt]
                        vputs -v3 -c <COMMENT>[lindex $VarCmnt end]\n
                    } else {
                        error "comment missing before line [incr LineIdx]!"
                    }
                }
                (?i)VAR {
                    set ReadVar true
                    set VarStr $Str
                    lappend VarCmnt1 $Cmnt1
                    set Cmnt1 ""

                    # Deal with the previous <GRAMMAR>
                    if {$ReadGrm} {
                        set ReadGrm false
                    } else {
                        error "grammar missing before line [incr LineIdx]!"
                    }
                }
                (?i)TOOL {
                    set ReadTool true
                    set STStr $Str

                    # Deal with the previous <VAR>
                    if {$ReadVar} {;# VarStr is dealt later
                        set ReadVar false
                        set UpdateVar true
                    } else {
                        error "variable missing before line [incr LineIdx]!"
                    }
                }
                default {;# Tail
                    set ReadTail true
                    set TStr [string trim $Str]

                    # Deal with the previous <VAR> or <TOOL>
                    if {$ReadVar} {
                        set ReadVar false
                        set UpdateVar true
                    } elseif {$ReadTool} {
                        set ReadTool false
                        set UpdateTool true
                    } else {
                        error "variable missing before line [incr LineIdx]!"
                    }
                }
            }
        } elseif {[regexp {^\s*#} $Line]} {
            if {$ReadVar} {
                if {$Cmnt2 eq ""} {
                    set Cmnt2 $Line
                } else {
                    append Cmnt2 \n$Line
                }
            } else {
                if {$Cmnt1 eq ""} {
                    set Cmnt1 $Line
                } else {
                    append Cmnt1 \n$Line
                }
            }
        } else {

            # Ignore lines before <HEAD>
            foreach Elm {ReadHead ReadCmnt ReadGrm ReadVar ReadTool ReadTail}\
                Str {HStr Cmnt GrmStr VarStr STStr TStr} {
                upvar 0 $Elm Alias
                if {$Alias} {

                    # Preserve the original format of each line
                    append $Str \n$Line
                    break
                }
            }
        }

        # Last line
        if {$LineIdx == $LineEnd} {
            if {$ReadCmnt} {
                error "grammar missing before the last line!"
            } elseif {$ReadGrm} {
                error "variable missing before the last line!"
            } elseif {$ReadVar} {
                set UpdateVar true

                # No <TAIL> found, update the variable file
                set arr(Tail) "--- No variables afterwards"
                set arr(UpdateRaw) true
            } elseif {$ReadTool} {
                set UpdateTool true

                # No <TAIL> found, update the variable file
                set arr(Tail) "--- No variables afterwards"
                set arr(UpdateRaw) true
            } elseif {$ReadTail} {
                set arr(Tail) $TStr
            } else {
                error "invalid '$::SimArr(FVarRaw)'!"
            }
        }
        if {$UpdateTool} {

            # Replace multiple spaces within the sentence with a single space
            set STStr [regsub -all {\s+} $STStr " "]
            if {[regexp -nocase ^$::SimArr(STDfltID)$ [string trim $STStr]\
                -> Lbl Tool]} {

                # Check against pre-defined tool names
                set Tmp [lsearch -regexp $::SimArr(STTools) (?i)^$Tool$]
                if {$Tmp == -1} {
                    error "unknown ST tool '$Tool'!"
                } else {
                    lappend STName [lindex $::SimArr(STTools) $Tmp]
                }

                # Update the case for tool label by checking the command file
                set FCmd $Lbl[lindex $::SimArr(STSuffix) $Tmp]
                if {[catch {iFileExists FCmd}]} {
                    error "invalid tool label '$Lbl'!"
                } else {
                    set Lbl [string range $FCmd 0 end-8]
                }
                lappend STLbl $Lbl
                lappend STIdx $Idx
                vputs -v3 "ST tool: '[lindex $STName end]'\tlabel:\
                    '$Lbl'\tindex: '$Idx'\n"
            } else {
                error "invalid ST settings '$STStr'!"
            }
            if {$ReadTail} {
                vputs -v2 -i-1 "Reading the file tail..."
            }
            set UpdateTool false
        }
        if {$UpdateVar} {
            if {[llength $VarStr] == 0} {
                error "no variable and value!"
            } elseif {[llength $VarStr] == 1} {
                error "no value assigned to variable '$VarStr'!"
            } else {

                # Valid variable name: [a-zA-Z0-9_]
                set Var [lindex $VarStr 0]
                if {![regexp {^\w+$} $Var]} {
                    error "invalid variable name '$Var'. only characters\
                        'a-zA-Z0-9_' are allowed!"
                }

                # Update the case for each variable name
                set Tmp [lsearch -inline -regexp $::SimArr(VarName) (?i)^$Var$]
                if {$Tmp eq ""} {
                    vputs "warning: variable name '$Var' not found in\
                        '::SimArr(VarName)' of '11ctrlsim.tcl'!"
                } else {
                    set Var $Tmp
                }

                # Properly convert a grammar string to a list
                lappend VarGStr [string trim $GrmStr]
                vputs -v3 -c <GRAMMAR>[lindex $VarGStr end]\n
                lappend VarGLst [str2List "$Var: Grammar" $GrmStr]
                if {[lindex $VarCmnt1 end] ne ""} {
                    vputs -v3 -c [lindex $VarCmnt1 end]\n
                }

                # Convert strings properly to lists for variable values
                # in spite of levels of nesting
                # For variable 'SimEnv', multiple levels are dropped
                if {[llength $VarStr] == 2
                    || [string equal -nocase $Var SimEnv]} {
                    lappend VarName $Var
                    lappend VarVal [str2List "$Var: Value" [lindex $VarStr 1]]
                } else {
                    lappend VarName $Var<mfj>
                    lappend VarVal [str2List "$Var: Value"\
                        [lrange $VarStr 1 end]]
                }
            }
            lappend VarCmnt2 $Cmnt2
            if {$Cmnt2 ne ""} {
                vputs -v3 -c $Cmnt2\n
            }
            set Cmnt2 ""
            if {$ReadTail} {
                vputs -v2 -i-1 "Reading the file tail..."
            }
            set UpdateVar false
            incr Idx
        }
        incr LineIdx
    }
    set mfjProc::arr(Indent1) 0
    if {[llength $VarName]} {

        # Case-insensitive lsort (find duplicate variables)
        set Tmp [lsort -unique [string tolower $VarName]]
        if {[llength $VarName] ne [llength $Tmp]} {
            error "no duplicate variable name allowed!"
        }
        foreach Elm [list VarName VarVal VarCmnt VarCmnt1 VarCmnt2 VarGStr\
            VarGLst STLbl STName STIdx] {
            upvar 0 $Elm Alias
            set arr(Raw$Elm) $Alias
        }
    } else {
        error "no variables in '$::SimArr(FVarRaw)'!"
    }

    # Remove trailing blank lines in the tail section
    set arr(Tail) [string trim $arr(Tail)]
    vputs -v3 -c <TAIL>$arr(Tail)
    vputs
}

# mfjIntrpr::readBrf
    # Read variables and their values if the brief version exists and
    # is more recent than ::SimArr(FVarRaw)
    # The brief version only has variables and their value
    # There is no way to distinguish environment and simulation variables
    # So the environment variables have to be placed in front
proc mfjIntrpr::readBrf {} {
    variable arr
    set FVarBrf [file rootname $::SimArr(FVarRaw)]-brief.txt
    vputs "Reading the brief TXT file '$FVarBrf'..."
    if {[catch {iFileExists FVarBrf}]} {
        vputs -i1 "The brief TXT file '$FVarBrf' not found!"
        set arr(UpdateBrf) true
    } else {
        set mfjProc::arr(Indent1) 1

        # Read all lines to memory for a small text file
        set Inf [open $FVarBrf r]
        set Lines [split [read $Inf] \n]
        close $Inf

        # Strictly treat each line as a string only insted of a list
        # Each variable should be seperated at least a blank or comment line
        # Comment lines are skipped and will not be saved when updating the file
        set LineIdx 0
        set LineEnd [llength $Lines]
        incr LineEnd -1
        set Str ""
        set VarVal [list]
        foreach Line $Lines {

            # Trim leading and trailing spaces
            set Line [string trim $Line]
            set Char [string index $Line 0]
            if {$Char ne "#" && $Line ne ""} {
                append Str " $Line"
            }

            # String list duality
            # Three conditions to extract variables values: comment line,
            # blank line or the last line
            if {$Char eq "#" || $Line eq "" || $LineIdx == $LineEnd} {
                if {[llength $Str] == 0} {
                    continue
                }
                if {[llength $Str] == 1} {
                    error "no value assigned to variable '$Str'!"
                }

                # Valid variable name: [a-zA-Z0-9_]
                set Var [lindex $Str 0]
                if {![regexp {^\w+$} $Var]} {
                    error "invalid variable name '$Var'. only characters\
                        'a-zA-Z0-9_' are allowed!"
                }

                # Update the case for each variable name
                set Tmp [lsearch -inline -regexp $::SimArr(VarName) (?i)^$Var$]
                if {$Tmp eq ""} {
                    vputs "warning: variable name '$Var' not found in\
                        '::SimArr(VarName)' of '11ctrlsim.tcl'!"
                } else {
                    set Var $Tmp
                }

                # Convert strings properly to lists for values
                if {[llength $Str] == 2
                    || [string equal -nocase $Var SimEnv]} {
                    lappend arr(BrfVarName) $Var
                    lappend VarVal [str2List "$Var:" [lindex $Str 1]]
                } else {
                    lappend arr(BrfVarName) $Var<mfj>
                    lappend VarVal [str2List "$Var:" [lrange $Str 1 end]]
                }
                set Str ""
            }
            incr LineIdx
        }
        set mfjProc::arr(Indent1) 0
        if {[llength $arr(BrfVarName)]} {

            # Case-insensitive lsort
            set Tmp [lsort -unique [string tolower $arr(BrfVarName)]]
            if {[llength $arr(BrfVarName)] ne [llength $Tmp]} {
                error "no duplicate variable name allowed!"
            }
        } else {
            error "no variables in '$FVarBrf'!"
        }
        set arr(BrfVarVal) $VarVal
    }
    vputs
}

# mfjIntrpr::rawvsBrf
    # Compare ::SimArr(FVarRaw) against the brief version
proc mfjIntrpr::rawvsBrf {} {
    variable arr
    if {$arr(UpdateBrf)} {
        set arr(BrfVarName) $arr(RawVarName)
        set arr(BrfVarVal) $arr(RawVarVal)
    } else {
        set FVarBrf [file rootname $::SimArr(FVarRaw)]-brief.txt
        vputs "Comparing '$::SimArr(FVarRaw)' against '$FVarBrf'..."

        # A user can only modify a value for a variable in the brief version
        # Adding or removing a variable can only be done in the variable file
        if {[llength $arr(BrfVarName)] != [llength $arr(RawVarName)]} {
            set arr(UpdateBrf) true
            vputs -i1 "Variable # '[llength $arr(BrfVarName)]' different\
                from '[llength $arr(RawVarName)]'!"
        } else {
            foreach BVar $arr(BrfVarName) BVal $arr(BrfVarVal) {
                if {[regexp ^(\\w+)<mfj>$ $BVar -> Tmp]} {
                    set Var $Tmp
                } else {
                    set Var $BVar
                }

                # Variables should be the same as those in ::SimArr(FVarRaw)
                set Idx [lsearch -regexp $arr(RawVarName) ^${Var}(<mfj>)?$]
                if {$Idx == -1} {
                    set arr(UpdateBrf) true
                    vputs -i1 "Variable '$BVar' not found in\
                        '$::SimArr(FVarRaw)'!"
                    break
                } else {

                    # Only show changes here without actually doing it
                    if {![string equal -nocase $BVal\
                        [lindex $arr(RawVarVal) $Idx]]} {
                        vputs -v2 -i1 "'$BVal' in $FVarBrf\
                            different from '[lindex $arr(RawVarVal) $Idx]'!"
                        if {[file mtime $FVarBrf]
                            < [file mtime $::SimArr(FVarRaw)]} {
                            set arr(UpdateBrf) true
                        } else {
                            set arr(UpdateRaw) true
                            vputs -v2 -i1 "Simulation variable '$BVar' updated!"
                        }
                    }
                }
            }
        }

        if {$arr(UpdateBrf) || $arr(UpdateRaw)} {
            if {$arr(UpdateBrf)} {
                vputs -i1 "'$::SimArr(FVarRaw)' is newer than '$FVarBrf'!"
                set arr(BrfVarName) $arr(RawVarName)
                set arr(BrfVarVal) $arr(RawVarVal)
            }
            if {$arr(UpdateRaw)} {
                vputs -i1 "'$FVarBrf' is newer than '$::SimArr(FVarRaw)'!"
                foreach Elm {VarName VarVal VarCmnt VarCmnt1 VarCmnt2
                    VarGLst VarGStr} {
                    set $Elm [list]
                }
                foreach BVar $arr(BrfVarName) BVal $arr(BrfVarVal) {
                    if {[regexp ^(\\w+)<mfj>$ $BVar -> Tmp]} {
                        set Var $Tmp
                    } else {
                        set Var $BVar
                    }
                    lappend VarName $BVar
                    lappend VarVal $BVal
                    set Idx [lsearch -regexp $arr(RawVarName) ^${Var}(<mfj>)?$]
                    lappend VarCmnt [lindex $arr(RawVarCmnt) $Idx]
                    lappend VarCmnt1 [lindex $arr(RawVarCmnt1) $Idx]
                    lappend VarCmnt2 [lindex $arr(RawVarCmnt2) $Idx]
                    lappend VarGStr [lindex $arr(RawVarGStr) $Idx]
                    lappend VarGLst [lindex $arr(RawVarGLst) $Idx]
                }
                foreach Elm {VarName VarVal VarCmnt VarCmnt1 VarCmnt2
                    VarGLst VarGStr} {
                    upvar 0 $Elm Alias
                    set arr(Raw$Elm) $Alias
                }
                vputs -v3 -i1 "\nOutput update raw variables for\
                    verification..."
                foreach Var $arr(RawVarName) Val $arr(RawVarVal)\
                    Cmnt $arr(RawVarCmnt) Cmnt1 $arr(RawVarCmnt1)\
                    Cmnt2 $arr(RawVarCmnt2) Str $arr(RawVarGStr)\
                    Lst $arr(RawVarGLst) {
                    vputs -v3 -c -s "<COMMENT>$Cmnt\n\n<GRAMMAR>$Str\n\n$Lst\n"
                    if {$Cmnt1 ne ""} {
                        vputs -v3 -c $Cmnt1\n
                    }
                    vputs -v3 -c "<VAR>$Var \{$Val\}\n"
                    if {$Cmnt2 ne ""} {
                        vputs -v3 -c $Cmnt2\n
                    }
                }
            }
        } else {
            vputs -i1 "'$::SimArr(FVarRaw)' is the same as '$FVarBrf'!"
        }
        vputs
    }
}

# mfjIntrpr::readHost
#   Read simulator settings on the current host
proc mfjIntrpr::readHost {} {
    variable host
    set host(ID) [lindex [split $::env(HOSTNAME) .] 0]
    vputs "Extracting settings from host '$host(ID)'..."
    set host(User) $::env(USER)
    vputs -v3 -i1 "User: $host(User)"
    foreach Name $::SimArr(STHosts) Sufx $::SimArr(ESuffix) {
        if {[string index $Name 0] eq [string index $host(ID) 0]} {
            set host(ESuffix) $Sufx
            break
        }
    }

    # Email format: local-part@domain
    # local-part: \w!#$%&'*+-/=?^_`{|}~.
    # domain: \w-
    if {![regexp {([\w.%+-]+@(\w+[\.-])+[a-zA-Z]{2,4})}\
        [exec getent passwd $host(User)] -> host(Email)]} {
        set host(Email) $host(User)@$host(ESuffix)
    }
    vputs -v3 -i1 "Email: $host(Email)"

    # Check available job schedulers
    if {[eval {auto_execok qsub}] ne ""} {
        lappend host(JobSched) PBS
    }
    if {[eval {auto_execok sbatch}] ne ""} {
        lappend host(JobSched) SLURM
    }
    vputs -v3 -i1 "Job scheduler available: $host(JobSched)"

    # Retrieve Sentaurus TCAD related settings
    set FoundPath true
    if {[info exists ::env(STROOT)] && [info exists ::env(LM_LICENSE_FILE)]} {
        set host(STPath) [file dirname $::env(STROOT)]
        set host(STLicn) [lindex [split $::env(LM_LICENSE_FILE) :] 0]
    } else {
        foreach Name $::SimArr(STHosts) Path $::SimArr(STPaths)\
            Licn $::SimArr(STLicns) {
            if {[string index $Name 0] eq [string index $host(ID) 0]} {
                if {[string index $Path end] eq "/"} {
                    set Path [string range $Path 0 end-1]
                }
                set host(STPath) $Path
                set host(STLicn) $Licn
                break
            }
        }
    }
    vputs -v3 -i1 "ST license: $host(STLicn)"
    foreach Name $::SimArr(STHosts) Lib $::SimArr(STLib) {
        if {[string index $Name 0] eq [string index $host(ID) 0]
            && [iFileExists Lib]} {
            set host(STLib) $Lib
            break
        }
    }
    vputs -v3 -i1 "ST shared libraries: $host(STLib)"

    # Check Sentaurus TCAD path
    if {[catch {iFileExists host(STPath)}]} {
        set FoundPath false
        vputs -v3 -i1 "ST path: Invalid '$host(STPath)'"
    } else {
        if {![file isdirectory $host(STPath)]} {
            set FoundPath false
            vputs -v3 -i1 "ST path: Invalid '$host(STPath)'"
        } else {
            vputs -v3 -i1 "ST path: $host(STPath)"
        }
    }

    # Find available Sentaurus TCAD versions
    if {$FoundPath} {
        foreach Elm [glob -nocomplain -directory $host(STPath) *] {
            set Elm [string toupper [file tail $Elm]]
            if {[regexp {^[A-Z]+-[0-9]{4}\.[0-9]{2}} $Elm]} {
                lappend host(AllSTVer) $Elm
            }
        }
    }
    set host(AllSTVer) [lsort $host(AllSTVer)]
    vputs -v3 -i1 "ST versions: $host(AllSTVer)"
    vputs
}

# mfjIntrpr::actConvFeat
    # Check arr(RawVarVal) and arr(RawVarGLst) to activate the override and
    # then recycle features if necessary.
proc mfjIntrpr::actConvFeat {} {
    variable arr

    vputs "Activate overriding in simulation variables if any..."
    set NewLst [list]
    set Sum 0
    foreach SimName $arr(RawVarName) SimVal $arr(RawVarVal) {

        # Only check variables with multiple levels
        if {[regexp ^(\\w+)<mfj>$ $SimName -> VarName]} {
            set NewVal [override $VarName $SimVal]
            if {[lindex $NewVal 0]} {
                vputs -v2 -i1 "$VarName: [lindex $NewVal 0] overrides detected!"
                vputs -v2 -c "Before: \{$SimVal\}"
                vputs -v2 -c "After: \{$[lindex $NewVal 1]\}\n"
                incr Sum [lindex $NewVal 0]
            }
            lappend NewLst [lindex $NewVal 1]
        } else {
            lappend NewLst $SimVal
        }
    }
    if {$Sum} {
        set arr(RawVarVal) $NewLst
        vputs -i1 "Totally $Sum overriding features activated!"
    } else {
        vputs -i1 "No override found!"
    }
    vputs

    vputs "Activate recycling in all variables if any..."
    set Sum 0
    foreach Var [list RawVarName RawVarName] Val [list RawVarGLst RawVarVal] {
        set NewLst [list]
        set Update false
        foreach SimName $arr($Var) SimVal $arr($Val) {
            regexp ^(\\w+)(<mfj>)?$ $SimName -> VarName Flg
            set Cnt [regexp -all {@(-?\d+[:,/&])*-?\d+} $SimVal]
            if {$Cnt} {
                vputs -v2 -i1 "$VarName: $Cnt recycles detected!"
                vputs -v2 -c "Before: \{$SimVal\}"

                # No multiple levels for grammar rules
                if {$Flg ne "" && $Val eq "RawVarVal"} {
                    set NewVal [list]
                    set Lvl 0
                    foreach LvlVal $SimVal {
                        lappend NewVal [recycle $VarName $LvlVal $LvlVal $Lvl]
                        incr Lvl
                    }
                } else {
                    set NewVal [recycle $VarName $SimVal $SimVal]
                }
                vputs -v2 -c "After: \{$NewVal\}\n"
                set Update true
                incr Sum $Cnt
                lappend NewLst $NewVal
            } else {
                lappend NewLst $SimVal
            }
        }
        if {$Update} {
            set arr($Val) $NewLst
        }
    }
    if {$Sum} {
        vputs -i1 "Totally $Sum recycling features activated!"
    } else {
        vputs -i1 "No recycling found!"
    }
    vputs
}

# mfjIntrpr::valSimEnv
#   Find and set the environment variable 'SimEnv' to be the first variable.
#   Update rules such as simulator versions and job scheduler
proc mfjIntrpr::valSimEnv {} {
    variable arr
    variable host
    vputs "Alter the sequence for environment variable 'SimEnv' if necessary..."

    vputs -i1 -n "Searching for environment variable 'SimEnv'..."
    set Idx [lsearch -exact $arr(RawVarName) SimEnv]
    if {$Idx == -1} {
        error "missing environment variable 'SimEnv' in '$::SimArr(FVarRaw)'!"
    } else {
        vputs -c " found at index '$Idx'!"
    }
    if {$Idx != 0} {
        vputs -i1 "Set 'SimEnv' to index '0'..."
        foreach Elm [list RawVarName RawVarVal RawVarGStr RawVarGLst\
            RawVarCmnt RawVarCmnt1 RawVarCmnt2] {
            set arr($Elm) [concat [lrange $arr($Elm) $Idx $Idx]\
                [lrange $arr($Elm) 0 [incr Idx -1]]\
                [lrange $arr($Elm) [incr Idx 2] end]]
        }
    } else {
        vputs -i1 "No change!"
    }

    vputs "\nUpdate grammar for 'SimEnv' if necessary..."

    # Check and update job scheduler settings in 'SimEnv'
    set UpdateGrm false
    set SimEnvGrm [lindex $arr(RawVarGLst) 0]
    if {$host(AllSTVer) eq ""} {
        error "no ST version available!"
    }

    # Set the default version to the latest (a == latest)
    if {[lindex $SimEnvGrm 1 2] ne [lindex $host(AllSTVer) end]} {
        set UpdateGrm true
        lset SimEnvGrm 1 2 [lindex $host(AllSTVer) end]
    }

    # Sentaurus TCAD versions in the grammar vs available
    set Diff false
    set AllSTVer [string map {< "" > ""} [lrange [lindex $SimEnvGrm 1] 5 end]]
    if {[llength $AllSTVer] == [llength $host(AllSTVer)]} {
        foreach Elm $AllSTVer {
            if {[lsearch -exact -sorted $host(AllSTVer) $Elm] == -1} {
                set Diff true
                break
            }
        }
    } else {
        set Diff true
    }
    if {$Diff} {
        set UpdateGrm true
        set Lst ""
        foreach Elm $host(AllSTVer) {
            lappend Lst [string map {- <-} $Elm]>
        }
        lset SimEnvGrm 1 [concat [lrange [lindex $SimEnvGrm 1] 0 4] $Lst]
    }

    if {$host(JobSched) eq ""} {
        if {[llength $SimEnvGrm] >= 7
            && [llength [lindex $SimEnvGrm 6]] >= 6
            && ![string equal -nocase [lindex $SimEnvGrm 6 5] Local]} {
            set UpdateGrm true
            lset SimEnvGrm 6 {a = Local | s Local}
        }
    } else {
        set Lst ""
        foreach Elm $host(JobSched) {
            lappend Lst [string index $Elm 0]<[string range $Elm 1 end]>
        }
        if {![string equal -nocase [lrange [lindex $SimEnvGrm 6] 5 end]\
            "$Lst Local"]} {
            set UpdateGrm true
            lset SimEnvGrm 6 "a = Local | s $Lst Local"
        }
    }

    # Output the grammar of 'SimEnv' if updated
    if {$UpdateGrm} {
        set arr(UpdateRaw) true
        lset arr(RawVarGLst) 0 $SimEnvGrm
        set Idx 0
        set Str ""
        foreach Elm $SimEnvGrm {
            if {$Idx == 0} {
                append Str [wrapText \{$Elm\}]
            } else {
                append Str [wrapText \n\{$Elm\}]
            }
            incr Idx
        }
        lset arr(RawVarGStr) 0 $Str
        vputs -i1 "Updated 'SimEnv' grammar: [lindex $arr(RawVarGLst) 0]"
    } else {
        vputs -i1 "No update!"
    }

    vputs "\nValidating 'SimEnv'..."
    set SimEnvVal [lindex $arr(RawVarVal) 0]
    vputs -v3 -i1 "Before validation: \{$SimEnvVal\}"

    # Use the string/list duality to flatten a list of any nested levels
    set SimEnvVal [string map {\{\} \"\" \{ "" \} ""} $SimEnvVal]

    # Revert '""' to '{}'
    set SimEnvVal [string map {\"\" \{\}} $SimEnvVal]
    set SimEnvVal [mfjGrm::applyGrm $SimEnvVal $SimEnvGrm]
    vputs -v3 -i1 "After validation: \{$SimEnvVal\}"
    lset arr(RawVarVal) 0 $SimEnvVal
    vputs

    # Extract material database from the selected software version
    if {[string equal -nocase [lindex $arr(RawVarVal) 0 0] Sentaurus]} {
        vputs "Identifying material database from\
            [lindex $arr(RawVarVal) 0 0] [lindex $arr(RawVarVal) 0 1]..."
        set FMat $host(STPath)/[lindex $arr(RawVarVal) 0 1]/tcad/[lindex\
            $arr(RawVarVal) 0 1]/lib/datexcodes.txt
        set ::SimArr(MatDB) [readMatDB datexcodes.txt $FMat]
        vputs
    }
}

# mfjIntrpr::alterSimVar
    # Alter the sequence for simulation variables. If simulation variable
    # 'RegGen' is found, set it as the second if not. Additionally,
    # sort variables so that 'RegGen' is followed immediately by the rest
    # region related variables
proc mfjIntrpr::alterSimVar {} {
    variable arr
    vputs "Alter the sequence for simulation variables if necessary..."

    vputs -i1 -n "Searching for simulation variable 'RegGen'..."
    set Idx [lsearch -regexp $arr(RawVarName) ^RegGen(<mfj>)?$]
    if {$Idx == -1} {
        foreach GLst $arr(RawVarGLst) {
            if {[regexp -nocase {^`?r} [lindex $GLst 0]]} {
                error "missing simulation variable 'RegGen' in\
                    '$::SimArr(FVarRaw)'!"
            }
        }
        vputs -c " failed!"
    } else {
        vputs -c " found at index '$Idx'!"
        if {$Idx != 1} {
            vputs -i1 "Set 'RegGen' to index '1'..."
            set Idx1 [expr {$Idx-1}]
            set Idx2 [expr {$Idx+1}]
            foreach Elm [list RawVarName RawVarVal RawVarGStr RawVarGLst\
                RawVarCmnt RawVarCmnt1 RawVarCmnt2] {
                set arr($Elm) [concat [lrange $arr($Elm) 0 0]\
                    [lrange $arr($Elm) $Idx $Idx] [lrange $arr($Elm) 1 $Idx1]\
                    [lrange $arr($Elm) $Idx2 end]]
            }
        } else {
            vputs -i1 "No change!"
        }

        # 'RegGen' has splits
        if {[regexp ^\\w+<mfj>$ [lindex $arr(RawVarName) 1]]} {
            vputs "\nMultiple levels detected for 'RegGen'..."

            # Update levels for 'RegGen'
            set arr(RGLvlLen) [llength [lindex $arr(RawVarVal) 1]]
        }
    }
    vputs
}


# mfjIntrpr::valSimVar
    # Validate each simulation variables according to their grammar settings.
    # Due to added complexity, 'RegGen' requires further validation and
    # conversion in addition to the existing grammar rules. Furthermore,
    # contacts are extracted from 'IntfAttr' and the total # of ramping
    # variables are determined from 'VarVary'
    # Key thoughts:
    # 1. Validate values but refrain from expanding
    # 2. For subgroup variables, remove duplicates
    # 3. Additional info is updated to simArr and assigned to internal variables
    # 4. Expansion of "r" variables is no longer necessary (default behavior
    #    will be implemented in simulator instead)
proc mfjIntrpr::valSimVar {} {
    variable arr
    vputs "Validating simulation variables..."
    set ::SimArr(ModTime) ""
    set SimIdx 0

    # Correct the index considering 'SimEnv' and 'RegGen'
    foreach Elm [list RawVarName RawVarVal RegInfo RegMat RegIdx\
        ConLst ConLen VarLen] {
        upvar 0 $Elm Alias
        set Alias [list]
    }
    foreach VarName $arr(RawVarName) VarVal $arr(RawVarVal)\
        VarGrm $arr(RawVarGLst) {

        # Skip 'SimEnv'
        if {$SimIdx == 0} {
            lappend RawVarName $VarName
            lappend RawVarVal $VarVal
            incr SimIdx
            continue
        }

        # Deal with multiple levels if any
        # Users are responsible for assigning multiple levels to 'RegGen'
        if {[regexp ^(\\w+)<mfj>$ $VarName -> Var]} {
            set LvlLen [llength $VarVal]
            set RGLvlLen $arr(RGLvlLen)
            if {$Var eq "RegGen"} {
                set RGLvlLen 1
            }
        } else {
            set Var $VarName
            set LvlLen 1
            set RGLvlLen 1
        }
        vputs -i1 '$Var':

        # If 'RegGen' has multiple levels, region related variables should have
        # the same levels. For other variables, however, set RGLvlLen to 1
        # if {$SimIdx >= 2 && $LvlLen > 1} {
            # set RGLvlLen $arr(RGLvlLen)
        # } else {
            # set RGLvlLen 1
        # }

        # Outer loop: variable levels; Inner loop: 'RegGen' levels
        set VarMsg "variable '$Var'"
        set NewLst [list]
        set LvlIdx -1
        for {set i 0} {$i < $LvlLen} {incr i} {

            # Use the string/list duality to flatten a list of any nested levels
            if {$LvlLen == 1} {
                set OldLvl [string map {\{\} \"\" \{ "" \} ""} $VarVal]
            } else {
                set OldLvl [string map {\{\} \"\" \{ "" \} ""}\
                    [lindex $VarVal $i]]
            }

            # Revert '""' to '{}'
            set OldLvl [string map {\"\" \{\}} $OldLvl]
            for {set j 0} {$j < $RGLvlLen} {incr j} {

                # For the column mode, skip other combinations for region
                # related variables
                if {[string equal -nocase $::SimArr(ColMode) ColMode]
                    && $LvlLen == $RGLvlLen && $i != $j} {
                    continue
                }
                if {$LvlLen > 1} {
                    if {$RGLvlLen == 1} {
                        vputs -v3 -i2 "Level '[incr LvlIdx]':"
                    } else {
                        vputs -v3 -i2 "Level '[incr LvlIdx]'(RegGen level $j):"
                    }
                }

                # Validate a variable if its format is present
                if {[llength $VarGrm]} {
                    vputs -v3 -c "Before: \{$OldLvl\}"
                    if {[llength [lindex $VarGrm 0]]} {

                        # Split elements for group IDs 'b', 'm', 'v', 'p', 'r',
                        # 'o', 'pp' and 'rr'
                        # string -> list -> sort in increasing order
                        set Grm0 [lsort [string tolower\
                            [string map {` "" | " "} [lindex $VarGrm 0]]]]
                        set Cnt 0
                        foreach Elm $Grm0 {
                            if {[regexp {^(b|m|o|p|pp|r|rr|v)$} $Elm]} {
                                incr Cnt
                            }
                        }
                        if {[llength $Grm0] == $Cnt} {
                            set GID true
                        } else {
                            if {$Cnt} {
                                error "unknown group ID found in\
                                    '[lindex $VarGrm 0]'!"
                            }
                            set GID false
                        }
                    } else {
                        set GID false
                    }
                    if {$GID} {
                        set ::SimArr(RegLvl) $j
                        set ::SimArr(DimLen) [llength\
                            [lindex $::SimArr(RegInfo) $j 0 1]]
                        if {[llength $OldLvl]} {
                            set NewLvl [valSplit $Var $OldLvl $Grm0\
                                $LvlIdx $LvlLen]
                        } else {
                            set NewLvl $OldLvl
                        }
                        vputs -v3 -c "valSplit: \{$NewLvl\}"
                        set GrpLen [llength $NewLvl]
                    } else {
                        set GrpLen 1
                    }

                    # Apply formats to each element in a list or sublist
                    set Lst [list]
                    for {set k 0} {$k < $GrpLen} {incr k} {
                        if {$GID} {
                            set Val [lindex $NewLvl $k]
                            lappend Lst [mfjGrm::applyGrm $Val $VarGrm]
                        } else {
                            set Lst [mfjGrm::applyGrm $OldLvl $VarGrm]
                        }
                    }
                    vputs -v3 -c "After validation: \{$Lst\}"
                    vputs -v3 ""
                } else {
                    set Lst $OldLvl
                }
                if {$LvlLen == 1 && $RGLvlLen == 1} {
                    set NewLst $Lst
                } else {
                    lappend NewLst $Lst
                }
            }
        }

        # Validate 'RegGen' further if present
        if {$SimIdx == 1 && $Var eq "RegGen"} {
            lset arr(RawVarVal) 1 $NewLst
            valRegGen
            set NewLst $arr(RegGen)
        }

        # Extract contacts from 'IntfAttr' if present
        if {$Var eq "IntfAttr"} {
            if {$Var eq $VarName} {
                foreach Elm $NewLst {
                    if {[regexp {^c\d$} [lindex $Elm 1]]} {
                        lappend ConLst [lindex $Elm 1]
                    }
                }

                # Retain the last duplicate found
                set ConLst [lsort -unique $ConLst]
                set ConLen [llength $ConLst]
            } else {
                foreach Lst $NewLst {
                    set Tmp [list]
                    foreach Elm $Lst {
                        if {[regexp {^c\d$} [lindex $Elm 1]]} {
                            lappend Tmp [lindex $Elm 1]
                        }
                    }
                    set Tmp [lsort -unique $Tmp]
                }
                lappend ConLst $Tmp
                lappend ConLen [llength $Tmp]
            }
            set ::SimArr(ConLst) $ConLst
            set ::SimArr(ConLen) $ConLen
        }

        # Get the # of variables in 'VarVary' if present
        if {$Var eq "VarVary"} {
            if {$Var eq $VarName} {
                set VarLen [llength $NewLst]
            } else {
                foreach Lst $NewLst {
                    lappend VarLen [llength $Lst]
                }
            }
            set ::SimArr(VarLen) $VarLen
        }

        lappend RawVarName $VarName
        lappend RawVarVal $NewLst
        incr SimIdx
    }
    set arr(RawVarName) $RawVarName
    set arr(RawVarVal) $RawVarVal

    # Include key ST files in ::SimArr(ModTime)
    if {$arr(RawSTName) ne ""} {
        foreach Name $arr(RawSTName) Lbl $arr(RawSTLbl) {
            set Idx [lsearch -exact $::SimArr(STTools) $Name]
            set FCmd $Lbl[lindex $::SimArr(STSuffix) $Idx]
            if {$Name eq "sdevice"} {
                if {[file isfile sdevice.par]} {
                    lappend ::SimArr(ModTime) [list sdevice.par\
                        [file mtime sdevice.par]]
                } else {
                    error "'sdevice.par' not found!"
                }
            }
            lappend ::SimArr(ModTime) [list $FCmd [file mtime $FCmd]]
        }
    }

    # Include key TCL files, datexcodes.txt, Molefraction.txt and PMI files
    foreach Elm [concat 11ctrlsim.tcl datexcodes.txt Molefraction.txt\
        [glob -nocomplain .mfj/mfj*.tcl $::SimArr(PMIDir)/*.\[cC\]]] {
        lappend ::SimArr(ModTime) [list $Elm [file mtime $Elm]]
    }
    vputs -v3 -i1 "Files for simulation and their modification time:"

    # Only keep the last duplicate file found
    set ::SimArr(ModTime) [lsort -unique -index 0 $::SimArr(ModTime)]
    vputs -v3 $::SimArr(ModTime)
    vputs
}

# mfjIntrpr::valRegGen
    # Validate the simulation variable 'RegGen' to determine all the
    # regions and the dimensions of the simulation domain
    # This variable has a couple of region materials and their corresponding
    # dimensions while attributes are no longer supported.
    # Return 'RegGen' to its initial form and put detailed info in 'RegInfo'
proc mfjIntrpr::valRegGen {} {
    variable arr
    if {![regexp ^RegGen(<mfj>)?$ [lindex $arr(RawVarName) 1]]} {
        error "attempting to access a non-existing variable 'RegGen'!"
    }
    vputs -i2 "Further validation:"
    set VarMsg "variable 'RegGen'"
    foreach Elm [list RegInfo RegGen RegMat RegIdx] {
        set $Elm [list]
    }
    set GasThx $::SimArr(GasThx)
    set LvlLen $arr(RGLvlLen)
    set VarVal [lindex $arr(RawVarVal) 1]
    for {set i 0} {$i < $LvlLen} {incr i} {
        if {$LvlLen == 1} {
            set OldLvl $VarVal
            set Msg $VarMsg
            set Idt 3
        } else {
            vputs -i3 "Level '$i':"
            set OldLvl [lindex $VarVal $i]
            set Msg "level '$i' of $VarMsg"
            set Idt 4
        }
        set RegLen [llength $OldLvl]
        if {$RegLen == 0} {
            error "no region specified for $Msg!"
        }
        foreach Elm {YMax1 ZMax1 XMax YMax ZMax X1 X2 Y1 Y2 Z1 Z2 Lyr RegSeq
            NegSeq App1} {
            set $Elm 0
        }
        foreach Elm [list 1D 2D 3D] Tmp [list RILst RDLst MatLst IdxLst] {
            set $Elm false
            set $Tmp [list]
        }

        # Update region name and region ID with this format: material, region,
        # group, region ID. User-specified regions are indexed from 1 and
        # created from (0 0 0) to (XMax YMax ZMax). A to-be-removed region is
        # assigned a negative index and a to-be-merged region is assigned a
        # negative index suffixed with 'm'.
        set Seq 1
        set RegID ""
        foreach OldReg $OldLvl {
            set Mat [lindex $OldReg 0]
            set DimLst [lrange $OldReg 1 end]
            set Len [llength $DimLst]
            if {$Len == 0} {
                error "no dimension specified for '[lindex $Mat 0]'!"
            }

            # Regions are specified using Approach 1, which determines the
            # simulation domain. Convert Approach 1 to two diagonal points
            # for each region (1D, 2D and 3D).
            if {[string is double -strict [lindex $DimLst 0]]} {
                set App1 true
                lset Mat 1 [incr RegSeq]_[lindex $Mat 0]
                lset Mat end $RegSeq
                if {$Len == 1} {
                    if {$3D} {
                        set Z1 [format %.12g $ZMax]
                        set Z2 [format %.12g [expr {$ZMax+$DimLst}]]
                    } elseif {$2D} {
                        set Y1 [format %.12g $YMax]
                        set Y2 [format %.12g [expr {$YMax+$DimLst}]]
                    } else {
                        set 1D true
                        set X1 [format %.12g $XMax]
                        set X2 [format %.12g [expr {$XMax+$DimLst}]]
                        vputs -i$Idt "Layer [incr Lyr]:"
                    }
                } elseif {$Len == 2} {
                    if {$1D} {
                        error "dimension '$DimLst' not 1D!"
                    }
                    if {$3D} {
                        set Y1 [format %.12g $YMax]
                        set Y2 [format %.12g [expr {$YMax+[lindex $DimLst 0]}]]
                        set Z1 0
                        set Z2 [format %.12g [lindex $DimLst 1]]
                    } else {
                        set 2D true
                        set X1 [format %.12g $XMax]
                        set X2 [format %.12g [expr {$XMax+[lindex $DimLst 0]}]]
                        set Y1 0
                        set Y2 [format %.12g [lindex $DimLst 1]]
                        vputs -i$Idt "Layer [incr Lyr]:"
                    }
                } else {
                    if {$1D} {
                        error "dimension '$DimLst' not 1D!"
                    }
                    if {$2D} {
                        error "dimension '$DimLst' not 2D!"
                    }
                    set 3D true
                    set X1 [format %.12g $XMax]
                    set X2 [format %.12g [expr {$XMax+[lindex $DimLst 0]}]]
                    set Y1 0
                    set Y2 [lindex $DimLst 1]
                    set Z1 0
                    set Z2 [lindex $DimLst 2]
                    vputs -i$Idt "Layer [incr Lyr]:"
                }
                vputs -i[expr $Idt+1] $OldReg

                # If the last region, update the max size of each dimension
                if {$Seq == $RegLen} {
                    set XMax [format %.12g $X2]
                    set YMax [format %.12g $Y2]
                    set ZMax [format %.12g $Z2]
                }

                # Check alignment of the previous region in Y and Z directions
                if {($Y1 == 0 && $Z1 == 0 || $Seq == $RegLen) && $YMax > 0} {
                    if {$YMax1 == 0} {
                        set YMax1 $YMax
                    }
                    if {$YMax1 > 0 && abs($YMax1-$YMax) > 1e-7} {
                        error "YMax '$YMax' is different from the previous\
                            layer YMax '$YMax1' in $Msg!"
                    }
                }
                if {($Z1 == 0 || $Seq == $RegLen) && $ZMax > 0} {
                    if {$ZMax1 == 0} {
                        set ZMax1 $ZMax
                    }
                    if {$ZMax1 > 0 && abs($ZMax1-$ZMax) > 1e-7} {
                        error "ZMax '$ZMax' is different from the previous\
                            section ZMax '$ZMax1' in $Msg!"
                    }
                }

                # Update the max size of each dimension with the current region
                if {$Seq != $RegLen} {
                    set XMax $X2
                    set YMax $Y2
                    set ZMax $Z2
                }
            } else {

                # Regions specified using Approach 2. No alignment check so
                # users are responsible for drawing reasonable regions. Any
                # region outside of the simulation domain is trimmed
                if {$App1} {
                    error "approach 1 should come after approach 2!"
                }
                if {[lindex $DimLst 1] eq "Remove"} {
                    lset Mat 1 [incr NegSeq -1]_[lindex $Mat 0]
                    lset Mat end $NegSeq
                    set RegID $NegSeq
                } elseif {[lindex $DimLst 1] eq "Merge"} {

                    # The first region can't be labeled as "Merge"
                    if {$Seq == 1} {
                        error "1st region should be 'Keep' or 'Remove'!"
                    }
                    foreach Grp $RILst {
                        if {$RegID == [lindex $Grp 0 end]} {
                            lset Mat 1 Merge_[lindex $Grp 0 1]
                            break
                        }
                    }
                    lset Mat end $RegID
                } else {
                    lset Mat 1 [incr RegSeq]_[lindex $Mat 0]
                    lset Mat end $RegSeq
                    set RegID $RegSeq
                }

                # Make sure all points tally with the dimension
                set PStr [string range [lindex $DimLst 2] 1 end]
                set Lst [lindex $DimLst 0]
                if {[lindex $DimLst 0] eq "Block"} {

                    # Sort, verify 'pp' and convert it to 'p'
                    set Idx 0
                    set Cnt 0
                    set PPLst [split [split $PStr _] /]
                    foreach Elm1 [lindex $PPLst 0] Elm2 [lindex $PPLst 1] {
                        incr Cnt [expr $Elm1 == $Elm2]

                        # Sort and format each number properly
                        set Tmp [lsort -real [list $Elm1 $Elm2]]
                        lset PPLst 0 $Idx [lindex $Tmp 0]
                        lset PPLst 1 $Idx [lindex $Tmp 1]
                        incr Idx
                    }
                    if {$Cnt != 0} {
                        error "element '[lindex $DimLst 2]' of '$OldReg'\
                            should be a region!"
                    }
                    set Lst [concat $Lst $PPLst]
                } elseif {[lindex $DimLst 0] eq "Vertex"} {
                    foreach Elm [lrange $DimLst 2 end] {
                        set PStr [string range $Elm 1 end]
                        lappend Lst [split $PStr _]
                        set Len [llength [lindex $Lst end]]
                        if {$Len != 2} {
                            error "point '$Elm' not 2D!"
                        }
                    }
                } else {

                    # Convert 'pp' to 'p' and append the rest elements
                    set Lst [concat $Lst [split [split $PStr _] /]\
                        [lrange $DimLst 3 end]]
                }
                set Len [llength [lindex $Lst 2]]
                if {$Len == 2} {
                    if {$1D} {
                        error "point '[lindex $DimLst 2]' not 1D!"
                    }
                    if {$3D || [regexp {^[CP][a-z]+$} [lindex $DimLst 0]]} {
                        error "point '[lindex $DimLst 2]' not 3D!"
                    }
                    set 2D true
                } elseif {$Len == 3} {
                    if {$1D} {
                        error "point '[lindex $DimLst 2]' not 1D!"
                    }
                    if {$2D} {
                        error "point '[lindex $DimLst 2]' not 2D!"
                    }
                    set 3D true
                } else {
                    error "point '[lindex $DimLst 2]' not 2D/3D!"
                }
            }

            # Update 'MatLst' and 'IdxLst'.
            if {[string index [lindex $Mat 1] 0] ne "M"
                && [lindex $Mat end] > 0} {
                set Idx [lsearch -exact $MatLst [lindex $Mat 0]]
                if {$Idx == -1} {
                    lappend MatLst [lindex $Mat 0]
                    lappend IdxLst [lindex $Mat end]
                } else {
                    lset IdxLst $Idx [concat [lindex $IdxLst $Idx]\
                        [lindex $Mat end]]
                }
            }

            # Revert it back to 'RDLst' and append detailed info to 'RILst'
            lappend RDLst [concat [lindex $Mat 0] $DimLst]
            if {$1D} {
                lappend RILst [list $Mat $X1 $X2]
            } elseif {$2D} {
                if {[string is double -strict [lindex $DimLst 0]]} {
                    lappend RILst [list $Mat [list $X1 $Y1] [list $X2 $Y2]]
                } else {
                    lappend RILst [concat [list $Mat] $Lst]
                }
            } else {
                if {[string is double -strict [lindex $DimLst 0]]} {
                    lappend RILst [list $Mat [list $X1 $Y1 $Z1]\
                        [list $X2 $Y2 $Z2]]
                } else {
                    lappend RILst [concat [list $Mat] $Lst]
                }
            }
            incr Seq
        }

        if {!$App1} {
            error "no approach 1 for defining simulation domain!"
        }

        # If a single level, 'RegGen' should be treated differently
        if {$LvlLen == 1} {
            set RegGen $RDLst
        } else {
            lappend RegGen $RDLst
        }

        # Determine the number of digits for region index
        # For 2D, if it is 'Cylindrical', the total regions are N+2, else N+3
        # For 3D, the total regions are N+5
        # If it is 'OptOnly', the total regions are N despite the dimensions
        set Tmp $RegSeq
        if {[string index [lindex $arr(RawVarVal) 0 2] 0] eq "!"} {
            set Cylind false
        } else {
            if {$2D} {
                set Cylind true
            } else {
                if {$3D} {
                    vputs -i$Idt "Warning: 3D, disable 'Cylindrical' option!"
                } else {
                    vputs -i$Idt "Warning: 1D, disable 'Cylindrical' option!"
                }
                set Cylind false
                lset arr(RawVarVal) 0 2 !Cylindrical
            }
        }
        if {[string index [lindex $arr(RawVarVal) 0 3] 0] eq "!"} {
            set OptOnly false
            if {$1D} {
                set NOD [expr int(ceil(log10([incr Tmp])))]
            } elseif {$2D} {
                if {$Cylind} {
                    set NOD [expr int(ceil(log10([incr Tmp 2])))]
                } else {
                    set NOD [expr int(ceil(log10([incr Tmp 3])))]
                }
            } else {
                set NOD [expr int(ceil(log10([incr Tmp 5])))]
            }
        } else {
            set OptOnly true
            set NOD [expr int(ceil(log10($Tmp)))]
        }

        # Define the additional topmost gas layer
        set GasReg [list Gas [format %0${NOD}d 0]_Gas Insulator 0]
        set Idx [lsearch -exact $MatLst Gas]
        if {$Idx == -1} {
            lappend MatLst Gas
            lappend IdxLst 0
        } else {
            lset IdxLst $Idx [concat [lindex $IdxLst $Idx] 0]
        }
        if {$1D} {
            set GasReg [list $GasReg -$GasThx 0]
        } elseif {$2D} {
            set GasReg [list $GasReg [list -$GasThx 0] [list 0 $YMax]]
        } else {
            set GasReg [list $GasReg [list -$GasThx 0 0] [list 0 $YMax $ZMax]]
        }
        vputs -i$Idt -v4 "Layer 0:\n    $GasReg"

        # RILvl: region info+dummy regions
        set RILvl [list]
        lappend RILvl $GasReg

        # Format each region index with the right number of digits
        foreach Lst $RILst {
            if {[string index [lindex $Lst 0 1] 0] ne "M"} {
                lset Lst 0 1 [format %0${NOD}d\
                    [lindex $Lst 0 end]]_[lindex $Lst 0 0]
            }
            lappend RILvl $Lst
        }

        if {!$OptOnly} {

            # Append the bottommost gas layer
            lset GasReg 0 1 [format %0${NOD}d [incr RegSeq]]_Gas
            lset GasReg 0 end $RegSeq
            set Idx [lsearch -exact $MatLst Gas]
            lset IdxLst $Idx [concat [lindex $IdxLst $Idx] $RegSeq]
            if {$1D} {
                lset GasReg 1 $XMax
                lset GasReg 2 [expr $XMax+$GasThx]
            } elseif {$2D} {
                lset GasReg 1 [list $XMax 0]
                lset GasReg 2 [list [expr $XMax+$GasThx] $YMax]
            } else {
                lset GasReg 1 [list $XMax 0 0]
                lset GasReg 2 [list [expr $XMax+$GasThx] $YMax $ZMax]
            }
            lappend RILvl $GasReg
            vputs -i$Idt -v4 "Layer [incr Lyr]:\n    $GasReg"

            if {$2D || $3D} {
                if {$3D || !$Cylind} {

                    # Append the leftmost gas region for 2D/3D
                    lset GasReg 0 1 [format %0${NOD}d [incr RegSeq]]_Gas
                    lset GasReg 0 end $RegSeq
                    lset IdxLst $Idx [concat [lindex $IdxLst $Idx] $RegSeq]
                    if {$3D} {
                        lset GasReg 1 [list -$GasThx -$GasThx 0]
                        lset GasReg 2 [list [expr $XMax+$GasThx] 0 $ZMax]
                    } else {
                        lset GasReg 1 [list -$GasThx -$GasThx]
                        lset GasReg 2 [list [expr $XMax+$GasThx] 0]
                    }
                    lappend RILvl $GasReg
                }

                # Append the rightmost gas region for 2D/3D
                lset GasReg 0 1 [format %0${NOD}d [incr RegSeq]]_Gas
                lset GasReg 0 end $RegSeq
                lset IdxLst $Idx [concat [lindex $IdxLst $Idx] $RegSeq]
                if {$3D} {
                    lset GasReg 1 [list -$GasThx $YMax 0]
                    lset GasReg 2 [list [expr $XMax+$GasThx]\
                        [expr $YMax+$GasThx] $ZMax]
                } else {
                    lset GasReg 1 [list -$GasThx $YMax]
                    lset GasReg 2 [list [expr $XMax+$GasThx]\
                        [expr $YMax+$GasThx]]
                }
                lappend RILvl $GasReg
            }
            if {$3D} {

                # Append the farmost gas region for 3D
                lset GasReg 0 1 [format %0${NOD}d [incr RegSeq]]_Gas
                lset GasReg 0 end $RegSeq
                lset IdxLst $Idx [concat [lindex $IdxLst $Idx] $RegSeq]
                lset GasReg 1 [list -$GasThx -$GasThx -$GasThx]
                lset GasReg 2 [list [expr $XMax+$GasThx] [expr $YMax+$GasThx] 0]
                lappend RILvl $GasReg

                # Append the nearmost gas region for 3D
                lset GasReg 0 1 [format %0${NOD}d [incr RegSeq]]_Gas
                lset GasReg 0 end $RegSeq
                lset IdxLst $Idx [concat [lindex $IdxLst $Idx] $RegSeq]
                lset GasReg 1 [list -$GasThx -$GasThx $ZMax]
                lset GasReg 2 [list [expr $XMax+$GasThx] [expr $YMax+$GasThx]\
                    [expr $ZMax+$GasThx]]
                lappend RILvl $GasReg
            }
        }
        lappend RegInfo $RILvl
        lappend RegMat $MatLst
        lappend RegIdx $IdxLst
        vputs -i$Idt "Totally '[incr RegSeq]' regions!"
        vputs -v3 -c "Region info: \{$RILvl\}"
        vputs -v3 -c "Region materials: \{$MatLst\}"
        vputs -v3 -c "Region indices: \{$IdxLst\}"
        vputs -v3 -c "After conversion: \{$RegGen\}\n"
    }
    set ::SimArr(RegInfo) $RegInfo
    set ::SimArr(RegMat) $RegMat
    set ::SimArr(RegIdx) $RegIdx
    set arr(RegGen) $RegGen
}

# mfjIntrpr::readFmt
    # Read ::SimArr(FVarFmt) and update the following variables in arr:
    # FmtVarName FmtVarVal FmtSTLbl FmtSTName FmtSTIdx
    # FmtSimEnv FmtModTime FmtRegInfo
proc mfjIntrpr::readFmt {} {
    variable arr
    vputs "Reading the formatted variable file '$::SimArr(FVarFmt)'..."
    if {[file isfile $::SimArr(FVarFmt)]} {
        set ReadVar false
        foreach Elm [list VarName VarVal STLbl STName STIdx Str] {
            upvar 0 $Elm Alias
            set Alias [list]
        }
        set VarIdx 0
        set Inf [open $::SimArr(FVarFmt) r]
        vputs -v3 -i1 "Environment variables:"
        while {[gets $Inf Line] != -1} {
            if {[regexp {\S} $Line]} {
                append Str "[string trimleft $Line] "
            } else {
                if {$Str ne ""} {
                    if {[string index $Str 0] eq "#"} {
                        if {[regexp -nocase $::SimArr(STDfltID) $Str\
                            -> Lbl Tool]} {
                            set ReadVar true
                            lappend STLbl $Lbl
                            lappend STName $Tool
                            lappend STIdx $VarIdx
                            vputs -v3 -i1 "ST tool: '$Tool'\tlabel:\
                                '$Lbl'\tindex: '$VarIdx'"
                        }
                    } else {
                        if {$ReadVar} {
                            if {[llength $Str] > 2} {
                                lappend VarName [lindex $Str 0]<mfj>
                                lappend VarVal [lrange $Str 1 end]
                            } else {
                                lappend VarName [lindex $Str 0]
                                lappend VarVal [lindex $Str 1]
                            }
                            incr VarIdx
                            vputs -v3 -i2 "[lindex $VarName end]:\
                                \{[lindex $VarVal end]\}"
                        } else {
                            if {[regexp {^mfj(DfltSet|ModTime|RegInfo)$}\
                                [lindex $Str 0] -> Var]} {
                                set arr(Fmt$Var) [lindex $Str 1]
                                vputs -v3 -i2 "arr(Fmt$Var):\
                                    \{[lindex $Str 1]\}"
                            } elseif {[lindex $Str 0] eq "SimEnv"} {
                                set arr(FmtSimEnv) [lindex $Str 1]
                                vputs -v3 -i2 "arr(FmtSimEnv):\
                                    \{[lindex $Str 1]\}"
                            } else {
                                vputs -v3 -i2 "Unknown variable\
                                    '[lindex $Str 0]'!"
                            }
                        }
                    }
                }
                set Str ""
            }
        }
        close $Inf
        foreach Elm [list VarName VarVal STLbl STName STIdx] {
            upvar 0 $Elm Alias
            set arr(Fmt$Elm) $Alias
        }
    } else {
        vputs -i1 "The formatted variable file '$::SimArr(FVarFmt)' not found!"
        set arr(UpdateFmt) true
    }
    vputs
}

# mfjIntrpr::fmtvsRaw
    # Compare ::SimArr(FVarFmt) against ::SimArr(FVarRaw) and set arr(UpdateFmt)
    # to be true if there is any difference
proc mfjIntrpr::fmtvsRaw {} {
    variable arr

    # Extract 'SimEnv' and construct 'DfltSet' for easy comparison
    set SimEnv [lindex $arr(RawVarVal) 0]
    set DfltSet [list $::SimArr(DfltYMax) $::SimArr(LatFac) $::SimArr(GasThx)]
    foreach Elm {Node4All ColMode FullSchenk} {
        if {[string equal -nocase $::SimArr($Elm) $Elm]} {
            lappend DfltSet $Elm
        } else {
            lappend DfltSet !$Elm
        }
    }
    foreach Elm {TrapDLN EdgeEx IntfEx NThread BitSize Digits RhsMin Iter} {
        lappend DfltSet $::SimArr($Elm)
    }
    set VarName [lrange $arr(RawVarName) 1 end]
    set VarVal [lrange $arr(RawVarVal) 1 end]

    # Everything within the format file is case sensitive
    set Msg "'$::SimArr(FVarFmt)' is different from '$::SimArr(FVarRaw)'!"
    if {!$arr(UpdateFmt)} {
        vputs "Comparing '$::SimArr(FVarFmt)' against '$::SimArr(FVarRaw)'..."
        if {$arr(FmtSimEnv) ne $SimEnv} {
            set arr(UpdateFmt) true
            vputs -i1 $Msg
            vputs -i2 "Environment variable 'SimEnv' has a value of\
                '$arr(FmtSimEnv)' different from '$SimEnv'!"

            # Remove all compiled share objects if version changes
            if {[lindex $arr(FmtSimEnv) 1] ne [lindex $SimEnv 1]} {
                foreach Elm [glob -nocomplain $::SimArr(PMIDir)/*.so.*] {
                    file delete $Elm
                }
            }
        } elseif {$DfltSet ne $arr(FmtDfltSet)} {
            set arr(UpdateFmt) true
            vputs -i1 $Msg
            vputs -i2 "Environment variable 'mfjDfltSet' has a value of\
                '$arr(FmtDfltSet)' different from '$DfltSet'!"
        } elseif {$arr(FmtRegInfo) ne $::SimArr(RegInfo)} {
            set arr(UpdateFmt) true
            vputs -i1 $Msg
            vputs -i2 "Environment variable 'mfjRegInfo' has a value of\
                '$arr(FmtRegInfo)' different from '$::SimArr(RegInfo)'!"
        } else {
            set Flg false
            set ModTime $::SimArr(ModTime)
            foreach Elm $arr(FmtModTime) {

                # A file name may contain special characters, not suitable
                # for 'regexp' to perform string match
                set Lst [list]
                set FmtFlg false
                foreach Grp $ModTime {
                    if {[lindex $Elm 0] eq [lindex $Grp 0]} {
                        set FmtFlg true
                        if {[lindex $Elm 1] != [lindex $Grp 1]} {
                            set arr(UpdateFmt) true
                            if {!$Flg} {
                                vputs -i1 $Msg
                                set Flg true
                            }
                            vputs -i2 "File '[lindex $Elm 0]' updated!"

                            # If PMI files are updated, remove the
                            # corresponding share objects
                            if {[string equal -nocase .c\
                                [file extension [lindex $Elm 0]]]} {
                                set Obj [glob -nocomplain\
                                    $::SimArr(PMIDir)/[file rootname\
                                    [lindex $Elm 0]].so.*]
                                if {$Obj ne ""} {
                                    file delete $Obj
                                }
                            }
                        }
                    } else {
                        lappend Lst $Grp
                    }

                    # Update ModTime to remove the matched file
                    set ModTime $Lst

                    # Output each file removed
                    if {!$FmtFlg} {
                        set arr(UpdateFmt) true
                        if {!$Flg} {
                            vputs -i1 $Msg
                            set Flg true
                        }
                        vputs -i2 "File '[lindex $Elm 0]' abandoned!"
                    }
                }
            }

            # Output the remaining files in ::SimArr(ModTime)
            foreach Elm $ModTime {
                set arr(UpdateFmt) true
                if {!$Flg} {
                    vputs -i1 $Msg
                    set Flg true
                }
                vputs -i2 "File '[lindex $Elm 0]' added!"
            }
        }
        if {!$arr(UpdateFmt)} {
            if {[llength $arr(FmtVarName)] != [llength $VarName]} {
                set arr(UpdateFmt) true
                vputs -i1 $Msg
                vputs -i2 "Simulation variable # '[llength $arr(FmtVarName)]'\
                    different from '[llength $VarName]'!"
            } else {
                foreach FVar $arr(FmtVarName) FVal $arr(FmtVarVal)\
                    RVar $VarName RVal $VarVal {

                    # Variables should have the same sequence
                    if {$FVar ne $RVar} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                        vputs -i2 "Simulation variable '$FVar' different from\
                            '$RVar'!"
                        break
                    }
                    if {$FVal ne $RVal} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                        vputs -i2 "Simulation variable '$FVar' has a value of\
                            '$FVal' different from '$RVal'!"
                        break
                    }
                }
            }
        }
        if {!$arr(UpdateFmt)} {
            if {[llength $arr(FmtSTName)] != [llength $arr(RawSTName)]} {
                set arr(UpdateFmt) true
                vputs -i1 $Msg
                vputs -i2 "ST tool # '[llength $arr(FmtSTName)]' different\
                    from '[llength $arr(RawSTName)]'!"
            } else {
                foreach FName $arr(FmtSTName) RName $arr(RawSTName)\
                    FLbl $arr(FmtSTLbl) RLbl $arr(RawSTLbl)\
                    FIdx $arr(FmtSTIdx) RIdx $arr(RawSTIdx) {
                    if {$FName ne $RName} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                        vputs -i2 "ST tool name '$FName' different from\
                            '$RName'!"
                        break
                    }
                    if {$FLbl ne $RLbl} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                        vputs -i2 "ST tool label '$FLbl' different from\
                            '$RLbl'!"
                        break
                    }
                    if {$FIdx != $RIdx} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                        vputs -i2g "ST tool index '$FIdx' different from\
                            '$RIdx'!"
                        break
                    }
                }
            }
        }
        if {!$arr(UpdateFmt)} {
            vputs -i1 "'$::SimArr(FVarFmt)' is the same as\
                '$::SimArr(FVarRaw)'!"
        }
        vputs
    }
    if {$arr(UpdateFmt)} {

        # Perform an efficient update of all related variables
        set arr(FmtSimEnv) $SimEnv
        set arr(FmtDfltSet) $DfltSet
        set arr(FmtModTime) $::SimArr(ModTime)
        set arr(FmtRegInfo) $::SimArr(RegInfo)
        set arr(FmtVarName) $VarName
        set arr(FmtVarVal) $VarVal
        set arr(FmtSTName) $arr(RawSTName)
        set arr(FmtSTLbl) $arr(RawSTLbl)
        set arr(FmtSTIdx) $arr(RawSTIdx)
    }
}

# mfjIntrpr::fmtvsTCL
    # Compare ::SimArr(FVarFmt) against ::SimArr(FVarEnv) and ::SimArr(FVarSim)
    # and set arr(UpdateFmt) to be true if there is any difference
proc mfjIntrpr::fmtvsTCL {} {
    variable arr

    # Fmt related variables should be updated here
    if {!$arr(UpdateFmt)} {
        vputs "Comparing '$::SimArr(FVarFmt)' against '$::SimArr(FVarEnv)' and\
            '$::SimArr(FVarSim)'..."

        # Re-run all the tools for major changes
        if {$arr(FmtSimEnv) ne $mfjST::arr(TCLSimEnv)} {
            set arr(UpdateFmt) true
            set Msg "Environment variable 'SimEnv' has a value of\
                '$arr(FmtSimEnv)' different from '$mfjST::arr(TCLSimEnv)'!"
        } else {
            if {[llength $arr(FmtSTLbl)] != [llength $mfjST::arr(TCLSTLbl)]} {
                set arr(UpdateFmt) true
                set Msg "ST tool # '[llength $arr(FmtSTLbl)]' different\
                    from '[llength $mfjST::arr(TCLSTLbl)]'!"
            } else {
                foreach FLbl $arr(FmtSTLbl) TLbl $mfjST::arr(TCLSTLbl)\
                    FName $arr(FmtSTName) TName $mfjST::arr(TCLSTName)\
                    FIdx $arr(FmtSTIdx) TIdx $mfjST::arr(TCLSTIdx) {
                    if {$FLbl ne $TLbl} {
                        set arr(UpdateFmt) true
                        set Msg "ST tool label '$FLbl' different from '$TLbl'!"
                        break
                    }
                    if {$FName ne $TName} {
                        set arr(UpdateFmt) true
                        set Msg "ST tool name '$FName' different from '$TName'!"
                        break
                    }
                    if {$FIdx != $TIdx} {
                        set arr(UpdateFmt) true
                        set Msg "ST tool index '$FIdx' different from '$TIdx'!"
                        break
                    }
                }
            }
        }

        if {!$arr(UpdateFmt)} {
            if {[llength $arr(FmtVarName)]\
                != [llength $mfjST::arr(TCLVarName)]} {
                set arr(UpdateFmt) true
                set Msg "Simulation variable # '[llength $arr(FmtVarName)]'\
                    different from '[llength $mfjST::arr(TCLVarName)]'!"
            } else {
                foreach FVar $arr(FmtVarName) FVal $arr(FmtVarVal)\
                    TVar $mfjST::arr(TCLVarName) TVal $mfjST::arr(TCLVarVal) {

                    # Variables should have the same sequence
                    if {$FVar ne $TVar} {
                        set arr(UpdateFmt) true
                        set Msg "Simulation variable '$FVar' different from\
                            '$TVar'!"
                        break
                    }
                    if {$FVal ne $TVal} {
                        set arr(UpdateFmt) true
                        set Msg "Simulation variable '$FVar' has a value of\
                            '$FVal' different from '$TVal'!"
                        break
                    }
                }
            }
        }

        if {$arr(UpdateFmt)} {
            vputs -i1 "'$::SimArr(FVarFmt)' is different from\
                '$::SimArr(FVarEnv)' and '$::SimArr(FVarSim)'!"
            vputs -i2 $Msg
        } else {
            set arr(StartIdx) [llength $arr(FmtSTIdx)]
            vputs -i1 "'$::SimArr(FVarFmt)' is the same as '$::SimArr(FVarEnv)'\
                and '$::SimArr(FVarSim)'!"
        }
        vputs
    }
    if {$arr(UpdateFmt)} {

        # Perform an efficient update of all related variables
        set arr(FmtSimEnv) $mfjST::arr(TCLSimEnv)
        set arr(FmtSTName) $mfjST::arr(TCLSTName)
        set arr(FmtSTLbl) $mfjST::arr(TCLSTLbl)
        set arr(FmtSTIdx) $mfjST::arr(TCLSTIdx)
        set arr(FmtVarName) $mfjST::arr(TCLVarName)
        set arr(FmtVarVal) $mfjST::arr(TCLVarVal)
    }
}

# mfjIntrpr::rawvsFmt
    # Compare ::SimArr(FVarRaw) against ::SimArr(FVarFmt) and set arr(UpdateRaw)
    # and arr(UpdatBrf) to be true if there is any difference
proc mfjIntrpr::rawvsFmt {} {
    variable arr

    # Extract 'SimEnv' for easy comparison
    set SimEnv [lindex $arr(RawVarVal) 0]
    set VarName [lrange $arr(RawVarName) 1 end]
    set VarVal [lrange $arr(RawVarVal) 1 end]

    # Everything within the format file is case sensitive
    if {!$arr(UpdateRaw)} {
        vputs "Comparing '$::SimArr(FVarRaw)' against '$::SimArr(FVarFmt)'..."
        if {$SimEnv ne $arr(FmtSimEnv)} {
            set arr(UpdateRaw) true
            set Msg "Environment variable 'SimEnv' has a value of\
                '$SimEnv' different from '$arr(FmtSimEnv)'!"
        } else {
            if {[llength $VarName] != [llength $arr(FmtVarName)]} {
                set arr(UpdateRaw) true
                set Msg "Simulation variable # '[llength $VarName]'\
                    different from '[llength $arr(FmtVarName)]'!"
            } else {
                foreach RVar $VarName RVal $VarVal\
                    FVar $arr(FmtVarName) FVal $arr(FmtVarVal) {

                    # Variables should have the same sequence
                    if {$RVar ne $FVar} {
                        set arr(UpdateRaw) true
                        set Msg "Simulation variable '$RVar' different from\
                            '$FVar'!"
                        break
                    }
                    if {$RVal ne $FVal} {
                        set arr(UpdateRaw) true
                        set Msg "Simulation variable '$RVar' has a value of\
                            '$RVal' different from '$FVal'!"
                        break
                    }
                }
            }
        }
        if {!$arr(UpdateRaw)} {
            if {[llength $arr(RawSTName)] != [llength $arr(FmtSTName)]} {
                set arr(UpdateRaw) true
                set Msg "ST tool # '[llength $arr(RawSTName)]' different\
                    from '[llength $arr(FmtSTName)]'!"
            } else {
                foreach RName $arr(RawSTName) FName $arr(FmtSTName)\
                    RLbl $arr(RawSTLbl) FLbl $arr(FmtSTLbl)\
                    RIdx $arr(RawSTIdx) FIdx $arr(FmtSTIdx) {
                    if {$RName ne $FName} {
                        set arr(UpdateRaw) true
                        set Msg "ST tool name '$RName' different from '$FName'!"
                        break
                    }
                    if {$RLbl ne $FLbl} {
                        set arr(UpdateRaw) true
                        set Msg "ST tool label '$RLbl' different from '$FLbl'!"
                        break
                    }
                    if {$RIdx != $FIdx} {
                        set arr(UpdateRaw) true
                        set Msg "ST tool index '$RIdx' different from '$FIdx'!"
                        break
                    }
                }
            }
        }
        if {$arr(UpdateRaw)} {
            vputs -i1 "'$::SimArr(FVarRaw)' is different from\
                '$::SimArr(FVarFmt)'!"
            vputs -i2 $Msg
        } else {
            vputs -i1 "'$::SimArr(FVarRaw)' is the same as\
                '$::SimArr(FVarFmt)'!"
        }
        vputs
    }
    if {$arr(UpdateRaw)} {

        # Perform an efficient update of all related variables
        set arr(RawSTName) $arr(FmtSTName)
        set arr(RawSTLbl) $arr(FmtSTLbl)
        set arr(RawSTIdx) $arr(FmtSTIdx)

        # Preserve original comments and grammar
        set VarName SimEnv
        set VarVal [list $arr(FmtSimEnv)]
        set VarGrm [list [lindex $arr(RawVarGStr) 0]]
        set VarCmnt [list [lindex $arr(RawVarCmnt) 0]]
        set VarCmnt1 [list [lindex $arr(RawVarCmnt1) 0]]
        set VarCmnt2 [list [lindex $arr(RawVarCmnt2) 0]]
        foreach Var $arr(FmtVarName) Val $arr(FmtVarVal) {
            lappend VarName $Var
            lappend VarVal $Val

            # Extract variable name
            regexp {^(\w+)(<mfj>)?$} $Var -> Name
            set Idx [lsearch -regexp $arr(RawVarName) (?i)^${Name}(<mfj>)?$]
            if {$Idx == -1} {
                lappend VarGrm ""
                lappend VarCmnt "Pls. add comments regarding $Name"
                lappend VarCmnt1 ""
                lappend VarCmnt2 ""
            } else {
                lappend VarGrm [lindex $arr(RawVarGStr) $Idx]
                lappend VarCmnt [lindex $arr(RawVarCmnt) $Idx]
                lappend VarCmnt1 [lindex $arr(RawVarCmnt1) $Idx]
                lappend VarCmnt2 [lindex $arr(RawVarCmnt2) $Idx]
            }
        }
        set arr(RawVarName) $VarName
        set arr(RawVarVal) $VarVal
        set arr(RawVarGStr) $VarGrm
        set arr(RawVarCmnt) $VarCmnt
        set arr(RawVarCmnt1) $VarCmnt1
        set arr(RawVarCmnt2) $VarCmnt2

        # Update the brief file as well
        set arr(UpdateBrf) true
        set arr(BrfVarName) $arr(RawVarName)
        set arr(BrfVarVal) $arr(RawVarVal)
    }
}

# mfjIntrpr::updateRaw
    # If arr(updateRaw) is true, update the raw TXT file with the related
    # raw variables in arr
proc mfjIntrpr::updateRaw {} {
    variable arr
    set Tab $mfjProc::arr(Tab)

    if {$arr(UpdateRaw)} {
        vputs "Updating the raw variable file '$::SimArr(FVarRaw)'..."
        if {[file isfile $::SimArr(FVarRaw)]} {
          set Tmp $::SimArr(FVarRaw).backup
          vputs -v2 -i1 "Backing up with '$Tmp'..."
          file copy -force $::SimArr(FVarRaw) $Tmp
        }
        set Ouf [open $::SimArr(FVarRaw).mfj w]
        vputs -v2 -i1 "Writing the file head..."
        puts $Ouf <HEAD>$arr(Head)\n
        vputs -v2 -i1 "Writing simulation variables..."
        vputs -v3 -i2 -n "Calculating the max length of variable names... "
        set MaxLen [calMaxVarLen $arr(RawVarName) <mfj>]
        vputs -v3 -c '$MaxLen'

        # Include at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]

        set VarIdx -1
        set STIdx 0
        set STLen [llength $arr(RawSTName)]
        set Ptn [string map {(\\S+) %s} $::SimArr(STDfltID)]
        foreach Cmnt $arr(RawVarCmnt) Cmnt1 $arr(RawVarCmnt1)\
            Cmnt2 $arr(RawVarCmnt2) Grm $arr(RawVarGStr)\
            Var $arr(RawVarName) Val $arr(RawVarVal) {

            # In case no variables between tools
            while {$STIdx < $STLen
                && $VarIdx == [lindex $arr(RawSTIdx) $STIdx]} {
                puts $Ouf [format <TOOL>$Ptn\n [lindex $arr(RawSTLbl) $STIdx]\
                    [lindex $arr(RawSTName) $STIdx]]
                incr STIdx
            }
            puts $Ouf <COMMENT>$Cmnt\n
            puts $Ouf <GRAMMAR>$Grm\n
            if {$Cmnt1 ne ""} {
                puts $Ouf $Cmnt1\n
            }

            # Take care of splits
            if {[regexp ^(\\w+)<mfj>$ $Var -> Tmp]} {
                set Var $Tmp
            } else {

                # Increase nested level for a single level value
                set Val [list $Val]
            }

            # Preserve each value so that it is the same as in the brief file
            puts $Ouf [wrapText [format <VAR>%-${MaxLen}s%s\n $Var $Val]]
            if {$Cmnt2 ne ""} {
                puts $Ouf $Cmnt2\n
            }
            incr VarIdx
        }

        # In case no variables or the rest tools have no variables
        while {$STIdx < $STLen && $VarIdx == [lindex $arr(RawSTIdx) $STIdx]} {
            puts $Ouf [format <TOOL>$Ptn\n [lindex $arr(RawSTLbl) $STIdx]\
                [lindex $arr(RawSTName) $STIdx]]
            incr STIdx
        }

        vputs -v2 -i1 "Writing the file tail..."
        puts $Ouf <TAIL>$arr(Tail)\n
        close $Ouf
        file rename -force $::SimArr(FVarRaw).mfj $::SimArr(FVarRaw)
        vputs
    }
}

# mfjIntrpr::updateBrf
    # If arr(UpdateBrf) is true, update the brief with the related variables
proc mfjIntrpr::updateBrf {} {
    variable arr

    if {$arr(UpdateBrf)} {
        set FVarBrf [file rootname $::SimArr(FVarRaw)]-brief.txt
        vputs "Updating the brief variable file '$FVarBrf'..."
        if {[file isfile $FVarBrf]} {
            vputs -v2 -i1 "Backing up with '$FVarBrf.backup'..."
            file copy -force $FVarBrf $FVarBrf.backup
        }
        set Ouf [open $FVarBrf.mfj w]
        vputs -v3 -i2 -n "Calculating the max length of variable names... "
        set MaxLen [calMaxVarLen $arr(BrfVarName) <mfj>]
        vputs -v3 -c '$MaxLen'

        # With at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]

        # Output all variables
        foreach Var $arr(BrfVarName) Val $arr(BrfVarVal) {
            if {[regexp ^(\\w+)<mfj>$ $Var -> Tmp]} {
                set Var $Tmp
            } else {
                set Val [list $Val]
            }
            puts $Ouf [wrapText [format %-${MaxLen}s%s\n $Var $Val]]
        }
        close $Ouf
        file rename -force $FVarBrf.mfj $FVarBrf
        vputs
    }
}

# mfjIntrpr::updateFmt
    # If arr(UpdateFmt) is true, update the variable formatted file
    # with the related variables
proc mfjIntrpr::updateFmt {} {
    variable arr
    set Tab $mfjProc::arr(Tab)

    if {$arr(UpdateFmt)} {
        vputs "Updating the formatted variable file '$::SimArr(FVarFmt)'..."
        if {[file isfile $::SimArr(FVarFmt)]} {
            vputs -v2 -i1 "Backing up with '$::SimArr(FVarFmt).backup'..."
            file copy -force $::SimArr(FVarFmt) $::SimArr(FVarFmt).backup
        }
        set Ouf [open $::SimArr(FVarFmt).mfj w]
        vputs -v3 -i2 -n "Calculating the max length of variable names... "
        set MaxLen [calMaxVarLen [concat $arr(FmtVarName) mfjDfltSet] <mfj>]

        # No leading space, at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]
        vputs -v3 -c '$MaxLen'

        # No extra trailing spaces
        puts $Ouf "$::SimArr(Prefix) Variables with validated values\n"

        # Output environment variables
        puts $Ouf [wrapText [format %-${MaxLen}s\{%s\}\n SimEnv\
            $arr(FmtSimEnv)] $Tab]
        foreach Elm [list DfltSet ModTime RegInfo] {
            puts $Ouf [wrapText [format %-${MaxLen}s\{%s\}\n mfj$Elm\
                $arr(Fmt$Elm)] $Tab]
        }

        # Output simulation variables
        set VarIdx 0
        set STIdx 0
        set STLen [llength $arr(FmtSTName)]
        set Ptn [string map {(\\S+) %s} $::SimArr(STDfltID)]
        foreach Var $arr(FmtVarName) Val $arr(FmtVarVal) {

            # In case no variables between tools
            while {$STIdx < $STLen
                && $VarIdx == [lindex $arr(FmtSTIdx) $STIdx]} {
                puts $Ouf [format "# $Ptn\n" [lindex $arr(FmtSTLbl) $STIdx]\
                    [lindex $arr(FmtSTName) $STIdx]]
                incr STIdx
            }
            if {[regexp ^(\\w+)<mfj>$ $Var -> Tmp]} {
                set Var $Tmp
            } else {
                set Val [list $Val]
            }
            puts $Ouf [wrapText [format %-${MaxLen}s%s\n $Var $Val] $Tab]
            incr VarIdx
        }

        # In case no variables or the rest tools have no variables
        while {$STIdx < $STLen && $VarIdx == [lindex $arr(FmtSTIdx) $STIdx]} {
            puts $Ouf [format "# $Ptn\n" [lindex $arr(FmtSTLbl) $STIdx]\
                [lindex $arr(FmtSTName) $STIdx]]
            incr STIdx
        }
        close $Ouf
        file rename -force $::SimArr(FVarFmt).mfj $::SimArr(FVarFmt)
        vputs
    }
}

# mfjIntrpr::raw2Fmt
    # Do all the heavy lifting here by performing many small tasks. Mainly:
    # 1. Read variables and their values
    # 2. Apply convenient features to expand values
    # 3. Apply format rules to further validate values
    # 4. Compare variables in the raw file and those in the formatted file
proc mfjIntrpr::raw2Fmt {} {
    foreach Elm [list readHost readRaw readBrf rawvsBrf updateBrf\
        actConvFeat valSimEnv alterSimVar valSimVar readFmt fmtvsRaw\
        updateFmt updateRaw] {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

# mfjIntrpr::tcl2Raw
    # Reverse the actions in raw2Fmt to update the raw variable file
proc mfjIntrpr::tcl2Raw {} {
    foreach Elm {readFmt fmtvsTCL updateFmt readRaw rawvsFmt updateRaw
        updateBrf} {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

package provide mfjIntrpr $mfjIntrpr::version
