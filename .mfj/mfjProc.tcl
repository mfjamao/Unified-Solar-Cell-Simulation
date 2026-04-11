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
#     Safely logs a message to a file, automatically creating directories and
#     handling symbolic links.
# Purpose
# Provides robust file logging functionality that:
#     Automatically creates parent directories if they don't exist
#     Handles symbolic links appropriately
#     Ensures file write operations are safe and reliab
# Arguments
#     Argument  Type    Description
#     FName     String  Path to the log file
#     Access    String  File access mode: 'w' (write/overwrite) or 'a' (append)
#     Msg       String  The message content to log
#     NewLine   Boolean Flag indicating whether to append a newline character
# Return Value
#     Success: Returns 1
#     Failure: Triggers an error (function does not return)

# Processing Flow
# 1. Argument Validation
#     Check if filename (FName) is empty
#     If empty: Return 1 (success) immediately
#     Convert access mode to lowercase
#     Verify access mode is either "w" (write) or "a" (append)
#     If invalid: Throw error "invalid access mode: must be 'w' or 'a'"
# 2. Directory Preparation
#     Check if file already exists
#     If file does not exist:
#         Extract directory path from filename
#         Check if directory exists
#         If directory does not exist: Create parent directories recursively
#             using file mkdir
#     If file exists:
#         Check if running on Unix platform
#         If on Unix: Verify file is not a symbolic link
#         If symbolic link detected: "a symbolic link not allowed: '$FName'"
# 3. Backup Creation (Write Mode Only)
#     If access mode is "w":
#         Set backup filename to ${FName}.backup
#         Check if original file exists
#         If original file exists: Create backup copy using file copy -force
# 4. File Opening
#     Attempt to open file with specified access mode
#     Use catch to handle potential errors
#     If open fails: Throw error with details "failed to open '$FName': $Err"
# 5. Message Writing
#     Check NewLine flag:
#         If true: Write message with newline
#         If false: Write message without newline
# 6. Cleanup and Return
#     Close the file handle
#     Return 1 indicating success
proc mfjProc::safeLog {FName Access Msg
    {NewLine true}} {

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
#     Enhanced output formatting procedure that extends standard puts with
#     advanced controls for verbosity, indentation, and file logging.
# Purpose
# Provides versatile output formatting with:
#     Verbosity-based terminal filtering
#     Configurable indentation levels
#     Automatic line wrapping (80-character limit)
#     Simultaneous file logging for diagnostics
#     Support for hanging indents and formatting preservation
# Features
# 1. Verbosity Control
#     Terminal output is filtered based on a global verbosity level
#     Messages with verbosity higher than the global setting are suppressed
#     from terminal
#     All messages are still written to log files regardless of verbosity
# 2. Indentation Management
#     Default behavior includes proper indentation
#     Indentation controlled by:
#         Tab setting
#         Indent1 and Indent2 from array arr
#         Variable Indent
#     Can be disabled with -c flag
# 3. Line Formatting
#     Default: Automatic line splitting at 80 characters for readability
#     Hanging Indents: Subsequent lines receive additional tab indentation
#     Same Indent: -s flag enforces identical indentation for all lines
#     Raw Output: -o flag suppresses all line splitting, outputting text
#     exactly as provided
# 4. File Logging
#     Terminal output is copied to FOut for reference
#     All messages (regardless of verbosity) are written to FLog for
#     diagnostics
#     Default behavior appends to files; -w flag enables write/overwrite
#     mode
# Arguments
#     Flag  Description
#     -c    Write at current position (no indentation)
#     -n    Suppress newline at end of output
#     -o    Output raw string without line splitting
#     -s    Use same indentation for all lines (no hanging indent)
#     -w    Write/overwrite files instead of appending
#     -i#   Specify number of tabs for indentation
#     -v#   Set verbosity level (compared against global setting)
# Return Value
#     No return value. Output is written to terminal and/or files as
#     configured.

# Processing Flow
# 1. Argument Parsing and Separation
#     Extract the last argument as the message string (Str)
#     Remove the last argument from args, leaving only options
#     Initialize default settings:
#         Access: "a" (append mode for file logging)
#         Continue: false (disable continuous output without indentation)
#         NewLine: true (add newline after message)
#         OneLine: false (disable raw output without line wrapping)
#         SameInt: false (disable same indentation for all lines)
#         Indent: 0 (no additional indentation tabs)
#         Verbosity: 1 (default verbosity level)
# 2. Option Processing Loop
#     Iterate through remaining arguments and process each option:
#         Option    Effect
#         -c        Set Continue = true (ignore indentation)
#         -n        Set NewLine = false (suppress newline)
#         -o        Set OneLine = true (output raw string, no line splitting)
#         -s        Set SameInt = true (use same indentation for all lines)
#         -w        Set Access = "w" (write/overwrite mode for files)
#         -i#       Set Indent to numeric value (additional tabs)
#         -v#       Set Verbosity to numeric value
#         --        Stop option processing
#         -*        Unknown option → throw error
#         other     Invalid argument format → throw error
#     After processing each option, remove it from args list.
# 3. Validation
#     Verify required array elements exist in arr:
#         Indent1, Indent2, Tab, MaxVerb, FOut, FLog, LineLen
#         Missing any → throw error
#         Validate that Indent1, Indent2, MaxVerb, LineLen are integers
#         Invalid → throw error
# 4. Indentation Calculation
#     If Continue is false:
#         Calculate total indentation value: Val = arr(Indent1) + arr(Indent2)
#         + Indent
#     If Val > 0: Create Prefix by repeating arr(Tab) Val times
#     Calculate prefix length: Len = string length of arr(Tab) * abs(Val)
#     Set index: Idx = Len - 1
# 5. Message Formatting
#     Skip if Str is empty:
#     Case A: Raw Output (OneLine = true)
#         Use Str as-is without any processing
#     Case B: Formatted Output (OneLine = false)
#         Split Str by newlines
#         Process each line based on indentation:
#             Condition Processing
#             Val >= 0 (indent)
#                 - If SameInt = true: wrapText with same indentation for all
#                     lines
#                 - If SameInt = false: wrapText with hanging indent
#                     (additional tab for wrapped lines)
#             Val < 0 (outdent)
#                 - If line starts with non-space at position ≤ Idx: Trim left,
#                     then wrap
#                 - If line starts with spaces: Remove first Len characters,
#                     preserve leading spaces, then wrap
#         Join processed lines with newlines
# 6. Output Based on Verbosity
#     Compare Verbosity against arr(MaxVerb) (global verbosity level)
#     If Verbosity ≤ arr(MaxVerb):
#         Terminal output:
#             NewLine = true: puts $Msg
#             NewLine = false: puts -nonewline $Msg
#         Copy to FOut file using safeLog with current output settings
#     Regardless of verbosity (for debugging):
#         Always copy to FLog file using safeLog with current ouput settings
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
#     Wraps text to a specified line length with support for leading/trailing
#     text and hanging indentation.
# Purpose
#     Formats text by breaking long lines at word boundaries while preserving
#     paragraph structure. Provides flexible options for adding prefixes,
#     suffixes, and special indentation for wrapped lines.
# Arguments
#     Argument  Type    Description                         Default
#     Text      String  The input text to be wrapped        Required
#     Lead      String  Optional leading text               "" (empty)
#     Trail     String  Optional trailing text              "" (empty)
#     HangIdt   String  Optional hanging indentation        "" (empty)
#     Note: Setting HangIdt to "!" disables hanging indentation (no tab added
#     to wrapped lines)
# Return Value
#     Returns the wrapped text as a string with lines delimited by \n.

# Processing Flow
# 1. Initial Validation and Setup
#     Check HangIdt parameter:
#         If first character is "!": Disable hanging indentation (Tab = "")
#         Otherwise: Use arr(Tab) for hanging indentation
#     Calculate lengths:
#         LeadLen: Length of leading text
#         TrailLen: Length of trailing text
#         TabLen: Length of tab string (for hanging indent)
#     Initialize NewText as empty string
#     Set paragraph counter ParaCnt = 0
# 2. Paragraph Processing Loop
#     Split input Text by newlines and process each paragraph independently:
#     For each paragraph (Para):
#         Calculate maximum line length: MaxLen
#         Set maximum index: MaxIdx = MaxLen - 1
#         Get paragraph length: ParaLen = string length $Para
#         Initialize line counter LineCnt = 0 and NewPara = ""
# 3. Line Wrapping Loop (while paragraph has content)
#     Process the paragraph line by line:
#     Step A: Check if paragraph fits within margin
#         If ParaLen ≤ MaxLen:
#         Use entire paragraph as current line
#         Clear Para (all content processed)
#     Step B: Paragraph exceeds margin - find split point
#         Take the character at MaxIdx as potential line: Line
#         Case 1: Character at position MaxLen is a space
#             Split cleanly at space
#             Set Para to remaining text starting after the space
#         Case 2: No space at position MaxLen
#             Search backwards from MaxLen to find the last space within margin
#             If space found: Split at that space position
#             If no space found within margin:
#                 Set "LongStr = true" flag
#                 Try extended search up to arr(LineLen)
#                 If still no space found:
#                     Finding next space beyond margin
#                     Splitting at that position
#                     Or if no spaces exist, split at maximum length
# 4. Line Assembly and Formatting
#     First line of paragraph (LineCnt = 0):
#         If LongStr is true: NewPara = $Line (no Lead/Trail)
#         Otherwise: NewPara = $Lead$Line$Trail
#         Adjust for hanging indentation: MaxLen -= TabLen, update MaxIdx
#     Subsequent lines (LineCnt > 0):
#         Insert newline before each line
#         If LongStr is true: Append just the line
#         Otherwise: Append with hanging indentation: \n$Lead$Tab$Line$Trail
# 5. Continue Loop
#     Update ParaLen with remaining text length
#     Increment line counter LineCnt
#     Repeat until all text in paragraph is processed
# 6. Paragraph Assembly
#     After completing a paragraph:
#         If first paragraph (ParaCnt = 0): Set NewText = $NewPara
#         Otherwise: Append with newline: NewText += \n$NewPara
#     Increment paragraph counter ParaCnt
#     Process next paragraph
# 7. Return Result
#     Return the fully wrapped and formatted text as NewText
proc mfjProc::wrapText {Text
    {Lead ""} {Trail ""} {HangIdt ""}} {
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
    set ParaCnt 0
    foreach Para [split $Text \n] {

        # Substitute multiple spaces with one space
        # set Para [regsub -all {\s+} $Para " "]
        set MaxLen [expr $arr(LineLen)-$LeadLen-$TrailLen]
        set MaxIdx $MaxLen
        incr MaxIdx -1

        # Only treat each paragraph as a string
        # It may cause issues if treated as a list
        set ParaLen [string length $Para]
        set LineCnt 0
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
            if {$LineCnt} {

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
            incr LineCnt
        }
        if {$ParaCnt} {

            # Insert a newline between each paragraph
            append NewText \n $NewPara
        } else {

            # Update the first paragraph
            set NewText $NewPara
        }
        incr ParaCnt
    }
    return $NewText
}

# mfjProc::readIdx
#     Parses and expands an index string into a list of index permutations,
#     supporting range expansion, negative index conversion, and permutation
#     generation.
# Purpose
#     Converts a compact index notation into explicit index permutations for
#     nested list access, with flexible range specifications and automatic
#     handling of negative indices.
# Special Symbols
#     Symbol    Meaning
#       /       Separates indices for different nested list levels
#       ,       Separates multiple index specifications within the same level
#       :       First occurrence: Defines a range from start index to end index
#       :       Second occurrence: Specifies the step size for range traversal
#       @       Specifies steps for range traversal
#     Syntax Examples
#     Basic syntax: level0/level1,rangeStart:rangeEnd:step
#     0/1,3:7:2 expands to: (0 1) (0 3) (0 5) (0 7)
# Arguments
#     Argument  Type    Description
#     IdxStr    String  Index string to parse and expand (e.g., "0/1,3:7:2")
#     LenLst    List    (Optional) List of length values for each nested
#                       level, separated by /. Used to convert negative
#                       indices to positive equivalents and validate range
#                       bounds.
# Return Value
#     Returns a list of index permutations, where each permutation is a list
#     of indices for each nested level.

# Processing Flow
# 1. Argument Validation
#     Parses LenLst by splitting on /
#     Validates each length as a positive integer
#     Formats numbers to remove leading zeros and convert octal/hex to
#         decimal
#     Empty values are preserved for unspecified levels
# 2. Index String Parsing
#     Appends trailing , to ensure last index is processed
#     Iterates through each character, building index strings
#     Validates characters (must be integers or special symbols : / ,)
#     Validates index strings as integers
# 3. Negative Index Conversion (when LenLst provided)
#     Converts negative indices to positive by adding the level length
#     Validates converted index is within range [0, length-1]
#     Triggers error if index remains out of bounds
# 4. Range Processing
#     Detects patterns like start:end or start:end:step
#     Sets default step to 1 or -1 based on direction
#     Validates:
#         Start and end have same sign
#         Step direction matches range direction
#         Step size evenly divides the range
#     Expands range into a list of indices
# 5. Level Processing
#     On encountering / or end of string:
#         Saves current level's index list to NewLst
#         Tracks count of indices per level in CntLst
#         Calculates total permutations (Prod)
#         Updates IdxLen for next level if length information available
# 6. Permutation Generation (when multiple indices exist)
#     If Prod > 1:
#         Builds divisor list for generating all combinations
#         Supports two permutation modes based on ::SimArr(IndexWise):
#             Index-wise: Permutations combine levels independently
#             Product mode: Generates all possible combinations
#         Generates all index permutations by iterating through combinations
#     If Prod == 1: Returns single permutation
proc mfjProc::readIdx {IdxStr
    {LenLst ""}} {
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
    set Str ""
    set IdxBgn ""
    set IdxEnd ""
    set IdxStp 0
    set Lst [list]
    set NewLst [list]
    set CntLst [list]
    set IdxLen [lindex $LenLst 0]
    set Len [string length $IdxStr]
    set Idx 0
    set Stps false
    set IndexWise [expr {[string index $::SimArr(IndexWise) 0] ne "!"}]

    # Append "," to the indices string so that the last index can be processed
    # in the same way as the rest indices
    foreach Char [split $IdxStr, ""] {
        if {[regexp {\d} $Char] || $Char eq "-"} {
            append Str $Char
            incr Idx
            continue
        }
        # Raise an error if Char is not one of the special symbols
        if {![regexp {:|/|,|@} $Char]} {
             error "invalid character '$Char' in index string '$IdxStr'!"
        }
        # Raise an error if Str is not an integer
        if {![string is integer -strict $Str]} {
            error "invalid index '$Str' in index string '$IdxStr'!"
        }
        
        if {$Char eq ":"} {
            if {$IdxBgn eq ""} {
                set IdxBgn $Str
            } elseif {$IdxEnd eq ""} {
                set IdxEnd $Str
                set Stps false
            } else {
                error "more than two ':' in index string '$IdxStr'!"
            }
        } elseif {$Char eq "@"} {
            if {$IdxEnd eq ""} {
                set IdxEnd $Str
                set Stps true
            } else {
                error "wrong index string '$IdxStr'!"
            }
        } else {
            if {[llength $IdxBgn]} {
                if {[llength $IdxEnd]} {
                    if {$Stps} {
                        # #:#@#
                        set IdxStps $Str
                        if {$IdxStps <= 0} {
                            error "steps <= 0 in '$IdxStr'!"
                        }
                    } else {
                        # #:#:#
                        set IdxStp $Str
                    }
                } else {
                    # #:# with step size default to 1 or -1
                    set IdxEnd $Str
                }
                # A negative index is converted to positive if IdxLen is present
                if {$IdxLen > 0} {
                    if {$IdxBgn < 0} {
                        incr IdxBgn $IdxLen
                    }
                    if {$IdxBgn < 0 || $IdxBgn >= $IdxLen} {
                        error "'$IdxStr' index out of range '$IdxLen'!"
                    }
                    if {$IdxEnd < 0} {
                        incr IdxEnd $IdxLen
                    }
                    if {$IdxEnd < 0 || $IdxEnd >= $IdxLen} {
                        error "'$IdxStr' index out of range '$IdxLen'!"
                    }
                }

                # Raise an error if the product of IdxEnd and
                # IdxBgn is negative
                if {[expr $IdxEnd*$IdxBgn] < 0} {
                    error "'$IdxEnd' and '$IdxBgn' have different signs!"
                }
                if {$IdxStp == 0} {
                    set IdxStp [expr ($IdxEnd-$IdxBgn)/abs($IdxEnd-$IdxBgn)]
                }
                if {$Stps} {
                    set IdxStp [expr ($IdxEnd-$IdxBgn)/$IdxStps]
                }
                if {![string is integer $IdxStp]} {
                    error "index step size must be integer in '$IdxStr'!"
                }
                # If the step size is not consistent with the direction
                if {($IdxStp > 0 && $IdxBgn > $IdxEnd)
                    || ($IdxStp < 0 && $IdxBgn < $IdxEnd)} {
                    error "wrong step setting '$IdxStp' in '$IdxStr'!"
                }
                if {[expr ($IdxEnd-$IdxBgn) % $IdxStp] != 0} {
                    error "the step size '$IdxStp' does not fit the range from\
                        '$IdxBgn' to '$IdxEnd'!"
                }

                # Preserve the original form of Str and IdxBgn
                lappend Lst $IdxBgn
                if {$IdxBgn != $IdxEnd} {
                    while {$IdxBgn != $IdxEnd} {
                        lappend Lst [incr IdxBgn $IdxStp]
                    }
                }
                set IdxBgn ""
                set IdxEnd ""
                set IdxStp 0
            } else {
                # A negative index is converted to positive if IdxLen is present
                # A negative index is out of range if it is greater than or
                # equal to IdxLen or still negative after conversion
                if {$IdxLen > 0} {
                    if {$Str < 0} {
                        incr Str $IdxLen
                    }
                    if {$Str < 0 || $Str >= $IdxLen} {
                        error "'$IdxStr' index out of range '$IdxLen'!"
                    }
                }
                # Append Str to Lst if it is a single index
                lappend Lst $Str
            }
            if {$Char eq "/" || $Idx == $Len} {
                lappend NewLst $Lst

                # The number of permutations is updated only when the
                # number of values is higher than one and different
                # from the previous one
                # or ::SimArr(IndexWise) is !IndexWise
                set Cnt [llength $Lst]
                if {$Cnt != [lindex $CntLst end] || !$IndexWise} {
                    set Prod [expr $Prod*$Cnt]
                }
                lappend CntLst $Cnt
                set Lst [list]

                # Update IdxLen if positive
                set LstLen [llength $NewLst]
                if {[lindex $LenLst $LstLen] > 0} {
                    set IdxLen [lindex $LenLst $LstLen]
                }
            }
        }

        # Reset for the next index and move to the next character
        set Str ""
        incr Idx
    }

    if {$Prod > 1} {
        set IdxLst [list]
        set LstLen [llength $NewLst]

        # Dividend / Divisor = Quotient, Dividend % Divisor = Remainder
        # Determine the denominator/divisor list
        set DivrLst [list]
        set Quo $Prod
        set Cnt 0
        # The quotient is updated only when the number of values is higher
        # than one and different from the previous one
        # or ::SimArr(IndexWise) is !IndexWise
        for {set i 0} {$i < $LstLen} {incr i} {
            if {$Quo > 1 && ($Cnt != [lindex $CntLst $i] || !$IndexWise)} {
                set Quo [expr $Quo/[lindex $CntLst $i]]
            }
            lappend DivrLst $Quo
            set Cnt [lindex $CntLst $i]
        }

        # Generate all the permutations of indices
        # based on the denominator/divisor list
        for {set i 0} {$i < $Prod} {incr i} {
            set Lst [list]
            for {set j 0} {$j < $LstLen} {incr j} {
                set Cnt [lindex $CntLst $j]
                set Divr [lindex $DivrLst $j]
                lappend Lst [lindex $NewLst $j [expr int($i/$Divr)%$Cnt]]
            }
            lappend IdxLst $Lst
        }
    } else {
        set IdxLst [list $NewLst]
    }
    return $IdxLst
}

# mfjProc::replaceElm
#     This procedure replaces elements within a nested list structure based on
#     defined patterns and rules, supporting multiple value replacement, range
#     expansion (linear/logarithmic), and permutation generation across
#     multiple elements.
# Purpose
#     Enable batch simulations by allowing variables to have multiple values
#     through element-level substitution. This is particular useful for
#     systematic exploration of parameter spaces (parameter sweep or pairing)
#     where variables need to take multiple values typically with small
#     variations (e.g., changing one or two elements only).
# Shorthand Syntax
#     Basic pattern (without braces):
#         i/j/k,l:n&i/k/o,x:z=val1&val2&....
#     Note:
#         i/j/k: Index path targeting specific element(s)
#         /: Separator for multiple levels of indices
#         ,: Separator for multiple indices at same level
#         :: Range separator for indices at same level
#         &: Separator for multiple index paths
#         =: Assignment operator
#         val1&val2&...: Values assigned to targeted elements, respectively
#     Easy-to-Read form (with braces):
#         {i/j/k,l:n&i/k/o,x:z=val1 val2 ...}
#     Note:
#         Values are separated by a space instead of '&' in Easy-to-Read form
# Element Value Assignment
#     Multiple element values using the '|' symbol: (Can NOT use ',')
#         i/j/k=ElmVal1|ElmVal2|...
# Sequnence Generation Syntax
#     Four syntax forms are available for generating value sequnences
#         (linear or logarithmic progression):
#         i/j/k=[ElmBgn:]ElmVal:Step - Linear progression with step
#         i/j/k=[ElmBgn:]ElmVal:Step: - Logarithmic progression with step
#         i/j/k=[ElmBgn:]ElmVal@Steps - Linear progression with steps
#         i/j/k=[ElmBgn:]ElmVal@Steps@ - Logarithmic progression with steps
#     Note:
#         ElmBgn is optional and defaults to the element's current value
#         Using : indicates step-based progression (last value determined by
#             step)
#         Using @ indicates step-count-based progression (last value equals End)
#         Appending an extra `:` or `@` indicates logarithmic spacing
# Permutation Generation Logic
#     When multiple elements have multiple values:
#         Case 1 - Same number of values per element:
#             IndexWise: Permutations are generated element-wise or pairwise
#             Otherwise: falls back as the product of all element values
#         Case 2 - Different numbers of values per element:
#             Always full combinatorial/Cartesian/cross product
#     Note:
#         This design choice ensures that no data is silently dropped, which
#             is important for simulation integrity.
# Handling Multiple Element Values
#     When an element receives multiple values:
#         1. Values are temporarily "folded" (stored separately) to prevent
#             chaotic references
#         2. The number of variable values increases accordingly
#         3. Folding values are only visible for element substitution, not for
#             variable value substitution
# Arguments
#     Argument    Type    Description
#     VarName     String  Name of the variable to process
#     VarVal      List    List of variable values, where the first value is the
#                         original value and the rest are replacement patterns
# Return Values
# The procedure returns a two-element list:
#     LvlFoldLst: List tracking which levels contain folded (multiple) values
#         Value > 0 indicates number of additional permutations at that level
#     NewLst: Processed list with elements replaced and permutations expanded

# Processing Flow
# 1. Initialization
#     Preserve first value as baseline (level 0)
#     Initialize NewLst with the first value and LvlFoldLst with 0 (no folding)
#     Set level counter (LvlIdx) to 1 for processing replacement patterns
# 2. Process each subsequent value in VarVal from level 1 to end
# 3. Pattern detection and parsing
#     Step 1: Check for element-replacement pattern (with or without braces)
#         Pattern: ^((-?\d+[,:/&])*-?\d+)=(.+)$
#             • Left side: Index reference string
#             • Right side: Value assignment string
#     Step 2: Parse index references
#         • Split by '&' for multiple reference paths
#         • Process each reference with `readIdx`
#         • Validate first index (level 0) is consistent across all references
#         • Convert negative indices to positive
#         • Verify all indices are within range
#     Step 3: Parse value assignments
#         • Split value string into list
#         • Handle length mismatch:
#             - If too short: repeat last value
#             - If too long: truncate with warning
# 4. Value generation processing
#     Process each value in ElmValLst for each index path
#     Check for multiple values for the same element
#         Pattern 1: (ElmBgn:)ElmVal:Step - Linear with Step
#         Pattern 2: (ElmBgn:)ElmVal:Step: - Logarithmic with Step
#         Pattern 3: (ElmBgn:)ElmVal@Steps - Linear with Steps
#         Pattern 4: (ElmBgn:)ElmVal@Steps@ - Logarithmic with Steps
#         Pattern 5: ElmVal1|ElmVal2... - Multiple values separated by '|'
#     For each generated/assigned value:
#         Append to temporary list (Lst) for the current level
#         Track count (Cnt) of values for the current element
#         Update Begin value for subsequent value generation if necessary
# 5. Permutation calculation
#     Calculate total permutations (Prod):
#         • Base case: Product of all value counts (Cnt for each index)
#         • IndexWise mode: Only multiply when counts differ
#             (::SimArr(IndexWise) controls behavior)
#     If Prod > 2: Generate all permutations of values
#         • Calculate divisor list for nested loop generation
#         • Use depth-first approach to create all combinations
#         • For each permutation i from 1 to Prod-1:
#             - Select value index using integer division and modulo
#             - Update NewVal at target indices
#             - Append to permutation list
#     Otherwise: Single value assignment, no permutation needed
#         • Update NewVal directly with values
# 6. Result acumulation
#     Append processed NewVal to NewLst for the current level
#     Update LvlFoldLst with (Prod-1) to track folding values for each level
#     Increment level counters (LvlIdx, LvlLen) for next iteration
# 7. Return [list $LvlFoldLst $NewLst]
proc mfjProc::replaceElm {VarName VarVal} {
    set VarMsg "variable '$VarName'"

    # Check the 2nd value (level 1) onwards for element-replacement pattern
    set LvlIdx 1
    set LvlLen 2
    set NewLst [list [lindex $VarVal 0]]
    # Each level has a value: 0 -> no folding; positive -> folding
    set LvlFoldLst 0
    foreach OldVal [lrange $VarVal 1 end] {
        set LvlMsg "level '$LvlIdx'"
        set Msg "$LvlMsg of $VarMsg"

        # For the Easy2Read form, remove the enclosing braces if any
        if {[regexp {\{(-?\d+[,:/&])*-?\d+=} $OldVal]} {
            # Find the position of the first digit or minus sign
            regexp -indices {(-|\d)} $OldVal Loc
            # `Loc` is a list of two elements: {startIndex endIndex}
            set Idx [lindex $Loc 0]
            set OldVal [string range $Idx end-$Idx]
        }

        # Check the string for element-replacement pattern. Negative indexing
        # is supported by changing regular expression pattern from '\d+' to
        # '-?\d+'
        if {![regexp {^((-?\d+[,:/&])*-?\d+)=(.+)$} $OldVal\
            -> IdxPathStr -> ElmValStr]} {
            # This level has no element-replacement pattern
            lappend NewLst $OldVal
            lappend LvlFoldLst 0
            incr LvlIdx
            incr LvlLen
            continue
        }

        # Pattern detected! Treat the list in the Easy2Read form also as a
        # string! Interpret the index string and check validity of each
        # reference. Make sure the level 0 index is equal (same original value)
        # and within range and the rest indices are within range.
        set IdxLst [list]
        set Lvl0Idx ""
        foreach IdxPath [split $IdxPathStr &] {
            foreach Elm [readIdx $IdxPath] {

                # Check level 0 index of each reference and make sure
                # they are the same if there are multiple references
                if {$Lvl0Idx eq ""} {
                    set Lvl0Idx [lindex $Elm 0]
                    # If any index is negative, convert it to positive
                    if {$Lvl0Idx < 0} {
                        incr Lvl0Idx $LvlLen
                    }
                    if {$Lvl0Idx < 0 || $Lvl0Idx >= $LvlIdx} {
                        error "level 0 index '$Lvl0Idx' of reference\
                            '$IdxPathStr' out of range for $Msg!"
                    }
                    # Initialise reference value
                    set NewVal [lindex $NewLst $Lvl0Idx]
                } else {
                    set Idx [lindex $Elm 0]
                    if {$Idx < 0} {
                        incr Idx $LvlLen
                    }
                    if {$Idx != $Lvl0Idx} {
                        error "invalid reference '$IdxPathStr' for $Msg,\
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
                            '$IdxPathStr' out of range for $Msg!"
                    }
                    lappend Lst $Idx
                    set Val [lindex $Val $Idx]
                    set Len [llength $Val]
                    incr Cnt
                }
                lappend IdxLst $Lst
            }
        }
        set LstLen [llength $IdxLst]

        # Convert the '&'-seperated element value string to a value list
        # and check whether 'ElmValLst' tallies with 'IdxLst'
        set ElmValLst [lrange [string map {& " "} $ElmValStr] 0 end]
        set ElmValLen [llength $ElmValLst]
        if {$ElmValLen < $LstLen} {

            # Repeat the last element to complement the list
            set Lst $ElmValLst
            while {$ElmValLen < $LstLen} {
                lappend Lst [lindex $ElmValLst end]
                incr ElmValLen
            }
            set ElmValLst $Lst
        } elseif {$ElmValLen > $LstLen} {
            vputs -v2 "value '[lrange $ElmValLst $LstLen end]' excess\
                for $Msg!"
            set ElmValLst [lrange $ElmValLst 0 [incr LstLen -1]]
        }

        # Search 'ElmValLst' for value sequence generation patterns
        set Prod 1
        set ValSubLst [list] ;# List of sublists for values
        set ValCntLst [list] ;# List of counts of element values
        set IndexWise [expr {[string index $::SimArr(IndexWise) 0] ne "!"}]
        foreach ElmIdx $IdxLst ElmVal $ElmValLst {
            # Count of values for the current element
            set Cnt 0
            # Set the default begin value to the current element
            set DfltBgn [lindex $NewVal $ElmIdx]
            set SubLst [list]
            # Parse the element value string for each index and generate the
            # value list for the current index path
            foreach ValStr [split $ElmVal |] {
                set Begin ""
                set End ""
                set Step ""
                set Steps ""
                set Log ""
                # Pattern 5: Simple value (no generation)
                if {![regexp {^(([^:]+):)?([^:]+):([^:@]+)(:|@)?$}\
                    $ValStr -> -> Begin End Step Log]
                    && ![regexp {^(([^:]+):)?([^@]+)@(\d+)([^\d])?$}\
                    $ValStr -> -> Begin End Steps Log]} {
                    # ValStr not necessaryly a number, so no validation here
                    lappend SubLst $ValStr
                    set DfltBgn $ValStr
                    incr Cnt
                    continue
                }

                # Pattern 1&2: [Begin:]End:Step[:] (specifies step)
                # Pattern 3&4: [Begin:]End@Steps[@] (specifies steps)
                # Validate Begin and End values
                if {$Begin ne ""} {
                    foreach Var {Begin End} Val [list $Begin $End] {
                        if {[catch {set $Var [expr 1.*$Val]}]} {
                            error "invalid range in '$ValStr' for $Msg!"
                        }
                    }
                    # Append the Begin value to the list
                    if {$Begin != $DfltBgn} {
                        lappend SubLst [format %g $Begin]
                        incr Cnt
                    }
                } else {
                    if {[catch {set Begin [expr 1.*$DfltBgn]}]} {
                        error "invalid default begin value '$DfltBgn' for $Msg!"
                    }
                    if {[catch {set End [expr 1.*$End]}]} {
                        error "invalid range in '$ValStr' for $Msg!"
                    }
                }
                if {$Begin == $End} {
                    error "begin and end values are the same in\
                        $ValStr for $Msg!"
                }
                if {$Log ne ""} {
                    if {$Begin <= 0 || $End <= 0} {
                        error "begin and end values must be positive\
                            for logarithmic progression for $Msg!"
                    }
                }
                if {$Steps ne ""} {
                    # Validate Steps value
                    if {$Steps == 0} {
                        error "number of steps cannot be zero in '$ValStr'\
                            for $Msg!"
                    }
                    # Calculate step size based on the number of steps
                    if {$Log ne ""} {
                        set Step [expr exp(log($End/$Begin)/$Steps)]
                    } else {
                        set Step [expr 1.*($End-$Begin)/$Steps]
                    }
                } else {
                    # Validate Step value
                    if {[catch {set Step [expr 1.*$Step]}]} {
                        error "invalid step size in '$ValStr' for $Msg!"
                    }
                    # Check direction consistency and step size
                    if {$Log ne ""} {
                        if {($Step > 1 && $Begin > $End)
                            || ($Step < 1 && $Begin < $End)} {
                            error "step factor direction inconsistent\
                                with range from $Begin to $End for $Msg!"
                        }
                        if {($Step > 1 && $End < $Begin*$Step)
                            || ($Step < 1 && $End > $Begin*$Step)} {
                            error "step factor too large for the range\
                                from $Begin to $End for $Msg!"
                        }
                    } else {
                        if {($Step > 0 && $Begin > $End)
                            || ($Step < 0 && $Begin < $End)} {
                            error "step direction inconsistent with\
                                range from $Begin to $End for $Msg!"
                        }
                        if {($Step > 0 && $End < $Begin + $Step)
                            || ($Step < 0 && $End > $Begin + $Step)} {
                            error "step size too large for the range\
                                from $Begin to $End for $Msg!"
                        }
                    }
                }

                # Generate the value list for four patterns
                if {$Log ne ""} {
                    # Generate logarithmic progression with step factor
                    set Val $Begin
                    while {($Step > 1 && $Val < $End - 0.5*$Step*$Val)
                        || ($Step < 1 && $Val > $End - 0.5*$Step*$Val)} {
                        set Val [expr {$Val * $Step}]
                        lappend SubLst [format %g $Val]
                        incr Cnt
                    }
                } else {
                    # Generate linear progression with step
                    # Buffer zone of 0.5*Step avoid precision issue
                    set Val $Begin
                    while {($Step > 0 && $Val < $End - 0.5*$Step)
                        || ($Step < 0 && $Val > $End - 0.5*$Step)} {
                        set Val [expr {$Val + $Step}]
                        lappend SubLst [format %g $Val]
                        incr Cnt
                    }
                }
                # Update DfltBgn for the next value generation
                set DfltBgn [format %g $Val]
            }

            # The number of permutations is updated only when the number
            # of values is higher than one and different from the previous
            # one or ::SimArr(IndexWise) is !IndexWise
            if {$Cnt == 0} {
                error "no valid value from '$ValStr' for $Msg!"
            }
            if {$Cnt != [lindex $ValCntLst end] || !$IndexWise} {
                set Prod [expr $Prod*$Cnt]
            }
            lappend ValSubLst $SubLst
            lappend ValCntLst $Cnt
        }

        # No expanding to the full list yet so the indexing afterwards is ok
        # These permutations are generated similar to the depth-first search
        if {$Prod > 1} {
            set Lst [list]

            # Dividend / Divisor = Quotient, Dividend % Divisor = Remainder
            # Determine the denominator/divisor list
            set DivrLst [list]
            set Quo $Prod
            set Cnt 0
            for {set i 0} {$i < $LstLen} {incr i} {
                if {$Quo > 1
                    && ($Cnt != [lindex $ValCntLst $i] || !$IndexWise)} {
                    set Quo [expr $Quo/[lindex $ValCntLst $i]]
                }
                lappend DivrLst $Quo
                set Cnt [lindex $ValCntLst $i]
            }
            for {set i 0} {$i < $Prod} {incr i} {
                for {set j 0} {$j < $LstLen} {incr j} {
                    set Cnt [lindex $ValCntLst $j]
                    set Divr [lindex $DivrLst $j]
                    set ElmIdx [lindex $IdxLst $j]
                    set Val [lindex $ValSubLst $j [expr int($i/$Divr)%$Cnt]]
                    if {[catch {lset NewVal $ElmIdx $Val} Err]} {
                        error "failed to update index '$ElmIdx' for $Msg:\
                            $Err!"
                    }
                }
                lappend Lst $NewVal
            }
            lappend NewLst $Lst
        } else {
            foreach ElmIdx $IdxLst Val $ElmValLst {
                if {[catch {lset NewVal $ElmIdx $Val} Err]} {
                    error "failed to update index '$ElmIdx' for $Msg: $Err!"
                }
            }
            lappend NewLst $NewVal
        }

        # One level already has a value without folding
        lappend LvlFoldLst [incr Prod -1]
        incr LvlIdx
        incr LvlLen
    }

    # Returns the fold status and the new list with replaced elements
    return [list $LvlFoldLst $NewLst]
}

# mfjProc::reuseElm
#     Recursively substitutes element-reuse references within variable values,
#     supporting cross-level references, repetition, and arithmetic expression
#     evaluation.
# Purpose
#     Enables input economy by allowing previously entered values to be
#     referenced and reused. References can appear anywhere (between values or
#     within a value) and are substituted in place with the corresponding
#     referenced elements.
# Reference Syntax
#     References follow the pattern: <i,j:k/i,j:k&l,m:n/l,m:n*#>
#     Symbol  Meaning
#     < >     Delimiters for reuse reference
#     /       Separates nested list levels
#     ,       Separates multiple indices within same level
#     :       Defines index range
#     &       Combines multiple reference paths
#     *#      Optional repetition count (repeats referenced elements # times)
# Reference Rules
#     Within current value: Level index must be omitted
#     To previous value: Level index must be included
# Arguments
    # Argument    Description                                     Default
    # VarName     Variable name (for error messages)              Required
    # ValName     Name of variable value (passed by reference)    Required
    # XLvl        Cross-level reference flag                      true
    # Lvl         Level index for current processing level        ""
    # SubIdx      Index path to current sublist                   ""
# Result
    # No return value. References are updated in place within the variable value

# Processing Flow
# 1. Initialization and Argument Validation
#     Step 1A: Process XLvl Flag
#         If first character is "!" or value is 0: Set XLvl = 0 (disable
#         cross-level); Otherwise: Set XLvl = 1 (enable cross-level)
#     Step 1B: Validate Lvl
#         Check if Lvl is non-negative integer. If valid: Format to remove
#         leading zeros and convert octal/hex to decimal; If invalid:
#         Set Lvl = "" (empty)
#     Step 1C: Validate SubIdx
#         Verify each element is a positive integer or zero. If any element
#         fails validation: Set SubIdx = ""
# 2. Set Up Variable Reference
#     Use upvar 1 $ValName VarVal to create reference to calling scope variable
#     Initialize SubLst (sublist to process):
#         If SubIdx empty and Lvl empty: SubLst = $VarVal (full variable)
#         If SubIdx empty and Lvl present: SubLst = [lindex $VarVal $Lvl]
#         If SubIdx present: SubLst = [lindex $VarVal $SubIdx] (nested sublist)
# 3. Iterate Through Sublist Elements
#     For each element (Elm) in SubLst:
#     Step 3A: Build Context Message
#         Construct error message with level information (if available)
#         and index path
#     Step 3B: Find and Process Reuse References
#         While element contains reference pattern <...>:
#         Check for Nested References: Call isLstDec to detect if element
#         contains list structure
#             If nested: Recursively call reuseElm (adaptive function name
#             using [info level 0])
#                 Pass same parameters with current index path
#                 Break while loop after recursion
#             If not nested: Process current reference
# 4. Reference Processing (Non-Nested)
#     Step 4A: Parse Reference
#         Split reference by * to extract:
#             StrLst: Reference path string (may contain & for multiple paths)
#             Cnt: Repetition count (defaults to empty if not specified)
#         Format repetition count to remove leading zeros and convert octal/hex
#     Step 4B: Split Multiple Paths
#         Split path string by & into individual reference strings (StrLst)
#         For each reference string:
#             Call readIdx to expand index string into index lists
#             Process each index list
#     Step 4C: Build Referenced Value Path (Lst)
#         Add omitted level: If cross-level disabled (XLvl = 0) and Lvl present:
#         Prepend Lvl to index list
#         Trace nested list: Navigate from outermost to innermost:
#             Start with Val = $VarVal
#             Track current position using EndLst (indices to reach target)
#             For each index in Lst:
#                 Convert negative indices to positive using current length
#                 Validate index within bounds
#                 Store positive index in PIdxLst
#                 Update Val to nested element
#                 Update tracking variables for subsequent indices
#     Step 4D: Validate References
#         Circular Reference Detection: Compare PIdxLst with NewIdx (current
#         position)
#             If identical: Throw error "circular reference: '<...>'!"
#         Boundary Validation: Ensure indices are within range
#     Step 4E: Collect Referenced Values
#         If single reference (llength StrLst * llength IdxLst == 1):
#             Concatenate value to NewElm (flattened)
#         Otherwise:
#             Append value as list element to NewElm
# 5. Repetition and Substitution
#     Step 5A: Apply Repetition
#         Set Tmp = $NewElm (store original result)
#         For i = 1 to Cnt-1:
#             Concatenate Tmp to NewElm
#             Use regsub to replace <...> pattern with NewElm in current element
#     Step 5B: Cross-Level Update
#         If cross-level enabled (XLvl = 1) and level present (Lvl):
#             Update variable value at current index path
#             Break while loop (reference processed)
# 6. Element Update (Within Current Level)
#     Step 6A: Apply In-Place Updates
#         If Reuse flag is true and cross-level disabled (XLvl = 0):
#             Expression Evaluation: If element is single value:
#                 Convert to lowercase
#                 Attempt to evaluate as arithmetic expression using
#                 expr 1.*$NewElm
#                 Format result with %g to remove unnecessary decimal places
#         If evaluation fails: Log warning "not an arithmetic expression"
#             Update variable value at current index path
#     Step 6B: Continue Iteration
#         Increment LstIdx to process next element
# 7. Processing Complete
#     Function returns; modifications are in place

# Key Features
# Feature                 Description
# In-Place Substitution   References replaced directly in the variable value
# Recursive Processing    Handles nested references through self-calls
# Cross-Level References  Optional referencing to previous variable values
# Negative Index Support  Converted negative indices using current list length
# Repetition              *# syntax repeats referenced elements specified times
# Arithmetic Evaluation   Numeric expressions evaluated after substitution
# Circular Ref Detection  Break loop by detecting self-references
# Multi-Path References   & separator combines multiple reference paths
# Range Expansion         : syntax for index ranges (via readIdx)
proc mfjProc::reuseElm {VarName ValName
    {XLvl ""} {Lvl ""} {SubIdx ""}} {

    # Initialise XLvl as 0/1.
    # In regression 0 is still 0, 1 is still 1
    if {[string index $XLvl 0] eq "!"} {
        set XLvl 0
    } elseif {$XLvl == 0} {
        set XLvl 0
    } else {
        set XLvl 1
    }

    # Validate arguments
    # All levels should not be negative integers
    if {[string is integer -strict $Lvl] && $Lvl >= 0} {

        # Format the level to remove leading zeroes
        # and convert octal(0#) and hexadecimal(0x#) to decimal
        set Lvl [format %d $Lvl]
    } else {
        set Lvl ""
    }

    # All indices should be either positive integer or zero
    foreach Elm $SubIdx {
        if {![regexp {^\d+$} $Elm]} {
            set SubIdx ""
            break
        }
    }

    # Set VarVal pointing to ValName
    upvar 1 $ValName VarVal

    # Initialise SubLst
    if {$SubIdx eq ""} {
        if {$Lvl eq ""} {

            # Single value
            set SubLst $VarVal
        } else {
            set SubIdx $Lvl
            set SubLst [lindex $VarVal $SubIdx]
        }
    } else {

        # In case of regression
        set SubLst [lindex $VarVal $SubIdx]
    }

    set VarMsg "variable '$VarName'"
    set LstIdx 0
    set Reuse false
    foreach Elm $SubLst {
        set NewIdx [concat $SubIdx $LstIdx]
        set Reuse false
        if {$Lvl ne ""} {
            set Msg "'$Elm' of level '$Lvl' (index $NewIdx) of $VarMsg"
        } else {
            set Msg "'$Elm' of $VarMsg (index $NewIdx)"
        }

        # Replace each element-reuse feature
        # Negative indexing is supported with the pattern '-?\d+'
        while {[regexp {<((-?\d+[,:/&])*-?\d+(\*\d+)?)>} $Elm -> IdxPathStr]} {
            if {[isLstDec $Elm]} {

                # Visit all the nested elements by regression
                # The function name is adaptive: '[lindex [info level 0] 0]'
                # VarVal: pass by reference; $ValName fails
                [lindex [info level 0] 0] $VarName VarVal\
                    $XLvl $Lvl $NewIdx

                # Either update Elm or simply break the while loop
                break
            }
            set NewElm [list]
            set Lst [split $IdxPathStr *]
            set Cnt [lindex $Lst 1]

            # Format repeat times
            if {[string is integer -strict $Cnt]} {
                set Cnt [format %d $Cnt]
            }
            set StrLst [split [lindex $Lst 0] &]
            foreach Str $StrLst {
                set IdxLst [readIdx $Str]
                foreach Lst $IdxLst {

                    # Multiple values and reuse elements within a level
                    # Prepend the omitted level
                    if {!$XLvl && $Lvl ne ""} {
                        set Lst [concat $Lvl $Lst]
                    }

                    # Trace a nested list from the outmost to innermost
                    set Val $VarVal

                    # Initially get EndIdx from the current indices
                    set EndLst $NewIdx

                    # Only refer to a previous element
                    set EndIdx [lindex $EndLst 0]
                    set Len [expr 1+$EndIdx]

                    # #: forwards from the first index
                    # -#: backwards from the current index (-1)
                    # Store postive indices in PIdxLst
                    set PIdxLst [list]
                    foreach Idx $Lst {
                        set PIdx $Idx
                        if {$Idx < 0} {
                            incr PIdx $Len
                        }
                        if {$PIdx < 0 || $PIdx > $EndIdx} {
                            error "index '$Idx' out of range\
                                '$EndIdx' for element $Msg!"
                        }
                        lappend PIdxLst $PIdx

                        # Update the value for next round index check
                        set Val [lindex $Val $PIdx]
                        if {$EndLst ne "" && $PIdx == $EndIdx} {

                            # Continue to extract next EndIdx from EndLst
                            set EndLst [lrange $EndLst 1 end]
                            set EndIdx [lindex $EndLst 0]
                            set Len [expr 1+$EndIdx]
                        } else {

                            # The current index is not EndIdx anymore
                            # Clear EndLst
                            set EndLst ""

                            # Extract EndIdx from the list directly
                            set Len [llength $Val]
                            set EndIdx [expr $Len-1]
                        }
                    }

                    # Detect and raise a circular reference error
                    # NewIdx is a list of postive indices by default
                    if {$PIdxLst eq $NewIdx} {
                        error "circular reference: '<$IdxPathStr>'!"
                    }
                    if {[llength $StrLst]*[llength $IdxLst] == 1} {
                        set NewElm [concat $NewElm $Val]
                    } else {
                        lappend NewElm $Val
                    }
                }
            }

            # Substitute only the 1st pattern in the element in each loop
            set Reuse true
            set Tmp $NewElm

            # If Cnt exceeds 1, repeat Cnt times
            for {set i 1} {$i < $Cnt} {incr i} {
                set NewElm [concat $NewElm $Tmp]
            }
            regsub {<(-?\d+[:,/&])*-?\d+(\*\d+)?>} $Elm $NewElm Elm

            # Need to break loop after activating reuse-only feature
            # in level 1+
            if {$XLvl && $Lvl} {
                lset VarVal $NewIdx $Elm
                break
            }
        }

        # Update elements for references within a level
        if {$Reuse && !$XLvl} {
            if {[llength $Elm] == 1} {

                # Try to evaluate an arithmetic expression if it is
                set NewElm [string tolower $Elm]
                if {[catch {set Elm [format %g [expr 1.*$NewElm]]}]} {
                    vputs -v2 "'$Elm' not an arithmetic expression!"
                }
            }
            lset VarVal $NewIdx $Elm
        }
        incr LstIdx
    }
}

# mfjProc::isLstDec
    # Designed to judge whether a list can be further decomposed or not
# Arguments
    # Lst         A list to be evaluated
# Result: Return true for further decomposition or false
proc mfjProc::isLstDec {Lst} {

    # For further decomposition, a list shall either have multiple elements
    # or be a braced list (i.e. a nested list)
    return [expr [llength $Lst] > 1 || [regexp {^\{.*\}$} $Lst]]
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
proc mfjProc::readTT {TTArr TTFile
    {TTRatio 1}} {
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
proc mfjProc::lPolation {XList YList X
    {LinX ""} {LinY ""}} {

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
proc mfjProc::str2List {StrList
    {VarInfo ""} {Level 0}} {

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
        } elseif {[isLstDec $SubLst]} {

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
#     Splits variable values into multiple sublists based on predefined
#     group IDs, supporting materials, positions, regions, interfaces, and
#     various simulation identifiers
# Purpose
#     Organizes variable values that contain data for multiple entities
#     (materials, regions, interfaces, positions, etc.) by grouping them
#     according to specified group IDs. Each value is validated against
#     its expected group type and transformed into a standardized format.
# Supported Group IDs
#     ID  Description                     Validation Source
#     b   Boundary/contact identifiers    SimArr(BIDLst)
#     d   Default attr identifiers        SimArr(DIDLst)
#     m   Material names                  Material database (SimArr(MatDB))
#     o   Optical identifiers             SimArr(OIDLst)
#     p   Single position                 Coordinate validation
#     pp  Box (two positions)             Coordinate validation
#     q   Process/operation identifiers   SimArr(QIDLst)
#     r   Region index                    Region information
#     rr  Interface (two regions)         Region information
#     v   Varying variable reference      SimArr(VarLen)
# Arguments
#     Argument    Description
#     VarName     Variable name (for error messages)
#     VarVal      Variable values to group
#     GrpID       Permutations of group IDs (e.g., {m p r})
#     LvlIdx      Current level index
#     LvlLen      Total number of levels
# Return Value
#     Returns a grouped list where each group's first element is the group
#     identifier followed by its associated values.

# Processing Flow
# 1. Argument Validation and Context Setup
#     Step 1A: Build Grammar String
#         • Join GrpID into GStr (e.g., {m p r} → mpr)
#         • Initialize error context message Txt
#     Step 1B: Process Each Group ID Type
#         ID  Action                              Source Array
#         b   Load BIDLst, build context          SimArr(BIDLst)
#         d   Load DIDLst, build context          SimArr(DIDLst)
#         o   Load OIDLst, build context          SimArr(OIDLst)
#         q   Load QIDLst, build context          SimArr(QIDLst)
#         v   Load VarLen, build context          SimArr(VarLen)
#         m   Validate material database exists   SimArr(MatDB)
#     Step 1C: Position/Region Grammar Context
#         Pattern Context Text
#         ppp     "a position or box"
#         pp      "a box"
#         p       "a position"
#         rrr     "a region or interface"
#         rr      "an interface"
#         r       "a region"
# 2. Extract Simulation Domain Boundaries
# Only if GStr contains p or r:
#     • Filter region information (RegInfo) to exclude:
#         - Regions marked with M (to be removed)
#         - Regions with negative indices
#     • Extract coordinate lists (XLst, YLst, ZLst) from SimArr
#     • Store in DimLst as [list $XLst $YLst $ZLst]
# 3. Regular Expression Definitions
#     Variable    Pattern Purpose
#     RE_m        [\w.]+                      Material names
#     RE_r        (-?\d+[:@,])*-?\d+          Region/interface indices
#     RE_v        (-?\d+[:@,])*-?\d+          Varying variable indices
#     RE_n        Scientific notation pattern Numeric values
# 4. Main Processing Loop
# For each value (Val) in VarVal:
# Initialize per value:
#     • Bool = false (group ID not yet matched)
#     • Track value index (ValIdx) and total count (ValEnd)
# For each group ID (GID) in GrpID:
# Case b - Boundary/Contact IDs
#     • Search BIDLst for case-insensitive match:
#         o Index 0: Contact name - validate against IntfAttr
#         o Index 1: Always matches
#         o Index 2+: Special keywords:
#             - M → MonoScaling
#             - S → SpecScaling
#             - W → Wavelength
#     • Convert matched value to lowercase
#     • Throw error if contact not found in IntfAttr
# Case d - Data Type IDs
#     • Search DIDLst for match:
#         o M → Mesh
#         o N → Numeric
#         o O → Other
# Case o - Optical IDs
#     • Search OIDLst for match:
#         o I → Incidence
#         o M → Monochromatic
#         o S → Spectrum
# Case q - Process/Operation IDs
#     • Search QIDLst for match (using first 3 characters):
#         o Cal → calibrate
#         o Dep → deposit
#         o Dif → diffuse
#         o Etc → etch
#         o Imp → implant
#         o Ini → init
#         o Mas → mask
#         o Sel → select
#         o Tra → transform
#         o Wri → write
# Case m - Material Names
#     • Skip if value is a position or numeric expression
#     • Skip if value matches shape keywords (Ellipse, Vertex, etc.)
#     • Search material database for exact match (case-insensitive)
#     • If found:
#         o For GStr = "m": Create material record
#             [list material region_id group region_seq]
#         o Otherwise: Return material name

# Case p / pp - Positions
#     • Call verifyPos with DimLst and context
#     • If valid positions returned: Set Bool = true, update Val
# Case r - Regions
#     • Match pattern: ^r$RE_r$ (e.g., r5, r1:3)
# Case rr - Interfaces
#     • Match pattern: ^r($RE_r/$RE_r&)*$RE_r/$RE_r$ (e.g., r0/1, r1:3/5:7)
# Case v - Varying Variables
#     • Extract index string after v or V
#     • Read indices using readIdx with VarLen:
#         o Single level: Use VarLen directly
#         o Multiple levels with IndexWise: Use level-specific length
#         o Multiple levels without IndexWise: Check all levels
#     • Generate v<index> strings for each valid index
#     • Special case: Precision → return as-is
# 5. Region/Interface Expansion
# When value matches region/interface pattern:
#     • Split by & (remove leading r)
#     • For each reference string:
#         o Call readIdx with RegLen
#         o For each index list:
#             - If interface (2+ indices): Call rr2pp to verify interface
#                 between block regions
#             - Add to result as r<joined_indices>
#     • Sort and deduplicate results
# 6. Group Assembly
#     Step 6A: Group Boundary Detection
#         • If not first element and group ID found:
#             o Complete current group: prepend identifier to
#                 all subgroup values
#             o Add to NewLst
#             o Reset SubLst
#     Step 6B: First Element Validation
#         • First element must match a group ID
#         • Throw error if not: "the first element 'Val' should refer to Txt"
#     Step 6C: Accumulate Values
#         • Add current value to SubLst
#     Step 6D: Final Group Completion
#         • If last element: Finalize the last group
# 7. Return Result
#     Return NewLst containing grouped lists.
# Key Features
# Feature                 Description
# Multi-Type Support      Handles materials, positions, and other identifiers
# Range Expansion         Expands region/interface index ranges
# Case Insensitivity      All identifier matching is case-insensitive
# Hierarchical Validation Validates against simulation data structures
# Interface Verification  Calls rr2pp to verify interface validity
# Duplicate Removal       Sorts and deduplicates expanded values
# Contextual Errors       Provides detailed error messages with context
# Multi-Level Support     Handles nested simulation levels with IndexWise mode
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
    set RE_r {(-?\d+[:@,])*-?\d+}
    set RE_v {(-?\d+[:@,])*-?\d+}

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
                            if {[string index $::SimArr(IndexWise) 0] ne "!"
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
                            && [string index $::SimArr(IndexWise) 0] ne "!"} {
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
#     Validates and evaluates position strings, ensuring coordinates are within
#     simulation domain bounds, with support for expressions, coordinate
#     variables, and region specifications.
# Purpose
#     Parses position strings containing coordinate specifications (e.g.,
#     p###_###_###), evaluates any embedded expressions or coordinate references
#     (e.g., x#, y#, z#), validates bounds against simulation domain, and
#     optionally sorts coordinates for region definitions.
# Supported Position Formats
#     Format              Description
#     p#_#_#              Single position with 1-3 coordinates
#     p#_#_#//x#_y#_z#    Region defined by two positions
#     p#_#_#&x#_y#_z#     Multiple positions separated by &
#     p#+5_#_#            Expressions in coordinates
#     px#_y#_z#           Variable references using x#, y#, z#
# Arguments
#     Argument    Type    Description
#     PosStr      String  Position string to validate and evaluate
#     GStr        String  Grammar string (e.g., p, pp, pprr, ppprrr)
#     DimLst      List    List of coordinate lists [xLst yLst zLst]
#                             defining simulation domain
#     Context     String  Context message for error reporting
# Return Value
#     Returns a list of verified/evaluated position strings
#     (sorted with duplicates removed).

# Processing Flow
# 1. Initialization and Setup
#     Step 1A: Parse Dimension Lists
#         • Extract xLst, yLst, zLst from DimLst
#         • Calculate lengths (xLen, yLen, zLen)
#         • Determine DimLen (number of active dimensions: 1, 2, or 3)
#         • Initialize NewStrLst = [] (empty result list)
#     Step 1B: Preprocess Input
#         • Convert PosStr to lowercase (Tcl functions are lowercase)
#         • Early exit: If first character is not p, return empty list
#             (not a position string)
# 2. Parse Position String
#     Step 2A: Split by & Separator
#         • Remove leading p character
#         • Split remainder by & into StrLst
#     Step 2B: Classify Each Segment
#     Pattern Type                                Description
#     ^([^_]+_){0,2}[^_]+//([^_]+_){0,2}[^_]+$    Two positions separated by //
#     ^([^_]*\d+[^_]*_){0,2}[^_]*\d+[^_]*$        One position with coordinates
#     Other                                       Not a valid position format
#     Validation Rules:
#         • Cannot mix single positions and regions in same PosStr
#         • Region positions must have same number of coordinates
#         • Track PosLen: 1 for single position, 2 for region
# 3. Coordinate Verification Loop
# For each position list (PosLst) in PPLst:
#     Step 3A: Dimension Consistency Check
#         • If DimLen == 0: Set DimLen from first position's coordinate count
#         • Otherwise: Verify all positions have same coordinate count
#         • Special case for 1D interfaces with pprr grammar:
#             Allow + or - as valid coordinate
#     Step 3B: Process Each Coordinate
#     For each coordinate (Elm) with axis (x, y, z):
#     Expression Evaluation:
#         a. Replace variable references (x#, y#, z#):
#             • Extract coordinate letter and index (e.g., x2 → x, 2)
#             • Convert negative indices to positive using axis length
#             • Validate index within bounds [0, Len-1]
#             • Replace all occurrences with actual value from xLst/yLst/zLst
#         b. Evaluate arithmetic expression:
#             • Use expr 1.*$Elm to evaluate
#             • Catch and report evaluation errors
#     Boundary Validation:
#         • Check coordinate is a valid number
#         • Verify coordinate within simulation domain [Min, Max] for that axis
#         • Format number to remove trailing zeros (using format %.12g)
# 4. Position Assembly
# Single Position (PosLen == 1):
#     • Join coordinates with _
#     • Prefix with p
#     • Add to NewStrLst
# Region (PosLen == 2):
#     • Format as p<coord1>//<coord2>
#     • Add to NewStrLst
# 5. Region Coordinate Sorting (for pp grammar)
#     Step 5A: Count Matching Coordinates
#         • Compare coordinates between the two positions
#         • Count how many axes have equal values (Cnt)
#     Step 5B: Sorting Rules by Grammar
#     Grammar         Required Match Count    Action
#     pprr or opprr   Exactly 1               Interface
#                                             (perpendicular to one axis)
#     Other (pp)      Exactly 0               Region (box)
#                                             sort coordinates ascending
#     Any             Cnt == DimLen           Error: positions are identical
#     Step 5C: Apply Sorting (for regions)
#         • Sort coordinate pairs in ascending order using lsort -real
#         • Update both positions with sorted values
#         • Update NewStrLst entry with sorted coordinates
# 6. Return Results
#     • Remove duplicates using lsort -unique
#     • Return final list of verified position strings
# Key Features
# Feature                     Description
# Multi-Dimensional Support   Handles 1D, 2D, and 3D coordinates
# Variable References         x#, y#, z# with negative index support
# Arithmetic Expressions      Any valid Tcl expression (e.g., px2+5)
# Region Definition           Two positions separated by //
# Multiple Positions          & separator for multiple entries
# Automatic Sorting           Sorts region coordinates for consistent
#                             representation
# Domain Validation           Ensures coordinates within simulation bounds
# Interface Detection         Special handling for pprr grammar (1D interfaces)
# Duplicate Removal           Returns unique sorted results
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
                if {$Arr(${Axis}Len) > 0} {
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
#     Evaluates a numeric string that may contain arithmetic expressions or
#     variable references (e.g., x#, x#+5), replacing coordinate variables
#     with their actual values before evaluation
# Purpose
# Converts a numeric expression string into a numeric value by:
#     • Evaluating arithmetic expressions (e.g., 10+20, (5+3)*2)
#     • Resolving coordinate variable references (e.g., x2, y-1, z0)
#     • Validating indices against dimension bounds
#     • Handling negative indices (converting to positive positions)
# Supported Input Formats
#     Format  Description                 Example
#     ###     Plain number                10, 3.14, -5
#     x#      Coordinate variable         x2, y0, z-1
#     x#+5    Expression with variable    x2+5, y3*2, (z0+z1)/2
#     ###+### Arithmetic expression       10+20, 100/4, 2**3
# Arguments
#     Argument    Description                                 Default
#     NumStr      Numeric string to evaluate                  Required
#     DimLst      List of coordinate lists [xLst yLst zLst]   "" (empty)
#     Context     Context message for error reporting         "" (empty)
# Return Value
#     Returns the evaluated number as a floating-point value

# Processing Flow
# 1. Initial Preprocessing
#     Step 1A: Normalize Case
#         • Convert NumStr to lowercase (Tcl functions require lowercase)
#         • Example: "LOG(3)" → "log(3)"
#     Step 1B: Check if Already Numeric
#         • Attempt to evaluate NumStr directly using expr 1.*$NumStr
#         • If successful: Return the evaluated number immediately
#             - 1.* ensures floating-point arithmetic
#             - catch handles evaluation errors gracefully
#         • If evaluation fails: Continue to variable reference processing
# 2. Dimension List Setup
# Only if DimLst is provided and evaluation failed:
#     Step 2A: Parse Dimension Lists
#         • Extract xLst, yLst, zLst from DimLst
#         • Calculate lengths (xLen, yLen, zLen)
#         • Determine DimLen (number of active dimensions):
#             - Count dimensions where length > 0
#             - Valid values: 0, 1, 2, or 3
#     Step 2B: Store in Array
#         • Arr(xLst), Arr(xLen) - X-axis coordinate list and length
#         • Arr(yLst), Arr(yLen) - Y-axis coordinate list and length
#         • Arr(zLst), Arr(zLen) - Z-axis coordinate list and length
# 3. Variable Reference Replacement (Recursive Loop)
# Loop continues while pattern ([xyz])(-?\d+) is found in NumStr:
#     Step 3A: Extract Variable Information
#         • Coord: Axis letter (x, y, or z)
#         • Idx: Index number (may be negative)
#         • Example: x-2 → Coord="x", Idx="-2"
#     Step 3B: Validate Dimension Availability
#         Coordinate  Required DimLen Error Message
#         x           ≥ 1             "no x coordinate in 'RegGen'!"
#         y           ≥ 2             "no y coordinate for 1D!"
#         z           ≥ 3             "no z coordinate for 1D/2D!"
#     Step 3C: Convert Negative Index to Positive
#         • Store original index for error messages (OldIdx)
#         • If Idx < 0: Idx += CoordLen (wrap to positive position)
#         • Example: x-1 with xLen=5 → Idx = -1 + 5 = 4
#     Step 3D: Validate Index Bounds
#         • Check 0 <= Idx < CoordLen
#         • If out of bounds: Throw error with context
#     Step 3E: Replace All Occurrences
#         • Get actual coordinate value: [lindex $CoordList $Idx]
#         • Use regsub -all to replace all occurrences of the pattern
#         • Example: "x2+x2" with xLst=[10,20,30] and Idx=2
#             - Replace x2 with 30 → "30+30"
# 4. Final Expression Evaluation
#     Step 4A: Evaluate the Expression
#         • After all variable references are replaced:
#             - Attempt expr 1.*$NumStr
#             - 1.* ensures floating-point arithmetic (not integer division)
#     Step 4B: Error Handling
#         • If evaluation fails: Throw detailed error
# 5. Return Result
#     • Return the evaluated numeric value
#     • Note: Cannot wrap return in catch (return value is needed)
# Key Features
#     Feature                         Description
#     Immediate Numeric Detection     Returns if input is already a valid number
#     Arithmetic Expression Support   Any valid Tcl expression
#     Variable References             x#, y#, z# coordinate substitution
#     Negative Index Support          x-1 refers to last element
#     Multiple Replacements           -all flag replaces all occurrences
#     Dimension Validation            No referencing unavailable dimensions
#     Bounds Checking Ensures         indices within coordinate list range
#     Context-Aware Errors            Includes user-provided context
#     Floating-Point Arithmetic       Always returns floating-point
# Usage Notes
# • Case Insensitive: Converts input to lowercase automatically
# • Early Return Optimization: Skips variable processing if already numeric
# • Floating-Point Always: Uses 1.* to ensure floating-point arithmetic
# • Negative Index Semantics: -1 = last element, -2 = second-to-last, etc.
# • Recursive Replacement: Loop continues until all variable references resolved
# • Expression Complexity: Supports any Tcl-compatible arithmetic expression
proc mfjProc::evalNum {NumStr
    {DimLst ""} {Context ""}} {

    # Tcl functions are lower cases so change the string to lower cases
    set NumStr [string tolower $NumStr]

    # Return if the string is already a number
    if {![catch {set Res [expr 1.*$NumStr]} Err]} {
        return $Res
    }

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

    # Recursively replace x#, y#, z# if present
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
proc mfjProc::intfVn {Pos1
    {Pos2 ""}} {
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
proc mfjProc::calMaxVarLen {VarName
    {Suffix ""}} {
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
    # Build a SWB node tree according to the IndexWise or full permutation mode
    # Key nodes are a list of the last nodes of all tools
# Arguments:
    # VarName             Variable names
    # VarVal              Variable values
    # STIdxLst            Sentaurus tool Index list
    # IndexWise            Optional, IndexWise (default) or full permutation
    # NodeTree            Optional, returns node tree (default) or key nodes
# Result: Return the node tree
proc mfjProc::buildTree {VarName VarVal STIdxLst
    {IndexWise ""} {NodeTree ""}} {

    # Validate arguments
    foreach Elm [list IndexWise NodeTree] {

        # Make an alias of 'IndexWise' and 'NodeTree'
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
            if {$ValLen != $LastLen || !$IndexWise} {
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
proc mfjProc::tcl2Scheme {VarName VarVal
    {Level 0}} {

    # Validate arguments
    # A level should not be a negative integer
    if {![regexp {^\d+$} $Level]} {
        error "invalid level '$Level'!"
    }

    set SLst [list]
    foreach SubLst $VarVal {
        set SubLen [llength $SubLst]
        if {[isLstDec $SubLst]} {

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
proc mfjProc::customSpec {FSpec WBegin WEnd WStep
    {Shading 0} {FSave ""}} {

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
proc mfjProc::curve2CSV {CName XTitle YTitle PName FCSV
    {TLyr 0} {BLyr 0}} {

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
proc mfjProc::plx2CSV {FPlx
    {FCSV ""} {Remove ""}} {

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
proc mfjProc::gVar2DOESum {GVarArr TrialNode
    {FDOESum ""}} {

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
