!(

#--- Get Tcl global variables
#include ".mfj/varSim.tcl"

# Check 'VarVary' for optical requirement
set VarVary [str2List "" $VarVary]
if {([regexp {\{MonoScaling\s} $VarVary] && $LPD == 0)
    || ([regexp {\{SpecScaling\s} $VarVary] && !$LoadTDR && $LPD == 0)} {
    error "no optical solver in 'GopAttr' for varying optics in 'VarVary'!"
}

# Check whether the spectrum file is missing in 'GopAttr' if required
if {[regexp {\{SpecScaling\s} $VarVary] && !$LoadTDR
    && ![regexp {\{Spectrum\s} $GopAttr]} {
    error "no spectrum file specified in 'GopAttr'!"
}

# No distributed resistance for current contact
# Check for current contacts
foreach grp $VarVary {
    if {[regexp {^(c\d) Current} $grp -> var]} {

        # Check distributed resistance from IntfAttr
        foreach elm $IntfCon {
            if {[lindex $elm 1] eq $var && [lindex $elm 4] > 0} {
                error "no distributed resistance for current contact '$var'!"
            }
        }
    }
}

# Alert users to remove/combine duplicate regions/materials
set ModPar [lsort -index 0 $ModPar]
if {[llength [lsort -unique -index 0 $ModPar]] < [llength $ModPar]} {
    error "duplicate entries found in ModPar '$ModPar'!"
}

# Update 'ModPar' to put each individual model and value as a sublist
set lst [list]
foreach grp $ModPar {
    set val [lrange $grp 0 1]
    set grp [lrange $grp 2 end]
    set tmp ""
    while {[llength $grp]} {
        if {[regexp {^(EA0|Eg0|NC300|NV300|DC|mt|mu|BGN|SRH|Trap|Aug|Rad)$}\
            [lindex $grp 0]]} {
            if {[llength $tmp]} {
                lappend val $tmp
            }
            set tmp [lindex $grp 0]
        } else {
            lappend tmp [lindex $grp 0]
        }
        set grp [lrange $grp 1 end]
    }
    if {[llength $tmp]} {
        lappend val $tmp
    }

    # Alert users to remove/combine duplicate models
    set tmp [lsort -index 0 [lrange $val 2 end]]
    if {[llength [lsort -unique -index 0 $tmp]] < [llength $tmp]} {
        error "duplicate models found in ModPar '$val'!"
    }
    lappend lst [concat [lrange $val 0 1] $tmp]
}
set ModPar $lst
vputs [wrapText "'ModPar': \{$ModPar\}" "* "]

# Split 'GetFld' into 'VV2Fld' and 'SS2Fld'
set VV2Fld [list]
set SS2Fld [list]
foreach grp [str2List "" $GetFld] {
    if {[regexp {^p[^/]+} [lindex $grp 0]]} {
        if {[string is integer -strict [lindex $grp 1]]} {
            lappend SS2Fld $grp
        } else {
            lappend VV2Fld $grp
        }
    } else {
        if {[regexp {^(Ave|Int|Max|Lea)\w+$} [lindex $grp 1]]} {
            lappend VV2Fld $grp
        } else {
            lappend SS2Fld $grp
        }
    }
}

# Update 'VV2Fld' to put each extraction method and fields as a sublist
set lst [list]
foreach grp $VV2Fld {
    set val [lindex $grp 0]

    # Keep the first position/region/window/interface and skip duplicates
    if {[regexp \\\{$val $lst]} continue
    set grp [lrange $grp 1 end]

    # 'p' extract fields from a point
    if {[regexp {^p[^/]+$} $val]} {

        # 'Dn' means 'n p D ni_eff'. Remove duplicates
        if {[regexp {Dn} $grp]} {
            set grp [string map {" n" "" " p" "" " Dop" "" " ni_eff" ""} $grp]
        }
        lappend lst [concat $val [lsort -unique $grp]]
        continue
    }
    set var [list]
    while {[llength $grp]} {
        if {[regexp {^(Ave|Int|Max|Lea)\w+$} [lindex $grp 0]]} {
            if {[llength $var]} {

                # 'Dn' means 'n p D ni_eff'. Remove duplicates
                if {[regexp {Dn} $var]} {
                    set var [string map {" ni_eff CP" "" " n CP" "" " p CP" ""
                        " Dop CP" ""} $var]
                    set var [string map {" ni_eff" "" " n" "" " p" ""
                        " Dop" ""} $var]
                }

                # No coordinate printing for 'Integrate'
                if {[lindex $var 0] eq "Integrate"} {
                    lappend val [string map {" CP" ""} $var]
                } else {
                    lappend val $var
                }
            }
            set var [lindex $grp 0]
        } else {
            lappend var [lindex $grp 0]
        }
        set grp [lrange $grp 1 end]
    }
    if {[llength $var]} {
        if {[regexp {Dn} $var]} {
            set var [string map {" ni_eff CP" "" " n CP" "" " p CP" ""
                " Dop CP" ""} $var]
            set var [string map {" ni_eff" "" " n" "" " p" "" " Dop" ""} $var]
        }
        if {[lindex $var 0] eq "Integrate"} {
            lappend val [string map {" CP" ""} $var]
        } else {
            lappend val $var
        }
    }

    # Keep the last duplicate extraction and sort in increasing order
    lappend lst [concat [lindex $val 0]\
        [lsort -unique -index 0 [lrange $val 1 end]]]
}

# Rename: 'Least' means 'Minimum'
regsub -all {Least} $lst Minimum VV2Fld
vputs [wrapText "'VV2Fld': \{$VV2Fld\}" "* "]

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
vputs [wrapText "'SS2Fld': \{$SS2Fld\}" "* "]

# Set up a global array to store initial values of variables
array set ValArr [list SpecScaling 0 MonoScaling 0]

# Set the default wavelength and intensity to 0.3 um and 1e-3 W/cm^2
if {[regexp {\{Monochromatic\s+(\S+)} $GopAttr -> val]} {
    set ValArr(Wavelength) $val
} else {
    lappend GopAttr [list Monochromatic 0.3 1e-3]
    set ValArr(Wavelength) 0.3
}

# Set the default incidence
if {![regexp {\{Incidence\s} $GopAttr]} {
    lappend GopAttr [list Incidence 0 0 0]
}
vputs [wrapText "'GopAttr': \{$GopAttr\}" "* "]

# Keep the last contact settings if duplicates exist to 'IntfCon'
set IntfCon [lsort -unique -index 1 $IntfCon]
foreach grp $IntfCon {
    if {[regexp {^C} [lindex $grp 2]]} {
        array set ValArr [list [lindex $grp 1] [lrange $grp 2 3]]
    } else {
        array set ValArr [list [lindex $grp 1]\
            [list Voltage [lindex $grp 3]]]
    }
}
vputs [wrapText "'IntfCon': \{$IntfCon\}" "* "]
vputs [wrapText "array 'ValArr': \{[array get ValArr]\}" "* "]

)!

* set node dependence
#setdep @previous@
*--- Refer to Table 207 in sdevice manual vT-2022.03

File {
    Current= "@plot@"
    Grid= "@tdr@"
    Output= "@log@"
    OpticsOutput= "@optlog@"
    Parameter= "@parameter@"
    Plot= "@tdrdat@"
    PMIUserFields= "@tdr@"
    !(

    if {[regexp {c\d\s+Frequency} $VarVary]} {
        vputs -n -i-2 "
            ACExtract= \"@acplot@\""
    }
    vputs -n -i-2 "
            PMIPath= \"$SimArr(PMIDir)\""
    if {$LoadTDR} {
        vputs -n -i-2 "
            OpticalGenerationInput= \"@tdr@\""
    }
    if {[regexp {\sExternal\s+([^\s\}]+)} $GopAttr -> str]} {

        # Only assign the first spectral OG file and ignore the rest
        vputs -n -i-2 "
            OpticalSolverInput= \"$str\""
    }
    if {[regexp {\{SpecScaling\s} $VarVary] && !$LoadTDR} {
        set val n@node@_spec.txt
        foreach grp $GopAttr {
            if {[lindex $grp 0] eq "Spectrum"} {
                set lst [lrange $grp 1 end]
            }
            if {[lindex $grp 0] eq "Incidence"} {
                set tmp [lindex $grp 1]
            }
        }

        # 'eval': concat, interpret the string and return result
        eval customSpec $lst $tmp $val
        vputs -n -i-2 "
            IlluminationSpectrum= \"$val\""
    }

    )!

}

!(

if {[llength $IntfCon]} {
    vputs -n -i-2 "
        *--- Refer to Table 206 in T-2022.03
        Electrode \{"
}
foreach grp $IntfCon {
    vputs -n -i-2 "
            \{Name= \"[lindex $grp 1]\" "

    # Current or charge contact
    if {[lindex $grp 2] eq "Current"} {
        vputs -n -c "[lindex $grp 2]= [lindex $grp 3] Voltage= 0"
    } elseif {[lindex $grp 2] eq "Charge"} {
        vputs -n -c "[lindex $grp 2]= [lindex $grp 3]"
    } else {
        if {[lindex $grp 2] eq "Ohmic"} {
            vputs -n -c "Voltage= [lindex $grp 3]"
        } else {
            vputs -n -c "Voltage= [lindex $grp 3] [lindex $grp 2]"
        }
        if {[lindex $grp 4] > 0} {
            vputs -n -c " DistResist= [lindex $grp 4]"
        }
        if {[lindex $grp 2] eq "Schottky"} {
            vputs -n -c " Barrier= [lindex $grp 5]"
        }
        if {[llength $grp] == 7} {
            vputs -n -i-2 "
                eRecVelocity= [lindex $grp 6] hRecVelocity= [lindex $grp 6]"
        } else {
            vputs -n -i-2 "
                eRecVelocity= [lindex $grp 6] hRecVelocity= [lindex $grp 7]"
        }
    }
    vputs -n -i-2 "
            \}"
}
if {[llength $IntfCon]} {
    vputs -n -i-2 "
        \}\n"
}

if {[regexp {\sRaytrace\s} $GopAttr]} {
    vputs -n -i-2 "
        RayTraceBC \{ * Default Reflectivity boundary condition
            \{Name= \"TOpt\" reflectivity= 0 transmittivity= 0\}
            \{Name= \"BOpt\" reflectivity= 0 transmittivity= 0\}"
    if {$Dim == 3} {
        vputs -n -i-2 "
            \{Name= \"LOpt\" reflectivity= 1.0\}
            \{Name= \"ROpt\" reflectivity= 1.0\}
            \{Name= \"FOpt\" reflectivity= 1.0\}
            \{Name= \"NOpt\" reflectivity= 1.0\}"
    } else {
        if {!$Cylind} {
            vputs -n -i-3 "
                \{Name= \"LOpt\" reflectivity= 1.0\}"
        }
        vputs -n -i-2 "
            \{Name= \"ROpt\" reflectivity= 1.0\}"
    }
    vputs -n -i-2 "
        \}\n"

    foreach grp $GopAttr {
        if {[lindex $grp 1] eq "ARC"} {
            set lst [string map {r "" / " "} [lindex $grp 0]]
            set var [lindex $RegGen [lindex $lst 0] 0 1]
            set val [lindex $RegGen [lindex $lst 1] 0 1]
            vputs -n -i-4 "
                Physics (RegionInterface= \"$var/$val\") \{
                    RayTraceBC (
                        TMM (
                            ReferenceRegion= \"$var\"
                            LayerStructure \{ * Start from the reference"
            foreach {var val tmp} [lrange $grp 2 end] {
                vputs -n -i-4 "
                                $val\t\"$var\";"
            }
            vputs -n -i-4 "
                            \}
                        )
                    )
                \}\n"
        }

        if {[regexp {^r\d+/\d+} [lindex $grp 0]]
            && ([lindex $grp 1] eq "Fresnel"
            || [string is double -strict [lindex $grp 1]])} {
            set lst [string map {r "" / " "} [lindex $grp 0]]
            set var [lindex $RegGen [lindex $lst 0] 0 1]
            set val [lindex $RegGen [lindex $lst 1] 0 1]
            if {[llength $grp] == 2 && [lindex $grp 1] eq "Fresnel"} {
                vputs -i-5 "
                    Physics (RegionInterface= \"$var/$val\") \{
                        RayTraceBC (
                            Fresnel
                        )
                    \}"
            } elseif {[llength $grp] == 2
                && [string is double -strict [lindex $grp 1]]} {
                vputs -i-5 "
                    Physics (RegionInterface= \"$var/$val\") \{
                        RayTraceBC (
                            Reflectivity= [lindex $grp 1]
                        )
                    \}"
            } else {
                vputs -n -i-5 "
                    Physics (RegionInterface= \"$var/$val\") \{
                        RayTraceBC (
                            pmiModel= pmi_rtDiffuseBC (
                                * 0->Phong, 1->Lambert, 2->Random, 3->Gaussian"
                if {[lindex $grp 2] eq "Phong"} {
                    vputs -n -i-5 "
                                roughsurfacemodel= 0
                                phong_w= [lindex $grp 3]"
                } elseif {[lindex $grp 2] eq "Gaussian"} {
                    vputs -n -i-5 "
                                roughsurfacemodel= 3
                                gaussian_sigma= [lindex $grp 3]"
                } else {
                    vputs -n -i-5 "
                                roughsurfacemodel= 2
                                * 0 to 10000, -1->don't set
                                set_randomseed= [lindex $grp 3]"
                }
                if {[lindex $grp 1] eq "Fresnel"} {
                    vputs -n -i-5 "
                                surfacereflectivity= -1     * -1->Fresnel
                                surfacetransmittivity= -1   * -1->Fresnel"
                } else {
                    vputs -n -i-5 "
                                surfacereflectivity= [lindex $grp 1]
                                surfacetransmittivity=\
                                    [expr 1.-[lindex $grp 1]]"
                }
                vputs -i-5 "
                            )
                        )
                    \}"
            }
        }
    }
}

)!

Plot {
    *-- Doping and mole fraction profiles
    xMoleFraction
    DonorConcentration AcceptorConcentration DopingConcentration
    *-- Band Diagram
    ElectronAffinity BandGap EffectiveBandGap BandgapNarrowing
    ConductionBandEnergy ValenceBandEnergy eSchenkBGN hSchenkBGN
    eQuasiFermiEnergy hQuasiFermiEnergy eQuantumPotential hQuantumPotential
    *-- Carrier Densities
    eDensity hDensity IntrinsicDensity EffectiveIntrinsicDensity
    *-- Traps
    eTrappedCharge hTrappedCharge eInterfaceTrappedCharge
    hInterfaceTrappedCharge
    *-- Fields, Potentials and Charge distributions
    SpaceCharge ElectricField/Vector Potential
    *-- Currents and current components
    eCurrent/vector hCurrent/vector TotalCurrentDensity/vector
    current/vector CurrentPotential
    eMobility hMobility
    *-- Generation/Recombination
    srhRecombination RadiativeRecombination PMIRecombination
    AugerRecombination SurfaceRecombination TotalRecombination
    eGapStatesRecombination hGapStatesRecombination eLifeTime hLifeTime
    *-- Optics
    DielectricConstant RefractiveIndex OpticalGeneration OpticalIntensity
    AbsorbedPhotonDensity ComplexRefractiveIndex
    *-- Heat
    Temperature Thermalconductivity lHeatFlux
    eJouleHeat hJouleHeat ThomsonHeat PeltierHeat
    RecombinationHeat OpticalAbsorptionHeat TotalHeat
    *-- Nonlocal meshes
    NonLocal eBarrierTunneling hBarrierTunneling
}

*--- Refer to Appendix F: Tables 195, 196, 197, 198 in T-2022.03
CurrentPlot {
    !(

    if {$OptOnly && [regexp {\sRaytrace\s} $GopAttr]} {
        vputs -n -i-2 "
            pmi_OG1D"
    }
    if {[regexp {\{(Mono|Spec)Scaling\s} $VarVary]} {
        vputs -n -i-2 "
            ModelParameter= \"Optics/Excitation/Wavelength\""
    }

    # 'Dn' means 'n p'
    regsub -all {Dn\s+CP} $VV2Fld "n CP p CP Dop CP ni_eff CP" val
    regsub -all {Dn} $val {n p Dop ni_eff} val

    # Extract all fields from 'VV2Fld'
    set lst {PD Gop n p ni_eff UA UB US UP UD UT}
    foreach grp $val {
        if {[regexp {^p[^/]+$} [lindex $grp 0]]} {
            set lst [concat $lst [lrange $grp 1 end]]
        } else {
            foreach elm [lrange $grp 1 end] {
                set lst [concat $lst [string map {" CP" ""}\
                    [lrange $elm 1 end]]]
            }
        }
    }

    foreach elm [lsort -unique $lst] {
        if {[regexp {^(PD|Gop)$} $elm]} {
            if {![regexp {\s(OBAM|TMM|Raytrace|External)(\s|\})} $GopAttr]
                && !$LoadTDR} continue
            if {$elm eq "PD"} {
                vputs -n -i-5 "
                        [lindex [split $mfjProc::tabArr($elm) |] 0] (
                            Integrate (Semiconductor)
                            Integrate (EveryWhere)"
            } else {
                vputs -n -i-5 "
                        [lindex [split $mfjProc::tabArr($elm) |] 0] (
                            Integrate (Semiconductor)
                            Average (Semiconductor)"
            }

            # By default, integrate PD and Gop in each semicon region
            foreach grp $RegGen {
                if {$elm eq "Gop" && [lindex $grp 0 2] ne "Semiconductor"
                    || ($elm eq "PD" && [lindex $grp 0 0] eq "Gas")} {
                    continue
                }
                vputs -n -i-5 "
                            Integrate (Region= \"[lindex $grp 0 1]\")"
                foreach str $val {
                    if {[lindex $str 0] ne "r[lindex $grp 0 end]"} continue
                    foreach var [lrange $str 1 end] {
                        if {![regexp \\s$elm $var]} continue
                        if {[lindex $var 0] eq "Integrate"} continue
                        set tmp "[lindex $var 0] (Region= \"[lindex $grp 0 1]\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    }
                }
            }

            # Go through the rest 'p', 'rr' and 'pp'
            foreach str $val {
                if {![regexp \\s$elm $str]} continue
                if {[regexp {^p[^/]+$} [lindex $str 0]]} {
                    if {$Dim == 1} {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]]\
                            [format %g [expr $YMax/2.]])"
                    } else {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]])"
                    }
                    continue
                }
                foreach var [lrange $str 1 end] {
                    if {![regexp \\s$elm $var]} continue
                    if {[regexp {^r(\d+/\d+)$} [lindex $str 0]]} {
                        set idx [string map {r "" / " "} [lindex $str 0]]
                        set tmp [lindex $RegGen [lindex $idx 0] 0\
                            1]/[lindex $RegGen [lindex $idx 1] 0 1]
                        set tmp "[lindex $var 0] (RegionInterface= \"$tmp\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    } elseif {[regexp {^p[^/]+/[^/]+$} [lindex $str 0]]} {
                        set tmp [split [split [string range [lindex $str 0]\
                            1 end] _] /]
                        if {$Dim == 1} {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0] 0) ([lindex $tmp 1] $YMax)\]"
                        } else {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0]) ([lindex $tmp 1])\]"
                        }
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    }
                }
            }
            vputs -n -i-5 "
                        )"
        } elseif {[regexp {^(n|p|ni_eff)$} $elm]} {
            if {$OptOnly} continue
            vputs -n -i-5 "
                        [lindex [split $mfjProc::tabArr($elm) |] 0] ("

            # By default, monitor average e h ni_eff in each semicon region
            foreach grp $RegGen {
                if {[lindex $grp 0 2] ne "Semiconductor"} continue
                set flg true
                foreach str $val {
                    if {[lindex $str 0] ne "r[lindex $grp 0 end]"} continue
                    foreach var [lrange $str 1 end] {
                        if {![regexp \\s$elm $var]} continue
                        if {[lindex $var 0] eq "Average"} {
                            set flg false
                        }
                        set tmp "[lindex $var 0] (Region= \"[lindex $grp 0 1]\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    }
                }
                if {$flg} {
                    vputs -n -i-5 "
                            Average (Region= \"[lindex $grp 0 1]\")"
                }
            }

            # Go through the rest 'p', 'rr' and 'pp'
            foreach str $val {
                if {![regexp \\s$elm $str]} continue
                if {[regexp {^p[^/]+$} [lindex $str 0]]} {
                    if {$Dim == 1} {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]]\
                            [format %g [expr $YMax/2.]])"
                    } else {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]])"
                    }
                    continue
                }
                foreach var [lrange $str 1 end] {
                    if {![regexp \\s$elm $var]} continue
                    if {[regexp {^r(\d+/\d+)$} [lindex $str 0]]} {
                        set idx [string map {r "" / " "} [lindex $str 0]]
                        set tmp [lindex $RegGen [lindex $idx 0] 0\
                            1]/[lindex $RegGen [lindex $idx 1] 0 1]
                        set tmp "[lindex $var 0] (RegionInterface= \"$tmp\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    } elseif {[regexp {^p[^/]+/[^/]+$} [lindex $str 0]]} {
                        set tmp [split [split [string range [lindex $str 0]\
                            1 end] _] /]
                        if {$Dim == 1} {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0] 0) ([lindex $tmp 1] $YMax)\]"
                        } else {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0]) ([lindex $tmp 1])\]"
                        }
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    }
                }
            }
            vputs -n -i-5 "
                        )"
        } elseif {[regexp {^(UA|UB|US|UP|UD|UT)$} $elm]} {
            if {$OptOnly} continue
            vputs -n -i-5 "
                        [lindex [split $mfjProc::tabArr($elm) |] 0] (
                            Integrate (Semiconductor)"

            # By default, integrate recombination in each semiconductor region
            foreach grp $RegGen {
                if {[lindex $grp 0 2] ne "Semiconductor"} {
                    continue
                }
                vputs -n -i-5 "
                            Integrate (Region= \"[lindex $grp 0 1]\")"
                foreach str $val {
                    if {[lindex $str 0] ne "r[lindex $grp 0 end]"} continue
                    foreach var [lrange $str 1 end] {
                        if {![regexp \\s$elm $var]} continue
                        if {[lindex $var 0] eq "Integrate"} continue
                        set tmp "[lindex $var 0] (Region= \"[lindex $grp 0 1]\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    }
                }
            }

            # Go through the rest 'p', 'rr' and 'pp'
            foreach str $val {
                if {![regexp \\s$elm $str]} continue
                if {[regexp {^p[^/]+$} [lindex $str 0]]} {
                    if {$Dim == 1} {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]]\
                            [format %g [expr $YMax/2.]])"
                    } else {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]])"
                    }
                    continue
                }
                foreach var [lrange $str 1 end] {
                    if {![regexp \\s$elm $var]} continue
                    if {[regexp {^r(\d+/\d+)$} [lindex $str 0]]} {
                        set idx [string map {r "" / " "} [lindex $str 0]]
                        set tmp [lindex $RegGen [lindex $idx 0] 0\
                            1]/[lindex $RegGen [lindex $idx 1] 0 1]
                        set tmp "[lindex $var 0] (RegionInterface= \"$tmp\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    } elseif {[regexp {^p[^/]+/[^/]+$} [lindex $str 0]]} {
                        set tmp [split [split [string range [lindex $str 0]\
                            1 end] _] /]
                        if {$Dim == 1} {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0] 0) ([lindex $tmp 1] $YMax)\]"
                        } else {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0]) ([lindex $tmp 1])\]"
                        }
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    }
                }
            }
            vputs -n -i-5 "
                        )"
        } else {

            # No defaults, apply settings in 'VV2Fld'
            vputs -n -i-5 "
                        [lindex [split $mfjProc::tabArr($elm) |] 0] ("
            foreach str $val {
                if {![regexp \\s$elm $str]} continue
                if {[regexp {^p[^/]+$} [lindex $str 0]]} {
                    if {$Dim == 1} {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]]\
                            [format %g [expr $YMax/2.]])"
                    } else {
                        vputs -n -i-5 "
                            ([string map {p "" _ " "} [lindex $str 0]])"
                    }
                    continue
                }
                foreach var [lrange $str 1 end] {
                    if {![regexp \\s$elm $var]} {
                        continue
                    }
                    if {[regexp {^r(\d+)$} [lindex $str 0] -> idx]} {
                        if {$idx == [lindex $grp 0 end]
                            && [lindex $var 0] eq "Integrate"} {
                            continue
                        }
                        set tmp "[lindex $var 0] (Region= "
                        append tmp "\"[lindex $RegGen $idx 0 1]\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    } elseif {[regexp {^r(\d+/\d+)$} [lindex $str 0]]} {
                        set idx [string map {r "" / " "} [lindex $str 0]]
                            set tmp [lindex $RegGen [lindex $idx 0] 0\
                                1]/[lindex $RegGen [lindex $idx 1] 0 1]
                        set tmp "[lindex $var 0] (RegionInterface= \"$tmp\""
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    } else {
                        set tmp [split [split [string range [lindex $str 0]\
                            1 end] _] /]
                        if {$Dim == 1} {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0] 0) ([lindex $tmp 1] $YMax)\]"
                        } else {
                            set tmp "[lindex $var 0] (Window\[([lindex $tmp\
                                0]) ([lindex $tmp 1])\]"
                        }
                        if {[regexp $elm\\s+CP $var]} {
                            append tmp " Coordinates)"
                        } else {
                            append tmp ")"
                        }
                        vputs -n -i-5 "
                            $tmp"
                    }
                }
            }
            vputs -n -i-5 "
                        )"
        }
    }

    # Integrate tunnelling events in the involved regions
    set lst [list]
    foreach grp $IntfTun {
        set lst [concat $lst [string map {r "" / " "} [lindex $grp 0]]]
    }
    if {[llength $lst]} {
        vputs -n -i-5 "
                        eBarrierTunneling ("
    }
    foreach elm [lsort -unique $lst] {
        vputs -n -i-5 "
                            Integrate (Region= \"[lindex $RegGen $elm 0 1]\")"
    }
    if {[llength $lst]} {
        vputs -n -i-5 "
                        )"
    }

    # By default, integrate surface recombination along region interfaces
    set flg false
    foreach grp $IntfSRV {
        if {![string is double -strict [lindex $grp 2]]} continue
        set lst [string map {r "" / " "} [lindex $grp 0]]
        set intf [lindex $RegGen [lindex $lst 0] 0 1]/[lindex\
            $RegGen [lindex $lst 1] 0 1]
        if {!$flg} {
            set flg true
            vputs -n -i-5 "
                        SurfaceRecombination ("
        }
        vputs -n -i-5 "
                            Integrate (RegionInterface= \"$intf\")"
    }
    if {$flg} {
        vputs -n -i-5 "
                        )"
    }

    )!
}

