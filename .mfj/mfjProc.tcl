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
        Eg BandGap|eV BGN
        BandgapNarrowing|eV ni IntrinsicDensity|cm^-3
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

# mfjProc::safeLog
    # Designed to log a message to files with directory creation and symbolic
    # link checks
# Arguments:
    # FName       A log file name
    # Access      File access mode, 'w' or 'a'
    # Msg         A message to be logged
    # NewLine     New line flag
# Result: Return 1 as success or run into an error
proc mfjProc::safeLog {FName Access Msg {NewLine true}} {

    # Validate arguments. Return if no file name specified
    if {![llength $FName]} {
        return 1
    }
    set Access [string tolower $Access]
    if {$Access ne "w" && $Access ne "a"} {
        error "invalid access mode: must be 'w' or 'a'!"
    }

    # Create parent directory if needed
    if {![file isfile $FName]} {
        set Dir [file dirname $FName]
        if {![file isdirectory $Dir]} {
            file mkdir $Dir
        }
    } else {

        # Avoid a symbolic link under Unix
        if {$::tcl_platform(platform) eq "unix"
            && [file type $FName] eq "link"} {
            error "a symbolic link not allowed: '$FName'"
        }
    }

    # Handle backup creation for write mode
    if {$Access eq "w"} {
        set Bak "${FName}.backup"
        if {[file isfile $FName]} {
            file copy -force $FName $Bak
        }
    }

    # Open the file with error handling
    if {[catch {set Ouf [open $FName $Access]} Err]} {
        error "failed to open '$FName': $Err"
    }

    # Log with or without newline
    if {$NewLine} {
        puts $Ouf $Msg
    } else {
        puts -nonewline $Ouf $Msg
    }
    close $Ouf
    return 1
}

# mfjProc::vputs
    # Designed to handle formatted output with various options for verbosity,
    # indentation, and file logging by adding additional controls to 'puts'
    # to achieve versatile output styles. It handles a wide range of formatting
    # scenarios and ensures that messages are output correctly based on the
    # specified options.
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

    # Separate string from options
    set Str [lindex $args end]
    set args [lrange $args 0 end-1]

    # Default vputs behaviour
    set Access a
    set Continue false
    set NewLine true
    set OneLine false
    set SameInt false
    set Indent 0
    set Verbosity 1

    # Analyse arguments
    while {[llength $args]} {
        set opt [lindex $args 0]
        switch -regexp -- $opt {
            ^-[cC]$ {
                set Continue true
            }
            ^-[nN]$ {
                set NewLine false
            }
            ^-[oO]$ {
                set OneLine true
            }
            ^-[sS]$ {
                set SameInt true
            }
            ^-[wW]$ {
                set Access w
            }
            ^-[iI]-?\\d+$ {
                set Indent [string range $opt 2 end]
            }
            ^-[vV]-?\\d+$ {
                set Verbosity [string range $opt 2 end]
            }
            ^--$ {
                break
            }
            default {
                if {[string match -* $opt]} {
                    error "unknown option '$opt'!"
                } else {
                    error "wrong # args: should be \"vputs ?-c|n|o|s|w|i|v?\
                        string\""
                }
            }
        }
        set args [lrange $args 1 end]
    }

    # Validate required array elements
    foreach var {Indent1 Indent2 Tab MaxVerb FOut FLog LineLen} {
        if {![info exists arr($var)]} {
            error "missing required array element 'arr($var)'!"
        }
    }

    # Validate integer values
    foreach {var val} [list Indent1 $arr(Indent1) Indent2 $arr(Indent2)\
        MaxVerb $arr(MaxVerb) LineLen $arr(LineLen)] {
        if {![string is integer -strict $val]} {
            error "invalid integer value for $var: '$val'"
        }
    }

    # Calculate indentation
    set Prefix ""
    set Val 0
    if {!$Continue} {
        set Val [expr {$arr(Indent1)+$arr(Indent2)+$Indent}]
        if {$Val > 0} {
            set Prefix [string repeat $arr(Tab) $Val]
        }
        set Len [expr {[string length $arr(Tab)]*abs($Val)}]
        set Idx [expr $Len-1]
    }

    # Apply indentation (even to an empty string)
    # Strictly treat strings as strings
    set Msg ""
    if {$Str ne ""} {
        if {$OneLine} {
            set Msg $Str
        } else {
            set Cnt 0
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
                    append Msg \n
                }
                append Msg $Txt
                incr Cnt
            }
        }
    }

    # Output based on verbosity
    if {$Verbosity <= $arr(MaxVerb)} {
        if {$NewLine} {
            puts $Msg
        } else {
            puts -nonewline $Msg
        }
        safeLog $arr(FOut) $Access $Msg $NewLine
    }

    # Output anyway for debugging in case of an error
    safeLog $arr(FLog) $Access $Msg $NewLine
}

# mfjProc::wrapText
    # Designed to wrap text to a specified line length, handling various
    # formatting options such as leading and trailing text, and hanging
    # indentation (one tab size).
# Arguments
    # Text            The input text to be wrapped
    # Lead            Optional leading text to be added to each line
    # Trail           Optional trailing text to be added to each line
    # HangIdt         Optional switch for hanging indentation
