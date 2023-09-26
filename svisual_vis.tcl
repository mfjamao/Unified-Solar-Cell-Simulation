!(

#--- Get TCL global variables
#include ".mfj/varSim.tcl"

# Alert users to remove/combine duplicate vv#
set PPAttr [lsort -index 0 [str2List "" $PPAttr]]
if {[llength [lsort -unique -index 0 $PPAttr]] < [llength $PPAttr]} {
    error "duplicate entries found in PPAttr '$PPAttr'!"
}

)!

#setdep @previous@
#--- Get TCL parameters
!(

foreach var {RegGen VarVary DfltAttr VV2Fld SS2Fld PPAttr GopAttr
    IntfCon IntfTun IntfSRV RegIntfTrap ModPar\
    Dim Cylind OptOnly LoadTDR XMax YMax ZMax} {
    vputs -n -i-3 "
        set $var \{[regsub -all {\s+} [set $var] " "]\}"
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
# In integer division like a/b, if a < b, a/b = 0, which is undesired.
# So it is necessary to convert either a or b to a real number. For example,
# 1/3 = 0; 1./3 = 0.3333333333333333; 1/3. = 0.3333333333333333
set PI [expr 2*asin(1)]
set mu0 [expr {4e-7*$PI}]
set c0 2.99792458e8
set q 1.602176634e-19
set eps0 [expr {1/($c0*$c0*$mu0)}]
set h 6.62607015e-34
set hB [expr {$h/$q}]
set k 1.380649e-23
set kB [expr {$k/$q}]
regexp {\{Other\s+([^\}]+)} $DfltAttr -> lst
set T [expr [lindex $lst 0]+273.15]

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
set inf [open n@previous@_des.out r]
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
    set jArea [expr 1e-8*$YMax*$ZMax]
    set intArea $jArea
} elseif {$Dim == 2 && $Cylind} {
    set jArea [expr 1e-8*$PI*pow($YMax,2)]
    set intArea $jArea
} else {
    set jArea [expr 1e-8*$YMax]
    set intArea [expr 1e-4*$YMax]
}
vputs -i1 "\njArea= $jArea cm^2, intArea= $intArea cm^2"

# RE for integers and real numbers (including scientific notation)
set RE_n {[+-]?(\.\d+|\d+(\.\d*)?)([eE][+-]?\d+)?}

# Regular expression for a position
set RE_p (${RE_n}_){0,2}$RE_n

# Process all saved snapshots at once according to SS2Fld
if {!$OptOnly && [regexp \\\{p$RE_p\\s $SS2Fld]} {
    foreach tdr [glob -d $SimArr(EtcDir) n@previous@_*_des.tdr] {
        set pCnt -1
        regexp {/n@previous@_(\w+)_des.tdr$} $tdr -> fID
        vputs -i1 "\nExtract fields from '$tdr'"
        load_file $tdr -name TDRData_$fID
        create_plot -name PltFld_$fID -dataset TDRData_$fID
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
                    create_cutplane -name TDRData_${fID}_Z[lindex $pLst 2]\
                        -plot PltFld_$fID -type z -at [lindex $pLst 2]
                    create_plot -name ${fID}_Z[lindex $pLst 2]\
                        -dataset TDRData_${fID}_Z[lindex $pLst 2]\
                        -ref_plot PltFld_$fID
                    create_cutline -name TDRData_${fID}_Y[lindex $pLst 1]\
                        -plot ${fID}_Z[lindex $pLst 2]\
                        -type y -at [lindex $pLst 1]
                    remove_plots ${fID}_Z[lindex $pLst 2]
                    remove_datasets TDRData_${fID}_Z[lindex $pLst 2]
                } else {
                    if {[llength $pLst] == 1} {
                        set yPos [expr $YMax/2.]
                    } else {
                        set yPos [lindex $pLst 1]
                    }
                    create_cutline -name TDRData_${fID}_Y[lindex $pLst 1]\
                        -plot PltFld_$fID -type y -at $yPos
                }
                create_plot -name ${fID}_$grp0\
                    -dataset TDRData_${fID}_Y[lindex $pLst 1] -1d
                foreach elm [lrange $grp 3 end] {
                    set str [lindex [split $mfjProc::tabArr($elm) |] 0]
                    create_curve -name ${grp0}_$elm\
                        -dataset TDRData_${fID}_Y[lindex $pLst 1]\
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

# Perform known data analysis and plot curves
# Note: The names of datasets, plots, and curves should be unique
set valIdx 0
foreach pp $PPAttr {
    set pp0 [lindex $pp 0]
    set vIdx [string range $pp0 1 end]
    set pCnt 0
    if {[lindex $pp 1] eq "RAT"} {
        vputs -i1 "\nn@node@_$pp0: Plot reflection,\
            absorption, and transmission curves"
    } elseif {[lindex $pp 1] eq "CV"} {
        vputs -i1 "\nn@node@_$pp0: Plot current density and power\
            density curves and save capaitance-voltage curves"
    } elseif {[lindex $pp 1] eq "JV"} {
        vputs -i1 "\nn@node@_$pp0: Plot current density and power\
            density curves"
    } elseif {[lindex $pp 1] eq "QE"} {
        vputs -i1 "\nn@node@_$pp0: Plot quantum efficiency curves"
    } elseif {[lindex $pp 1] eq "QSSPC"} {
        vputs -i1 "\nn@node@_$pp0: Plot lifetime curves"
    } elseif {[lindex $pp 1] eq "SunsVoc"} {
        vputs -i1 "\nn@node@_$pp0: Plot Suns-Voc curves"
    } elseif {[lindex $pp 1] eq "SunsJsc"} {
        vputs -i1 "\nn@node@_$pp0: Plot Suns-Jsc curves"
    }

    # Update 'ValArr' up to the previous step of 'VarVary'
    if {$vIdx > 0} {
        foreach grp [lrange $VarVary $valIdx [expr $vIdx-1]] {
            if {[regexp {^c\d$} [lindex $grp 0]]} {
                if {[string is double -strict [lindex $grp 1]]} {
                    set ValArr([lindex $grp 0]) [list\
                        [lindex $ValArr([lindex $grp 0]) 0] [lindex $grp 1]]
                } else {
                    set ValArr([lindex $grp 0]) [lindex $grp 1]
                }
            } elseif {[regexp {^(MonoScaling|SpecScaling|Wavelength)$}\
                [lindex $grp 0]]} {
                set ValArr([lindex $grp 0]) [lindex $grp 1]
            } else {
                if {[array names ValArr [lindex $grp 0]] eq [lindex $grp 0]} {
                    set ValArr([lindex $grp 0]) [lindex $grp 1]
                } else {
                    set tmp [split [lindex $grp 0] /]
                    set val [lindex $tmp end]
                    set tmp [join [lrange $tmp 0 end-1] /]
                    if {[string is double -strict $val]} {
                        array set ValArr [list $tmp [lindex $grp 1]]
                    } else {
                        error "no initial value for '[lindex $grp 0]'!"
                    }
                }
            }
        }
        set valIdx $vIdx
    }

    # Output raw data
    if {![file isfile ${pp0}_@plot@]} {
        vputs -i2 "\nerror: ${pp0}_@plot@ not found!\n"
        continue
    }
    load_file ${pp0}_@plot@ -name Data_$pp0
    set fRaw $SimArr(OutDir)/n@node@_${pp0}_raw.csv
    vputs -i2 "Save raw data to '$fRaw'"
    export_variables -dataset Data_$pp0 -overwrite -filename $fRaw

    # OptOnly section
    #================
    if {[lindex $pp 1] eq "RAT" && $OptOnly} {

        # Verify the current 'VarVary' step
        if {[lindex $VarVary $vIdx 0] ne "Wavelength"} {
            puts -i2 "\nerror: element '$vIdx' of 'VarVary' not 'Wavelength'!\n"
            continue
        }

        # Need to check the nearest mono varying step in 'VarVary'
        if {$ValArr(MonoScaling) == 0} {
            vputs -i2 "\nerror: no monochromatic intensity for RAT!\n"
            continue
        }
        if {$ValArr(SpecScaling) != 0} {
            vputs -i2 "\nerror: a spectrum is enabled for RAT!\n"
            continue
        }

        # Initialise parameters
        set capRAT "n@node@_$pp0: R A T curves"
        set fRAT $SimArr(OutDir)/n@node@_${pp0}_RAT.csv
        set fGopWS $SimArr(OutDir)/n@node@_${pp0}_1DGop_WS.plx
        set fGopARCWS $SimArr(OutDir)/n@node@_${pp0}_1DGop_ARC_WS.plx
        set fGopSpec $SimArr(OutDir)/n@node@_${pp0}_1DGop_Spectral.plx
        set fGopARCSpec $SimArr(OutDir)/n@node@_${pp0}_1DGop_ARC_Spectral.plx
        set fGopSum $SimArr(OutDir)/n@node@_${pp0}_1DGop_Summary.csv
        create_plot -name PltRAT_$pp0 -1d

        # Get monochromatic light intensity
        regexp {\{Monochromatic\s+\S+\s+([^\s\}]+)} $GopAttr -> val
        set pMono [expr $val*$ValArr(MonoScaling)]
        vputs -i2 "Monochromatic intensity: $pMono W*cm^-2"
        vputs -i2 "Create wavelength variable \[um -> nm\]"
        set xVar Wavelength|nm
        set xCap $xVar
        create_variable -name $xVar -dataset Data_$pp0\
            -function "<$wlPlt:Data_$pp0>*1e3"

        # Extract X axis and data trend (ascending or not)
        set xLst [get_variable_data -dataset Data_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr 1.*($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]
        create_curve -name ${pp0}_ww -dataset Data_$pp0\
            -axisX $xVar -axisY $xVar
        vputs -i2 "Calculate illuminated photons analytically"
        create_curve -name ${pp0}_A_Inc -function\
            "$pMono*$intArea/($h*$c0/(<${pp0}_ww>*1.e-9))"
        remove_curves ${pp0}_ww

        # Two columns from customSpec: Wavelength [nm] intensity [W*cm^-2]
        # Wavelengths in ascending order
        set specLst [list]
        if {[regexp {\{Spectrum\s+(\S+)} $GopAttr -> fSpec]} {
            vputs -i2 "Build custom spectrum from '$xLow' to '$xHigh' nm based\
                on spectrum file '$fSpec'"
            set specLst [customSpec $fSpec [expr 1e-3*$xLow]\
                [expr 1e-3*$xHigh] [expr 1e-3*$xStep]]
            set intJph 0
            foreach w [lindex $specLst 0] p [lindex $specLst 1] {
                set jph [expr 1e3*$q*$p/($h*$c0/$w*1e9)]
                set intJph [expr $intJph+$jph]
            }
            vputs -i3 "DOE: ${pp0}_Jph [format %.4f $intJph]"
            set gVarArr(${pp0}_Jph|mA*cm^-2) [format %.4f $intJph]
        }

        if {[regexp {\sRaytrace\s} $GopAttr]} {

            # Photon flux integration assumes 1 um in Z direction in 2D
            # Scale up y values so that z direction is also 1 cm
            vputs -i2 "Calculate illuminated photons numerically"
            create_curve -name ${pp0}_N_Inc -dataset Data_$pp0\
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
            create_curve -name ${pp0}_NR -dataset Data_$pp0\
                -axisX $xVar -axisY "RaytraceContactFlux\
                A(TOpt([lindex $RegGen 0 0 1]/OutDevice))"
            if {$Dim != 3 && !$Cylind} {
                create_curve -name ${pp0}_0|R -function\
                    "1e4*<${pp0}_NR>/<${pp0}_A_Inc>"
            } else {
                create_curve -name ${pp0}_0|R -function\
                    "1.*<${pp0}_NR>/<${pp0}_A_Inc>"
            }
            vputs -i2 "Calculate transmitted photons leaving at the back"
            create_curve -name ${pp0}_NT -dataset Data_$pp0\
                -axisX $xVar -axisY "RaytraceContactFlux\
                A(BOpt([lindex $RegGen end 0 1]/OutDevice))"
            if {$Dim != 3 && !$Cylind} {
                create_curve -name ${pp0}_1|T -function\
                    "1e4*<${pp0}_NT>/<${pp0}_A_Inc>"
            } else {
                create_curve -name ${pp0}_1|T -function\
                    "1.*<${pp0}_NT>/<${pp0}_A_Inc>"
            }
            remove_curves "${pp0}_NR ${pp0}_NT"

            vputs -i2 "Calculate absorbed photons (and FCA) in regions"
            foreach grp $RegGen {
                set mat [lindex $grp 0 0]
                set reg [lindex $grp 0 1]

                # Skip dummy regions
                if {$mat eq "Gas"} continue
                vputs -i3 -n "$reg: absorbed photons"
                create_curve -name ${pp0}_NA|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY "Integr$reg $monoAP"
                create_curve -name ${pp0}_3|A|$reg -function\
                    "1.*<${pp0}_NA|$reg>/<${pp0}_A_Inc>"
                remove_curves ${pp0}_NA|$reg
                if {[lindex $grp 0 2] eq "Semiconductor"} {
                    vputs -c -n ", electron-hole pairs"
                    create_curve -name ${pp0}_NOG|$reg\
                        -dataset Data_$pp0\
                        -axisX $xVar -axisY "Integr$reg $monoOG"
                    create_curve -name ${pp0}_4|OG|$reg -function\
                        "1.*<${pp0}_NOG|$reg>/<${pp0}_A_Inc>"
                    remove_curves ${pp0}_NOG|$reg

                    # Skip FCA if the max value is 0
                    create_curve -name ${pp0}_5|FCA|$reg -function\
                        "<${pp0}_3|A|$reg>-<${pp0}_4|OG|$reg>"
                    set lst [get_curve_data ${pp0}_5|FCA|$reg -axisY\
                        -plot PltRAT_$pp0]
                    if {[lindex [lsort -real -decreasing $lst] 0] > 1e-10} {
                        vputs -c -n ", FCA"
                    } else {
                        remove_curves ${pp0}_5|FCA|$reg
                    }
                }
                vputs
            }

            array unset arr
            if {[regexp {\sARC\s} $GopAttr]} {
                vputs -i2 "Calculating absorbed photons in the ARC layers"
                foreach grp $GopAttr {

                    # Skip non-ARC groups
                    if {[lindex $grp 1] ne "ARC"} continue
                    set lst [string map {r "" / " "} [lindex $grp 0]]
                    set intf [lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
                        $RegGen [lindex $lst 1] 0 1]
                    set idx 0
                    while {$idx < [expr ([llength $grp]-2.)/3]} {
                        set lst [lrange $grp [expr $idx*3+2] [expr $idx*3+3]]
                        set str [lindex $grp 0]|[lindex $lst 0]
                        lappend arr(ARCMat) [lindex $lst 0]
                        lappend arr(ARCThx|um) [lindex $lst 1]
                        lappend arr(ARCCurve) ${pp0}_6|$str
                        vputs -i3 "RaytraceInterfaceTMMLayerFlux\
                            A($intf).layer$idx"
                        create_curve -name ${pp0}_N_$str -dataset Data_$pp0\
                            -axisX $xVar -axisY "RaytraceInterfaceTMMLayerFlux\
                            A($intf).layer$idx"
                        if {$Dim != 3 && !$Cylind} {
                            create_curve -name ${pp0}_6|$str -function\
                                "1e4*<${pp0}_N_$str>/<${pp0}_A_Inc>"
                        } else {
                            create_curve -name ${pp0}_6|$str -function\
                                "1.*<${pp0}_N_$str>/<${pp0}_A_Inc>"
                        }
                        remove_curves ${pp0}_N_$str
                        incr idx
                    }
                }
            }

            # Create the fraction of shading if exists
            regexp {\{Incidence\s+(\S+)} $GopAttr -> fShd
            if {$fShd > 0} {
                create_curve -name ${pp0}_7|Shading -function\
                    "$fShd*<${pp0}_A_Inc>/<${pp0}_A_Inc>"
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

        } elseif {[regexp {\sTMM\s} $GopAttr]} {

            set idx 0
            foreach grp $GopAttr {
                if {[lindex $grp 1] ne "TMM"} continue
                vputs -i2 "TMM W$idx:"
                create_curve -name ${pp0}_0_w$idx|R -dataset Data_$pp0\
                    -axisX $xVar -axisY "LayerStack(W$idx) R_Total"
                create_curve -name ${pp0}_3_w$idx|A -dataset Data_$pp0\
                    -axisX $xVar -axisY "LayerStack(W$idx) A_Total"
                create_curve -name ${pp0}_1_w$idx|T -dataset Data_$pp0\
                    -axisX $xVar -axisY "LayerStack(W$idx) T_Total"
                create_curve -name ${pp0}_2_w$idx|RAT -function\
                    "<${pp0}_0_w$idx|R>+<${pp0}_3_w$idx|A>+<${pp0}_1_w$idx|T>"
                if {[llength $specLst] == 0} {
                    incr idx
                    continue
                }
                set intJR 0
                set intJA 0
                set intJT 0
                foreach w [lindex $specLst 0] p [lindex $specLst 1] {
                    set jph [expr 1e3*$q*$p/($h*$c0/$w*1e9)]
                    set r [lindex [probe_curve ${pp0}_0_w$idx|R -valueX $w\
                        -plot PltRAT_$pp0] 0]
                    set t [lindex [probe_curve ${pp0}_1_w$idx|T -valueX $w\
                        -plot PltRAT_$pp0] 0]
                    set a [lindex [probe_curve ${pp0}_3_w$idx|A -valueX $w\
                        -plot PltRAT_$pp0] 0]
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

            vputs -i2 "Calculate absorbed photons (and FCA) in regions"
            foreach grp $RegGen {
                set mat [lindex $grp 0 0]
                set reg [lindex $grp 0 1]

                # Skip dummy regions
                if {$mat eq "Gas"} continue
                vputs -i3 -n "$reg: absorbed photons"
                create_curve -name ${pp0}_NA|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY "Integr$reg $monoAP"
                create_curve -name ${pp0}_3|A|$reg -function\
                    "1.*<${pp0}_NA|$reg>/<${pp0}_A_Inc>"
                remove_curves ${pp0}_NA|$reg
                if {[lindex $grp 0 2] eq "Semiconductor"} {
                    vputs -c -n ", electron-hole pairs"
                    create_curve -name ${pp0}_NOG|$reg\
                        -dataset Data_$pp0\
                        -axisX $xVar -axisY "Integr$reg $monoOG"
                    create_curve -name ${pp0}_4|OG|$reg -function\
                        "1.*<${pp0}_NOG|$reg>/<${pp0}_A_Inc>"
                    remove_curves ${pp0}_NOG|$reg

                    # Skip FCA if the max value is 0
                    create_curve -name ${pp0}_5|FCA|$reg -function\
                        "<${pp0}_3|A|$reg>-<${pp0}_4|OG|$reg>"
                    set lst [get_curve_data ${pp0}_5|FCA|$reg -axisY\
                        -plot PltRAT_$pp0]
                    if {[lindex [lsort -real -decreasing $lst] 0] > 1e-10} {
                        vputs -c -n ", FCA"
                    } else {
                        remove_curves ${pp0}_5|FCA|$reg
                    }
                }
                vputs
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
                    create_curve -name ${pp0}_NA|$reg -dataset Data_$pp0\
                        -axisX $xVar -axisY "Integr$reg $monoAP"
                    create_curve -name ${pp0}_3|A|$reg -function\
                        "1.*<${pp0}_NA|$reg>/<${pp0}_A_Inc>"
                    remove_curves ${pp0}_NA|$reg
                    if {[lindex $grp 0 2] eq "Semiconductor"} {
                        vputs -c -n ", electron-hole pairs"
                        create_curve -name ${pp0}_NOG|$reg\
                            -dataset Data_$pp0\
                            -axisX $xVar -axisY "Integr$reg $monoOG"
                        create_curve -name ${pp0}_4|OG|$reg -function\
                            "1.*<${pp0}_NOG|$reg>/<${pp0}_A_Inc>"
                        remove_curves ${pp0}_NOG|$reg

                        # Skip FCA in nonsilicon and nonpolysi regions
                        if {$mat eq "Silicon" || $mat eq "PolySi"} {
                            vputs -c -n ", FCA"
                            create_curve -name ${pp0}_5|FCA|$reg -function\
                                "<${pp0}_3|A|$reg>-<${pp0}_4|OG|$reg>"
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

        if {[regexp {\sRaytrace\s} $GopAttr]} {

            # Check each ARC material for its material group and retain
            # the first semiconductor layer onwards
            if {[info exists arr(ARCMat)]} {
                set MatDB [readMatDB datexcodes.txt $iseroot_lib/datexcodes.txt]
                set len [llength $arr(ARCMat)]
                for {set i 0} {$i < $len} {incr i} {
                    set idx [lsearch -regexp [lindex $MatDB 0]\
                        ^[lindex $arr(ARCMat) $i]$]
                    if {[lindex $MatDB 1 $idx] eq "Semiconductor"} {
                        break
                    }
                }
                set arr(ARCMat) [lrange $arr(ARCMat) $i end]
                set arr(ARCThx|um) [lrange $arr(ARCThx|um) $i end]
                set arr(ARCCurve) [lrange $arr(ARCCurve) $i end]
            }

            # Extract depth and wavelength dependent photon absorbance profile
            if {![file exists n@previous@_OG1D.plx]} {
                vputs -i3 "\nerror: n@previous@_OG1D.plx not found!\n"
                continue
            }
            set idx 0
            set ogLst [list]
            set inf [open n@previous@_OG1D.plx r]
            vputs -i3 "Read n@previous@_OG1D.plx"
            while {[gets $inf line] != -1} {
                if {[string is double -strict [lindex $line 0]]} {
                    if {$idx == 0} {
                        lappend arr(Dep|um) [lindex $line 0]
                    }
                    lappend ogLst [lindex $line end]
                } elseif {[regexp {^# End of wavelength varying} $line]} {
                    if {$xAsc} {
                        lappend arr(Lambda|nm) [format %g\
                            [expr $xLow+$xStep*$idx]]
                    } else {
                        lappend arr(Lambda|nm) [format %g\
                            [expr $xHigh-$xStep*$idx]]
                    }
                    vputs -i4 "[lindex $arr(Lambda|nm) end] nm"
                    set arr([lindex $arr(Lambda|nm) end]) $ogLst
                    set ogLst [list]
                    incr idx
                }
            }
            close $inf

            # Sort wavelengths ascendingly
            set arr(Lambda|nm) [lsort -real $arr(Lambda|nm)]

            vputs -i2 "Save spectral 1D optical generation rate\
                to '$fGopSpec' ascendingly"

            # Summarise Jmono and JOG for each wavelength
            # ogLst: depth, Gop, cumulative JOG, ROG
            set capLst Summary
            set sumLst Sum
            set ogLst [list]
            set len [llength $arr(Dep|um)]
            set ouf [open $fGopSpec w]
            puts $ouf "# Spectral 1D optical generation rate at $pMono|W*cm^-2"
            puts $ouf "# Depth|um, AbsorbedPhotonDensity|cm^-3*s^-1"
            foreach w $arr(Lambda|nm) {
                puts $ouf "\n\"g([expr 1e-3*$w])\""
                puts $ouf "Wavelength = [expr 1e-3*$w] \[um\]\
                    Intensity = $pMono \[W*cm^-2\]"
                set lst [list]
                foreach dep $arr(Dep|um) og $arr($w) {
                    puts $ouf [format %.4e\t%.4e $dep $og]
                    lappend lst [list $dep $og]
                }

                # Append cumulative JOG [mA/cm2] with absorbance depth
                lset lst 0 [concat [lindex $lst 0] 0]
                for {set i 1} {$i < $len} {incr i} {
                    set sum [lindex $lst [expr $i-1] end]
                    set sum [expr $sum+([lindex $lst [expr $i-1] end-1]\
                        +[lindex $lst $i end])*([lindex $lst $i 0]\
                        -[lindex $lst [expr $i-1] 0])/2e1*$q]
                    lset lst $i [concat [lindex $lst $i] $sum]
                }

                # Calculate incident photon density Jmono [mA/cm2]
                set val [expr 1e3*$q*$pMono/($h*$c0/(1e-9*$w))]
                append capLst " Wavelength|nm Jmono|mA*cm^-2 JOG|mA*cm^-2"
                append sumLst " $w $val $sum"

                # Append ROG with absorbance depth
                if {[llength $ogLst]} {
                    set newLst [list]
                    foreach elm $lst grp $ogLst {
                        set rog [expr 1e2*[lindex $elm end]/$sum]
                        lappend newLst [concat $grp [lrange $elm 1 end] $rog]
                    }
                    set ogLst $newLst
                } else {
                    foreach elm $lst {
                        set rog [expr 1e2*[lindex $elm end]/$sum]
                        lappend ogLst [concat $elm $rog]
                    }
                }
            }
            close $ouf

            if {[info exists arr(ARCMat)] && [llength $arr(ARCMat)]} {
                vputs -i2 "Save spectral 1D optical generation rate with ARC\
                    to '$fGopARCSpec' ascendingly"
                set ouf [open $fGopARCSpec w]
                puts $ouf "# Spectral 1D optical generation rate with ARC at\
                    $pMono|W*cm^-2"
                puts $ouf "# Depth|um, AbsorbedPhotonDensity|cm^-3*s^-1"
                foreach w $arr(Lambda|nm) {
                    puts $ouf "\n\"g([expr 1e-3*$w])\""
                    puts $ouf "Wavelength = [expr 1e-3*$w] \[um\]\
                        Intensity = $pMono \[W*cm^-2\]"

                    # Calculate incident photon flux [cm^-2s^-1]
                    set val [expr 1e-9*$pMono*$w/$h/$c0]
                    set thx 0
                    set lst [list]
                    foreach elm $arr(ARCThx|um) str $arr(ARCCurve) {
                        set arc [lindex [probe_curve $str -valueX $w\
                            -plot PltRAT_$pp0] 0]
                        set og [expr 1e4*$val*$arc/$elm]
                        lappend lst $og
                        puts $ouf [format %.4e\t%.4e $thx $og]
                        set thx [expr $thx+$elm/2.]
                        puts $ouf [format %.4e\t%.4e $thx $og]
                        set thx [expr $thx+$elm/2.]
                        puts $ouf [format %.4e\t%.4e $thx $og]
                    }
                    lappend arr(ARCOG|cm^-3*s^-1) $lst
                    foreach dep $arr(Dep|um) og $arr($w) {
                        puts $ouf [format %.4e\t%.4e [expr $dep+$thx] $og]
                    }
                }
                close $ouf
            }

            # Two columns from customSpec: Wavelength [nm] intensity [W*cm^-2]
            if {[llength $specLst]} {
                vputs -i2 "Calculate weighted average reflectance, absorptance,\
                    optical generation from '$xLow' to '$xHigh' nm"
                foreach curve [list_curves -plot PltRAT_$pp0] {
                    if {![regexp {^v\d+_\d\|(R|A.*|OG.+|r.+)$} $curve -> str]} {
                        continue
                    }

                    # 'swb' can't display a variable name with '|' and '/'
                    set str [string map {| _ / _} $str]
                    set sum 0
                    foreach w [lindex $specLst 0] p [lindex $specLst 1] {
                        set val [lindex [probe_curve $curve -valueX $w\
                            -plot PltRAT_$pp0] 0]
                        set sum [expr $sum+$val*1e3*$q*$p/($h*$c0/$w*1e9)]
                    }
                    vputs -i3 "DOE: ${pp0}_J$str [format %.4f $sum]"
                    set gVarArr(${pp0}_J$str) [format %.4f $sum]
                }

                # Calculate 1D weighted sum of the absorptance profile
                vputs -i2 "Calculate 1D weighted sum of optical generation rate"

                # Calculate weighted sum of photons for each depth
                if {[llength $arr(Lambda|nm)]
                    != [llength [lindex $specLst 1]]} {
                    vputs -i2 "\nerror: $len records !=\
                        [llength [lindex $specLst 1]] wavelengths!\n"
                    continue
                }
                set idx 0
                foreach dep $arr(Dep|um) {
                    set sum 0
                    foreach w $arr(Lambda|nm) p [lindex $specLst 1] {
                        set sum [expr $sum+[lindex $arr($w) $idx]*$p/$pMono]
                    }
                    lappend arr(WSOG|cm^-3*s^-1) $sum
                    incr idx
                }
                vputs -i2 "Save 1D weighted sum of optical generation rate\
                    to '$fGopWS'"
                set ouf [open $fGopWS w]
                puts $ouf "# 1D weighted sum of optical generation rate from\
                    '$xLow' to '$xHigh' nm with a step\n# size of '[expr\
                    abs($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]' nm using\
                    spectrum '$fSpec'"
                puts $ouf "# Depth|um, AbsorbedPhotonDensity|cm^-3*s^-1"
                puts $ouf {"AbsorbedPhotonDensity"}
                set lst [list]
                set len [llength $arr(Dep|um)]
                foreach dep $arr(Dep|um) og $arr(WSOG|cm^-3*s^-1) {
                    puts $ouf [format %.4e\t%.4e $dep $og]
                    lappend lst [concat $dep $og]
                }
                close $ouf

                # Append cumulative JOG [mA/cm2] with absorbance depth
                lset lst 0 [concat [lindex $lst 0] 0]
                for {set i 1} {$i < $len} {incr i} {
                    set sum [lindex $lst [expr $i-1] end]
                    set sum [expr $sum+([lindex $lst [expr $i-1] end-1]\
                        +[lindex $lst $i end])*([lindex $lst $i 0]\
                        -[lindex $lst [expr $i-1] 0])/2e1*$q]
                    lset lst $i [concat [lindex $lst $i] $sum]
                }
                set capLst [concat [lindex $capLst 0] WeightedSum Jph|mA*cm^-2\
                    JOG|mA*cm^-2 [lrange $capLst 1 end]]
                set sumLst [concat [lindex $sumLst 0] WSOG $intJph $sum\
                    [lrange $sumLst 1 end]]

                # Append ROG with absorbance depth
                set newLst [list]
                foreach elm $lst grp $ogLst {
                    set rog [expr 1e2*[lindex $elm end]/$sum]
                    lappend newLst [concat $elm $rog [lrange $grp 1 end]]
                }
                set ogLst $newLst
            }

            if {[info exists arr(ARCMat)] && [llength $arr(ARCMat)]} {
                vputs -i2 "Save 1D weighted sum of optical generation rate\
                    with ARC to '$fGopARCWS'"
                set ouf [open $fGopARCWS w]
                puts $ouf "# 1D weighted sum of optical generation rate with\
                    ARC from '$xLow' to '$xHigh' nm with\n# a stepsize of\
                    '[expr abs($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]' nm\
                    using spectrum '$fSpec'"
                puts $ouf "# Depth|um, AbsorbedPhotonDensity|cm^-3*s^-1"
                puts $ouf {"AbsorbedPhotonDensity"}
                set thx 0
                set idx 0
                foreach elm $arr(ARCThx|um) {

                    # Calculate weighted sum of absorbed photons in ARC
                    set sum 0
                    foreach og $arr(ARCOG|cm^-3*s^-1) p [lindex $specLst 1] {
                        set sum [expr $sum+[lindex $og $idx]*$p/$pMono]
                    }
                    puts $ouf [format %.4e\t%.4e $thx $sum]
                    set thx [expr $thx+$elm/2.]
                    puts $ouf [format %.4e\t%.4e $thx $sum]
                    set thx [expr $thx+$elm/2.]
                    puts $ouf [format %.4e\t%.4e $thx $sum]
                    incr idx
                }

                foreach dep $arr(Dep|um) og $arr(WSOG|cm^-3*s^-1) {
                    puts $ouf [format %.4e\t%.4e [expr $dep+$thx] $og]
                }
                close $ouf
            }

            # Save 1DGop summary
            set ouf [open $fGopSum w]
            puts $ouf [join $capLst ,]
            puts $ouf [join $sumLst ,]\n
            set len [expr int([llength $sumLst]/3)]
            set str Depth|um
            for {set i 0} {$i < $len} {incr i} {
                append str ",Gop|cm^-3*s^-1,JOG|mA*cm^-2*s^-1,ROG|%"
            }
            puts $ouf $str
            foreach lst $ogLst {
                set str [format %.4e [lindex $lst 0]]
                foreach elm [lrange $lst 1 end] {
                    append str ,[format %.4e $elm]
                }
                puts $ouf $str
            }
            close $ouf
        }

        # No further postprocessing
        continue
    }

    # Other than OptOnly simulations
    #===============================
    if {[lindex $pp 1] eq "JV" || [lindex $pp 1] eq "CV"} {

        # Verify the current 'VarVary' step
        set bCon [lindex $VarVary $vIdx 0]
        if {![regexp {^c\d$} $bCon] || [lindex $ValArr($bCon) 0] ne "Voltage"} {
            vputs -i2 "\nerror: element '$vIdx' of 'VarVary' not a voltage\
                contact!\n"
            continue
        }

        # Initialise parameters
        set capJV "n@node@_${pp0}: J-V at $T K"
        set fJV $SimArr(OutDir)/n@node@_${pp0}_JV.csv

        # Extract X axis and data trend (ascending or not)
        set xVar "$bCon OuterVoltage"
        set xCap $bCon|V
        set xLst [get_variable_data -dataset Data_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr 1.*($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]

        create_plot -name PltJV_$pp0 -1d
        create_curve -name ${pp0}_IV -dataset Data_$pp0\
            -axisX $xVar -axisY "$bCon TotalCurrent"
        create_curve -name ${pp0}_VV -dataset Data_$pp0\
            -axisX $xVar -axisY $xVar
        create_curve -name ${pp0}_JV -function "1e3*<${pp0}_IV>/$jArea"
        create_curve -name ${pp0}_P -function "<${pp0}_JV>*<${pp0}_VV>"
        remove_curves "${pp0}_IV ${pp0}_VV"

        # Extract maximum current density
        set jLst [get_curve_data ${pp0}_JV -axisY -plot PltJV_$pp0]
        set pLst [get_curve_data ${pp0}_P -axisY -plot PltJV_$pp0]
        set maxJ [lindex [lsort -real $jLst] end]
        vputs -i2 [format "Max current density: %.4g mA*cm^-2" $maxJ]
        if {$xLow <= 0 && $xHigh >= 0} {
            set jsc [lindex [probe_curve ${pp0}_JV -valueX 0\
                -plot PltJV_$pp0] 0]
        } else {
            set jsc [lindex [lsort -real $jLst] 0]
        }

        # Check monochromatic and spectrum scaling for light JV
        if {$ValArr(SpecScaling) > 0 || $ValArr(MonoScaling) > 0} {

            # Calculate photogeneration current density
            set jog [expr 1e3*$q*[lindex [get_variable_data -dataset\
                Data_$pp0 "IntegrSemiconductor $ogPlt"] end]/$intArea]
            vputs -i2 [format "Photogeneration current density:\
                %.4g mA*cm^-2" $jog]
            set tmp [format %.4g $jog]
            vputs -i2 "DOE: ${pp0}_Jog $tmp"
            set gVarArr(${pp0}_Jog|mA*cm^-2) $tmp

            # Check the previous mono/spectrum scaling from 'VarVary'
            set pSum 0
            if {$ValArr(SpecScaling) > 0
                && [regexp {\{Spectrum\s+(\S+)} $GopAttr -> str]} {

                # Extract the spectrum power [mW*cm^-2]
                set pSpec [expr [specInt $str]*$ValArr(SpecScaling)]
                set tmp [format %.4g $pSpec]
                vputs -i2 "DOE: ${pp0}_Pspec $tmp"
                set gVarArr(${pp0}_Pspec|mW*cm^-2) $tmp
                set pSum [expr $pSum+$pSpec]
            }
            if {$ValArr(MonoScaling) > 0 && [regexp\
                {\{Monochromatic\s+\S+\s+([^\s\}]+)} $GopAttr -> tmp]} {
                set pMono [expr 1e3*$tmp*$ValArr(MonoScaling)]
                set tmp [format %.4g $pMono]
                vputs -i2 "DOE: ${pp0}_Pmono $tmp"
                set gVarArr(${pp0}_Pmono|mW*cm^-2) $tmp
                set pSum [expr $pSum+$pMono]
            }
            set tmp [format %.4g $pSum]
            vputs -i2 "DOE: ${pp0}_Psum $tmp"
            set gVarArr(${pp0}_Psum|mW*cm^-2) $tmp

            # Extract Jsc, Voc, Eff and FF for forward bias only
            if {$jsc < 0} {
                set tmp [format %.4g [expr abs($jsc)]]
                vputs -i2 [format "Short circuit current density:\
                    %.4g mA*cm^-2" $tmp]
                vputs -i2 "DOE: ${pp0}_Jsc $tmp"
                set gVarArr(${pp0}_Jsc|mA*cm^-2) $tmp
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
                if {$pSum > 0} {
                    set tmp [format %.4g [expr 1e2*abs($pmpp)/$pSum]]
                    vputs -i2 "DOE: ${pp0}_Eff $tmp"
                    set gVarArr(${pp0}_Eff|%) $tmp
                } else {
                    vputs -i2 "no spectrum specified!"
                }
                set tmp [format %.4g $vmpp]
                vputs -i2 "DOE: ${pp0}_Vmpp $tmp"
                set gVarArr(${pp0}_Vmpp|V) $tmp
                if {$maxJ > 0} {
                    set voc [lindex [probe_curve ${pp0}_JV -valueY 0\
                        -plot PltJV_$pp0] 0]
                    set foundVoc true
                    set tmp [format %.5g $voc]
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
            } else {
                vputs -i2 "\nerror: '$bCon' not a hole contact!\n"
                continue
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

        if {[lindex $pp 1] eq "CV"} {
            set fCV $SimArr(OutDir)/n@node@_${pp0}_CV.csv
            load_file ${pp0}_@acplot@ -name ACData_$pp0
            vputs -i2 "\nExtract capaitance and admittance vs. voltage"
            set fLst [get_variable_data -dataset ACData_$pp0 "frequency"]
            set fLst [lsort -unique $fLst]
            vputs -n -i3 Frequency:
            set line V|V
            foreach elm $fLst {
                lappend line C_[format %.2E $elm]|C
                lappend line A_[format %.2E $elm]|S
                vputs -n -c [format " %.2E" $elm]
            }
            set vLst [get_variable_data -dataset ACData_$pp0 "v(N_$bCon)"]
            set aLst [get_variable_data -dataset ACData_$pp0\
                "a(N_$bCon,N_$bCon)"]
            set cLst [get_variable_data -dataset ACData_$pp0\
                "c(N_$bCon,N_$bCon)"]

            # Save voltage, capaitance, admittance
            vputs -i2 "\nSave capaitance and admittance vs. voltage"
            set ouf [open $fCV.[pid] w]
            puts $ouf [join $line ,]
            set idx 0
            set len [llength $vLst]
            set fLen [llength $fLst]
            set line [list]
            while {$idx < $len} {
                if {$idx%$fLen == 0} {
                    if {[llength $line]} {
                        puts $ouf [join $line ,]
                    }
                    set line [list [lindex $vLst $idx] [lindex $cLst $idx]\
                        [lindex $aLst $idx]]
                } else {
                    lappend line [lindex $cLst $idx]
                    lappend line [lindex $aLst $idx]
                }
                incr idx
            }
            if {[llength $line]} {
                puts $ouf [join $line ,]
            }
            close $ouf
            file rename -force $fCV.[pid] $fCV
        }

    } elseif {[lindex $pp 1] eq "QE"} {

        # Find a voltage hole contact from 'ValArr'
        set bCon ""
        foreach elm [array names ValArr] {
            if {[regexp {^c\d$} $elm]
                && [lindex $ValArr($elm) 0] eq "Voltage"} {
                set lst [get_variable_data -dataset Data_$pp0\
                    "$elm TotalCurrent"]

                # Current is negative on the hole contact
                if {[lindex $lst 0] < 0} {
                    set bCon $elm
                    break
                }
            }
        }
        if {$bCon eq ""} {
            vputs -i2 "\nerror: no voltage contact for QE!\n"
            continue
        } else {
            vputs -i2 "Found a voltage hole contact '$bCon'!"
            vputs -i2 "Bias voltage at '$bCon': [lindex $ValArr($bCon) 1] V"
        }

        # Verify the current 'VarVary' step
        if {[lindex $VarVary $vIdx 0] eq "Wavelength"} {

            # Need to check the previous monoScaling step
            set val 0
            for {set idx [expr $vIdx-1]} {$idx >= 0} {incr idx -1} {
                if {[lindex $VarVary $idx 0] eq "MonoScaling"} {
                    set val [lindex $VarVary $idx 1]
                    break
                }
            }
            if {$val == 0} {
                vputs -i2 "\nerror: no monochromatic intensity for QE!\n"
                continue
            }

            # Make sure initial monochromatic light intensity (index 0) is 0
            load_file v${idx}_@plot@ -name BiasData_$pp0
            set lst [get_variable_data -dataset BiasData_$pp0\
                "IntegrSemiconductor $monoOG"]
            if {[lindex $lst 0] > 0} {
                vputs -i2 "\nerror: 'v$idx' nonzero initial mono intensity!\n"
                continue
            }

            # Extract jOGBias and jBias at index 0
            set lst [get_variable_data -dataset BiasData_$pp0\
                "IntegrSemiconductor $ogPlt"]
            set jOGBias [expr 1e3*$q*[lindex $lst 0]/$intArea]
            set lst [get_variable_data -dataset BiasData_$pp0\
                "$bCon TotalCurrent"]
            set jBias [expr 1e3*[lindex $lst 0]/$jArea]
            vputs -i2 [format "Extracted Jsc/JOG at bias light:\
                %.4g/%.4g mA*cm^-2" $jBias $jOGBias]
            unload_file v${idx}_@plot@

            regexp {\{Monochromatic\s+\S+\s+([^\s\}]+)} $GopAttr -> val
            set pMono [expr $val*$ValArr(MonoScaling)]
            vputs -i2 "Monochromatic signal light intensity: $pMono W*cm^-2"
        } else {
            vputs -i2 "\nerror: element '$vIdx' of 'VarVary' not wavelength!\n"
            continue
        }

        # Initialise parameters
        set capQE "n@node@_${pp0}: QE at $T K"
        set fQE $SimArr(OutDir)/n@node@_${pp0}_QE.csv
        create_plot -name PltQE_$pp0 -1d
        select_plots PltQE_$pp0
        vputs -i2 "Create wavelength variable \[um -> nm\]"
        set xVar Wavelength|nm
        set xCap $xVar
        create_variable -name $xVar -dataset Data_$pp0\
            -function "<$wlPlt:Data_$pp0>*1e3"

        # Extract X axis and data trend (ascending or not)
        set xLst [get_variable_data -dataset Data_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr 1.*($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]

        vputs -i2 "Creating differential current density curve"
        create_curve -name ${pp0}_ww -dataset Data_$pp0\
            -axisX $xVar -axisY $xVar
        create_curve -name ${pp0}_jBias -function "$jBias+<${pp0}_ww>*0"

        # X in nm, Y in mA*cm^-2
        create_curve -name ${pp0}_jSum -dataset Data_$pp0\
            -axisX $xVar -axisY "$bCon TotalCurrent"
        create_curve -name ${pp0}_jSig -function\
            "<${pp0}_jBias>-1e3*<${pp0}_jSum>/$jArea"

        # X in nm, Y in mA*cm^-2 (J*s^-1*cm^2/(J*s*m/s/m) )
        vputs -i2 "Calculating signal photon current..."
        create_curve -name ${pp0}_jphSig\
            -function "1e3*$q*$pMono/($h*$c0/(1e-9*<${pp0}_ww>))"
        vputs -i2 "Creating differential optical generation from\
            signal only..."
        create_curve -name ${pp0}_NogSig -dataset Data_$pp0\
            -axisX $xVar -axisY "IntegrSemiconductor $monoOG"
        create_curve -name ${pp0}_jogSig -function\
            "1e3*$q*<${pp0}_NogSig>/$intArea"
        vputs -i2 "Creating quantum efficiency curves..."
        create_curve -name ${pp0}_dEQE -function\
            "1e2*<${pp0}_jSig>/<${pp0}_jphSig>"
        create_curve -name ${pp0}_dIQE -function\
            "1e2*<${pp0}_jSig>/<${pp0}_jogSig>"
        remove_curves "${pp0}_ww ${pp0}_jBias\
            ${pp0}_jSum ${pp0}_NogSig"

        # Two columns from customSpec: Wavelength [nm] intensity [W*cm^-2]
        set specLst [list]
        if {[regexp {\{Spectrum\s+(\S+)} $GopAttr -> fSpec]} {
            vputs -i2 "Build custom spectrum from '$xLow' to '$xHigh' nm based\
                on spectrum file '$fSpec'"
            set specLst [customSpec $fSpec [expr 1e-3*$xLow]\
                [expr 1e-3*$xHigh] [expr 1e-3*$xStep]]
            set intJph 0
            set intJQE 0
            foreach w [lindex $specLst 0] p [lindex $specLst 1] {
                set jph [expr 1e3*$q*$p/($h*$c0/$w*1e9)]
                set intJph [expr $intJph+$jph]
                set intJQE [expr $intJQE+$p/$pMono*[lindex [probe_curve\
                    ${pp0}_jSig -valueX $w -plot PltQE_$pp0] 0]]
            }
            vputs -i3 "DOE: ${pp0}_Jph [format %.4f $intJph]"
            set gVarArr(${pp0}_Jph|mA*cm^-2) [format %.4f $intJph]
            vputs -i3 "DOE: ${pp0}_JQE [format %.4f $intJQE]"
            set gVarArr(${pp0}_JQE|mA*cm^-2) [format %.4f $intJQE]
        }

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
            if {[regexp {^d} $str]} {
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

        # Verify the current 'VarVary' step
        if {[lindex $VarVary $vIdx 0] ne "SpecScaling"
            && [lindex $VarVary $vIdx 0] ne "MonoScaling"} {
            vputs -i2 "error: element '$vIdx' of 'VarVary' not 'SpecScaling'\
                and 'MonoScaling'!"
            continue
        }

        # Use the first Dn from position or average as the X axis
        if {[regexp { Dn} $VV2Fld]} {
            vputs -i2 "Create Delta n variable \[cm^-3\]"
        } else {
            vputs -i2 "error: no 'Dn' in 'GetFld'!"
            continue
        }

        # Initialise parameters
        set captau "n@node@_${pp0}: lifetime at $T K"
        set ftau $SimArr(OutDir)/n@node@_${pp0}_lifetime.csv
        set capiVoc "n@node@_${pp0}: iVoc at $T K"
        set fiVoc $SimArr(OutDir)/n@node@_${pp0}_iVoc.csv
        set jVar JOG|mA*cm^-2
        set jCap $jVar
        set capJ0 "n@node@_${pp0}: J0 at $T K"
        set fJ0 $SimArr(OutDir)/n@node@_${pp0}_J0.csv
        set var [format %g [expr $YMax/2.]]
        set dnLst [list]

        # Load equilibrium data to extract n0, p0, and ni0
        load_file eqm_@plot@ -name EqmData_$pp0
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
                set n0 [lindex [get_variable_data -dataset EqmData_$pp0\
                    "$txt eDensity"] 0]
                set p0 [lindex [get_variable_data -dataset EqmData_$pp0\
                    "$txt hDensity"] 0]
                set ni0 [lindex [get_variable_data -dataset EqmData_$pp0\
                    "$txt EffectiveIntrinsicDensity"] 0]
                vputs -i4 [format "n0= %.4E p0= %.4E ni0= %.4E" $n0 $p0 $ni0]
                if {$n0 >= $p0} {

                    # n-type substrate
                    create_variable -name Dn|[lindex $grp 0]|cm^-3 -dataset\
                        Data_$pp0 -function "<$txt hDensity:Data_$pp0>-$p0"
                } else {

                    # p-type substrate
                    create_variable -name Dn|[lindex $grp 0]|cm^-3 -dataset\
                        Data_$pp0 -function "<$txt eDensity:Data_$pp0>-$n0"
                }

                # Create the normalised pn for the first Dn: (pn/ni/ni - 1)
                if {[llength $dnLst] == 0} {
                    set xVar Dn|[lindex $grp 0]|cm^-3
                    set DnPlt $txt
                    set xCap $xVar
                    create_variable -name "$txt Normd_pn" -dataset Data_$pp0\
                        -function "(<$txt hDensity:Data_$pp0>\
                        *<$txt eDensity:Data_$pp0>\
                        /<$txt EffectiveIntrinsicDensity:Data_$pp0>\
                        /<$txt EffectiveIntrinsicDensity:Data_$pp0>-1.)"
                }
                lappend dnLst Dn|[lindex $grp 0]
            }
        }

        # Extract X axis and data trend (ascending or not)
        set xLst [get_variable_data -dataset Data_$pp0 $xVar]
        if {[lindex $xLst 0] < [lindex $xLst end]} {
            set xAsc true
            set xLow [lindex $xLst 0]
            set xHigh [lindex $xLst end]
        } else {
            set xAsc false
            set xLow [lindex $xLst end]
            set xHigh [lindex $xLst 0]
        }
        set xStep [expr 1.*($xHigh-$xLow)/[lindex $VarVary $vIdx 2]]

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

        create_plot -name PltiVoc_$pp0 -1d
        windows_style -style max
        set_plot_prop -show_grid -show_curve_markers\
            -title_font_size 28 -title $capiVoc
        set_grid_prop -show_minor_lines -line1_style dash\
            -line1_color gray -line2_style dot -line2_color lightGray
        set_axis_prop -axis x -title_font_size 20 -type log\
            -scale_font_size 16 -scale_format preferred\
            -title $jCap
        set_axis_prop -axis y -title_font_size 20 -type linear\
            -scale_font_size 16 -scale_format preferred\
            -title {iVoc|V}
        set_axis_prop -axis y2 -title_font_size 20 -type log\
            -scale_font_size 16 -scale_format preferred\
            -title {Carrier density|cm^-3}
        set_legend_prop -location top_left

        create_plot -name PltJ0_$pp0 -1d
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

        # Extract volume of all semiconductors [cm^3]
        set val [get_variable_data -dataset Data_$pp0\
            "IntegrSemiconductor $ogPlt"]
        if {[lindex $val 0] == 0} {
            set vol [expr 1.*[lindex $val end]/[lindex [get_variable_data\
                -dataset Data_$pp0 "AveSemiconductor $ogPlt"] end]]
        } else {
            set vol [expr 1.*[lindex $val 0]/[lindex [get_variable_data\
                -dataset Data_$pp0 "AveSemiconductor $ogPlt"] 0]]
        }
        vputs -i3 "Total semiconductor region volume: $vol cm^3"

        if {[llength $dnLst] > 1} {
            vputs -i2 "Plot the rest excess carrier density curves"
            foreach elm [lrange $dnLst 1 end] {
                vputs -i3 $elm
                create_curve -name ${pp0}_9|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY2 $elm|cm^-3 -plot Plttau_$pp0
            }
        }

        # Extract scaling factor
        vputs -i2 "Plot the [lindex $VarVary $vIdx 0] curve"
        create_variable -name [lindex $VarVary $vIdx 0] -dataset Data_$pp0\
            -function "$ValArr([lindex $VarVary $vIdx 0])+<time:Data_$pp0>\
            *([lindex $VarVary $vIdx 1]-$ValArr([lindex $VarVary $vIdx 0]))"
        create_curve -name ${pp0}_8|[lindex $VarVary $vIdx 0]\
            -dataset Data_$pp0 -plot Plttau_$pp0\
            -axisX $xVar -axisY2 [lindex $VarVary $vIdx 0]

        # Note: ln() is log() in TCL. No error using ln() in -function though
        # Refer to available functions in Table 34, SVisual T-2022.03
        vputs -i2 "Plot the implied Voc curve kBTln((NA+Dn)Dn/nie/nie)"
        create_variable -name $jVar -dataset Data_$pp0\
            -function "1e3*$q*<IntegrSemiconductor $ogPlt:Data_$pp0>/$intArea"
        set jLst [lsort [get_variable_data $jVar -dataset Data_$pp0]]
        set jLow [lindex $jLst 0]
        set jHigh [lindex $jLst end]
        if {$n0 < $p0} {
            create_variable -name iVoc|V -dataset Data_$pp0\
                -function "$kB*$T*log(($p0+<$xVar:Data_$pp0>)*<$xVar:Data_$pp0>\
                /<$DnPlt EffectiveIntrinsicDensity:Data_$pp0>\
                /<$DnPlt EffectiveIntrinsicDensity:Data_$pp0>)"
        } else {
            create_variable -name iVoc|V -dataset Data_$pp0\
                -function "$kB*$T*log(($n0+<$xVar:Data_$pp0>)*<$xVar:Data_$pp0>\
                /<$DnPlt EffectiveIntrinsicDensity:Data_$pp0>\
                /<$DnPlt EffectiveIntrinsicDensity:Data_$pp0>)"
        }

        set var [lindex [split $xVar |] 1]
        vputs -i3 iVoc|$var
        create_curve -name ${pp0}_0|iVoc|$var -dataset Data_$pp0\
            -plot PltiVoc_$pp0 -axisX $jVar -axisY iVoc|V
        vputs -i3 [lindex $VarVary $vIdx 0]
        create_curve -name ${pp0}_1|[lindex $VarVary $vIdx 0]\
            -dataset Data_$pp0 -plot PltiVoc_$pp0\
            -axisX $jVar -axisY2 [lindex $VarVary $vIdx 0]
        vputs -i3 Dn|$var
        create_curve -name ${pp0}_2|Dn|$var -dataset Data_$pp0\
            -plot PltiVoc_$pp0 -axisX $jVar -axisY2 $xVar
        vputs -i3 n|$var
        create_curve -name ${pp0}_3|n|$var -dataset Data_$pp0\
            -plot PltiVoc_$pp0 -axisX $jVar -axisY2 "$DnPlt eDensity"
        vputs -i3 p|$var
        create_curve -name ${pp0}_4|p|$var -dataset Data_$pp0\
            -plot PltiVoc_$pp0 -axisX $jVar -axisY2 "$DnPlt hDensity"
        vputs -i3 nie|$var
        create_curve -name ${pp0}_5|nie|$var -dataset Data_$pp0\
            -plot PltiVoc_$pp0 -axisX $jVar\
            -axisY2 "$DnPlt EffectiveIntrinsicDensity"
        vputs -i3 Normd_pn|$var
        create_curve -name ${pp0}_6|Normd_pn|$var -dataset Data_$pp0\
            -plot PltiVoc_$pp0 -axisX $jVar -axisY2 "$DnPlt Normd_pn"

        # Extract implied Voc at JOG (default: 44 mA*cm^-2)
        if {[lindex $pp 3] > $jLow && [lindex $pp 3] < $jHigh} {
            set tmp [lindex [probe_curve ${pp0}_0|iVoc|$var\
                -valueX [lindex $pp 3] -plot PltiVoc_$pp0] 0]
            vputs -i3 "DOE: ${pp0}_iVoc [format %.5g $tmp]"
            set gVarArr(${pp0}_iVoc) [format %.5g $tmp]
        }

        vputs -i2 "Plot the effective lifetime curve"
        create_variable -name tau_eff|s -dataset Data_$pp0\
            -function "<$xVar:Data_$pp0>*$vol\
            /<IntegrSemiconductor $ogPlt:Data_$pp0>"
        create_curve -name ${pp0}_0|tau_eff -dataset Data_$pp0\
            -axisX $xVar -axisY tau_eff|s -plot Plttau_$pp0
        vputs -i2 "Plot the total J0 curve"
        create_variable -name J0_sum|fA*cm^-2 -dataset Data_$pp0\
            -function "<IntegrSemiconductor $ogPlt:Data_$pp0>\
            *1e15*$q/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
        create_curve -name ${pp0}_0|J0_sum -dataset Data_$pp0\
            -axisX $xVar -axisY J0_sum|fA*cm^-2 -plot PltJ0_$pp0

        # Extract effective lifetime at Dn (default: 1e15 cm^-3)
        if {[lindex $pp 2] > $xLow && [lindex $pp 2] < $xHigh} {
            set tmp [lindex [probe_curve ${pp0}_0|tau_eff\
                -valueX [lindex $pp 2] -plot Plttau_$pp0] 0]
            vputs -i3 "DOE: ${pp0}_tau_eff [format %.4e $tmp]"
            set gVarArr(${pp0}_tau_eff) [format %.4e $tmp]
        }

        vputs -i2 "Plot lifetime and J0 curves in regions"
        foreach grp $RegGen {
            if {[lindex $grp 0 2] ne "Semiconductor"} continue
            set mat [lindex $grp 0 0]
            set reg [lindex $grp 0 1]
            set idx [lindex $grp 0 end]

            # SRH is enabled by default for all semiconductors. In addition,
            # Auger and radiative are also enabled for silicon.
            # If PMI Auger, radiative is enabled only when fPR is 1.
            set srh 1
            foreach elm {aug rad trap fPR pmi} {
                set $elm 0
            }
            foreach elm $ModPar {
                if {"r$idx" eq [lindex $elm 0]} {
                    if {[regexp {\sAug} $elm]} {
                        set aug 1
                    } elseif {[regexp {\{(Aug(\s+[^\}]+)+)\}} $elm -> tmp]} {
                        if {[lindex $tmp 1] eq "!"} {
                            set aug -1
                        } else {
                            set aug 1
                            if {![string is double -strict [lindex $tmp 1]]} {
                                set pmi 1
                            }
                        }
                        if {[string is double -strict [lindex $tmp 2]]} {
                            set fPR [lindex $tmp 2]
                        }
                    } else {
                        if {$mat eq "Silicon"} {
                            set aug 1
                            set pmi 1
                        }
                    }
                    if {[regexp {\sRad} $elm]} {
                        set rad 1
                    } elseif {[regexp {\{(Rad(\s+[^\}]+)+)\}} $elm -> tmp]} {
                        if {[lindex $tmp 1] eq "!"} {
                            set rad -1
                        } else {
                            set rad 1
                        }
                    } else {
                        if {$mat eq "Silicon"} {
                            set rad 1
                        }
                    }
                    if {[regexp {\{(SRH(\s+[^\}]+)+)\}} $elm -> tmp]} {
                        if {[lindex $tmp 1] eq "!"} {
                            set srh 0
                        }
                    }
                    if {[regexp {\{Trap\s} $elm]
                        || [regexp \\\{r$idx\\s $RegIntfTrap]
                        || [regexp \\\{r\\d+/$idx\\s+TAT $IntfTun]} {
                        set trap 1
                    }
                    break
                }
            }
            if {$aug != -1 && $aug} {
                vputs -i3 tau_Aug|$reg
                create_variable -name tau_Aug|$reg|s -dataset Data_$pp0\
                    -function "<$xVar:Data_$pp0>*$vol\
                    /(<Integr$reg AugerRecombination:Data_$pp0>\
                    +<Integr$reg PMIRecombination:Data_$pp0>)"
                create_curve -name ${pp0}_3|tau_Aug|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_Aug|$reg|s -plot Plttau_$pp0
                vputs -i3 J0_Aug|$reg
                create_variable -name J0_Aug|$reg|fA*cm^-2 -dataset Data_$pp0\
                    -function "(<Integr$reg AugerRecombination:Data_$pp0>\
                    +<Integr$reg PMIRecombination:Data_$pp0>)*1e15*$q\
                    /$intArea/<$DnPlt Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_3|J0_Aug|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_Aug|$reg|fA*cm^-2 -plot PltJ0_$pp0
            }
            if {(!$pmi || $fPR == 1) && $rad != -1 && $rad} {
                vputs -i3 tau_B2B|$reg
                create_variable -name tau_B2B|$reg|s -dataset Data_$pp0\
                    -function "<$xVar:Data_$pp0>*$vol\
                    /<Integr$reg RadiativeRecombination:Data_$pp0>"
                create_curve -name ${pp0}_4|tau_B2B|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_B2B|$reg|s -plot Plttau_$pp0
                vputs -i3 J0_B2B|$reg
                create_variable -name J0_B2B|$reg|fA*cm^-2 -dataset Data_$pp0\
                    -function "<Integr$reg RadiativeRecombination:Data_$pp0>\
                    *1e15*$q/$intArea/<$DnPlt\
                    Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_4|J0_B2B|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_B2B|$reg|fA*cm^-2 -plot PltJ0_$pp0
            }
            if {$srh} {
                vputs -i3 tau_SRH|$reg
                create_variable -name tau_SRH|$reg|s -dataset Data_$pp0\
                    -function "<$xVar:Data_$pp0>*$vol\
                    /<Integr$reg srhRecombination:Data_$pp0>"
                create_curve -name ${pp0}_2|tau_SRH|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_SRH|$reg|s -plot Plttau_$pp0
                vputs -i3 J0_SRH|$reg
                create_variable -name J0_SRH|$reg|fA*cm^-2 -dataset Data_$pp0\
                    -function "<Integr$reg srhRecombination:Data_$pp0>*1e15\
                    *$q/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_2|J0_SRH|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_SRH|$reg|fA*cm^-2 -plot PltJ0_$pp0
            }
            if {$trap} {
                vputs -i3 tau_Trap|$reg
                create_variable -name tau_Trap|$reg|s -dataset Data_$pp0\
                    -function "<$xVar:Data_$pp0>*$vol\
                    /<Integr$reg eGapStatesRecombination:Data_$pp0>"
                create_curve -name ${pp0}_1|tau_Trap|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_Trap|$reg|s -plot Plttau_$pp0
                vputs -i3 J0_Trap|$reg
                create_variable -name J0_Trap|$reg|fA*cm^-2 -dataset Data_$pp0\
                    -function "1e15*$q/$intArea*<Integr$reg\
                    eGapStatesRecombination:Data_$pp0>/<$DnPlt\
                    Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_1|J0_Trap|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_Trap|$reg|fA*cm^-2 -plot PltJ0_$pp0
            }
        }

        vputs -i2 "Plot lifetime and J0 curves at region interfaces"
        foreach grp $IntfSRV {
            if {![string is double -strict [lindex $grp 2]]
                || [lindex $grp 2] == 0} continue
            set lst [string map {r "" / " "} [lindex $grp 0]]
            set intf [lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
                $RegGen [lindex $lst 1] 0 1]
            vputs -i3 tau|$intf
            create_variable -name tau|$intf|s -dataset Data_$pp0\
                -function "<$xVar:Data_$pp0>*$vol\
                /<Integr$intf SurfaceRecombination:Data_$pp0>"
            create_curve -name ${pp0}_5|tau|$intf -dataset Data_$pp0\
                -axisX $xVar -axisY tau|$intf|s -plot Plttau_$pp0
            vputs -i3 J0|$intf
            create_variable -name J0|$intf|fA*cm^-2 -dataset Data_$pp0\
                -function "<Integr$intf SurfaceRecombination:Data_$pp0>\
                *1e15*$q/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
            create_curve -name ${pp0}_5|J0|$intf -dataset Data_$pp0\
                -axisX $xVar -axisY J0|$intf|fA*cm^-2 -plot PltJ0_$pp0
        }

        # jArea is related to current density, photon flux, ...
        # intArea: affected by IntegrationUnit in Math section
        if {[llength $IntfCon]} {
            vputs -i2 "Plot lifetime and J0 curves at contacts"
            foreach elm [array names ValArr] {
                if {![regexp {^c\d$} $elm]
                    || [regexp {^Charge} $ValArr($elm)]} continue
                if {abs([lindex [get_variable_data -dataset Data_$pp0\
                    "$elm eCurrent"] 0]) < abs([lindex [get_variable_data\
                    -dataset Data_$pp0 "$elm hCurrent"] 0])} {
                    create_variable -name tau|$elm|s -dataset Data_$pp0\
                        -function "<$xVar:Data_$pp0>*$vol*$jArea/$intArea*$q\
                        /abs(<$elm eCurrent:Data_$pp0>)"
                    create_variable -name J0|$elm|fA*cm^-2 -dataset Data_$pp0\
                        -function "abs(<$elm eCurrent:Data_$pp0>)*1e15\
                        /$jArea/<$DnPlt Normd_pn:Data_$pp0>"
                } else {
                    create_variable -name tau|$elm|s -dataset Data_$pp0\
                        -function "<$xVar:Data_$pp0>*$vol*$jArea/$intArea*$q\
                        /abs(<$elm hCurrent:Data_$pp0>)"
                    create_variable -name J0|$elm|fA*cm^-2 -dataset Data_$pp0\
                        -function "abs(<$elm hCurrent:Data_$pp0>)*1e15\
                        /$jArea/<$DnPlt Normd_pn:Data_$pp0>"
                }
                vputs -i3 tau|$elm
                create_curve -name ${pp0}_6|tau|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY tau|$elm|s -plot Plttau_$pp0
                vputs -i3 J0|$elm
                create_curve -name ${pp0}_6|J0|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY J0|$elm|fA*cm^-2 -plot PltJ0_$pp0
            }
        }

        # Plot lifetime and J0 of integerated recombination in 'VV2Fld'
        foreach grp $VV2Fld {

            # Skip point
            if {[regexp {^p[^/]+$} [lindex $grp 0]]} continue

            # Skip regions and region interfaces
            if {[string index [lindex $grp 0] 0] eq "r"} continue
            foreach lst [lrange $grp 1 end] {
                if {[lindex $lst 0] ne "Integrate"} continue
                vputs -i2 "[lindex $grp 0]: Plot lifetime and J0 curves of\
                    integerated recombination"
                foreach elm [lrange $lst 1 end] {
                    set val [lindex [split $mfjProc::tabArr($elm) |] 0]

                    # Skip integration of non recombination fields
                    if {![regexp {Recombination$} $val]} continue
                    vputs -i3 $val
                    if {$Dim == 1} {
                        set str [string map {p (( / ,0),(}\
                            [lindex $grp 0]],$YMax))
                    } else {
                        set str [string map {p (( _ , / ),(}\
                            [lindex $grp 0]]))
                    }
                    create_variable -name tau|[lindex $grp 0]|$elm|s\
                        -dataset Data_$pp0 -function "<$xVar:Data_$pp0>*$vol\
                        /<IntegrWindow$str $val:Data_$pp0>"
                    create_curve -name ${pp0}_7|tau|[lindex $grp 0]|$elm\
                        -dataset Data_$pp0 -plot Plttau_$pp0 -axisX $xVar\
                        -axisY tau|[lindex $grp 0]|$elm|s
                    create_variable -name J0|[lindex $grp 0]|$elm|fA*cm^-2\
                        -dataset Data_$pp0 -function "1e15*$q*<IntegrWindow$str\
                        $val:Data_$pp0>/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
                    create_curve -name ${pp0}_7|J0|[lindex $grp 0]|$elm\
                        -dataset Data_$pp0 -plot PltJ0_$pp0 -axisX $xVar\
                        -axisY J0|[lindex $grp 0]|$elm|fA*cm^-2
                }
            }
        }

        vputs -i2 "Save all curves to $ftau"
        foreach curve [list_curves -plot Plttau_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            if {[regexp {^(8|9)\|} $str]} {
                set_curve_prop $curve -label $str -axis right -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]\
                    -plot Plttau_$pp0
            } else {
                set_curve_prop $curve -label $str -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]\
                    -plot Plttau_$pp0
            }
            incr pCnt
            if {[regexp {^9\|} $str]} {
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title\
                    -plot Plttau_$pp0] -> str
            } elseif {[regexp {^8\|} $str]} {
                set str Suns
            } else {
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                    -plot Plttau_$pp0] -> str
            }
            curve2CSV $curve $xCap [get_curve_prop $curve -label\
                -plot Plttau_$pp0]|$str Plttau_$pp0 $ftau
        }

        vputs -i2 "Save all curves to $fiVoc"
        foreach curve [list_curves -plot PltiVoc_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            if {[regexp {^0\|} $str]} {
                set_curve_prop $curve -label $str -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]\
                    -plot PltiVoc_$pp0
            } else {
                set_curve_prop $curve -label $str -axis right -markers_type\
                    [lindex $markerLst [expr $pCnt%$markerLen]]\
                    -plot PltiVoc_$pp0
            }
            incr pCnt
            if {[regexp {^0\|} $str]} {
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                    -plot PltiVoc_$pp0] -> str
            } elseif {[regexp {^[16]\|} $str]} {
                set str ""
            } else {
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title\
                    -plot PltiVoc_$pp0] -> str
            }
            curve2CSV $curve $jCap [get_curve_prop $curve -label\
                -plot PltiVoc_$pp0]|$str PltiVoc_$pp0 $fiVoc
        }

        vputs -i2 "Save all curves to $fJ0"
        foreach curve [list_curves -plot PltJ0_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            set_curve_prop $curve -label $str -plot PltJ0_$pp0\
                -markers_type [lindex $markerLst [expr $pCnt%$markerLen]]
            incr pCnt
            regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                -plot PltJ0_$pp0] -> str
            curve2CSV $curve $xCap [get_curve_prop $curve -label\
                -plot PltJ0_$pp0]|$str PltJ0_$pp0 $fJ0
        }
        continue

    } elseif {[lindex $pp 1] eq "SunsVoc" || [lindex $pp 1] eq "SunsJsc"} {

        # Verify whether the current varvary step is 'SpecScaling'
        if {[lindex $VarVary $vIdx 0] ne "SpecScaling"} {
            vputs -i2 "\nerror: element '$vIdx' of 'VarVary' not\
                'SpecScaling'!\n"
            continue
        }

        # Initialise parameters
        if {[lindex $pp 1] eq "SunsVoc"} {
            vputs -i2 "\nPlot Suns-Voc curve"
            set capSuns "n@node@_${pp0}: Suns-Voc at $T K"
            set fSuns $SimArr(OutDir)/n@node@_${pp0}_SunsVoc.csv
        } else {
            vputs -i2 "\nPlot Suns-Jsc curve"
            set capSuns "n@node@_${pp0}: Suns-Jsc at $T K"
            set fSuns $SimArr(OutDir)/n@node@_${pp0}_SunsJsc.csv
        }

        # Extract the spectrum power [mW*cm^-2]
        regexp {\{Spectrum\s+(\S+)} $GopAttr -> str
        set pSpec [specInt $str]
        set tmp [format %.4g $pSpec]
        vputs -i2 "DOE: ${pp0}_Pspec $tmp"
        set gVarArr(${pp0}_Pspec|mW*cm^-2) $tmp

        # Extract X axis and data trend (ascending or not)
        set xCap Suns
        set xVar Suns
        if {$ValArr(SpecScaling) < [lindex $VarVary $vIdx 1]} {
            set xAsc true
            set xLow $ValArr(SpecScaling)
            set xHigh [lindex $VarVary $vIdx 1]
        } else {
            set xAsc false
            set xLow [lindex $VarVary $vIdx 1]
            set xHigh $ValArr(SpecScaling)
        }

        # Find a current contact and voltage contacts from 'ValArr'
        set cLst [list]
        set vLst [list]
        foreach elm [array names ValArr] {
            if {[regexp {^c\d$} $elm]} {
                if {[lindex $ValArr($elm) 0] eq "Current"} {
                    lappend cLst $elm
                    vputs -i3 "Found a current contact '$elm'!"
                } elseif {[lindex $ValArr($elm) 0] eq "Voltage"} {
                    lappend vLst $elm
                    vputs -i3 "Found a voltage contact '$elm'!"
                }
            }
        }
        if {[lindex $pp 1] eq "SunsVoc" && [llength $cLst] == 0} {
            vputs -i2 "\nerror: no current contact found for Suns-Voc!\n"
            continue
        }
        if {[lindex $pp 1] eq "SunsJsc" && [llength $vLst] == 0} {
            vputs -i2 "\nerror: no voltage contact found for Suns-Jsc!\n"
            continue
        }
        create_plot -name PltSuns_$pp0 -1d

        # Create Suns variable
        create_variable -name Suns -dataset Data_$pp0\
            -function "$ValArr(SpecScaling)+<time:Data_$pp0>\
            *([lindex $VarVary $vIdx 1]-$ValArr(SpecScaling))"

        # Create Suns-Voc or Suns-Jsc curve
        if {[lindex $pp 1] eq "SunsVoc"} {
            foreach elm $cLst {
                create_curve -name ${pp0}_SVoc_$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY "$elm OuterVoltage" -plot PltSuns_$pp0
                set smpp 0
                set vmpp 0
                set pmpp 0
                foreach s [get_curve_data ${pp0}_SVoc_$elm -axisX\
                    -plot PltSuns_$pp0] v [get_curve_data ${pp0}_SVoc_$elm\
                    -axisY -plot PltSuns_$pp0] {
                    set p [expr ($s-1.)*$v]
                    if {$p < $pmpp} {
                        set pmpp $p
                        set vmpp $v
                        set smpp $s
                    }
                }
                set tmp [format %.4g $vmpp]
                vputs -i2 "DOE: ${pp0}_Vocmpp_$elm $tmp"
                set gVarArr(${pp0}_Vocmpp_$elm|V) $tmp
                set tmp [format %.4g $smpp]
                vputs -i2 "DOE: ${pp0}_Sunsmpp_$elm $tmp"
                set gVarArr(${pp0}_Sunsmpp_$elm) $tmp
                if {$xLow <= 1 && $xHigh >= 1} {
                    set voc [lindex [probe_curve ${pp0}_SVoc_$elm -valueX 1\
                        -plot PltSuns_$pp0] 0]
                    set tmp [format %.5g $voc]
                    vputs -i2 "DOE: ${pp0}_Voc_$elm $tmp"
                    set gVarArr(${pp0}_Voc_$elm|V) $tmp
                    set tmp [format %.4g [expr 1e2*(1.-$smpp)*$vmpp/$voc]]
                    vputs -i2 "DOE: ${pp0}_FF_$elm $tmp"
                    set gVarArr(${pp0}_FF_$elm) $tmp
                }
            }
        } else {
            foreach elm $vLst {
                create_variable -name "$elm CurrentDensity|mA*cm^-2"\
                    -dataset Data_$pp0\
                    -function "1e3*<$elm TotalCurrent:Data_$pp0>/$jArea"
                create_curve -name ${pp0}_SJsc_$elm -dataset Data_$pp0\
                     -plot PltSuns_$pp0\
                     -axisX $xVar -axisY "$elm CurrentDensity|mA*cm^-2"
                if {$xLow <= 1 && $xHigh >= 1} {
                    set jsc [lindex [probe_curve ${pp0}_SJsc_$elm -valueX 1\
                        -plot PltSuns_$pp0] 0]
                    set tmp [format %.4g [expr abs($jsc)]]
                    vputs -i2 "DOE: ${pp0}_Jsc_$elm $tmp"
                    set gVarArr(${pp0}_Jsc_$elm|mA*cm^-2) $tmp
                }
            }
        }

        windows_style -style max
        set_plot_prop -show_grid -show_curve_markers\
            -title_font_size 28 -title $capSuns
        set_grid_prop -show_minor_lines\
            -line1_style dash -line1_color gray\
            -line2_style dot -line2_color lightGray
        set_axis_prop -axis x -title_font_size 20 -type log\
            -scale_font_size 16 -scale_format preferred\
            -title $xCap -range "1e-6 $xHigh"
        if {[lindex $pp 1] eq "SunsVoc"} {
            set_axis_prop -axis y -title_font_size 20 -type linear\
                -scale_font_size 16 -scale_format preferred\
                -title {Open circuit voltage|V}
        } else {
            set_axis_prop -axis y -title_font_size 20 -type linear\
                -scale_font_size 16 -scale_format preferred\
                -title {Short circuit current density|mA/cm2}
        }
        set_legend_prop -location top_left

        vputs -i2 "Save all curves to $fSuns"
        foreach curve [list_curves -plot PltSuns_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            set_curve_prop $curve -label $str -markers_type\
                [lindex $markerLst [expr $pCnt%$markerLen]]
            regexp {\|(\S+)$} [get_axis_prop -axis Y -title] -> str
            incr pCnt
            curve2CSV $curve $xCap [get_curve_prop $curve -label]|$str\
                PltSuns_$pp0 $fSuns
        }

    }

    # Jloss, (J0 and lifetime) for known extraction and analysis
    if {[llength $pp] > 1} {
        set capJLoss "n@node@_${pp0}: JLoss for [lindex $pp 1] at $T K"
        set fJLoss $SimArr(OutDir)/n@node@_${pp0}_[lindex $pp 1]_JLoss.csv
        set capJ0 "n@node@_${pp0}: J0 for [lindex $pp 1] at $T K"
        set fJ0 $SimArr(OutDir)/n@node@_${pp0}_[lindex $pp 1]_J0.csv
        set captau "n@node@_${pp0}: lifetime for [lindex $pp 1] at $T K"
        set ftau $SimArr(OutDir)/n@node@_${pp0}_[lindex $pp 1]_lifetime.csv

        create_plot -name PltJLoss_$pp0 -1d
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

        # Use the Dn from position or average from 'VV2Fld'
        if {[regexp { Dn} $VV2Fld]} {
            vputs -i2 "\nPlot Jloss, J0 and lifetime curves for [lindex $pp 1]"
            vputs -i2 "Create Delta n variable \[cm^-3\]"
        } else {
            vputs -i2 "\nPlot Jloss curves for [lindex $pp 1]"
        }

        # Load equilibrium data to extract n0, p0, and ni0
        load_file eqm_@plot@ -name EqmData_$pp0
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
                set n0 [lindex [get_variable_data -dataset EqmData_$pp0\
                    "$txt eDensity"] 0]
                set p0 [lindex [get_variable_data -dataset EqmData_$pp0\
                    "$txt hDensity"] 0]
                set ni0 [lindex [get_variable_data -dataset EqmData_$pp0\
                    "$txt EffectiveIntrinsicDensity"] 0]
                vputs -i4 [format "n0= %.4E p0= %.4E ni0= %.4E" $n0 $p0 $ni0]
                if {$n0 >= $p0} {

                    # n-type substrate
                    create_variable -name Dn|[lindex $grp 0]|cm^-3 -dataset\
                        Data_$pp0 -function "<$txt hDensity:Data_$pp0>-$p0"
                } else {

                    # p-type substrate
                    create_variable -name Dn|[lindex $grp 0]|cm^-3 -dataset\
                        Data_$pp0 -function "<$txt eDensity:Data_$pp0>-$n0"
                }

                # Create the normalised pn for the first Dn: (pn/ni/ni - 1)
                if {[llength $dnLst] == 0} {
                    set DnVar Dn|[lindex $grp 0]|cm^-3
                    set DnPlt $txt
                    create_variable -name "$txt Normd_pn" -dataset Data_$pp0\
                        -function "(<$txt hDensity:Data_$pp0>\
                        *<$txt eDensity:Data_$pp0>\
                        /<$txt EffectiveIntrinsicDensity:Data_$pp0>\
                        /<$txt EffectiveIntrinsicDensity:Data_$pp0>-1.)"
                }
                lappend dnLst Dn|[lindex $grp 0]
            }
        }
        if {[llength $dnLst]} {
            create_plot -name PltJ0_$pp0 -1d
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
            set_axis_prop -axis y2 -title_font_size 20 -type log\
                -scale_font_size 16 -scale_format preferred\
                -title {Excess carrier densities|cm^-3}
            set_legend_prop -location top_left

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
            set_axis_prop -axis y2 -title_font_size 20 -type log\
                -scale_font_size 16 -scale_format preferred\
                -title {Excess carrier density|cm^-3}
            set_legend_prop -location top_left

            # Extract volume of all semiconductors [cm^3]
            if {[regexp {\{(Mono|Spec)Scaling\s} $VarVary]} {
                set val [get_variable_data -dataset Data_$pp0\
                    "IntegrSemiconductor $ogPlt"]
                if {[lindex $val 0] == 0} {
                    set vol [expr 1.*[lindex $val end]/[lindex\
                        [get_variable_data -dataset Data_$pp0\
                        "AveSemiconductor $ogPlt"] end]]
                } else {
                    set vol [expr 1.*[lindex $val 0]/[lindex\
                        [get_variable_data -dataset Data_$pp0\
                        "AveSemiconductor $ogPlt"] 0]]
                }
            } else {

                # Manually calculate total semiconductor volume
                # Will improve accuracy later
                if {$Dim == 3} {
                    set vol [expr 1e-12*$XMax*$YMax*$ZMax]
                } elseif {$Dim == 2 && $Cylind} {
                    set vol [expr 1e-12*$XMax*$PI*$YMax*$YMax]
                } else {
                    set vol [expr 1e-8*$XMax*$YMax]
                }
            }
            vputs -i3 "Total semiconductor region volume: $vol cm^3"
            vputs -i2 "Plot excess carrier density curves"
            foreach elm $dnLst {
                create_curve -name ${pp0}_9|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY2 $elm|cm^-3 -plot PltJLoss_$pp0
                create_curve -name ${pp0}_9|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY2 $elm|cm^-3 -plot Plttau_$pp0
                create_curve -name ${pp0}_9|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY2 $elm|cm^-3 -plot PltJ0_$pp0
            }
            vputs -i2 "Plot n, p, and nie curves"
            set var [lindex [split $DnVar |] 1]
            vputs -i3 n|$var
            create_curve -name ${pp0}_8|n|$var -dataset Data_$pp0\
                -plot PltJ0_$pp0 -axisX $xVar -axisY2 "$DnPlt eDensity"
            vputs -i3 p|$var
            create_curve -name ${pp0}_8|p|$var -dataset Data_$pp0\
                -plot PltJ0_$pp0 -axisX $xVar -axisY2 "$DnPlt hDensity"
            vputs -i3 nie|$var
            create_curve -name ${pp0}_8|nie|$var -dataset Data_$pp0\
                -plot PltJ0_$pp0 -axisX $xVar\
                -axisY2 "$DnPlt EffectiveIntrinsicDensity"
        }

        vputs -i2 "Plot JLoss, (J0 and lifetime) curves in regions"
        foreach grp $RegGen {
            if {[lindex $grp 0 2] ne "Semiconductor"} continue
            set mat [lindex $grp 0 0]
            set reg [lindex $grp 0 1]
            set idx [lindex $grp 0 end]

            # SRH is enabled by default for all semiconductors. In addition,
            # Auger and radiative are also enabled for silicon.
            # If PMI Auger, radiative is enabled only when fPR is 1.
            set srh 1
            foreach elm {aug rad trap fPR pmi} {
                set $elm 0
            }
            foreach elm $ModPar {
                if {"r$idx" eq [lindex $elm 0]} {
                    if {[regexp {\sAug} $elm]} {
                        set aug 1
                    } elseif {[regexp {\{(Aug(\s+[^\}]+)+)\}} $elm -> tmp]} {
                        if {[lindex $tmp 1] eq "!"} {
                            set aug -1
                        } else {
                            set aug 1
                            if {![string is double -strict [lindex $tmp 1]]} {
                                set pmi 1
                            }
                        }
                        if {[string is double -strict [lindex $tmp 2]]} {
                            set fPR [lindex $tmp 2]
                        }
                    } else {
                        if {$mat eq "Silicon"} {
                            set aug 1
                            set pmi 1
                        }
                    }
                    if {[regexp {\sRad} $elm]} {
                        set rad 1
                    } elseif {[regexp {\{(Rad(\s+[^\}]+)+)\}} $elm -> tmp]} {
                        if {[lindex $tmp 1] eq "!"} {
                            set rad -1
                        } else {
                            set rad 1
                        }
                    } else {
                        if {$mat eq "Silicon"} {
                            set rad 1
                        }
                    }
                    if {[regexp {\{(SRH(\s+[^\}]+)+)\}} $elm -> tmp]} {
                        if {[lindex $tmp 1] eq "!"} {
                            set srh 0
                        }
                    }
                    if {[regexp {\{Trap\s} $elm]
                        || [regexp \\\{r$idx\\s $RegIntfTrap]
                        || [regexp \\\{r\\d+/$idx\\s+TAT $IntfTun]} {
                        set trap 1
                    }
                    break
                }
            }
            if {$aug != -1 && $aug} {
                vputs -i3 JLoss_Aug|$reg
                create_variable -name JLoss_Aug|$reg|mA*cm^-2\
                    -dataset Data_$pp0\
                    -function "(<Integr$reg AugerRecombination:Data_$pp0>\
                    +<Integr$reg PMIRecombination:Data_$pp0>)*1e3*$q/$intArea"
                create_curve -name ${pp0}_3|Aug|$reg -dataset Data_$pp0\
                    -plot PltJLoss_$pp0\
                    -axisX $xVar -axisY JLoss_Aug|$reg|mA*cm^-2
            }
            if {(!$pmi || $fPR == 1) && $rad != -1 && $rad} {
                vputs -i3 JLoss_B2B|$reg
                create_variable -name JLoss_B2B|$reg|mA*cm^-2\
                    -dataset Data_$pp0 -function "1e3*$q/$intArea*<Integr$reg\
                    RadiativeRecombination:Data_$pp0>"
                create_curve -name ${pp0}_4|B2B|$reg -dataset Data_$pp0\
                    -plot PltJLoss_$pp0\
                    -axisX $xVar -axisY JLoss_B2B|$reg|mA*cm^-2
            }
            if {$srh} {
                vputs -i3 JLoss_SRH|$reg
                create_variable -name JLoss_SRH|$reg|mA*cm^-2\
                    -dataset Data_$pp0 -function "1e3*$q/$intArea*<Integr$reg\
                    srhRecombination:Data_$pp0>"
                create_curve -name ${pp0}_2|SRH|$reg -dataset Data_$pp0\
                    -plot PltJLoss_$pp0\
                    -axisX $xVar -axisY JLoss_SRH|$reg|mA*cm^-2
            }
            if {$trap} {
                vputs -i3 JLoss_Trap|$reg
                if {[regexp \\\{r\\d+/$idx\\s+TAT $IntfTun]} {

                    # Trap-assisted tunnelling: JLoss = JTrap + J
                    # It is not accurate yet. Need better algorithm
                    create_variable -name JLoss_Trap|$reg|mA*cm^-2\
                        -dataset Data_$pp0 -function "1e3*($q*<Integr$reg\
                        eGapStatesRecombination:Data_$pp0>/$intArea+<$bCon\
                        TotalCurrent:Data_$pp0>/$jArea)"
                } else {
                    create_variable -name JLoss_Trap|$reg|mA*cm^-2\
                        -dataset Data_$pp0 -function "1e3*$q*<Integr$reg\
                        eGapStatesRecombination:Data_$pp0>/$intArea"
                }
                create_curve -name ${pp0}_1|Trap|$reg -dataset Data_$pp0\
                    -plot PltJLoss_$pp0\
                    -axisX $xVar -axisY JLoss_Trap|$reg|mA*cm^-2
            }

            if {![llength $dnLst]} continue
            if {$aug != -1 && ($mat eq "Silicon" || $aug)} {
                vputs -i3 J0_Aug|$reg
                create_variable -name J0_Aug|$reg|fA*cm^-2 -dataset Data_$pp0\
                    -function "(<Integr$reg AugerRecombination:Data_$pp0>\
                    +<Integr$reg PMIRecombination:Data_$pp0>)*1e15*$q/$intArea\
                    /<$DnPlt Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_3|Aug|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_Aug|$reg|fA*cm^-2 -plot PltJ0_$pp0
                vputs -i3 tau_Aug|$reg
                create_variable -name tau_Aug|$reg|s -dataset Data_$pp0\
                    -function "<$DnVar:Data_$pp0>*$vol\
                    /(<Integr$reg AugerRecombination:Data_$pp0>\
                    +<Integr$reg PMIRecombination:Data_$pp0>)"
                create_curve -name ${pp0}_3|tau_Aug|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_Aug|$reg|s -plot Plttau_$pp0
            }
            if {(!$pmi || $fPR == 1) && $rad != -1
                && ($mat eq "Silicon" || $rad)} {
                vputs -i3 J0_B2B|$reg
                create_variable -name J0_B2B|$reg|fA*cm^-2 -dataset Data_$pp0\
                    -function "<Integr$reg RadiativeRecombination:Data_$pp0>\
                    *1e15*$q/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_4|B2B|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_B2B|$reg|fA*cm^-2 -plot PltJ0_$pp0
                vputs -i3 tau_B2B|$reg
                create_variable -name tau_B2B|$reg|s -dataset Data_$pp0\
                    -function "<$DnVar:Data_$pp0>*$vol\
                    /<Integr$reg RadiativeRecombination:Data_$pp0>"
                create_curve -name ${pp0}_4|tau_B2B|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_B2B|$reg|s -plot Plttau_$pp0
            }
            if {$srh} {
                vputs -i3 J0_SRH|$reg
                create_variable -name J0_SRH|$reg|fA*cm^-2 -dataset Data_$pp0\
                    -function "<Integr$reg srhRecombination:Data_$pp0>\
                    *1e15*$q/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_2|SRH|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_SRH|$reg|fA*cm^-2 -plot PltJ0_$pp0
                vputs -i3 tau_SRH|$reg
                create_variable -name tau_SRH|$reg|s -dataset Data_$pp0\
                    -function "<$DnVar:Data_$pp0>*$vol\
                    /<Integr$reg srhRecombination:Data_$pp0>"
                create_curve -name ${pp0}_2|tau_SRH|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_SRH|$reg|s -plot Plttau_$pp0
            }
            if {$trap} {
                vputs -i3 J0_Trap|$reg
                if {[regexp \\\{r\\d+/$idx\\s+TAT $IntfTun]} {
                    create_variable -name J0_Trap|$reg|fA*cm^-2\
                        -dataset Data_$pp0 -function "1e15*($q*<Integr$reg\
                        eGapStatesRecombination:Data_$pp0>/$intArea+<$bCon\
                        TotalCurrent:Data_$pp0>/$jArea)\
                        /<$DnPlt Normd_pn:Data_$pp0>"
                    create_variable -name tau_Trap|$reg|s -dataset Data_$pp0\
                        -function "<$DnVar:Data_$pp0>*$vol\
                        /(<Integr$reg eGapStatesRecombination:Data_$pp0>\
                        +<$bCon TotalCurrent:Data_$pp0>/$q)"
                } else {
                    create_variable -name J0_Trap|$reg|fA*cm^-2\
                        -dataset Data_$pp0 -function "1e15*$q*<Integr$reg\
                        eGapStatesRecombination:Data_$pp0>/$intArea\
                        /<$DnPlt Normd_pn:Data_$pp0>"
                    create_variable -name tau_Trap|$reg|s -dataset Data_$pp0\
                        -function "<$DnVar:Data_$pp0>*$vol\
                        /<Integr$reg eGapStatesRecombination:Data_$pp0>"
                }
                create_curve -name ${pp0}_1|Trap|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_Trap|$reg|fA*cm^-2 -plot PltJ0_$pp0
                vputs -i3 tau_Trap|$reg
                create_curve -name ${pp0}_1|tau_Trap|$reg -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_Trap|$reg|s -plot Plttau_$pp0
            }
        }

        vputs -i2 "Plot JLoss, (J0 and lifetime) curves at region interfaces"
        foreach grp $IntfSRV {
            if {![string is double -strict [lindex $grp 2]]
                || [lindex $grp 2] == 0} continue
            set lst [string map {r "" / " "} [lindex $grp 0]]
            set intf [lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
                $RegGen [lindex $lst 1] 0 1]
            vputs -i3 JLoss|$intf
            create_variable -name JLoss|$intf|mA*cm^-2 -dataset Data_$pp0\
                -function "<Integr$intf SurfaceRecombination:Data_$pp0>\
                *1e3*$q/$intArea"
            create_curve -name ${pp0}_5|$intf -dataset Data_$pp0\
                -axisX $xVar -axisY JLoss|$intf|mA*cm^-2 -plot PltJLoss_$pp0

            if {![llength $dnLst]} continue
            vputs -i3 J0|$intf
            create_variable -name J0|$intf|fA*cm^-2 -dataset Data_$pp0\
                -function "<Integr$intf SurfaceRecombination:Data_$pp0>\
                *1e15*$q/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
            create_curve -name ${pp0}_5|$intf -dataset Data_$pp0\
                -axisX $xVar -axisY J0|$intf|fA*cm^-2 -plot PltJ0_$pp0
            vputs -i3 tau|$intf
            create_variable -name tau|$intf|s -dataset Data_$pp0\
                -function "<$DnVar:Data_$pp0>*$vol\
                /<Integr$intf SurfaceRecombination:Data_$pp0>"
            create_curve -name ${pp0}_5|tau|$intf -dataset Data_$pp0\
                -axisX $xVar -axisY tau|$intf|s -plot Plttau_$pp0
        }

        # Extract minority carrier current density from contacts
        if {[llength $IntfCon]} {
            vputs -i2 "Plot JLoss, (J0 and lifetime) curves at contacts"
            set pCon ""
            foreach elm [array names ValArr] {
                if {![regexp {^c\d$} $elm]
                    || [regexp {^Charge} $ValArr($elm)]} continue

                # Find the p-type contact (Jsc < 0)
                if {[lindex $ValArr($elm) 0] eq "Voltage"} {
                    set lst [get_variable_data "$elm TotalCurrent"\
                        -dataset Data_$pp0]
                    if {[lindex $lst 0] < 0} {
                        set pCon $elm
                    }
                }
                if {abs([lindex [get_variable_data -dataset Data_$pp0\
                    "$elm eCurrent"] 0]) < abs([lindex [get_variable_data\
                    -dataset Data_$pp0 "$elm hCurrent"] 0])} {
                     create_variable -name JLoss|$elm|mA*cm^-2\
                        -dataset Data_$pp0 -function "abs(<$elm\
                        eCurrent:Data_$pp0>)*1e3/$jArea"
                     if {[llength $dnLst]} {
                        create_variable -name J0|$elm|fA*cm^-2\
                            -dataset Data_$pp0\
                            -function "abs(<$elm eCurrent:Data_$pp0>)\
                            *1e15/$jArea/<$DnPlt Normd_pn:Data_$pp0>"
                        create_variable -name tau|$elm|s -dataset Data_$pp0\
                            -function "<$DnVar:Data_$pp0>*$vol*$jArea/$intArea\
                            *$q/abs(<$elm eCurrent:Data_$pp0>)"
                     }
                } else {
                    create_variable -name JLoss|$elm|mA*cm^-2\
                        -dataset Data_$pp0 -function "abs(<$elm\
                        hCurrent:Data_$pp0>)*1e3/$jArea"
                    if {[llength $dnLst]} {
                        create_variable -name J0|$elm|fA*cm^-2\
                            -dataset Data_$pp0\
                            -function "abs(<$elm hCurrent:Data_$pp0>)\
                            *1e15/$jArea/<$DnPlt Normd_pn:Data_$pp0>"
                        create_variable -name tau|$elm|s -dataset Data_$pp0\
                            -function "<$DnVar:Data_$pp0>*$vol*$jArea/$intArea\
                            *$q/abs(<$elm hCurrent:Data_$pp0>)"
                    }
                }
                vputs -i3 JLoss|$elm
                create_curve -name ${pp0}_6|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY JLoss|$elm|mA*cm^-2 -plot PltJLoss_$pp0

                if {![llength $dnLst]} continue
                vputs -i3 J0|$elm
                create_curve -name ${pp0}_6|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY J0|$elm|fA*cm^-2 -plot PltJ0_$pp0
                vputs -i3 tau|$elm
                create_curve -name ${pp0}_6|tau|$elm -dataset Data_$pp0\
                    -axisX $xVar -axisY tau|$elm|s -plot Plttau_$pp0
            }
        }

        # Total JLoss is the difference between JOG and J$pCon
        if {$pCon ne ""} {
            vputs -i2 "Plot the total JLoss curve from JOG + J$pCon"
            create_variable -name JLoss_sum|mA*cm^-2 -dataset Data_$pp0\
                -function "<IntegrSemiconductor $ogPlt:Data_$pp0>/$intArea\
                *1e3*$q+1e3*<$pCon TotalCurrent:Data_$pp0>/$jArea"
            create_curve -name ${pp0}_0|JLoss_sum -dataset Data_$pp0\
                -axisX $xVar -axisY JLoss_sum|mA*cm^-2 -plot PltJLoss_$pp0
            if {[llength $dnLst]} {
                vputs -i2 "Plot the total J0 curve"
                create_variable -name J0_sum|fA*cm^-2 -dataset Data_$pp0\
                    -function "(<IntegrSemiconductor $ogPlt:Data_$pp0>\
                    +<$pCon TotalCurrent:Data_$pp0>/$jArea*$intArea/$q)*1e15*\
                    $q/$intArea/<$DnPlt Normd_pn:Data_$pp0>"
                create_curve -name ${pp0}_0|J0_sum -dataset Data_$pp0\
                    -axisX $xVar -axisY J0_sum|fA*cm^-2 -plot PltJ0_$pp0
                vputs -i2 "Plot the effective lifetime curve"
                create_variable -name tau_eff|s -dataset Data_$pp0\
                    -function "<$DnVar:Data_$pp0>*$vol\
                    /(<IntegrSemiconductor $ogPlt:Data_$pp0>\
                    +<$pCon TotalCurrent:Data_$pp0>/$jArea*$intArea/$q)"
                create_curve -name ${pp0}_0|tau_eff -dataset Data_$pp0\
                    -axisX $xVar -axisY tau_eff|s -plot Plttau_$pp0
            }
        }

        vputs -i2 "Save all curves to $fJLoss"
        foreach curve [list_curves -plot PltJLoss_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            set_curve_prop $curve -label $str -plot PltJLoss_$pp0\
                -markers_type [lindex $markerLst [expr $pCnt%$markerLen]]
            incr pCnt
            if {[regexp {^9\|} $str]} {
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title\
                    -plot PltJLoss_$pp0] -> str
            } else {
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                    -plot PltJLoss_$pp0] -> str
            }
            curve2CSV $curve $xCap [get_curve_prop $curve -label\
                -plot PltJLoss_$pp0]|$str PltJLoss_$pp0 $fJLoss
        }

        if {![llength $dnLst]} continue
        vputs -i2 "Save all curves to $fJ0"
        foreach curve [list_curves -plot PltJ0_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            set_curve_prop $curve -label $str -plot PltJ0_$pp0\
                -markers_type [lindex $markerLst [expr $pCnt%$markerLen]]
            incr pCnt
            if {[regexp {^[89]\|} $str]} {
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title\
                    -plot PltJ0_$pp0] -> str
            } else {
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                    -plot PltJ0_$pp0] -> str
            }
            curve2CSV $curve $xCap [get_curve_prop $curve -label\
                -plot PltJ0_$pp0]|$str PltJ0_$pp0 $fJ0
        }

        vputs -i2 "Save all curves to $ftau"
        foreach curve [list_curves -plot Plttau_$pp0] {
            regexp {^v\d+_(.+)$} $curve -> str
            set_curve_prop $curve -label $str -plot Plttau_$pp0\
                -markers_type [lindex $markerLst [expr $pCnt%$markerLen]]
            incr pCnt
            if {[regexp {^9\|} $str]} {
                regexp {\|(\S+)$} [get_axis_prop -axis Y2 -title\
                    -plot Plttau_$pp0] -> str
            } else {
                regexp {\|(\S+)$} [get_axis_prop -axis Y -title\
                    -plot Plttau_$pp0] -> str
            }
            curve2CSV $curve $xCap [get_curve_prop $curve -label\
                -plot Plttau_$pp0]|$str Plttau_$pp0 $ftau
        }
    }

} ;# end of foreach

# Update the file 'SimArr(OutDir)/SimArr(FDOESum)'
gVar2DOESum gVarArr @node@
vputs "\nProcessing time = [expr [clock seconds] - $tm] s\n"