*--- Refer to Table 214
!(

# Define global physics options
regexp {\{Other\s+([^\}]+)} $DfltAttr -> lst
vputs -n -i-1 "
    Physics \{

        # Default physics for all regions: Constant mobility,
        # no bandgap narrowing with Fermi statistics
        Temperature= [expr [lindex $lst 0]+273.15] * K
        Thermionic * Thermionic emission over interfaces
        Fermi * Enable Fermi statistics

        # HighFieldSaturation not working with the Schenk model
        # Enable HighFieldSaturation will cause unknown error
        Mobility (HighFieldSaturation)
        EffectiveIntrinsicDensity (NoBandGapNarrowing)\n"

if {!$OptOnly && [regexp {\s[ceh]T\s} $IntfTun]} {
    set idx 0
    foreach grp $IntfTun {
        if {[regexp {^[ceh]T$} [lindex $grp 1]]} {
            array unset arr
            readTT arr [lindex $grp 2]
            set str "Band2Band= [lindex $grp 5]"
            if {$arr(PModel) eq "WKB"} {
                if {[string index $arr(TwoBand) 0] ne "-"} {
                    append str " TwoBand"
                }
                if {[string index $arr(Multivalley) 0] ne "-"} {
                    append str " Multivalley"
                }
            }
        }
        if {[regexp {^[eh]T$} [lindex $grp 1]]} {
            vputs -n -i-3 "
                [string index [lindex $grp 1] 0]BarrierTunneling\
                    \"NLM$idx\" ($str)\n"
        } elseif {[regexp {^cT$} [lindex $grp 1]]} {
            vputs -n -i-3 "
                eBarrierTunneling \"NLM$idx\" ($str)
                hBarrierTunneling \"NLM$idx\" ($str)\n"
        }
        incr idx
    }
}

if {[regexp {\{(Mono|Spec)Scaling\s} $VarVary]} {
    vputs -n -i-1 "
        * Use Unified Interface for optical generation
        * Excitation is common to TMM, OptBeam, and FromFile
        * 2D: Theta is the angle with the positive y-axis
        * 3D: Theta is the angle with the positive z-axis
        *     Phi is the angle with the positive x-axis in xy plane
        * Refer to Table 321 in T-2022.03
        Optics ("


    # 'OpticalGeneration' subsection: three methods are supported
    # for AbsorbedPhotonDensity. QuantumYield determines final OG
    # FCA calculation is enabled only for pure optical simulation
    vputs -n -i-1 "
            OpticalGeneration ("
    if {$OptOnly} {
        vputs -n -i-1 "
                QuantumYield (EffectiveAbsorption)"
    } else {
        vputs -n -i-1 "
                QuantumYield (Unity)"
    }
    if {[regexp {\{MonoScaling\s} $VarVary]} {
        vputs -n -i-1 "
                ComputeFromMonochromaticSource (Scaling= 0)"
    }
    if {[regexp {\{SpecScaling\s} $VarVary]} {
        if {$LoadTDR} {
            vputs -n -i-1 "
                ReadFromFile (
                    DatasetName= AbsorbedPhotonDensity
                    Scaling= 0
                )"
        } else {
            vputs -n -i-1 "
                ComputeFromSpectrum (Scaling= 0)"
        }
    }
    vputs -n -i-1 "
            ) * end of OpticalGeneration"

    # 'Excitation' subsection
    regexp {\{Monochromatic\s+(\S+)\s+([^\s\}]+)} $GopAttr -> var val
    vputs -n -i-1 "
            Excitation (
                Polarization= 0.5 * Unpolarized light
                Wavelength= $var * um"
    regexp {\{Incidence\s+(\S+)\s+(\S+)\s+([^\s\}]+)} $GopAttr -> str var tmp
    vputs -n -i-1 "
                Intensity= [expr $val*(1.-$str)] * W/cm^2"
    if {$LPD == -1} {
        set var [expr 270.+$var]
        set tmp [expr 180.+$tmp]
    } else {
        set var [expr 90.+$var]
    }
    if {$Dim == 3} {
        vputs -n -i-1 "
                Theta= $var * deg
                Phi= $tmp * deg"
    } else {
        vputs -n -i-1 "
                Theta= $var * deg"
    }

    # Every attribute has a number
    set idx 0
    foreach grp $GopAttr {
        if {[regexp {^(OBAM|TMM|Raytrace|External)$} [lindex $grp 1]]} {
            if {[regexp {^r(\d+)/(\d+)$} [lindex $grp 0] -> val tmp]} {
                set lst [rr2pp $RegGen $val $tmp]
            } else {
                set lst [split [split [string range [lindex $grp 0]\
                    1 end] _] /]
            }
            vputs -n -i-1 "
                Window (\"W$idx\") ("
            if {$Dim == 3} {
                vputs -n -i-1 "
                    Origin= ([lindex $lst 0 0], [expr ([lindex $lst 0 1]\
                        +[lindex $lst 1 1])*0.5], [expr ([lindex $lst 0 2]\
                        +[lindex $lst 1 2])*0.5])
                    XDirection= (0, 0, 1) * Redefine 'x' as 'z'
                    Rectangle (
                        Dx= [expr abs([lindex $lst 1 2]-[lindex $lst 0 2])]
                        Dy= [expr abs([lindex $lst 1 1]-[lindex $lst 0 1])]
                    )"
            } elseif {$Dim == 2} {
                vputs -n -i-1 "
                    Origin= ([lindex $lst 0 0], [expr ([lindex $lst 0 1]\
                        +[lindex $lst 1 1])*0.5])
                    XDirection= (0, 1) * Redefine 'x' as 'y'
                    Line (
                        Dx= [expr abs([lindex $lst 1 1]-[lindex $lst 0 1])]
                    )"
            } else {
                vputs -n -i-1 "
                    Origin= ([lindex $lst 0 0], [expr $YMax*0.5])
                    XDirection= (0, 1) * Redefine 'x' as 'y'
                    Line (
                        Dx= $YMax
                    )"
            }
            vputs -n -i-1 "
                )"
            incr idx
        }
    }
    vputs -n -i-1 "
            ) * end of Excitation"

    # 'OpticalSolver' subsection
    if {[regexp {\s(OBAM|TMM|Raytrace|External)(\s|\})} $GopAttr]} {
        vputs -n -i-1 "
            OpticalSolver ("
    }
    if {[regexp {\sOBAM\}} $GopAttr]} {
        vputs -n -i-1 "
                OptBeam ("
        set idx 0
        foreach grp $GopAttr {
            if {[lindex $grp 1] eq "OBAM"} {
                vputs -n -i-1 "
                    LayerStackExtraction (
                        WindowName= \"W$idx\"
                        Mode= RegionWise * Default
                    )"
                incr idx
            }
        }
        vputs -n -i-1 "
                )"
    } elseif {[regexp {\sTMM\s} $GopAttr]} {
        vputs -n -i-1 "
                TMM (
                    IntensityPattern= Envelope
                    PropagationDirection= Refractive
                    NodesPerWavelength= 20"
        set idx 0
        foreach grp $GopAttr {
            if {[lindex $grp 1] eq "TMM"} {
                vputs -n -i-1 "
                    LayerStackExtraction (
                        WindowName= \"W$idx\"
                        WindowPosition= Center
                        Mode= RegionWise * Default"
                if {[llength $grp] == 3} {
                    vputs -n -i-1 "
                        Medium (
                            Location= bottom
                            Material= \"[lindex $grp 2]\"
                        )"
                } else {
                    vputs -n -i-1 "
                        Medium (
                            Location= bottom
                            RefractiveIndex= [lindex $grp 2]
                            ExtinctionCoefficient= [lindex $grp 3]
                        )"
                }
                vputs -n -i-1 "
                    )"
                incr idx
            }
        }
        vputs -n -i-1 "
                )"
    } elseif {[regexp {\sExternal\s} $GopAttr]} {
        vputs -n -i-1 "
                FromFile (
                    ProfileIndex= 0
                    IdentifyingParameter= (\"Wavelength\")
                    DatasetName= AbsorbedPhotonDensity
                    SpectralInterpolation= PiecewiseConstant
                )"
    } elseif {[regexp {\sRaytrace\s+(\S+)\s+(\S+)\s+(\S+)\s+([^\s\}]+)}\
        $GopAttr -> val str var tmp]} {
        vputs -n -i-1 "

                *--- Refer to Table 259 in T-2022.03
                RayTracing (
                    * NonSemiconductorAbsorption
                    * OmitReflectedRays
                    * OmitWeakerRays
                    PolarizationVector= Random
                    CompactMemoryOption
                    PlotInterfaceFlux
                    WeightedOpticalGeneration * from element to vertices
                    MinIntensity= $var * 1e-4
                    DepthLimit= $tmp * 100000"
        if {$str eq "MonteCarlo"} {
            vputs -n -i-1 "
                    MonteCarlo"
        } else {
            set str AutoPopulate
            vputs -n -i-1 "
                    RedistributeStoppedRays"
        }
        set idx 0
        foreach grp $GopAttr {
            if {[lindex $grp 1] eq "Raytrace"} {
                vputs -n -i-1 "
                    RayDistribution (
                        WindowName= \"W$idx\"
                        Mode= $str * Equidistant, MonteCarlo, AutoPopulate
                        NumberOfRays= $val
                    )"
                incr idx
            }
        }
        vputs -n -i-1 "
                )"
    } else {

        # Other optical solver
    }
    if {[regexp {\s(OBAM|TMM|Raytrace|External)(\s|\})} $GopAttr]} {
        vputs -n -i-1 "
            ) * end of OpticalSolver
            ComplexRefractiveIndex (
                WavelengthDep (real imag)"
        if {$OptOnly} {
            vputs -n -i-1 "
                CarrierDep (imag)"
        }
        vputs -n -i-1 "
            )"
    }

    vputs -n -i-1 "
        ) * end of Optics"
}
vputs -i-1 "
    \} * end of global physics"

# Redefine physics options for individual semiconductor region
if {!$OptOnly} {
    foreach grp $RegGen {
        if {[lindex $grp 0 2] ne "Semiconductor"} continue
        vputs -n -i-3 "
            Physics (Region= \"[lindex $grp 0 1]\") \{"

        # Enable incomplet ionization for Al in a Si region
        set flg false
        if {[lindex $grp 0 0] eq "Silicon"} {
            foreach elm $RegFld {
                if {[lindex $elm 0] eq "r[lindex $grp 0 end]"} {
                    if {[regexp {\{AluminumActiveConcentration\s} $elm]} {
                        set flg true
                    }
                    break
                }
            }
            foreach elm $RegIntfFld {
                if {[lindex $elm 0] eq "r[lindex $grp 0 end]"} {
                    if {[regexp {\{AluminumActiveConcentration\s} $elm]} {
                        set flg true
                    }
                }
            }
            if {$flg} {
                vputs -n -i-4 "
                    IncompleteIonization (
                        Dopants= \"AluminumActiveConcentration\"
                    )"
            }
        }

        # Check trap settings in 'RegIntfTrap'
        set str ""
        foreach elm $RegIntfTrap {
            if {[lindex $elm 0] ne "r[lindex $grp 0 end]"} {
                continue
            }
            foreach var [lrange $elm 1 end] {

                # Restore the list back to an array
                array unset arr
                foreach val [lrange $var 1 end] {
                    set arr([lindex $val 0]) [lindex $val 1]
                }
                lappend str "($arr(TrapNat) $arr(TrapRef)"
                lappend str "SFactor= \"[lindex $var 0]\""
                if {[info exists arr(Reference)]} {
                    lappend str "Reference= $arr(Reference)"
                }
                if {$arr(TrapDist) eq "Level"} {
                    lappend str "Level EnergyMid= $arr(EnergyMid)"
                } elseif {$arr(TrapDist) eq "Table"} {
                    lappend str "Table= ($arr(Table))"
                } else {
                    lappend str "$arr(TrapDist) EnergyMid= $arr(EnergyMid)"
                    lappend str "EnergySig= $arr(EnergySig)"
                }
                lappend str "eXsection= $arr(eXsection)"
                lappend str "hXsection= $arr(hXsection))"
            }

        }

        # Check trap settings in 'IntfTun'
        set lst [list]
        set val 0
        foreach elm $IntfTun {
            set idx [string map {r "" / " "} [lindex $elm 0]]
            if {![regexp {^TAT$} [lindex $elm 1]]
                || [lindex $idx 1] != [lindex $grp 0 end]} {
                incr val
                continue
            }
            array unset arr
            readTT arr [lindex $elm 2]
            set len [llength $arr(TrapNat)]
            for {set idx 0} {$idx < $len} {incr idx} {
                set tmp [lindex $arr(TrapRef) $idx]
                lappend lst "([lindex $arr(TrapNat) $idx] $tmp"
                if {[info exists arr(Reference)]} {
                    lappend lst "Reference= [lindex $arr(Reference) $idx]"
                }
                if {[info exists arr(TrapVolume)]} {
                    lappend lst "TrapVolume= [lindex $arr(TrapVolume) $idx]"
                    lappend lst "PhononEnergy= [lindex $arr(PhononEnergy) $idx]"
                }
                if {[info exists arr(Conc)]} {
                    set tmp [format %g [expr 1.*[lindex $arr(Conc) $idx]\
                        *[lindex $elm 4]]]
                }
                if {[lindex $arr(TrapDist) $idx] eq "Level"} {
                    lappend lst "EnergyMid= [lindex $arr(EnergyMid) $idx]"
                } elseif {[lindex $arr(TrapDist) $idx] eq "Table"} {
                    lappend lst "Table= ([lindex $arr(Table) $idx])"
                } else {
                    lappend lst "[lindex $arr(TrapDist) $idx] Conc= $tmp"
                    lappend lst "EnergyMid= [lindex $arr(EnergyMid) $idx]"
                    lappend lst "EnergySig= [lindex $arr(EnergySig) $idx]"
                }
                if {[lindex $elm 5] eq "c"} {
                    lappend lst "eBarrierTunneling (NonLocal= \"NLM$val\")"
                    lappend lst "hBarrierTunneling (NonLocal= \"NLM$val\")"
                } else {
                    lappend lst "[lindex $elm 5]BarrierTunneling (NonLocal=\
                        \"NLM$val\")"
                }
                set tmp [format %g [lindex $arr(eXsection) $idx]]
                lappend lst "eXsection= $tmp"
                set tmp [format %g [lindex $arr(hXsection) $idx]]
                lappend lst "hXsection= $tmp)"
            }
            incr val
        }

        # Parse mu, BGN, Aug, Rad, SRH, Trap in 'ModPar'
        # Set a flag for trap
        set flg false
        foreach elm $ModPar {
            if {"r[lindex $grp 0 end]" ne [lindex $elm 0]} continue
            if {[regexp {\{(mu(\s+[^\}]+)+)\}} $elm -> var]} {
                if {![string is double -strict [lindex $var 1]]} {
                    vputs -n -i-5 "
                        Mobility (DopingDependence ([lindex $var 1]))"
                }
            } else {
                if {[lindex $grp 0 0] eq "Silicon"} {
                    vputs -n -i-5 "
                        Mobility (
                            PhuMob (Phosphorus) HighFieldSaturation
                        )"
                }
            }
            if {[regexp {\{(BGN(\s+[^\}]+)+)\}} $elm -> var]} {
                vputs -n -i-5 "
                        EffectiveIntrinsicDensity (
                            BandGapNarrowing([lindex $var 1])
                        )"
            } else {
                if {[lindex $grp 0 0] eq "Silicon"} {

                    # Set Schenk model for Si and enable LocalModelOnly
                    # to suppress the quantization corrections
                    # Turn off everything in density gradient model
                    # except band-edge shift
                    # vputs -n -i-5 "
                        # eQuantumPotential (
                            # LocalModel= SchenkBGN_elec LocalModelOnly
                        # )
                        # hQuantumPotential (
                            # LocalModel= SchenkBGN_hole LocalModelOnly
                        # )"

                    # Use Schenk BGN model yet assuming no injection
                    vputs -n -i-5 "
                        EffectiveIntrinsicDensity (
                            BandGapNarrowing (TableBGN) NoFermi
                        )"
                }
            }

            # Default Auger model is Niewelt for a Si region
            set val [list]
            set fPR 0
            if {[regexp {\sAug} $elm]} {
                lappend val Auger
            } elseif {[regexp {\{(Aug(\s+[^\}]+)+)\}} $elm -> var]} {
                if {[string is double -strict [lindex $var 1]]} {
                    lappend val Auger
                } elseif {[lindex $var 1] ne "!"} {
                    lappend val pmi_Aug_[lindex $var 1]
                    if {[string is double -strict [lindex $var 2]]} {
                        set fPR [lindex $var 2]
                    }
                }
            } else {
                if {[lindex $grp 0 0] eq "Silicon"} {
                    lappend val pmi_Aug_Niewelt
                }
            }

            if {![regexp {^pmi_Aug} [lindex $val end]] || $fPR == 1} {
                if {[regexp {\sRad} $elm]} {
                    lappend val Radiative
                } elseif {[regexp {\{(Rad(\s+[^\}]+)+)\}} $elm -> var]} {
                    if {[lindex $var 1] ne "!"} {
                        lappend val Radiative
                    }
                } else {
                    if {[lindex $grp 0 0] eq "Silicon"} {
                        lappend val Radiative
                    }
                }
            }
            if {[regexp {\{(SRH(\s+[^\}]+)+)\}} $elm -> var]} {
                if {[lindex $var 1] ne "!"} {
                    lappend val SRH
                }
            } else {

                # SRH should be enabled by default
                lappend val SRH
            }
            if {[regexp {\{(Trap(\s+[^\}]+)+)\}} $elm -> var]} {

                # Default trap ratios are 1
                if {[llength $var] == 2} {
                    set var [concat $var 1 1 1]
                } elseif {[llength $var] == 3} {
                    set var [concat $var 1 1]
                } elseif {[llength $var] == 4} {
                    lappend var 1
                }
                set flg true
                vputs -n -i-5 "
                        Traps ("
                array unset arr
                readTT arr [lindex $var 1]
                set len [llength $arr(TrapNat)]
                for {set idx 0} {$idx < $len} {incr idx} {
                    set tmp [lindex $arr(TrapRef) $idx]
                    vputs -n -i-5 "
                            ([lindex $arr(TrapNat) $idx] $tmp"
                    if {[info exists arr(reference)]} {
                        vputs -n -i-5 "
                            Reference= [lindex $arr(Reference) $idx]"
                    }
                    if {[lindex $arr(TrapDist) $idx] eq "Level"} {
                        vputs -n -i-5 "
                            Level Conc= [format %g [expr [lindex $var 2]\
                                *[lindex $arr(Conc) $idx]]]
                            EnergyMid= [lindex $arr(EnergyMid) $idx]"
                    } elseif {[lindex $arr(TrapDist) $idx] eq "Table"} {
                        vputs -n -i-5 "
                            Table= ([lindex $arr(Table) $idx])"
                    } else {
                        vputs -n -i-5 "
                            [lindex $arr(TrapDist) $idx] Conc= [format %g [expr\
                                [lindex $var 2]*[lindex $arr(Conc) $idx]]]
                            EnergyMid= [lindex $arr(EnergyMid) $idx]
                            EnergySig= [lindex $arr(EnergySig) $idx]"
                    }
                    vputs -n -i-5 "
                            eXsection= [format %g [expr [lindex $var 3]\
                                *[lindex $arr(eXsection) $idx]]]
                            hXsection= [format %g [expr [lindex $var 4]\
                                *[lindex $arr(hXsection) $idx]]])"
                }

                # Check trap settings in 'RegIntfTrap'
                if {[llength $str]} {
                    vputs -n -i2 \n[join $str \n]
                }

                # Check trap settings in 'IntfTun'
                if {[llength $lst]} {
                    vputs -n -i2 \n[join $lst \n]
                }
                vputs -n -i-5 "
                        )"
            }
            if {$val ne ""} {
                vputs -n -i-4 "
                    Recombination ($val)"
            }
            break
        }

        # Check trap settings in 'RegIntfTrap' and 'IntfTun'
        if {!$flg && ([llength $str] || [llength $lst])} {
            vputs -n -i-3 "
                Traps ("
            if {[llength $str]} {
                vputs -n -i2 \n[join $str \n]
            }
            if {[llength $lst]} {
                vputs -n -i2 \n[join $lst \n]
            }
            vputs -n -i-3 "
                )"
        }
        vputs -n -i-3 "
            \}\n"
    }

    # Enable interface recombination or traps
    foreach grp $IntfSRV {
        set lst [string map {r "" / " "} [lindex $grp 0]]
        set var [lindex $RegGen [lindex $lst 0] 0 1]
        set val [lindex $RegGen [lindex $lst 1] 0 1]
        vputs -n -i-3 "
            Physics (RegionInterface= \"$var/$val\") \{
                Traps (
                    (FixedCharge Conc= [lindex $grp 1])"
        foreach elm $IntfTrap {
            if {[lindex $grp 0] ne [lindex $elm 0]
                && "r[lindex $lst 1]/[lindex $lst 0]" ne [lindex $elm 0]} {
                continue
            }
            array unset arr
            readTT arr [lindex $elm 1]
            set len [llength $arr(TrapNat)]
            for {set idx 0} {$idx < $len} {incr idx} {
                set tmp [lindex $arr(TrapRef) $idx]
                vputs -n -i-3 "
                        ([lindex $arr(TrapNat) $idx] $tmp"
                if {[info exists arr(Reference)]} {
                    vputs -n -i-4 "
                        Reference= $arr(Reference)"
                }
                if {[lindex $arr(TrapDist) $idx] eq "Level"} {
                    vputs -n -i-4 "
                        Level Conc= [format %g [expr [lindex $elm 2]\
                            *[lindex $arr(Conc) $idx]]]
                        EnergyMid= [lindex $arr(EnergyMid) $idx]"
                } elseif {[lindex $arr(TrapDist) $idx] eq "Table"} {
                    vputs -n -i-4 "
                        Table= ([lindex $arr(Table) $idx])"
                } else {
                    vputs -n -i-4 "
                        [lindex $arr(TrapDist) $idx] Conc= [format %g [expr\
                            [lindex $elm 2]*[lindex $arr(Conc) $idx]]]
                        EnergyMid= [lindex $arr(EnergyMid) $idx]
                        EnergySig= [lindex $arr(EnergySig) $idx]"
                }
                if {[lindex $RegGen [lindex $lst 0] 0 2] eq "Semiconductor"
                    && [lindex $RegGen [lindex $lst 1] 0 2]
                    eq "Semiconductor" && [info exists Arr(Region)]} {
                    vputs -n -i-4 "
                        Region= \"[lindex $RegGen [lindex $lst\
                            [lindex $Arr(Region) $idx]] 0 1]\""
                }
                vputs -n -i-4 "
                        eXsection= [format %g [expr [lindex $elm 3]\
                            *[lindex $arr(eXsection) $idx]]]
                        hXsection= [format %g [expr [lindex $elm 4]\
                            *[lindex $arr(hXsection) $idx]]])"
            }
            break
        }
        vputs -n -i-4 "
                    )"

        if {([string is double -strict [lindex $grp 2]] && [lindex $grp 2] > 0)
            || ([string is double -strict [lindex $grp 3]]
            && [lindex $grp 3] > 0)} {
            vputs -n -i-3 "
                Recombination (SurfaceSRH)"
        }
        vputs -n -i-3 "
            \}\n"
    }

    # In case trap interfaces are not visited previously
    foreach elm $IntfTrap {
        regsub {r(\d+)/(\d+)} [lindex $elm 0] {r\2/\1} str
        if {[regexp \\\{([lindex $elm 0]|$str)\\s $IntfSRV} continue
        set lst [string map {r "" / " "} [lindex $elm 0]]
        set var [lindex $RegGen [lindex $lst 0] 0 1]
        set val [lindex $RegGen [lindex $lst 1] 0 1]
        vputs -n -i-3 "
            Physics (RegionInterface= \"$var/$val\") \{
                Traps ("
        array unset arr
        readTT arr [lindex $elm 1]
        set len [llength $arr(TrapNat)]
        for {set idx 0} {$idx < $len} {incr idx} {
            vputs -n -i-3 "
                    ([lindex $arr(TrapNat) $idx] [lindex $arr(TrapRef) $idx]
                    eXsection= [format %g [expr [lindex $elm 3]\
                        *[lindex $arr(eXsection) $idx]]]
                    hXsection= [format %g [expr [lindex $elm 4]\
                        *[lindex $arr(hXsection) $idx]]]"
            if {[info exists arr(Reference)]} {
                vputs -n -i-3 "
                    Reference= $arr(Reference)"
            }
            if {[lindex $arr(TrapDist) $idx] eq "Level"} {
                vputs -n -i-3 "
                    Level Conc= [format %g [expr [lindex $elm 2]\
                        *[lindex $arr(Conc) $idx]]]
                    EnergyMid= [lindex $arr(EnergyMid) $idx]"
            } elseif {[lindex $arr(TrapDist) $idx] eq "Table"} {
                vputs -n -i-3 "
                    Table= ([lindex $arr(Table) $idx])"
            } else {
                vputs -n -i-3 "
                    [lindex $arr(TrapDist) $idx] Conc= [format %g [expr\
                        [lindex $elm 2]*[lindex $arr(Conc) $idx]]]
                    EnergyMid= [lindex $arr(EnergyMid) $idx]
                    EnergySig= [lindex $arr(EnergySig) $idx]"
            }
            if {[lindex $RegGen [lindex $lst 0] 0 2] eq "Semiconductor"
                && [lindex $RegGen [lindex $lst 1] 0 2]
                eq "Semiconductor" && [info exists Arr(Region)]} {
                vputs -n -i-3 "
                    Region= \"[lindex $RegGen [lindex $lst\
                        [lindex $Arr(Region) $idx]] 0 1]\""
            }
            vputs -n -i-3 "
                    )"
        }
        vputs -n -i-3 "
                )
            \}\n"
    }
}

)!

