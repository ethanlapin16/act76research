/*------------------------------------------------------------
File:       05_act45.do
Purpose:    Tests Results for Act 45
Inputs:     data/clean/cleaned_dataset.dta
Outputs:    Regression results tables
Run order:  After 02_descriptive.do
------------------------------------------------------------*/
version 19                        // pin Stata semantics
clear all
set more off
set seed 12345                    // determinism for any random ops
set sortseed 12345                // stable sort ties across versions
cap log close
cap log close _all

*Load data
do "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project/scripts/stata/_config.do"
use "$PROJ/data/clean/cleaned_dataset.dta", clear

*IMPORTANT: FRAME*
frame copy default new 
frame new {
local y_var lhours //sets Y var, allows easy changes 

*==========Establish Pool==================*
gen byte period = year >= 2022    // 0 = pre, 1 = pooled post
drop if inlist(year, 2018, 2019)

* === Spec 1: all eligible mothers ===
keep if mother_elig == 1
gen byte band_45 = (pct_fpl < 350)
gen int gvar = 0
replace gvar = 2022 if Treat == 1 & band_45 == 1
replace gvar = 2024 if Treat == 1 & expansion_group == 1
csdid `y_var' $covs_main band_45 [iw=perwt], time(year) gvar(gvar) drimp
keep if inlist(year, 2021, 2022, 2023) 
keep if band_45 == 1
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp

* === Spec 4: only single mothers ===
preserve
keep if single_mother == 1
drdid `y_var' $covs_sm [iw=perwt], time(period) tr(Treat) drimp
restore

* === Spec 5: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
eststo DR1
ritest Treat (att: el(e(b),1,1)), reps(1000) cluster(statefip) force: /// *calls the first element of the outputs of drdid
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
local ri_p = el(r(p), 1, 1)     // grab RI p while ritest's r() is active
restore
estadd scalar ri_p = `ri_p' : DR1

* === Spec 6: mothers of young children ===
preserve
keep if mother_young == 1
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
restore

*===Spec 7: Mothers who work full time ===
preserve
keep if fulltime == 1
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
restore 

*===Spec 8 Mothers who work part time ===
preserve
keep if parttime == 1
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
restore 

*=================================
* Saved Block of Replication Code
*---------------------------------
* used in the event that we need 
* to permute results
*=================================
// keep if inlist(period, 2021, 2022)
// ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// *calls the first element of the outputs of drdid
// 	drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp

}

frame drop new //drop the frame
