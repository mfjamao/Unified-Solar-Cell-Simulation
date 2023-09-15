!(

#--- Get TCL environment variables (double quotes are required!)
#include ".mfj/varEnv.tcl"

#--- Get TCL global variables
#include ".mfj/varSim.tcl"

# Load 'SimArr' in 11ctrlsim.tcl
set inf [open 11ctrlsim.tcl r]
set str [read $inf]
close $inf
if {[regexp {array set SimArr \{(.+)\};\#} $str -> tmp]} {
    array set SimArr [regsub -all {\s+} $tmp " "]
} else {
    error "'SimArr' not found in '11ctrlsim.tcl'!"
}

# Source general procedures to reduce lengthy embedded code
source $SimArr(FProc)
namespace import mfjProc::*

# Retrieve more detailed information from 'mfjRegInfo'
# Remove negative RID from 'RegGen'; App1 -> 'RegApp1'; App2 -> 'RegApp2'
# 'RegApp2' needs to be drawn before 'RegApp1'
# Need to remove excess spaces in RegGen and mfjRegInfo
set tmp [info global RegGen<*>]
if {$tmp eq ""} {
    set RegGen [str2List "" [lindex $mfjRegInfo 0]]
} else {
    set idx 0
    upvar 0 $tmp val
    foreach grp [str2List "" $val] {
        if {$grp eq $RegGen} {
            set RegGen [str2List "" [lindex $mfjRegInfo $idx]]
            break
        }
        incr idx
    }
}
set RegApp1 [list]
set RegApp2 [list]
set lst [list]
foreach grp $RegGen {
    set tmp [lindex $grp 1]
    if {[llength $tmp] == 1 && ![string is double -strict $tmp]} {
        lappend RegApp2 $grp
    } else {
        lappend RegApp1 $grp
    }
    if {[string index [lindex $grp 0 1] 0] ne "M" && [lindex $grp 0 end] >= 0} {
        lappend lst $grp
    }
}
set RegGen $lst

# Extract the dimension (1,2,3) from the top dummy layer
set Dim [llength [lindex $RegGen 0 1]]
if {![regexp {^[123]$} $Dim]} {
    error "wrong dimension '$Dim' detected!"
}

# Define two boolean values for easy reference later
set SimEnv [str2List "" $SimEnv]
if {[string index [lindex $SimEnv 2] 0] eq "!"} {
    set Cylind false
} else {
    set Cylind true
}
if {[string index [lindex $SimEnv 3] 0] eq "!"} {
    set OptOnly false
} else {
    set OptOnly true
}

# Extract simulation max size (Dummy layers are ignored)
# Extract the number of regions 'RegLen'
set RegLen [llength $RegGen]
if {$OptOnly} {

    # No dummy layers except the top one
    set XMax [lindex $RegGen end 2 0]
    if {$Dim == 1} {
        set YMax [format %g [lindex $mfjDfltSet 0]]
        set ZMax 0
    } elseif {$Dim == 2} {
        set YMax [lindex $RegGen end 2 1]
        set ZMax 0
    } else {
        set YMax [lindex $RegGen end 2 1]
        set ZMax [lindex $RegGen end 2 2]
    }
} else {
    if {$Dim == 1} {
        set XMax [lindex $RegGen end 1]
        set YMax [format %g [lindex $mfjDfltSet 0]]
        set ZMax 0
    } elseif {$Dim == 2} {
        if {$Cylind} {
            set XMax [lindex $RegGen end-1 1 0]
        } else {
            set XMax [lindex $RegGen end-2 1 0]
        }
        set YMax [lindex $RegGen end 1 1]
        set ZMax 0
    } else {
        set XMax [lindex $RegGen end-4 1 0]
        set YMax [lindex $RegGen end-2 1 1]
        set ZMax [lindex $RegGen end 1 2]
    }
}

# Split 'FldAttr' to 'RegFld' and 'IntfFld' for easier handling
# RegFld format: Region ID, (field ID, value), (field ID, value), ...
# IntfFld format: rr, (profile file, lateral factor), ...
#   (pp Vn), (profile file, lateral factor), ...
set RegFld [list]
set IntfFld [list]
set FldAttr [lsort -index 0 [str2List "" $FldAttr]]

# Alert users to remove/combine duplicate regions/interfaces
if {[llength [lsort -unique -index 0 $FldAttr]] < [llength $FldAttr]} {
    error "duplicate entries found in FldAttr '$FldAttr'!"
}
foreach grp $FldAttr {
    set val [lindex $grp 0]

    # Axis normal interface: Append normal vector
    if {[string index $val 0] eq "p"} {
        set val [list [list $val [intfVn [string range $val 1 end]]]]
    }

    # Go through the rest elements
    set grp [lrange $grp 1 end]
    set lst [list]
    set elm [list]
    while {[llength $grp]} {
        if {[string is double -strict [lindex $grp 0]]} {
            lappend elm [lindex $grp 0]
        } else {
            if {[llength $elm]} {
                if {[file isfile $elm]} {
                    append elm " 1 [lindex $mfjDfltSet 1]"
                } elseif {[llength $elm] == 2
                    && [file isfile [lindex $elm 0]]} {
                    lappend elm [lindex $mfjDfltSet 1]
                }
                lappend lst $elm
            }

            # Translate abbreviations to Sentaurus scalar data names
            if {[file isfile [lindex $grp 0]]} {
                set elm [lindex $grp 0]
            } else {
                set elm [lindex [split\
                    $mfjProc::tabArr([lindex $grp 0]) |] 0]
            }
        }
        set grp [lrange $grp 1 end]
    }
    if {[llength $elm]} {
        if {[file isfile $elm]} {
            append elm " 1 [lindex $mfjDfltSet 1]"
        } elseif {[llength $elm] == 2 && [file isfile [lindex $elm 0]]} {
            lappend elm [lindex $mfjDfltSet 1]
        }
        lappend lst $elm
    }

    # Sort region (field value) or interface (file lateralfactor)
    set tmp [lsort -index 0 $lst]

    # Alert users to remove/combine duplicate fields/files
    if {[llength [lsort -unique -index 0 $tmp]] < [llength $tmp]} {
        error "duplicate fields/files found in FldAttr '$val $tmp'!"
    }
    set lst [concat $val $tmp]
    if {[regexp {^r\d+$} $val]} {
        lappend RegFld $lst
    } else {
        lappend IntfFld $lst
    }
}

# Further process 'IntfFld' and extract trap settings if any
# RegIntfFld format: (regionID (fieldID depth) ...) ...
# RegIntfTrap format: (regionID (fieldID trap settings) ...) ...
set RegIntfFld [list]
set RegIntfTrap [list]
set idx 0
foreach grp $IntfFld {
    if {[regexp {^r(\d+)/(\d+)$} [lindex $grp 0] -> var val]} {
        if {[catch {lset grp 0 [rr2pp $RegGen $var $val]} err]} {
            vputs "\n;# warning: $err!"
        }
    } else {
        lset grp 0 [split [split [string range [lindex $grp 0 0] 1 end] _] /]
    }
    set cnt 1
    foreach elm [lrange $grp 1 end] {
        array unset arr
        readTT arr [lindex $elm 0] [lindex $elm 1]
        if {[info exists arr(Field)] && [llength $arr(Field)]} {

            # Update the original interface field file to n@node@_xxx.plx
            set str n@node@_[file rootname [file tail [lindex $elm 0]]].plx
            lset IntfFld $idx $cnt 0 $str
            file rename -force $arr(FFld) $str
        } else {
            error "no depth-field pairs found in '[lindex $elm 0]'!"
        }
        if {[string index [lindex $grp 0] 0] ne "r"} {
            foreach reg $RegGen {
                if {[lindex $reg 0 2] ne "Semiconductor"
                    || ([llength [lindex $reg 1]] == 1
                    && ![string is double [lindex $reg 1]]
                    && [lindex $reg 1] ne "Block")} continue
                set val [overlap [lindex $grp 0] [lindex $arr(Field) end 0]\
                    $reg]
                if {$val > 0} {
                    set flg true
                    set lst [list]
                    foreach var $RegIntfFld {
                        if {[lindex $var 0] eq "r[lindex $reg 0 end]"} {
                            lappend var [list $arr(ID) $val]
                            set var [concat [lindex $var 0] [lsort -unique\
                                -index 0 [lrange $var 1 end]]]
                            set flg false
                        }
                        lappend lst $var
                    }
                    if {$flg} {
                        lappend RegIntfFld [list r[lindex $reg 0 end]\
                            [list $arr(ID) $val]]
                    } else {
                        set RegIntfFld $lst
                    }
                    if {[info exists arr(TrapNat)]} {
                        set flg true
                        set lst [list]
                        foreach var $RegIntfTrap {
                            if {[lindex $var 0] eq "r[lindex $reg 0 end]"} {
                                set tmp [list]
                                foreach key [array names arr] {
                                    if {$key ne "ID" && $key ne "Field"
                                        && $key ne "FFld"} {
                                        lappend tmp [list $key $arr($key)]
                                    }
                                }
                                lappend var [concat $arr(ID) $tmp]
                                set var [concat [lindex $var 0] [lsort -unique\
                                    -index 0 [lrange $var 1 end]]]
                                set flg false
                            }
                            lappend lst $var
                        }
                        if {$flg} {
                            set tmp [list]
                            foreach key [array names arr] {
                                if {$key ne "ID" && $key ne "Field"
                                    && $key ne "FFld"} {
                                    lappend tmp [list $key $arr($key)]
                                }
                            }
                            lappend RegIntfTrap [list r[lindex $reg 0 end]\
                                [concat $arr(ID) $tmp]]
                        } else {
                            set RegIntfTrap $lst
                        }
                    }
                }
            }
        }
        incr cnt
    }
    incr idx
}
set RegIntfFld [lsort -index 0 $RegIntfFld]
set RegIntfTrap [lsort -index 0 $RegIntfTrap]

# Set the default mesh, numeric, and other settings for 'DfltAttr'
if {![regexp {\{Mesh\s} $DfltAttr]} {
    lappend DfltAttr [list Mesh 10 0.05 8 0.001 8 1.5 0.001 1.1]
}
if {![regexp {\{Numeric\s} $DfltAttr]} {
    lappend DfltAttr [list Numeric 64]
}
if {![regexp {\{Other\s} $DfltAttr]} {
    lappend DfltAttr [list Other 25]
}

# Seperate interfaces from 'IntfAttr' and check duplicates
# 'IntfSRV': the SRH recombiantion interfaces using SRVs
# 'IntfTrap': the SRH recombiantion interfaces using trap settings
# 'IntfCon': only contacts
# 'IntfTun': the tunnel interfaces, skip duplicate check
foreach elm {IntfSRV IntfTrap IntfCon IntfTun lst} {
    set $elm [list]
}
set IntfAttr [str2List "" $IntfAttr]
foreach grp $IntfAttr {
    set lst [string map {r "" / " "} [lindex $grp 0]]
    regsub {^r(\d+)/(\d+)} $grp {r\2/\1} str
    if {[regexp {^c\d$} [lindex $grp 1]]} {
        set var [concat $IntfCon [list $str]]
        set val [concat $IntfCon [list $grp]]
        lappend IntfCon $grp
    } elseif {[string is double -strict [lindex $grp 1]]} {
        if {[string is double -strict [lindex $grp 2]]
            && [lindex $RegGen [lindex $lst 0] 0 2] ne "Semiconductor"
            && [lindex $RegGen [lindex $lst 1] 0 2] ne "Semiconductor"} {
            error "either 'r[lindex $lst 0]' or 'r[lindex $lst 1]' should\
                be semiconductor!"
        } else {
            set var [concat $IntfSRV [list $str]]
            set val [concat $IntfSRV [list $grp]]
            lappend IntfSRV $grp
        }
    } elseif {[file isfile [lindex $grp 1]]} {
        set var [concat $IntfTrap [list $str]]
        set val [concat $IntfTrap [list $grp]]
        lappend IntfTrap $grp
    } else {
        lappend IntfTun $grp
    }

    # Alert users to remove/combine duplicate interface attributes
    if {[llength [lsort -unique -index 0 $var]] < [llength $var]
        || [llength [lsort -unique -index 0 $val]] < [llength $val]} {
        error "duplicate '$grp' found in IntfAttr '[lrange $var 0 end-1]'!"
    }
}

# Make sure a contact is not used for other interfaces
foreach grp $IntfCon {
    regsub {r(\d+)/(\d+)} [lindex $grp 0] {r\2/\1} str
    if {[regexp \\\{([lindex $grp 0]|$str)\\s $IntfSRV -> val]} {
        error "interface '$val' of $IntfSRV is already the contact\
            '[lindex $grp 1]'!"
    }
    if {[regexp \\\{([lindex $grp 0]|$str)\\s $IntfTrap -> val]} {
        error "interface '$val' of $IntfTrap is already the contact\
            '[lindex $grp 1]'!"
    }
    if {[regexp \\\{([lindex $grp 0]|$str)\\s $IntfTun -> val]} {
        error "interface '$val' of $IntfTun is already the contact\
            '[lindex $grp 1]'!"
    }
}

# Check whether 'AbsorbedPhotonDensity' is found in 'FldAttr', or more
# precisely, 'RegFld' and 'RegIntfFld' and set 'LoadTDR'
set LoadTDR false
if {[regexp {\{AbsorbedPhotonDensity\s} $RegFld]
    || [regexp {\{AbsorbedPhotonDensity\s} $RegIntfFld]} {
    set LoadTDR true
}

# Disable LoadTDR for optical only simulation
if {$OptOnly} {
    set LoadTDR false
}

# Check whether 'GopAttr' lacks an optical solver
if {!$LoadTDR && [llength $GopAttr]
    && ![regexp {\s(OBAM|TMM|Raytrace|External)(\s|\})} $GopAttr]} {
    error "no optical solver specified!"
}

# Make sure all optical windows for External, OBAM, TMM and Raytrace face
# the same direction (light propagation direction LPD is either 1 or -1)
# Convert ri/j to pp list 'GopPP'
set txt ""
set LPD 0
set GopPP [list]
set GopAttr [str2List "" $GopAttr]
foreach grp $GopAttr {
    if {[regexp {^(OBAM|TMM|Raytrace|External)$} [lindex $grp 1]]} {
        if {$txt eq ""} {
            set txt [lindex $grp 1]
        } else {
            if {$txt ne [lindex $grp 1]} {
                error "only one optical solver is allowed!"
            }
        }
        if {[regexp {^r(\d+)/(\d+)$} [lindex $grp 0] -> idx val]} {
            set lst [rr2pp $RegGen $idx $val]
        } else {
            set lst [split [split [string range [lindex $grp 0] 1 end] _] /]
        }
        lappend GopPP [concat $lst [lrange $grp 1 end]]

        # Get the normal vector
        set val [lindex [intfVn $lst] 0]
        if {$val == 0} {
            error "optical interface '[lindex $grp 0]' not normal to X axis!"
        }
        if {$LPD != 0} {
            if {$LPD != $val} {
                error "normal vector of '[lindex $grp 0]' (LPD) not '$LPD 0 0'!"
            }
        } else {
            set LPD $val
        }
    }
}

# 'LPD' for raytrace should be 1 in optical only simulation
if {$OptOnly} {
    if {$LPD == 0} {
        error "no optical solver specified!"
    } else {
        if {[regexp {\sExternal\s} $GopAttr]} {
            error "no 'External' solver for optical only simulation!"
        }
        if {[regexp {\sRaytrace\s} $GopAttr] && $LPD == -1} {
            error "light propagation direction not '+X' for raytrace!"
        }
    }
}

# 'Cylindrical' for raytrace is available from M-2016.12
if {[regexp {\sRaytrace\s} $GopAttr] && $Cylind
    && [string compare M-2016.12 [lindex $SimEnv 1]] == 1} {
    error "M-2016.12 and above required for raytrace with cylindrical!"
}

)!

;#--------------------------------------------------------------
(sde:clear)
!(

#--- Pass all global TCL parameters to SCHEME
foreach var {RegGen RegApp1 RegApp2 RegFld IntfFld RegIntfFld RegIntfTrap
    DfltAttr IntfAttr IntfSRV IntfTrap IntfCon IntfTun GopAttr GopPP Cylind
    OptOnly LPD Dim XMax YMax ZMax RegLen} {
    vputs "(define $var [tcl2Scheme $var [set $var]])"
}
regexp {\{Mesh\s+([^\}]+)} $DfltAttr -> val
vputs "(define MeshAttr [tcl2Scheme MeshAttr $val])"
)!

;# Define local scheme procedures for convenience
;# For comparison, it is safer to use equal? instead of eq? and eqv?
;# Display a chain of objects
(define (mfj:display . AnyObject)
    (for-each
        (lambda (Obj)
            (display Obj)
        ) AnyObject
    )
)

;# Convert a value to its half
(define (mfj:half Val)
    (if (number? Val)
        (/ Val 2.)
        (sde:error "not a number!\n")
    )
)

;# Get the sign of a value
(define (mfj:sign Val)
    (if (number? Val)
        (cond
            ((negative? Val) -1)
            ((positive? Val) 1)
            (else 0)
        )
        (sde:error "not a number!\n")
    )
)

;# Logical NOT function
(define (mfj:not Val)
    (if (number? Val)
        (if (= Val 0) 1 0)
        (sde:error "not a number!\n")
    )
)

;# Realise 'compose' function for a chain of functions
;# Note 1: The named 'let' is equivalent to letrec
;# Note 2: The last argument of 'apply' has to be a list
(define (mfj:compose . FLst)
    (lambda args
        (let Next ((f FLst) (x args))
            (if (= (length f) 1)
                (apply (car f) x)
                ((car f) (Next (cdr f) x))
            )
        )
    )
)

;# Convert any value to string
(define (mfj:to-string Val)
    (cond
        ((string? Val) Val)
        ((number? Val) (number->string Val))
        ((symbol? Val) (symbol->string Val))
        ((boolean? Val) (if Val "#t" "#f"))
        ((char? Val) (string Val))
        ((null? Val) "")
        (else (sde:error "unknown value!\n"))
    )
)
;# Split a string according to a delimiting character to a list
(define (mfj:string-split Str SplitChr)
    (let Next ((StrLst (string->list Str)) (ChrLst '()) (Lst '()))
        (if (or (null? StrLst) (char=? (car StrLst) SplitChr))
            (begin
                (define ElmStr (list->string (reverse ChrLst)))
                (set! ChrLst '())
                (if (equal? (string->number ElmStr) #f)
                    (set! Lst (cons ElmStr Lst))
                    (set! Lst (cons (string->number ElmStr) Lst))
                )
            )
            (set! ChrLst (cons (car StrLst) ChrLst))
        )
        (if (null? StrLst)
            (reverse Lst)
            (Next (cdr StrLst) ChrLst Lst)
        )
    )
)

;# Join a list with a seperator
(define (mfj:join Lst SepStr)
    (let Next ((NewLst (cdr Lst)) (Str (mfj:to-string (car Lst))))
        (if (null? NewLst)
            Str
            (Next (cdr NewLst) (string-append Str SepStr
                (mfj:to-string (car NewLst))))
        )
    )
)

;# Extract interface between two 2D bodies and return the edge list
;# Return a polygon list with additional parameters
(define (mfj:extract-2D-interface Reg1 Reg2 . Anything)
    (let ((PLst '()) (Lst '()) (ELst '()) (Idx 0))
        (for-each
            (lambda (E2)
                (set! Lst (find-edge-id (edge:mid-point E2)))
                (if (= (length Lst) 2)
                    (for-each
                        (lambda (E1)
                            (if (member E1 Lst)
                                (set! ELst (cons E2 ELst))
                            )
                        ) (entity:edges (find-region-id Reg1))
                    )
                )
            ) (entity:edges (find-region-id Reg2))
        )
        (if (null? Anything)
            (reverse ELst)
            (begin
                (set! PLst (cons (edge:end (car ELst)) PLst))
                (for-each
                    (lambda (E)
                        (if (> Idx 0)
                            (if (equal? (edge:end E) (car PLst))
                                (set! PLst (cons (edge:start E) PLst))
                                (sde:error "discontinuous interface!")
                            )
                            (set! PLst (cons (edge:start E) PLst))
                        )
                        (set! Idx (+ Idx 1))
                    ) ELst
                )
                (cons (edge:end (car ELst)) PLst)
            )
        )
    )
)

;# Define local scheme variables
(define ElmMax (car MeshAttr))   ;# Over refinement != better convergence
(define ElmMin (cadr MeshAttr))
(define RegSp (caddr MeshAttr))
(define IntfMin (cadddr MeshAttr))
(define MaxLvl (list-ref MeshAttr 4))
(define IntfRat (list-ref MeshAttr 5))    ;# Ratio <= 1.5
(define Var '())
(define Val '())
(define Vn '())
(define Lst '())
(define Str "")
(define MB "")
(define P1 '())
(define P2 '())
(define Idx 0)
(define Flg #f)
(define Offset #f)
(define XCutLst '())
(define YCutLst '())
(define ZCutLst '())

;# Old replaces new
(sdegeo:set-default-boolean "BAB" )

;# All structures generated below comply with UCS (1) instead of DFISE (0).
;# 2D: UCS (up -X, right Y), DFISE (up -Y, right X)
;# 3D: UCS (up -X, right Y, near Z), DFISE (up Z, right Y, near X)
(sde:set-process-up-direction 1)

;# Approach 2 if any
(for-each
    (lambda (RGen)
        (let ((Mat (caar RGen)) (Reg (cadar RGen)) (Shp (cadr RGen)))
            (if (string=? Reg (cadaar RegApp2))
                (mfj:display "Creating regions of special shapes with"
                    " approach 2...\n")
            )
            (mfj:display (make-string 4 #\space) RGen "\n")
            (mfj:display (make-string 8 #\space) "Region: '" Reg
                "', shape: '" Shp "'\n")
            (if (or (string=? Shp "Block") (string=? Shp "Ellipse")
                (string=? Shp "Cone") (string=? Shp "Pyramid"))
                (begin
                    (set! P1 (caddr RGen))
                    (set! P2 (cadddr RGen))
                )
            )
            (cond
                ((string=? Shp "Block")
                    (if (= Dim 3)
                        (sdegeo:create-cuboid
                            (apply position P1) (apply position P2) Mat Reg)
                        (sdegeo:create-rectangle
                            (position (car P1) (cadr P1) 0)
                            (position (car P2) (cadr P2) 0) Mat Reg)
                    )
                )
                ((string=? Shp "Vertices")
                    (set! Lst '())
                    (for-each
                        (lambda (PLst)
                            (set! Lst (cons (position (car PLst) (cadr PLst) 0)
                                Lst))
                        ) (list-tail RGen 2)
                    )
                    (sdegeo:create-polygon (reverse Lst) Mat Reg)
                )
                ((string=? Shp "Ellipse")
                    (if (= Dim 3)
                        (sdegeo:create-ellipsoid
                            (apply position P1) (apply position P2)
                            (list-ref RGen 4) Mat Reg)
                        (sdegeo:create-ellipse
                            (position (car P1) (cadr P1) 0)
                            (position (car P2) (cadr P2) 0)
                            (list-ref RGen 4) Mat Reg)
                    )
                )
                ((string=? Shp "Cone")
                    (if (= (length RGen) 6)
                        (sdegeo:create-cone
                            (apply position P1) (apply position P2)
                            (list-ref RGen 4) (list-ref RGen 5) Mat Reg)
                        (sdegeo:create-cone
                            (apply position P1) (apply position P2)
                            (list-ref RGen 4) (list-ref RGen 5)
                            (list-ref RGen 6) Mat Reg)
                    )
                )

                ;# In DFISE, a pyramid is centered about the origin with its
                ;# height along the z-axis, the major-radius along the x-axis,
                ;# and the minor-radius along the y-axis. To create a pyramid
                ;# along the x-axis, a pyramid should be first created outside
                ;# of simulation domain and perform a mirror and translation
                ((string=? Shp "Pyramid")

                    ;# Due to the strange behaviour of 'create-pyramid' in UCS,
                    ;# the coordinate system is set to DFISE (0) instead
                    (sde:set-process-up-direction 0)
                    (set! Var (gvector:from-to (apply position P1)
                        (apply position P2)))
                    (set! Val (+ (* 5 ZMax) (mfj:half (gvector:length Var))))
                    (sdegeo:create-pyramid
                        (position:+ (apply position P1) (position 0 0 Val))
                        (gvector:length Var) (list-ref RGen 4)
                        (* (list-ref RGen 4) (list-ref RGen 7))
                        (list-ref RGen 6) (list-ref RGen 5) Mat Reg)

                    ;# Mirror according to the interface normal to gvector
                    ;# and to the direction of gvector
                    (sdegeo:mirror-selected (find-region-id Reg)
                        (transform:reflection (position:+ (apply position P1)
                        (position 0 0 (* 5 ZMax)))
                        (gvector:- (gvector:unitize Var) (gvector 0 0 1))) #f)

                    ;# Translate the pyramid back to its original position
                    (sdegeo:translate-selected (find-region-id Reg)
                        (transform:translation (gvector 0 0 (* -5 ZMax))) #f)

                    ;# Revert to UCS (1)
                    (sde:set-process-up-direction 1)
                )
                (else (sde:error (string-append "unknown shape '" Shp "'!\n")))
            )
            (if (char=? (string-ref Reg 0) #\M)
                (begin
                    (set! Str (substring Reg 6 (string-length Reg)))
                    (define Res (sdegeo:bool-unite (list (find-region-id Str)
                        (find-region-id Reg))))
                    (if (boolean? Res)
                        (sde:error (string-append "Can't merge with '" Str
                            "'!\n"))
                        (mfj:display (make-string 12 #\space)
                            "Merged with region '" Str "!'\n")
                    )
                )
            )
        )
    ) RegApp2
)

;# Remove negative RID regions if any
(set! Flg #t)
(for-each
    (lambda (RGen)
        (let ((Reg (cadar RGen)))
            (if (and (char=? (string-ref (cadar RGen) 0) #\-)
                (< (cadddr (car RGen)) 0))
                (begin
                    (if Flg
                        (begin
                            (mfj:display "Removing regions with negative"
                                " region ID...\n")
                            (set! Flg #f)
                        )
                    )
                    (mfj:display (make-string 4 #\space) "Region '" Reg
                        "' removed\n")
                    (entity:delete (find-region-id Reg))
                )
            )
        )
    ) RegApp2
)

;# Trim everything beyond (0 0 0) to (XMax YMax ZMax)
;# 3D can be done with 'sdegeo:body-trim' while 2D is a bit cumbersome
(if (> (length RegApp2) 0)
    (if (= Dim 3)
        (begin
            (mfj:display "3D: Prune everything beyond (0 0 0) to ("
                XMax " " YMax " " ZMax ")\n")
            (sdegeo:body-trim 0 0 0 XMax YMax ZMax)
        )

        ;# let*: initialise from left to right; let: initialise without order
        (let* ((BLst (get-body-list)) (min-x (sde:min-x BLst))
            (max-x (sde:max-x BLst)) (min-y (sde:min-y BLst))
            (max-y (sde:max-y BLst)))
            (mfj:display "2D: Prune everything beyond (0 0) to (" XMax
                " " YMax ")\n")

            ;# New replaces old
            (sdegeo:set-default-boolean "ABA" )
            (for-each
                (lambda (True P1 P2)
                    (if True
                        (begin
                            (sdegeo:create-rectangle P1 P2 "Gas" "Tmp")
                            (sdegeo:delete-region (find-region-id "Tmp"))
                        )
                    )
                ) (list (< min-x 0) (> max-x XMax) (< min-y 0) (> max-y YMax))
                    (list (position 0 min-y 0) (position XMax min-y 0)
                        (position min-x 0 0)(position min-x YMax 0))
                    (list (position min-x max-y 0) (position max-x max-y 0)
                        (position max-x min-y 0) (position max-x max-y 0))
            )

            ;# Revert to "old replaces new"
            (sdegeo:set-default-boolean "BAB" )
        )
    )
)

(mfj:display "Creating regions with approach 1 to form"
    " the simulation domain...\n")
(for-each
    (lambda (RGen)
        (let ((Mat (caar RGen)) (Reg (cadar RGen))
            (P1 (cadr RGen)) (P2 (caddr RGen)))
            (mfj:display (make-string 4 #\space) RGen "\n")
            (mfj:display (make-string 8 #\space) "Region name: '" Reg "'\n")
            (cond
                ((= Dim 1)
                    (sdegeo:create-rectangle (position P1 0 0)
                        (position P2 YMax 0) Mat Reg)
                )
                ((= Dim 2)
                    (sdegeo:create-rectangle
                        (position (car P1) (cadr P1) 0)
                        (position (car P2) (cadr P2) 0) Mat Reg)
                )
                (else
                    (sdegeo:create-cuboid
                        (apply position P1) (apply position P2) Mat Reg)
                    (if (and (> (caddr P1) 0) (< (caddr P1) ZMax)
                        (not (member (caddr P1) ZCutLst)))
                        (set! ZCutLst (cons (caddr P1) ZCutLst))
                    )
                )
            )
            (if (= Dim 1)
                (if (and (> P1 0) (< P1 XMax)
                    (not (member P1 XCutLst)))
                    (set! XCutLst (cons P1 XCutLst))
                )
                (if (and (> (car P1) 0) (< (car P1) XMax)
                    (not (member (car P1) XCutLst)))
                    (set! XCutLst (cons (car P1) XCutLst))
                )
            )
            (if (and (>= Dim 2) (> (cadr P1) 0)
                (< (cadr P1) YMax) (not (member (cadr P1) YCutLst)))
                (set! YCutLst (cons (cadr P1) YCutLst))
            )
        )
    ) RegApp1
)

;# Double check whether the number of regions in SDE tally with that in 'RegGen'
(mfj:display "Double check the created " (length (get-body-list)) " regions:\n")
(if (= (length (get-body-list)) (length RegGen))
    (for-each
        (lambda (BID)
            (mfj:display (make-string 4 #\space)(generic:get BID "region") "\n")
        ) (get-body-list)
    )
    (sde:error (string-append "final region number '" (number->string
        (length (get-body-list))) "' different from 'RegGen'!\n"))
)

(for-each
    (lambda (RFld)
        (let* ((RStr (car RFld))
            (RIdx (string->number (substring RStr 1 (string-length RStr))))
            (Reg (cadar (list-ref RegGen RIdx)))
            (Grp (caddar (list-ref RegGen RIdx))))
            (if (string=? RStr (caar RegFld))
                (mfj:display "Introducing constant region fields to"
                    " semiconductor regions...\n")
            )
            (mfj:display (make-string 4 #\space) RFld "\n")

            ;# Field and value pairs
            (for-each
                (lambda (FLst)
                    (let ((Name (string-append Reg "-" (car FLst))))
                        (if (> (cadr FLst) 0)
                            (begin
                                (mfj:display (make-string 8 #\space)
                                    "Region field: '" Name "'\n")
                                (apply sdedr:define-constant-profile Name FLst)
                                (sdedr:define-constant-profile-region Name Name
                                    Reg)
                            )
                        )
                    )
                ) (cdr RFld)
            )
        )
    ) RegFld
)

;# Interface fields have a direction either from Reg1 to Reg2 or right-hand rule
(for-each
    (lambda (IFld)
        (let* ((IntfID (car IFld)) (Idx 0) (F1D "") (IntfStr "") (IntfLst '()))
            (if (equal? IntfID (caar IntfFld))
                (mfj:display "Introducing interface field profiles...\n")
            )
            (mfj:display (make-string 4 #\space) IFld "\n")
            (if (list? IntfID)
                (set! IntfStr (car IntfID))
                (set! IntfStr IntfID)
            )
            (set! IntfLst (mfj:string-split
                (substring IntfStr 1 (string-length IntfStr)) #\/))
            (define Intf (string-append "IntfFld-" IntfStr))
            (if (list? IntfID)
                (begin
                    (set! Str "Line")
                    (if (= Dim 1)
                        (if (string=? (cadr IntfLst) "+")
                            (begin
                                (set! P1 (list (car IntfLst) YMax 0))
                                (set! P2 (list (car IntfLst) 0 0))
                            )
                            (begin
                                (set! P1 (list (car IntfLst) 0 0))
                                (set! P2 (list (car IntfLst) YMax 0))
                            )
                        )
                        (begin
                            (set! P1 (mfj:string-split (car IntfLst) #\_))
                            (set! P2 (mfj:string-split (cadr IntfLst) #\_))
                            (if (= Dim 2)
                                (begin
                                    (set! P1 (append P1 '(0)))
                                    (set! P2 (append P2 '(0)))
                                )
                                (set! Str "Rectangle")
                            )
                        )
                    )
                    (sdedr:define-refeval-window Intf Str
                        (apply position P1) (apply position P2))
                )
                (begin
                    (define Reg1 (cadar (list-ref RegGen (car IntfLst))))
                    (define Reg2 (cadar (list-ref RegGen (cadr IntfLst))))

                    ;# 'sdedr:define-body-interface-refwin' works fine for 3D
                    ;# For 2D, however, it only works for one-edge interface
                    (if (= Dim 3)
                        (begin
                            (sdedr:define-body-interface-refwin (list
                                (find-region-id Reg1) (find-region-id Reg2))
                                Intf)
                            (if (null? (find-drs-id Intf))
                                (sde:error "no interface found!")
                            )
                            (for-each
                                (lambda (F)
                                    (mfj:display (make-string 8 #\space)
                                        "Face " Idx " Vertex positions: \n"
                                        (make-string 12 #\space))
                                    (for-each
                                        (lambda (V)
                                            (mfj:display (vertex:position V)
                                                " ")
                                        ) (entity:vertices F)
                                    )(newline)
                                    (mfj:display (make-string 8 #\space)
                                        "Normal vector: " (face:plane-normal F)
                                        "\n")
                                    (set! Idx (+ Idx 1))
                                ) (entity:faces (find-drs-id Intf))
                            )
                        )
                        (begin
                            (sdedr:define-body-interface-refwin (list
                                (find-region-id Reg2) (find-region-id Reg1))
                                Intf)

                            ;# Manually search for the interfaces
                            (if (null? (find-drs-id Intf))
                                (begin
                                    (mfj:display (make-string 8 #\space)
                                        "interface not found with "
                                        "'sdedr:define-body-interface-refwin'"
                                        "\n")
                                    (set! Var (mfj:extract-2D-interface Reg1
                                        Reg2 ""))
                                    (mfj:display (make-string 8 #\space)
                                        "manually extract interface polygon:\n")
                                    (for-each
                                        (lambda (P)
                                            (mfj:display

                                                ;# Weird! char should be at the
                                                ;# same line with make-string
                                                ;# Otherwise, premature end of
                                                ;# file error
                                                (make-string 12 #\space) P "\n")
                                        ) Var
                                    )
                                    (if (null? Var)
                                        (sde:error "no interface found!")
                                    )
                                    (sdedr:define-refeval-window Intf "Polygon"
                                        Var)
                                )
                                (begin
                                    (set! Var ((mfj:compose car entity:edges
                                        find-drs-id) Intf))
                                    (mfj:display (make-string 8 #\space)
                                        "Edge 0 " (edge:start Var) " -> "
                                        (edge:end Var) "\n")
                                    (set! Vn (gvector:from-to (edge:start Var)
                                        (edge:end Var)))
                                    (set! Vn ((mfj:compose gvector:unitize
                                        gvector) (- (gvector:y Vn))
                                        (gvector:x Vn) 0))
                                    (mfj:display (make-string 8 #\space)
                                        "Normal vector: " Vn "\n")
                                )
                            )
                        )
                    )
                )
            )
            (mfj:display (make-string 8 #\space) "Interface ID: '" Intf "'\n")
            (for-each
                (lambda (FLst)
                    (set! F1D (string-append (car FLst) "-" IntfStr))
                    (mfj:display (make-string 8 #\space)
                        "Interface profile: '" F1D "'\n")
                    (sdedr:define-1d-external-profile F1D (car FLst) "Scale" 1
                        "Gauss" "Factor" (cadr FLst))
                    (sdedr:define-analytical-profile-placement F1D F1D Intf
                        "Positive" "NoReplace" "Eval")
                ) (cdr IFld)
            )
        )
    ) IntfFld
)

;# Metal contacts have no direction
(for-each
    (lambda (Con)
        (let* ((RStr (car Con)) (RRLst
            (mfj:string-split (substring RStr 1 (string-length RStr)) #\/))
            (Reg1 (cadar (list-ref RegGen (car RRLst))))
            (Reg2 (cadar (list-ref RegGen (cadr RRLst))))
            (Intf (string-append "Contact-" RStr)))
            (if (string=? RStr (caar IntfCon))
                (mfj:display "Introducing metal contacts...\n")
            )
            (mfj:display (make-string 4 #\space) Con "\n")

            ;# 'sdedr:define-body-interface-refwin' works fine for 3D
            ;# For 2D, however, it only works for one-edge interface
            (if (= Dim 3)
                (begin
                    (sdedr:define-body-interface-refwin (list
                        (find-region-id Reg1) (find-region-id Reg2)) Intf)
                    (if (null? (find-drs-id Intf))
                        (sde:error "no interface found!")
                    )
                    (set! Lst '())
                    (for-each
                        (lambda (F)
                            (mfj:display (make-string 8 #\space) "Face " Idx
                                " Vertex positions: \n"
                                (make-string 12 #\space))
                            (set! Lst (cons ((mfj:compose find-face-id
                                sdegeo:face-find-interior-point) F) Lst))
                            (for-each
                                (lambda (V)
                                    (mfj:display (vertex:position V) " ")
                                ) (entity:vertices F)
                            )(newline)
                            (set! Idx (+ Idx 1))
                        ) (entity:faces (find-drs-id Intf))
                    )
                )
                (begin
                    (sdedr:define-body-interface-refwin (list
                        (find-region-id Reg2) (find-region-id Reg1)) Intf)

                    ;# Manually search for the interfaces
                    (if (null? (find-drs-id Intf))
                        (begin
                            (mfj:display (make-string 8 #\space) "interface"
                                " not found with"
                                " 'sdedr:define-body-interface-refwin'\n")
                            (set! Var (mfj:extract-2D-interface Reg1 Reg2))
                            (if (null? Var)
                                (sde:error "no interface found!")
                            )
                            (mfj:display (make-string 8 #\space) "manually"
                                " extract interface edges:\n")
                            (set! Lst '())
                            (for-each
                                (lambda (E)
                                    (mfj:display (make-string 8 #\space)
                                        (edge:start E) " -> "
                                        (edge:end E) "\n")
                                    (set! Lst (cons E Lst))
                                ) Var
                            )
                        )
                        (begin
                            (set! Var ((mfj:compose car entity:edges
                                find-drs-id) Intf))
                            (mfj:display (make-string 8 #\space) "Edge 0 "
                                (edge:start Var) " -> " (edge:end Var) "\n")
                            (set! Lst (list ((mfj:compose
                                find-edge-id edge:mid-point) Var)))
                        )
                    )
                )
            )
            (mfj:display (make-string 8 #\space) "Entity list: " Lst "\n")
            (if (= (length Lst) 1)
                (sdegeo:set-contact (car Lst) (cadr Con))
                (sdegeo:set-contact Lst (cadr Con))
            )
        )
    ) IntfCon
)

;# Set refinement properties for curved boundaries
(sde:setrefprops 0.001 15 0 0)

;# Stick to axis aligned mesh for block type of regions. If a non-block region
;# found, enable offsetting mesh
(set! Offset #f)
(for-each
    (lambda (Grp)
        (if (not (member "Block" (car Grp)))
            (set! Offset #t)
        )
    ) RegApp2
)
(for-each
    (lambda (RGen)
        (let* ((Reg (cadar RGen)) (Grp (caddar RGen))
            (RID (find-region-id Reg))
            (min-x (sde:min-x RID)) (min-y (sde:min-y RID))
            (min-z (sde:min-z RID)) (max-x (sde:max-x RID))
            (max-y (sde:max-y RID)) (max-z (sde:max-z RID))
            (Max '()) (Min '()))
            (if (string=? Reg (cadaar RegGen))
                (mfj:display "Mesh refinement for regions...\n")
            )
            (if (string=? Grp "Semiconductor")
                (begin
                    (if (> (/ (- max-z min-z) RegSp) ElmMax)
                        (set! Max (cons ElmMax Max))
                        (set! Max (cons (/ (- max-z min-z) RegSp) Max))
                    )
                    (if (> (car Max) ElmMin)
                        (set! Min (cons ElmMin Min))
                        (set! Min (cons (car Max) Min))
                    )
                    (if (= Dim 1)
                        (begin
                            (set! Max (cons (mfj:half YMax) Max))
                            (set! Min (cons (mfj:half YMax) Min))
                        )
                        (begin
                            (if (> (/ (- max-y min-y) RegSp) ElmMax)
                                (set! Max (cons ElmMax Max))
                                (set! Max (cons (/ (- max-y min-y) RegSp) Max))
                            )
                            (if (> (car Max) ElmMin)
                                (set! Min (cons ElmMin Min))
                                (set! Min (cons (car Max) Min))
                            )
                        )
                    )
                    (if (> (/ (- max-x min-x) RegSp) ElmMax)
                        (set! Max (cons ElmMax Max))
                        (set! Max (cons (/ (- max-x min-x) RegSp) Max))
                    )
                    (if (> (car Max) ElmMin)
                        (set! Min (cons ElmMin Min))
                        (set! Min (cons (car Max) Min))
                    )
                    (sdedr:define-refinement-function Reg
                        "DopingConcentration" "MaxTransDiff" 1)
                    (sdedr:define-refinement-function Reg
                        "AbsorbedPhotonDensity" "MaxTransDiff" 1)
                    (if Offset
                        (sdedr:offset-block "region" Reg "maxlevel" MaxLvl)
                    )
                )
                (begin
                    (set! Max (map / (map - (list max-x max-y max-z)
                        (list min-x min-y min-z)) '(2 2 2)))
                    (set! Min Max)
                )
            )
            (mfj:display (make-string 4 #\space) Reg ", max: " Max ", min: "
                Min "\n")
            (apply sdedr:define-refinement-size Reg (append Max Min))
            (sdedr:define-refinement-region Reg Reg Reg)
        )
    ) RegGen
)

;# If TMM is selected, sdevice triggers an unknown issue to increase memory
;# consumption contineously until crash using offset refinement
(for-each
    (lambda (IFld)
        (let* ((IntfID (car IFld)) (IntfStr "") (IntfLst '()))
            (if (equal? IntfID (caar IntfFld))
                (if Offset
                    (mfj:display "Offset refinement for interface"
                        " profiles...\n")
                    (mfj:display "Refinement for interface profiles...\n")
                )
            )
            (if (list? IntfID)
                (set! IntfStr (car IntfID))
                (set! IntfStr IntfID)
            )
            (set! IntfLst (mfj:string-split
                (substring IntfStr 1 (string-length IntfStr)) #\/))
            (mfj:display (make-string 4 #\space) IntfStr "\n")
            (if (list? IntfID)
                (begin
                    (set! MB (string-append "IntfFld-" IntfStr))
                    (if (= (length (cdr IFld)) 1)
                        (set! Val (cadadr IFld))

                        ;# More than one profile. Find the maximum depth by
                        ;# first transposing the profile list
                        (set! Val (apply max (cadr (apply map list
                            (cdr IFld)))))
                    )
                    (set! Lst (list Val Val Val))
                    (set! Str "Rectangle")
                    (set! Vn (cadr IntfID))
                    (if (= Dim 1)
                        (begin
                            (set! P1 (list (car IntfLst) 0 0))
                            (set! P2 (map + (list (car IntfLst) YMax 0)
                                (map * Vn Lst)))
                        )
                        (begin
                            (set! P1 (mfj:string-split (car IntfLst) #\_))
                            (set! P2 (mfj:string-split (cadr IntfLst) #\_))
                            (if (= Dim 2)
                                (begin
                                    (set! P1 (append P1 '(0)))
                                    (set! P2 (map + (append P2 '(0))
                                        (map * Vn Lst)))
                                )
                                (begin
                                    (set! P2 (map + P2 (map * Vn Lst)))
                                    (set! Str "Cuboid")
                                )
                            )
                        )
                    )
                    (sdedr:define-refeval-window MB Str
                        (apply position P1) (apply position P2))
                    (apply sdedr:define-multibox-size MB (append (list ElmMax
                        ElmMax ElmMax IntfMin IntfMin IntfMin) (map * Vn
                        (list IntfRat IntfRat IntfRat))))
                    (sdedr:define-multibox-placement MB MB MB)
                )
                (begin
                    (define Reg1 (cadar (list-ref RegGen (car IntfLst))))
                    (define Reg2 (cadar (list-ref RegGen (cadr IntfLst))))
                    (if Offset
                        (sdedr:offset-interface "region" Reg2 Reg1 "hlocal"
                            IntfMin "factor" IntfRat)
                        (sdedr:refine-interface "region" Reg2 Reg1 "hlocal"
                            IntfMin "factor" IntfRat)
                    )
                )
            )
        )
    ) IntfFld
)

;# Refinement for interface attributes
;# Store region pairs for query and skip a subsequent pair if exists
(set! Lst '())
(for-each
    (lambda (Attr)
        (let* ((RStr (car Attr)) (RRLst (mfj:string-split
            (substring RStr 1 (string-length RStr)) #\/))
            (Reg1 (cadar (list-ref RegGen (car RRLst))))
            (Reg2 (cadar (list-ref RegGen (cadr RRLst))))
            (Grp1 (caddar (list-ref RegGen (car RRLst))))
            (Grp2 (caddar (list-ref RegGen (cadr RRLst)))))
            (if (string=? RStr (caar IntfAttr))
                (if Offset
                    (mfj:display "Offset refinement for interface"
                        " attributes...\n")
                    (mfj:display "Refinement for interface attributes...\n")
                )
            )

            ;# Skip interface refinement for 3D to reduce mesh points
            (if (and (not (or (member (list Reg1 Reg2) Lst)
                (member (list Reg2 Reg1) Lst))) (< Dim 3))
                (begin
                    (if (string=? Grp1 "Semiconductor")
                        (begin
                            (mfj:display (make-string 4 #\space) RStr "-"
                                (car RRLst) "\n")
                            (if Offset
                                (sdedr:offset-interface "region" Reg1 Reg2
                                    "hlocal" IntfMin "factor" IntfRat)
                                (sdedr:refine-interface "region" Reg1 Reg2
                                    "hlocal" IntfMin "factor" IntfRat)
                            )
                        )
                    )
                    (if (string=? Grp2 "Semiconductor")
                        (begin
                            (mfj:display (make-string 4 #\space) RStr "-"
                                (cadr RRLst) "\n")
                            (if Offset
                                (sdedr:offset-interface "region" Reg2 Reg1
                                    "hlocal" IntfMin "factor" IntfRat)
                                (sdedr:refine-interface "region" Reg2 Reg1
                                    "hlocal" IntfMin "factor" IntfRat)
                            )
                        )
                    )
                )
            )
            (set! Lst (cons (list Reg1 Reg2) Lst))
        )
    ) IntfAttr
)

;# Optical refinement for each illumination interface is necessary for correct
;# integration of optical generation in electrical simulation
(mfj:display "Multibox refinement for Gop in electrical simulation...")
(set! Var '("External" "OBAM" "TMM" "Raytrace"))
(set! Val (* LPD 0.00001))
(set! Idx 0)
(for-each
    (lambda (PP)
        (define BID "")
        (define Mat "")
        (define Pos "")
        (cond
            ((= Dim 1)
                (set! MB (string-append "Gop-p" (number->string (car PP))
                    "/" (cadr PP)))
                (set! P1 (list (car PP) 0 0))
                (if (= LPD 1)
                    (set! P2 (list XMax YMax 0))
                    (set! P2 (list 0 YMax 0))
                )
                (set! Str "Rectangle")
            )
            ((= Dim 2)
                (set! MB (string-append "Gop-p" (mfj:join (car PP) "_") "/"
                    (mfj:join (cadr PP) "_")))
                (set! P1 (append (car PP) '(0)))
                (if (= LPD 1)
                    (set! P2 (list XMax (cadadr PP) 0))
                    (set! P2 (list 0 (cadadr PP) 0))
                )
                (set! Str "Rectangle")
            )
            (else
                (set! MB (string-append "Gop-p" (mfj:join (car PP) "_") "/"
                    (mfj:join (cadr PP) "_")))
                (set! P1 (car PP))
                (if (= LPD 1)
                    (set! P2 (cons XMax (cdadr PP)))
                    (set! P2 (cons 0 (cdadr PP)))
                )
                (set! Str "Cuboid")
            )
        )
        (set! Pos (map mfj:half (map + P1 P2)))

        ;# Refine if it is an illumination interface and electrical simulation
        (if (and (not OptOnly) (member (caddr PP) Var))
            (let Next ((X (car P1)))
                (set-car! Pos (+ X Val))
                (set! BID ((mfj:compose car find-body-id)
                    (apply position Pos)))
                (set! Mat (generic:get BID "material"))
                (if (string=? (sde:material-type Mat) "Semiconductor")
                    (begin
                        (set-car! P1 X)
                        (sdedr:define-refeval-window MB Str
                            (apply position P1) (apply position P2))
                        (sdedr:define-multibox-size MB
                            ElmMax 0 0 (list-ref MeshAttr 6) 0 0
                            (* LPD (list-ref MeshAttr 7)) 0 0)
                        (sdedr:define-multibox-placement MB MB MB)
                    )

                    ;# Not a semiconductor region? Iterate until it is found
                    (if (= LPD 1)
                        (Next (sde:max-x BID))
                        (Next (sde:min-x BID))
                    )
                )
            )
        )
        (set! Idx (+ Idx 1))
    ) GopPP
)


;# Define optical boundaries for raytrace simulation
(set! Flg #f)
(for-each
    (lambda (Gop)
        (if (member "Raytrace" Gop)
            (set! Flg #t)
        )
    ) GopAttr
)
(if Flg
    (begin
        (mfj:display "Define front, back and surounding optical contacts for"
            " raytrace...\n")
        (if (= Dim 3)
            (begin
                (mfj:display (make-string 4 #\space) "TOpt:\n"
                    (make-string 8 #\space))
                (set! Lst ((mfj:compose find-face-id position)
                    (caadar RegGen) (mfj:half YMax) (mfj:half ZMax)))
                (set! Val (- (length (entity:vertices Lst)) 1))
                (set! Idx 0)
                (for-each
                    (lambda (Vx)
                        (if (= Idx Val)
                            (mfj:display (vertex:position Vx))
                            (mfj:display (vertex:position Vx) " -> ")
                        )
                        (set! Idx (+ Idx 1))
                    ) (entity:vertices Lst)
                )(newline)
                (mfj:display (make-string 8 #\space) "TOpt entity list: "
                    Lst "\n")
                (sdegeo:set-contact Lst "TOpt")

                ;# If 'OptOnly', bottom contact is defined at X = XMax
                (mfj:display (make-string 4 #\space) "BOpt:\n"
                    (make-string 8 #\space))
                (set! Lst '())
                (if OptOnly

                    ;# Visit all faces of all bodies to define 'BOpt'
                    (for-each
                        (lambda (F)
                            (set! Var (sdegeo:face-find-interior-point F))
                            (if (and (gvector:parallel? (face:plane-normal F)
                                (gvector 1 0 0))
                                (< (abs (- (position:x Var) XMax)) 1e-6)
                                (<= (position:y Var) YMax)
                                (>= (position:y Var) 0)
                                (>= (position:z Var) 0)
                                (<= (position:z Var) ZMax))
                                (begin
                                    (set! Lst (cons F Lst))
                                    (set! Val (- (length (entity:vertices F))
                                        1))
                                    (set! Idx 0)
                                    (for-each
                                        (lambda (Vx)
                                            (if (= Idx Val)
                                                (mfj:display
                                                    (vertex:position Vx))
                                                (mfj:display
                                                    (vertex:position Vx) " -> ")
                                            )
                                            (set! Idx (+ Idx 1))
                                        ) (entity:vertices F)
                                    )
                                    (mfj:display "\n" (make-string 8 #\space))
                                )
                            )
                        ) (entity:faces (get-body-list))
                    )
                    (begin
                        (set! Lst ((mfj:compose find-face-id position)
                            (car (caddar (reverse RegGen))) (mfj:half YMax)
                            (mfj:half ZMax)))
                        (set! Val (- (length (entity:vertices Lst)) 1))
                        (set! Idx 0)
                        (for-each
                            (lambda (Vx)
                                (if (= Idx Val)
                                    (mfj:display (vertex:position Vx))
                                    (mfj:display (vertex:position Vx) " -> ")
                                )
                                (set! Idx (+ Idx 1))
                            ) (entity:vertices Lst)
                        )(newline)
                    )
                )
                (mfj:display (make-string 8 #\space) "BOpt entity list: "
                    Lst "\n")
                (sdegeo:set-contact Lst "BOpt")

                ;# Visit all faces of all bodies to define surounding boundaries
                ;# Each side has to be defined seperately to avoid erroneous
                ;# and lengthy optical simulation
                (mfj:display (make-string 4 #\space) "surounding boundaries:\n"
                    (make-string 8 #\space))
                (define LFLst '())
                (define RFLst '())
                (define FFLst '())
                (define NFLst '())
                (for-each
                    (lambda (F)
                        (set! Var (sdegeo:face-find-interior-point F))
                        (set! Str "")
                        (if (and (gvector:parallel? (face:plane-normal F)
                            (gvector 0 1 0)) (<= (position:z Var) ZMax)
                            (>= (position:z Var) 0) (= (position:y Var) 0))
                            (begin
                                (set! LFLst (cons F LFLst))
                                (set! Str "Left face: ")
                            )
                        )
                        (if (and (gvector:parallel? (face:plane-normal F)
                            (gvector 0 1 0)) (<= (position:z Var) ZMax)
                            (>= (position:z Var) 0) (= (position:y Var) YMax))
                            (begin
                                (set! RFLst (cons F RFLst))
                                (set! Str "Right face: ")
                            )
                        )
                        (if (and (gvector:parallel? (face:plane-normal F)
                            (gvector 0 0 1)) (<= (position:y Var) YMax)
                            (>= (position:y Var) 0) (= (position:z Var) 0))
                            (begin
                                (set! FFLst (cons F FFLst))
                                (set! Str "Far face: ")
                            )
                        )
                        (if (and (gvector:parallel? (face:plane-normal F)
                            (gvector 0 0 1)) (<= (position:y Var) YMax)
                            (>= (position:y Var) 0) (= (position:z Var) ZMax))
                            (begin
                                (set! NFLst (cons F NFLst))
                                (set! Str "Near face: ")
                            )
                        )
                        (if (> (string-length Str) 0)
                            (begin
                                (set! Val (- (length (entity:vertices F)) 1))
                                (set! Idx 0)
                                (mfj:display Str)
                                (for-each
                                    (lambda (Vx)
                                        (if (= Idx Val)
                                            (mfj:display (vertex:position Vx))
                                            (mfj:display
                                                (vertex:position Vx) " -> ")
                                        )
                                        (set! Idx (+ Idx 1))
                                    ) (entity:vertices F)
                                )
                                (mfj:display "\n" (make-string 8 #\space))
                            )
                        )
                    ) (entity:faces (get-body-list))
                )
                (mfj:display (make-string 8 #\space) "LOpt entity list: "
                    LFLst "\n")
                (sdegeo:set-contact LFLst "LOpt")
                (mfj:display (make-string 8 #\space) "ROpt entity list: "
                    RFLst "\n")
                (sdegeo:set-contact RFLst "ROpt")
                (mfj:display (make-string 8 #\space) "FOpt entity list: "
                    FFLst "\n")
                (sdegeo:set-contact FFLst "FOpt")
                (mfj:display (make-string 8 #\space) "NOpt entity list: "
                    NFLst "\n")
                (sdegeo:set-contact NFLst "NOpt")
            )
            (begin
                (if (= Dim 2)
                    (set! Lst ((mfj:compose find-edge-id position)
                        (caadar RegGen) (mfj:half YMax) (mfj:half ZMax)))
                    (set! Lst ((mfj:compose find-edge-id position)
                        (cadar RegGen) (mfj:half YMax) (mfj:half ZMax)))
                )
                (mfj:display (make-string 4 #\space) "TOpt:\n")
                (mfj:display (make-string 8 #\space) (edge:start (car Lst))
                    " -> " (edge:end (car Lst)) "\n")
                (mfj:display (make-string 8 #\space) "TOpt entity list: "
                    Lst "\n")
                (sdegeo:set-contact Lst "TOpt")

                ;# If 'OptOnly', bottom contact is defined at X = XMax
                (mfj:display (make-string 4 #\space) "BOpt:\n")
                (set! Lst '())
                (if OptOnly

                    ;# Visit all edges of all bodies to define 'BOpt'
                    (for-each
                        (lambda (E)
                            (set! Var (edge:start E))
                            (set! Val (edge:end E))
                            (if (and (gvector:parallel? (gvector:from-to
                                Var Val) (gvector 0 1 0))
                                (< (abs (- (position:x Var) XMax)) 1e-6)
                                (>= (position:y Var) 0)
                                (>= (position:y Val) 0)
                                (<= (position:y Var) YMax)
                                (<= (position:y Val) YMax))
                                (begin
                                    (set! Lst (cons E Lst))
                                    (mfj:display (make-string 8 #\space)
                                        Var " -> " Val "\n")
                                )
                            )
                        ) (entity:edges (get-body-list))
                    )
                    (begin
                        (if (= Dim 2)
                            (set! Lst ((mfj:compose find-edge-id position)
                                (car (caddar (reverse RegGen))) (mfj:half YMax)
                                (mfj:half ZMax)))
                            (set! Lst ((mfj:compose find-edge-id position)
                                (caddar (reverse RegGen)) (mfj:half YMax)
                                (mfj:half ZMax)))
                        )
                        (mfj:display (make-string 8 #\space) (edge:start
                            (car Lst)) " -> " (edge:end (car Lst)) "\n")
                    )
                )
                (mfj:display (make-string 8 #\space) "BOpt entity list: "
                    Lst "\n")
                (sdegeo:set-contact Lst "BOpt")

                ;# Visit all edges of all bodies
                ;# If cylindrical, edges with Y = 0 are ignored
                (mfj:display (make-string 4 #\space) "surounding boundaries:\n")
                (define LFLst '())
                (define RFLst '())
                (for-each
                    (lambda (E)
                        (set! Var (edge:start E))
                        (set! Val (edge:end E))
                        (if (and (gvector:parallel? (gvector:from-to
                            Var Val) (gvector 1 0 0))
                            (= (position:y Var) YMax))
                            (begin
                                (set! RFLst (cons E RFLst))
                                (mfj:display (make-string 8 #\space)
                                    "Right edge: " Var " -> " Val "\n")
                            )
                        )
                        (if (and (not Cylind) (gvector:parallel?
                            (gvector:from-to Var Val) (gvector 1 0 0))
                            (= (position:y Var) 0))
                            (begin
                                (set! LFLst (cons E LFLst))
                                (mfj:display (make-string 8 #\space)
                                    "Left edge: " Var " -> " Val "\n")
                            )
                        )
                    ) (entity:edges (get-body-list))
                )
                (if (not Cylind)
                    (begin
                        (mfj:display (make-string 8 #\space)
                            "LOpt entity list: " LFLst "\n")
                        (sdegeo:set-contact LFLst "LOpt")
                    )
                )
                (mfj:display (make-string 8 #\space) "ROpt entity list: "
                    RFLst "\n")
                (sdegeo:set-contact RFLst "ROpt")
            )
        )
    )
)

;# Enable axis-aligned algorithm in addition to bisectional refinement algorithm
;# Reduce mesh-induced numeric noise e.g. changing contact width
(if (= (length XCutLst) 0) (set! XCutLst XMax))
(if (= (length YCutLst) 0) (set! YCutLst YMax))
(if (= (length ZCutLst) 0) (set! ZCutLst ZMax))
(if (= Dim 3)
    (sdesnmesh:axisaligned "xCuts" XCutLst "yCuts" YCutLst "zCuts" ZCutLst)
    (sdesnmesh:axisaligned "xCuts" XCutLst "yCuts" YCutLst)
)

(mfj:display "Saving 'n@node@_bnd.tdr' and 'n@node@_msh.cmd'"
    " and building mesh...\n")
(sdeio:save-tdr-bnd (get-body-list) "n@node@_bnd.tdr")
(sdedr:write-cmd-file "n@node@_msh.cmd")
(if Offset
    (sde:build-mesh "snmesh" "-a -offset -m 1000000" "n@node@")
    (sde:build-mesh "snmesh" "-a" "n@node@")
)
(mfj:display "SDE done. Have a nice day!\n")