*--- Refer to Table 211 in T-2022.03
Math {
    WallClock
    CoordinateSystem {AsIs}
    * CNormPrint
    ExitOnFailure
    Extrapolate
    Derivatives
    RelErrControl
    NotDamped= 50
    RhsFactor= 1e50

    * Direct solver PARDISO and iterative solver ILS support parallelization
    * Method=Blocked SubMethod=Super 1D, 2D default solvers for Coupled
    * ACMethod=Blocked ACSubMethod=Super 1D, 2D default solvers for AC analysis
    * Linear solvers (ParDiSo, ILS, Super), Blocked (block decomposition)
    Method= Blocked
    SubMethod= PARDISO
    CurrentPlot (
        IntegrationUnit= cm
    )
    !(

    vputs -n -i-1 "
        TrapDLN= [lindex $mfjDfltSet 6]
        Traps (Damping= 100) * Default: 10
        Number_of_Threads= [lindex $mfjDfltSet end-4]
        StackSize= 20000000 * Set stacksze as 20 MB

        * Increase the value of Digits. Possible values are Digits=15 for
        * ExtendedPrecision(128) and Digits=25 for ExtendedPrecision(256).
        * Decrease the value of RhsMin. Possible values are RhsMin=1e-15 for
        * ExtendedPrecision(128) and RhsMin=1e-25 for ExtendedPrecision(256)
        * Slightly increase Iterations, for example, from 15 to 20."

    regexp {\{Numeric\s+([^\}]+)} $DfltAttr -> lst
    set idx [lsearch [lindex $mfjDfltSet end-3] [lindex $lst 0]]
    if {$idx == -1} {
        error "'[lindex $lst 0]' not found in '[lindex $mfjDfltSet end-3]'!"
    }
    vputs -n -i-1 "
        Digits= [lindex $mfjDfltSet end-2 $idx]
        RhsMin= [lindex $mfjDfltSet end-1 $idx]
        Iterations= [lindex $mfjDfltSet end $idx]"
    if {[lindex $lst 0] == 64} {
        vputs -n -i-2 "
            * CheckRhsAfterUpdate * May help improve convergence"
    } elseif {[lindex $lst 0] == 80} {
        vputs -n -i-2 "
            ExtendedPrecision"
    } else {
        vputs -n -i-2 "
            ExtendedPrecision([lindex $lst 0])"
    }
    if {$Dim == 2 && $Cylind} {
        vputs -n -i-2 "
            Cylindrical (yAxis= 0)"
    }
    if {[regexp {c\d\s+Frequency\s} $VarVary]} {
        vputs -n -i-2 "
            ImplicitACSystem"
    }

    if {!$OptOnly && [regexp {\s(c|e|h|TA)T\s} $IntfTun]} {
        set idx 0
        foreach grp $IntfTun {
            if {[regexp {^(c|e|h|TA)T$} [lindex $grp 1]]} {
                set lst [string map {r "" / " "} [lindex $grp 0]]
                set var [lindex $RegGen [lindex $lst 0] 0 1]
                set val [lindex $RegGen [lindex $lst 1] 0 1]
                vputs -n -i-4 "
                    NonLocal \"NLM$idx\" (
                        RegionInterface= \"$var/$val\"
                        Length= [expr [lindex $grp 3]*1e-4] * cm"
                if {[lindex $grp 1] ne "TAT"} {
                    vputs -n -i-4 "
                        Permeation= [expr [lindex $grp 4]*1e-4] * cm"
                }
                array unset arr
                readTT arr [lindex $grp 2]
                foreach elm {Discretization Digits EnergyResolution MaxAngle} {
                    if {![info exists arr($elm)]} continue
                    vputs -n -i-4 "
                        $elm= $arr($elm)"
                }
                if {![catch {set str [rr2pp $RegGen [lindex $lst 0]\
                    [lindex $lst 1] !Intf]}]} {
                    vputs -n -i-4 "
                        Direction= ($str)"
                }
                if {[info exists arr(Transparent)]} {
                    if {$arr(Transparent) eq "- -"} {
                        error "at least one region is transparent!"
                    }
                    if {$arr(Transparent) eq "- +"} {
                        vputs -n -i-5 "
                            -Transparent (Region= \"$var\")"
                    }
                    if {$arr(Transparent) eq "+ -"} {
                        vputs -n -i-5 "
                            -Transparent (Region= \"$val\")"
                    }
                }
                foreach elm {Permeable Endpoint Refined} {
                    if {![info exists arr($elm)]} continue
                    set str ""
                    if {$arr($elm) eq "- -"} {
                        set str "Region= \"$var\" Region= \"$val\""
                    }
                    if {$arr($elm) eq "- +"} {
                        set str "Region= \"$var\""
                    }
                    if {$arr($elm) eq "+ -"} {
                        set str "Region= \"$val\""
                    }
                    if {$str eq ""} continue
                    vputs -n -i-4 "
                        -$elm ($str)"
                }
                vputs -n -i-4 "
                    )"
            }
            incr idx
        }
    }

    )!
}

!(

vputs -n -i-1 "
    *--- Refer to Table 337 in T-2022.03
    Solve \{
        System(\"rm -f *n@node@_des.plt\")\n"

if {$OptOnly} {

    # Optical simulation only
    set var Optics
    if {[regexp {\sRaytrace\s} $GopAttr]} {
        vputs -n -i-2 "
            System(\"rm -f n@node@_OG1D.plx\")\n"
    }
} else {

    # Thermal equilibrium condition
    # Schenk implementation in Sentaurus is bad.
    # Eg_eff and nieff do not change and Schenk doesn't work with QSSPC
    # set var {Coupled {Poisson Electron Hole
        # eQuantumPotential hQuantumPotential}}
    set var {Coupled {Poisson Electron Hole}}
    vputs -n -i-1 "
        Coupled (LineSearchDamping=0.01 Iterations= 5000) \{Poisson\}\n
        NewCurrentPrefix= \"eqm_\"
        Coupled (Iterations= 100) \{Poisson Electron Hole\}
        Plot (FilePrefix= \"$SimArr(EtcDir)/n@node@_Eqm\")\n"
}

# Go through 'VarVary'
set idx 0
array unset arr
array set arr [array get ValArr]
foreach grp $VarVary {
    if {[regexp {^c\d$} [lindex $grp 0]]} {

        # Get the contact initial value and update
        set val $arr([lindex $grp 0])
        if {[string is double -strict [lindex $grp 1]]} {
            if {[lindex $val 1] != [lindex $grp 1]} {
                set arr([lindex $grp 0])\
                    [list [lindex $val 0] [lindex $grp 1]]
                if {[lindex $grp 2]} {
                    set str "CurrentPlot (Time= (range=(0 1);\
                        range= (0 1) intervals= [lindex $grp 2]))"

                    # By default save snapshots at 0 and 1
                    set lst [list 0 1]
                    foreach elm [lrange $grp 3 end] {
                        lappend lst [expr 1.*($elm-[lindex $val 1])\
                            /([lindex $grp 1]-[lindex $val 1])]
                    }
                    set lst [lsort -real $lst]
                    append str "\n[string repeat $mfjProc::arr(Tab) 6]Plot\
                        (FilePrefix= \"$SimArr(EtcDir)/n@node@_v$idx\"\
                        Time= ([join $lst {; }]) noOverwrite)"
                } else {
                    set str "CurrentPlot (Time= (-1))"
                }
                vputs -i-4 "
                    NewCurrentPrefix= \"v${idx}_\"
                    Quasistationary (
                        InitialStep= 1 MaxStep= 1 MinStep= 1e-100
                        Increment= 2 Decrement= 10 DoZero
                        Goal \{
                            Name= \"[lindex $grp 0]\"
                            [lindex $val 0]= [lindex $grp 1]
                        \}
                    ) \{$var
                        $str
                    \}\n"

                # Remove ac analysis afterwards
                if {[regexp {^ACCoupled} $var]} {
                    set var "Coupled \{Poisson Electron Hole\}"
                }
            }
        } else {
            if {[lindex $grp 1] eq "Frequency"} {

                # C-V simulation based on small AC signals (Table 338)
                set var "ACCoupled (StartFrequency= [lindex $grp 2]\
                    EndFrequency= [lindex $grp 3]\
                    NumberOfPoints= [lindex $grp 4] Decade)\
                    \{Poisson Electron Hole\}"

                # Make sure the next step is a voltage varying step
                set tmp [lindex $VarVary [expr $idx+1]]
                if {![regexp {^c\d$} [lindex $tmp 0]]
                    || ![string is double -strict [lindex $tmp 1]]} {
                    error "'$tmp' not a voltage varying step!"
                }
                set val $arr([lindex $tmp 0])
                if {[lindex $val 0] ne "Voltage"} {
                    error "'[lindex $tmp 0]' not a voltage contact!"
                }
            } else {

                # Update the contact type if required. The initial value
                # after type change depends on the previous step
                if {[lindex $grp 1] ne [lindex $val 0]} {
                    set arr([lindex $grp 0]) [lindex $grp 1]
                    vputs -i-5 "
                        Set (\"[lindex $grp 0]\" mode [lindex $grp 1])\n"
                }
            }
        }
    } elseif {[regexp {^(Spec|Mono)Scaling$} [lindex $grp 0]]} {

        # Get the initial intensity scaling value and update
        set val $arr([lindex $grp 0])
        if {$val != [lindex $grp 1]} {
            set arr([lindex $grp 0]) [lindex $grp 1]
            if {[lindex $grp 2] > 1} {

                # Realise the logarithmic scale (Equidistant logarithmically)
                # for intensity scaling: MPP for Suns-Voc is around 4-5% sun
                if {$val == 0} {
                    set txt 0
                    set tmp -1
                    while {$tmp < [lindex $grp 2]} {
                        append txt "\; [expr exp(log(1e-6)+[incr tmp]\
                            *(log([lindex $grp 1])-log(1e-6))/[lindex $grp 2])\
                            /[lindex $grp 1]]"
                    }
                } elseif {[lindex $grp 1] == 0} {
                    set txt ""
                    set tmp -1
                    while {$tmp < [lindex $grp 2]} {
                        append txt "[expr exp(log($val)+[incr tmp]\
                            *(log(1e-6)-log($val))/[lindex $grp 2])/$val]\; "
                    }
                    append txt 1
                } else {
                    set txt 0
                    set tmp 0
                    while {$tmp < [lindex $grp 2]} {
                        append txt "\; [expr 1.*(exp(log($val)+[incr tmp]\
                            *(log([lindex $grp 1])-log($val))/[lindex $grp 2])\
                            -$val)/([lindex $grp 1]-$val)]"
                    }
                }
                set str "CurrentPlot (Time= ($txt))"
            } else {
                set str "CurrentPlot (Time= (0; 1))"
            }

            # By default save snapshots at 0 and 1
            set lst [list 0 1]
            foreach elm [lrange $grp 3 end] {
                lappend lst [expr 1.*($elm-$val)\
                    /([lindex $grp 1]-$val)]
            }
            set lst [lsort -real $lst]
            append str "\n[string repeat $mfjProc::arr(Tab)\
                6]Plot (FilePrefix= \"$SimArr(EtcDir)/n@node@_v$idx\"\
                Time= ([join $lst {; }]) noOverwrite)"
            if {[lindex $grp 2] == 0} {
                set str "CurrentPlot (Time= (-1))"
            }

            # Provide correct full path for ModelParameter
            set tmp Optics/OpticalGeneration
            if {[lindex $grp 0] eq "SpecScaling"} {
                if {[regexp {\s(OBAM|TMM|Raytrace)(\s|\})} $GopAttr]} {
                    set txt\
                        $tmp/ComputeFromSpectrum/Scaling
                } else {
                    if {$LoadTDR} {
                        set txt\
                            $tmp/ReadFromFile/Scaling
                    } else {
                        set txt\
                            $tmp/ComputeFromSpectrum/Scaling
                    }
                }
            } else {
                set txt\
                    $tmp/ComputeFromMonochromaticSource/Scaling
            }
            vputs -i-4 "
                    NewCurrentPrefix= \"v${idx}_\"
                    Quasistationary (
                        InitialStep= 1 MaxStep= 1 MinStep= 1e-100
                        Increment= 2 Decrement= 10 DoZero
                        Goal \{
                            ModelParameter= \"$txt\"
                            Value= [lindex $grp 1]
                        \}
                    ) \{$var
                        $str
                    \}\n"
        }
    } else {
        if {[array names arr [lindex $grp 0]] eq [lindex $grp 0]} {

            # Get the initial value from 'arr' and update
            set val $arr([lindex $grp 0])
            set arr([lindex $grp 0]) [lindex $grp 1]
        } else {

            # Add a new name and value pair to 'arr'
            set tmp [split [lindex $grp 0] /]
            set val [lindex $tmp end]
            set tmp [join [lrange $tmp 0 end-1] /]
            if {[string is double -strict $val]} {
                array set arr [list $tmp [lindex $grp 1]]
            } else {
                error "no initial value for '[lindex $grp 0]'!"
            }
        }
        if {$val != [lindex $grp 1]} {
            if {[lindex $grp 2]} {
                set str "CurrentPlot (Time= (range=(0 1);\
                    range= (0 1) intervals= [lindex $grp 2]))"

                # By default save snapshots at 0 and 1
                set lst [list 0 1]
                foreach elm [lrange $grp 3 end] {
                    lappend lst [expr 1.*($elm-[lindex $val 1])\
                        /([lindex $grp 1]-[lindex $val 1])]
                }
                set lst [lsort -real $lst]
                append str "\n[string repeat $mfjProc::arr(Tab) 6]Plot\
                    (FilePrefix= \"$SimArr(EtcDir)/n@node@_v$idx\"\
                    Time= ([join $lst {; }]) noOverwrite)"
            } else {
                set str "CurrentPlot (Time= (-1))"
            }

            # Provide full path for 'Wavelength'
            if {[lindex $grp 0] eq "Wavelength"} {
                set txt Optics/Excitation/Wavelength
            } else {
                set txt [lindex $grp 0]
            }
            vputs -i-4 "
                    NewCurrentPrefix= \"v${idx}_\"
                    Quasistationary (
                        InitialStep= 1 MaxStep= 1 MinStep= 1e-100
                        Increment= 2 Decrement= 10 DoZero
                        Goal \{
                            ModelParameter= \"$txt\"
                            Value= [lindex $grp 1]
                        \}
                    ) \{$var
                        $str
                    \}\n"
        }
    }
    incr idx
}
vputs -n -i-1 "
    \}"

)!