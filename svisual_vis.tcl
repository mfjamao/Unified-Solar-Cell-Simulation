!(
    #--- Get TCL global variables
    #include ".mfj/varSim.tcl"

    # Update 'SS2Fld' to replace 'BD' with 'EA EC EV EFe EFh'
    set lst [list]
    foreach grp [lsort -unique -index 0 $SS2Fld] {
        if {[regexp {^p[^/]+$} [lindex $grp 0]]} {
            set grp [concat [lrange $grp 0 2]\
                [lsort -unique [lrange $grp 3 end]]]
        } else {
            set grp [concat [lindex $grp 0]\
                [lsort -unique [lrange $grp 1 end]]]
        }
        lappend lst [string map {Band "EA EC EV EFe EFh"} $grp]
    }
    set SS2Fld $lst
    vputs [wrapText "'SS2Fld': \{$SS2Fld\}" "# "]
)!

#setdep @previous@
#--- Get TCL parameters
!(
    foreach var {RegGen VarVary MiscAttr VV2Fld SS2Fld PPAttr GopAttr
        IntfCon IntfSRH RegIntfTrap ModPar mfjDfltSet Dim Cylind OptOnly
        LoadTDR XMax YMax}\
        val [list $RegGen $VarVary $MiscAttr $VV2Fld $SS2Fld $PPAttr\
        $GopAttr $IntfCon $IntfSRH $RegIntfTrap $ModPar $mfjDfltSet $Dim\
        $Cylind $OptOnly $LoadTDR $XMax $YMax] {
        vputs -n -i-3 "
            set $var \{[regsub -all {\s+} $val " "]\}"
    }
    vputs -n -i-2 "
        array set ValArr \{[array get ValArr]\}
        array set SimArr \{[array get SimArr]\}"
)!

#--- Source general procedures to reduce lengthy embedded code
source $SimArr(FProc)
namespace import mfjProc::*
set mfjProc::arr(FLog) [file rootname [info script]].mfj
set mfjProc::arr(MaxVerb) 1
vputs -n -w ""

#--- Define a few common constants
set PI [expr 2.*asin(1.)]
set mu0 [expr {4e-7*$PI}]
set c0 2.99792458e8
set q 1.602176634e-19
set eps0 [expr {1./($c0*$c0*$mu0)}]
set h 6.62607015e-34
set hB [expr {$h/$q}]
set k 1.380649e-23
set kB [expr {$k/$q}]
set T [expr [lindex $MiscAttr 8]+273.15]

#--- Automatic alternating color, marker and line assignment
set colorLst {black red darkRed green darkGreen blue darkBlue cyan darkCyan
    magenta darkMagenta yellow olive gray}
set colorLen [llength $colorLst]
set markerLst {circle diamond square circlef diamondf squaref plus cross}
set markerLen [llength $markerLst]
set lineLst {solid dot dash dashdot dashdotdot}
set lineLen [llength $lineLst]


#--- Svisual local parameters
set tm [clock seconds]

# Extract run time of sdevice
vputs "svisual $::env(STRELEASE) starts at [clock format $tm -format\
    "%Y-%b-%d %A %H:%M:%S"]"
vputs -i1 "Listing key constants used in calculation..."
foreach elm {PI mu0 c0 q eps0 h hB k kB T}\
    unit {N/A H/m m*s^-1 C F/m J*s eV*s J/K eV/K K} {
    upvar 0 $elm alias
    vputs -i2 "$elm: [format %.6g $alias] $unit"
}
array unset gVarArr

vputs -i1 "\nExtract SDevice wall time:"
set inf [open n@previous@_des.log r]
while {[gets $inf Line] != -1} {
    if {[regexp {^\s+wallclock:\s+(\S+)\s+s} $Line -> wallTm]} {
        set day [expr int($wallTm/86400)]
        set hr [expr int(fmod($wallTm,86400)/3600)]
        set min [expr int(fmod(fmod($wallTm,86400),3600)/60)]
        set sec [expr fmod(fmod(fmod($wallTm,86400),3600),60)]
        if {$day} {
            vputs -i2 "DOE: SDeviceTime ${day}d${hr}h${min}m${sec}s"
            set gVarArr(SDeviceTime) ${day}d${hr}h${min}m${sec}s
        } elseif {$hr} {
            vputs -i2 "DOE: SDeviceTime ${hr}h${min}m${sec}s"
            set gVarArr(SDeviceTime) ${hr}h${min}m${sec}s
        } elseif {$min} {
            vputs -i2 "DOE: SDeviceTime ${min}m${sec}s"
            set gVarArr(SDeviceTime) ${min}m${sec}s
        } else {
            vputs -i2 "DOE: SDeviceTime ${sec}s"
            set gVarArr(SDeviceTime) ${sec}s
        }
        break
    }
}
close $inf

#--- Current plot names
set wlPlt Device=,File=CommandFile/Physics,DefaultRegionPhysics,
append wlPlt ModelParameter=Optics/Excitation/Wavelength
if {[regexp {\s(OBAM|TMM|Raytrace)(\s|\})} $GopAttr]
    || ([regexp {\sExternal\s} $GopAttr] && !$LoadTDR)} {
    set specOG OpticalGenerationFromSpectrum
} elseif {$LoadTDR} {
    set specOG OpticalGenerationFromFile
}
set specAP AbsorbedPhotonDensityFromSpectrum
set monoOG OpticalGenerationFromMonochromaticSource
set monoAP AbsorbedPhotonDensityFromMonochromaticSource
set ogPlt OpticalGeneration
set apPlt AbsorbedPhotonDensity

#--- Calculate area [cm^2], jArea is different from intArea as jArea
# assumes 1 um for z direction while intArea assumes 1 cm in a 2D simulation
# jArea is related to current density, photon flux, ...
# intArea: affected by IntegrationUnit in Math section
if {$Dim == 3} {
    set jArea [expr 1e-8*([lindex $RegGen 0 2 1]-[lindex $RegGen 0 1 1])\
        *([lindex $RegGen 0 2 2]-[lindex $RegGen 0 1 2])]
    set intArea $jArea
} elseif {$Dim == 2} {
    if {$Cylind} {
        set jArea [expr 1e-8*$PI*pow([lindex $RegGen 0 2 1]\
            -[lindex $RegGen 0 1 1],2)]
        set intArea $jArea
    } else {
        set jArea [expr 1e-8*([lindex $RegGen 0 2 1]-[lindex $RegGen 0 1 1])]
        set intArea [expr 1e-4*([lindex $RegGen 0 2 1]-[lindex $RegGen 0 1 1])]
    }
} else {
    set jArea [expr 1e-8*[lindex $mfjDfltSet 0]]
    set intArea [expr 1e-4*[lindex $mfjDfltSet 0]]
}
vputs -i1 "\njArea= $jArea cm^2, intArea= $intArea cm^2"

# RE for integers and real numbers (including scientific notation)
set RE_n {[+-]?(\.\d+|\d+(\.\d*)?)([eE][+-]?\d+)?}

