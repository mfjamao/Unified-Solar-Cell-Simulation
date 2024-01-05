!(

#--- Get Tcl global variables
#include "varSim.tcl"

# Generate an input script for sprocess
set ouf [open n@node@_fps.tcl w]
if {[llength $ProcSeq]} {

    # Global settings for sprocess
    puts $ouf "math coord.ucs numThreads= $SimArr(NThread)"
    regexp -nocase {\{Other([^\}]+)} $DfltAttr -> lst
    puts $ouf "SetTemp [lindex $lst 0]<C>\n"

    # Extract 'calibrate' and set 'init' as the 1st process in 'ProcSeq'
    set lst [list]
    set var [list]
    foreach grp $ProcSeq {
        if {[lindex $grp 0] eq "calibrate"} {
            set var $grp
        } elseif {[lindex $grp 0] eq "init"} {
            set lst [concat [list $grp] $lst]
        } else {
            lappend lst $grp
        }
    }
    set ProcSeq $lst

    # Advanced calibration
    if {[llength $var] > 1} {
        puts $ouf "AdvancedCalibration [lindex [split [lindex $var 1] -] 1]"
        if {[llength $var] > 2} {
            puts $ouf "source [lindex $var 2]"
        }
        puts -nonewline $ouf \n
    }

    if {[lindex $ProcSeq 0 0] ne "init"} {
        puts $ouf "init tdr= n@previous@_msh"
    }

    # Interprete process sequences in 'ProcSeq'
    set idx 0
    set cnt -1
    set lst [list]
    foreach grp $ProcSeq {
        switch -- [lindex $grp 0] {
            deposit {
                if {[llength $grp] == 3} {
                    set str "deposit material= [lindex $grp 1]\
                        thickness= [lindex $grp 2]<um> type= anisotropic"
                } else {
                    set str "deposit material= [lindex $grp 1]\
                        thickness= [lindex $grp 2]<um> type= [lindex $grp 3]"
                }
                if {$Dim > 1 && [lindex $grp 4] >= 0
                    && [lindex $grp 4] <= $cnt} {
                    append str " mask= \"M[lindex $grp 4]\""
                }
                set grp [lrange $grp 5 end]
                set var ""
                while {[llength $grp]} {
                    if {[regexp {^(Al|As|B|C|F|Ge|In|N|P|Sb)$}\
                        [lindex $grp 0]]} {
                        set val [lindex [split\
                            $mfjProc::tabArr([lindex $grp 0]) |] 0]
                    }
                    if {$var eq ""} {
                        append var "$val= [lindex $grp 1]"
                    } else {
                        append var " $val= [lindex $grp 1]"
                    }
                    set grp [lrange $grp 2 end]
                }
                if {$var ne ""} {
                    append str " fields.values= \{$var\}"
                }
                puts $ouf $str
            }
            diffuse {
                puts $ouf "temp_ramp name= temp$idx\
                    read.temp.file= [lindex $grp 1]"
                set val [lindex $grp 2]
                set grp [lrange $grp 3 end]
                if {[llength $grp] == 0} {
                    puts $ouf "diffuse temp.ramp= temp$idx"
                } elseif {[llength $grp] == 2} {
                    if {[string equal -nocase [lindex $grp 0] N2]} {
                        puts $ouf "diffuse temp.ramp= temp$idx"
                    } else {
                        puts $ouf "diffuse temp.ramp= temp$idx [lindex $grp 0]\
                            pressure= [lindex $grp 1]<$val>"
                    }
                } else {
                    set var [list]
                    while {[llength $grp]} {
                        lappend var "[lindex $grp 0]= [lindex $grp 1]<$val>"
                        set grp [lrange $grp 2 end]
                    }
                    puts $ouf "gas_flow name= flow$idx\
                        partial.pressure= \"$var\""
                    puts $ouf "diffuse temp.ramp= temp$idx gas.flow= flow$idx"
                }
            }
            etch {
                if {[llength $grp] == 3} {
                    set str "etch material= [lindex $grp 1]\
                        thickness= [lindex $grp 2]<um> type= anisotropic"
                } else {
                    set str "etch material= [lindex $grp 1]\
                        thickness= [lindex $grp 2]<um> type= [lindex $grp 3]"
                }
                if {$Dim > 1 && [lindex $grp 4] >= 0
                    && [lindex $grp 4] <= $cnt} {
                    append str " mask= \"M[lindex $grp 4]\""
                }
                puts $ouf $str
            }
           implant {
                set str "implant species= $arr([lindex $grp 1])\
                    energy= [lindex $grp 2]<keV> dose= [lindex $grp 3]"
                if {[llength $grp] >= 5} {
                    append str " rotation= [lindex $grp 4]"
                }
                if {[llength $grp] >= 6} {
                    append str " tilt=[lindex $grp 5]"
                }
                puts $ouf $str
            }
            init {
                set var [string map {p \{ _ " " / "\} \{"} [lindex $grp 2]]\}
                set val [lindex $var 1 0]
                puts $ouf "line x loc= 0.0 Spa= 0.001 tag= top"
                if {$val > 0.05} {
                    puts $ouf "line x loc= 0.05 Spa= 0.005"
                }
                if {$val > 1} {
                    puts $ouf "line x loc= 1.0 Spa= 0.05"
                }
                puts $ouf "line x loc= $val Spa= 0.05 tag= bot"
                if {$Dim > 1} {
                    set val [lindex $var 1 1]
                    puts $ouf "line y loc= 0.0 Spa= 0.001 tag= left"
                    if {$val > 0.05} {
                        puts $ouf "line y loc= 0.05 Spa= 0.005"
                    }
                    if {$val > 1} {
                        puts $ouf "line y loc= 1.0 Spa= 0.05"
                    }
                    puts $ouf "line y loc= $val Spa= 0.05 tag= right"
                }
                if {$Dim == 3} {
                    set val [lindex $var 1 2]
                    puts $ouf "line z loc= 0.0 Spa= 0.001 tag= far"
                    if {$val > 0.05} {
                        puts $ouf "line z loc= 0.05 Spa= 0.005"
                    }
                    if {$val > 1} {
                        puts $ouf "line z loc= 1.0 Spa= 0.05"
                    }
                    puts $ouf "line z loc= $val Spa= 0.05 tag= near"
                }
                if {$Dim == 1} {
                    puts $ouf "region [lindex $grp 1] xlo= top xhi= bot"
                } elseif {$Dim == 2} {
                    puts $ouf "region [lindex $grp 1] xlo= top xhi= bot\
                        ylo= left yhi= right"
                } else {
                    puts $ouf "region [lindex $grp 1] xlo= top xhi= bot\
                        ylo= left yhi= right zlo= far zhi= near"
                }
                set str init
                if {[llength $grp] > 3} {
                    append str " wafer.orient= [lindex $grp 3]"
                } else {
                    append str " wafer.orient= 100"
                }
                if {[llength $grp] == 6} {
                    set val [lindex [split\
                        $mfjProc::tabArr([lindex $grp 4]) |] 0]
                    append str " field= $val concentration= [lindex $grp 5]"
                }
                puts $ouf $str
            }
            mask {
                if {[lindex $grp 3] eq "clear"} {
                    puts $ouf "mask clear"
                    set cnt -1
                } else {
                    if {[llength $grp] == 2} {
                        set str "mask name= [incr cnt] positive"
                    } else {
                        set str "mask name= [incr cnt] [lindex $grp 2]"
                    }
                    set var [string map {p \{ _ " " / "\} \{"}\
                        [lindex $grp 1]]\}
                    if {$Dim == 1} {
                        incr idx
                        continue
                    } elseif {$Dim == 2} {
                        append str " left= [lindex $var 0 1]\
                            right= [lindex $var 1 1]"
                    } else {
                        append str " left= [lindex $var 0 1]\
                            right= [lindex $var 1 1] front= [lindex $var 0 2]\
                            back= [lindex $var 1 2]"
                    }
                    puts $ouf $str
                }
            }
            select {
                set str "select name= [lindex $grp 1] z= [lindex $grp 2]"
                if {[llength $grp] > 3} {
                    append str " [lindex $grp 3]"
                } else {
                    append str " store"
                }
                if {[llength $grp] > 4} {
                    append str " [lindex $grp 4]"
                } else {
                    append str " Silicon"
                }
                puts $ouf $str
            }
            transform {
                puts $ouf "transform [lindex $grp 1]\
                    location= [string range [lindex $grp 2] 1 end]"
            }
            write {
                set var [split [string range [lindex $grp 1] 1 end] _]
                set val [file join $SimArr(OutDir) n@node@_p${idx}_1DCut.plx]
                set str "WritePlx $val"
                if {$Dim == 1} {
                    append str " y= [expr $YMax*0.5]"
                } elseif {$Dim == 2} {
                    append str " y= [lindex $var 1]"
                } else {
                    append str " y= [lindex $var 1] z= [lindex $var 2]"
                }
                puts $ouf $str
                lappend lst [lindex $str 1]
            }
            default {
                error "unknown process '$grp'!"
            }
        }
        incr idx
    }
    puts $ouf "struct tdr= n@node@ Gas\n"

    # Convert .plx files from process simulaton to .CSV files
    if {[llength $lst]} {
        puts $ouf "source \[file join $SimArr(CodeDir) $SimArr(FProc)\]"
    }
    foreach elm $lst {
        puts $ouf "mfjProc::plx2CSV $elm"
    }
} else {
    puts $ouf "file copy -force n@previous@_msh.tdr n@node@_fps.tdr"
}
close $ouf

)!

#setdep @previous@
CHECKOFF
source n@node@_fps.tcl
