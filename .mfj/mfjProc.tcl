################################################################################
# This namespace is designed to group procedures for generic usage.
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
################################################################################

package require Tcl 8.4

namespace eval mfjProc {
    variable version 2.0
    variable arr
    array set arr {
        Indent1 0
        Indent2 0
        Tab "    "
        FOut ""
        FLog ""
        MaxVerb 1
        LineLen 80
    }

    # Refer to Tables 162 and 163 in sdevice manual
    array set TabArr {
        Al Aluminum|cm^-3 As Arsenic|cm^-3 B Boron|cm^-3 C Carbon|cm^-3
        F Fluorine|cm^-3 Ge Germanium|cm^-3 In Indium|cm^-3 N Nitrogen|cm^-3
        P Phosphorus|cm^-3 Sb Antimony|cm^-3 x xMoleFraction|1
        y yMoleFraction|1 PD AbsorbedPhotonDensity|cm^-3*s^-1
        Dn ExcessCarrierDensity|cm^-3 n eDensity|cm^-3 p hDensity|cm^-3
        UA AugerRecombination|cm^-3*s^-1 UB RadiativeRecombination|cm^-3*s^-1
        US srhRecombination|cm^-3*s^-1 UP PMIRecombination|cm^-3*s^-1
        UT TotalRecombination|cm^-3*s^-1 Gop OpticalGeneration|cm^-3*s^-1
        Eg BandGap|eV BGN BandgapNarrowing|eV ni IntrinsicDensity|cm^-3
        EA ElectronAffinity|eV EC ConductionBandEnergy|eV
        EV ValenceBandEnergy|eV EFe eQuasiFermiEnergy|eV
        EFh hQuasiFermiEnergy|eV Band BandDiagram|eV
        NA AcceptorConcentration|cm^-3 ND DonorConcentration|cm^-3
        UD eGapStatesRecombination|cm^-3*s^-1 Eg_eff EffectiveBandGap|eV
        ni_eff EffectiveIntrinsicDensity|cm^-3
        V ElectrostaticPotential|V q SpaceCharge|cm^-3
        UT TotalRecombination|cm^-3*s^-1 eBT eBarrierTunneling|cm^-3*s^-1
        hBT hBarrierTunneling|cm^-3*s^-1 eQt eTrappedCharge|cm^-3
        hQt hTrappedCharge|cm^-3 E Abs(ElectricField-V)|V/cm
        UI SurfaceRecombination|cm^-2*s^-1 Dop DopingConcentration|cm^-3
    }
    namespace export {[a-z]*}
}

# Performance hints: http://wiki.tcl.tk/348

# mfjProc::vputs
    # This function adds additional controls to 'puts' to achieve versatile
    # output profiles.
    # 1. Terminal output is determined by a global verbosity level. A string
        # with a higher verbosity is not sent to a terminal.
    # 2. Output is typically indented and indentation is controlled by 'Tab',
        # 'Indent1', 'Indent2' from array 'arr' and variable 'Indent'.
        # Indentation may be disabled by specifying '-c'.
    # 3. Line splitting is the default behaviour for better reading pleasure
        # using a terminal output. Each line is no more than 80 characters.
    # 4. After line splitting. Except the first line, the rest lines are
        # neatly indented with an additional indentation (one tab), which is
        # so called hanging indents. The same indentation can be re-enforced
        # by specifying '-s'.
    # 5. Line splitting can be suppressed by specifying '-o'. A string is
        # output as it is.
    # 6. Terminal output is copied to 'FOut' for reference later. For the
        # diagnostic purpose, all strings are copied to 'FLog' despite
        # the verbosity setting.
# Arguments:
    # -c          Write right after the current position, indentation ignored
    # -n          No new line
    # -o          Output a string as it is
    # -s          Same indentation
    # -w          Write instead of default appending output to FOut and FLog
    # -i#         Specify tabs for string indentation
    # -v#         Specify a verbosity level and check against the global
                    # verbosity setting to determine whether a string should
                    # appear on a terminal
# Result: No return value
proc mfjProc::vputs args {
    variable arr

    # Default vputs behaviour
    set Access a
    set Continue false
    set NewLine true
    set OneLine false
    set SameInt false
    set Indent 0
    set Verbosity 1
    set Str [lindex $args end]
    set args [lrange $args 0 end-1]

    # Analyse arguments
    while {[llength $args]} {
        switch -glob -- [lindex $args 0] {
            -[cC] {
                set Continue true
                set args [lrange $args 1 end]
            }
            -[nN] {
                set NewLine false
                set args [lrange $args 1 end]
            }
            -[oO] {
                set OneLine true
                set args [lrange $args 1 end]
            }
            -[sS] {
                set SameInt true
                set args [lrange $args 1 end]
            }
            -[wW] {
                set Access w
                set args [lrange $args 1 end]
            }
            -[iI]* {
                set Indent [string range [lindex $args 0] 2 end]
                set args [lrange $args 1 end]
            }
            -[vV]* {
                set Verbosity [string range [lindex $args 0] 2 end]
                set args [lrange $args 1 end]
            }
            -- {
                set args [lrange $args 1 end]
                break
            }
            -* {
                error "unknown option '[lindex $args 0]'!"
            }
            default {
                error "wrong # args: should be \"vputs ?-c|n|o|s|w|i|v? string\""
            }
        }
    }

    # Calculate indentation
    set Prefix ""
    set Val 0
    set Msg "expecting an integer, but got"
    if {!$Continue} {
        if {![string is integer -strict $Indent]} {
            error "option '-i' $Msg '$Indent'!"
        }
        if {![string is integer -strict $arr(Indent1)]} {
            error "variable 'Indent1' in array 'arr' $Msg '$arr(Indent1)'!"
        }
        if {![string is integer -strict $arr(Indent2)]} {
            error "variable 'Indent2' in array 'arr' $Msg '$arr(Indent2)'!"
        }
        set Val [expr {$arr(Indent1)+$arr(Indent2)+$Indent}]
        set Prefix [string repeat $arr(Tab) $Val]
        set Len [expr {[string length $arr(Tab)]*abs($Val)}]
        set Idx [expr {$Len-1}]
    }

    # Output according to the verbosity level set by a user
    if {![regexp {^\d+$} $Verbosity]} {
        error "option '-v' $Msg '$Verbosity'!"
    }

    # Apply indentation (even to empty strings)
    # Strictly treat strings as strings
    if {$Str ne ""} {
        if {$OneLine} {
            set Msg $Str
        } else {
            set Cnt 0
            set Msg ""
            foreach Txt [split $Str \n] {
                if {$Val >= 0} {
                    if {$SameInt} {
                        set Txt [wrapText $Txt $Prefix "" !HangIdt]
                    } else {
                        set Txt [wrapText $Txt $Prefix]
                    }
                } else {

                    # Outdent each line
                    if {[regexp {\S} [string range $Txt 0 $Idx]]} {
                        set Txt [string trimleft $Txt]
                        if {[string length $Txt] > $arr(LineLen)} {
                            set Txt [wrapText $Txt]
                        }
                    } else {
                        set Txt [string range $Txt $Len end]
                        if {[string length $Txt] > $arr(LineLen)} {

                            # Preserve the leading spaces
                            set Tmp ""
                            foreach Char [split $Txt ""] {
                                if {$Char eq " "} {
                                    append Tmp $Char
                                } else {
                                    break
                                }
                            }
                            set Txt [wrapText [string trimleft $Txt] $Tmp]
                        }
                    }
                }
                if {$Cnt} {
                    append Msg \n $Txt
                } else {
                    set Msg $Txt
                }
                incr Cnt
            }
        }
    } else {
        set Msg "${Prefix}$Str"
    }
    if {$Verbosity <= $arr(MaxVerb)} {
        if {$NewLine} {
            puts $Msg
        } else {
            puts -nonewline $Msg
        }
        if {$arr(FOut) ne ""} {
            if {$Access eq "w" && [file isfile $arr(FOut)]} {
                file copy -force $arr(FOut) $arr(FOut).backup
            }
            if {[catch {set Ouf [open $arr(FOut) $Access]}]} {
                error "can't open '$arr(FOut)' for '$Access'!"
            }
            if {$NewLine} {
                puts $Ouf $Msg
            } else {
                puts -nonewline $Ouf $Msg
            }
            close $Ouf
        }
    }

    # Output anyway for debugging in case of an error
    if {$arr(FLog) ne ""} {
        if {$Access eq "w" && [file isfile $arr(FLog)]} {
            file copy -force $arr(FLog) $arr(FLog).backup
        }
        if {[catch {set Ouf [open $arr(FLog) $Access]}]} {
            error "can't open '$arr(FLog)' for '$Access'!"
        }
        if {$NewLine} {
            puts $Ouf $Msg
        } else {
            puts -nonewline $Ouf $Msg
        }
        close $Ouf
    }
}

# mfjProc::wrapText
    # Wrap a text output into multiple lines (Default margin 80 characters/line)
    # Each line may be proceeded by an optional leading text and followed by an
    # optional trailing text. In addition to the leading text, a hanging indent
    # (one tab size) is applied to the rest lines by default for reading clarity.
# Arguments
    # Text            A long text
    # Lead            Optional, the leading text
    # Trail           Optional, the trailing text
    # HangIdt         Optional, enable/disable a hanging indent
# Result: Return a new text with delimited by \n
proc mfjProc::wrapText {Text {Lead ""} {Trail ""} {HangIdt ""} } {
    variable arr

    # Validate arguments
    if {[string index $HangIdt 0] eq "!"} {
        set Tab ""
    } else {
        set Tab $arr(Tab)
    }

    # Set a few constants
    set LeadLen [string length $Lead]
    set TrailLen [string length $Trail]
    set TabLen [string length $Tab]

    # Split text to multiple paragraphs if any
    set NewText ""
    set Cnt1 0
    foreach Para [split $Text \n] {

        # Substitute multiple spaces with one space
        # set Para [regsub -all {\s+} $Para " "]
        set MaxLen [expr $arr(LineLen)-$LeadLen-$TrailLen]
        set MaxIdx $MaxLen
        incr MaxIdx -1

        # Only treat each paragraph as a string
        # It may cause issues if treated as a list
        set ParaLen [string length $Para]
        set Cnt2 0
        set NewPara ""
        while {$ParaLen > 0} {
            set LongStr false
            if {$ParaLen <= $MaxLen} {

                # Para length within margin
                set Line $Para
                set Para ""
            } else {
                set Line [string range $Para 0 $MaxIdx]

                # Paragraph length beyond margin so split text
                if {[string index $Para $MaxLen] eq " "} {
                    set Para [string range $Para [expr $MaxLen+1] end]
                } else {

                    # A do-until loop to find the 1st space within the margin
                    set Idx $MaxLen
                    while {$Idx > 0} {
                        if {[string index $Para [incr Idx -1]] eq " "} {
                            incr Idx -1
                            break
                        }
                    }
                    if {$Idx == 0} {

                        # Found a very long string without any space
                        # Try to fit it by removing leading and trailing text
                        set LongStr true
                        set Line [string range $Para 0 $arr(LineLen)]
                        if {[string index $Para $arr(LineLen)] eq " "} {
                            set Para [string range $Para\
                                [expr $arr(LineLen)+1] end]
                        } else {
                            set Idx $arr(LineLen)
                            while {$Idx > 0} {
                                if {[string index $Para [incr Idx -1]] eq " "} {
                                    incr Idx -1
                                    break
                                }
                            }
                            if {$Idx == 0} {

                                # Found an extremely long continuous string
                                # Stop wrapping it
                                set Idx $arr(LineLen)
                                while {$Idx < $ParaLen} {
                                    if {[string index $Para $Idx] eq " "} {
                                        incr Idx -1
                                        break
                                    }
                                    incr Idx
                                }
                                set Line [string range $Para 0 $Idx]
                                set Para [string range $Para [incr Idx 2] end]
                            } else {
                                set Line [string range $Para 0 $Idx]
                                set Para [string range $Para [incr Idx 2] end]
                            }
                        }
                    } else {

                        # Found a space within the margin
                        set Line [string range $Para 0 $Idx]
                        set Para [string range $Para [incr Idx 2] end]
                    }
                }
            }
            if {$Cnt2} {

                # Insert a newline before the subsequent lines and add hanging
                if {$LongStr} {
                    append NewPara \n $Line
                } else {
                    append NewPara \n $Lead $Tab $Line $Trail
                }
            } else {

                # Update the first line
                if {$LongStr} {
                    set NewPara $Line
                } else {
                    set NewPara $Lead$Line$Trail
                }

                # Take care of hanging indents afterwards
                incr MaxLen -$TabLen
                set MaxIdx [expr $MaxLen-1]
            }
            set ParaLen [string length $Para]
            incr Cnt2
        }
        if {$Cnt1} {

            # Insert a newline between each paragraph
            append NewText \n $NewPara
        } else {

            # Update the first paragraph
            set NewText $NewPara
        }
        incr Cnt1
    }
    return $NewText
}

# mfjProc::readIdx
    # Read and interpret the index combination containing special symbols:
    # '/' denotes index combination
    # ':' denotes all indices from index 1 to index 2
    # ',' separates index 1 and index 2
    # Example: 0/1,3:5 -> (0 1) (0 3) (0 4) (0 5)
# Arguments
    # IdxStr        A string of indices
    # IdxLen        The length of indices if any