# Regular expression for a position
set RE_p (${RE_n}_){0,2}$RE_n
if {!$OptOnly && [regexp \\\{p$RE_p\\s $SS2Fld]} {
    foreach tdr [glob -d $SimArr(EtcDir) n@previous@_*_des.tdr] {
        set pCnt -1
        regexp {/n@previous@_(\w+)_des.tdr$} $tdr -> fID
        vputs -i1 "\nExtract fields from '$tdr'"
        load_file $tdr -name Dataset_$fID
        create_plot -name PltFld_$fID -dataset Dataset_$fID
        set xVar X
        set xCap Depth|um
        foreach grp $SS2Fld {
            set grp0 [lindex $grp 0]
            if {[regexp {^p[^/]+$} $grp0]} {
                set capFld "n@node@: 1D Fields at $grp0 from '$tdr' at $T K"
                set fFld $SimArr(OutDir)/n@node@_${fID}_${grp0}_1DField.csv
                set pLst [split $grp0 _]
                select_plots PltFld_$fID
                if {[llength $pLst] == 3} {
                    create_cutplane -name Dataset_${fID}_Z[lindex $pLst 2]\
                        -plot PltFld_$fID -type z -at [lindex $pLst 2]
                    create_plot -name ${fID}_Z[lindex $pLst 2]\
                        -dataset Dataset_${fID}_Z[lindex $pLst 2]\
                        -ref_plot PltFld_$fID
                    create_cutline -name Dataset_${fID}_Y[lindex $pLst 1]\
                        -plot ${fID}_Z[lindex $pLst 2]\
                        -type y -at [lindex $pLst 1]
                    remove_plots ${fID}_Z[lindex $pLst 2]
                    remove_datasets Dataset_${fID}_Z[lindex $pLst 2]
                } else {
                    if {[llength $pLst] == 1} {
                        set yPos [expr $YMax/2]
                    } else {
                        set yPos [lindex $pLst 1]
                    }
                    create_cutline -name Dataset_${fID}_Y[lindex $pLst 1]\
                        -plot PltFld_$fID -type y -at $yPos
                }
                create_plot -name ${fID}_$grp0\
                    -dataset Dataset_${fID}_Y[lindex $pLst 1] -1d
                foreach elm [lrange $grp 3 end] {
                    set str [lindex [split $mfjProc::tabArr($elm) |] 0]
                    create_curve -name ${grp0}_$elm\
                        -dataset Dataset_${fID}_Y[lindex $pLst 1]\
                        -axisX $xVar -axisY $str
                    set_curve_prop [lindex $grp 0]_$elm -label $elm\
                        -markers_type [lindex $markerLst [expr [incr pCnt]\
                        %$markerLen]]
                }

                windows_style -style max
                set_plot_prop -show_grid -show_curve_markers\
                    -title_font_size 28 -title $capFld
                set_grid_prop -show_minor_lines -line1_style dash\
                    -line1_color gray -line2_style dot -line2_color lightGray
                set_axis_prop -axis x -title_font_size 20 -type linear\
                    -scale_font_size 16 -scale_format preferred\
                    -title $xCap
                set_axis_prop -axis y -title_font_size 20 -type linear\
                    -scale_font_size 16 -scale_format preferred\
                    -title {Field}
                set_legend_prop -location top_left

                vputs -i2 "Save all field curves to '$fFld'"
                foreach curve [list_curves -plot ${fID}_$grp0] {
                    set str [lindex [split $curve _] end]
                    set str [lindex [split $mfjProc::tabArr($str) |] 1]
                    curve2CSV $curve $xCap [get_curve_prop $curve -label]|$str\
                        ${fID}_$grp0 $fFld [lindex $grp 1] [lindex $grp 2]
                }
            } else {

                # Integerate fields in a region
            }
        }
    }
    remove_plots PltFld_$fID
}

# Note: The names of datasets, plots, and curves should be unique
foreach pp $PPAttr {
    set pp0 [lindex $pp 0]
    set vIdx [string range $pp0 1 end]
    set pCnt 0
    if {[lindex $pp 1] eq "RAT"} {
        vputs -i1 "\nn@node@_$pp0: Plot reflection,\
            absorption, and transmission curves"
    } elseif {[lindex $pp 1] eq "JV"} {
        vputs -i1 "\nn@node@_$pp0: Plot current density and power\
            density curves"
    } elseif {[lindex $pp 1] eq "QE"} {
        vputs -i1 "\nn@node@_$pp0: Plot quantum efficiency curves"
    } elseif {[lindex $pp 1] eq "QSSPC"} {
        vputs -i1 "\nn@node@_$pp0: Plot lifetime curves"
    } elseif {[lindex $pp 1] eq "SunsVoc"} {
        vputs -i1 "\nn@node@_$pp0: Plot Suns-Voc curves"
    }
    if {![file isfile ${pp0}_@plot@]} {
        vputs -i2 "error: ${pp0}_@plot@ not found!"
        continue
    }
    load_file ${pp0}_@plot@ -name Dataset_$pp0
    set fRaw $SimArr(OutDir)/n@node@_${pp0}_raw.csv
    vputs -i2 "Save raw data to '$fRaw'"
    export_variables -dataset Dataset_$pp0 -overwrite -filename $fRaw

    # OptOnly section
    #================
    if {[lindex $pp 1] eq "RAT" && $OptOnly} {

        # Verify the current 'VarVary' step
        if {[lindex $VarVary $vIdx 0] ne "Wavelength"} {
            puts -i2 "error: element '$vIdx' of 'VarVary' not 'Wavelength'!"
            continue
        }
        set capRAT "n@node@_$pp0: R A T curves"
        set fRAT $SimArr(OutDir)/n@node@_${pp0}_RAT.csv
        set fTotGop $SimArr(OutDir)/n@node@_${pp0}_1DGop_Total.plx
        set fSpecGop $SimArr(OutDir)/n@node@_${pp0}_1DGop_Spectral.plx
        create_plot -name PltRAT_$pp0 -1d

        # Need to check the nearest mono varying step in 'VarVary'
        set val 0
        for {set i [expr $vIdx-1]} {$i >= 0} {incr i -1} {
            if {[lindex $VarVary $i 0] eq "MonoScaling"} {
                set val [lindex $VarVary $i 1]
                break
            }
        }
        if {$val == 0} {
            vputs -i2 "error: no monochromatic intensity for RAT!"
            continue
        }

        # Calculate monochromatic light intensity
        set pMono [expr [lindex $MiscAttr 5]*$val]
        vputs -i2 "Monochromatic intensity: $pMono W*cm^-2"
        vputs -i2 "Create wavelength variable \[um -> nm\]"
        set xVar Wavelength|nm
        set xCap $xVar
        create_variable -name $xVar -dataset Dataset_$pp0\
            -function "<$wlPlt:Dataset_$pp0>*1e3"

        # Extract X axis and data trend (ascending or not)
        set xLst [get_variable_data -dataset Dataset_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr ($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]
        create_curve -name ${pp0}_ww -dataset Dataset_$pp0\
            -axisX $xVar -axisY $xVar
        vputs -i2 "Calculate illuminated photons analytically"
        create_curve -name ${pp0}_A_Inc -function\
            "$pMono*$intArea/($h*$c0/(<${pp0}_ww>*1.e-9))"
        remove_curves ${pp0}_ww

        # Two columns from customSpec: Wavelength [nm] intensity [W*cm^-2]
        vputs -i2 "Build custom spectrum from '$xLow' to '$xHigh' nm based\
            on spectrum file '[lindex $MiscAttr 0]'"
        set specLst [customSpec [lindex $MiscAttr 0] [expr 1e-3*$xLow]\
            [expr 1e-3*$xHigh] [expr 1e-3*$xStep]]
        set intJph 0
        foreach w [lindex $specLst 0] p [lindex $specLst 1] {
            set jph [expr 1e3*$q*$p/($h*$c0/$w*1e9)]
            set intJph [expr $intJph+$jph]
        }
        vputs -i3 "DOE: ${pp0}_Jph [format %.4f $intJph]"
        set gVarArr(${pp0}_Jph|mA*cm^-2) [format %.4f $intJph]

        if {[regexp {\sRaytrace\s} $GopAttr]} {

            # Photon flux integration assumes 1 um in Z direction in 2D
            # Scale up y values so that z direction is also 1 cm
            vputs -i2 "Calculate illuminated photons numerically"
            create_curve -name ${pp0}_N_Inc -dataset Dataset_$pp0\
                -axisX $xVar -axisY "RaytracePhoton Input"
            if {$Dim != 3 && !$Cylind} {
                set_curve_prop ${pp0}_N_Inc -yScale 1e4
            }
            create_curve -name ${pp0}_D_Inc -function\
                "1e2*(<${pp0}_N_Inc>-<${pp0}_A_Inc>)/<${pp0}_A_Inc>"
            vputs -i2 "  Wl\tA_Inc\t  N_Inc\t   \
                1e2*(<${pp0}_N_Inc>-<${pp0}_A_Inc>)/<${pp0}_A_Inc>"
            foreach w $xLst\
                a [get_curve_data ${pp0}_A_Inc -axisY -plot PltRAT_$pp0]\
                n [get_curve_data ${pp0}_N_Inc -axisY -plot PltRAT_$pp0]\
                d [get_curve_data ${pp0}_D_Inc -axisY -plot PltRAT_$pp0] {
                vputs -i2 [format "%4g nm\t%.3e %.3e %.3f%%"\
                    $w $a $n $d]
            }
            remove_curves "${pp0}_N_Inc ${pp0}_D_Inc"

            # Reflectance, transmittance, absorptance
            vputs -i2 "Calculate reflected photons leaving at the front"
            create_curve -name ${pp0}_NR -dataset Dataset_$pp0\
                -axisX $xVar -axisY "RaytraceContactFlux\
                A(TOpt([lindex $RegGen 0 0 1]/OutDevice))"
            if {$Dim != 3 && !$Cylind} {
                create_curve -name ${pp0}_0|R -function\
                    "1e4*<${pp0}_NR>/<${pp0}_A_Inc>"
            } else {
                create_curve -name ${pp0}_0|R -function\
                    "<${pp0}_NR>/<${pp0}_A_Inc>"
            }
            vputs -i2 "Calculate transmitted photons leaving at the back"
            create_curve -name ${pp0}_NT -dataset Dataset_$pp0\
                -axisX $xVar -axisY "RaytraceContactFlux\
                A(BOpt([lindex $RegGen end 0 1]/OutDevice))"
            if {$Dim != 3 && !$Cylind} {
                create_curve -name ${pp0}_1|T -function\
                    "1e4*<${pp0}_NT>/<${pp0}_A_Inc>"
            } else {
                create_curve -name ${pp0}_1|T -function\
                    "<${pp0}_NT>/<${pp0}_A_Inc>"
            }
            remove_curves "${pp0}_NR ${pp0}_NT"

            # Calculate FCA in silicon/polysi regions (can be extended)
            vputs -i2 "Calculate absorbed photons (and FCA) in regions"
            foreach grp $RegGen {
                set mat [lindex $grp 0 0]
                set reg [lindex $grp 0 1]

                # Skip dummy regions
                if {$mat ne "Gas"} {
                    vputs -i3 -n "$reg: absorbed photons"
                    create_curve -name ${pp0}_NA_$reg -dataset Dataset_$pp0\
                        -axisX $xVar -axisY "Integr$reg $monoAP"
                    create_curve -name ${pp0}_3|A_$reg -function\
                        "<${pp0}_NA_$reg>/<${pp0}_A_Inc>"
                    remove_curves ${pp0}_NA_$reg
                    if {[lindex $grp 0 2] eq "Semiconductor"} {
                        vputs -c -n ", electron-hole pairs"
                        create_curve -name ${pp0}_NOG_$reg\
                            -dataset Dataset_$pp0\
                            -axisX $xVar -axisY "Integr$reg $monoOG"
                        create_curve -name ${pp0}_4|OG_$reg -function\
                            "<${pp0}_NOG_$reg>/<${pp0}_A_Inc>"
                        remove_curves ${pp0}_NOG_$reg

                        # Skip FCA in nonsilicon and nonpolysi regions
                        if {$mat eq "Silicon" || $mat eq "PolySi"} {
                            vputs -c -n ", FCA"
                            create_curve -name ${pp0}_5|FCA_$reg -function\
                                "<${pp0}_3|A_$reg>-<${pp0}_4|OG_$reg>"
                        }
                    }
                    vputs
                }
            }
            if {[regexp {\sARC\s} $GopAttr]} {
                vputs -i2 "Calculating absorbed photons in the ARC layers"
                foreach grp $GopAttr {

                    # Skip non-ARC groups
                    if {[lindex $grp 1] ne "ARC"} continue
                    set lst [string map {r "" / " "} [lindex $grp 0]]
                    set intf [lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
                        $RegGen [lindex $lst 1] 0 1]
                    set idx 0
                    while {$idx < [expr ([llength $grp]-2)/3]} {
                        set str [lindex $grp 0]_[lindex $grp [expr $idx*3+2]]
                        vputs -i3 "RaytraceInterfaceTMMLayerFlux\
                            A($intf).layer$idx"
                        create_curve -name ${pp0}_N_$str -dataset Dataset_$pp0\
                            -axisX $xVar -axisY "RaytraceInterfaceTMMLayerFlux\
                            A($intf).layer$idx"
                        if {$Dim != 3 && !$Cylind} {
                            create_curve -name ${pp0}_6|$str -function\
                                "1e4*<${pp0}_N_$str>/<${pp0}_A_Inc>"
                        } else {
                            create_curve -name ${pp0}_6|$str -function\
                                "<${pp0}_N_$str>/<${pp0}_A_Inc>"
                        }
                        remove_curves ${pp0}_N_$str
                        incr idx
                    }
                }
            }
            remove_curves ${pp0}_A_Inc
            set lst [list]
            foreach curve [list_curves -plot PltRAT_$pp0] {
                if {![regexp {^v\d+_\d\|(OG|FCA)} $curve]} {
                    lappend lst <$curve>
                }
            }
            vputs -i2 "Create RAT from the sum of $lst"
            create_curve -name ${pp0}_2|RAT -function [join $lst +]

            # Two columns from customSpec: Wavelength [nm] intensity [W*cm^-2]
            vputs -i2 "Calculate weighted average reflectance, absorptance,\
                transmittance from '$xLow' to '$xHigh' nm based on spectrum\
                file '[lindex $MiscAttr 0]'"
            set intJR 0
            set intJA 0
            set intJT 0
            foreach w [lindex $specLst 0] p [lindex $specLst 1] {
                set jph [expr 1e3*$q*$p/($h*$c0/$w*1e9)]
                set r [lindex [probe_curve ${pp0}_0|R -valueX $w\
                    -plot PltRAT_$pp0] 0]
                set t [lindex [probe_curve ${pp0}_1|T -valueX $w\
                    -plot PltRAT_$pp0] 0]
                set a [expr [lindex [probe_curve ${pp0}_2|RAT\
                    -valueX $w -plot PltRAT_$pp0] 0]-$r-$t]
                set intJR [expr $intJR+$r*$jph]
                set intJA [expr $intJA+$a*$jph]
                set intJT [expr $intJT+$t*$jph]
            }
            vputs -i3 "DOE: ${pp0}_JR [format %.4f $intJR]"
            set gVarArr(${pp0}_JR) [format %.4f $intJR]
            vputs -i3 "DOE: ${pp0}_JA [format %.4f $intJA]"
            set gVarArr(${pp0}_JA|mA*cm^-2) [format %.4f $intJA]
            vputs -i3 "DOE: ${pp0}_JT [format %.4f $intJT]"
            set gVarArr(${pp0}_JT|mA*cm^-2) [format %.4f $intJT]

            # Calculate total 1D weighted average absorptance profile
            vputs -i2 "Calculate total 1D weighted optical generation rate\
                from n@previous@_OG1D.plx based on spectrum file\
                '[lindex $MiscAttr 0]'"
            if {![file exists n@previous@_OG1D.plx]} {
                vputs -i3 "error: n@previous@_OG1D.plx not found!"
                continue
            }
            set idx 0
            set len [llength [lindex $specLst 0]]
            set ogLst [list]
            array unset arr
            set inf [open n@previous@_OG1D.plx r]
            vputs -i3 "Read n@previous@_OG1D.plx"
            while {[gets $inf line] != -1} {
                if {[string is double -strict [lindex $line 0]]} {
                    if {!$idx} {
                        lappend arr(Dep|um) [lindex $line 0]
                    }
                    lappend ogLst [lindex $line end]
                } elseif {[regexp {^# End of wavelength varying} $line]} {
                    if {$idx >= $len} {
                        vputs -i4 "error: wavelength step '$idx' >= $len!"
                        break
                    }
                    if {$xAsc} {
                        lappend arr(Lambda|nm) [lindex $specLst 0 $idx]
                        lappend arr(P|W*cm^-2) [lindex $specLst 1 $idx]
                    } else {
                        lappend arr(Lambda|nm) [lindex $specLst 0 end-$idx]
                        lappend arr(P|W*cm^-2) [lindex $specLst 1 end-$idx]
                    }
                    vputs -i4 "[lindex $arr(Lambda|nm) end] nm\
                        [lindex $arr(P|W*cm^-2) end] W*cm^-2"
                    set arr([lindex $arr(Lambda|nm) end]) $ogLst
                    set ogLst [list]
                    incr idx
                }
            }
            close $inf

            # Calculate weighted average photons for each depth
            set idx 0
            foreach dep $arr(Dep|um) {
                set sum 0
                foreach w $arr(Lambda|nm) p $arr(P|W*cm^-2) {
                    set sum [expr $sum+[lindex $arr($w) $idx]*$p/$pMono]
                }
                lappend arr(WOG|cm^-3*s^-1) $sum
                incr idx
            }
            vputs -i2 "Save total 1D weighted optical generation rate\
                to '$fTotGop'"
            set ouf [open $fTotGop w]
            puts $ouf "# Total 1D weighted optical generation rate from\
                '$xLow' to '$xHigh' nm with a step\n# size of '[expr\
                abs($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]' nm using\
                spectrum '[lindex $MiscAttr 0]'"
            puts $ouf "# Depth \[um\], AbsorbedPhotonDensity \[cm^-3*s^-1\]"
            puts $ouf {"AbsorbedPhotonDensity"}
            foreach dep $arr(Dep|um) og $arr(WOG|cm^-3*s^-1) {
                puts $ouf [format %.6e\t%.6e $dep $og]
            }
            close $ouf
            vputs -i2 "Save spectral 1D optical generation rate\
                to '$fSpecGop'"
            set ouf [open $fSpecGop w]
            puts $ouf "# Spectral 1D optical generation rate"
            puts $ouf "# Depth \[um\], AbsorbedPhotonDensity \[cm^-3*s^-1\]"
            foreach w [lsort -real $arr(Lambda|nm)] {
                set val [expr 1e-3*$w]
                puts $ouf "\n\"g($val)\""
                puts $ouf "Wavelength = $val \[um\]\
                    Intensity = $pMono \[W*cm^-2\]"
                foreach x $arr(Dep|um) p $arr($w) {
                    puts $ouf [format %.6e\t%.6e $x $p]
                }
            }
            close $ouf

        } elseif {[regexp {\sTMM\s} $GopAttr]} {

            set idx 0
            foreach grp $GopAttr {
                if {[lindex $grp 1] ne "TMM"} continue
                vputs -i2 "TMM W$idx:"
                create_curve -name ${pp0}_w${idx}_R -dataset Dataset_$pp0\
                    -axisX $xVar -axisY "LayerStack(W$idx) R_Total"
                create_curve -name ${pp0}_w${idx}_A -dataset Dataset_$pp0\
                    -axisX $xVar -axisY "LayerStack(W$idx) A_Total"
                create_curve -name ${pp0}_w${idx}_T -dataset Dataset_$pp0\
                    -axisX $xVar -axisY "LayerStack(W$idx) T_Total"
                create_curve -name ${pp0}_w${idx}_RAT -function\
                    "<${pp0}_w${idx}_R>+<${pp0}_w${idx}_A>+<${pp0}_w${idx}_T>"
                set intJR 0
                set intJA 0
                set intJT 0
                foreach w [lindex $specLst 0] p [lindex $specLst 1] {
                    set jph [expr 1e3*$q*$p/($h*$c0/$w*1e9)]
                    set r [lindex [probe_curve ${pp0}_w${idx}_R -valueX $w\
                        -plot PltRAT_$pp0] 0]
                    set t [lindex [probe_curve ${pp0}_w${idx}_T -valueX $w\
                        -plot PltRAT_$pp0] 0]
                    set a [lindex [probe_curve ${pp0}_w${idx}_A\
                        -valueX $w -plot PltRAT_$pp0] 0]
                    set intJR [expr $intJR+$r*$jph]
                    set intJA [expr $intJA+$a*$jph]
                    set intJT [expr $intJT+$t*$jph]
                }
                vputs -i3 "DOE: ${pp0}_w${idx}_JR [format %.4f $intJR]"
                set gVarArr(${pp0}_w${idx}_JR|mA*cm^-2) [format %.4f $intJR]
                vputs -i3 "DOE: ${pp0}_w${idx}_JA [format %.4f $intJA]"
                set gVarArr(${pp0}_w${idx}_JA|mA*cm^-2) [format %.4f $intJA]
                vputs -i3 "DOE: ${pp0}_w${idx}_JT [format %.4f $intJT]"
                set gVarArr(${pp0}_w${idx}_JT|mA*cm^-2) [format %.4f $intJT]
                incr idx
            }

            # Calculate FCA in silicon/polysi regions (can be extended)
            vputs -i2 "Calculate absorbed photons (and FCA) in regions"
            foreach grp $RegGen {
                set mat [lindex $grp 0 0]
                set reg [lindex $grp 0 1]

                # Skip dummy regions
                if {$mat ne "Gas"} {
                    vputs -i3 -n "$reg: absorbed photons"
                    create_curve -name ${pp0}_NA_$reg -dataset Dataset_$pp0\
                        -axisX $xVar -axisY "Integr$reg $monoAP"
                    create_curve -name ${pp0}_A_$reg -function\
                        "<${pp0}_NA_$reg>/<${pp0}_A_Inc>"
                    remove_curves ${pp0}_NA_$reg
                    if {[lindex $grp 0 2] eq "Semiconductor"} {
                        vputs -c -n ", electron-hole pairs"
                        create_curve -name ${pp0}_NOG_$reg\
                            -dataset Dataset_$pp0\
                            -axisX $xVar -axisY "Integr$reg $monoOG"
                        create_curve -name ${pp0}_OG_$reg -function\
                            "<${pp0}_NOG_$reg>/<${pp0}_A_Inc>"
                        remove_curves ${pp0}_NOG_$reg

                        # Skip FCA in nonsilicon and nonpolysi regions
                        if {$mat eq "Silicon" || $mat eq "PolySi"} {
                            vputs -c -n ", FCA"
                            create_curve -name ${pp0}_FCA_$reg -function\
                                "<${pp0}_A_$reg>-<${pp0}_OG_$reg>"
                        }
                    }
                    vputs
                }
            }
            remove_curves ${pp0}_A_Inc

        } elseif {[regexp {\sOBAM} $GopAttr]} {

            # Abnormal T-2022.03: AbsorbedPhotonDensity is slightly larger
            # Calculate FCA in silicon/polysi regions (can be extended)
            vputs -i2 "Calculate absorbed photons (and FCA) in regions"
            foreach grp $RegGen {
                set mat [lindex $grp 0 0]
                set reg [lindex $grp 0 1]

                # Skip dummy regions
                if {$mat ne "Gas"} {
                    vputs -i3 -n "$reg: absorbed photons"
                    create_curve -name ${pp0}_NA_$reg -dataset Dataset_$pp0\
                        -axisX $xVar -axisY "Integr$reg $monoAP"
                    create_curve -name ${pp0}_A_$reg -function\
                        "<${pp0}_NA_$reg>/<${pp0}_A_Inc>"
                    remove_curves ${pp0}_NA_$reg
                    if {[lindex $grp 0 2] eq "Semiconductor"} {
                        vputs -c -n ", electron-hole pairs"
                        create_curve -name ${pp0}_NOG_$reg\
                            -dataset Dataset_$pp0\
                            -axisX $xVar -axisY "Integr$reg $monoOG"
                        create_curve -name ${pp0}_OG_$reg -function\
                            "<${pp0}_NOG_$reg>/<${pp0}_A_Inc>"
                        remove_curves ${pp0}_NOG_$reg

                        # Skip FCA in nonsilicon and nonpolysi regions
                        if {$mat eq "Silicon" || $mat eq "PolySi"} {
                            vputs -c -n ", FCA"
                            create_curve -name ${pp0}_FCA_$reg -function\
                                "<${pp0}_A_$reg>-<${pp0}_OG_$reg>"
                        }
                    }
                    vputs
                }
            }
            remove_curves ${pp0}_A_Inc

        } else {
        }

        # Plot and save RAT curves
        windows_style -style max
        set_plot_prop -show_grid -show_curve_markers\
            -title_font_size 28 -title $capRAT
        set_grid_prop -show_minor_lines\
            -line1_style dash -line1_color gray\
            -line2_style dot -line2_color lightGray
        set_axis_prop -axis x -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title $xCap -range "$xLow $xHigh"
        set_axis_prop -axis y -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title {RAT} -range "0 1.01"
        set_legend_prop -location top_right

        vputs -i2 "Save all curves to $fRAT"
        foreach curve [list_curves -plot PltRAT_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            set_curve_prop $curve -label $str -markers_type\
                [lindex $markerLst [expr $pCnt%$markerLen]]
            incr pCnt
            curve2CSV $curve $xCap [get_curve_prop $curve -label]\
                PltRAT_$pp0 $fRAT
        }

        # No further postprocessing
        continue
    }

    # Other than OptOnly simulations
    #===============================
    if {[lindex $pp 1] eq "JV"} {
        set capJV "n@node@_${pp0}: J-V at $T K"
        set fJV $SimArr(OutDir)/n@node@_${pp0}_JV.csv

        # Verify the current 'VarVary' step
        if {![regexp {^c\d$} [lindex $VarVary $vIdx 0]]} {
            vputs -i2 "error: element '$vIdx' of 'VarVary' not contact!"
            continue
        }
        set bCon [lindex $VarVary $vIdx 0]

        # Extract X axis and data trend (ascending or not)
        set xVar "$bCon OuterVoltage"
        set xCap $bCon|V
        set xLst [get_variable_data -dataset Dataset_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr ($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]

        create_plot -name PltJV_$pp0 -1d
        create_curve -name ${pp0}_IV -dataset Dataset_$pp0\
            -axisX $xVar -axisY "$bCon TotalCurrent"
        create_curve -name ${pp0}_VV -dataset Dataset_$pp0\
            -axisX $xVar -axisY $xVar
        create_curve -name ${pp0}_JV -function "1e3*<${pp0}_IV>/$jArea"
        create_curve -name ${pp0}_P -function "<${pp0}_JV>*<${pp0}_VV>"
        remove_curves "${pp0}_IV ${pp0}_VV"
        set jog [expr 1e3*$q*[lindex [get_variable_data -dataset\
            Dataset_$pp0 "IntegrSemiconductor $ogPlt"] end]/$intArea]

        # Extract Jsc, Voc, Eff and FF for light JV
        if {$jog > 0} {

            # Calculate photogeneration current density
            vputs -i2 [format "Photogeneration current density:\
                %.4g mA*cm^-2" $jog]
            set tmp [format %.4g $jog]
            vputs -i2 "DOE: ${pp0}_Jog $tmp"
            set gVarArr(${pp0}_Jog|mA*cm^-2) $tmp

            # Need to check the previous mono/spectrum scaling from 'VarVary'
            set suns 0
            set str ""
            for {set i [expr $vIdx-1]} {$i >= 0} {incr i -1} {
                if {[lindex $VarVary $i 0] eq "SpecScaling"
                    || [lindex $VarVary $i 0] eq "MonoScaling"} {
                    set suns [lindex $VarVary $i 1]
                    set str [lindex $VarVary $i 0]
                    break
                }
            }
            if {$suns == 0} {
                vputs -i2 "error: no illumination intensity for light JV!"
                continue
            }
            vputs -i2 "DOE: ${pp0}_Scaling $suns"
            set gVarArr(${pp0}_Scaling) $suns

            # Extract the spectrum power [mW*cm^-2]
            if {$str eq "SpecScaling"} {
                set pSpec [expr [specInt [lindex $MiscAttr 0]]*$suns]
            } else {
                set pSpec [expr 1e3*[lindex $MiscAttr 5]*$suns]
            }
            set tmp [format %.4g $pSpec]
            vputs -i2 "DOE: ${pp0}_Pspec $tmp"
            set gVarArr(${pp0}_Pspec|mW*cm^-2) $tmp

            # Extract maximum current density
            set jLst [get_curve_data ${pp0}_JV -axisY\
                -plot PltJV_$pp0]
            set maxJ [lindex [lsort -real $jLst] end]
            vputs -i2 [format "Max current density: %.4g mA*cm^-2" $maxJ]
            if {$xLow <= 0} {
                set jsc [lindex [probe_curve ${pp0}_JV -valueX 0\
                    -plot PltJV_$pp0] 0]
            } else {
                set jsc 1
            }

            # Extract Jsc, Voc, Eff and FF for forward bias only
            if {$jsc < 0} {
                set tmp [format %.4g [expr abs($jsc)]]
                vputs -i2 [format "Short circuit current density:\
                    %.4g mA*cm^-2" $tmp]
                vputs -i2 "DOE: ${pp0}_Jsc $tmp"
                set gVarArr(${pp0}_Jsc|mA*cm^-2) $tmp
                set pLst [get_curve_data ${pp0}_P -axisY -plot PltJV_$pp0]
                set pmpp 0
                set vmpp 0
                set jmpp 0
                foreach j $jLst v $xLst p $pLst {
                    if {$p < $pmpp} {
                        set pmpp $p
                        set vmpp $v
                        set jmpp $j
                    }
                }
                set tmp [format %.4g [expr abs($pmpp)]]
                vputs -i2 "DOE: ${pp0}_Pmpp $tmp"
                set gVarArr(${pp0}_Pmpp|mW*cm^-2) $tmp
                set tmp [format %.4g [expr 1e2*abs($pmpp)/$pSpec]]
                vputs -i2 "DOE: ${pp0}_Eff $tmp"
                set gVarArr(${pp0}_Eff|%) $tmp
                set tmp [format %.4g $vmpp]
                vputs -i2 "DOE: ${pp0}_Vmpp $tmp"
                set gVarArr(${pp0}_Vmpp|V) $tmp
                if {$maxJ > 0} {
                    set voc [lindex [probe_curve ${pp0}_JV -valueY 0\
                        -plot PltJV_$pp0] 0]
                    set foundVoc true
                    set tmp [format %.4g [lindex $voc 0]]
                    vputs -i2 "DOE: ${pp0}_Voc $tmp"
                    set gVarArr(${pp0}_Voc|V) $tmp
                } else {
                    set foundVoc false
                    vputs -i2 "Voc could NOT be extracted!"
                }
                if {$foundVoc} {
                    set tmp [format %.4g [expr 1e2*$pmpp/$voc/$jsc]]
                    vputs -i2 "DOE: ${pp0}_FF $tmp"
                    set gVarArr(${pp0}_FF) $tmp
                    set tmp [format %.4g [expr abs($jmpp)]]
                    vputs -i2 "DOE: ${pp0}_Jmpp $tmp"
                    set gVarArr(${pp0}_Jmpp|mA*cm^-2) $tmp
                }
            }
        }

        windows_style -style max
        set_plot_prop -show_grid -show_curve_markers\
            -title_font_size 28 -title $capJV
        set_grid_prop -show_minor_lines\
            -line1_style dash -line1_color gray\
            -line2_style dot -line2_color lightGray
        set_axis_prop -axis x -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title $xCap -range "$xLow $xHigh"
        set jLst [lsort -real $jLst]
        set_axis_prop -axis y -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title {Current densities|mA/cm2}\
            -range "[expr int([lindex $jLst 0])-2] 5"
        set pLst [lsort -real $pLst]
        set_axis_prop -axis y2 -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title {Power densities|mW/cm2}\
            -range "[expr int([lindex $pLst 0])-2] 0"
        set_legend_prop -location top_left

        vputs -i2 "Save all curves to $fJV"
        foreach curve [list_curves -plot PltJV_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            if {$str eq "JV"} {
                set_curve_prop $curve -label $str -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title] -> str
            } else {
                set_curve_prop $curve -label $str -axis right -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title] -> str
            }
            incr pCnt
            curve2CSV $curve $xCap [get_curve_prop $curve -label]|$str\
                PltJV_$pp0 $fJV
        }

    } elseif {[lindex $pp 1] eq "QE"} {
        set capQE "n@node@_${pp0}: QE at $T K"
        set fQE $SimArr(OutDir)/n@node@_${pp0}_QE.csv

        # Find a voltage contact
        if {[llength $IntfCon]} {
            foreach grp $IntfCon {
                if {![regexp {^C} [lindex $grp 2]]} {
                    set con [lindex $grp 1]
                    break
                }
            }
        } else {
            vputs -i2 "error: no voltage contact for QE calculation!"
            continue
        }

        # Verify the current 'VarVary' step
        if {[lindex $VarVary $vIdx 0] eq "Wavelength"} {

            # Need to check the nearest mono varying step in 'VarVary'
            set val 0
            for {set idx [expr $vIdx-1]} {$idx >= 0} {incr idx -1} {
                if {[lindex $VarVary $idx 0] eq "MonoScaling"} {
                    set val [lindex $VarVary $idx 1]
                    break
                }
            }
            if {$val == 0} {
                vputs -i2 "error: no monochromatic intensity for QE!"
                continue
            }

            # Extract jOGBias and jscBias
            load_file v${idx}_@plot@ -name v${idx}_Tmp
            set Lst [lsort -real [get_variable_data -dataset\
                v${idx}_Tmp "IntegrSemiconductor $specOG"]]
            set jOGBias [expr 1e3*$q*[lindex $Lst 0]/$intArea]
            set Lst [lsort -real [get_variable_data\
                -dataset v${idx}_Tmp "$con TotalCurrent"]]
            set jscBias [expr 1e3*[lindex $Lst 0]/$jArea]
            vputs -i2 [format "Extracted JOG/Jsc at bias light:\
                %.4g/%.4g mA*cm^-2" $jOGBias $jscBias]
            unload_file v${idx}_@plot@
            set pSig [expr [lindex $MiscAttr 5]*[lindex $VarVary $idx 1]]
            vputs -i2 "Monochromatic signal light intensity:\
                $pSig W*cm^-2"
        } else {
            vputs -i2 "error: element '$vIdx' of 'VarVary' not wavelength!"
            continue
        }
        create_plot -name PltQE_$pp0 -1d
        select_plots PltQE_$pp0
        vputs -i2 "Create wavelength variable \[um -> nm\]"
        set xVar Wavelength|nm
        set xCap $xVar
        create_variable -name $xVar -dataset Dataset_$pp0\
            -function "<$wlPlt:Dataset_$pp0>*1e3"

        # Extract X axis and data trend (ascending or not)
        set xLst [get_variable_data -dataset Dataset_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr ($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]

        vputs -i2 "Creating differential Jsc curve"
        create_curve -name ${pp0}_ww -dataset Dataset_$pp0\
            -axisX $xVar -axisY $xVar
        create_curve -name ${pp0}_jscBias -function "$jscBias+<${pp0}_ww>*0"

        # X in nm, Y in mA*cm^-2
        create_curve -name ${pp0}_jsc -dataset Dataset_$pp0\
            -axisX $xVar -axisY "$con TotalCurrent"
        create_curve -name ${pp0}_jscSig -function\
            "abs(1e3*<${pp0}_jsc>/$jArea-<${pp0}_jscBias>)"
        vputs -i2 "Calculating signal photon current..."

        # X in nm, Y in mA*cm^-2 (J*s^-1*cm^2/(J*s*m/s/m) )
        create_curve -name ${pp0}_jSig\
            -function "1e3*$q*$pSig/($h*$c0/(1e-9*<${pp0}_ww>))"
        vputs -i2 "Creating differential optical generation from\
            signal only..."
        create_curve -name ${pp0}_NogSig -dataset Dataset_$pp0\
            -axisX $xVar -axisY "IntegrSemiconductor $monoOG"
        create_curve -name ${pp0}_jogSig -function\
            "1e3*$q*<${pp0}_NogSig>/$intArea"
        vputs -i2 "Creating quantum efficiency curves..."
        create_curve -name ${pp0}_dEQE -function\
            "1e2*<${pp0}_jscSig>/<${pp0}_jSig>"
        create_curve -name ${pp0}_dIQE -function\
            "1e2*<${pp0}_jscSig>/<${pp0}_jogSig>"
        remove_curves "${pp0}_ww ${pp0}_jscBias\
            ${pp0}_jsc ${pp0}_NogSig"

        windows_style -style max
        set_plot_prop -show_grid -show_curve_markers\
            -title_font_size 28 -title $capQE
        set_grid_prop -show_minor_lines -line1_style dash\
            -line1_color gray -line2_style dot -line2_color lightGray
        set_axis_prop -axis x -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title $xCap -range "$xLow $xHigh"
        set_axis_prop -axis y -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title {QE|%} -range "-1 101"
        set_axis_prop -axis y2 -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title {Current densities|mA*cm^-2}
        set_legend_prop -location top_left

        vputs -i2 "Save all curves to $fQE"
        foreach curve [list_curves -plot PltQE_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            if {[regexp {^v\d+_d} $curve]} {
                set_curve_prop $curve -label $str -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title] -> str
            } else {
                set_curve_prop $curve -label $str -axis right -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title] -> str
            }
            incr pCnt
            curve2CSV $curve $xCap [get_curve_prop $curve -label]|$str\
                PltQE_$pp0 $fQE
        }

    } elseif {[lindex $pp 1] eq "QSSPC"} {
        set captau "n@node@_${pp0}: lifetime at $T K"
        set ftau $SimArr(OutDir)/n@node@_${pp0}_lifetime.csv
        set capJ0 "n@node@_${pp0}: J0 at $T K"
        set fJ0 $SimArr(OutDir)/n@node@_${pp0}_J0.csv

        # Verify the current 'VarVary' step
        if {[lindex $VarVary $vIdx 0] ne "SpecScaling"
            && [lindex $VarVary $vIdx 0] ne "MonoScaling"} {
            vputs -i2 "error: element '$vIdx' of 'VarVary' not 'SpecScaling'\
                and 'MonoScaling'!"
            continue
        }

        # Use the first Dn from position or average as the X axis
        vputs -i2 "Create Delta n variable \[cm^-3\]"
        set var [format %g [expr $YMax/2.]]
        set dnLst [list]
        foreach grp $VV2Fld {
            set txt ""
            set str [string range [lindex $grp 0] 1 end]
            if {[regexp {^p[^/]+$} [lindex $grp 0]]
                && [regexp { Dn} $grp]} {
                if {$Dim == 1} {
                    set txt Pos($str,$var)
                } else {
                    set txt Pos([string map {_ ,} $str])
                }
            }
            if {![regexp {^p[^/]+$} [lindex $grp 0]]
                && [regexp {\{Average[^\}]+Dn} $grp]} {
                if {[regexp {r\d+} [lindex $grp 0]]} {
                    set txt Ave[lindex $RegGen $str 0 1]
                } elseif {[regexp {r\d+/\d+} [lindex $grp 0]]} {
                    set lst [split $str /]
                    set txt Ave[lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
                        $RegGen [lindex $lst 1] 0 1]
                } else {
                    set lst [split $str /]
                    if {$Dim == 1} {
                        set txt AveWindow(([lindex $lst 0],0),([lindex\
                            $lst 1],$YMax))
                    } else {
                        set txt AveWindow(([string map {_ , / ),(} $str]))
                    }
                }
            }
            if {$txt ne ""} {
                set dopLst [get_variable_data -dataset Dataset_$pp0\
                    "$txt DopingConcentration"]
                set niLst [get_variable_data -dataset Dataset_$pp0\
                    "$txt EffectiveIntrinsicDensity"]
                if {[lindex $niLst 0] < [lindex $niLst end]} {
                    if {[lindex $dopLst 0] == 0} {
                        set val [expr abs([lindex $dopLst 0])]
                    } else {
                        set val [expr pow([lindex $niLst 0],2)/abs([lindex\
                            $dopLst 0])]
                    }
                } else {
                    if {[lindex $dopLst 0] == 0} {
                        set val [expr abs([lindex $dopLst end])]
                    } else {
                        set val [expr pow([lindex $niLst end],2)/abs([lindex\
                            $dopLst 0])]
                    }
                }
                if {[lindex $dopLst 0] >= 0} {
                    create_variable -name "Dn|cm^-3 [lindex $grp 0]"\
                        -dataset Dataset_$pp0\
                        -function "<$txt hDensity:Dataset_$pp0>-$val"
                } else {
                    create_variable -name "Dn|cm^-3 [lindex $grp 0]"\
                        -dataset Dataset_$pp0\
                        -function "<$txt eDensity:Dataset_$pp0>-$val"
                }

                # Create the normalised pn for the first Dn: (pn - ni^2)/ni^2
                if {![llength $dnLst]} {
                    set xVar "Dn|cm^-3 [lindex $grp 0]"
                    set xCap Dn_[lindex $grp 0]|cm^-3
                    create_variable -name Normalised_pn -dataset Dataset_$pp0\
                        -function "(<$txt hDensity:Dataset_$pp0>\
                        *<$txt eDensity:Dataset_$pp0>\
                        -pow(<$txt EffectiveIntrinsicDensity:Dataset_$pp0>,2))\
                        /pow(<$txt EffectiveIntrinsicDensity:Dataset_$pp0>,2)"
                }
                lappend dnLst [lindex $grp 0]
            }
        }
        if {![llength $dnLst]} {
            error "no 'Dn' in 'VV2Fld'!"
        }

        # Extract X axis and data trend (ascending or not)
        set xLst [get_variable_data -dataset Dataset_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr ($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]

        create_plot -name Plttau_$pp0 -1d
        windows_style -style max
        set_plot_prop -show_grid -show_curve_markers\
            -title_font_size 28 -title $captau
        set_grid_prop -show_minor_lines -line1_style dash\
            -line1_color gray -line2_style dot -line2_color lightGray
        set_axis_prop -axis x -title_font_size 20 -type log\
            -scale_font_size 16 -scale_format preferred\
            -title $xCap
        set_axis_prop -axis y -title_font_size 20 -type log\
            -scale_font_size 16 -scale_format preferred\
            -title {Lifetime|s}
        if {[llength $dnLst] > 1} {
            set_axis_prop -axis y2 -title_font_size 20 -type log\
                -scale_font_size 16 -scale_format preferred\
                -title {Excess carrier density|cm^-3}
        }
        set_legend_prop -location top_left

        create_plot -name PltJ0_$pp0 -1d

        # Extract volume of all semiconductors [cm^3]
        set vol [expr [lindex [get_variable_data -dataset Dataset_$pp0\
            "IntegrSemiconductor $ogPlt"] 1]/[lindex [get_variable_data\
            -dataset Dataset_$pp0 "AveSemiconductor $ogPlt"] 1]]
        vputs -i3 "Total semiconductor region volume: $vol cm^3"

        if {[llength $dnLst] > 1} {
            vputs -i2 "Create the rest excess carrier density curves"
            foreach elm [lrange $dnLst 1 end] {
                create_curve -name ${pp0}_8|Dn_$elm -dataset Dataset_$pp0\
                    -axisX $xVar -axisY2 "Dn|cm^-3 $elm" -plot Plttau_$pp0
            }
        }

        # Extract scaling factor
        set sLst [list]
        for {set i $vIdx} {$i >= 0} {incr i -1} {
            if {[lindex $VarVary $i 0] eq "MonoScaling"
                || [lindex $VarVary $i 0] eq "SpecScaling"} {
                if {[llength $sLst]
                    && [lindex $VarVary $i 0] ne [lindex $sLst end 0]} {
                    continue
                }
                lappend sLst [lrange [lindex $VarVary $i] 0 1]
            }
        }
        if {[llength $sLst] == 1} {
            lappend sLst [list [lindex $sLst end 0] 0]
        }
        vputs -i2 "Create the [lindex $sLst 0 0] curve"
        create_variable -name Scaling -dataset Dataset_$pp0\
            -function "[lindex $sLst 1 1]+<time:Dataset_$pp0>\
            *([lindex $sLst 0 1]-[lindex $sLst 1 1])"
        create_curve -name ${pp0}_9|Scaling -dataset Dataset_$pp0\
            -axisX $xVar -axisY2 "Scaling" -plot Plttau_$pp0

        vputs -i2 "Create the effective lifetime curve"
        create_variable -name tau_eff -dataset Dataset_$pp0\
            -function "<$xVar:Dataset_$pp0>*$vol\
            /<IntegrSemiconductor $ogPlt:Dataset_$pp0>"
        create_curve -name ${pp0}_0|tau_eff -dataset Dataset_$pp0\
            -axisX $xVar -axisY tau_eff -plot Plttau_$pp0
        vputs -i2 "Create the total J0 curve"
        create_variable -name J0_sum -dataset Dataset_$pp0\
            -function "<IntegrSemiconductor $ogPlt:Dataset_$pp0>\
            *1e15*$q/$intArea/<Normalised_pn:Dataset_$pp0>"
        create_curve -name ${pp0}_0|J0_sum -dataset Dataset_$pp0\
            -axisX $xVar -axisY J0_sum -plot PltJ0_$pp0

        # Extract effective lifetime at 1e15 cm^-3
        if {[lindex $pp 2] > $xLow && [lindex $pp 2] < $xHigh} {
            set tmp [lindex [probe_curve ${pp0}_0|tau_eff\
                -valueX [lindex $pp 2] -plot Plttau_$pp0] 0]
            vputs -i3 "DOE: ${pp0}_tau_eff [format %.4g $tmp]"
            set gVarArr(${pp0}_tau_eff) [format %.4g $tmp]
        }

        vputs -i2 "Create lifetime/J0 curves in regions"
        foreach grp $RegGen {
            set mat [lindex $grp 0 0]
            set reg [lindex $grp 0 1]
            if {[lindex $grp 0 2] ne "Semiconductor"} continue
            if {$mat eq "Silicon" || [regexp \\\{r[lindex $grp 0\
                end]\[^\\\}\]+Aug $ModPar]} {
                vputs -i3 Aug_$reg
                create_variable -name tau_Aug_$reg -dataset Dataset_$pp0\
                    -function "<$xVar:Dataset_$pp0>*$vol\
                    /(<Integr$reg AugerRecombination:Dataset_$pp0>\
                    +<Integr$reg PMIRecombination:Dataset_$pp0>)"
                create_curve -name ${pp0}_1|tau_Aug_$reg -dataset Dataset_$pp0\
                    -axisX $xVar -axisY tau_Aug_$reg -plot Plttau_$pp0
                create_variable -name J0_Aug_$reg -dataset Dataset_$pp0\
                    -function "(<Integr$reg AugerRecombination:Dataset_$pp0>\
                    +<Integr$reg PMIRecombination:Dataset_$pp0>)\
                    *1e15*$q/$intArea/<Normalised_pn:Dataset_$pp0>"
                create_curve -name ${pp0}_1|J0_Aug_$reg -dataset Dataset_$pp0\
                    -axisX $xVar -axisY J0_Aug_$reg -plot PltJ0_$pp0
            }
            if {$mat eq "Silicon" || [regexp \\\{r[lindex $grp 0\
                end]\[^\\\}\]+Rad $ModPar]} {
                vputs -i3 B2B_$reg
                create_variable -name tau_B2B_$reg -dataset Dataset_$pp0\
                    -function "<$xVar:Dataset_$pp0>*$vol\
                    /<Integr$reg RadiativeRecombination:Dataset_$pp0>"
                create_curve -name ${pp0}_1|tau_B2B_$reg -dataset Dataset_$pp0\
                    -axisX $xVar -axisY tau_B2B_$reg -plot Plttau_$pp0
                create_variable -name J0_B2B_$reg -dataset Dataset_$pp0\
                    -function "<Integr$reg RadiativeRecombination:Dataset_$pp0>\
                    *1e15*$q/$intArea/<Normalised_pn:Dataset_$pp0>"
                create_curve -name ${pp0}_1|J0_B2B_$reg -dataset Dataset_$pp0\
                    -axisX $xVar -axisY J0_B2B_$reg -plot PltJ0_$pp0
            }
            vputs -i3 SRH_$reg
            create_variable -name tau_SRH_$reg -dataset Dataset_$pp0\
                -function "<$xVar:Dataset_$pp0>*$vol\
                /<Integr$reg srhRecombination:Dataset_$pp0>"
            create_curve -name ${pp0}_1|tau_SRH_$reg -dataset Dataset_$pp0\
                -axisX $xVar -axisY tau_SRH_$reg -plot Plttau_$pp0
            create_variable -name J0_SRH_$reg -dataset Dataset_$pp0\
                -function "<Integr$reg srhRecombination:Dataset_$pp0>\
                *1e15*$q/$intArea/<Normalised_pn:Dataset_$pp0>"
            create_curve -name ${pp0}_1|J0_SRH_$reg -dataset Dataset_$pp0\
                -axisX $xVar -axisY J0_SRH_$reg -plot PltJ0_$pp0
            if {[regexp \\\{$reg $RegIntfTrap]} {
                vputs -i3 Trap_$reg
                create_variable -name tau_Trap_$reg -dataset Dataset_$pp0\
                    -function "<$xVar:Dataset_$pp0>*$vol\
                    /<Integr$reg eGapStatesRecombination:Dataset_$pp0>"
                create_curve -name ${pp0}_1|tau_Trap_$reg -dataset Dataset_$pp0\
                    -axisX $xVar -axisY tau_Trap_$reg -plot Plttau_$pp0
                create_variable -name J0_Trap_$reg -dataset Dataset_$pp0\
                    -function\
                    "<Integr$reg eGapStatesRecombination:Dataset_$pp0>\
                    *1e15*$q/$intArea/<Normalised_pn:Dataset_$pp0>"
                create_curve -name ${pp0}_1|J0_Trap_$reg -dataset Dataset_$pp0\
                    -axisX $xVar -axisY J0_Trap_$reg -plot PltJ0_$pp0
            }
        }

        vputs -i2 "Create lifetime curves at region interfaces"
        foreach grp $IntfSRH {
            if {![string is double -strict [lindex $grp 1]]
                || (![string is double -strict [lindex $grp 2]]
                && ![string is double -strict [lindex $grp 3]])} continue
            set lst [string map {r "" / " "} [lindex $grp 0]]
            set intf [lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
                $RegGen [lindex $lst 1] 0 1]
            vputs -i2 $intf
            create_variable -name tau_$intf -dataset Dataset_$pp0\
                -function "<$xVar:Dataset_$pp0>*$vol\
                /<Integr$intf SurfaceRecombination:Dataset_$pp0>"
            create_curve -name ${pp0}_2|tau_$intf -dataset Dataset_$pp0\
                -axisX $xVar -axisY tau_$intf -plot Plttau_$pp0
            create_variable -name J0_$intf -dataset Dataset_$pp0\
                -function "<Integr$intf SurfaceRecombination:Dataset_$pp0>\
                *1e15*$q/$intArea/<Normalised_pn:Dataset_$pp0>"
            create_curve -name ${pp0}_2|J0_$intf -dataset Dataset_$pp0\
                -axisX $xVar -axisY J0_$intf -plot PltJ0_$pp0
        }

        if {[llength $IntfCon]} {
            vputs -i2 "Plot lifetime curves at contacts"
            foreach grp $IntfCon {
                set con [lindex $grp 1]
                if {[regexp {^C} [lindex $grp 2]]} continue
                vputs -i3 $con
                if {abs([lindex [get_variable_data -dataset Dataset_$pp0\
                    "$con eCurrent"] 0]) < abs([lindex [get_variable_data\
                    -dataset Dataset_$pp0 "$con hCurrent"] 0])} {
                    create_variable -name tau_$con -dataset Dataset_$pp0\
                        -function "<$xVar:Dataset_$pp0>*$vol*$q\
                        /abs(<$con eCurrent:Dataset_$pp0>)"
                    create_variable -name J0_$con -dataset Dataset_$pp0\
                        -function "abs(<$con eCurrent:Dataset_$pp0>)\
                        *1e15/$intArea/<Normalised_pn:Dataset_$pp0>"
                } else {
                    create_variable -name tau_$con -dataset Dataset_$pp0\
                        -function "<$xVar:Dataset_$pp0>*$vol*$q\
                        /abs(<$con hCurrent:Dataset_$pp0>)"
                    create_variable -name J0_$con -dataset Dataset_$pp0\
                        -function "abs(<$con hCurrent:Dataset_$pp0>)\
                        *1e15/$intArea/<Normalised_pn:Dataset_$pp0>"
                }
                create_curve -name ${pp0}_3|tau_$con -dataset Dataset_$pp0\
                    -axisX $xVar -axisY tau_$con -plot Plttau_$pp0
                create_curve -name ${pp0}_3|J0_$con -dataset Dataset_$pp0\
                    -axisX $xVar -axisY J0_$con -plot PltJ0_$pp0
            }
        }

        windows_style -style max
        set_plot_prop -show_grid -show_curve_markers\
            -title_font_size 28 -title $capJ0
        set_grid_prop -show_minor_lines -line1_style dash\
            -line1_color gray -line2_style dot -line2_color lightGray
        set_axis_prop -axis x -title_font_size 20 -type log\
            -scale_font_size 16 -scale_format preferred\
            -title $xCap
        set_axis_prop -axis y -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title {J0|fA*cm^-2}
        set_legend_prop -location top_left

        vputs -i2 "Save all curves to $ftau"
        foreach curve [list_curves -plot Plttau_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            if {$str eq "9|Scaling"} {
                set_curve_prop $curve -label $str -axis right -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]\
                    -plot Plttau_$pp0
            } else {
                set_curve_prop $curve -label $str -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]\
                    -plot Plttau_$pp0
            }
            incr pCnt
            if {[regexp {^v\d+_8\|Dn} $curve]} {
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title\
                    -plot Plttau_$pp0] -> str
            } elseif {[regexp {^v\d+_9\|Scaling} $curve]} {
                set str Suns
            } else {
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                    -plot Plttau_$pp0] -> str
            }
            curve2CSV $curve $xCap [get_curve_prop $curve -label\
                -plot Plttau_$pp0]|$str Plttau_$pp0 $ftau
        }

        vputs -i2 "Save all curves to $fJ0"
        foreach curve [list_curves -plot PltJ0_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            set_curve_prop $curve -label $str -markers_type\
                [lindex $markerLst [expr $pCnt%$markerLen]] -plot PltJ0_$pp0
            incr pCnt
            regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                -plot PltJ0_$pp0] -> str
            curve2CSV $curve $xCap [get_curve_prop $curve -label\
                -plot PltJ0_$pp0]|$str PltJ0_$pp0 $fJ0
        }
        continue

    } elseif {[lindex $pp 1] eq "SunsVoc"} {
        set capSVoc "n@node@_${pp0}: Suns-Voc at $T K"
        set fSVoc $SimArr(OutDir)/n@node@_${pp0}_Suns-Voc.csv

    }

    # Current density loss analysis
    set capJLoss "n@node@_${pp0}: JLoss at $T K"
    set fJLoss $SimArr(OutDir)/n@node@_${pp0}_JLoss.csv
    create_plot -name ${pp0}_PltJLoss -1d
    vputs -i2 "\nPlot current density loss curves in regions"
    foreach grp $RegGen {
        set mat [lindex $grp 0 0]
        set reg [lindex $grp 0 1]
        if {[lindex $grp 0 2] ne "Semiconductor"} continue
        if {$mat eq "Silicon" || [regexp \\\{r[lindex $grp 0\
            end]\[^\\\}\]+Aug $ModPar]} {
            create_curve -name ${pp0}_RAug_$reg -dataset Dataset_$pp0\
                -axisX $xVar -axisY "Integr$reg AugerRecombination"
            create_curve -name ${pp0}_RPMI_$reg -dataset Dataset_$pp0\
                -axisX $xVar -axisY "Integr$reg PMIRecombination"
            vputs -i3 Aug_$reg
            create_curve -name ${pp0}_2|Aug_$reg -function\
                "1e3*$q*(<${pp0}_RAug_$reg>+<${pp0}_RPMI_$reg>)/$intArea"
            remove_curves "${pp0}_RAug_$reg ${pp0}_RPMI_$reg"
        }
        if {$mat eq "Silicon" || [regexp \\\{r[lindex $grp 0\
            end]\[^\\\}\]+Rad $ModPar]} {
            create_curve -name ${pp0}_RB2B_$reg -dataset Dataset_$pp0\
                -axisX $xVar -axisY "Integr$reg RadiativeRecombination"
            vputs -i3 B2B_$reg
            create_curve -name ${pp0}_3|B2B_$reg -function\
                "1e3*$q*<${pp0}_RB2B_$reg>/$intArea"
            remove_curves ${pp0}_RB2B_$reg
        }
        create_curve -name ${pp0}_RSRH_$reg -dataset Dataset_$pp0\
            -axisX $xVar -axisY "Integr$reg srhRecombination"
        vputs -i3 SRH_$reg
        create_curve -name ${pp0}_0|SRH_$reg -function\
            "1e3*$q*<${pp0}_RSRH_$reg>/$intArea"
        remove_curves ${pp0}_RSRH_$reg
        if {[regexp \\\{$reg $RegIntfTrap]} {
            create_curve -name ${pp0}_RTrap_$reg -dataset Dataset_$pp0\
                -axisX $xVar -axisY "Integr$reg eGapStatesRecombination"
            vputs -i3 Trap_$reg
            create_curve -name ${pp0}_1|Trap_$reg -function\
                "1e3*$q*<${pp0}_RTrap_$reg>/$intArea"
            remove_curves ${pp0}_RTrap_$reg
        }
    }

    vputs -i2 "Plot current density loss curves at region interfaces"
    foreach grp $IntfSRH {
        if {![string is double -strict [lindex $grp 1]]
            || (![string is double -strict [lindex $grp 2]]
            && ![string is double -strict [lindex $grp 3]])} continue
        set lst [string map {r "" / " "} [lindex $grp 0]]
        set intf [lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
            $RegGen [lindex $lst 1] 0 1]
        create_curve -name ${pp0}_[lindex $grp 0] -dataset Dataset_$pp0\
            -axisX $xVar -axisY "Integr$intf SurfaceRecombination"
        vputs -i3 $intf
        create_curve -name ${pp0}_4|$intf -function\
            "1e3*$q*<${pp0}_[lindex $grp 0]>/$intArea"
        remove_curves ${pp0}_[lindex $grp 0]
    }

    # Extract minority carrier current density from contacts
    vputs -i2 "Plot current density loss curves at contacts"
    foreach grp $IntfCon {
        set con [lindex $grp 1]
        if {[regexp {^C} [lindex $grp 2]]} continue
        vputs -i3 $con
        if {abs([lindex [get_variable_data -dataset Dataset_$pp0\
            "$con eCurrent"] 0]) < abs([lindex [get_variable_data\
            -dataset Dataset_$pp0 "$con hCurrent"] 0])} {
            create_curve -name ${pp0}_Ie_$con -dataset Dataset_$pp0\
                -axisX $xVar -axisY "$con eCurrent"
            create_curve -name ${pp0}_5|$con\
                -function "1e3*abs(<${pp0}_Ie_$con>)/$jArea"
            remove_curves ${pp0}_Ie_$con
        } else {
            create_curve -name ${pp0}_Ih_$con -dataset Dataset_$pp0\
                -axisX $xVar -axisY "$con hCurrent"
            create_curve -name ${pp0}_5|$con\
                -function "1e3*abs(<${pp0}_Ih_$con>)/$jArea"
            remove_curves ${pp0}_Ih_$con
        }
    }

    # Use the Dn from position or average from 'VV2Fld'
    vputs -i2 "Create Delta n variable \[cm^-3\]"
    set var [format %g [expr $YMax/2.]]
    set dnLst [list]
    foreach grp $VV2Fld {
        set txt ""
        set str [string range [lindex $grp 0] 1 end]
        if {[regexp {^p[^/]+$} [lindex $grp 0]]
            && [regexp { Dn} $grp]} {
            if {$Dim == 1} {
                set txt Pos($str,$var)
            } else {
                set txt Pos([string map {_ ,} $str])
            }
        }
        if {![regexp {^p[^/]+$} [lindex $grp 0]]
            && [regexp {\{Average[^\}]+Dn} $grp]} {
            if {[regexp {r\d+} [lindex $grp 0]]} {
                set txt Ave[lindex $RegGen $str 0 1]
            } elseif {[regexp {r\d+/\d+} [lindex $grp 0]]} {
                set lst [split $str /]
                set txt Ave[lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
                    $RegGen [lindex $lst 1] 0 1]
            } else {
                set lst [split $str /]
                if {$Dim == 1} {
                    set txt AveWindow(([lindex $lst 0],0),([lindex\
                        $lst 1],$YMax))
                } else {
                    set txt AveWindow(([string map {_ , / ),(} $str]))
                }
            }
        }
        if {$txt ne ""} {
            vputs -i3 $txt
            set dopLst [get_variable_data -dataset Dataset_$pp0\
                "$txt DopingConcentration"]
            set niLst [get_variable_data -dataset Dataset_$pp0\
                "$txt EffectiveIntrinsicDensity"]
            if {[lindex $niLst 0] < [lindex $niLst end]} {
                if {[lindex $dopLst 0] == 0} {
                    set val [expr abs([lindex $dopLst 0])]
                } else {
                    set val [expr pow([lindex $niLst 0],2)/abs([lindex\
                        $dopLst 0])]
                }
            } else {
                if {[lindex $dopLst 0] == 0} {
                    set val [expr abs([lindex $dopLst end])]
                } else {
                    set val [expr pow([lindex $niLst end],2)/abs([lindex\
                        $dopLst 0])]
                }
            }
            if {[lindex $dopLst 0] >= 0} {
                create_variable -name "Dn|cm^-3 [lindex $grp 0]"\
                    -dataset Dataset_$pp0\
                    -function "<$txt hDensity:Dataset_$pp0>-$val"
            } else {
                create_variable -name "Dn|cm^-3 [lindex $grp 0]"\
                    -dataset Dataset_$pp0\
                    -function "<$txt eDensity:Dataset_$pp0>-$val"
            }
            lappend dnLst [lindex $grp 0]
        }
    }
    if {[llength $dnLst]} {
        vputs -i2 "Create excess carrier density curves"
        foreach elm $dnLst {
            create_curve -name ${pp0}_9|Dn_$elm -dataset Dataset_$pp0\
                -axisX $xVar -axisY2 "Dn|cm^-3 $elm"
        }
    }

    windows_style -style max
    set_plot_prop -show_grid -show_curve_markers\
        -title_font_size 28 -title $capJLoss
    set_grid_prop -show_minor_lines\
        -line1_style dash -line1_color gray\
        -line2_style dot -line2_color lightGray
    set_axis_prop -axis x -title_font_size 20 -type linear\
        -scale_font_size 16 -scale_format preferred\
        -title $xCap -range "$xLow $xHigh"
    set_axis_prop -axis y -title_font_size 20 -type log\
        -scale_font_size 16 -scale_format preferred\
        -title {Loss current densities|mA*cm^-2}
    set_axis_prop -axis y2 -title_font_size 20 -type log\
        -scale_font_size 16 -scale_format preferred\
        -title {Excess carrier densities|cm^-3}
    set_legend_prop -location top_left

    vputs -i2 "Save all curves to $fJLoss"
    foreach curve [list_curves -plot ${pp0}_PltJLoss] {
        regexp {^v\d+_(.+)$} $curve -> str
        set_curve_prop $curve -label $str -markers_type\
            [lindex $markerLst [expr $pCnt%$markerLen]]
        incr pCnt
        if {[regexp {^v\d+_9\|Dn} $curve]} {
            regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title] -> str
        } else {
            regexp {\|(\S+)$} [get_axis_prop -axis Y -title] -> str
        }
        curve2CSV $curve $xCap [get_curve_prop $curve -label]|$str\
            ${pp0}_PltJLoss $fJLoss
    }

} ;# end of foreach

# Update the file 'SimArr(OutDir)/SimArr(FDOESum)'
gVar2DOESum gVarArr @node@
vputs "\nDone!"