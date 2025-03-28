################################################################################
# This namespace is designed to parse and apply customed grammar rules to input
# values or lists.
#
# Maintained by Dr. Fa-Jun MA (mfjamao@yahoo.com)
################################################################################

package require Tcl 8.4

namespace eval mfjGrm {
    variable version 1.0
    variable varName ""
    variable varVal ""
    variable valIdx ""
    variable grmStr ""
    variable currToken ""
    variable ruleChk ""
    variable nestLvl ""

    # grmEval
        # Evaluate a test with necessary arguments. Assign the default
        # value if present once the test is evaluated to be true
    # Arguments
        # Test          Key test string
        # Arguments     Test related arguments
        # DfltVal       Default value if a test is fulfilled
    # Result: Return a boolean result
    proc grmEval {Test Arguments DfltVal} {
        variable varName
        variable varVal
        variable valIdx

        # RE for integers and real numbers
        set RE_n {[+-]?(\.\d+|\d+(\.\d*)?)([eE][+-]?\d+)?}

        # Regular expression for a position (n_n_n)
        set RE_p (${RE_n}_){0,2}$RE_n

        # Regular expression for 'xx' or 'yy' or 'zz'
        # To be updated...
        set RE_c $RE_n/$RE_n

        # Replace a potential reference with the specified element in arguments
        set Lst [list]
        set valLen [expr 1+$valIdx]
        foreach Elm $Arguments {
            if {[regexp -nocase {^(v|g|m)(-?\d+)$} $Elm -> Char Idx]} {

                # Negative index for the current index: -1
                # Convert a negative index to the positive one
                if {$Idx < 0} {
                    incr Idx $valLen
                }
                if {$Idx < 0 || $Idx > $valIdx} {
                    error "'$Elm' index out of range!"
                }
                set Val [lindex $varVal $Idx]

                # Reference to a region element
                set Char [string tolower $Char]
                if {$Char eq "m" || $Char eq "g"} {
                    if {![regexp {^r\d+$} $Val]} {
                        error "'$Elm' should be a region index!"
                    }

                    # No 'RegIdx' verification for index 0
                    set RegIdx [string range $Val 1 end]

                    # Skip to-be-removed and to-be-merged regions from 'RegInfo'
                    set RegInfo [list]
                    foreach Reg [lindex $::SimArr(RegInfo) $::SimArr(RegLvl)] {
                        if {[string index [lindex $Reg 0 1] 0] ne "M"
                            && [lindex $Reg 0 end] >= 0} {
                            lappend RegInfo $Reg
                        }
                    }
                    if {$Char eq "m"} {
                        lappend Lst [lindex $RegInfo $RegIdx 0 0]
                    } else {
                        lappend Lst [lindex $RegInfo $RegIdx 0 2]
                    }
                } else {
                    lappend Lst $Val
                }
            } else {
                lappend Lst $Elm
            }
        }
        set Arg $Lst

        # Evaluate the default value if necessary
        if {$DfltVal ne ""} {
            set DfltStr $DfltVal

            # Find and substitute all the relevant indices
            while {[regexp {v(-?\d+)} $DfltStr -> Idx]} {

                # Negative index for the current index: -1
                # Convert a negative index to the positive one
                if {$Idx < 0} {
                    incr Idx $valLen
                }
                if {$Idx < 0 || $Idx > $ValIdx} {
                    error "'$DfltStr' index out of range!"
                }
                regsub {v-?\d+} $DfltStr [lindex $varVal $Idx] DfltStr
            }

            # In case an reference index is within an expression
            if {[regexp {v-?\d+} $DfltVal]
                && ![regexp {^v-?\d+$} $DfltVal]} {

                # Evaluate the updated default string
                if {[catch {set DfltVal [format %g [expr 1.*$DfltStr]]}]} {
                    error "unknown expression '$DfltVal'!"
                }
            } else {
                set DfltVal $DfltStr
            }
        }

        # Evaluate the current element at "valIdx" against a format rule
        set Val [lindex $varVal $valIdx]
        if {[regexp {^`+([^`]+)$} $Test -> Test]} {
            set Vital true
        } else {
            set Vital false
        }

        # Comparison tests
        if {[regexp {^(>|>=|<|<=|==|!=)$} $Test]} {
            if {[llength $Arg] == 0} {
                error "No arguments for '$Test', check rule!"
            }
            if {[llength $Arg] == 1} {
                set Arg [concat $Val $Arg]
            }
            if {[string is double -strict [lindex $Arg 0]]
                && [string is double -strict [lindex $Arg 1]]} {
                set Str "[lindex $Arg 0] $Test [lindex $Arg 1]"
            } else {

                # Case-insensitive pattern matching with regexp
                if {$Test eq "=="} {
                    set Str "\[regexp -nocase \{^[lindex $Arg 1]$\}\
                        [lindex $Arg 0]\]"
                } elseif {$Test eq "!="} {
                    set Str "!\[regexp -nocase \{^[lindex $Arg 1]$\}\
                        [lindex $Arg 0]\]"
                } else {
                    if {$Test eq ">"} {
                        set Str "\[string compare -nocase [lindex $Arg 0]\
                            [lindex $Arg 1]\] == 1"
                    } elseif {$Test eq ">="} {
                        set Str "\[string compare -nocase [lindex $Arg 0]\
                            [lindex $Arg 1]\] >= 0"
                    } elseif {$Test eq "<"} {
                        set Str "\[string compare -nocase [lindex $Arg 0]\
                            [lindex $Arg 1]\] == -1"
                    } else {
                        set Str "\[string compare -nocase [lindex $Arg 0]\
                            [lindex $Arg 1]\] <= 0"
                    }
                }
            }

            # Special treatment for an empty element to avoid 'regexp' error
            if {[lindex $Arg 0] eq ""} {
                set Bool false
            } else {
                set Bool [expr $Str]
            }
            if {!$Bool && $Vital} {
                error "element '$Val' of '$varVal' should be\
                    '$Test [lindex $Arg 1]'!"
            }
        } else {

            # Other tests
            if {[regexp {^(!+)([^!]+)$} $Test -> Tmp Test]} {
                if {[string length $Tmp]%2} {
                    set Inv !
                } else {
                    set Inv ""
                }
            } else {
                set Inv ""
            }

            # Extract boundaries for tests: 'i', 'n', 'p', 'r', 'x', 'y', 'z'
            set DimLst [list]
            if {$varName ne "RegGen" && [regexp {[inprxyz]} $Test]} {

                # Get values from global array 'SimArr'.
                # Skip to-be-removed and to-be-merged regions from 'RegInfo'
                if {![info exists RegInfo]} {
                    set RegInfo [list]
                    foreach Reg [lindex $::SimArr(RegInfo) $::SimArr(RegLvl)] {
                        if {[string index [lindex $Reg 0 1] 0] ne "M"
                            && [lindex $Reg 0 end] >= 0} {
                            lappend RegInfo $Reg
                        }
                    }
                }
                set RegLen [llength $RegInfo]

                # Extract the boundaries of the simulation domain (including
                # dummy gaseous layers)
                set XLst [lindex $::SimArr(RegX) $::SimArr(RegLvl)]
                set YLst [lindex $::SimArr(RegY) $::SimArr(RegLvl)]
                set ZLst [lindex $::SimArr(RegZ) $::SimArr(RegLvl)]
                set DimLst [list $XLst $YLst $ZLst]
            }

            switch -- $Test {

                # This test does not apply for the previous elements
                a {

                    # Even arguments exist, they will be ignored
                    if {$valIdx >= [llength $varVal]} {
                        set Bool [expr "$Inv true"]
                    } else {
                        set Bool [expr "$Inv false"]
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element index '$valIdx' of '$varVal' should\
                                be absent!"
                        } else {
                            error "element index '$valIdx' of '$varVal' should\
                                NOT be absent!"
                        }
                    }
                }
                b {
                    if {$valIdx == 0} {

                        # skip index 0 for group ID
                        set Bool true
                    } else {

                        # Not required at the moment
                    }
                }
                d {
                    if {$valIdx == 0} {

                        # skip index 0 for group ID
                        set Bool true
                    } else {

                        # Not required at the moment
                    }
                }
                e {

                    # If arguments exist, test the 1st argument instead
                    if {[llength $Arg]} {
                        set Val [lindex $Arg 0]
                    }
                    if {[llength $Val]} {
                        set Bool [expr "$Inv false"]
                    } else {
                        set Bool [expr "$Inv true"]
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be empty!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be empty!"
                        }
                    }
                }
                f {

                    # If arguments exist, test the 1st argument instead
                    if {[llength $Arg]} {
                        set Val [lindex $Arg 0]

                        # A previous index is already tested
                        set Bool [file isfile $Val]
                        set Bool [expr "$Inv $Bool"]
                    } else {

                        # No arguments, update the current element
                        if {[catch {iFileExists varVal $valIdx}]} {
                            set Bool [expr "$Inv false"]
                        } else {
                            set Bool [expr "$Inv true"]

                            # Append the file and mtime to $::SimArr(ModTime)
                            set Tmp [lindex $varVal $valIdx]
                            lappend ::SimArr(ModTime) [list $Tmp\
                                [file mtime $Tmp]]
                        }
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be a file!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be a file!"
                        }
                    }
                }
                i {

                    # If arguments exist, test the 1st argument instead
                    if {[llength $Arg]} {
                        set Val [lindex $Arg 0]
                    }
                    if {[string is integer -strict $Val]} {
                        set Flg true
                    } else {
                        if {[catch {set Val [evalNum $Val $DimLst $varVal]}]} {
                            set Flg false
                        } else {
                            if {[string is integer -strict $Val]} {
                                set Flg true
                            } else {
                                set Flg false
                            }
                        }
                    }
                    if {$Flg} {
                        set Bool [expr "$Inv true"]

                        # No arguments, update the current element
                        if {![llength $Arg]} {

                            # Format each number to its proper form
                            lset varVal $valIdx [format %d $Val]
                        }
                    } else {
                        set Bool [expr "$Inv false"]
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be an integer!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be an integer!"
                        }
                    }
                }
                m {
                    if {$valIdx == 0} {

                        # skip index 0 for group ID
                        set Bool true
                    } else {

                        # If arguments exist, test the 1st argument instead
                        if {[llength $Arg]} {
                            set Val [lindex $Arg 0]
                        }
                        if {$::SimArr(MatDB) eq ""} {
                            error "material database is empty!"
                        }
                        set MatDB $::SimArr(MatDB)

                        # Exact match to avoid multiple matches
                        set Mat [lsearch -inline -regexp\
                            [lindex $MatDB 0] (?i)^$Val$]
                        if {$Mat eq ""} {
                            set Bool [expr "$Inv false"]
                        } else {
                            set Bool [expr "$Inv true"]

                            # No arguments, update the current element
                            if {![llength $Arg]} {
                                lset varVal $valIdx $Mat
                            }
                        }
                        if {!$Bool && $Vital} {
                            if {$Inv eq ""} {
                                error "element '$Val' of '$varVal' should\
                                    be a material, check 'datexcodes.txt'!"
                            } else {
                                error "element '$Val' of '$varVal' should\
                                    NOT be a material!"
                            }
                        }
                    }
                }
                n {

                    # If arguments exist, test the 1st argument instead
                    # Verification of multiple arguments is possible but
                    # the rules for input get inconsistent and it is more
                    # complicated
                    if {[llength $Arg]} {
                        set Val [lindex $Arg 0]
                    }
                    if {[string is double -strict $Val]} {
                        set Flg true
                    } else {
                        if {[catch {set Val [evalNum $Val $DimLst $varVal]}]} {
                            set Flg false
                        } else {
                            if {[string is double -strict $Val]} {
                                set Flg true
                            } else {
                                set Flg false
                            }
                        }
                    }
                    if {$Flg} {
                        set Bool [expr "$Inv true"]

                        # No arguments, update the current element
                        if {![llength $Arg]} {

                            # Format each number to its proper form
                            lset varVal $valIdx [format %.12g $Val]
                        }
                    } else {
                        set Bool [expr "$Inv false"]
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be a number!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be a number!"
                        }
                    }
                }
                o {
                    if {$valIdx == 0} {

                        # skip index 0 for group ID
                        set Bool true
                    } else {

                        # Not required at the moment
                    }
                }
                q {
                    if {$valIdx == 0} {

                        # skip index 0 for group ID
                        set Bool true
                    } else {

                        # Not required at the moment
                    }
                }

                # This test does not apply for a previous index
                s {

                    # Arguments have to be present
                    if {[llength $Arg] == 0} {
                        error "No pattern for '$Test', check rule!"
                    }

                    # Multiple choices
                    if {[regexp {^\w+,\w+} $Val]} {
                        set Lst [list]
                        foreach Elm [split $Val ,] {
                            if {$Vital} {
                                lappend Lst [iSwitch !Dflt $Elm $Arg]
                            } else {
                                lappend Lst [iSwitch Dflt $Elm $Arg]
                            }
                        }
                        lset varVal $valIdx $Lst
                    } else {
                        if {$Vital} {
                            lset varVal $valIdx [iSwitch !Dflt $Val $Arg]
                        } else {
                            lset varVal $valIdx [iSwitch Dflt $Val $Arg]
                        }
                    }
                    set Bool [expr "$Inv true"]
                }
                t {

                    # If arguments exist, test the 1st argument instead
                    if {[llength $Arg]} {
                        set Val [lindex $Arg 0]
                    }
                    if {[string is true -strict $Val]} {
                        set Bool [expr "$Inv true"]
                    } else {
                        set Bool [expr "$Inv false"]
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be true!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                be false!"
                        }
                    }
                }
                v {
                    if {$valIdx == 0} {

                        # Skip index 0 for group ID
                        set Bool true
                    } else {
                        if {[llength $Arg]} {

                            # If arguments exist, test the 1st argument instead
                            set Val [lindex $Arg 0]

                            # Rough check for a previous index
                            if {[regexp {^[vV](\d+)$} $Val]} {
                                set Bool [expr "$Inv true"]
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        } else {
                            if {[regexp {^[vV](\d+)$} $Val -> VStr]} {

                                # No multiple levels for 'VarVary'
                                if {[llength $::SimArr(VarLen)] == 1} {
                                    if {[catch {set Idx [readIdx $VStr\
                                        $::SimArr(VarLen)]}]} {
                                        error "'$Val' index out of range!"
                                    }
                                } else {
                                    foreach Len $::SimArr(VarLen) {
                                        if {[catch {set Idx [readIdx $VStr\
                                            $Len]}]} {
                                            error "'$Val' index out of range!"
                                        }
                                    }
                                }
                                set Bool [expr "$Inv true"]

                                # Update the current element
                                lset varVal $valIdx v$VStr]
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        }
                        if {!$Bool && $Vital} {
                            if {$Inv eq ""} {
                                error "element '$Val' of '$varVal' should\
                                    be a ref to a variable in 'VarVary'!"
                            } else {
                                error "element '$Val' of '$varVal' should\
                                    NOT be a ref to a variable in 'VarVary'!"
                            }
                        }
                    }
                }
                p {
                    if {$valIdx == 0} {

                        # Skip index 0 for group ID
                        set Bool true
                    } else {
                        if {[llength $Arg]} {

                            # If arguments exist, test the 1st argument instead
                            set Val [lindex $Arg 0]

                            # Rough check for a previous index
                            if {[regexp ^\[pP\]($RE_p)$ $Val]} {
                                set Bool [expr "$Inv true"]
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        } else {
                            set Lst [verifyPos $Val $Test $DimLst $varVal]
                            if {[llength $Lst]} {
                                set Bool [expr "$Inv true"]

                                # Update the current element
                                lset varVal $valIdx $Lst
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        }
                        if {!$Bool && $Vital} {
                            if {$Inv eq ""} {
                                error "element '$Val' of '$varVal' should\
                                    be a point!"
                            } else {
                                error "element '$Val' of '$varVal' should\
                                    NOT be a point!"
                            }
                        }
                    }
                }
                pp {
                    if {$valIdx == 0} {

                        # skip index 0 for group ID
                        set Bool true
                    } else {

                        # If arguments exist, test the 1st argument instead
                        if {[llength $Arg]} {
                            set Val [lindex $Arg 0]

                            # Rough check for a previous index
                            if {[regexp ^\[pP\]($RE_p//$RE_p)$ $Val]} {
                                set Bool [expr "$Inv true"]
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        } else {
                            set Lst [verifyPos $Val $Test $DimLst $varVal]

                            # Verify and sort the positions
                            if {[llength $Lst]} {

                                set Bool [expr "$Inv true"]

                                # Update the current element
                                lset varVal $valIdx $Lst
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        }
                        if {!$Bool && $Vital} {
                            if {$Inv eq ""} {
                                error "element '$Val' of '$varVal' should\
                                    be a box!"
                            } else {
                                error "element '$Val' of '$varVal' should\
                                    NOT be a box!"
                            }
                        }
                    }
                }
                r {
                    if {$valIdx == 0} {

                        # Skip index 0 for group ID
                        set Bool true
                    } else {
                        if {[llength $Arg]} {

                            # If arguments exist, test the 1st argument instead
                            set Val [lindex $Arg 0]

                            # Rough check for a previous index
                            if {[regexp {^[rR](\d+)$} $Val]} {
                                set Bool [expr "$Inv true"]
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        } else {
                            set RE_r {(-?\d+[:,])*-?\d+}
                            if {[regexp -nocase ^r($RE_r)$ $Val -> RStr]} {

                                # Read an index string and verify region indices
                                if {[catch {set IdxLst [readIdx $RStr\
                                    $RegLen]}]} {
                                    error "'$Val' index out of range!"
                                }
                                set Bool [expr "$Inv true"]

                                # Update the current element
                                set Lst [list]
                                foreach Idx $IdxLst {
                                    lappend Lst r$Idx
                                }
                                lset varVal $valIdx $Lst
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        }
                        if {!$Bool && $Vital} {
                            if {$Inv eq ""} {
                                error "element '$Val' of '$varVal' should\
                                    be a region!"
                            } else {
                                error "element '$Val' of '$varVal' should\
                                    NOT be a region!"
                            }
                        }
                    }
                }
                rr {
                    if {$valIdx == 0} {

                        # Skip index 0 for group ID
                        set Bool true
                    } else {

                        # If arguments exist, test the 1st argument instead
                        if {[llength $Arg]} {
                            set Val [lindex $Arg 0]

                            # Rough check for a previous index
                            if {[regexp {^[rR](\d+/\d+)$} $Val]} {
                                set Bool [expr "$Inv true"]
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        } else {
                            if {[regexp {^[rR](\d+/\d+)$} $Val -> RStr]} {

                                # Read an index string and verify region indices
                                if {[catch {set Idx [readIdx $RStr $RegLen]}]} {
                                    error "'$Val' index out of range!"
                                }
                                set Bool [expr "$Inv true"]

                                # Update the current element
                                lset varVal $valIdx r[join $Idx /]]
                            } else {
                                set Bool [expr "$Inv false"]
                            }
                        }
                        if {!$Bool && $Vital} {
                            if {$Inv eq ""} {
                                error "element '$Val' of '$varVal' should\
                                    be a region interface!"
                            } else {
                                error "element '$Val' of '$varVal' should\
                                    NOT be a region interface!"
                            }
                        }
                    }
                }
                x {
                    if {[llength $Arg]} {

                        # If arguments exist, test the 1st argument instead
                        set Val [lindex $Arg 0]

                        # Rough check for a previous index
                        if {[regexp ^\[xX\]$RE_n$ $Val]} {
                            set Bool [expr "$Inv true"]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    } else {
                        if {[regexp ^\[xX\]($RE_n)$ $Val -> CStr]} {
                            set XMin [lindex $XLst 0]
                            set XMax [lindex $XLst end]

                            # Make sure X is within simulation domain
                            if {$CStr < $XMin || $CStr > $XMax} {
                                error "element '$Val' of '$varVal' beyond\
                                    simulation domain($XMin $XMax)!"
                            }
                            set Bool [expr "$Inv true"]

                            # Update the current element
                            lset varVal $valIdx x[format %.12g $CStr]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be an X coordinate!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be an X coordinate!"
                        }
                    }
                }
                xx {
                    if {[llength $Arg]} {

                        # If arguments exist, test the 1st argument instead
                        set Val [lindex $Arg 0]

                        # Rough check for a previous index
                        if {[regexp ^\[xX\]$RE_c$ $Val]} {
                            set Bool [expr "$Inv true"]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    } else {
                        if {[regexp ^\[xX\]($RE_c)$ $Val -> CStr]} {
                            set XMin [lindex $XLst 0]
                            set XMax [lindex $XLst end]
                            set CLst [lsort -real [string map {// " "} $CStr]]
                            set Lst [list]
                            foreach Elm $CLst {

                                # Make sure X is within simulation domain
                                if {$Elm < $XMin || $Elm > $XMax} {
                                    error "element '$Val' of '$varVal' beyond\
                                        simulation domain($XMin $XMax)!"
                                }
                                lappend Lst [format %.12g $Elm]
                            }
                            if {[lindex $CLst 0] == [lindex $CLst 1]} {
                                error "X coordinates in element '$Val' of\
                                    '$varVal' should be different!"
                            }
                            set Bool [expr "$Inv true"]

                            # Update the current element
                            lset varVal $valIdx x[join $Lst /]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be two X coordinates!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be two X coordinates!"
                        }
                    }
                }
                y {
                    if {[llength $Arg]} {

                        # If arguments exist, test the 1st argument instead
                        set Val [lindex $Arg 0]

                        # Rough check for a previous index
                        if {[regexp ^\[yY\]$RE_n$ $Val]} {
                            set Bool [expr "$Inv true"]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    } else {
                        if {[regexp ^\[yY\]($RE_n)$ $Val -> CStr]} {
                            if {[llength $YLst] == 0} {
                                error "element '$Val' of '$varVal': no Y\
                                    coordinate allowed for 1D!"
                            }

                            # Make sure Y is within simulation domain
                            set YMin [lindex $YLst 0]
                            set YMax [lindex $YLst end]
                            if {$CStr < $YMin || $CStr > $YMax} {
                                error "element '$Val' of '$varVal' beyond\
                                    simulation domain($YMin $YMax)!"
                            }
                            set Bool [expr "$Inv true"]

                            # Update the current element
                            lset varVal $valIdx y[format %.12g $CStr]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be an Y coordinate!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be an Y coordinate!"
                        }
                    }
                }
                yy {
                    if {[llength $Arg]} {

                        # If arguments exist, test the 1st argument instead
                        set Val [lindex $Arg 0]

                        # Rough check for a previous index
                        if {[regexp ^\[yY\]$RE_c$ $Val]} {
                            set Bool [expr "$Inv true"]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    } else {
                        if {[regexp ^\[yY\]($RE_c)$ $Val -> CStr]} {
                            if {[llength $YLst] == 1} {
                                error "element '$Val' of '$varVal': no Y\
                                    coordinates allowed for 1D!"
                            }
                            set YMin [lindex $YLst 0]
                            set YMax [lindex $YLst end]
                            set CLst [lsort -real [string map {// " "} $CStr]]
                            set Lst [list]
                            foreach Elm $CLst {

                                # Make sure Y is within simulation domain
                                if {$Elm < $YMin || $Elm > $YMax} {
                                    error "element '$Val' of '$varVal' beyond\
                                        simulation domain($YMin $YMax)!"
                                }
                                lappend Lst [format %.12g $Elm]
                            }
                            if {[lindex $CLst 0] == [lindex $CLst 1]} {
                                error "Y coordinates in element '$Val' of\
                                    '$varVal' should be different!"
                            }
                            set Bool [expr "$Inv true"]

                            # Update the current element
                            lset varVal $valIdx y[join $Lst /]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be two Y coordinates!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be two Y coordinates!"
                        }
                    }
                }
                z {
                    if {[llength $Arg]} {

                        # If arguments exist, test the 1st argument instead
                        set Val [lindex $Arg 0]

                        # Rough check for a previous index
                        if {[regexp ^\[zZ\]$RE_n$ $Val]} {
                            set Bool [expr "$Inv true"]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    } else {
                        if {[regexp ^\[zZ\]($RE_n)$ $Val -> CStr]} {
                            if {[llength $ZLst] == 0} {
                                error "element '$Val' of '$varVal': no Z\
                                    coordinate allowed for non-3D!"
                            }

                            # Make sure Z is within simulation domain
                            set ZMin [lindex $ZLst 0]
                            set ZMax [lindex $ZLst end]
                            if {$CStr < $ZMin || $CStr > $ZMax} {
                                error "element '$Val' of '$varVal' beyond\
                                    simulation domain($ZMin $ZMax)!"
                            }
                            set Bool [expr "$Inv true"]

                            # Update the current element
                            lset varVal $valIdx z[format %.12g $CStr]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be a Z coordinate!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be a Z coordinate!"
                        }
                    }
                }
                zz {
                    if {[llength $Arg]} {

                        # If arguments exist, test the 1st argument instead
                        set Val [lindex $Arg 0]

                        # Rough check for a previous index
                        if {[regexp ^\[zZ\]$RE_c$ $Val]} {
                            set Bool [expr "$Inv true"]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    } else {
                        if {[regexp ^\[zZ\]($RE_c)$ $Val -> CStr]} {
                            if {[llength $ZLst] == 0} {
                                error "element '$Val' of '$varVal': no Z\
                                    coordinates allowed for non-3D!"
                            }
                            set ZMin [lindex $ZLst 0]
                            set ZMax [lindex $ZLst end]
                            set CLst [lsort -real [string map {// " "} $CStr]]
                            set Lst [list]
                            foreach Elm $CLst {

                                # Make sure Z is within simulation domain
                                if {$Elm < $ZMin || $Elm > $ZMax} {
                                    error "element '$Val' of '$varVal' beyond\
                                        simulation domain($ZMin $ZMax)!"
                                }
                                lappend Lst [format %.12g $Elm]
                            }
                            if {[lindex $CLst 0] == [lindex $CLst 1]} {
                                error "Z coordinates in element '$Val' of\
                                    '$varVal' should be different!"
                            }
                            set Bool [expr "$Inv true"]

                            # Update the current element
                            lset varVal $valIdx z[join $Lst /]
                        } else {
                            set Bool [expr "$Inv false"]
                        }
                    }
                    if {!$Bool && $Vital} {
                        if {$Inv eq ""} {
                            error "element '$Val' of '$varVal' should\
                                be two Z coordinates!"
                        } else {
                            error "element '$Val' of '$varVal' should\
                                NOT be two Z coordinates!"
                        }
                    }
                }
                default {
                    error "unknown test '$Test'!"
                }
            }
        }
        if {$Bool && $DfltVal ne ""} {
            if {$valIdx < [llength $varVal]} {
                lset varVal $valIdx $DfltVal
            } else {
                lappend varVal $DfltVal
            }
        }
        if {$Bool} {
            if {$Test eq "s"} {
                # vputs -v5 -c " -> '[lindex $varVal $valIdx]'"
            } else {
                # vputs -v5 -c " -> 'true'"
            }
        } else {
            # vputs -v5 -c " -> 'false'"
        }
        return $Bool
    }

    # grmLexer
        # Lexer, scanner or tokenizer. Break a string into multiple tokens
    # Result: Return a token
    proc grmLexer {} {
        variable grmStr

        if {[llength $grmStr]} {
            set Token [lindex $grmStr 0]

            # Check token in case a space is missing for '(', ')', '&', '|'
            if {[string length $Token] > 1} {
                if {[regexp {^\(.+\)} $Token]} {

                    # In this case parentheses are not seperate tokens
                    # Ignore such a case
                } elseif {[string index $Token 0] eq "("} {
                    lset grmStr 0 [string range $Token 1 end]
                    return (
                } elseif {[regexp {(\)+)$} $Token -> Str]} {

                    # 'regexp' is greedy, all ')' will be extracted to 'Str'
                    if {$Token eq $Str} {
                        lset grmStr 0 [string range $Str 1 end]
                        return )
                    } else {
                        lset grmStr 0 $Str
                        return [string range $Token 0 end-[string length $Str]]
                    }
                } elseif {[regexp {^(&+|\|+)$} $Token]} {
                    set grmStr [lrange $grmStr 1 end]

                    # Multiple '&' -> '&'; multiple '|' -> '|'
                    return [string index $Token 0]
                } elseif {[regexp {^(&+|\|+)} $Token -> Str]} {
                    lset grmStr 0 [string range $Token [string length $Str] end]
                    return [string index $Token 0]
                } elseif {[regexp {(&+|\|+)$} $Token -> Str]} {
                    lset grmStr 0 [string index $Token end]
                    return [string range $Token 0 end-[string length $Str]]
                }
            }
            set grmStr [lrange $grmStr 1 end]
            return $Token
        }
        return EOF
    }

    # grmFactor
        # EBNF grammar:
        # <factor>::=<rule> | "(" <expr> ")"
        # Parse each rule into a test with arguments and default value
        # Proceed to a special token (&, | ), EOF)
    # Result: Return the result of a test or false if a test is skipped
    proc grmFactor {} {
        variable currToken
        variable nestLvl
        variable ruleChk

        set currToken [grmLexer]
        if {$currToken eq "("} {

            # Stack up the occurance of the left parenthesis and propagate
            # rule checking settings from the upper level
            incr nestLvl
            lappend ruleChk [list $nestLvl [lindex $ruleChk end 1]]
            set Bool [grmExpr]
            if {$currToken eq ")"} {

                # Reduce the occurance and shrink rule checking level
                incr nestLvl -1
                set ruleChk [lrange $ruleChk 0 end-1]

                # Forward to the next token
                set currToken [grmLexer]
                return $Bool
            } else {
                error "expecting ')'!"
            }
        } else {
            set seekTest true
            set FoundEq false
            set Arg [list]
            set Dflt [list]
            while {1} {
                if {$seekTest} {
                    set Test $currToken
                    set seekTest false
                } else {
                    if {$currToken eq "="} {
                        set FoundEq true
                    } else {
                        if {$FoundEq} {

                            # Convert a string to list
                            lappend Dflt $currToken
                        } else {
                            lappend Arg $currToken
                        }
                    }
                }
                set currToken [grmLexer]
                if {[regexp {^(\&|\||\)|EOF)$} $currToken]} {

                    # Test is always lowercase
                    set Test [string tolower $Test]
                    if {$Dflt eq ""} {
                        if {$Arg eq ""} {
                            set Str $Test
                        } else {
                            set Str "$Test $Arg"
                        }
                    } else {

                        # Default value should has only one element
                        set Dflt [lindex $Dflt 0]
                        if {$Arg eq ""} {
                            set Str "$Test = $Dflt"
                        } else {
                            set Str "$Test $Arg = $Dflt"
                        }
                    }
                    if {[lindex $ruleChk end 1]} {
                        # vputs -n -i3 -v5 "Check '$Str'"
                        return [grmEval $Test $Arg $Dflt]
                    } else {
                        # vputs -i3 -v5 "Ignore '$Str'"
                        return false
                    }
                }
            }
        }
    }

    # grmTerm
        # EBNF grammar:
        # <term>::=<factor> {"&" <factor>}
    # Result: Return a boolean
    proc grmTerm {} {
        variable currToken
        variable ruleChk
        variable nestLvl

        set Bool [grmFactor]

        # If false, no checking of remaining rules
        # However, it is necessary to go through all '&' before returning
        while {$currToken eq "&"} {
            if {$Bool} {
                lset ruleChk $nestLvl 1 true
                set Factor [grmFactor]
                set Bool [expr $Bool && $Factor]
            } else {

                # Scan the rest without evaluating each test (false anyway)
                lset ruleChk $nestLvl 1 false
                set Factor [grmFactor]
            }
        }
        return $Bool
    }

    # grmExpr
        # EBNF grammar:
        # <expr>::=<term> {"|" <term>}
    # Result: Return a boolean
    proc grmExpr {} {
        variable currToken
        variable ruleChk
        variable nestLvl

        set Bool [grmTerm]
        while {$currToken eq "|"} {
            if {$Bool} {

                # Scan the rest without evaluating each test (true anyway)
                # No rule checking until meeting ')'
                if {$nestLvl} {
                    lset ruleChk $nestLvl 1 false
                } else {
                    break
                }
            } else {

                # Reset rule checking based on the upper level
                if {$nestLvl} {
                    lset ruleChk $nestLvl 1 [lindex $ruleChk end-1 1]
                } else {
                    set ruleChk [list [list 0 true]]
                }
            }
            set Term [grmTerm]
            set Bool [expr $Bool || $Term]
        }
        return $Bool
    }

    # applyGrm
        # Some variables contain settings for input values
    # Arguments:
        # VarName         Variable name
        # VarVal          Variable value
        # VarGrm          Variable grammar
    # Result: Return the formatted list
    proc applyGrm {VarName VarVal VarGrm} {
        variable varName
        variable varVal
        variable valIdx
        variable grmStr
        variable ruleChk
        variable nestLvl

        # Extend grammar rules if needed
        set GrmExt false
        if {[lindex $VarGrm end] eq "..."} {
            set VarGrm [lrange $VarGrm 0 end-1]
            set GrmExt true
        }
        set grmLen [llength $VarGrm]
        set Val [llength $VarVal]
        incr Val -$grmLen
        if {!$GrmExt && $Val > 0} {
            vputs -i1 "no rules for elements (index $grmLen and beyond)!"
        }
        if {$GrmExt && $Val > 0} {
            set Grm [lindex $VarGrm end]
            while {$Val > 0} {
                lappend VarGrm $Grm
                incr Val -1
            }
        }

        # Validate each element against the format rule
        set varName $VarName
        set varVal $VarVal
        set valIdx 0
        foreach grmStr $VarGrm {
            vputs -i2 -v5 "'[lindex $varVal $valIdx]': \{$grmStr\}"

            # Initiate these variables
            set nestLvl 0
            set ruleChk [list [list $nestLvl true]]
            if {![grmExpr]} {
                error "dubious rule: '$grmStr'!"
            }
            incr valIdx
        }
        return $varVal
    }
}

package provide mfjGrm $mfjGrm::version