# Result: Return a new text with delimited by \n
proc mfjProc::wrapText {Text {Lead ""} {Trail ""} {HangIdt ""}} {
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
    # Designed to parse and expand an index string into a list of index
    # permutations. It supports various features such as range expansion,
    # negative index conversion, and permutation generation.
    # The meaning of special symbols:
        # '/' denotes index permutation
        # ':' denotes all indices from index 1 to index 2
        # ',' separates index 1 and index 2
    # Example: 0/1,3:5 -> (0 1) (0 3) (0 4) (0 5)
    # Negative indices are converted to positive if 'LenLst' is present
# Arguments
    # IdxStr        A string of indices
    # LenLst        A list of the length values of lists if provided
# Result: Return the interpreted list of indices/permutation
proc mfjProc::readIdx {IdxStr {LenLst ""}} {

    # Validate arguments
    set Lst [list]
    foreach Len [split $LenLst /] {
        if {[string is integer -strict $Len] && $Len > 0} {

            # Format the length to remove leading zeroes
            # and convert octal(0#) and hexadecimal(0x#) to decimal
            lappend Lst [format %d $Len]
        } else {
            lappend Lst ""
        }
    }
    set LenLst $Lst

    # Verify, convert or expand if necessary
    # Tracks the total number of permutations
    set Prod 1
    set Idx1 ""
    set Idx2 ""
    set Lst [list]
    set IdxLst [list]
    set IdxLen [lindex $LenLst 0]
    set Len [string length $IdxStr]
    set Idx 0

    # Append "," to the indices string
    # Split the string to its constituent characters
    foreach Char [split $IdxStr, ""] {
        if {$Char eq "/" || $Char eq ":" || $Char eq ","} {
            if {[string is integer -strict $Idx1]} {

                # Align with python convention (-0 is the same as 0!)
                set Idx1 [format %d $Idx1]

                # A negative index is converted to positive if IdxLen positive
                if {$IdxLen > 0} {
                    if {$Idx1 < 0} {
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

                    # Expand ranges
                    if {[llength $Idx2]} {

                        # Raise an error if the product of Idx1 and
                        # Idx2 is negative
                        if {[expr $Idx1*$Idx2] < 0} {
                            error "'$Idx1' and '$Idx2' have different signs!"
                        }
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
                        set Prod [expr $Prod*[llength $Lst]]
                        set Lst [list]

                        # Update IdxLen if positive
                        if {[lindex $LenLst [llength $IdxLst]] > 0} {
                            set IdxLen [lindex $LenLst [llength $IdxLst]]
                        }
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
                        set Prod [expr $Prod*[llength $Lst]]
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

    # Expand to a full list of indices permutation (1 to n dimensions)
    set OutLen 1
    set TmpLst [list]
    foreach SubLst $IdxLst {
        set IdxLen [llength $SubLst]
        set InnLen [expr $Prod/$IdxLen/$OutLen]
        set Lst [list]
        for {set i 0} {$i < $OutLen} {incr i} {
            foreach Idx $SubLst {
                for {set j 0} {$j < $InnLen} {incr j} {
                    lappend Lst $Idx
                }
            }
        }
        set OutLen [expr $IdxLen*$OutLen]
        lappend TmpLst $Lst
    }

    # Rearrange the full list
    set IdxLst [list]
    set IdxLen [llength $TmpLst]
    for {set i 0} {$i < $Prod} {incr i} {
        set Lst [list]
        for {set j 0} {$j < $IdxLen} {incr j} {
            lappend Lst [lindex $TmpLst $j $i]
        }
        lappend IdxLst $Lst
    }
    return $IdxLst
}

# mfjProc::replaceElm
    # Designed to replace elements in a nested list structure based on specified
    # patterns and rules. It handles various cases, including element
    # replacement, range expansion, and permutation generation.
    # A variable may have more than one value to enable a batch simulation. In
    # practice, the difference between values is usually small, varying one or
    # two elements. For values beyond the 1st one, they can be assigned quickly
    # with a shorthand form like:
        # i/j/k,l:n&i/k/o,x:z=val1|val2|....
    # If the pattern is present, copy the content of value i and replace those
    # referenced elements with the assigned element values, respectively. For
    # each referenced element, it may also be supplied with multiple element
    # values. Under such circumstance, the number of values should be increased.
    # Yet, it may cause chaotic references subsequently. So those values are
    # folded temporarily until the end of replacing and reusing elements.
    # Element replacement has two forms, where references must share the same
    # level 0 index and end with '=' and element values are separated by '|':
        # Easy2Read form: {i/j/k,l:n&i/k/o,x:z= ElmVal1 ElmVal2 ...}
        # Compact form: i/j/k,l:n&i/k/o,x:z=ElmVal1|ElmVal1|...
    # Multiple element values can be assigned to one element by three methods:
        # 1. Specify steps after the assigned element value separated by '@':
        # i/j/k=ElmVal@#(l), where '#' refers to the number of steps and 'l' is
        # optional. By default, element values are generated between the inital
        # and assigned values with the same intervals. If an optional letter is
        # appended, these values become evenly-spaced logarithmically.
        # 2. Enumerate element values separated by '~': i/j/k=ElmVal1~ElmVal2...
        # 3. Mix steps and enumeration: i/j/k=ElmVal1@#(l)~ElmVal2...
        # Note: The permutation of multiple elements is affected by
        # ::SimArr(OneChild)
# Arguments
    # VarName     Variable name
    # VarVal      Variable value
# Result: Return the # of folded values and the list after substitution
proc mfjProc::replaceElm {VarName VarVal} {
    set VarMsg "variable '$VarName'"

    # Check the 2nd value (level 1) onwards for element-replacement pattern
    set LvlIdx 1
    set LvlLen 2
    set NewLst [list [lindex $VarVal 0]]
    set FoldLst 0   ;# 0 -> false, no folding values
    foreach OldVal [lrange $VarVal 1 end] {
        set LvlMsg "level '$LvlIdx'"
        set Msg "$LvlMsg of $VarMsg"

        # For the Easy2Read form, remove the enclosing braces if any
        if {[regexp {\{(-?\d+[:,/&])*-?\d+=} $OldVal]} {
            regexp -indices {(-|\d)} $OldVal Loc
            set Idx [lindex $Loc 0]
            set OldVal [string range $Idx end-$Idx]
        }

        # Check the string for element-replacement pattern and treat the list in
        # the Easy2Read form also as a string! Negative indexing is supported by
        # changing regular expression pattern from '\d+' to '-?\d+'
        if {[regexp {^((-?\d+[:,/&])*-?\d+)=(.+)$} $OldVal\
            -> ElmRefStr Tmp ElmValStr]} {

            # Interpret the index string and check validity of each reference.
            # Make sure the level 0 index is equal (same original value) and
            # within range and the rest indices are within range.
            # If any index is negative, convert it to positive
            set IdxLst [list]
            set Idx0 ""
            foreach RefStr [split $ElmRefStr &] {
                foreach Elm [readIdx $RefStr] {

                    # Check the first index
                    if {$Idx0 eq ""} {
                        set Idx0 [lindex $Elm 0]
                        if {$Idx0 < 0} {
                            incr Idx0 $LvlLen
                        }
                        if {$Idx0 < 0 || $Idx0 >= $LvlIdx} {
                            error "level 0 index '$Idx0' of reference\
                                '$ElmRefStr' out of range for $Msg!"
                        }
                        set NewVal [lindex $NewLst $Idx0]
                    } else {
                        set Idx [lindex $Elm 0]
                        if {$Idx < 0} {
                            incr Idx $LvlLen
                        }
                        if {$Idx != $Idx0} {
                            error "invalid reference '$ElmRefStr' for $Msg,\
                                referring to multiple values!"
                        }
                    }

                    # Check the rest indices
                    set Lst [list]
                    set Val $NewVal
                    set Len [llength $Val]
                    set Cnt 1
                    foreach Idx [lrange $Elm 1 end] {
                        if {$Idx < 0} {
                            incr Idx $Len
                        }
                        if {$Idx < 0 || $Idx >= $Len} {
                            error "level $Cnt index '$Idx' of reference\
                                '$ElmRefStr' out of range for $Msg!"
                        }
                        lappend Lst $Idx
                        set Val [lindex $Val $Idx]
                        set Len [llength $Val]
                        incr Cnt
                    }
                    lappend IdxLst $Lst
                }
            }
            set IdxLen [llength $IdxLst]

            # Convert the '|'-seperated elemeent value string to a value list
            # and check whether 'ElmValLst' tallies with 'IdxLst'
            set ElmValLst [lrange [string map {| " "} $ElmValStr] 0 end]
            set ElmValLen [llength $ElmValLst]
            if {$ElmValLen < $IdxLen} {

                # Repeat the last element to complement the list
                set Lst $ElmValLst
                while {$ElmValLen < $IdxLen} {
                    lappend Lst [lindex $ElmValLst end]
                    incr ElmValLen
                }
                set ElmValLst $Lst
            } elseif {$ElmValLen > $IdxLen} {
                vputs -v2 "value '[lrange $ElmValLst $IdxLen end]' excess\
                    for $Msg!"
                set ElmValLst [lrange $ElmValLst 0 [incr IdxLen -1]]
            }

            # Search 'ElmValLst' for '@' and '~'. If found, one element has
            # multiple element values. If more than one elements have multiple
            # element values, the number of permutations is the number of values
            # for any element in case all elements have the same number of
            # values and ::SimArr(OneChild) is the column mode; Otherwise, it is
            # the product of the number of element values:
            #   1. Generate all values including the initial for each element
            #   2. Determine the number of permutations
            #   3. Generate all the permutations of element values
            set Prod 1
            set ValSubLst [list]
            set ValCntLst [list]
            foreach Idx $IdxLst ElmVal $ElmValLst {
                set Cnt 1
                set Begin [lindex $NewVal $Idx]
                set Lst $Begin
                foreach Val [split $ElmVal ~] {
                    if {[regexp {^([^@]+)@(\d+)([^\d]+)?$} $Val\
                        -> End Steps Str]} {
                        if {![string is double -strict $Begin]} {
                            error "'$Begin' of index '$Idx' not a number\
                                for $Msg!"
                        }
                        if {![string is double -strict $End]} {
                            error "'$End' in '$Val' not a number for $Msg!"
                        }
                        if {![string is integer -strict $Steps] || $Steps < 1} {
                            error "'$Steps' not a postive integer for $Msg!"
                        }

                        # Even distribution logarithmically
                        set Sign 1.
                        if {$Str ne ""} {
                            if {[expr $Begin*$End] <= 0} {
                                error "either '$Begin' or '$End' not positive\
                                    for $Msg!"
                            }
                            if {$Begin < 0} {
                                set Sign -1.
                                set Begin [expr $Sign*$Begin]
                                set End [expr $Sign*$End]
                            }
                            for {set i 1} {$i <= $Steps} {incr i} {
                                lappend Lst [expr {$Sign*exp(log($Begin)\
                                    +1.*(log($End)-log($Begin))*$i/$Steps)}]
                            }
                        } else {
                            for {set i 1} {$i <= $Steps} {incr i} {
                                lappend Lst [expr {$Begin\
                                    +1.*($End-$Begin)*$i/$Steps}]
                            }
                        }
                        set Begin [expr $Sign*$End]
                        incr Cnt $Steps
                    } else {
                        lappend Lst $Val
                        set Begin $Val
                        incr Cnt
                    }
                }

                # The number of permutations is updated only when the number
                # of values is higher than one and different from the previous
                # or ::SimArr(OneChild) is !OneChild
                if {$Cnt != [lindex $ValCntLst end]
                    || [string index $::SimArr(OneChild) 0] eq "!"} {
                    set Prod [expr $Prod*$Cnt]
                }
                lappend ValSubLst $Lst
                lappend ValCntLst $Cnt
            }

            # No expanding to the full list yet so the indexing afterwards is ok
            # These permutations are generated similar to the depth-first search
            if {$Prod > 2} {
                set Lst [list]

                # Dividend ÷ Divisor = Quotient, Dividend % Divisor = Remainder
                # Determine the denominator/divisor list
                set DivrLst [list]
                set Quo $Prod
                foreach Cnt $ValCntLst {

                    # Update the quotient only if > 1
                    if {$Quo > 1} {
                        set Quo [expr $Quo/$Cnt]
                    }
                    lappend DivrLst $Quo
                }
                for {set i 1} {$i < $Prod} {incr i} {
                    for {set j 0} {$j < $IdxLen} {incr j} {
                        set Cnt [lindex $ValCntLst $j]
                        set Divr [lindex $DivrLst $j]
                        set Idx [lindex $IdxLst $j]
                        set Val [lindex $ValSubLst $j [expr int($i/$Divr)%$Cnt]]
                        if {[catch {lset NewVal $Idx $Val} Err]} {
                            error "failed to update index '$Idx' for $Msg:\
                                $Err!"
                        }
                    }
                    lappend Lst $NewVal
                }
                lappend NewLst $Lst
            } else {
                foreach Idx $IdxLst Val $ElmValLst {
                    if {[catch {lset NewVal $Idx $Val} Err]} {
                        error "failed to update index '$Idx' for $Msg: $Err!"
                    }
                }
                lappend NewLst $NewVal
            }

            # One level already has a value without folding
            lappend FoldLst [incr Prod -2]
        } else {

            # This level has no element-replacement pattern
            lappend NewLst $OldVal
            lappend FoldLst 0
        }
        incr LvlIdx
        incr LvlLen
    }

    # Returns the fold status and the new list with replaced elements
    return [list $FoldLst $NewLst]
}

# mfjProc::reuseElm
    # To save input, the values entered previously can be reused. Element-reuse
    # feature can be applied anywhere, between values or within a value. This
    # function recursively searches for the element-reuse features
    # (<i,j:k/i,j:k&l,m:n/l,m:n>) and substitutes them with referenced elements.
    # '&' is used to seperate references.
    # Note:
    #   Reference within the current value: Level index is omitted
    #   Reference to one previous value: Level index must be present
# Arguments
    # VarName     Variable name
    # VarVal      Variable value
    # SubLst      Sublist value
    # Lvl         Optional, level sequence (default: "")
    # OldIdx      Optional, trace the index of the SubLst (default: "")
    # InLvl       Optional, restrict reference within a level (default: true)
# Result: Return the updated list.
proc mfjProc::reuseElm {VarName VarVal SubLst {Lvl ""} {OldIdx ""} {InLvl ""}} {

    # Validate arguments
    # All levels should not be negative integers
    if {[string is integer -strict $Lvl] && $Lvl > 0} {

        # Format the level to remove leading zeroes
        # and convert octal(0#) and hexadecimal(0x#) to decimal
        set Lvl [format %d $Lvl]
    } else {
        set Lvl ""
    }

    # All indices should be either positive integer or zero
    foreach Elm $OldIdx {
        if {![regexp {^\d+$} $Elm]} {
            set OldIdx ""
            break
        }
    }
    set InLvl [expr {[string index $InLvl 0] ne "!"}]

    set VarMsg "variable '$VarName'"
    set NewLst [list]
    set LstIdx 0
    foreach Elm $SubLst {
        set NewIdx [concat $OldIdx $LstIdx]
        if {$Lvl ne ""} {
            set Msg "'$Elm' of level '$Lvl' (index $NewIdx) of $VarMsg"
        } else {
            set Msg "'$Elm' of $VarMsg (index $NewIdx)"
        }

        # Replace each element-reuse feature
        # Negative indexing is supported with the pattern '-?\d+'
        while {[regexp {<((-?\d+[:,/&])*-?\d+)>} $Elm -> ElmRefStr]} {
            if {[llength $Elm] > 1 || [regexp {^\{.+\}$} $Elm]} {

                # Visit all the elements by regression
                # The function name is adaptive: '[lindex [info level 0] 0]'
                set Elm [[lindex [info level 0] 0] $VarName $VarVal\
                    $Elm $Lvl $NewIdx]
            } else {
                set NewElm [list]
                set StrLst [split $ElmRefStr &]
                foreach Str $StrLst {
                    set IdxLst [readIdx $Str]
                    foreach Lst $IdxLst {
                        set Val $VarVal

                        # Start from the outmost level
                        set Ref $NewIdx
                        set End [lindex $Ref 0]
                        set Len [expr 1+$End]

                        # #: forwards from the first index
                        # -#: backwards from the current index (-1)
                        foreach Idx $Lst {
                            set Idx1 $Idx
                            if {$Idx < 0} {
                                incr Idx1 $Len
                            }
                            if {$Idx1 < 0 || $Idx1 > $End} {
                                error "index '$Idx' out of range\
                                    '$End' for element $Msg!"
                            }

                            # Update value to the element
                            set Val [lindex $Val $Idx1]
                            if {$Ref ne "" && $Idx1 == $End} {

                                # Next inner level of the current index
                                set Ref [lrange $Ref 1 end]
                                set End [lindex $Ref 0]
                                set Len [expr 1+$End]
                            } else {

                                # Not the current index anymore so discard 'Ref'
                                set Ref ""
                                set Len [llength $Val]
                                set End [expr $Len-1]
                            }
                        }

                        # Detect and raise a circular reference error
                        set MatLst [regexp -inline -all {<(-?\d+[:,/&])*-?\d+>}\
                            $Val]
                        foreach RefStr $MatLst {
                            if {[string index $RefStr 0] ne "<"} continue
                            set RefStr [string range $RefStr 1 end-1]
                            foreach RefLst [split $RefStr &] {
                                foreach RefIdx [readIdx $RefLst] {
                                    if {$RefIdx eq $Lst} {
                                        error "circular reference: '<$ElmRefStr>'\
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

                # Substitute the first pattern in the element
                regsub {<(-?\d+[:,/&])*-?\d+>} $Elm $NewElm Elm

                # Need to break loop after activating reuse-only feature
                # in level 1+
                if {!$InLvl && $Lvl} break
            }
        }

        # Need to assign value after activating reuse-only feature
        # in level 1+
        if {!$InLvl && $Lvl} {
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
        if {[catch {lset VarVal $IdxLst $ElmVal} Err]} {
            error "failed to update index '$IdxLst' for variable '$VarName':\
                $Err!"
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
#     Intf          An interface string, e.g. px1_y1_z1//x2_y2_z2
# Result: Return the region index or raise an error
proc mfjProc::getRegIdx {RegDim Intf} {

    # Validate argument
    if {regexp {^p[^/]+//[^/]+$} $Intf} {
        set Lst [string map {p \{ _ " " // "\} \{"} $Intf]\}
    } else {
        error "invalid argument '$Intf' for getRegIdx!"
    }
    set Dim [llength [lindex $RegDim 0 1]]
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
        set Alias [expr {[string index $Alias 0] ne "!"}]
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
            return [expr {exp(log($Y1)+1.*(log($Y2)-log($Y1))\
                *($X-$X1)/($X2-$X1))}]
        }
    } else {
        if {$LinY} {
            return [expr {$Y1+1.*($Y2-$Y1)*(log($X)-log($X1))\
                /(log($X2)-log($X1))}]
        } else {
            return [expr {exp(log($Y1)+1.*(log($Y2)-log($Y1))\
                *(log($X)-log($X1))/(log($X2)-log($X1)))}]
        }
    }
}

# mfjProc::str2List
    # Properly convert a string to a list especially a nested one using the
    # recursive mechanism. It trims excess spaces due to multiple lines and
    # user input.
# Arguments:
    # StrList     Original string list entered by a user
    # VarInfo     Optional variable info, default null string
    # Level       Optional, default list level starts from 0
# Result: Return the formatted list
proc mfjProc::str2List {StrList {VarInfo ""} {Level 0}} {

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
            lappend FmtLst [[lindex [info level 0] 0] $SubLst\
                $VarInfo [expr $Level+1]]
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
    set Dflt [expr {[string index $Dflt 0] ne "!"}]
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
        if {[regexp {^([^<]+)(<\S+>)?$} $Elm -> Ptn1 Ptn2]} {
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
    # interfaces, positions, etc. It is necessary to split the values into
    # multiple sublists based on the predefined group ID
# Arguments:
    # VarName     Variable name
    # VarVal      Variable value
    # GrpID       Permutations of 'm', 'p', 'pp', 'r', 'rr'
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
            append Txt " 'Precision' or a ref to a varying variable"
        } else {
            set Txt "'Precision' or a ref to a varying variable"
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
            append Txt " or position or box"
        } else {
            set Txt "a position or box"
        }
    } elseif {[regexp {pp} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or box"
        } else {
            set Txt "a box"
        }
    } elseif {[regexp {p} $GStr]} {
        if {[string length $Txt]} {
            append Txt " or position"
        } else {
            set Txt "a position"
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
    set DimLst [list]
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
        set RegLen [llength $RegInfo]

        # Extract the boundaries of the simulation domain (including
        # dummy gaseous layers)
        set XLst [lindex $::SimArr(RegX) $::SimArr(RegLvl)]
        set YLst [lindex $::SimArr(RegY) $::SimArr(RegLvl)]
        set ZLst [lindex $::SimArr(RegZ) $::SimArr(RegLvl)]
        set DimLst [list $XLst $YLst $ZLst]
    }

    # Set regular exppression strings for a material or regions
    # Use {} here to preserve a string as it is
    set RE_m {[\w.]+}
    set RE_r {(-?\d+[:,])*-?\d+}
    set RE_v {(-?\d+[:,])*-?\d+}

    # RE for integers and real numbers (including scientific notation)
    set RE_n {[+-]?(\.\d+|\d+(\.\d*)?)([eE][+-]?\d+)?}

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
                            if {[string index $::SimArr(OneChild) 0] ne "!"
                                && [llength $::SimArr(ConLen)] == $LvlLen} {
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
                if {[regexp {^[pP]([^_]*\d+[^_]*_){1,2}[^_]*\d+[^_]*$} $Val]
                    || ![catch {evalNum $Val $DimLst}]} {
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
                            if {$Idx == -1} {
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
            } elseif {$GID eq "pp" || $GID eq "p"} {
                set NewVal [verifyPos $Val $GStr $DimLst $VarMsg]
                if {[llength $NewVal]} {
                    set Bool true
                    set Val $NewVal
                } else {
                    set Bool false
                }
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
                        if {[catch {set IdxLst [readIdx $VStr $VarLen]} Err]} {
                            error "failed to eval '$Val': $Err!"
                        }
                    } else {

                        # Check against multiple-level 'VarVary'
                        if {[llength $VarLen] == $LvlLen
                            && [string index $::SimArr(OneChild) 0] ne "!"} {
                            if {[lindex $VarLen $LvlIdx] == 0} {
                                error "no varying variable in level '$LvlIdx\
                                    of 'VarVary'!"
                            }
                            if {[catch {set IdxLst [readIdx $VStr\
                                [lindex $VarLen $LvlIdx]]} Err]} {
                                error "failed to eval '$Val': $Err!"
                            }
                        } else {
                            set Idx 0
                            foreach Elm $VarLen {
                                if {$Elm == 0} {
                                    error "no varying variable in level '$Idx'\
                                        of 'VarVary'!"
                                }
                                if {[catch {set IdxLst [readIdx $VStr $Elm]}\
                                    Err]} {
                                    error "failed to eval '$Val': $Err!"
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
                } elseif {[string equal -nocase $Val Precision]} {
                    set Bool true
                    set Val Precision
                }
            }

            # Skip the rest further processing if not a group ID
            if {!$Bool} {
                continue
            }

            # Verify region and interface. Split them if necessary
            # Break regions/interfaces to each individual region/interface
            if {[regexp -nocase ^r($RE_r|($RE_r/$RE_r&)*$RE_r/$RE_r)$ $Val]} {
                set NewVal [list]
                foreach Str [split [string range $Val 1 end] &] {

                    # Read an index string and verify region indices
                    if {[catch {set IdxLst [readIdx $Str $RegLen]} Err]} {
                        error "failed to eval 'r$Str': $Err!"
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

# mfjProc::verifyPos
    # Verify a position string: p###_###_###, px#_y#_z#, px#+5_y#_###,
    # p###_###_###//x#_y#_z#, p###_###_###&x#_y#_z#&x#+5_y#_###
    # Evaluate coordinates and make sure they are within the simulation
    # domain. Sort the coordinates if 'GStr' is 'pp'.
# Arguments:
    # PosStr        A string of positions for evaluation
    # GStr          Total grammar string: 'p', 'pp', 'pprr', 'ppprrr', and ...
    # DimLst        Coordinates at X, Y Z axes
    # Context       A context message
# Result: Return the verified/evaluated position string list
proc mfjProc::verifyPos {PosStr GStr DimLst Context} {

    # Create an array for intepreting x#, y#, and z#
    set DimLen 0
    set Arr(xLst) [lindex $DimLst 0]
    set Arr(xLen) [llength $Arr(xLst)]
    incr DimLen [expr $Arr(xLen) > 0]
    set Arr(yLst) [lindex $DimLst 1]
    set Arr(yLen) [llength $Arr(yLst)]
    incr DimLen [expr $Arr(yLen) > 0]
    set Arr(zLst) [lindex $DimLst 2]
    set Arr(zLen) [llength $Arr(zLst)]
    incr DimLen [expr $Arr(zLen) > 0]
    set NewStrLst [list]

    # Tcl functions are lower cases so change the string to lower cases
    set PosStr [string tolower $PosStr]

    # A position string should start with 'p', otherwise not a position string
    if {[string index $PosStr 0] ne "p"} {
        return $NewStrLst
    }

    set StrLst [split [string range $PosStr 1 end] &]
    set Bool false
    set PosLen 0
    set PPLst [list]
    foreach Str $StrLst {
        if {[regexp {^([^_]+_){0,2}[^_]+//([^_]+_){0,2}[^_]+$} $Str]} {

            # Position list length is 2
            if {$PosLen == 1} {
                error "no mixed use of positions and regions in '$PosStr'\
                    of $Context!"
            }
            set PosLen 2
            if {!$Bool} {
                set Bool true
            }
            set Lst \{[string map {_ " " // "\} \{"} $Str]\}
            if {[llength [lindex $Lst 0]] != [llength [lindex $Lst 1]]} {
                error "two positions should have the same number of coordinates\
                    in element '$Lst' of $Context!"
            }
            lappend PPLst $Lst
        } elseif {[regexp {^([^_]*\d+[^_]*_){0,2}[^_]*\d+[^_]*$} $Str]} {

            # Position list length is 1
            if {$PosLen == 2} {
                error "no mixed use of positions and regions in '$PosStr'\
                    of $Context!"
            }
            set PosLen 1
            lappend PPLst [list [split $Str _]]
        } else {
            if {$Bool} {
                error "invalid position string for '$Str' of $Context!"
            } else {
                return $NewStrLst
            }
        }
    }

    # Verify each coordinate within each position
    foreach PosLst $PPLst {
        set Cnt 0
        set NewPosLst [list]
        foreach Pos $PosLst {
            if {$DimLen == 0} {

                # Update 'DimLen' if it is not set
                set DimLen [llength $Pos]
            } else {
                if {[llength $Pos] != $DimLen} {

                    # For 'p' test, skip a string having only one dimension.
                    # If the previous string is not a position, it is likely to
                    # an unrelevant string
                    if {$PosLen == 1 && [llength $Pos] == 1 && !$Bool} {
                        return $NewStrLst
                    } else {
                        error "element '$Pos' of $Context should\
                            have the same number of coordinates as\
                            variable 'RegGen'!"
                    }
                }
            }

            # 1D interface with '+' or '-'
            if {$DimLen == 1 && $Cnt == 1 && [regexp {^o?pprr} $GStr]} {
                if {$Pos eq "+" || $Pos eq "-"} {
                    lappend NewPosLst $Pos
                    incr Cnt
                    continue
                } else {
                    error "element '$PosLst' of $Context should\
                        be an interface!"
                }
            }

            # Verify each coordinate
            set NewPos [list]
            foreach Elm $Pos Axis {x y z} {
                if {$Elm eq ""} continue

                # If not number, evaluate the expression
                if {![string is double $Elm]} {

                    # Replace x#, y#, z# if present
                    while {[regexp {([xyz])(-?\d+)} $Elm -> Coord Idx]} {
                        set Lst $Arr(${Coord}Lst)
                        set Len $Arr(${Coord}Len)

                        # Deal with negative index
                        set OldIdx $Idx
                        if {$Idx < 0} {
                            incr Idx $Len
                        }
                        if {$Idx < 0 || $Idx >= $Len} {
                            error "index '${Coord}$OldIdx' out of range '$Len'\
                                in $Context!"
                        }

                        # Replace all occurances
                        regsub -all "${Coord}$OldIdx" $Elm [lindex $Lst $Idx]\
                            Elm
                    }

                    # Evaluate the expression
                    if {[catch {set Elm [expr 1.*$Elm]} Err]} {
                        error "failed to eval '$Elm' in $Context: $Err!"
                    }
                }

                if {![string is double $Elm]} {
                    error "coordinate '$Elm' not a number in $Context!"
                }

                # Each coordinate must be within the simulation domain
                if {$Arr(xLen) > 0} {
                    set Min [lindex $Arr(${Axis}Lst) 0]
                    set Max [lindex $Arr(${Axis}Lst) end]
                    if {$Elm < $Min || $Elm > $Max} {
                        error "$Axis coordinate '$Elm' of $Context beyond\
                            simulation domain($Min $Max)!"
                    }
                }

                # Format each number to the proper form such as removing
                # trailing zeroes and decimal point
                lappend NewPos [format %.12g $Elm]
                set Bool true
            }
            lappend NewPosLst $NewPos
            incr Cnt
        }
        if {$PosLen == 1} {
            lappend NewStrLst p[join [lindex $NewPosLst 0] _]
            continue
        }
        lappend NewStrLst\
            p[join [lindex $NewPosLst 0] _]//[join [lindex $NewPosLst 1] _]

        # Sort axis values in 'pp' ascendingly
        if {$PosLen == 2 && [llength [lindex $NewPosLst 0]] > 1} {
            set Idx 0
            set Cnt 0
            foreach Elm1 [lindex $NewPosLst 0] Elm2 [lindex $NewPosLst 1] {
                incr Cnt [expr $Elm1 == $Elm2]

                # Sort coordinates properly
                set Lst [lsort -real [list $Elm1 $Elm2]]
                lset NewPosLst 0 $Idx [lindex $Lst 0]
                lset NewPosLst 1 $Idx [lindex $Lst 1]
                incr Idx
            }

            # 'pp' should be two positions
            if {$Cnt == $DimLen} {
                error "element '$NewPosLst' of $Context should\
                    be two positions!"
            }

            # 'pp' for 'pprr' is perpendicular to one axis
            # Otherwise, it should be a region instead
            if {[regexp {^o?pprr} $GStr]} {
                if {$Cnt != 1} {
                    error "element '$NewPosLst' of $Context should\
                        be an interface!"
                }
            } else {
                if {$Cnt != 0} {
                    error "element '$NewPosLst' of $Context should be a region!"
                }

                # 'pp' for a region should be updated with sorted coordinates
                lset NewStrLst end p[join [lindex $NewPosLst 0]\
                    _]//[join [lindex $NewPosLst 1] _]
            }
        }
    }

    # Keep the last found duplicate
    return [lsort -unique $NewStrLst]
}

# mfjProc::evalNum
    # Evaluate a number string: ###, x#, x#+5
# Arguments:
    # NumStr        A string of number for evaluation
    # DimLst        Coordinates at X, Y Z axes
    # Context       A context message
# Result: Return the evaluated number
proc mfjProc::evalNum {NumStr {DimLst ""} {Context ""}} {

    # Create an array for intepreting x#, y#, and z#
    set DimLen 0
    if {[llength $DimLst]} {
        set Arr(xLst) [lindex $DimLst 0]
        set Arr(xLen) [llength $Arr(xLst)]
        incr DimLen [expr $Arr(xLen) > 0]
        set Arr(yLst) [lindex $DimLst 1]
        set Arr(yLen) [llength $Arr(yLst)]
        incr DimLen [expr $Arr(yLen) > 0]
        set Arr(zLst) [lindex $DimLst 2]
        set Arr(zLen) [llength $Arr(zLst)]
        incr DimLen [expr $Arr(zLen) > 0]
    }

    # Tcl functions are lower cases so change the string to lower cases
    set NumStr [string tolower $NumStr]

    # Recursively rplace x#, y#, z# if present
    while {[regexp {([xyz])(-?\d+)} $NumStr -> Coord Idx]} {

        # Avoid invalid coordinate
        if {$Coord eq "x" && $DimLen < 1} {
            error "no x coordinate in 'RegGen'!"
        }
        if {$Coord eq "y" && $DimLen < 2} {
            error "no y coordinate for 1D!"
        }
        if {$Coord eq "z" && $DimLen < 3} {
            error "no z coordinate for 1D/2D!"
        }
        set CoordList $Arr(${Coord}Lst)
        set CoordLen $Arr(${Coord}Len)

        # Deal with negative index
        set OldIdx $Idx
        if {$Idx < 0} {
            incr Idx $CoordLen
        }

        # Index validity check
        if {$Idx < 0 || $Idx >= $CoordLen} {
            error "index '${Coord}$OldIdx' out of range '$CoordLen' in $Context"
        }

        # Replace all occurances
        regsub -all "${Coord}$OldIdx" $NumStr [lindex $CoordList $Idx] NumStr
    }

    # Evaluate the expression
    if {[catch {set Res [expr 1.*$NumStr]} Err]} {
        error "failed to eval '$NumStr' in $Context: $Err"
    }

    # Return the value, can't put in catch
    return $Res
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
#     Pos1          Position 1 string/list or the interface string/list
#     Pos2          Opposite position 2 string/list
# Result: Return the normal 3D vector.
proc mfjProc::intfVn {Pos1 {Pos2 ""}} {
    set Vn [list]

    # Validate arguments (an interface or two positions). Valide arguments:
    #   0_0//1_0 or {{0 0} {1 0}} or {0 0} {1 0}
    if {$Pos2 eq ""} {
        if {[regexp {^[^/]+//[^/]+$} $Pos1]} {
            set Pos1 \{[string map {_ " " // "\} \{"} $Pos1]\}
        } elseif {[llength $Pos1] == 1} {
            error "invalid argument '$Pos1' for intfVn!"
        }
        set Pos2 [lindex $Pos1 1]
        set Pos1 [lindex $Pos1 0]
    }
    set Intf [join $Pos1 _]//[join $Pos2 _]
    if {[llength $Pos1] != [llength $Pos2]} {
        error "'$Intf' should have the same number of coordinates!"
    }

    # Determine Vn
    if {[llength $Pos1] == 1} {
        if {[string is double -strict $Pos1]} {
            if {$Pos2 eq "-"} {
                set Vn [list -1 0 0]
            } elseif {$Pos2 eq "+"} {
                set Vn [list 1 0 0]
            } else {
                error "unknown interface '$Pos1 $Pos2' for 1D!"
            }
        } else {
            error "unknown interface '$Pos1 $Pos2' for 1D!"
        }
    } elseif {[llength $Pos1] == 2} {
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
    } elseif {[llength $Pos1] == 3} {
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
                set Val [expr 1.*([lindex $Pos1 $Idx2]-[lindex $Pos2 $Idx2])\
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
        error "'$Intf' not a valid interface!"
    }
}

# mfjProc::overlap
#     Check overlap between an interface field and a region
# Arguments
#     Intf          An interface string/list normal to one axis
#     Dep           Field depth along the normal axis
#     Reg           An existing region
# Result: Return the depth of overlap. -1 -> no overlap.
proc mfjProc::overlap {Intf Dep Reg} {

    # Validate arguments
    if {![string is double -strict $Dep] || $Dep <= 0} {
        error "depth '$Dep' invalid!"
    }

    # Valide arguments: 0_0//1_0 or {{0 0} {1 0}}
    if {[regexp {^[^/]+//[^/]+$} $Intf]} {
        set Pos1 \{[string map {_ " " // "\} \{"} $Intf]\}
        set Pos2 [lindex $Pos1 1]
        set Pos1 [lindex $Pos1 0]
    } elseif {[llength $Intf] > 1} {
        set Pos1 [lindex $Intf 0]
        set Pos2 [lindex $Intf 1]
        set Intf [join $Pos1 _]//[join $Pos2 _]
    } else {
        error "invalid argument '$Intf' for overlap!"
    }

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
            lappend Pos2 [expr $Elm1+1.*$Elm2*$Dep]
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
        lappend Dep [expr 1.*$V*($MinMax-$MaxMin)]
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
# Result: Return the interface list between two block regions
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
proc mfjProc::calMaxVarLen {VarName {Suffix ""}} {
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
    # Build a SWB node tree according to the OneChild or full permutation mode
    # Key nodes are a list of the last nodes of all tools
# Arguments:
    # VarName             Variable names
    # VarVal              Variable values
    # STIdxLst            Sentaurus tool Index list
    # OneChild            Optional, OneChild (default) or full permutation
    # NodeTree            Optional, returns node tree (default) or key nodes
# Result: Return the node tree
proc mfjProc::buildTree {VarName VarVal STIdxLst {OneChild ""} {NodeTree ""}} {

    # Validate arguments
    foreach Elm [list OneChild NodeTree] {

        # Make an alias of 'OneChild' and 'NodeTree'
        upvar 0 $Elm Alias
        set Alias [expr {[string index $Alias 0] ne "!"}]
    }

    vputs -v2 "Building a SWB node list..."
    set Scenario default
    set STIdx 0
    set STLen [llength $STIdxLst]
    set VarIdx 0
    set Prod 1
    set LastLen 0
    set Seq 0
    set KeyNode [list]
    set SWBNode [list]
    set SWBTree [list]
    foreach Var $VarName Val $VarVal {

        # In case no variables between tools
        while {$STIdx < $STLen && [lindex $STIdxLst $STIdx] == $VarIdx} {
            set Tmp [list]
            for {set i 0} {$i < $Prod} {incr i} {
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
            if {$ValLen != $LastLen || !$OneChild} {
                set Prod [expr $Prod*$ValLen]
            }
            set LastLen $ValLen
        }
        set Tmp [list]
        for {set i 0} {$i < $Prod} {incr i} {
            lappend Tmp [incr Seq]
        }
        lappend SWBNode [list $Tmp $Var $Val]
        incr VarIdx
    }

    # In case no variables or the rest tools have no variables
    while {$STIdx < $STLen && [lindex $STIdxLst $STIdx] == $VarIdx} {
        set Tmp [list]
        for {set i 0} {$i < $Prod} {incr i} {
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
    for {set i 0} {$i < $Prod} {incr i} {
        for {set j 0} {$j <= $End} {incr j} {
            set k1 [expr $Prod/[llength [lindex $SWBNode $j 0]]]
            if {$i % $k1 == 0} {
                set n1 $j
                set n2 [lindex $SWBNode $j 0 [expr $i/$k1]]
                if {$i == 0 && $j == 0} {
                    set n3 0
                }
                if {$j > 0} {
                    incr j -1
                    set k2 [expr $Prod/[llength [lindex $SWBNode $j 0]]]
                    set n3 [lindex $SWBNode $j 0 [expr int($i/$k2)]]
                    incr j
                }
                set Len [llength [lindex $SWBNode $j end]]
                if {$Len} {
                    set Val [lindex $SWBNode $j end [expr $i/$k1%$Len]]
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
                $SubLst [expr $Level+1]]
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
        if {[catch {set Ouf [open $FSave w]} Err]} {
            error "failed to open '$FSave': $Err!"
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
    set Remove [expr {[string index $Remove 0] ne "!"}]

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
