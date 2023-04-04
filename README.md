# A collaborative framework for unifying multidimensional solar cell simulations
Typical solar cell simulations follow the same procedures, which can be well
    delineated by several variables. This project is designed to verify these
    variable values and pass the formatted results to Sentaurus TCAD, where a
    2/3D homo-/hetero-/single-/multi-junction solar cell is established and
    typical optical and electrical behaviours are investigated by ramping
    contact properties, illumination settings, etc.
Once all the files are downloaded to a linux server, open '11ctrlsim.tcl'
    with any text editor and update the settings for 'STHosts', 'STPaths',
    'STLicns' and 'STLib' according to your own configuration of Sentaurus.
    Save and make '11ctrlsim.tcl' executable.

# Design of experiments (DOE) using WinSCP
1. Login to a server hosting the desired simulator and find 10variables.txt
2. Open that text file and edit variable values following the comments
3. Add desired comments and save this text file to finalize DOE
4. Right click 11ctrlsim.tcl and select execute to start batch running
5. Check 11ctrlsim.out or job scheduler output file for job progress
6. Execute 11ctrlsim.tcl again to stop the running batch if necessary
7. Download numbered results under 06out directory for further analysis
8. Execute 12savetpl.tcl to save key files in 07tpl for future reference
9. Execute 13loadtpl.tcl to load key files back from a specified template

Note 1: A variable takes a list (anything enclosed by braces. Braces can be
    omitted for a one-element list) as its value. Assigning lists to a
    variable to enable multiple runs with spaces as the separator. i.e.
    Multiple lists: 1 {2 3} {4 5 6} {7 8 9 10} ...
Note 2: Case insensitiveness do NOT apply to grammar rules. Only savvy users
    are supposed to modify grammar rules.
Note 3: Problem or issue? Email Dr. Fa-Jun MA (mfjamao@yahoo.com) (Thanks!)

# Essential files for the codes and Sentaurus working properly
.mfj/mfjGrm.tcl
.mfj/mfjIntrpr.tcl
.mfj/mfjProc.tcl
.mfj/mfjST.tcl
.mfj/swb2var.tcl
10variables.txt
11ctrlsim.tcl
12savetpl.tcl
13loadtpl.tcl
gtooldb.tcl
datexcodes.txt
Molefraction.txt
sde_dvs.cmd
sdevice_des.cmd
sdevice.par
svisual_vis.tcl

Material, spectra and experimental files are also required if appeared in
    '10variables.txt'. Otherwise, they are optional. Additionally, they
    can be created following their respective patterns in directories 01mdb/,
    02opt/ and 03exp/, respectively.

# Version history
2.1		04/03/2023
	Enhancement: The majority of planned features are finally implemented.
		Optical simulation: OBAM, TMM, Raytracing
		Electrical simulation: QSSPC (including J0 extraction), QE,
		dark JV, light JV, Suns-Voc,Suns-Jsc, CV
		PL and EL are not yet available
2.0		31/07/2022
	Enhancement: New framework to support arbitrary 2D/3D structures. Adopted
		universal coordinate system. Reduced input parameters down to tweleve.
		Implementd a grammar check for input values. Combined optical, lifetime
		and electrical simulations into one project.
1.9		01/07/2018
	Enhancement: New framework (prototype) to support arbitrary 2D/3D
		structures. Tested it with optical simulation
1.8		20/02/2017
	Bug fix: Fixed a bug in loss analysis (Thanks to Aobo)
	Enhancement: Re-organization of input parameters
	Enhancement: Added support to interface recombination beyond the substrate
1.7		06/10/2016
	Enhancement: Added loss analysis for JV, QE and Suns-Voc sweep
	Enhancement: Improved mesh and numerics for better convergence when
		simulating Suns-Voc
	Enhancement: Added support to extract field quantities at any setpoints
		(Thanks to Alex)
	Enhancement: Implementd series resistance at MPP using LJV and Suns-Voc
	Enhancement: Added two band dispersion option for tunneling in III-V
		materials (Thanks to Chuqi)
1.6		24/08/2016
	Enhancement: Added support to tunnel diode (Thanks to Chuqi)
	Enhancement: Added series and shunt resistance to postprocessing (Thanks to
		Jing)
	Enhancement: Improved convergence of LJV for heterojunction (Thanks to Jing)
	Enhancement: Combined doping, traps, x and y mole profiles to reduce
		variables
1.5		22/08/2016
	Enhancement: Improved mesh for thin film solar cells
1.4		09/08/2016
	Enhancement: Move contact resistance calculation to postprocessing
1.3		21/07/2016
	Enhancement: Added support to thin film devices (Thanks to Chuqi)
	Enhancement: Enabled a simple optical simulation, OBAM (Thanks to Aobo)
1.2		05/07/2016
	Enhancement: Added AluminumActiveConcentration and improved mesh
1.1		30/06/2016
	Enhancement: Added Rs calculation based on multi-light method
1.0		27/06/2016
	Initial version: (Thanks for the support from Ziv and feedbacks from Jing,
		Aobo, Alex, Hongzhao and Mengjie)
