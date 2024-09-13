# UniSolar: Unifying typical multidimensional solar cell simulations
UniSolar is a collaborative framework, designed to streamline the utilization of
    commercial software packages such as Sentaurus TCAD. Drawing from extensive
    experience spanning over a decade in various solar cell architectures and
    technologies, it capitalizes on the finding that typical simulation
    workflows encompass no more than 11 common steps. As a result, relevant
    details crucial for process, optical, and electrical simulations are
    systematically organized into these 11 steps, each represented by a variable
    accepting a list as its value. By simply tuning values for these variables
    in a plain text file (e.g., 10variables.txt or 10variables-brief.txt),
    multidimensional process, optical, and electrical simulations for a wide
    range of solar cells can be easily performed without even knowing Sentaurus.
    With UniSolar, simulations are entirely managed by a solitary command file
    (11ctrlsim.tcl), responsible for key tasks such as grammar checks, variable
    conversion, Sentaurus interaction, and job execution/termination.
    Furthermore, UniSolar provides two auxiliary command files (12savetpl.tcl
    and 13loadtpl.tcl) to archive relevant files into and retrieve them from
    a Tar/GZip format, thus facilitating efficient preservation of previous
    simulations and swift initiation of new ones.

Currently only Sentaurus TCAD is supported. In your home directory on your
    Linux server, create and enter a directory "STDB". Download the entire
    project there from Github using the following git command:
        git clone https://github.com/mfjamao/Unified-Solar-Cell-Simulation.git
    Afterwards, enter the subdirectory "Unified-Solar-Cell-Simulation", make
    sure '11ctrlsim.tcl' is executable. Open '11ctrlsim.tcl' with any text
    editor and update the values for keys 'ST|Hosts', 'ST|Paths', 'ST|Licns',
    Email|Sufx, and Email in the array 'SimArr' according to your own set up
    of Sentaurus TCAD.

# Citation for UniSolar
If UniSolar promotes your research, kindly cite the following references in your
    publication:
    [1] Ma F-J, Wang S, Yi C, Zhou L, Hameiri Z, Bremner S, Hao X, and Hoex B.
    A collaborative framework for unifying typical multidimensional solar cell
    simulations – Part I. Ten common simulation steps and representing
    variables. Prog Photovolt Res Appl. 2024; 1‐16. doi:10.1002/pip.3779

# Perform design of experiments (DOE) with UniSolar using WinSCP
1. Login to your server and find 10variables.txt or 10variables-brief.txt
2. Edit variable values following the comments within 10variables.txt
3. Add desired comments and save the text file to finalize DOE
4. Right click 11ctrlsim.tcl and select 'execute' to start batch running
5. Check 11ctrlsim.out or job scheduler output file for job progress
6. Execute 11ctrlsim.tcl again to stop the running batch if necessary
7. Download numbered results under 06out directory for data analysis
8. Execute 12savetpl.tcl to save key files in 07tpl for future reference
9. Execute 13loadtpl.tcl to load key files back from a specified .tgz file

Note 1: A variable takes a list (anything enclosed by braces. Braces can be
    omitted for a one-element list) as its value. Assigning lists to a
    variable to enable multiple runs with spaces as the separator. i.e.
    Multiple lists: 1 {2 3} {4 5 6} {7 8 9 10} ...
Note 2: Case insensitiveness do NOT apply to grammar rules. Only savvy users
    are supposed to modify grammar rules.
Note 3: Problem or issue? Please email Dr. Fa-Jun MA (mfjamao@yahoo.com)

# Essential files for UniSolar to work properly
.mfj/mfjGrm.tcl
.mfj/mfjIntrpr.tcl
.mfj/mfjProc.tcl
.mfj/mfjST.tcl
10variables.txt
11ctrlsim.tcl
12savetpl.tcl
13loadtpl.tcl
gtooldb.tcl
datexcodes.txt
Molefraction.txt
sde_dvs.cmd
sprocess_fps.cmd
sdevice_des.cmd
sdevice.par
svisual_vis.tcl

Material, spectra and experimental files are also required if appeared in
    '10variables.txt'. Otherwise, they are optional. Additionally, they
    can be created following their respective patterns in directories 01mdb/,
    02opt/ and 03exp/, respectively.

# Version history
2.3     12/09/2024
    Enhancement: 1. Introduced a shorthand format to allow easy permutation of
        multiple element values.  2. Added X, Y, and Z references following the
        implicit method used in 'RegGen'. 3. Enabled math calculations including
        Tcl math functions for each coordinate in position specifications.  4.
        Updated the delimiter between two positions from '/' to '//' to avoid
        confusion with the division symbol.
2.2     04/01/2024
    Enhancement: Process simulations are integrated into UniSolar. Processes
        like diffusion, implantation are supported.
2.1     04/03/2023
    Enhancement: The majority of planned features are finally implemented.
        Optical simulation: OBAM, TMM, Raytracing
        Electrical simulation: QSSPC (including J0 extraction), QE,
        dark JV, light JV, Suns-Voc,Suns-Jsc, CV
        PL and EL are not yet available
2.0     31/07/2022
    Enhancement: New framework to support arbitrary 2D/3D structures. Adopted
        universal coordinate system. Reduced input parameters down to tweleve.
        Implementd a grammar check for input values. Combined optical, lifetime
        and electrical simulations into one project.
1.9     01/07/2018
    Enhancement: New framework (prototype) to support arbitrary 2D/3D
        structures. Tested it with optical simulation
1.8     20/02/2017
    Bug fix: Fixed a bug in loss analysis (Thanks to Aobo)
    Enhancement: Re-organization of input parameters
    Enhancement: Added support to interface recombination beyond the substrate
1.7     06/10/2016
    Enhancement: Added loss analysis for JV, QE and Suns-Voc sweep
    Enhancement: Improved mesh and numerics for better convergence when
        simulating Suns-Voc
    Enhancement: Added support to extract field quantities at any setpoints
        (Thanks to Alex)
    Enhancement: Implementd series resistance at MPP using LJV and Suns-Voc
    Enhancement: Added two band dispersion option for tunneling in III-V
        materials (Thanks to Chuqi)
1.6     24/08/2016
    Enhancement: Added support to tunnel diode (Thanks to Chuqi)
    Enhancement: Added series and shunt resistance to postprocessing (Thanks to
        Jing)
    Enhancement: Improved convergence of LJV for heterojunction (Thanks to Jing)
    Enhancement: Combined doping, traps, x and y mole profiles to reduce
        variables
1.5     22/08/2016
    Enhancement: Improved mesh for thin film solar cells
1.4     09/08/2016
    Enhancement: Move contact resistance calculation to postprocessing
1.3     21/07/2016
    Enhancement: Added support to thin film devices (Thanks to Chuqi)
    Enhancement: Enabled a simple optical simulation, OBAM (Thanks to Aobo)
1.2     05/07/2016
    Enhancement: Added AluminumActiveConcentration and improved mesh
1.1     30/06/2016
    Enhancement: Added Rs calculation based on multi-light method
1.0     27/06/2016
    Initial version: (Thanks for the support from Ziv and feedbacks from Jing,
        Aobo, Alex, Hongzhao and Mengjie)
