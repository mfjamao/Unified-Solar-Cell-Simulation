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

    # Define a big array to handle all data exchange
    variable arr
    array set arr {
        Host|ID "" Host|User "" Host|Email "" Host|ESuffix "" Host|JobSched ""
        Host|STPath "" Host|STLicn "" Host|STLib "" Host|AllSTVer ""
        Head "" Tail "" Raw|VarLst "" RawST|VarLst "" RawEnv|VarLst ""
        Raw|STLst "" Brf|VarLst "" FmtRsvd|VarLst "" FmtEnv|VarLst ""
        Fmt|VarLst "" FmtST|VarLst "" Fmt|STLst "" FmtVal|mfjDfltSet ""
        FmtVal|mfjRegInfo "" FmtVal|mfjModTime "" FmtVal|mfjSTLst ""
        UpdateRaw false UpdateBrf false UpdateFmt false
    }
}

# mfjIntrpr::readRaw
#     Read ::SimArr(FVarRaw) and update the corresponding variables in arr
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
    foreach Elm [list VarName VarLvl VarVal VarCmnt VarCmnt1 VarCmnt2 VarGStr\
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
    set VarIdx 0
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
                                #vputs -v3 -c <HEAD>$arr(Head)\n
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
                        #vputs -v3 -c <COMMENT>[lindex $VarCmnt end]\n
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
                lappend STIdx $VarIdx
                vputs -v3 "ST tool: '[lindex $STName end]'\tlabel:\
                    '$Lbl'\tindex: '$VarIdx'\n"
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
                    error "variable name '$Var' not found in\
                        '::SimArr(VarName)' of '11ctrlsim.tcl'!"
                } else {
                    set Var $Tmp
                }

                # Properly convert a grammar string to a list
                lappend VarGStr [string trim $GrmStr]
                #vputs -v3 -c <GRAMMAR>[lindex $VarGStr end]\n
                lappend VarGLst [str2List "$Var: Grammar" $GrmStr]
                if {[lindex $VarCmnt1 end] ne ""} {
                    #vputs -v3 -c [lindex $VarCmnt1 end]\n
                }

                # Convert strings properly to lists for variable values
                # in spite of levels of nesting
                # For variables before ST tools, multiple levels are dropped
                # Multiple-level: LvlLen > 1
                set Len [llength $VarStr]
                lappend VarName $Var
                if {$Len == 2 || $STIdx eq ""} {
                    lappend VarLvl 1
                    lappend VarVal [str2List "$Var: Value" [lindex $VarStr 1]]
                } else {
                    lappend VarLvl [incr Len -1]
                    lappend VarVal [str2List "$Var: Value"\
                        [lrange $VarStr 1 end]]
                }
            }
            lappend VarCmnt2 $Cmnt2
            if {$Cmnt2 ne ""} {
                #vputs -v3 -c $Cmnt2\n
            }
            set Cmnt2 ""
            if {$ReadTail} {
                vputs -v2 -i-1 "Reading the file tail..."
            }
            set UpdateVar false
            incr VarIdx
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

        # Pass essential variables to array 'arr'
        set VarIdx 0
        set Idx 0
        set Len [llength $STName]
        if {$Len == 0} {
            error "no ST tools found!"
        }
        foreach Var $VarName Len $VarLvl Val $VarVal Cmnt $VarCmnt\
            Cmnt1 $VarCmnt1 Cmnt2 $VarCmnt2 GStr $VarGStr GLst $VarGLst {
            lappend arr(Raw|VarLst) $Var
            set arr(RawLvl|$Var) $Len
            set arr(RawVal|$Var) $Val
            set arr(RawCmnt|$Var) $Cmnt
            set arr(RawCmnt1|$Var) $Cmnt1
            set arr(RawCmnt2|$Var) $Cmnt2
            set arr(RawGStr|$Var) $GStr
            set arr(RawGLst|$Var) $GLst
            if {$VarIdx < [lindex $STIdx 0]} {
                lappend arr(RawEnv|VarLst) $Var
            } elseif {$VarIdx == [lindex $STIdx $Idx]} {
                set Tool [lindex $STName $Idx]
                lappend arr(Raw|STLst) $Tool
                lappend arr(RawST|VarLst) $Var
                lappend arr(Raw$Tool|VarLst) $Var
                set arr(RawLbl|$Tool) [lindex $STLbl $Idx]
                incr Idx
            } else {
                lappend arr(RawST|VarLst) $Var
                lappend arr(Raw$Tool|VarLst) $Var
            }
            incr VarIdx
        }

        # In case no variables or the rest tools have no variables
        while {$Idx < $Len && $VarIdx == [lindex $STIdx $Idx]} {
            set Tool [lindex $STName $Idx]
            lappend arr(Raw|STLst) $Tool
            set arr(RawLbl|$Tool) [lindex $STLbl $Idx]
            set arr(Raw$Tool|VarLst) [list]
            incr Idx
        }
    } else {
        error "no variables in '$::SimArr(FVarRaw)'!"
    }

    # Remove trailing blank lines in the tail section
    set arr(Tail) [string trim $arr(Tail)]
    #vputs -v3 -c <TAIL>$arr(Tail)
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
            # Ignore comment lines
            if {$Char eq "#" || $Line eq "" || $LineIdx == $LineEnd} {
                if {[llength $Str] == 0} {
                    incr LineIdx
                    continue
                }
                if {[llength $Str] == 1} {
                    error "no value assigned to variable '$Str'!"
                }

                # Valid variable name: [a-zA-Z0-9_]
                set Var [lindex $Str 0]
                set Val [lrange $Str 1 end]
                set Str ""
                if {![regexp {^\w+$} $Var]} {
                    error "invalid variable name '$Var'. only characters\
                        'a-zA-Z0-9_' are allowed!"
                }

                # Update the case for each variable name
                set Tmp [lsearch -inline -regexp $::SimArr(VarName) (?i)^$Var$]
                if {$Tmp eq ""} {
                    error "variable name '$Var' not found in\
                        '::SimArr(VarName)' of '11ctrlsim.tcl'!"
                } else {
                    set Var $Tmp
                }

                # Convert strings properly to lists for values
                lappend arr(Brf|VarLst) $Var
                set Len [llength $Val]
                if {$Len == 1 || $Var eq "SimEnv"} {
                    set arr(BrfLvl|$Var) 1
                    set arr(BrfVal|$Var) [str2List "$Var:" [lindex $Val 0]]
                } else {
                    set arr(BrfLvl|$Var) $Len
                    set arr(BrfVal|$Var) [str2List "$Var:" $Val]
                }
            }
            incr LineIdx
        }
        set mfjProc::arr(Indent1) 0
        if {[llength $arr(Brf|VarLst)]} {

            # Case-insensitive lsort
            set Tmp [lsort -unique [string tolower $arr(Brf|VarLst)]]
            if {[llength $arr(Brf|VarLst)] != [llength $Tmp]} {
                error "no duplicate variable name allowed!"
            }
        } else {
            vputs -i1 "Warning: no variables in '$FVarBrf'!"
            set arr(UpdatBrf) true
        }
    }
    vputs
}