# Result: Return the interpreted list of indices/combination
proc mfjProc::readIdx {IdxStr {IdxLen ""}} {

    # Validate arguments
    if {[regexp {^\d+$} $IdxLen]} {

        # Format the length to remove leading zeroes
        # and convert octal(0#) and hexadecimal(0x#) to decimal
        set IdxLen [format %d $IdxLen]
    } else {
        set IdxLen 0
    }

    # Verify, convert or expand if necessary
    set Ply 1
    set Idx1 ""
    set Idx2 ""
    set Lst [list]
    set IdxLst [list]
    set Len [string length $IdxStr]
    set Idx 0

    # Append "," to the indices string
    # Split the string to its constituent characters
    foreach Char [split $IdxStr, ""] {
        if {$Char eq "/" || $Char eq ":" || $Char eq ","} {
            if {[string is integer -strict $Idx1]} {

                # Align with python convention (-0 is the same as 0!)
                set Idx1 [format %d $Idx1]

                # A negative index is converted to positive if IdxLen present
                if {$IdxLen > 0} {
                    if {[string index $Idx1 0] eq "-"} {
                        incr Idx1 $IdxLen
                    }
                    if {$Idx1 < 0 || $Idx1 >= $IdxLen} {
                        error "'$IdxStr' index out of range '$IdxLen'!"
                    }
                }
                if {$Char eq ":"} {
                    if {$Idx2 eq ""} {
                        set Idx2 $Idx1
                    }
                } else {
                    if {[llength $Idx2]} {
                        set Stp [expr ($Idx1-$Idx2)/abs($Idx1-$Idx2)]

                        # Preserve the original form of Idx1 and Idx2
                        lappend Lst $Idx2
                        if {$Idx2 != $Idx1} {
                            set Tmp [expr $Idx1-$Stp]
                            while {$Idx2 != $Tmp} {
                                lappend Lst [incr Idx2 $Stp]
                            }
                            lappend Lst $Idx1
                        }
                        set Idx2 ""
                    } else {
                        lappend Lst $Idx1
                    }
                    if {$Char eq "/" || $Idx == $Len} {
                        lappend IdxLst $Lst
                        set Ply [expr $Ply*[llength $Lst]]
                        set Lst [list]
                    }
                }
            } else {
                set RegMat [lindex $::SimArr(RegMat) $::SimArr(RegLvl)]

                # Material name can be brief as the database is small
                # Only one match allowed. Otherwise multiple matches are shown
                set MLst [lsearch -all -regexp $RegMat (?i)^$Idx1]
                if {$MLst eq ""} {
                    error "material '$Idx1' in '$IdxStr' NOT found in\
                        variable 'RegGen'!"
                } elseif {[llength $MLst] > 1} {
                    set Tmp [list]
                    foreach Elm $MLst {
                        lappend Tmp [lindex $RegMat $Elm]
                    }
                    error "material '$Idx1' in '$IdxStr' matches materials\
                        '$Tmp'!"
                } else {
                    set Tmp [lindex $::SimArr(RegIdx) $::SimArr(RegLvl) $MLst]
                    set Lst [concat $Lst $Tmp]
                    if {$Char eq "/" || $Idx == $Len} {
                        lappend IdxLst $Lst
                        set Ply [expr $Ply*[llength $Lst]]
                        set Lst [list]
                    }
                }
            }
            set Idx1 ""
        } else {
            append Idx1 $Char
        }
        incr Idx
    }

    # Expand to a full list of indices combination (1 to n dimensions)
    set OutLen 1
    set TmpLst [list]
    foreach SubLst $IdxLst {
        set IdxLen [llength $SubLst]
        set InnLen [expr $Ply/$IdxLen/$OutLen]
        set Lst [list]
        for {set i 0} {$i < $OutLen} {incr i} {
            foreach Idx $SubLst {
                for {set j 0} {$j < $InnLen} {incr j} {
                    lappend Lst $Idx
                }
            }
        }
        set OutLen [expr {$IdxLen*$OutLen}]
        lappend TmpLst $Lst
    }

    # Rearrange the full list
    set IdxLst [list]
    set IdxLen [llength $TmpLst]
    for {set i 0} {$i < $Ply} {incr i} {
        set Lst [list]
        for {set j 0} {$j < $IdxLen} {incr j} {
            lappend Lst [lindex $TmpLst $j $i]
        }
        lappend IdxLst $Lst
    }
    return $IdxLst
}

# mfjProc::replace
    # Searching for the replacing features (i,j:k/i,j:k&l,m:n/l,m:n=).
    # If found, replace it with the subsequent elements and retain the rest.
    # Easy2Read form: {i,j:k/i,j:k&l,m:n/l,m:n= Val1 Val2 ...}
    # Compact form: i,j:k/i,j:k&l,m:n/l,m:n=Val1,Val2,...
# Arguments
    # VarName     Variable name
    # VarVal      Variable value
# Result: Return the number of occurances and the updated list
proc mfjProc::replace {VarName VarVal} {
    set VarMsg "variable '$VarName'"
    set Cnt 0
    set LvlIdx 1
    set NewLst [list [lindex $VarVal 0]]
    foreach OldVal [lrange $VarVal 1 end] {
        set LvlMsg "level '$LvlIdx'"
        set Msg "$LvlMsg of $VarMsg"

        # Check the string for the replacing pattern and treat a list in the
        # Easy2Read form as a string as well
        # Negative index is allowed by changing '\d+' to '-?\d+'
        if {[regexp {^((-?\d+[:,/&])*-?\d+)=(.+)$} $OldVal\
            -> IdxStr Tmp ValStr]} {

            # Get the index list
            set IdxLst [list]
            foreach Elm [split $IdxStr &] {
                set IdxLst [concat $IdxLst [readIdx $Elm]]
            }

            # Check the consistency of the reference level
            set Lst [list]
            set RefLvl -1
            foreach Elm $IdxLst {
                if {[string index $Elm 0] eq "-"} {
                    set Lvl [expr $LvlIdx+[lindex $Elm 0]]
                } else {
                    set Lvl [lindex $Elm 0]
                }

                # Replace '-1' with 'end' and '-#' with 'end[incr -#]'
                set Tmp [list]
                foreach Idx [lrange $Elm 1 end] {
                    if {$Idx == -1} {
                        lappend Tmp end
                    } elseif {$Idx < 0} {
                        lappend Tmp end[incr $Idx]
                    } else {
                        lappend Tmp $Idx
                    }
                }
                lappend Lst $Tmp
                set Elm [join $Elm /]
                if {$RefLvl == -1} {
                    if {$Lvl < 0 || $Lvl >= $LvlIdx} {
                        error "level reference '$Elm' out of range for $Msg!"
                    }
                    set RefLvl $Lvl
                } else {
                    if {$RefLvl != $Lvl} {
                        error "inconsistent level reference '$Elm' for $Msg!"
                    }
                }
            }
            set IdxLst $Lst
            set IdxLen [llength $IdxLst]

            # Convert a |-seperated string to a value list
            set ValLst [lrange [string map {| " "} $ValStr] 0 end]
            set ValLen [llength $ValLst]

            # Check whether 'ValLst' tallies with 'IdxLst'
            if {$ValLen < $IdxLen} {
                error "value '$ValLst' insufficient for $Msg!"
            } elseif {$ValLen > $IdxLen} {
                vputs -v2 "value '[lrange $ValLst $IdxLen end]' excess\
                    for $Msg!"
                set ValLst [lrange $ValLst 0 [incr IdxLen -1]]
            }
            set NewVal [lindex $NewLst $RefLvl]
            foreach Idx $IdxLst Val $ValLst {
                if {[catch {lset NewVal $Idx $Val}]} {
                    error "index '$Idx' invalid for $Msg!"
                }
            }
            lappend NewLst $NewVal
            incr Cnt
        } else {

            # This level has no replacing pattern
            lappend NewLst $OldVal
        }
        incr LvlIdx
    }
    return [list $Cnt $NewLst]
}

# mfjProc::reuse
    # Recursively searching for the reuse features (@i,j:k/i,j:k&l,m:n/l,m:n).
    # If found, reuse the previous elements.
# Arguments
    # VarName     Variable name
    # VarVal      Variable value
    # SubLst      Sublist value
    # Lvl         Optional, level sequence (default: -1)
    # OldIdx      Optional, trace the index of the SubLst (default: "")
    # InLvl       Optional, restrict reference within a level (default: true)
# Result: Return the updated list.
proc mfjProc::reuse {VarName VarVal SubLst {Lvl ""} {OldIdx ""} {InLvl ""}} {

    # Validate arguments
    # All levels should not be negative integers
    if {[regexp {^\d+$} $Lvl]} {

        # Format the level to remove leading zeroes
        # and convert octal(0#) and hexadecimal(0x#) to decimal
        set Lvl [format %d $Lvl]
    } else {
        set Lvl -1
    }

    # All indices should be either positive integer or zero
    foreach Elm $OldIdx {
        if {![regexp {^\d+$} $Elm]} {
            set OldIdx ""
            break
        }
    }

    if {[string index $InLvl 0] eq "!"} {
        set InLvl false
    } else {
        set InLvl true
    }

    set VarMsg "variable '$VarName'"
    set NewLst [list]
    set LstIdx 0
    foreach Elm $SubLst {
        set NewIdx [concat $OldIdx $LstIdx]
        if {$Lvl != -1} {
            set Msg "'$Elm' of level '$Lvl' (index $NewIdx) of $VarMsg"
        } else {
            set Msg "'$Elm' of $VarMsg (index $NewIdx)"
        }

        # Replace each reuse feature and evaluate the final expression
        # Negative index is allowed with the pattern '-?\d+'
        while {[regexp {@((-?\d+[:,/&])*-?\d+)} $Elm -> IdxStr]} {
            if {[llength $Elm] > 1  || [regexp {^\{.+\}$} $Elm]} {

                # Visit all the elements by regression
                # The function name is adaptive: '[lindex [info level 0] 0]'
                set Elm [[lindex [info level 0] 0] $VarName $VarVal\
                    $Elm $Lvl $NewIdx]
            } else {
                set NewElm [list]
                set StrLst [split $IdxStr &]
                foreach Str $StrLst {
                    set IdxLst [readIdx $Str]
                    foreach Lst $IdxLst {
                        set Val $VarVal

                        # Start from the outmost level
                        set Ref $NewIdx
                        set End [lindex $Ref 0]

                        # #: forwards from the first index
                        # -#: backwards from the current index
                        foreach Idx $Lst {
                            if {[string index $Idx 0] eq "-"} {
                                set Idx1 [string range $Idx 1 end]
                                set Idx2 [expr $End+$Idx]
                            } else {
                                set Idx1 $Idx
                                set Idx2 $Idx
                            }
                            if {$Idx1 > $End} {
                                error "index '$Idx' out of range\
                                    '$End' for element $Msg!"
                            }

                            # Update value to the element
                            set Val [lindex $Val $Idx2]
                            if {$Ref ne "" && $Idx2 == $End} {

                                # Next inner level of the current index
                                set Ref [lrange $Ref 1 end]
                                set End [lindex $Ref 0]
                            } else {

                                # Not the current index anymore
                                # so discard 'Ref' and 'End' is list length
                                set Ref ""
                                set End [llength $Val]
                            }
                        }

                        # Detect and raise a circular reference error
                        set MatLst [regexp -inline -all {@(-?\d+[:,/&])*-?\d+}\
                            $Val]
                        foreach RefStr $MatLst {
                            if {[string index $RefStr 0] ne "@"} continue
                            foreach RefLst [split $RefStr &] {
                                foreach RefIdx [readIdx [string range $RefLst\
                                    1 end]] {
                                    if {$RefIdx eq $Lst} {
                                        error "circular reference: '@$IdxStr'\
                                            -> '$Val'"
                                    }
                                }
                            }
                        }
                        if {[llength $StrLst]*[llength $IdxLst] == 1} {
                            set NewElm [concat $NewElm $Val]
                        } else {
                            lappend NewElm $Val
                        }
                    }
                }

                # Eval is required if reuse is not coming alone
                if {[regexp {^@(-?\d+[:,/&])*-?\d+$} $Elm]} {
                    set Eval false
                } else {
                    set Eval true
                }

                # Substitute the first reuse in the element
                regsub {@(-?\d+[:,/&])*-?\d+} $Elm $NewElm Elm

                # Evaluate the experession if no reuse feature
                # Operators + - * / and Tcl math functions are supported
                if {$Eval && ![regexp {@(-?\d+[:,/&])*-?\d+} $Elm]
                    && [catch {set Elm [format %g [expr $Elm]]}]} {
                    error "unable to eval '$Elm' in $Msg!"
                }

                # Need to break loop after activating reuse-only feature
                # in level 1+
                if {!$InLvl && !$Eval && $Lvl} break
            }
        }

        # Need to assign value after activating reuse-only feature
        # in level 1+
        if {!$InLvl && !$Eval && $Lvl} {
            set NewLst $Elm
        } else {
            lappend NewLst $Elm
        }
        incr LstIdx
    }
    return $NewLst
}

# mfjProc::iFileExists (The first argument: Pass by reference)
    # Case insensitive version of file exists (No nesting)
# Arguments
    # VarName     Variable name
    # args        Optional, element indices
