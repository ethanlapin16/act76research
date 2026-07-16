/*------------------------------------------------------------
File:       00_master.do
Purpose:    Installs Packages and Runs All Do Files
Inputs:     data/raw/usa_00005.* (loaded via usa_00005.do)
Outputs:    N/A
Run order:  Master
------------------------------------------------------------*/
version 19

* Project root (set your repo via the config) *
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"

* Package installs (comment out after first run) *
// cap ssc install reghdfe     // High-dimensional FE regressions
// cap ssc install ftools      // Required by reghdfe
// cap ssc install require 		// required by reghdfe 
// cap ssc install estout      // esttab / eststo for LaTeX tables	
// cap ssc install ivreg2      // 2SLS (needed by reghdfe for IV)
// cap ssc install ranktest    // Required by ivreg2
// cap ssc install coefplot    // Coefficient plots
// cap ssc install ietoolkit   // iebaltab for balance tables
// cap ssc install stackdid    // Stacked DiD
// cap ssc install sdid			// Synth DiD
// cap ssc install synth       // Abadie–Diamond–Hainmueller classic SCM
// cap ssc install synth_runner   // Galiani–Quistorff: placebo/permutation inference + p-values
// cap ssc install allsynth     // Wiltshire: bias-corrected ("augmented") SCM + event-study plots
// cap ssc install egenmore
// cap ssc install ritest
// cap ssc install drdid
// cap ssc install regsave 
// cap ssc install honestdid
// cap ssc install csdid
// cap ssc install grc1leg2

*run all do files* *this will take a substantial amount of time*
do "$PROJ/scripts/stata/01_loadclean.do"
do "$PROJ/scripts/stata/02_descriptive.do"
do "$PROJ/scripts/stata/03_main.do"
do "$PROJ/scripts/stata/04_act45pooled.do"
do "$PROJ/scripts/stata/05_fathers.do"