# mfjIntrpr::rawvsBrf
    # Compare ::SimArr(FVarRaw) against the brief version
proc mfjIntrpr::rawvsBrf {} {
    variable arr
    if {!$arr(UpdateBrf)} {
        set FVarBrf [file rootname $::SimArr(FVarRaw)]-brief.txt
        vputs "Comparing '$::SimArr(FVarRaw)' against '$FVarBrf'..."

        # A user can only modify a value for a variable in the brief version
        # Adding or removing a variable must be done in the variable file
        set Msg "'$FVarBrf' is different from '$::SimArr(FVarRaw)'!"
        foreach Var $arr(Brf|VarLst) {

            # Variables should be the same as those in ::SimArr(FVarRaw)
            if {[lsearch -exact $arr(Raw|VarLst) $Var] == -1} {
                if {!$arr(UpdateBrf)} {
                    set arr(UpdateBrf) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Variable '$Var' in '$::SimArr(FVarRaw)' removed!"
                continue
            }

            # Only show changes here without actually doing it
            if {![string equal -nocase $arr(BrfVal|$Var) $arr(RawVal|$Var)]} {
                if {[file mtime $FVarBrf] < [file mtime $::SimArr(FVarRaw)]} {
                    if {!$arr(UpdateBrf)} {
                        set arr(UpdateBrf) true
                        vputs -i1 $Msg
                    }
                } else {
                    if {!$arr(UpdateRaw)} {
                        set arr(UpdateRaw) true
                        vputs -i1 "'$::SimArr(FVarRaw)' is different from\
                            '$FVarBrf'!"
                    }
                }
                vputs -v3 -i2 "Variable '$Var' has a value of\
                    '$arr(BrfVal|$Var)' in '$FVarBrf' different from\
                    '$arr(RawVal|$Var)'!"
            }
        }
        foreach Var $arr(Raw|VarLst) {
            if {[lsearch -exact $arr(Brf|VarLst) $Var] == -1} {
                if {!$arr(UpdateBrf)} {
                    set arr(UpdateBrf) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "Variable '$Var' in '$::SimArr(FVarRaw)' added!"
            }
        }

        # Update the brief file only if both need update
        if {$arr(UpdateBrf) && $arr(UpdateRaw)} {
            set arr(UpdateRaw) false
        }
        if {$arr(UpdateBrf) || $arr(UpdateRaw)} {
            if {$arr(UpdateBrf)} {
                vputs -i2 "'$FVarBrf' needs update!"
            }
            if {$arr(UpdateRaw)} {
                vputs -i2 "'$::SimArr(FVarRaw)' needs update!"
            }
        } else {
            vputs -i1 "'$::SimArr(FVarRaw)' is the same as '$FVarBrf'!"
        }
        vputs
    }
    if {$arr(UpdateBrf)} {
        set arr(Brf|VarLst) $arr(Raw|VarLst)
        foreach Var $arr(Raw|VarLst) {
            set arr(BrfVal|$Var) $arr(RawVal|$Var)
            set arr(BrfLvl|$Var) $arr(RawLvl|$Var)
        }
    }
    if {$arr(UpdateRaw)} {
        set arr(Raw|VarLst) $arr(Brf|VarLst)
        foreach Var $arr(Raw|VarLst) {
            set arr(RawVal|$Var) $arr(BrfVal|$Var)
            set arr(RawLvl|$Var) $arr(BrfLvl|$Var)
        }
    }
}

# mfjIntrpr::readHost
#   Read simulator settings on the current host
proc mfjIntrpr::readHost {} {
    variable arr
    set arr(Host|ID) [lindex [split $::env(HOSTNAME) .] 0]
    vputs "Extracting settings from host '$arr(Host|ID)'..."
    set arr(Host|User) $::env(USER)
    vputs -v3 -i1 "User: $arr(Host|User)"
    foreach Name $::SimArr(STHosts) Sufx $::SimArr(ESuffix) {
        if {[string index $Name 0] eq [string index $arr(Host|ID) 0]} {
            set arr(Host|ESuffix) $Sufx
            break
        }
    }

    # Email format: local-part@domain
    # local-part: \w!#$%&'*+-/=?^_`{|}~.
    # domain: \w-
    if {![regexp {([\w.%+-]+@(\w+[\.-])+[a-zA-Z]{2,4})}\
        [exec getent passwd $arr(Host|User)] -> arr(Host|Email)]} {
        set arr(Host|Email) $arr(Host|User)@$arr(Host|ESuffix)
    }
    vputs -v3 -i1 "Email: $arr(Host|Email)"

    # Check available job schedulers
    if {[eval {auto_execok qsub}] ne ""} {
        lappend arr(Host|JobSched) PBS
    }
    if {[eval {auto_execok sbatch}] ne ""} {
        lappend arr(Host|JobSched) SLURM
    }
    vputs -v3 -i1 "Job scheduler available: $arr(Host|JobSched)"

    # Retrieve Sentaurus TCAD related settings
    set FoundPath true
    if {[info exists ::env(STROOT)] && [info exists ::env(LM_LICENSE_FILE)]} {
        set arr(Host|STPath) [file dirname $::env(STROOT)]
        set arr(Host|STLicn) [lindex [split $::env(LM_LICENSE_FILE) :] 0]
    } else {
        foreach Name $::SimArr(STHosts) Path $::SimArr(STPaths)\
            Licn $::SimArr(STLicns) {
            if {[string index $Name 0] eq [string index $arr(Host|ID) 0]} {
                if {[string index $Path end] eq "/"} {
                    set Path [string range $Path 0 end-1]
                }
                set arr(Host|STPath) $Path
                set arr(Host|STLicn) $Licn
                break
            }
        }
    }
    vputs -v3 -i1 "ST license: $arr(Host|STLicn)"
    foreach Name $::SimArr(STHosts) Lib $::SimArr(STLib) {
        if {[string index $Name 0] eq [string index $arr(Host|ID) 0]
            && [iFileExists Lib]} {
            set arr(Host|STLib) $Lib
            break
        }
    }
    vputs -v3 -i1 "ST shared libraries: $arr(Host|STLib)"

    # Check Sentaurus TCAD path
    if {[catch {iFileExists arr(Host|STPath)}]} {
        set FoundPath false
        vputs -v3 -i1 "ST path: Invalid '$arr(Host|STPath)'"
    } else {
        if {![file isdirectory $arr(Host|STPath)]} {
            set FoundPath false
            vputs -v3 -i1 "ST path: Invalid '$arr(Host|STPath)'"
        } else {
            vputs -v3 -i1 "ST path: $arr(Host|STPath)"
        }
    }

    # Find available Sentaurus TCAD versions
    if {$FoundPath} {
        foreach Elm [glob -nocomplain -directory $arr(Host|STPath) *] {
            set Elm [string toupper [file tail $Elm]]
            if {[regexp {^[A-Z]+-[0-9]{4}\.[0-9]{2}} $Elm]} {
                lappend arr(Host|AllSTVer) $Elm
            }
        }
    }
    set arr(Host|AllSTVer) [lsort $arr(Host|AllSTVer)]
    vputs -v3 -i1 "ST versions: $arr(Host|AllSTVer)"
    vputs
}

# mfjIntrpr::activateRR
    # Check arr(RawVarVal) and arr(RawVarGLst) to activate the replace and
    # then reuse features if necessary.
proc mfjIntrpr::activateRR {} {
    variable arr

    vputs "Activate replacing features in multiple-level variables if any..."
    set NewLst [list]
    set Sum 0
    foreach Var $arr(RawST|VarLst) {

        # Only check variables with multiple levels
        if {$arr(RawLvl|$Var) == 1} continue
        set NewVal [replace $Var $arr(RawVal|$Var)]
        if {[lindex $NewVal 0]} {
            vputs -v2 -i1 "$Var: [lindex $NewVal 0] replacing features\
                detected!"
            vputs -v2 -c "Before: \{$arr(RawVal|$Var)\}"
            vputs -v2 -c "After: \{[lindex $NewVal 1]\}\n"
            incr Sum [lindex $NewVal 0]
        }
        set arr(RawVal|$Var) [lindex $NewVal 1]
    }
    if {$Sum} {
        vputs -i1 "Totally $Sum replacing features activated!"
    } else {
        vputs -i1 "No replacing feature found!"
    }
    vputs

    vputs "Activate reuse features in all variables if any..."
    set Sum 0
    foreach Var $arr(Raw|VarLst) {
        set NewLst [list]
        set Update false
        set Cnt [regexp -all {@(-?\d+[:,/&])*-?\d+} $arr(RawGLst|$Var)]
        if {$Cnt} {
            incr Sum $Cnt
            vputs -v2 -i1 "$Var grammar: $Cnt reuse features detected!"
            vputs -v2 -c "Before: \{$arr(RawGLst|$Var)\}"
            set arr(RawGLst|$Var) [reuse $Var $arr(RawGLst|$Var)\
                $arr(RawGLst|$Var)]
            vputs -v2 -c "After: \{$arr(RawGLst|$Var)\}\n"
        }
        set Cnt [regexp -all {@(-?\d+[:,/&])*-?\d+} $arr(RawVal|$Var)]
        if {$Cnt} {
            incr Sum $Cnt
            vputs -v2 -i1 "$Var: $Cnt reuse features detected!"
            vputs -v2 -c "Before: \{$arr(RawVal|$Var)\}"
            if {$arr(RawLvl|$Var) > 1} {
                set NewVal [list]
                set Lvl 0
                foreach LvlVal $arr(RawVal|$Var) {

                    # Activate reuse only feature in level 1+:
                    # Set reference to the previous levels
                    if {[regexp {^@(-?\d+[:,/&])*-?\d+$} $LvlVal]} {
                        set LvlVal [reuse $Var $arr(RawVal|$Var)\
                            $LvlVal $Lvl $Lvl !InLvl]
                    }

                    # Activate reuse feature within each level:
                    # Set reference within the current level
                    lappend NewVal [reuse $Var $LvlVal $LvlVal $Lvl]
                    incr Lvl
                }
                set arr(RawVal|$Var) $NewVal
            } else {
                set arr(RawVal|$Var) [reuse $Var $arr(RawVal|$Var)\
                    $arr(RawVal|$Var)]
            }
            vputs -v2 -c "After: \{$arr(RawVal|$Var)\}\n"
        }
    }
    if {$Sum} {
        vputs -i1 "Totally $Sum reuse features activated!"
    } else {
        vputs -i1 "No reuse feature found!"
    }
    vputs
}

# mfjIntrpr::sortVar
    # Find and set the environment variable 'SimEnv' to be the first variable.
    # Find and set the variable 'RegGen' to be the second variable if not.
    # Additionally, sort variables so that 'RegGen' is followed immediately by
    # the rest region related variables.
proc mfjIntrpr::sortVar {} {
    variable arr
    vputs "Sort the sequence of variables if necessary..."

    vputs -i1 -n "Searching for variable 'SimEnv'..."
    set Idx [lsearch -exact $arr(Raw|VarLst) SimEnv]
    if {$Idx == -1} {
        error "missing variable 'SimEnv' in '$::SimArr(FVarRaw)'!"
    } else {
        vputs -c " found at index '$Idx'!"
        if {$Idx != 0} {
            vputs -i2 "Set 'SimEnv' to index '0'..."
            set arr(Raw|VarLst) [concat SimEnv\
                [lrange $arr(Raw|VarLst) 0 [incr Idx -1]]\
                [lrange $arr(Raw|VarLst) [incr Idx 2] end]]
        } else {
            vputs -i2 "No change!"
        }
    }

    vputs -i1 -n "Searching for variable 'RegGen'..."
    set Idx [lsearch -exact $arr(Raw|VarLst) RegGen]
    if {$Idx == -1} {
        foreach Var $arr(Raw|VarLst) {
            if {[regexp -nocase {^`?r} [lindex $arr(RawGLst|$Var) 0]]} {
                error "missing variable 'RegGen' in '$::SimArr(FVarRaw)'!"
            }
        }
        vputs -c " failed!"
    } else {
        vputs -c " found at index '$Idx'!"
        if {$Idx != 1} {
            vputs -i2 "Set 'RegGen' to index '1'..."
            set arr(Raw|VarLst) [concat SimEnv RegGen\
                [lrange $arr(Raw|VarLst) 1 [incr Idx -1]]\
                [lrange $arr(Raw|VarLst) [incr Idx 2] end]]
        } else {
            vputs -i2 "No change!"
        }
    }
    vputs
}

# mfjIntrpr::updateGrm
    # For 'SimEnv', update rules such as simulator versions and job scheduler
    # For 'ProcSeq', update rules with advanced calibration versions
proc mfjIntrpr::updateGrm {} {
    variable arr

    vputs "Update grammar for 'SimEnv' if necessary..."

    # Check and update job scheduler settings in 'SimEnv'
    set UpdateGrm false
    set SimGrm $arr(RawGLst|SimEnv)

    if {$arr(Host|AllSTVer) eq ""} {
        error "no ST version available!"
    }

    # Set the default version to the latest (a == latest)
    if {[lindex $SimGrm 1 2] ne [lindex $arr(Host|AllSTVer) end]} {
        set UpdateGrm true
        lset SimGrm 1 2 [lindex $arr(Host|AllSTVer) end]
    }
    # Sentaurus TCAD versions in the grammar vs available
    set Diff false
    set AllSTVer [string map {< "" > ""} [lrange [lindex $SimGrm 1] 5 end]]
    if {[llength $AllSTVer] == [llength $arr(Host|AllSTVer)]} {
        foreach Elm $AllSTVer {
            if {[lsearch -exact -sorted $arr(Host|AllSTVer) $Elm] == -1} {
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
        foreach Elm $arr(Host|AllSTVer) {
            lappend Lst [string map {- <-} $Elm]>
        }
        lset SimGrm 1 [concat [lrange [lindex $SimGrm 1] 0 4] $Lst]
    }

    # Index 4: Job scheduler
    if {$arr(Host|JobSched) eq ""} {
        if {[llength $SimGrm] >= 5
            && [llength [lindex $SimGrm 4]] >= 6
            && ![string equal -nocase [lindex $SimGrm 4 5] Local]} {
            set UpdateGrm true
            lset SimGrm 4 {a = Local | s Local}
        }
    } else {
        set Lst ""
        foreach Elm $arr(Host|JobSched) {
            lappend Lst [string index $Elm 0]<[string range $Elm 1 end]>
        }
        if {[llength $SimGrm] >= 5 && ![string equal -nocase\
            [lrange [lindex $SimGrm 4] 5 end] "$Lst Local"]} {
            set UpdateGrm true
            lset SimGrm 4 "a = Local | s $Lst Local"
        }
    }

    # Output the grammar of 'SimEnv' if updated
    if {$UpdateGrm} {
        set arr(UpdateRaw) true
        set arr(RawGLst|SimEnv) $SimGrm
        set Idx 0
        set Str ""
        foreach Elm $SimGrm {
            if {$Idx == 0} {
                append Str [wrapText \{$Elm\}]
            } else {
                append Str [wrapText \n\{$Elm\}]
            }
            incr Idx
        }
        set arr(RawGStr|SimEnv) $Str
        vputs -i1 "Updated 'SimEnv' grammar: $arr(RawGLst|SimEnv)"
    } else {
        vputs -i1 "No update!"
    }

    vputs -n "Update grammar for 'ProcSeq' if necessary..."
    set Idx [lsearch -exact $arr(Raw|VarLst) ProcSeq]
    if {$Idx == -1} {
        vputs -c " not found!"
    } else {
        vputs -c " found at index '$Idx'!"

        # Check and update job scheduler settings in 'ProcSeq'
        set UpdateGrm false
        set SimGrm $arr(RawGLst|ProcSeq)
        regexp {\(([^)]+)\)} [lindex $SimGrm 1] -> GrmStr

        # Set the default version to the latest (a == latest)
        if {[lindex $GrmStr 2] ne [lindex $arr(Host|AllSTVer) end]} {
            set UpdateGrm true
            lset GrmStr 2 [lindex $arr(Host|AllSTVer) end]
        }

        # Sentaurus TCAD versions in the grammar vs available
        set Diff false
        set AllSTVer [string map {< "" > ""} [lrange $GrmStr 5 end]]
        if {[llength $AllSTVer] == [llength $arr(Host|AllSTVer)]} {
            foreach Elm $AllSTVer {
                if {[lsearch -exact -sorted $arr(Host|AllSTVer) $Elm] == -1} {
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
            foreach Elm $arr(Host|AllSTVer) {
                lappend Lst [string map {- <-} $Elm]>
            }
            set GrmStr ([concat [lrange $GrmStr 0 4] $Lst])

            # Substitute matched string
            lset SimGrm 1 [regsub {\([^)]+\)} [lindex $SimGrm 1] $GrmStr]
        }

        # Output the grammar of 'ProcSeq' if updated
        if {$UpdateGrm} {
            set arr(UpdateRaw) true
            set arr(RawGLst|ProcSeq) $SimGrm
            set Idx 0
            set Str ""
            foreach Elm $SimGrm {
                if {$Idx == 0} {
                    append Str [wrapText \{$Elm\}]
                } else {
                    append Str [wrapText \n\{$Elm\}]
                }
                incr Idx
            }
            lset arr(RawGStr|ProcSeq) $Str
            vputs -i1 "Updated 'ProcSeq' grammar: $arr(RawGLst|ProcSeq)"
        } else {
            vputs -i1 "No update!"
        }
    }
    vputs
}

# mfjIntrpr::validateVar
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
proc mfjIntrpr::validateVar {} {
    variable arr
    vputs "Validating variables..."
    set ::SimArr(ModTime) ""
    foreach Elm [list RegInfo RegMat RegIdx ConLst ConLen VarLen] {
        upvar 0 $Elm Alias
        set Alias [list]
    }
    set SimIdx 0
    foreach Var $arr(Raw|VarLst) {
        set VarVal $arr(RawVal|$Var)

        # Validate 'SimEnv'
        if {$SimIdx == 0} {
            vputs -i1 '$Var':
            vputs -v3 -i2 "Before: \{$VarVal\}"

            # Use the string/list duality to flatten a list of any nested levels
            set VarVal [string map {\{\} \"\" \{ "" \} ""} $VarVal]

            # Revert '""' to '{}'
            set VarVal [string map {\"\" \{\}} $VarVal]
            set VarVal [mfjGrm::applyGrm $Var $VarVal $arr(RawGLst|$Var)]
            vputs -v3 -i2 "After validation: \{$VarVal\}"
            set arr(RawVal|SimEnv) $VarVal
            incr SimIdx

            # Extract material database from the selected software version
            if {[string equal -nocase [lindex $arr(RawVal|SimEnv) 0]\
                "Sentaurus"]} {
                vputs -i2 "Identifying material database from [lindex\
                    $arr(RawVal|SimEnv) 0] [lindex $arr(RawVal|SimEnv) 1]..."
                set FMat $arr(Host|STPath)/[lindex $arr(RawVal|SimEnv)\
                    1]/tcad/[lindex $arr(RawVal|SimEnv) 1]/lib/datexcodes.txt
                set ::SimArr(MatDB) [readMatDB datexcodes.txt $FMat]
                vputs
            }
            continue
        }

        # Deal with multiple levels if any
        # Users are responsible for assigning multiple levels to 'RegGen'
        if {$arr(RawLvl|$Var) > 1} {
            set LvlLen $arr(RawLvl|$Var)
            set RGLvlLen $arr(RawLvl|RegGen)
            if {$Var eq "RegGen"} {
                set RGLvlLen 1
            }
        } else {
            set LvlLen 1
            set RGLvlLen 1
        }
        vputs -i1 '$Var':

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
                if {$::SimArr(ColMode) eq "ColMode"
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
                if {[llength $arr(RawGLst|$Var)]} {
                    vputs -v3 -c "Before: \{$OldLvl\}"
                    if {[llength [lindex $arr(RawGLst|$Var) 0]]} {

                        # Split elements for group IDs 'm', 'p', 'pp', 'r', 'rr'
                        # 'b', 'd', 'o', 'q', 'v'
                        # string -> list -> sort in increasing order
                        set Grm0 [lsort [string tolower [string map\
                            {` "" | " "} [lindex $arr(RawGLst|$Var) 0]]]]
                        set Cnt 0
                        foreach Elm $Grm0 {
                            if {[regexp {^(m|p|pp|r|rr|b|d|o|q|v)$} $Elm]} {
                                incr Cnt
                            }
                        }
                        if {[llength $Grm0] == $Cnt} {
                            set GID true
                        } else {
                            if {$Cnt} {
                                error "unknown group ID found in\
                                    '[lindex $arr(RawGLst|$Var) 0]'!"
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
                            set NewLvl [groupValues $Var $OldLvl $Grm0\
                                $LvlIdx $LvlLen]
                        } else {
                            set NewLvl $OldLvl
                        }
                        vputs -v3 -c "After grouping: \{$NewLvl\}"
                        set GrpLen [llength $NewLvl]
                    } else {
                        set GrpLen 1
                    }

                    # Apply grammar check to each element in a list or sublist
                    set Lst [list]
                    for {set k 0} {$k < $GrpLen} {incr k} {
                        if {$GID} {
                            set Val [lindex $NewLvl $k]
                            lappend Lst [mfjGrm::applyGrm $Var $Val\
                                $arr(RawGLst|$Var)]
                        } else {
                            set Lst [mfjGrm::applyGrm $Var $OldLvl\
                                $arr(RawGLst|$Var)]
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
        if {$Var eq "RegGen"} {
            set arr(RawVal|RegGen) $NewLst
            valRegGen
            incr SimIdx
            continue
        }

        # Extract contacts from 'IntfAttr' if present
        if {$Var eq "IntfAttr"} {
            if {$arr(RawLvl|$Var) == 1} {
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
            if {$arr(RawLvl|$Var) == 1} {
                set VarLen [llength $NewLst]
            } else {
                foreach Lst $NewLst {
                    lappend VarLen [llength $Lst]
                }
            }
            set ::SimArr(VarLen) $VarLen
        }

        set arr(RawVal|$Var) $NewLst
        incr SimIdx
    }

    # Include key ST files in ::SimArr(ModTime)
    if {$arr(Raw|STLst) ne ""} {
        foreach Tool $arr(Raw|STLst) {
            set Idx [lsearch -exact $::SimArr(STTools) $Tool]
            set FCmd $arr(RawLbl|$Tool)[lindex $::SimArr(STSuffix) $Idx]
            if {$Tool eq "sdevice"} {
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

    # Include key Tcl files, datexcodes.txt, Molefraction.txt and PMI files
    foreach Elm [concat 11ctrlsim.tcl datexcodes.txt Molefraction.txt\
        [glob -nocomplain .mfj/mfj*.tcl $::SimArr(PMIDir)/*.\[cC\]]] {
        lappend ::SimArr(ModTime) [list $Elm [file mtime $Elm]]
    }
    vputs -v3 -i1 "Files for simulation and their modification time:"

    # Only keep the last duplicate file found
    set ::SimArr(ModTime) [lsort -unique -index 0 $::SimArr(ModTime)]
    vputs -v3 -c $::SimArr(ModTime)
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
    if {[lindex $arr(Raw|VarLst) 1] ne "RegGen"} {
        error "attempting to access a non-existing variable 'RegGen'!"
    }
    vputs -i2 "Further validation:"
    set VarMsg "variable 'RegGen'"
    foreach Elm [list RegInfo RegGen RegMat RegIdx] {
        set $Elm [list]
    }
    set GasThx $::SimArr(GasThx)
    set LvlLen $arr(RawLvl|RegGen)
    set VarVal $arr(RawVal|RegGen)
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
        foreach Elm {YMax1st ZMax1st XMax YMax ZMax X1 X2 Y1 Y2 Z1 Z2 Lyr
            RegSeq NegSeq Imp} {
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
            if {[string is double -strict [lindex $DimLst 0]]} {

                # Regions are specified using the implicit method, which
                # determines the simulation domain. Calculate two diagonal
                # points for each specified region (1D, 2D and 3D).
                set Imp true
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

                # Set YMax of the first layer
                if {$Y1 == 0 && $Z1 == 0 && $YMax1st == 0 && $YMax > 0} {
                    set YMax1st $YMax
                }

                # Set ZMax of the first section/layer
                if {$Z1 == 0 && $ZMax1st == 0 && $ZMax > 0} {
                    set ZMax1st $ZMax
                }

                # The last region: update dimensions for alignment check
                if {$Seq == $RegLen} {
                    set XMax [format %.12g $X2]
                    set YMax [format %.12g $Y2]
                    set ZMax [format %.12g $Z2]
                }

                # Check Y alignment against the first layer
                if {($Y1 == 0 && $Z1 == 0 || $Seq == $RegLen) && $YMax1st > 0
                    && abs($YMax1st-$YMax) > 1e-7} {
                    error "YMax '$YMax' is different from the first\
                        layer YMax '$YMax1st' in $Msg!"
                }

                # Check Z alignment against the first section/layer
                if {($Z1 == 0 || $Seq == $RegLen) && $ZMax1st > 0
                    && abs($ZMax1st-$ZMax) > 1e-7} {
                    error "ZMax '$ZMax' is different from the first\
                        section/layer ZMax '$ZMax1st' in $Msg!"
                }

                # Update the max size of each dimension with the current region
                if {$Seq != $RegLen} {
                    set XMax $X2
                    set YMax $Y2
                    set ZMax $Z2
                }
            } else {

                # Regions specified using the explicit method. No alignment
                # check so users are responsible for drawing reasonable regions.
                # Any region outside of the simulation domain is trimmed
                if {$Imp} {
                    error "The explicit method should be specified before the\
                        implicit method!"
                }
                if {[string equal -nocase [lindex $DimLst 1] "Remove"]} {
                    lset Mat 1 [incr NegSeq -1]_[lindex $Mat 0]
                    lset Mat end $NegSeq
                    set RegID $NegSeq
                } elseif {[string equal -nocase [lindex $DimLst 1] "Merge"]} {

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
                if {[string equal -nocase [lindex $DimLst 0] "Block"]} {

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
                } elseif {[string equal -nocase [lindex $DimLst 0] "Vertex"]} {
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

        if {!$Imp} {
            error "no implicit method for defining simulation domain!"
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
        # If it is 'Optical', the total regions are N despite the dimensions
        set Tmp $RegSeq
        if {[string index [lindex $arr(RawVal|SimEnv) 2] 0] eq "!"} {
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
                lset arr(RawVal|SimEnv) 2 !Cylindrical
            }
        }
        if {[string equal -nocase [lindex $arr(RawVal|SimEnv) 3] "Optical"]} {
            set NOD [expr int(ceil(log10($Tmp)))]
        } else {
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

        if {![string equal -nocase [lindex $arr(RawVal|SimEnv) 3] "Optical"]} {

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
        vputs -i$Idt "Totally '[incr RegSeq]' regions (including dummies)!"
        vputs -v3 -c "Region info: \{$RILvl\}"
        vputs -v3 -c "Region materials: \{$MatLst\}"
        vputs -v3 -c "Region indices: \{$IdxLst\}"
        vputs -v3 -c "After conversion: \{$RegGen\}\n"
    }
    set ::SimArr(RegInfo) $RegInfo
    set ::SimArr(RegMat) $RegMat
    set ::SimArr(RegIdx) $RegIdx
    set arr(RawVal|RegGen) $RegGen
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
        set Str ""
        set Flg true
        set Inf [open $::SimArr(FVarFmt) r]
        vputs -v3 -i1 "Reserved variables:"
        while {[gets $Inf Line] != -1} {
            if {[regexp {\S} $Line]} {
                append Str "[string trimleft $Line] "
            } else {
                if {$Str ne ""} {
                    if {[string index $Str 0] eq "#"} {
                        if {[regexp -nocase $::SimArr(STDfltID) $Str\
                            -> Lbl Tool]} {
                            set ReadVar true
                            lappend arr(Fmt|STLst) $Tool
                            set arr(FmtLbl|$Tool) $Lbl
                            set arr(Fmt$Tool|VarLst) [list]
                            vputs -v3 -i1 "ST tool: '$Tool'\tlabel: '$Lbl'"
                        }
                    } else {
                        set Var [lindex $Str 0]
                        if {$ReadVar} {
                            lappend arr(Fmt|VarLst) $Var
                            lappend arr(FmtST|VarLst) $Var
                            lappend arr(Fmt$Tool|VarLst) $Var
                        } else {
                            if {[regexp {^mfj\w+$} $Var]} {
                                lappend arr(FmtRsvd|VarLst) $Var
                            } else {
                                if {$Flg} {
                                    vputs -v3 -i1 "Environment variables:"
                                    set Flg false
                                }
                                lappend arr(FmtEnv|VarLst) $Var
                                lappend arr(Fmt|VarLst) $Var
                            }
                        }
                        set Len [llength $Str]
                        set arr(FmtLvl|$Var) [incr Len -1]
                        if {$Len > 1} {
                            set arr(FmtVal|$Var) [lrange $Str 1 end]
                        } else {
                            set arr(FmtVal|$Var) [lindex $Str 1]
                        }
                        vputs -v3 -i2 "$Var: \{$arr(FmtVal|$Var)\}"
                    }
                }
                set Str ""
            }
        }
        close $Inf
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

    # Construct reserved variables for ::SimArr(FVarRaw)
    set arr(RawRsvd|VarLst) {mfjDfltSet mfjRegInfo mfjSTLst mfjModTime}
    foreach Var $arr(RawRsvd|VarLst) {
        set arr(RawLvl|$Var) 1
    }
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
    set arr(RawVal|mfjDfltSet) $DfltSet
    set arr(RawVal|mfjRegInfo) $::SimArr(RegInfo)
    set arr(RawVal|mfjSTLst) $arr(Raw|STLst)
    set arr(RawVal|mfjModTime) $::SimArr(ModTime)

    # Everything within the format file is case sensitive
    if {!$arr(UpdateFmt)} {
        vputs "Comparing '$::SimArr(FVarFmt)' against '$::SimArr(FVarRaw)'..."
        set Msg "'$::SimArr(FVarFmt)' is different from '$::SimArr(FVarRaw)'!"
        foreach Tool {Rsvd Env} Str {Reserved Environment} {

            # Variable sequence doesn't matter
            foreach Var $arr(Fmt$Tool|VarLst) {
                if {[lsearch -exact $arr(Raw$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "$Str variable '$Var' in\
                        '$::SimArr(FVarRaw)' removed!"
                    continue
                }
                if {$arr(FmtVal|$Var) ne $arr(RawVal|$Var)} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "$Str variable '$Var' has a value of\
                        '$arr(FmtVal|$Var)' different from\
                        '$arr(RawVal|$Var)'!"
                }

                # Remove all compiled PMI share objects if version changes
                if {$Var eq "SimEnv" && [lindex $arr(FmtVal|SimEnv) 1]\
                    ne [lindex $arr(RawVal|SimEnv) 1]} {
                    foreach Elm [glob -nocomplain $::SimArr(PMIDir)/*.so.*] {
                        vputs -i2 "File '$Elm' deleted!"
                        file delete $Elm
                    }
                }

                # List detailed file changes
                if {$Var eq "mfjModTime"} {
                    set ModTime $arr(RawVal|mfjModTime)
                    foreach Elm $arr(FmtVal|mfjModTime) {
                        set Lst [list]
                        set FmtFlg false
                        foreach Grp $ModTime {
                            if {[lindex $Elm 0] eq [lindex $Grp 0]} {
                                set FmtFlg true
                                if {[lindex $Elm 1] != [lindex $Grp 1]} {
                                    if {!$arr(UpdateFmt)} {
                                        set arr(UpdateFmt) true
                                        vputs -i1 $Msg
                                    }
                                    vputs -i3 "File '[lindex $Elm 0]' updated!"

                                    # If PMI files are updated, remove the
                                    # corresponding share objects
                                    if {[string equal -nocase .c\
                                        [file extension [lindex $Elm 0]]]} {
                                        set Obj [glob -nocomplain [file\
                                            rootname [lindex $Elm 0]].so.*]
                                        if {$Obj ne ""} {
                                            vputs -i3 "File '$Obj' deleted!"
                                            file delete $Obj
                                        }
                                    }
                                }
                            } else {
                                lappend Lst $Grp
                            }
                        }

                        # Update ModTime to remove the matched file
                        set ModTime $Lst

                        # Output each file removed
                        if {!$FmtFlg} {
                            if {!$arr(UpdateFmt)} {
                                set arr(UpdateFmt) true
                                vputs -i1 $Msg
                            }
                            vputs -i3 "File '[lindex $Elm 0]' removed!"
                        }
                    }

                    # Output the remaining files in ::SimArr(ModTime)
                    foreach Elm $ModTime {
                        if {!$arr(UpdateFmt)} {
                            set arr(UpdateFmt) true
                            vputs -i1 $Msg
                        }
                        vputs -i3 "File '[lindex $Elm 0]' added!"
                    }
                }
            }
            foreach Var $arr(Raw$Tool|VarLst) {
                if {[lsearch -exact $arr(Fmt$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "$Str variable '$Var' in\
                        '$::SimArr(FVarRaw)' added!"
                }
            }
        }

        # Check ST tools and variables. Tools should have the same sequence
        if {$arr(Fmt|STLst) ne $arr(Raw|STLst)} {
            if {!$arr(UpdateFmt)} {
                set arr(UpdateFmt) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "ST tools '$arr(Fmt|STLst)' different from\
                '$arr(Raw|STLst)'!"
        }
        foreach Tool $arr(Fmt|STLst) {
            if {$arr(FmtLbl|$Tool) ne $arr(RawLbl|$Tool)} {
                if {!$arr(UpdateFmt)} {
                    set arr(UpdateFmt) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "ST tool label '$arr(FmtLbl|$Tool)' different\
                    from '$arr(RawLbl|$Tool)'!"
            }

            # Variable sequence for each tool doesn't matter
            foreach Var $arr(Fmt$Tool|VarLst) {
                if {[lsearch -exact $arr(Raw$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool'\
                        removed!"
                    continue
                }
                if {$arr(FmtVal|$Var) ne $arr(RawVal|$Var)} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' has a value of\
                        '$arr(FmtVal|$Var)' different from\
                        '$arr(RawVal|$Var)'!"
                }
            }
            foreach Var $arr(Raw$Tool|VarLst) {
                if {[lsearch -exact $arr(Fmt$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool' added!"
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
        set arr(FmtRsvd|VarLst) $arr(RawRsvd|VarLst)
        set arr(FmtEnv|VarLst) $arr(RawEnv|VarLst)
        set arr(FmtST|VarLst) $arr(RawST|VarLst)
        set arr(Fmt|VarLst) $arr(Raw|VarLst)
        foreach Var [concat $arr(FmtRsvd|VarLst) $arr(Fmt|VarLst)] {
            set arr(FmtVal|$Var) $arr(RawVal|$Var)
            set arr(FmtLvl|$Var) $arr(RawLvl|$Var)
        }
        set arr(Fmt|STLst) $arr(Raw|STLst)
        foreach Tool $arr(Fmt|STLst) {
            set arr(FmtLbl|$Tool) $arr(RawLbl|$Tool)
            set arr(Fmt$Tool|VarLst) $arr(Raw$Tool|VarLst)
        }
    }
}

# mfjIntrpr::fmtvsTcl
    # Compare ::SimArr(FVarFmt) against ::SimArr(FVarEnv) and ::SimArr(FVarSim)
    # and set arr(UpdateFmt) to be true if there is any difference
proc mfjIntrpr::fmtvsTcl {} {
    variable arr

    # Assumption: Changes in Sentaurus workbench are related to workbench
    # variables. Everything within the format file is case sensitive
    if {!$arr(UpdateFmt)} {
        vputs "Comparing '$::SimArr(FVarFmt)' against '$::SimArr(FVarSim)'..."

        # Check ST Tools and variables. Tools should have the same sequence
        set Msg "'$::SimArr(FVarFmt)' is different from '$::SimArr(FVarSim)'!"
        if {$arr(Fmt|STLst) ne $mfjST::arr(Tcl|STLst)} {
            if {!$arr(UpdateFmt)} {
                set arr(UpdateFmt) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "ST tools '$arr(Fmt|STLst)' different from\
                '$mfjST::arr(Tcl|STLst)'!"
        }
        foreach Tool $arr(Fmt|STLst) {
            if {$arr(FmtLbl|$Tool) ne $mfjST::arr(TclLbl|$Tool)} {
                if {!$arr(UpdateFmt)} {
                    set arr(UpdateFmt) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "ST tool label '$arr(FmtLbl|$Tool)' different\
                    from '$mfjST::arr(TclLbl|$Tool)'!"
            }

            # Variables for a tool may have a different sequence
            foreach Var $arr(Fmt$Tool|VarLst) {
                if {[lsearch -exact $mfjST::arr(Tcl$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool'\
                        removed!"
                    continue
                }
                if {$arr(FmtVal|$Var) ne $mfjST::arr(TclVal|$Var)} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' has a value of\
                        '$arr(FmtVal|$Var)' different from\
                        '$mfjST::arr(TclVal|$Var)'!"
                }
            }
            foreach Var $mfjST::arr(Tcl$Tool|VarLst) {
                if {[lsearch -exact $arr(Fmt$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateFmt)} {
                        set arr(UpdateFmt) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool' added!"
                }
            }
            incr STIdx
        }
        if {!$arr(UpdateFmt)} {
            vputs -i1 "'$::SimArr(FVarFmt)' is the same as\
                '$::SimArr(FVarSim)'!"
        }
        vputs
    }
    if {$arr(UpdateFmt)} {

        # Perform an efficient update of all related variables
        set arr(Fmt|VarLst) $mfjST::arr(Tcl|VarLst)
        foreach Var $arr(Fmt|VarLst) {
            set arr(FmtVal|$Var) $mfjST::arr(TclVal|$Var)
            set arr(FmtLvl|$Var) $mfjST::arr(TclLvl|$Var)
        }
        set arr(Fmt|STLst) $mfjST::arr(Tcl|STLst)
        foreach Tool $arr(Fmt|STLst) {
            set arr(FmtLbl|$Tool) $mfjST::arr(TclLbl|$Tool)
            set arr(Fmt$Tool|VarLst) $mfjST::arr(Tcl$Tool|VarLst)
        }
    }
}

# mfjIntrpr::rawvsFmt
    # Compare ::SimArr(FVarRaw) against ::SimArr(FVarFmt) and set arr(UpdateRaw)
    # and arr(UpdatBrf) to be true if there is any difference
proc mfjIntrpr::rawvsFmt {} {
    variable arr

    # Assumption: Changes in Sentaurus workbench are related to workbench
    # variables. Everything within the format file is case sensitive
    if {!$arr(UpdateRaw)} {
        vputs "Comparing '$::SimArr(FVarRaw)' against '$::SimArr(FVarFmt)'..."

        # Check ST Tools and variables. Tools should have the same sequence
        set Msg "'$::SimArr(FVarRaw)' is different from '$::SimArr(FVarFmt)'!"
        if {$arr(Raw|STLst) ne $arr(Fmt|STLst)} {
            if {!$arr(UpdateRaw)} {
                set arr(UpdateRaw) true
                vputs -i1 $Msg
            }
            vputs -v3 -i2 "ST tools '$arr(Raw|STLst)' different from\
                '$arr(Fmt|STLst)'!"
        }
        foreach Tool $arr(Raw|STLst) {
            if {$arr(RawLbl|$Tool) ne $arr(FmtLbl|$Tool)} {
                if {!$arr(UpdateRaw)} {
                    set arr(UpdateRaw) true
                    vputs -i1 $Msg
                }
                vputs -v3 -i2 "ST tool label '$arr(RawLbl|$Tool)' different\
                    from '$arr(FmtLbl|$Tool)'!"
            }

            # Variable sequence for each tool doesn't matter
            foreach Var $arr(Raw$Tool|VarLst) {
                if {[lsearch -exact $arr(Fmt$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateRaw)} {
                        set arr(UpdateRaw) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool'\
                        removed!"
                    continue
                }
                if {$arr(RawVal|$Var) ne $arr(FmtVal|$Var)} {
                    if {!$arr(UpdateRaw)} {
                        set arr(UpdateRaw) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' has a value of\
                        '$arr(RawVal|$Var)' different from\
                        '$arr(FmtVal|$Var)'!"
                }
            }
            foreach Var $arr(Raw$Tool|VarLst) {
                if {[lsearch -exact $arr(Fmt$Tool|VarLst) $Var] == -1} {
                    if {!$arr(UpdateRaw)} {
                        set arr(UpdateRaw) true
                        vputs -i1 $Msg
                    }
                    vputs -v3 -i2 "Simulation variable '$Var' of '$Tool' added!"
                }
            }
        }
        if {!$arr(UpdateRaw)} {
            vputs -i1 "'$::SimArr(FVarRaw)' is the same as\
                '$::SimArr(FVarFmt)'!"
        }
        vputs
    }
    if {$arr(UpdateRaw)} {

        # Perform an efficient update of all related variables
        set arr(Raw|VarLst) $arr(Fmt|VarLst)
        foreach Var $arr(Raw|VarLst) {
            set arr(RawVal|$Var) $arr(FmtVal|$Var)
            set arr(RawLvl|$Var) $arr(FmtLvl|$Var)
        }
        set arr(Raw|STLst) $arr(Fmt|STLst)
        foreach Tool $arr(Raw|STLst) {
            set arr(RawLbl|$Tool) $arr(FmtLbl|$Tool)
            set arr(Raw$Tool|VarLst) $arr(Fmt$Tool|VarLst)
        }

        # Update the brief file as well
        set arr(UpdateBrf) true
        set arr(Brf|VarLst) $arr(Fmt|VarLst)
        foreach Var $arr(Brf|VarLst) {
            set arr(BrfVal|$Var) $arr(FmtVal|$Var)
            set arr(BrfLvl|$Var) $arr(FmtLvl|$Var)
        }
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
        set MaxLen [calMaxVarLen $arr(Raw|VarLst)]
        vputs -v3 -c '$MaxLen'

        # Include at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]

        set Ptn [string map {(\\S+) %s} $::SimArr(STDfltID)]
        foreach Tool [concat Env $arr(Raw|STLst)] {
            if {$Tool ne "Env"} {
                puts $Ouf [format <TOOL>$Ptn\n $arr(RawLbl|$Tool) $Tool]
            }
            foreach Var $arr(Raw$Tool|VarLst) {
                if {[info exists arr(RawCmnt|$Var)]
                    && $arr(RawCmnt|$Var) ne ""} {
                    puts $Ouf <COMMENT>$arr(RawCmnt|$Var)\n
                } else {
                    puts $Ouf "<COMMENT>--- Put comments for $Var\n"
                }
                if {[info exists arr(RawGStr|$Var)]} {
                    puts $Ouf <GRAMMAR>$arr(RawGStr|$Var)\n
                } else {
                    puts $Ouf <GRAMMAR>\n
                }
                if {[info exists arr(RawCmnt1|$Var)]
                    && $arr(RawCmnt1|$Var) ne ""} {
                    puts $Ouf $arr(RawCmnt1|$Var)\n
                }

                # Increase nested level for a single level value
                if {$arr(RawLvl|$Var) == 1} {
                    set Val [list $arr(RawVal|$Var)]
                } else {
                    set Val $arr(RawVal|$Var)
                }

                # Preserve each value so it is the same as in the brief file
                puts $Ouf [wrapText [format <VAR>%-${MaxLen}s%s\n $Var $Val]]
                if {[info exists arr(RawCmnt2|$Var)]
                    && $arr(RawCmnt2|$Var) ne ""} {
                    puts $Ouf $arr(RawCmnt2|$Var)\n
                }
            }
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
        set MaxLen [calMaxVarLen $arr(Brf|VarLst)]
        vputs -v3 -c '$MaxLen'

        # With at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]

        # Output all variables
        foreach Var $arr(Brf|VarLst) {

            # Increase nested level for a single level value
            if {$arr(BrfLvl|$Var) == 1} {
                set Val [list $arr(BrfVal|$Var)]
            } else {
                set Val $arr(BrfVal|$Var)
            }

            # Ignore comments in FVarBrf
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

    if {$arr(UpdateFmt)} {
        vputs "Updating the formatted variable file '$::SimArr(FVarFmt)'..."
        if {[file isfile $::SimArr(FVarFmt)]} {
            vputs -v2 -i1 "Backing up with '$::SimArr(FVarFmt).backup'..."
            file copy -force $::SimArr(FVarFmt) $::SimArr(FVarFmt).backup
        }
        set Ouf [open $::SimArr(FVarFmt).mfj w]
        vputs -v3 -i2 -n "Calculating the max length of variable names... "
        set MaxLen [calMaxVarLen [concat $arr(Fmt|VarLst) $arr(FmtRsvd|VarLst)]]

        # No leading space, at least one space between a variable and its value
        set MaxLen [expr {int(ceil(($MaxLen+1.)/4.))*4}]
        vputs -v3 -c '$MaxLen'

        # No extra trailing spaces
        puts $Ouf "$::SimArr(Prefix) Variables with validated values\n"
        set Ptn [string map {(\\S+) %s} $::SimArr(STDfltID)]
        foreach Tool [concat Rsvd Env $arr(Fmt|STLst)] {
            if {$Tool ne "Rsvd" && $Tool ne "Env"} {
                puts $Ouf [format "# $Ptn\n" $arr(FmtLbl|$Tool) $Tool]
            }
            foreach Var $arr(Fmt$Tool|VarLst) {

                # Increase nested level for a single level value
                if {$arr(FmtLvl|$Var) == 1} {
                    set Val [list $arr(FmtVal|$Var)]
                } else {
                    set Val $arr(FmtVal|$Var)
                }
                puts $Ouf [wrapText [format %-${MaxLen}s%s\n $Var $Val]\
                    $mfjProc::arr(Tab)]
            }
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
    foreach Elm {readHost readRaw readBrf rawvsBrf updateBrf activateRR sortVar
        updateGrm validateVar readFmt fmtvsRaw updateFmt updateRaw} {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

# mfjIntrpr::tcl2Raw
    # Reverse the actions in raw2Fmt to update the raw variable file
proc mfjIntrpr::tcl2Raw {} {
    foreach Elm {readFmt fmtvsTcl updateFmt readRaw rawvsFmt updateRaw
        updateBrf} {
        if {[catch $Elm ErrMsg]} {
            vputs -c "\nError in proc '$Elm':\n$ErrMsg\n"
            exit 1
        }
    }
}

package provide mfjIntrpr $mfjIntrpr::version
