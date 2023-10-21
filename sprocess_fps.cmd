!(

#--- Get Tcl global variables
#include ".mfj/varSim.tcl"

)!

#setdep @previous@
#--- Get global Tcl parameters
!(

foreach var {Dim YMax DfltAttr ProcSeq} {
    vputs -n -i-3 "
        set $var \{[regsub -all {\s+} [set $var] " "]\}"
}
vputs -n -i-2 "
    array set SimArr \{[array get SimArr]\}"

)!

CHECKOFF
if {[llength $ProcSeq]} {
    source $SimArr(FProc)
    namespace import mfjProc::*
    set mfjProc::arr(FLog) [file rootname [info script]].mfj
    set mfjProc::arr(MaxVerb) 1
    vputs -n -w ""

    regexp -nocase {\{Other\s+([^\}]+)} $DfltAttr -> lst
    math coord.ucs numThreads= 1
    SetTemp [lindex $lst 0]<C>

    # Advanced calibration
    if {![regexp -nocase {\{calibrate\s+([^\}]+)} $ProcSeq -> lst]} {
        error "no calibration settings for 'ProcSeq'!"
    }
    AdvancedCalibration [lindex [split [lindex $lst 0] -] 1]
    if {[llength $lst] >= 2} {
        source [lindex $lst 1]
    }
    array set arr {B Boron P Phosphorus As Arsenic C Carbon Sb Antimony
        F Fluorine Ge Germanium In Indium N Nitrogen}

    init tdr= n@previous@_msh

    # Process sequences
    set idx 0
    foreach grp $ProcSeq {
        switch -- [lindex $grp 0] {
            calibrate {
                incr idx
                continue
            }
            deposit {
                set cmd "deposit material= [lindex $grp 1]\
                    thickness= [lindex $grp 2]<um>"
                if {[string index [lindex $grp 3] 0] eq "!"} {
                    append cmd " type= anisotropic"
                } else {
                    append cmd " type= isotropic"
                }
                if {$Dim > 1 && [lindex $grp 4] ne "!"} {
                    append cmd " mask= [lindex $grp 4]"
                }
                set grp [lrange $grp 5 end]
                set str ""
                while {[llength $grp]} {
                    if {[regexp {^(B|P|As)$} [lindex $grp 0]]} {
                        set fld $arr([lindex $grp 0])
                    } else {
                        set fld [lindex $grp 0]
                    }
                    if {$str eq ""} {
                        append str "$fld= [lindex $grp 1]"
                    } else {
                        append str " $fld= [lindex $grp 1]"
                    }
                    set grp [lrange $grp 2 end]
                }
                if {$str ne ""} {
                    append cmd " fields.values= \{$str\}"
                }
                vputs $cmd
                eval $cmd
            }
            diffuse {
                temp_ramp name= ramp$idx read.temp.file= [lindex $grp 1]
                set unit [lindex $grp 2]
                set grp [lrange $grp 3 end]
                if {[llength $grp] == 2} {
                    if {[string equal -nocase [lindex $grp 0] N2]} {
                        diffuse temp.ramp= ramp$idx
                    } else {
                        diffuse temp.ramp= ramp$idx [lindex $grp 0]\
                            pressure= [lindex $grp 1]<$unit>
                    }
                } else {
                    set lst [list]
                    while {[llength $grp]} {
                        lappend lst "[lindex $grp 0]= [lindex $grp 1]<$unit>"
                        set grp [lrange $grp 2 end]
                    }
                    gas_flow name= flow$idx partial.pressure= "$lst"
                    diffuse temp.ramp= ramp$idx gas.flow= flow$idx
                }
            }
            etch {
                set cmd "etch material= [lindex $grp 1]\
                    thickness= [lindex $grp 2]<um>"
                if {[string index [lindex $grp 3] 0] eq "!"} {
                    append cmd " anisotropic"
                } else {
                    append cmd " isotropic"
                }
                if {[lindex $grp 4] ne "!"} {
                    append cmd " mask= [lindex $grp 4]"
                }
                vputs "# $cmd"
                $cmd
            }
           implant {
                implant species= $arr([lindex $grp 1])\
                    energy= [lindex $grp 2]<keV> dose= [lindex $grp 3]\
                    rotation= [lindex $grp 4] tilt=[lindex $grp 5]
            }
            mask {
                set lst [string map {p \{ _ " " / "\} \{"} [lindex $grp 3]]\}
                if {$Dim == 1} {
                    incr idx
                    continue
                } elseif {$Dim == 2} {
                    set str "left= [lindex $lst 0 1] right= [lindex $lst 1 1]"
                } else {
                    set str "left= [lindex $lst 0 1] right= [lindex $lst 1 1]\
                        front= [lindex $lst 0 2] back= [lindex $lst 1 2]"
                }
                if {[string index [lindex $grp 2] 0] eq "!"} {
                    set type negative
                } else {
                    set type positive
                }
                mask name= [lindex $grp 1] $type $str
            }
            save {
                set lst [split [string range [lindex $grp 1] 1 end] _]
                if {$Dim == 1} {
                    WritePlx $SimArr(OutDir)/n@node@_p${idx}_1DCut.plx\
                        y= [expr $YMax*0.5]
                } elseif {$Dim == 2} {
                    WritePlx $SimArr(OutDir)/n@node@_p${idx}_1DCut.plx\
                        y= [lindex $lst 1]
                } else {
                    WritePlx $SimArr(OutDir)/n@node@_p${idx}_1DCut.plx\
                        y= [lindex $lst 1] z= [lindex $lst 2]
                }
            }
            transform {
                transform [lindex $grp 1]\
                    location= [string range [lindex $grp 2] 1 end]
            }
            default {
                error "unknown process '$grp'!"
            }
        }
        incr idx
    }

    struct tdr= n@node@ Gas

    vputs "Convert .plx files from process simulaton to .CSV files..."
    foreach elm [glob -nocomplain -d $SimArr(OutDir) n@node@*.plx] {
        vputs -i1 "$elm -> [file rootname $elm].csv"
        plx2CSV $elm
    }
} else {
    file copy -force n@previous@_msh.tdr n@node@_fps.tdr
}