# Result: Return 1 as success or run into an error
proc mfjProc::iFileExists {VarName args} {
    upvar 1 $VarName VarVal

    # Validate element indices
    if {[llength $args]} {
        set IdxLst [list]

        # Flatten a list with any nested level
        set Tmp [lrange [string map {\{ "" \} ""} $args] 0 end]
        foreach Elm $Tmp {
            if {[string is integer -strict $Elm]} {

                # Negative index is allowed
                # Format the index to remove leading zeroes
                # and convert octal(0#) and hexadecimal(0x#) to decimal
                # Replace '-1' with 'end' and '-#' with 'end[incr -#]'
                if {$Elm == -1} {
                    set Elm end
                } elseif {$Elm < 0} {
                    set Elm end[incr Elm]
                } else {
                    set Elm [format %d $Elm]
                }
            } else {
                error "index '$Tmp' for variable '$VarName'\
                    should be an integer!"
            }
            lappend IdxLst $Elm
        }
        set ElmVal [lindex $VarVal $IdxLst]

        # Verify the list index by setting the value back
        if {[catch {lset VarVal $IdxLst $ElmVal}]} {
            error "index '$IdxLst' out of range for variable '$VarName'!"
        }
        set Msg "element '$ElmVal' of variable '$VarName' (index $IdxLst)\
            should be an existing file!"
    } else {
        set IdxLst [list]
        set ElmVal $VarVal
        set Msg "value '$ElmVal' of variable '$VarName'\
            should be an existing file!"
    }

    if {[llength $ElmVal]} {

        # Remove . and .. from the path
        set DirLst [file split $ElmVal]
        if {[lindex $DirLst 0] eq ".."} {
            set Path [file dirname [pwd]]
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
        set ElmVal $Path

        # Analyse the path
        if {![file exists $ElmVal]} {
            set DirLst [file split [file dirname $ElmVal]]
            if {[file pathtype $ElmVal] eq "absolute"} {
                set Path [lindex $DirLst 0]
                set DirLst [lrange $DirLst 1 end]
            } else {
                set Path ""
            }
            foreach Elm $DirLst {
                set Str [lsearch -inline -regexp [glob -nocomplain -tails\
                    -directory $Path -type d *] (?i)^$Elm$]
                if {$Str eq ""} {
                    error $Msg
                }
                set Path [file join $Path $Str]
            }

            # if parent directories match, check file tail match
            set Str [lsearch -inline -regexp [glob -nocomplain -tails\
                -directory $Path *] (?i)^[file tail $ElmVal]$]
            if {$Str eq ""} {
                error $Msg
            }
            set Path [file join $Path $Str]
        }
        if {[llength $IdxLst]} {
            lset VarVal $IdxLst $Path
        } else {
            set VarVal $Path
        }
        return 1
    } else {
        error $Msg
    }
}

# mfjProc::getRegIdx
#     Find the region index where an interface profile belongs
# Arguments:
#     RegDim        Region settings
#     Intf          px1_y1_z1/x2_y2_z2
# Result: Return the region index or raise an error
proc mfjProc::getRegIdx {RegDim Intf} {
    set Dim [llength [lindex $RegDim 0 1]]
    set Lst [split [split [string range $Intf 1 end] _] /]
    if {$Dim == 1} {
        if {[lindex $Lst 1] == 1} {
            set Pos [expr [lindex $Lst 0]+0.0001]
        } else {
            set Pos [expr [lindex $Lst 0]-0.0001]
        }
        foreach Elm $RegDim {
            if {$Pos > [lindex $Elm 1] && $Pos < [lindex $Elm 2]} {
                return [lindex $Elm 0 end]
            }
        }
    } elseif {$Dim == 2} {
        if {[lindex $Lst 0 0] > [lindex $Lst 1 0]} {
            set Pos [list\
                [expr 0.5*([lindex $Lst 0 0]+[lindex $Lst 1 0])+0.0001]\
                [expr 0.5*([lindex $Lst 0 1]+[lindex $Lst 1 1])+0.0001]]
        } else {
            set Pos [list\
                [expr 0.5*([lindex $Lst 0 0]+[lindex $Lst 1 0])-0.0001]\
                [expr 0.5*([lindex $Lst 0 1]+[lindex $Lst 1 1])-0.0001]]
        }
        foreach Elm $RegDim {
            if {[lindex $Pos 0] > [lindex $Elm 1 0]
                && [lindex $Pos 0] < [lindex $Elm 2 0]
                && [lindex $Pos 1] > [lindex $Elm 1 1]
                && [lindex $Pos 1] < [lindex $Elm 2 1]} {
                return [lindex $Elm 0 end]
            }
        }
    } else {
        if {[lindex $Lst 0 0] < [lindex $Lst 1 0]} {
            set Pos [list\
                [expr 0.5*([lindex $Lst 0 0]+[lindex $Lst 1 0])+0.0001]\
                [expr 0.5*([lindex $Lst 0 1]+[lindex $Lst 1 1])+0.0001]\
                [expr 0.5*([lindex $Lst 0 2]+[lindex $Lst 1 2])+0.0001]]
        } else {
            set Pos [list\
                [expr 0.5*([lindex $Lst 0 0]+[lindex $Lst 1 0])-0.0001]\
                [expr 0.5*([lindex $Lst 0 1]+[lindex $Lst 1 1])-0.0001]\
                [expr 0.5*([lindex $Lst 0 2]+[lindex $Lst 1 2])-0.0001]]
        }
        foreach Elm $RegDim {
            if {[lindex $Pos 0] > [lindex $Elm 1 0]
                && [lindex $Pos 0] < [lindex $Elm 2 0]
                && [lindex $Pos 1] > [lindex $Elm 1 1]
                && [lindex $Pos 1] < [lindex $Elm 2 1]
                && [lindex $Pos 2] > [lindex $Elm 1 2]
                && [lindex $Pos 2] < [lindex $Elm 2 2]} {
                return [lindex $Elm 0 end]
            }
        }
    }
    error "unknown region index for '$Intf'!"
}

# mfjProc::readTT
#     Read a file to extract ID line, depth field density pair, trap settings,
#     depth trap density pair, nonlocal mesh settings. Only one ID line and
#     depth-field pairs are allowed!
# Arguments:
#     TTArr       Trap/tunnel array
#     TTFile      Trap/tunnel setting file
#     TTRatio     Optional field density ratio
# Result: Return ID, field depth, optional trap settings and trap profile file
proc mfjProc::readTT {TTArr TTFile {TTRatio 1}} {
    if {![file isfile $TTFile]} {
        error "'$TTFile' should be a file!"
    }

    # Map the local array 'Arr' to the global array 'TTArr'
    upvar 1 $TTArr Arr
    set OptLst {TrapNat TrapRef EnergyMid Xsection TrapDist Reference Conc
        EnergySig Jfactor PhononEnergy TrapVolume Discretization Digits
        EnergyResolution MaxAngle Transparent Permeable Endpoint Refined
        TwoBand Multivalley PModel Region}
    set ReadTbl false
    set Inf [open $TTFile r]

    # 'gets' is safer than 'read' in case the file is too big
    while {[gets $Inf Line] != -1} {
        set Line [string trim $Line]

        # Skip comments and blank lines
        if {$Line eq "" || [string index $Line 0] eq "#"} {
            continue
        }
        if {[regexp -nocase {^<Table>(.+)} $Line -> Line]} {
            if {$ReadTbl} {
                lappend Arr(Table) $Tbl
            } else {
                set ReadTbl true
            }
            if {[llength $Line] == 2
                && [string is double -strict [lindex $Line 0]]
                && [string is double -strict [lindex $Line 1]]
                && [lindex $Line 1] > 0} {
                set Tbl [lrange $Line 0 1]
            } else {
                set Tbl ""
            }
            continue
        }

        # Only the ID line has one element
        if {[llength $Line] == 1} {
            if {[regexp {^"(\w+)"$} $Line -> Str]} {
                if {[info exists Arr(ID)]} {
                    error "> 1 ID lines detected in '$TTFile'!"
                }
                set Arr(ID) $Str
                set Arr(FFld) [file rootname $TTFile]-[expr rand()].plx
                set Ouf [open $Arr(FFld) w]
                puts $Ouf \"$Arr(ID)\"
            } else {
                error "'$Line': invalid ID!"
            }
        } else {

            # Trap energetic distribution or spatial distribution
            if {[llength $Line] == 2
                && [string is double -strict [lindex $Line 0]]
                && [string is double -strict [lindex $Line 1]]} {
                if {$ReadTbl} {
                    if {[lindex $Line 1] > 0} {
                        lappend Tbl [lindex $Line 0]
                        lappend Tbl [format %.4e [lindex $Line 1]]
                    } else {
                        error "'$Line': invalid trap density!"
                    }
                } else {
                    if {[lindex $Line 0] >= 0 && [lindex $Line 1] >= 0} {
                        set Val [format %.4e [expr 1.*$TTRatio\
                            *[lindex $Line 1]]]
                        lappend Arr(Field) "[lindex $Line 0] $Val"
                        if {[info exists Ouf]} {
                            puts $Ouf "[lindex $Line 0] $Val"
                        }
                    } else {
                        error "'$Line': invalid depth-field profile!"
                    }
                }
                continue
            }
            set Idx [lsearch -regexp $OptLst (?i)^[lindex $Line 0]$]
            if {$Idx == -1} {
                error "'[lindex $Line 0]': unknown option!"
            } else {
                set Key [lindex $OptLst $Idx]
                if {$ReadTbl} {
                    lappend Arr(Table) $Tbl
                    set ReadTbl false
                }
            }

            # Check each option and validate its values
            switch -regexp -- $Key {
                ^(TrapNat|TrapRef|TrapDist|Reference|PModel)$ {
                    if {$Key eq "TrapNat"} {
                        set Lst {A<cceptor> D<onor>}
                    } elseif {$Key eq "TrapRef"} {
                        set Lst {FromCondBand FromMidBandGap FromValBand}
                    } elseif {$Key eq "TrapDist"} {
                        set Lst {L<evel> U<niform> E<xponential> G<aussian>
                            T<able>}
                    } elseif {$Key eq "Reference"} {
                        set Lst {B<andGap> E<ffectiveBandGap>}
                    } elseif {$Key eq "PModel"} {
                        set Lst {W<KB> S<chroedinger>}
                    }
                    lappend Arr($Key) [iSwitch !Dflt [lindex $Line 1] $Lst]
                }
                ^(Conc|EnergySig|TrapVolume)$ {
                    if {[string is double -strict [lindex $Line 1]]
                        && [lindex $Line 1] > 0} {
                        lappend Arr($Key) [format %.12g [lindex $Line 1]]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^EnergyMid$ {
                    if {[string is double -strict [lindex $Line 1]]} {
                        lappend Arr($Key) [format %.12g [lindex $Line 1]]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^Xsection$ {
                    if {[string is double -strict [lindex $Line 1]]
                        && [string is double -strict [lindex $Line 2]]
                        && [lindex $Line 1] > 0 && [lindex $Line 2] > 0} {
                        lappend Arr(e$Key) [format %.12g [lindex $Line 1]]
                        lappend Arr(h$Key) [format %.12g [lindex $Line 2]]
                    } elseif {[string is double -strict [lindex $Line 1]]
                        && [lindex $Line 1] > 0} {
                        lappend Arr(e$Key) [format %.12g [lindex $Line 1]]
                        lappend Arr(h$Key) [lindex $Arr(e$Key) end]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^Jfactor$ {
                    if {[string is double -strict [lindex $Line 1]]
                        && [string is double -strict [lindex $Line 2]]
                        && [lindex $Line 1] >= 0 && [lindex $Line 1] <= 1
                        && [lindex $Line 2] >= 0 && [lindex $Line 2] <= 1} {
                        lappend Arr(e$Key) [format %.12g [lindex $Line 1]]
                        lappend Arr(h$Key) [format %.12g [lindex $Line 2]]
                    } elseif {[string is double -strict [lindex $Line 1]]
                        && [lindex $Line 1] >= 0 && [lindex $Line 1] <= 1} {
                        lappend Arr(e$Key) [format %.12g [lindex $Line 1]]
                        lappend Arr(h$Key) [lindex $Arr(e$Key) end]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^PhononEnergy$ {
                    if {[string is double -strict [lindex $Line 1]]
                        && [lindex $Line 1] >= 0} {
                        lappend Arr($Key) [format %.12g [lindex $Line 1]]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^Region$ {
                    if {[lindex $Line 1] == 1 || [lindex $Line 1] == 2} {
                        lappend Arr($Key) [format %.12g [lindex $Line 1]]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^(Discretization|EnergyResolution)$ {
                    if {[string is double -strict [lindex $Line 1]]
                        && [lindex $Line 1] > 0} {
                        set Arr($Key) [format %.12g [lindex $Line 1]]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^MaxAngle$ {
                    if {[string is double -strict [lindex $Line 1]]
                        && [lindex $Line 1] >= 0
                        && [lindex $Line 1] <= 180} {
                        set Arr($Key) [format %.12g [lindex $Line 1]]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^Digits$ {
                    if {[string is integer -strict [lindex $Line 1]]
                        && [lindex $Line 1] > 0} {
                        set Arr($Key) [format %.12g [lindex $Line 1]]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^(Transparent|Permeable|Endpoint|Refined)$ {
                    if {[regexp {^[+-]$} [lindex $Line 1]]
                        && [regexp {^[+-]$} [lindex $Line 2]]} {
                        set Arr($Key) [lrange $Line 1 2]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                ^(TwoBand|Multivalley)$ {
                    if {[regexp {^[+-]$} [lindex $Line 1]]} {
                        set Arr($Key) [lindex $Line 1]
                    } else {
                        error "'$Line': unknown [string tolower $Key]!"
                    }
                }
                default {
                    error "double check '$Line'!"
                }
            }
        }
    }
    if {$ReadTbl} {
        lappend Arr(Table) $Tbl
    }
    close $Inf
    if {[info exists Ouf]} {
        close $Ouf
    }

    # Check trap related keys
    if {[info exists Arr(TrapNat)]} {
        set Len [llength $Arr(TrapNat)]

        # Ensure a minimum set of keys for traps
        foreach Elm {TrapRef EnergyMid eXsection} {
            if {![info exists Arr($Elm)]} {
                error "no '$Elm' found in '$TTFile'!"
            }
        }

        # Default trap distribution 'level'
        if {[info exists Arr(TrapDist)]} {
            if {[lindex $Arr(TrapDist) 0] eq "Table"} {
                if {![info exists Arr(Table)]} {
                    error "no '<Table>' found in '$TTFile'!"
                }
            } else {
                if {![info exists Arr(Field)] && ![info exists Arr(Conc)]} {
                    error "no 'Conc' found in '$TTFile'!"
                }
                if {[lindex $Arr(TrapDist) 0] ne "Level"
                    && ![info exists Arr(EnergySig)]} {
                    error "no 'EnergySig' found in '$TTFile'!"
                }
            }
        } else {
            set Arr(TrapDist) [string repeat "Level " [expr $Len-1]]Level
        }

        # Trap-assisted tunneling
        if {[info exists Arr(TrapVolume)]} {
            if {![info exists Arr(PhononEnergy)]} {
                error "no 'PhononEnergy' found in '$TTFile'!"
            }
        }

        # The length of trap related options should tally with each other
        foreach Elm {TrapDist TrapRef Conc EnergyMid EnergySig eXsection
            hXsection Table eJfactor hJfactor Reference PhononEnergy
            TrapVolume Region} {
            if {[info exists Arr($Elm)] && [llength $Arr($Elm)] != $Len} {
                error "length of $Elm '$Arr($Elm)' != $Len!"
            }
        }
    }
}

# mfjProc::lPolation
    # Perform linear/logarithm interpolation/extrapolation
# Arguments:
    # XList       A list of two different X values {X1 X2}
    # YList       A list of two Y values {Y1 Y2}
    # X           Known X value
    # LinX        Optional, linear (default) or logarithmic
    # LinY        Optional, linear (default) or logarithmic
# Result: Return the interpolation/extrapolation result
proc mfjProc::lPolation {XList YList X {LinX ""} {LinY ""}} {

    # Validate arguments
    if {[llength $XList] != 2 || [llength $YList] != 2} {
        error "'$XList' and '$YList' both need two numbers!"
    }
    foreach Elm [concat $XList $YList $X] {
        if {![string is double -strict $Elm]} {
            error "interpolation/extrapolation only applies to numbers!"
        }
    }
    foreach Elm [list LinX LinY] {

        # Make an alias of 'LinX' and 'LinY'
        upvar 0 $Elm Alias
        if {[string index $Alias 0] eq "!"} {
            set Alias false
        } else {
            set Alias true
        }
    }

    set X1 [lindex $XList 0]
    set X2 [lindex $XList 1]
    set Y1 [lindex $YList 0]
    set Y2 [lindex $YList 1]
    if {$X1 == $X2} {
        error "'$X1' and '$X2' should be different!"
    }
    if {!$LinX} {
        if {$X <= 0} {
            error "X expecting a positive value, but got '$X' for\
                logarithmic interpolation/extrapolation!"
        }
        foreach Val $XList {
            if {$Val <= 0} {
                error "element of XList expecting a positive value, but\
                    got '$Val' for logarithmic interpolation/extrapolation!"
            }
        }
    }
    if {!$LinY} {
        foreach Val $YList {
            if {$Val <= 0} {
                error "element of YList expecting a positive value, but\
                    got '$Val' for logarithmic interpolation/extrapolation!"
            }
        }
    }
    if {$LinX} {
        if {$LinY} {
            return [expr {$Y1+1.*($Y2-$Y1)*($X-$X1)/($X2-$X1)}]
        } else {
            return [expr {exp(log($Y1)+(log($Y2)-log($Y1))\
                *($X-$X1)/($X2-$X1))}]
        }
    } else {
        if {$LinY} {
            return [expr {$Y1+1.*($Y2-$Y1)*(log($X)-log($X1))\
                /(log($X2)-log($X1))}]
        } else {
            return [expr {exp(log($Y1)+(log($Y2)-log($Y1))\
                *(log($X)-log($X1))/(log($X2)-log($X1)))}]
        }
    }
}

# mfjProc::str2List
    # Properly convert a string to a list especially a nested one using the
    # recursive mechanism. It trims excess spaces due to multiple lines and
    # user input.
# Arguments:
    # VarInfo     Variable info
    # StrList     Original string list entered by a user
    # Level       Optional, default list level starts from 0
# Result: Return the formatted list
proc mfjProc::str2List {VarInfo StrList {Level 0}} {

    # Validate arguments
    # A level should not be a negative integer
    if {![regexp {^\d+$} $Level]} {
        error "invalid level '$Level'!"
    }

    if {$Level == 0 && [string length $VarInfo]} {
        vputs -v3 $VarInfo
    }
    set FmtLst [list]
    foreach SubLst $StrList {
        set SubLen [llength $SubLst]
        if {$SubLen == 0} {

            # In Tcl, a string of spaces are treated as an empty list
            lappend FmtLst [list]
        } elseif {$SubLen > 1 || [regexp {^\{.*\}$} $SubLst]} {

            # To correctly identify a list: 1. there are multiple elements;
            # 2. there is only one single element, yet this element is not
            # a string or number, but a nested list instead e.g. {{{}}} or
            # {{{1 2 3 ...}}}
            # The function name is adaptive using '[lindex [info level 0] 0]'
            lappend FmtLst [[lindex [info level 0] 0] $VarInfo\
                $SubLst [expr {$Level+1}]]
        } else {

            # A string or a number
            lappend FmtLst $SubLst
        }
    }
    if {$Level && [string length $VarInfo]} {
        vputs -v3 -i1 "Level $Level: \{$FmtLst\}"
    } else {

        # Level 0
        if {[string length $VarInfo]} {
            vputs -v3 -i1 "Level $Level: \{$FmtLst\}\n"
        }
    }
    return $FmtLst
}

# mfjProc::iSwitch
    # Case-insensitive switch with the return of the matched string. If any
    # pattern string contains angle brackets, only the leading characters are
    # used for match against the evaluation string.
# Arguments:
    # Dflt        If the value is "Dflt", the last argument will be the default
                # match in case no match can be found; Otherwise, an error will
                # be raised
    # Str         The string to be evaluated
    # Ptn         The pattern string
    # args        The rest pattern strings
# Result: Return the matched pattern string
proc mfjProc::iSwitch {Dflt Str Ptn args} {

    # Validate arguments
    if {[string index $Dflt 0] eq "!"} {
        set Dflt false
    } else {
        set Dflt true
    }
    set Lst [string map {\{ "" \} ""} [concat $Ptn $args]]
    if {![llength $Lst]} {
        error "no pattern specified for function 'iSwitch'!"
    }

    # Validate 'Str'
    if {$Str eq "" && !$Dflt} {
        error "'' for mandatory selection from '$Lst'!"
    }
    set Ptn [list]
    set KeyPtn [list]
    set OptPtn [list]
    foreach Elm $Lst {

        # \w characters: [a-zA-Z0-9_]
        if {[regexp {^(!\w*|\w+)(<\S+>)?$} $Elm -> Ptn1 Ptn2]} {
            lappend KeyPtn $Ptn1
            if {$Ptn2 eq ""} {
                lappend OptPtn [list]
                lappend Ptn $Ptn1
            } else {
                lappend OptPtn $Ptn1[string range $Ptn2 1 end-1]
                lappend Ptn [lindex $OptPtn end]
            }
        } else {
            error "illegal characters in '$Elm' in patterns\
                '[lrange $Lst 0 end]'!"
        }
    }

    set LstIdx -1
    set LstEnd [llength $KeyPtn]
    incr LstEnd -1
    foreach Key $KeyPtn Opt $OptPtn {
        if {[incr LstIdx] <= $LstEnd} {
            if {$Opt eq ""} {
                if {[string equal -nocase $Key $Str]} {
                    return $Key
                }
            } else {
                if {[regexp -nocase ^$Str $Opt]} {
                    return $Opt
                }
            }
        }
        if {$LstIdx == $LstEnd} {
            if {$Opt eq ""} {
                if {!$Dflt} {
                    error "no match found for '$Str' in '$Ptn'!"
                }
                return $Key
            } else {
                if {!$Dflt} {
                    error "no match found for '$Str' in '$Ptn'!"
                }
                return $Opt
            }
        }
    }
}

# mfjProc::groupValues
    # Some variables contain values for multiple materials, regions,
    # interfaces, points, etc. It is necessary to split the values into
    # multiple sublists based on the predefined group ID
# Arguments:
    # VarName     Variable name
    # VarVal      Variable value
    # GrpID       Combinations of 'm', 'p', 'pp', 'r', 'rr'
                  # 'b', 'd', 'o', 'q', 'v'
    # LvlIdx      The current level index
    # LvlLen      The total levels
# Results: Return the grouped list
proc mfjProc::groupValues {VarName VarVal GrpID LvlIdx LvlLen} {

    # Validate arguments
    set GStr [join $GrpID ""]
    set Txt ""
    if {[regexp {b} $GStr]} {
        if {[string length $Txt]} {
            append Txt\
                " or c# or 'MonoScaling' or 'SpecScaling' or 'Wavelength'"
        } else {
            set Txt "c# or 'MonoScaling' or 'SpecScaling' or 'Wavelength'"
        }
        set BIDLst $::SimArr(BIDLst)        ;# Supported 'b' group ID list
    }
    if {[regexp {d} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or 'Mesh' or 'Numeric' or 'Other'"
        } else {
            set Txt "'Mesh' or 'Numeric' or 'Other'"
        }
        set DIDLst $::SimArr(DIDLst)        ;# Supported 'd' group ID list
    }
    if {[regexp {o} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or 'Spectrum' or 'Monochromatic' or 'Incidence'"
        } else {
            set Txt "'Spectrum' or 'Monochromatic' or 'Incidence'"
        }
        set OIDLst $::SimArr(OIDLst)        ;# Supported 'o' group ID list
    }
    if {[regexp {q} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or 'Calibrate' or 'Diffuse' or 'Etch' or 'Implant'"
        } else {
            set Txt "'Calibrate' or 'Diffuse' or 'Etch' or 'Implant'"
        }
        set QIDLst $::SimArr(QIDLst)        ;# Supported 'q' group ID list
    }
    if {[regexp {v} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or ref to a varying variable"
        } else {
            set Txt "a ref to a varying variable"
        }
        set VarLen $::SimArr(VarLen)
    }
    if {[regexp {m} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or material"
        } else {
            set Txt "a material"
        }

        # Check the presence of material database
        if {$::SimArr(MatDB) eq ""} {
            error "material database is empty!"
        }
        set MatLst [lindex $::SimArr(MatDB) 0]
        set GrpLst [lindex $::SimArr(MatDB) 1]
    }
    if {[regexp {ppp} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or point or box"
        } else {
            set Txt "a point or box"
        }
    } elseif {[regexp {pp} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or box"
        } else {
            set Txt "a box"
        }
    } elseif {[regexp {p} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or point"
        } else {
            set Txt "a point"
        }
    }
    if {[regexp {rrr} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or region or interface"
        } else {
            set Txt "a region or interface"
        }
    } elseif {[regexp {rr} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or interface"
        } else {
            set Txt "an interface"
        }
    } elseif {[regexp {r} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or region"
        } else {
            set Txt "a region"
        }
    }

    # Extract boundaries of simulation domain for GID 'p', 'r'
    # Get values from global array 'SimArr'.
    # Skip to-be-removed and to-be-merged regions from 'RegInfo'
    if {[regexp {[pr]} $GStr]} {
        set RegInfo [list]
        foreach Reg [lindex $::SimArr(RegInfo) $::SimArr(RegLvl)] {
            if {[string index [lindex $Reg 0 1] 0] ne "M"
                && [lindex $Reg 0 end] >= 0} {
                lappend RegInfo $Reg
            }
        }
        # set RegMat [lindex $::SimArr(RegMat) $::SimArr(RegLvl)]
        # set RegIdx [lindex $::SimArr(RegIdx) $::SimArr(RegLvl)]
        set DimLen $::SimArr(DimLen)
        set RegLen [llength $RegInfo]

        # Extract the boundaries of the simulation domain (including
        # dummy gaseous layers)
        set XMin [lindex $RegInfo 0 1 0]
        set XMax [lindex $RegInfo end 2 0]
        set YMin 0
        set YMax 0
        set ZMin 0
        set ZMax 0
        if {[llength [lindex $RegInfo end 1]] > 1} {
            set YMax [lindex $RegInfo end 2 1]
        }
        if {[llength [lindex $RegInfo end 1]] == 2} {
            if {[lindex $RegInfo end-1 1 0] < 0} {
                set YMin [lindex $RegInfo end-1 1 1]
            } else {
                set YMin 0
            }
        }
        if {[llength [lindex $RegInfo end 1]] == 3} {
            set YMin [lindex $RegInfo end 1 1]
            set ZMin [lindex $RegInfo end-1 1 2]
            set ZMax [lindex $RegInfo end 2 2]
        }
    }

    # Set regular exppression strings for a material or regions
    # Use {} here to preserve a string as it is
    set RE_m {[\w.]+}
    set RE_r {(-?\d+[:,])*-?\d+}
    set RE_v {(-?\d+[:,])*-?\d+}

    # RE for integers and real numbers (including scientific notation)
    set RE_n {[+-]?(\.\d+|\d+(\.\d*)?)([eE][+-]?\d+)?}

    # Regular expression for a position
    set RE_p (${RE_n}_){0,2}$RE_n
    set pp1D $RE_n/\[+-\]

    set VarMsg "variable '$VarName'"
    set NewLst [list]
    set SubLst [list]
    set ValIdx 0
    set ValEnd [llength $VarVal]
    incr ValEnd -1
    set RegSeq 0

    # 0: Not a group ID; 1: one group ID; >1: Multiple group ID like r0,1:5
    set GIDLen 0

    # An empty list is automatically skipped here
    foreach Val $VarVal {
        foreach GID $GrpID {

            # Check whether an element is a group ID.
            # For 'b', 'd', 'o', 'q': update case
            # For 'm': attach more info
            # For 'p', 'r' and 'v': update numbers
            if {$GID eq "b"} {

                # Special treatment for the first two elements in 'BIDLst'
                set Bool false
                set Idx 0
                foreach Elm $BIDLst {

                    # Skip mismatch BID elements
                    if {![expr "\[regexp -nocase \{^$Elm$\} $Val\]"]} {
                        incr Idx
                        continue
                    }
                    if {$Idx == 0} {

                        # Check against single-level 'IntfAttr'
                        if {[llength $::SimArr(ConLen)] == 1} {
                            if {[regexp -nocase $Val $::SimArr(ConLst)]} {
                                set Bool true
                            }
                        } else {

                            # Check against multiple-level 'IntfAttr'
                            if {[llength $::SimArr(ConLen)] == $LvlLen
                                && $::SimArr(ColMode)} {
                                if {[regexp -nocase $Val\
                                    [lindex $::SimArr(ConLst) $LvlIdx]]} {
                                    set Bool true
                                }
                            } else {
                                set Bool 1
                                foreach Lst $::SimArr(ConLst) {
                                    set Bool [expr $Bool*[regexp -nocase $Val\
                                        $Lst]]
                                }
                            }
                        }
                        set Val [string tolower $Val]
                        if {!$Bool} {
                            error "Contact '$Val' not found in 'IntfAttr'!"
                        }
                    } elseif {$Idx == 1} {
                        set Bool true
                    } else {
                        switch -- [string index $Elm 0] {
                            M {
                                set Val MonoScaling
                            }
                            S {
                                set Val SpecScaling
                            }
                            W {
                                set Val Wavelength
                            }
                            default {
                                error "unknown group ID '$Elm'!"
                            }
                        }
                        set Bool true
                    }

                    # Stop the rest BIDs if found
                    if {$Bool} {
                        break
                    }
                    incr Idx
                }
            } elseif {$GID eq "d"} {
                set Bool false
                foreach Elm $DIDLst {
                    if {[expr "\[regexp -nocase \{^$Elm$\} $Val\]"]} {
                        switch -- [string index $Elm 0] {
                            M {
                                set Val Mesh
                            }
                            N {
                                set Val Numeric
                            }
                            O {
                                set Val Other
                            }
                            default {
                                error "unknown group ID '$Elm'!"
                            }
                        }
                        set Bool true
                        break
                    }
                }
            } elseif {$GID eq "o"} {
                set Bool false
                foreach Elm $OIDLst {
                    if {[expr "\[regexp -nocase \{^$Elm$\} $Val\]"]} {
                        switch -- [string index $Elm 0] {
                            I {
                                set Val Incidence
                            }
                            M {
                                set Val Monochromatic
                            }
                            S {
                                set Val Spectrum
                            }
                            default {
                                error "unknown group ID '$Elm'!"
                            }
                        }
                        set Bool true
                        break
                    }
                }
            } elseif {$GID eq "q"} {
                set Bool false
                foreach Elm $QIDLst {
                    if {[expr "\[regexp -nocase \{^$Elm$\} $Val\]"]} {
                        switch -- [string range $Elm 0 2] {
                            Cal {
                                set Val calibrate
                            }
                            Dep {
                                set Val deposit
                            }
                            Dif {
                                set Val diffuse
                            }
                            Etc {
                                set Val etch
                            }
                            Imp {
                                set Val implant
                            }
                            Ini {
                                set Val init
                            }
                            Mas {
                                set Val mask
                            }
                            Sel {
                                set Val select
                            }
                            Tra {
                                set Val transform
                            }
                            Wri {
                                set Val write
                            }
                            default {
                                error "unknown group ID '$Val'!"
                            }
                        }
                        set Bool true
                        break
                    }
                }
            } elseif {$GID eq "m"} {

                # Group ID 'm' is used in variable 'RegDim' only for groupValues
                if {[regexp -nocase ^($RE_n|p$RE_p|p$RE_p/$RE_p)$ $Val]} {
                    set Bool false
                } else {
                    if {[catch {iSwitch !Dflt $Val E<llipse> V<ertex>\
                        P<yramid> C<one> B<lock> K<eep> M<erge> R<emove>}]} {

                        # Material name needs exact match to avoid multiple
                        # matches for a large database
                        set Idx [lsearch -regexp $MatLst (?i)^$Val$]
                        if {$GStr eq "m"} {
                            if {$Idx == -1} {
                                error "unknown material '$Val' of $VarMsg,\
                                    check 'datexcodes.txt'!"
                            } else {

                                # Format: material, region, group, region ID
                                set Val [list [list [lindex $MatLst $Idx]\
                                    [incr RegSeq]_[lindex $MatLst $Idx]\
                                    [lindex $GrpLst $Idx] $RegSeq]]
                                set Bool true
                            }
                        } else {
                            if {$Idx eq -1} {
                                set Bool false
                            } else {
                                set Val [lindex $MatLst $Idx]
                                set Bool true
                            }
                        }
                    } else {
                        set Bool false
                    }
                }
            } elseif {$GID eq "p"} {
                set Bool [regexp ^\[pP\]($RE_p&)*$RE_p$ $Val]
            } elseif {$GID eq "pp"} {
                set Bool [expr [regexp ^\[pP\]($RE_p/$RE_p&)*$RE_p/$RE_p$ $Val]\
                    || [regexp ^\[pP\]($RE_n/\[+-\]&)*$RE_n/\[+-\]$ $Val]]
            } elseif {$GID eq "r"} {
                set Bool [regexp -nocase ^r$RE_r$ $Val]
            } elseif {$GID eq "rr"} {
                set Bool [regexp -nocase ^r($RE_r/$RE_r&)*$RE_r/$RE_r$ $Val]
            } elseif {$GID eq "v"} {
                set Bool false
                set NewVal [list]
                if {[regexp ^\[vV\]($RE_v)$ $Val -> VStr]} {

                    # Single level for 'VarVary'
                    if {[llength $VarLen] == 1} {
                        if {$VarLen == 0} {
                            error "no varying variable in 'VarVary'!"
                        }
                        if {[catch {set IdxLst [readIdx $VStr $VarLen]}]} {
                            error "'$Val' index out of range!"
                        }
                    } else {

                        # Check against multiple-level 'VarVary'
                        if {[llength $VarLen] == $LvlLen
                            && $::SimArr(ColMode)} {
                            if {[lindex $VarLen $LvlIdx] == 0} {
                                error "no varying variable in level '$LvlIdx\
                                    of 'VarVary'!"
                            }
                            if {[catch {set IdxLst [readIdx $VStr\
                                [lindex $VarLen $LvlIdx]]}]} {
                                error "'$Val' index out of range!"
                            }
                        } else {
                            set Idx 0
                            foreach Elm $VarLen {
                                if {$Elm == 0} {
                                    error "no varying variable in level '$Idx'\
                                        of 'VarVary'!"
                                }
                                if {[catch {set IdxLst [readIdx $VStr $Elm]}]} {
                                    error "'$Val' index out of range!"
                                }
                                incr Idx
                            }
                        }
                    }
                    set Bool true
                    foreach Idx $IdxLst {
                        lappend NewVal v$Idx
                    }

                    # Keep the last found duplicate
                    set Val [lsort -unique $NewVal]
                }
            }

            # Skip the rest further processing if not a group ID
            if {!$Bool} {
                continue
            }

            if {[regexp ^\[pP\]($RE_p&)*$RE_p$ $Val]} {
                set NewVal [list]
                foreach Str [split [string range $Val 1 end] &] {
                    set PLst [split $Str _]

                    # Verify coordinates and their numbers should match 'DimLen'
                    if {[llength $PLst] != $DimLen} {
                        error "element 'p$Str' of $VarMsg should have the\
                            same number of coordinates as variable 'RegGen'!"
                    }
                    set Lst [list]
                    foreach Elm $PLst Min [list $XMin $YMin $ZMin]\
                        Max [list $XMax $YMax $ZMax] {
                        if {$Elm ne ""} {

                            # Make sure each point is within simulation domain
                            if {$Elm < $Min || $Elm > $Max} {
                                error "element 'p$Str' of $VarMsg beyond\
                                    simulation domain($Min $Max)!"
                            }

                            # Format each number to the proper form such as
                            # removing trailing zeroes and decimal point
                            lappend Lst [format %.12g $Elm]
                        }
                    }
                    lappend NewVal p[join $Lst _]
                }

                # Keep the last found duplicate
                set Val [lsort -unique $NewVal]
            }
            if {[regexp ^\[pP\]($RE_p/$RE_p&)*$RE_p/$RE_p$ $Val]\
                || [regexp ^\[pP\]($RE_n/\[+-\]&)*$RE_n/\[+-\]$ $Val]} {
                set NewVal [list]
                foreach Str [split [string range $Val 1 end] &] {
                    if {$DimLen > 1} {
                        set PPLst [list]
                        foreach PLst [split [split $Str _] /] {
                            if {[llength $PLst] != $DimLen} {
                                error "element 'p$Str' of $VarMsg should have\
                                    the same number of coordinates as\
                                    variable 'RegGen'!"
                            }
                            set Tmp [list]
                            foreach Elm $PLst {

                                # Format each number to the proper form like
                                # removing trailing zeroes and decimal point
                                lappend Tmp [format %.12g $Elm]
                            }
                            lappend PPLst [join $Tmp _]
                        }
                        lappend NewVal p[join $PPLst /]

                        # sort axis values in 'pp' ascendingly
                        # make sure the interface or box is within simulation
                        # domain and defined correctly
                        set Idx 0
                        set Cnt 0
                        lset PPLst 0 [split [lindex $PPLst 0] _]
                        lset PPLst 1 [split [lindex $PPLst 1] _]
                        foreach Elm1 [lindex $PPLst 0] Elm2 [lindex $PPLst 1]\
                            Min [list $XMin $YMin $ZMin]\
                            Max [list $XMax $YMax $ZMax] {
                            if {$Elm1 ne ""} {
                                incr Cnt [expr $Elm1 == $Elm2]

                                # Sort and format each number properly
                                set Tmp [lsort -real [list $Elm1 $Elm2]]
                                lset PPLst 0 $Idx [lindex $Tmp 0]
                                lset PPLst 1 $Idx [lindex $Tmp 1]
                                if {[lindex $Tmp 0] < $Min
                                    || [lindex $Tmp 1] > $Max} {
                                    error "($Tmp) in element 'p$Str' of $VarMsg\
                                        beyond domain($Min $Max)!"
                                }
                            }
                            incr Idx
                        }

                        # 'pp' should be two points
                        if {$Cnt == $DimLen} {
                            error "element 'p$Str' of $VarMsg should be two\
                                points!"
                        }

                        # 'pp' for 'pprr' is perpendicular to one axis
                        # Otherwise, it should be a region instead
                        if {[regexp {^o?pprr} $GStr]} {
                            if {$Cnt != 1} {
                                error "element 'p$Str' of $VarMsg should\
                                    be an interface!"
                            }
                        } else {
                            if {$Cnt != 0} {
                                error "element 'p$Str' of $VarMsg should\
                                    be a region!"
                            }

                            # Update 'pp' for region with the sorted coordinates
                            lset NewVal end p[join [join $PPLst /] _]
                        }
                    } else {
                        set PLst [split $Str /]
                        if {[regexp {^o?pprr} $GStr]} {
                            if {[lindex $PLst 1] eq "-"
                                || [lindex $PLst 1] eq "+"} {
                                lappend NewVal p[format %.12g\
                                    [lindex $PLst 0]]/[lindex $PLst 1]
                            } else {
                                error "element 'p$Str' of $VarMsg should\
                                    be an interface!"
                            }
                        } else {
                            if {[lindex $PLst 0] == [lindex $PLst 1]} {
                                error "element 'p$Str' of $VarMsg should\
                                    be a region!"
                            }
                            lappend NewVal p[format %.12g [lindex $PLst\
                                0]]/[format %.12g [lindex $PLst 1]]
                        }
                    }
                }

                # Keep the last found duplicate
                set Val [lsort -unique $NewVal]
            }

            # Verify region and interface. Split them if necessary
            # Break regions/interfaces to each individual region/interface
            if {[regexp -nocase ^r($RE_r|($RE_r/$RE_r&)*$RE_r/$RE_r)$ $Val]} {
                set NewVal [list]
                foreach Str [split [string range $Val 1 end] &] {

                    # Read an index string and verify region indices
                    if {[catch {set IdxLst [readIdx $Str $RegLen]}]} {
                        error "element 'r$Str' index out of range!"
                    }
                    foreach Lst $IdxLst {
                        set Idx [lindex $Lst 0]
                        set Tmp [lindex $Lst 1]

                        # Verify the existence of a region interface between
                        # block regions. No conversion here
                        if {[llength $Lst] > 1
                            && ([llength [lindex $RegInfo $Idx 1]] > 1
                            || [string is double [lindex $RegInfo $Idx 1]])
                            && ([llength [lindex $RegInfo $Tmp 1]] > 1
                            || [string is double [lindex $RegInfo $Tmp 1]])} {
                            rr2pp $RegInfo [lindex $Lst 0] [lindex $Lst 1]
                        }
                        lappend NewVal r[join $Lst /]
                    }
                }

                # Keep the last found duplicate
                set Val [lsort -unique $NewVal]
            }

            # Update 'NewLst' if the next group ID is found unless it is
            # the very first element
            if {$ValIdx != 0} {
                foreach Elm [lindex $SubLst 0] {
                    lappend NewLst [concat [list $Elm] [lrange $SubLst 1 end]]
                }
                set SubLst [list]
            }

            # Skip the rest check if the group ID is verified
            break
        }

        # The first element should be a group ID
        if {$ValIdx == 0 && !$Bool} {
            error "the first element '$Val' of $VarMsg\
                should refer to $Txt!"
        }
        lappend SubLst $Val

        # Update 'NewLst' if it is the very last element
        # No property for a group ID is allowed.
        if {$ValIdx == $ValEnd} {
            foreach Elm [lindex $SubLst 0] {
                lappend NewLst [concat [list $Elm] [lrange $SubLst 1 end]]
            }
        }
        incr ValIdx
    }
    return $NewLst
}

# mfjProc::intfVn
#     Determine the normal 3D vector of an interface based on two opposite
#     positions. The interface is perpendicular to one axis and a dot in 1D,
#     a line in 2D and rectangle in 3D. In 1D, the normal vector is determined
#     from the '+' and '-' sign; In 2D, it is determined from the 'right-hand'
#     rule:
#       Always point the middle finger to the positive Z axis; Point the thumb
#       from the 1st position to the 2nd position, and the index finger points
#       to the normal vector.
#     In 3D, it is also determined from the 'right-hand' rule:
#       Point fingers from the 1st to the 2nd position. Always align the thumb
#       with the X axis, the index with Y, and the middle with Z.
# Arguments:
#     Pos1          Position 1
#     Pos2          Opposite position 2
# Result: Return the normal 3D vector.
proc mfjProc::intfVn {Pos1 {Pos2 ""}} {
    set Vn [list]

    # Validate arguments. Valide arguments:
    # 0_0/1_0 = {0_0 1_0} = {{0 0} {1 0}} = 0_0 1_0 = {0 0} {1 0}
    if {$Pos2 eq ""} {
        if {[regexp {/} $Pos1]} {
            set Pos1 [split $Pos1 /]
        }
        set Pos2 [lindex $Pos1 end]
        set Pos1 [lindex $Pos1 0]
    }
    set Pos1 [string map {_ " "} $Pos1]
    set Pos2 [string map {_ " "} $Pos2]

    # Determine Vn
    if {[llength $Pos1] == 1 && [llength $Pos2] == 1
        && [string is double $Pos1]} {
        if {$Pos2 eq "-"} {
            set Vn [list -1 0 0]
        } elseif {$Pos2 eq "+"} {
            set Vn [list 1 0 0]
        }
    } elseif {[llength $Pos1] == 2 && [llength $Pos2] == 2} {
        foreach Elm1 $Pos1 Elm2 $Pos2 {
            if {![string is double -strict $Elm1]} {
                error "'$Pos1' not a valid position!"
            }
            if {![string is double -strict $Elm2]} {
                error "'$Pos2' not a valid position!"
            }
        }

        # Interface perpendicular to X
        if {[lindex $Pos1 0] == [lindex $Pos2 0]} {
            if {[lindex $Pos1 1] < [lindex $Pos2 1]} {
                set Vn [list -1 0 0]
            } elseif {[lindex $Pos1 1] > [lindex $Pos2 1]} {
                set Vn [list 1 0 0]
            }
        }

        # Interface perpendicular to Y
        if {[lindex $Pos1 1] == [lindex $Pos2 1]} {
            if {[lindex $Pos1 0] < [lindex $Pos2 0]} {
                set Vn [list 0 1 0]
            } elseif {[lindex $Pos1 0] > [lindex $Pos2 0]} {
                set Vn [list 0 -1 0]
            }
        }
    } elseif {[llength $Pos1] == 3 && [llength $Pos2] == 3} {
        foreach Elm1 $Pos1 Elm2 $Pos2 {
            if {![string is double -strict $Elm1]} {
                error "'$Pos1' not a valid position!"
            }
            if {![string is double -strict $Elm2]} {
                error "'$Pos2' not a valid position!"
            }
        }

        foreach Idx1 {0 1 2} Idx2 {1 0 0} Idx3 {2 2 1} {
            if {[lindex $Pos1 $Idx1] == [lindex $Pos2 $Idx1]} {
                set Val [expr ([lindex $Pos1 $Idx2]-[lindex $Pos2 $Idx2])\
                    *([lindex $Pos1 $Idx3]-[lindex $Pos2 $Idx3])]
                if {$Val > 0} {
                    if {$Idx1 == 0} {
                        set Vn [list 1 0 0]
                    } elseif {$Idx1 == 1} {
                        set Vn [list 0 1 0]
                    } else {
                        set Vn [list 0 0 1]
                    }
                } elseif {$Val < 0} {
                    if {$Idx1 == 0} {
                        set Vn [list -1 0 0]
                    } elseif {$Idx1 == 1} {
                        set Vn [list 0 -1 0]
                    } else {
                        set Vn [list 0 0 -1]
                    }
                }
            }
        }
    }

    if {[llength $Vn]} {
        return $Vn
    } else {
        error "'$Pos1/$Pos2' not a valid interface!"
    }
}

# mfjProc::overlap
#     Check overlap between an interface field and a region
# Arguments
#     Intf          An interface normal to one axis
#     Dep           Field depth along the normal axis
#     Reg           An existing region
# Result: Return the depth of overlap. -1 -> no overlap.
proc mfjProc::overlap {Intf Dep Reg} {

    # Validate arguments
    if {![string is double -strict $Dep] || $Dep <= 0} {
        error "depth '$Dep' invalid!"
    }

    # 0_0/1_0 = {0_0 1_0} = {{0 0} {1 0}}
    if {[regexp {/} $Intf]} {
        set Intf [split $Intf /]
    }
    set Pos1 [lindex $Intf 0]
    set Pos2 [lindex $Intf end]
    set Pos1 [string map {_ " "} $Pos1]
    set Pos2 [string map {_ " "} $Pos2]

    # Get two opposite positions from the interface field
    set Vn [intfVn $Pos1 $Pos2]
    set Dim [llength [lindex $Reg 1]]
    set End [expr $Dim-1]
    if {$Dim == 1} {
        set Pos2 [expr $Pos1+[lindex $Vn 0]*$Dep]
    } else {
        set Lst $Pos2
        set Pos2 [list]
        foreach Elm1 $Lst Elm2 [lrange $Vn 0 $End] {
            lappend Pos2 [expr $Elm1+$Elm2*$Dep]
        }
    }

    # Sort positions from low to high
    set R1P1 [list]
    set R1P2 [list]
    foreach Elm1 $Pos1 Elm2 $Pos2 {
        set Tmp [lsort -real [list $Elm1 $Elm2]]
        lappend R1P1 [lindex $Tmp 0]
        lappend R1P2 [lindex $Tmp 1]
    }

    # Get two opposite positions from the region
    if {[lindex $Reg 1] eq "Block"} {
        set R2P1 [lindex $Reg 2]
        set R2P2 [lindex $Reg 3]
    } else {
        set R2P1 [lindex $Reg 1]
        set R2P2 [lindex $Reg 2]
    }

    # Check whether the lower coordinate of each region
    # is within another region
    set Coll 0
    set Dep [list]
    foreach C1 $R1P1 C2 $R1P2 C3 $R2P1 C4 $R2P2 V [lrange $Vn 0 $End] {
        if {$C1 <= $C3 && $C2 > $C3
            || ($C1 >= $C3 && $C1 < $C4)} {
            incr Coll
        }

        # Find the maximum from two minima (C1 and C3)
        # and the minimum from two maxima (C2 and C4)
        set MaxMin [expr $C1 > $C3 ? $C1 : $C3]
        set MinMax [expr $C2 < $C4 ? $C2 : $C4]
        lappend Dep [expr $V*($MinMax-$MaxMin)]
    }

    # If two boxes collide, they collide at all axes. Return overlap depth
    if {$Coll == $Dim} {
        return [expr abs([join $Dep +])]
    } else {
        return -1
    }
}

# mfjProc::rr2pp
#     Convert 'rr' to 'pp'
# Arguments:
#     RegInfo       Detailed info of regions
#     Idx1            Index of region 1
#     Idx2            Index of region 2
# Result: Return the interface between two block regions
proc mfjProc::rr2pp {RegInfo Idx1 Idx2} {

    # Validate arguments
    if {[regexp {^\d+$} $Idx1]} {

        # Format the index to remove leading zeroes
        # and convert octal(0#) and hexadecimal(0x#) to decimal
        set Idx1 [format %d $Idx1]
    } else {
        error "index '$Idx1' not valid!"
    }
    if {[regexp {^\d+$} $Idx2]} {

        # Format the index to remove leading zeroes
        # and convert octal(0#) and hexadecimal(0x#) to decimal
        set Idx2 [format %d $Idx2]
    } else {
        error "index '$Idx2' invalid!"
    }
    if {$Idx1 >= [llength $RegInfo] || $Idx2 >= [llength $RegInfo]} {
        error "index '$Idx1' or '$Idx2' out of range!"
    }
    if {[llength [lindex $RegInfo $Idx1 1]] == 1
        && ![string is double [lindex $RegInfo $Idx1 1]]
        && [lindex $RegInfo $Idx1 1] ne "Block"} {
        error "no rr2pp as region '$Idx1' is not a block!"
    }
    if {[llength [lindex $RegInfo $Idx2 1]] == 1
        && ![string is double [lindex $RegInfo $Idx2 1]]
        && [lindex $RegInfo $Idx2 1] ne "Block"} {
        error "no rr2pp as region '$Idx2' is not a block!"
    }

    # Check whether two regions are adjecent based
    # on axis-aligned bounding box (AABB) collision
    # detection algorithm
    if {[lindex $RegInfo $Idx1 1] eq "Block"} {
        set R1P1 [lindex $RegInfo $Idx1 2]
        set R1P2 [lindex $RegInfo $Idx1 3]
    } else {
        set R1P1 [lindex $RegInfo $Idx1 1]
        set R1P2 [lindex $RegInfo $Idx1 2]
    }
    if {[lindex $RegInfo $Idx2 1] eq "Block"} {
        set R2P1 [lindex $RegInfo $Idx2 2]
        set R2P2 [lindex $RegInfo $Idx2 3]
    } else {
        set R2P1 [lindex $RegInfo $Idx2 1]
        set R2P2 [lindex $RegInfo $Idx2 2]
    }
    set Dim [llength $R1P1]
    set Coll 0
    set MaxMin [list]
    set MinMax [list]
    set Touch false
    set Pos false

    # Check whether the lower coordinate of each region
    # is within another region
    foreach C1 $R1P1 C2 $R1P2 C3 $R2P1 C4 $R2P2 {
        if {$C1 <= $C3 && $C2 >= $C3
            || ($C1 >= $C3 && $C1 <= $C4)} {
            incr Coll
        }

        # Find the maximum from two minima (C1 and C3)
        # and the minimum from two maxima (C2 and C4)
        lappend MaxMin [expr $C1 > $C3 ? $C1 : $C3]
        lappend MinMax [expr $C2 < $C4 ? $C2 : $C4]

        # Maximum = minimum -> two boxes just touch
        if {[lindex $MaxMin end] == [lindex $MinMax end]} {
            if {$C1 != $C2
                && [lindex $MaxMin end] != $C1} {
                set Pos true
            }
            set Touch true
        }
    }

    # If two boxes collide, they collide at all axes
    # An interface is oriented and follows 'right-hand rule': Refer to 'intfVn'
    if {$Coll == $Dim} {
        if {$Touch} {

            # Reject the case where two boxes share one vertex
            if {$Dim > 1 && $MaxMin eq $MinMax} {
                error "region '$Idx1' and '$Idx2' just share one vertex!"
            }
            if {$Dim == 3} {
                if {$Pos} {
                    return [list $MaxMin $MinMax]
                } else {
                    return [list $MinMax $MaxMin]
                }
            } elseif {$Dim == 2} {
                if {$Pos} {
                    if {[lindex $MinMax 0] == [lindex $MaxMin 0]} {
                        return [list $MinMax $MaxMin]
                    } else {
                        return [list $MaxMin $MinMax]
                    }
                } else {
                    if {[lindex $MinMax 0] == [lindex $MaxMin 0]} {
                        return [list $MaxMin $MinMax]
                    } else {
                        return [list $MinMax $MaxMin]
                    }
                }
            } else {
                if {$Pos} {
                    return [list $MinMax +]
                } else {
                    return [list $MinMax -]
                }
            }
        } else {
            error "region '$Idx1' overlaps '$Idx2'!"
        }
    } else {
        error "regions '$Idx1' and '$Idx2' not adjecent!"
    }
}

# mfjProc::calMaxVarLen
#     Calculate the maximum string length of variable names
# Arguments:
#     VarName       List of variable names
#     Suffix        Calculate after removing the suffix string
# Result: Return the max length or 0 for a empty VarName
proc mfjProc::calMaxVarLen {VarName {Suffix ""} } {
    set MaxLen 0
    set SufLen [string length $Suffix]
    foreach Elm $VarName {
        set StrLen [string length $Elm]
        if {$SufLen > 0 && [regexp $Suffix$ $Elm]} {
            incr StrLen -$SufLen
        }
        set MaxLen [expr $MaxLen < $StrLen ? $StrLen : $MaxLen]
    }
    return $MaxLen
}

# mfjProc::readMatDB
    # Extract all supported materials in supplied database files.
    # First extract, then sort, remove duplicates (the last remains) followed
    # by splitting to one material list and one group list
# Arguments:
    # FMat      File name of a material database
    # args      More material database files
# Result: Return a sorted list containing one material list and one group list
proc mfjProc::readMatDB {FMat args} {

    # Validate arguments
    set FMat [string map {\{ "" \} ""} [concat $FMat $args]]

    set Lst [list]
    set Idx 0
    foreach Elm $FMat {
        if {[iFileExists Elm]} {
            vputs -v4 -i3 "Materials found in '$Elm': "
            set Inf [open $Elm r]
            set Begin false
            set ReadMat false
            while {[gets $Inf Line] != -1} {
                if {!$Begin} {
                    if {[regexp -nocase {^\s*Materials\s*\{} $Line]} {
                        set Begin true
                    }
                    continue
                }
                if {$ReadMat} {
                    if {[regexp -nocase {group\s*=\s*(\S+)} $Line -> Grp]} {
                        continue
                    }
                    if {[regexp \} $Line]} {
                        set ReadMat false
                        foreach Mat $Mats {
                            if {[regexp {^[\w.]+$} $Mat]} {
                                lappend Lst [list $Mat $Grp]
                                vputs -v4 -i4 [format "%3s %-24s%s" $Idx $Mat\
                                    $Grp]
                            } else {
                                vputs -i3 "Skip material name '$Mat', which\
                                    has characters beyond 'a-zA-Z0-9_.'!"
                            }
                            incr Idx
                        }
                    }
                } else {
                    if {[regexp {^\s*(.+)\s*\{} $Line -> Tmp]} {
                        set ReadMat true
                        set Mats [list]
                        foreach Mat [string map {, " "} $Tmp] {
                            lappend Mats $Mat
                        }
                        continue
                    }
                    if {[regexp \} $Line]} {
                        break
                    }
                }
            }
            close $Inf
        }
    }

    # Sort, remove duplicates (retain the last one) and split
    set MatLst [list]
    set GrpLst [list]
    foreach Elm [lsort -unique -index 0 $Lst] {
        lappend MatLst [lindex $Elm 0]
        lappend GrpLst [lindex $Elm 1]
    }
    if {[llength $MatLst]} {
        return [list $MatLst $GrpLst]
    } else {
        error "no materials found in '$FMat'!"
    }
}

# mfjProc::buildTree
    # Build a SWB node tree according to the column or full combination mode
    # Key nodes are a list of the last nodes of all tools
# Arguments:
    # VarName             Variable names
    # VarVal              Variable values
    # STIdxLst            Sentaurus tool Index list
    # ColMode             Optional, column (default) or full combination
    # NodeTree            Optional, returns node tree (default) or key nodes
# Result: Return the node tree
proc mfjProc::buildTree {VarName VarVal STIdxLst {ColMode ""} {NodeTree ""}} {

    # Validate arguments
    foreach Elm [list ColMode NodeTree] {

        # Make an alias of 'ColMode' and 'NodeTree'
        upvar 0 $Elm Alias
        if {[string index $Alias 0] eq "!"} {
            set Alias false
        } else {
            set Alias true
        }
    }

    vputs -v2 "Building a SWB node list..."
    set Scenario default
    set STIdx 0
    set STLen [llength $STIdxLst]
    set VarIdx 0
    set Ply 1
    set LastLen 1
    set Seq 0
    set KeyNode [list]
    set SWBNode [list]
    set SWBTree [list]
    foreach Var $VarName Val $VarVal {

        # In case no variables between tools
        while {$STIdx < $STLen && [lindex $STIdxLst $STIdx] == $VarIdx} {
            set Tmp [list]
            for {set i 0} {$i < $Ply} {incr i} {
                lappend Tmp [incr Seq]
            }
            if {$STIdx > 0} {
                lappend KeyNode [lindex $SWBNode end 0]
            }
            lappend SWBNode [list $Tmp "" "" ]
            incr STIdx
        }
        set ValLen [llength $Val]
        if {$ValLen > 1} {
            if {$ValLen != $LastLen || !$ColMode} {
                set Ply [expr {$Ply*$ValLen}]
            }
            set LastLen $ValLen
        }
        set Tmp [list]
        for {set i 0} {$i < $Ply} {incr i} {
            lappend Tmp [incr Seq]
        }
        lappend SWBNode [list $Tmp $Var $Val]
        incr VarIdx
    }

    # In case no variables or the rest tools have no variables
    while {$STIdx < $STLen && [lindex $STIdxLst $STIdx] == $VarIdx} {
        set Tmp [list]
        for {set i 0} {$i < $Ply} {incr i} {
            lappend Tmp [incr Seq]
        }
        if {$STIdx > 0} {
            lappend KeyNode [lindex $SWBNode end 0]
        }
        lappend SWBNode [list $Tmp "" "" ]
        incr STIdx
    }
    lappend KeyNode [lindex $SWBNode end 0]

    vputs -v2 -i1 [join $SWBNode \n]
    if {!$NodeTree} {
        return $KeyNode
    }

    vputs -v2 "Converting the node list to a SWB tree..."
    set End [llength $SWBNode]
    incr End -1
    for {set i 0} {$i < $Ply} {incr i} {
        for {set j 0} {$j <= $End} {incr j} {
            set k1 [expr {$Ply/[llength [lindex $SWBNode $j 0]]}]
            if {$i % $k1 == 0} {
                set n1 $j
                set n2 [lindex $SWBNode $j 0 [expr {$i/$k1}]]
                if {$i == 0 && $j == 0} {
                    set n3 0
                }
                if {$j > 0} {
                    incr j -1
                    set k2 [expr {$Ply/[llength [lindex $SWBNode $j 0]]}]
                    set n3 [lindex $SWBNode $j 0 [expr int($i/$k2)]]
                    incr j
                }
                set Len [llength [lindex $SWBNode $j end]]
                if {$Len} {
                    set Val [lindex $SWBNode $j end [expr {$i/$k1%$Len}]]
                } else {
                    set Val ""
                }
                lappend SWBTree "$n1 $n2 $n3 \{$Val\} \{$Scenario\} 0"
            }
        }
    }
    vputs -v2 -i1 [join $SWBTree \n]
    return $SWBTree
}

# mfjProc::tcl2Scheme
    # Properly convert a Tcl value (number, string or boolean) to the
    # corresponding SCHEME value. In case the value is a nested list,
    # the recursive mechanism is exploited. Additionally, all empty strings
    # are treated as empty SCHEME lists
# Arguments:
    # VarName     Variable name
    # VarVal      Variable value
    # Level       Optional, default list level starts from 0
# Result: Return the converted SCHEME value
proc mfjProc::tcl2Scheme {VarName VarVal {Level 0}} {

    # Validate arguments
    # A level should not be a negative integer
    if {![regexp {^\d+$} $Level]} {
        error "invalid level '$Level'!"
    }

    set SLst [list]
    foreach SubLst $VarVal {
        set SubLen [llength $SubLst]
        if {$SubLen > 1 || [regexp {^\{.*\}$} $SubLst]} {

            # The function name is adaptive using '[lindex [info level 0] 0]'
            lappend SLst [[lindex [info level 0] 0] $VarName\
                $SubLst [expr {$Level+1}]]
        } else {
            if {$SubLen == 0} {

                # Set 'SubLst' to {} so {  } is the same as {}
                # Otherwise, {  } will be converted to "  "
                set SubLst [list]
            } elseif {![string is double $SubLst]} {
                set SubLst '$SubLst'
            }
            lappend SLst $SubLst
        }
    }
    if {$Level} {
        vputs -v3 -i1 "Level $Level: \{$SLst\}"
    } else {

        # Level 0
        vputs -v3 -i1 "Level $Level: \{$SLst\}\n"

        # Convert to a SCHEME list except for a number or a string
        if {[llength $SLst] != 1 || [regexp {^\{.*\}$} $SLst]} {
            set SLst [string map {\{ "(list " \} ) ' \"} [list $SLst]]
        } else {
            set SLst [string map {' \"} $SLst]
        }

        # There is no boolean type in Tcl. Roughly, these strings like true,
        # false, yes, no, on, off are boolean. Strictly speaking, positive
        # integers have the boolean value of true, which are ignored here
        # '#t' in some Tcl intepreters may become '{#t}', which would cause
        # strange conversion in the above steps. It is better to do it here
        regsub -nocase -all {\"(true|yes|on)\"} $SLst #t SLst
        regsub -nocase -all {\"(false|no|off)\"} $SLst #f SLst
    }
    return $SLst
}

# mfjProc::customSpec
    # Extract and build a custom spectrum from a general spectrum. The old
    # spectrum should have two columns with unit nm and W*m^-2*nm^-1
# Arguments:
    # FSpec       A general spectrum file
    # WBegin      Beginning wavelength [um]
    # WEnd        Ending wavelength [um]
    # WStep       Step size between beginning and ending wavelengths [um]
    # Shading     Optional shading fraction [0]
    # FSave       Optional file name for saving the custom spectrum
# Result: Two lists of wavelengths (nm) and corresponding intensities (W*cm^-2)
proc mfjProc::customSpec {FSpec WBegin WEnd WStep {Shading 0} {FSave ""}} {

    # Validate arguments
    if {![file isfile $FSpec]} {
        error "file '$FSpec' not found!"
    }
    foreach Elm {WBegin WEnd WStep} {
        upvar 0 $Elm Alias
        if {![string is double -strict $Alias]} {
            error "'$Elm' should be a number!"
        }

        # Convert wavelengths from um to nm for accuracy
        set Alias [expr {1e3*$Alias}]
    }

    set WLow [expr {$WBegin-0.5*$WStep}]
    set WHigh [expr {$WBegin+0.5*$WStep}]
    set Sum 0
    foreach Elm {OldSpecWl OldSpecInt NewSpecWl NewSpecInt WlSubLst IntSubLst} {

        # Make an alias of each variables
        upvar 0 $Elm Alias
        set Alias [list]
    }
    vputs -v5 -i1 "Reading the general spectrum file '$FSpec'..."
    set Inf [open $FSpec r]
    while {[gets $Inf Line] != -1} {
        if {![regexp {^\s*#} $Line] && [llength $Line] == 2
            && [string is double -strict [lindex $Line 0]]
            && [string is double -strict [lindex $Line 1]]} {

            # Keep wavelength unit and change intensities to W*cm^-2*nm^-1
            lappend OldSpecWl [lindex $Line 0]
            lappend OldSpecInt [expr [lindex $Line 1]/1e4]
        }
    }
    close $Inf
    vputs -v5 -i2 "The general spectrum range: '[lindex $OldSpecWl 0]'\
        -> '[lindex $OldSpecWl end]' nm"
    if {[lindex $OldSpecWl 0] > $WBegin || [lindex $OldSpecWl end] < $WEnd} {
        error "either '$WBegin' or '$WEnd' nm is beyond '$FSpec'!"
    }
    vputs -v5 -i2 "The new spectrum range: '$WBegin' -> '$WEnd' nm\
        with a step size of $WStep"

    # Only interpolate values for $WHigh
    vputs -v5 -i1 "Calculating new wavelengths and intensities (W*cm^-2)..."
    foreach Wl $OldSpecWl Int $OldSpecInt {
        if {$Wl < $WLow} {
            continue
        } elseif {$Wl > $WLow} {
            if {$Wl < $WHigh} {

                # Append them to sublists
                lappend WlSubLst $Wl
                lappend IntSubLst $Int
            } else {
                if {$Wl == $WHigh} {
                    lappend WlSubLst $Wl
                    lappend IntSubLst $Int
                } else {

                    # Perform interpolation
                    set XLst [list [lindex $WlSubLst end] $Wl]
                    set YLst [list [lindex $IntSubLst end] $Int]
                    lappend WlSubLst $WHigh
                    lappend IntSubLst [lPolation $XLst $YLst $WHigh]

                }

                # Update NewSpecWl and NewSpecInt
                lappend NewSpecWl [expr {0.5*($WLow+$WHigh)}]

                # Sum up intensities using the trapezoidal rule
                set Len [llength $IntSubLst]
                for {set i 0; set j 1} {$j < $Len} {incr i; incr j} {
                    set Sum [expr {$Sum+0.5*([lindex $IntSubLst $j]\
                        +[lindex $IntSubLst $i])*([lindex $WlSubLst $j]\
                        -[lindex $WlSubLst $i])}]
                }

                # Force numbers to be double type in '*' and '/' operations
                lappend NewSpecInt [expr {(1.-$Shading)*$Sum*$WStep\
                    /([lindex $WlSubLst end]-[lindex $WlSubLst 0])}]
                vputs -v5 -i2 "[lindex $NewSpecWl end]\t[lindex\
                    $NewSpecInt end]"

                # Prepare for the next range
                if {$WLow+$WStep < $WEnd} {
                    set WLow [expr {$WLow+$WStep}]
                    set WHigh [expr {$WHigh+$WStep}]
                } else {
                    break
                }
                set Sum 0
                set WlSubLst [list [lindex $WlSubLst end]]
                set IntSubLst [list [lindex $IntSubLst end]]
                if {$Wl > $WHigh} {
                    lappend WlSubLst $Wl
                    lappend IntSubLst $Int
                }
            }
        } else {

            # Append them to sublists
            lappend WlSubLst $Wl
            lappend IntSubLst $Int
        }
    }

    # In case the last spectrum wavelength is lower than $WHigh
    if {$Wl < $WHigh} {

        # Update NewSpecWl and NewSpecInt
        lappend NewSpecWl [expr {0.5*($WLow+$WHigh)}]

        # Sum up intensities using the trapezoidal rule
        set Len [llength $IntSubLst]
        for {set i 0; set j 1} {$j < $Len} {incr i; incr j} {
            set Sum [expr {$Sum+0.5*([lindex $IntSubLst $j]\
                +[lindex $IntSubLst $i])\
                *([lindex $WlSubLst $j]-[lindex $WlSubLst $i])}]
        }
        lappend NewSpecInt [expr {(1.-$Shading)*$Sum*$WStep\
            /([lindex $WlSubLst end]-[lindex $WlSubLst 0])}]
        vputs -v5 -i2 "[lindex $NewSpecWl end]\t[lindex $NewSpecInt end]"
    }

    # Compute the new integrated intensity
    set Sum 0
    foreach Int $NewSpecInt {
        set Sum [expr $Sum+$Int]
    }
    set Sum [expr 1e4*$Sum]

    # Save the custom spectrum if required
    if {$FSave ne ""} {
        if {[catch {set Ouf [open $FSave w]}]} {
            error "unable to open '$FSave' for write!"
        }
        puts $Ouf "# Original spectrum: '$FSpec' begins from [format %.12g\
            [lindex $OldSpecWl 0]] nm, ends to [format %.12g [lindex\
            $OldSpecWl end]] nm"
        puts $Ouf "# New spectrum: Begins from [format %.12g $WBegin] nm and\
            ends to [format %.12g $WEnd] nm with a step size of [format %.12g\
            $WStep] nm"
        puts $Ouf [format "# The new integrated intensity: %.4f W*m^-2" $Sum]
        puts $Ouf "Optics/Excitation/Wavelength \[um\] intensity\
            \[W*cm^-2\]"
        foreach Wl $NewSpecWl Int $NewSpecInt {
            puts $Ouf [format "%.4f\t%.4e" [expr $Wl/1e3] $Int]
        }
        close $Ouf
    }
    return [list $NewSpecWl $NewSpecInt]
}

# mfjProc::specInt
    # Extract the total intensity [mW*cm^-2] from a spectrum, which has two
    # columns of data. The first column comes with unit nm and the second has
    # unit W*m^-2*nm^-1
# Arguments:
    # FSpec       A general spectrum file
# Result: The total intensity following the trapezoidal rule
proc mfjProc::specInt {FSpec} {

    # Validate arguments
    if {![file isfile $FSpec]} {
        error "file '$FSpec' not found!"
    }
    set Sum 0
    set Inf [open $FSpec r]
    while {[gets $Inf Line] != -1} {
        if {[llength $Line] == 2
            && [string is double -strict [lindex $Line 0]]
            && [string is double -strict [lindex $Line 1]]} {
            if {[info exists Wl]} {
                set Sum [expr {$Sum+5e-2*($Int+[lindex $Line 1])\
                    *abs([lindex $Line 0]-$Wl)}]
            }
            set Wl [lindex $Line 0]
            set Int [lindex $Line 1]
        }
    }
    close $Inf
    return $Sum
}

# mfjProc::curve2CSV
    # Write a curve to a CSV format file with more controls (SVisual only)
# Arguments:
    # CName       The curve name in SVisual
    # XTitle      The title of X-axis
    # YTitle      The title of Y-axis
    # PName       The plot name
    # FCSV        The CSV format file for output
    # TLyr        The number of top dummy layers
    # BLyr        The number of bottom dummy layers
# Result: Return 1 for success
proc mfjProc::curve2CSV {CName XTitle YTitle PName FCSV {TLyr 0} {BLyr 0}} {

    # Validate arguments
    foreach Elm {TLyr BLyr} {
        upvar 0 $Elm Alias
        if {![regexp {^\d+$} $Alias]} {
            error "invalid number of layer '$Alias'!"
        }
    }

    set XData [get_curve_data $CName -axisX -plot $PName]
    set YData [get_curve_data $CName -axisY -plot $PName]
    if {[llength $XData] < 2} {
        error "no sufficient data for '$CName'!"
    }

    # Trim left and right spaces if any
    set XTitle [string trim $XTitle]|X
    set YTitle [string trim $YTitle]

    # Ascending order for the X-axis
    set End [llength $XData]
    incr End -1
    if {[lindex $XData 0] > [lindex $XData end]} {
        set XTmp [list]
        set YTmp [list]
        for {set i $End} {$i >= 0} {incr i -1} {
            lappend XTmp [lindex $XData $i]
            lappend YTmp [lindex $YData $i]
        }
        set XData $XTmp
        set YData $YTmp
    }

    # Remove dummy layers if any
    set TIdx 0
    set BIdx $End
    if {$TLyr > 0 && $End > 0} {
        set Cnt 0
        set Idx 0
        for {set j $Idx; set i [incr Idx]} {$i <= $End} {incr i; incr j} {
            if {[lindex $XData $i] == [lindex $XData $j]} {
                incr Cnt
            }
            if {$Cnt == $TLyr} {
                set TIdx $i
                break
            }
        }
    }
    if {$BLyr > 0 && $End > 0} {
        set Cnt 0
        set Idx $End
        for {set j $Idx; set i [incr Idx -1]} {$i >= 0}\
            {incr i -1; incr j -1} {
            if {[lindex $XData $i] == [lindex $XData $j]} {
                incr Cnt
            }
            if {$Cnt == $BLyr} {
                set BIdx $i
                break
            }
        }
    }
    if {$TIdx > 0 || $BIdx < $End} {
        set XData [lrange $XData $TIdx $BIdx]
        set YData [lrange $YData $TIdx $BIdx]
    }

    set Ouf [open $FCSV.[pid] w]
    vputs -i3 "curve '$CName'"
    if {![file isfile $FCSV]} {
        puts $Ouf "$XTitle,$YTitle"
        set Idx 0
        foreach X $XData Y $YData {
            vputs -v5 "L$Idx: \{$X,$Y\}"
            puts $Ouf "$X,$Y"
            incr Idx
        }
    } else {
        set Inf [open $FCSV r]
        set OldTitles [split [gets $Inf] ,]
        vputs -v3 -i4 "Old Titles: $OldTitles"
        set Idx 0
        set NewTitles [list]
        set BlankLst [list]
        foreach Title $OldTitles {
            if {[regexp {\|X$} $Title]} {
                if {[info exists XExist]} {
                    if {![info exists YIdx]} {
                        set YIdx $Idx
                        lappend NewTitles $YTitle
                        lappend BlankLst ""
                    }
                    lappend NewTitles $Title
                    lappend BlankLst ""
                } else {

                    # strings are compared lexicographically
                    # -1: str1 < str2; 1: str1 > str2; 0: same
                    set tmp [string compare $XTitle $Title ]
                    if {$tmp <= 0} {
                        set XIdx $Idx
                        lappend NewTitles $XTitle
                        lappend BlankLst ""
                        if {$tmp == 0} {
                            vputs -v5 -i4 "XTitle '$XTitle' = '$Title'"
                            set XExist true
                        } else {
                            vputs -v5 -i4 "XTitle '$XTitle' < '$Title'"
                            set YIdx [incr Idx]
                            lappend NewTitles $YTitle
                            lappend BlankLst ""
                            lappend NewTitles $Title
                            lappend BlankLst ""
                        }
                    } else {
                        vputs -v5 -i4 "XTitle '$XTitle' > '$Title'"
                        lappend NewTitles $Title
                        lappend BlankLst ""
                    }
                }
            } else {
                if {[info exists XExist] && ![info exists YIdx]} {
                    set tmp [string compare $YTitle $Title]
                    if {$tmp <= 0} {
                        set YIdx $Idx
                        lappend NewTitles $YTitle
                        lappend BlankLst ""
                        if {$tmp == 0} {
                            vputs -v5 -i4 "YTitle '$YTitle' = '$Title'"
                            set YExist true
                        } else {
                            vputs -v5 -i4 "YTitle '$YTitle' < '$Title'"
                            lappend NewTitles $Title
                            lappend BlankLst ""
                        }
                    } else {
                        vputs -v5 -i4 "YTitle '$YTitle' > '$Title'"
                        lappend NewTitles $Title
                        lappend BlankLst ""
                    }
                } else {
                    lappend NewTitles $Title
                    lappend BlankLst ""
                }
            }
            incr Idx
        }

        # In case XTitle > all existing X titles
        if {![info exists XIdx]} {
            set XIdx $Idx
            set YIdx [incr Idx]
            lappend NewTitles $XTitle
            lappend NewTitles $YTitle
        }

        # In case XTitle is the last and YTitle > all existing Y titles
        if {![info exists YIdx]} {
            set YIdx $Idx
            lappend NewTitles $YTitle
        }
        vputs -v3 -i4 "NewTitles: $NewTitles"
        puts $Ouf [join $NewTitles ,]

        # Insert new data points to the existing data
        vputs -v3 -i3 "Writing new data to column '$XIdx' and '$YIdx'..."
        set Idx 0
        set Len [llength $XData]
        set Lines [split [read $Inf] \n]
        foreach Line $Lines {
            set NewLst [split $Line ,]
            if {[llength $NewLst] == 0} continue
            if {$Idx < $Len} {
                set X [lindex $XData $Idx]
                set Y [lindex $YData $Idx]
            } else {
                set X ""
                set Y ""
            }
            if {[info exists XExist]} {
                lset NewLst $XIdx $X
                if {[info exists YExist]} {
                    lset NewLst $YIdx $Y
                } else {
                    set NewLst [linsert $NewLst $YIdx $Y]
                }
            } else {
                set NewLst [linsert $NewLst $XIdx $X]
                set NewLst [linsert $NewLst $YIdx $Y]
            }
            vputs -v5 "L$Idx: \{[join $NewLst ,]\}"
            puts $Ouf [join $NewLst ,]
            incr Idx
        }
        close $Inf

        # In case there are more new data points
        while {$Idx < $Len} {
            set NewLst $BlankLst
            if {[info exists XExist]} {
                lset NewLst $XIdx [lindex $XData $Idx]
                if {[info exists YExist]} {
                  lset NewLst $YIdx [lindex $YData $Idx]
                } else {
                  set NewLst [linsert $NewLst $YIdx [lindex $YData $Idx]]
                }
            } else {
                set NewLst [linsert $NewLst $XIdx [lindex $XData $Idx]]
                set NewLst [linsert $NewLst $YIdx [lindex $YData $Idx]]
            }
            vputs -v5 "L$Idx: \{[join $NewLst ,]\}"
            puts $Ouf [join $NewLst ,]
            incr Idx
        }
    }
    close $Ouf
    file rename -force $FCSV.[pid] $FCSV
}

# mfjProc::plx2CSV
    # Convert a .plx file to a CSV file
# Arguments
    # FPlx        The file name of a .plx file
    # FCSV        The file name of the converted CSV file
    # Remove      A switch determining whether to remove the .plx file or not
# Result: Return 1 for success
proc mfjProc::plx2CSV {FPlx {FCSV ""} {Remove ""}} {

    # Verify arguments
    if {![file exists $FPlx]} {
        error "$FPlx not found!"
    }
    if {$FCSV eq ""} {
        set FCSV [file rootname $FPlx].csv
    }
    if {[string index $Remove 0] eq "!"} {
        set Remove false
    } else {
        set Remove true
    }

    # Read the .plx file
    set Inf [open $FPlx r]
    set XCol [list]
    set YCols [list]
    set Col [list]
    set Title Depth
    while {[gets $Inf Line] != -1} {
        if {[llength $Line] == 2 && [string is double [lindex $Line 0]]
            && [string is double [lindex $Line 1]]} {
            if {[llength $Title] == 2} {
                lappend XCol [lindex $Line 0]
            }
            lappend Col [lindex $Line 1]
        } elseif {[regexp {^"(\S+)"$} $Line -> Tmp]} {
            lappend Title $Tmp
            if {[llength $Col]} {
                lappend YCols $Col
            }
            set Col [list]
        }
    }
    if {[llength $Col]} {
        lappend YCols $Col
    }
    close $Inf

    # Write to the corresponding csv file
    set Ouf [open $FCSV w]
    puts $Ouf [join $Title ,]
    set Len [llength $XCol]
    set YLen [llength $YCols]
    for {set i 0} {$i < $Len} {incr i} {
        puts -nonewline $Ouf [lindex $XCol $i]
        for {set j 0} {$j < $YLen} {incr j} {
            puts -nonewline $Ouf ,[lindex $YCols $j $i]
        }
        puts $Ouf ""
    }
    close $Ouf

    if {$Remove} {
        file delete $FPlx
    }
}

# mfjProc::cut1D
    # Extract 1D profiles of structural fields from a saved snapshot
# Arguments
    # FTDR          The file name of a saved snapshot
    # FldStruct     Settings of extracting structural fields
    # RegDim        Region details
    # YDflt         Default Y value for 1D
    # FCSV          The file name of extracted fields
    # FCnt          A counter to differentiate names of plots and datasets
# Result: Return 0 for missing 'FTDR' or 1 for success
proc mfjProc::cut1D {FTDR FldStruct RegDim YDflt FCSV FCnt} {
    if {![file exists $FTDR]} {
        return 0
    }
    set Dim [llength [lindex $RegDim 0 1]]
    set Cut false
    regexp {_([a-zA-Z0-9]+)_des.tdr$} $FTDR -> Idx
    if {[string is integer $Idx]} {
        set Idx [format %.12g $Idx]
    }

    # 'svisual' remembers the names of plots and datasets even after
    # removing them so names have to be different
    vputs "Loading $FTDR for fields extraction..."
    load_file $FTDR -name DTDR
    set i 0
    foreach Grp $FldStruct {
        set PLst [string map {p "" _ " "} [lindex $Grp 0]]
        if {$Dim == 3} {
            create_plot -name P3D${FCnt}_$i -dataset DTDR
        } else {
            create_plot -name P2D${FCnt}_$i -dataset DTDR
        }

        # Do Y cut if 1D
        if {$Dim == 1 && $PLst >= 0 && $PLst <= $YDflt} {
            create_cutline -name C1D${FCnt}_$i -dataset DTDR\
                -type Y -at $PLst
            set Cut true
        }
        if {$Dim == 2} {
            if {[lindex $PLst 0] >= 0
                && [lindex $PLst 0] <= [lindex $RegDim end-1 1 0]} {
                create_cutline -name C1D${FCnt}_$i -plot P2D${FCnt}_$i\
                    -type X -at [lindex $PLst 0]
                set Cut true
            } elseif {[lindex $PLst 1] >= 0
                && [lindex $PLst 1] <= [lindex $RegDim end 1 1]} {
                create_cutline -name C1D${FCnt}_$i -plot P2D${FCnt}_$i\
                    -type Y -at [lindex $PLst 1]
                set Cut true
            }
        }
        if {$Dim == 3} {
            if {[lindex $PLst 0] >= 0
                && [lindex $PLst 0] <= [lindex $RegDim end-2 1 0]} {
                create_cutplane -name C2D${FCnt}_$i -plot P3D${FCnt}_$i\
                    -type X -at [lindex $PLst 0]
                create_plot -name P2D${FCnt}_$i -dataset C2D${FCnt}_$i\
                    -ref_plot P3D${FCnt}_$i
                remove_cutplanes C2D${FCnt}_$i
                if {[lindex $PLst 1] >= 0
                    && [lindex $PLst 1] <= [lindex $RegDim end-1 1 1]} {
                    create_cutline -name C1D${FCnt}_$i -plot P2D${FCnt}_$i\
                        -type Y -at [lindex $PLst 1]
                    set Cut true
                } elseif {[lindex $PLst 2] >= 0
                    && [lindex $PLst 2] <= [lindex $RegDim end 1 2]} {
                    create_cutline -name C1D${FCnt}_$i -plot P2D${FCnt}_$i\
                        -type Z -at [lindex $PLst 2]
                    set Cut true
                }
            } else {
                if {[lindex $PLst 1] >= 0 && [lindex $PLst 2] >= 0
                    && [lindex $PLst 1] <= [lindex $RegDim end-1 1 1]
                    && [lindex $PLst 2] <= [lindex $RegDim end 1 2]} {
                    create_cutplane -name C2D${FCnt}_$i -plot P3D${FCnt}_$i\
                        -type Y -at [lindex $PLst 1]
                    create_plot -name P2D${FCnt}_$i -dataset C2D${FCnt}_$i\
                        -ref_plot P3D${FCnt}_$i
                    remove_cutplanes C2D${FCnt}_$i
                    create_cutline -name C1D${FCnt}_$i -plot P2D${FCnt}_$i\
                        -type Z -at [lindex $PLst 2]
                    set Cut true
                }
            }
        }

        if {$Cut} {
            create_plot -name Plot1D$FCnt -dataset C1D${FCnt}_$i -1d
            if {$Dim == 3} {
                remove_plots P3D${FCnt}_$i
            }
            remove_plots P2D${FCnt}_$i
            select_plots Plot1D$FCnt
            set_plot_prop -show_grid -show_curve_markers\
                -title $FTDR -title_font_size 28
            set_grid_prop -show_minor_lines\
                -line1_style dash -line1_color gray\
                -line2_style dot -line2_color lightGray
            set_axis_prop -axis x -title_font_size 20 -title {Depth|um}\
                -scale_font_size 16 -scale_format preferred -type linear
            set j 0
            foreach Elm [lrange $Grp 3 end] {
                set Elm $mfjProc::TabArr($Elm)
                vputs -i1 "Extracting $Elm at [lindex $Grp 0]..."
                create_curve -name X${i}_F$j -dataset C1D${FCnt}_$i\
                    -axisX X -axisY [lindex [split $Elm |] 0]
                set_curve_prop X${i}_F$j -line_width 3\
                    -label $Elm
                curve2CSV X${i}_F$j [get_axis_prop -axis x -title]\
                    $Idx-[lindex $Grp 0]-$Elm Plot1D$FCnt $FCSV\
                    [lindex $Grp 1] [lindex $Grp 2]
                incr j
            }
        } else {
            vputs -i1 "No cut done, double check '[lindex $Grp 0]'"
        }
        incr i
    }
    vputs "Unloading $FTDR...\n"
    unload_file $FTDR

    return 1
}

# mfjProc::gVar2DOESum
    # Write an array of Sentaurus extracted variables to the DOE summary file
    # '06out/DOESummary.csv'
# Arguments:
    # GVarArr     Keys are Sentaurus extracted variables
    # TrialNode   The trial node which is running to extract variables
    # FDOESum     Optional, '06out/DOESummary.csv' is default
# Result: Return 1 for success
proc mfjProc::gVar2DOESum {GVarArr TrialNode {FDOESum ""}} {

    # Validate arguments
    if {$FDOESum eq ""} {
        set FDOESum 06out/DOESummary.csv
    }
    if {![regexp {^\d+$} $TrialNode]} {
        error "'$TrialNode' should be a positive integer or zero!"
    }
    vputs -i1 "\nUpdating '$FDOESum' with gVars for trial node '$TrialNode'..."

    # Delay a random time to avoid multiple processes accessing the fDOESum
    # at the same time
    after [expr int(1e3*rand())]

    # No read and write of $FDOESum until the file lock is removed
    set FLock [file rootname $FDOESum].lock
    while {[file exists $FLock]} {
        after 1000
    }

    # Set the file lock for exclusive access to $FDOESum
    vputs -i2 "Set a file lock for exclusive access to $FDOESum"
    close [open $FLock w]
    set Inf [open $FDOESum r]
    set Lines [list]
    set IdxLst [list]
    set CmntCnt 0
    upvar 1 $GVarArr Arr
    set KeyLst [lsort [array names Arr]]
    while {[gets $Inf Line] != -1} {
        if {[string index $Line 0] eq "#"} {
            incr CmntCnt
            lappend Lines $Line
        } else {
            if {$CmntCnt == 1 && [llength $Line]} {
                set NodeLst [lrange [split $Line ,] 1 end]
                set NodeLen [llength $NodeLst]
                set TrialIdx [lsearch -sorted -integer $NodeLst $TrialNode]
                if {$TrialIdx == -1} {
                    error "'$TrialNode' not found in '$NodeLst'!"
                }
                set LineIdx [expr $TrialIdx+1]
                lappend Lines $Line
            } elseif {$CmntCnt == 3} {
                vputs -v5 -i2 "Old line: $Line"
                set Line [split $Line ,]
                set Idx [lsearch -exact $KeyLst [lindex $Line 0]]
                if {$Idx != -1} {
                    set OldVal [lindex $Line $LineIdx]

                    # No space in the key of an array
                    set NewVal $Arr([lindex $KeyLst $Idx])
                    vputs -v5 -i3 "Updating index '$LineIdx':\
                        '$OldVal' -> '$NewVal'"
                    lset Line $LineIdx $NewVal
                    lappend IdxLst $Idx
                }
                lappend Lines [join $Line ,]
            } else {
                lappend Lines $Line
            }
        }
    }
    close $Inf

    # Append new lines for extracted variables
    if {[llength $IdxLst] < [llength $KeyLst]} {
        set IdxLst [lsort -integer $IdxLst]
        set Idx 0
        foreach Key $KeyLst {
            if {[llength $IdxLst]
                && $Key eq [lindex $KeyLst [lindex $IdxLst $Idx]]} {
                incr Idx
            } else {
                set Line [list]
                lappend Line $Key
                for {set i 0} {$i < $NodeLen} {incr i} {
                    if {$i != $TrialIdx} {
                        lappend Line ""
                    } else {
                        lappend Line $Arr($Key)
                    }
                }
                set Line [join $Line ,]
                lappend Lines $Line
                vputs -v5 -i2 "Appending a new line: '$Line'"
            }
        }
    }

    # Set the point to the beginning
    set Ouf [open $FDOESum w]
    puts $Ouf [join $Lines \n]
    close $Ouf

    # Have to remove the file lock to release $FDOESum
    vputs -i2 "Remove the file lock to release access to $FDOESum"
    file delete $FLock
}

package provide mfjProc $mfjProc::version
