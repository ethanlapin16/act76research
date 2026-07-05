/*------------------------------------------------------------
File:       06_pooledpost.do
Purpose:    Pooled-Post Period Respec
Inputs:     data/clean/cleaned_dataset.dta
Outputs:    Regression results tables
Run order:  After 05
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
gen byte period = year >= 2023    // 0 = pre, 1 = pooled post
keep if inlist(year, 2022, 2023, 2024)        // 2022 = pre, 2023/24 = post
			   
// *===========Triple  - Runs First before restricting to only eligible mothers -=========*
// gen DDD_treat = (statefip == 50) & (period == 1) & (mother_elig == 1)
// reghdfe `y_var' DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#period period#mother_elig)	
			   
*=== Spec 1: all eligible mothers ===
keep if mother_elig == 1
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp


* === Spec 2: only expansion group ===
preserve
keep if expansion_group == 1
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
restore

*=== Spec 3: only single mothers ===
preserve
keep if single_mother == 1
drdid `y_var' $covs_sm [iw=perwt], time(period) tr(Treat) drimp
restore

*====Spec 4: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
restore 

* === Spec 5: mothers of young children ===
preserve
keep if mother_young == 1
drdid lhours $covs_main [iw=perwt], time(period) tr(Treat) drimp
restore

} 
frame drop new //drop the frame
