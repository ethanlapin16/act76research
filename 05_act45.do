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
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"
use "$PROJ/data/clean/cleaned_dataset.dta", clear


*IMPORTANT: FRAME*
frame copy default new 
frame new {
	
*drop dummy vars and set covariates
cap drop white
cap gen double age2 = age^2

local covs_main age age2 single_mother black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural
local covs_sm  age age2 black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural

			   
* === Triple  Diff- Runs First before restricting to only eligible mothers ===
gen DDD_treat = (statefip == 50) & (year == 2022) & (mother_elig == 1)
reghdfe lf_indicator DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#year year#mother_elig)
estimates store D3		   


* === Spec 1: all eligible mothers ===
keep if mother_elig == 1
gen byte band_45 = (pct_fpl <= 350)
gen int gvar = 0
replace gvar = 2022 if Treat == 1 & band_45 == 1
replace gvar = 2024 if Treat == 1 & expansion_group == 1
csdid lf_indicator `covs_main' band_45 [iw=perwt], time(year) gvar(gvar) drimp
****
drdid lf_indicator `covs_main' if inlist(year, 2021, 2022) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR1

* === Spec 3: only expansion group ===
preserve
keep if expansion_group == 1
drdid lf_indicator `covs_main' if inlist(year, 2021, 2022) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR3
restore

* === Spec 4: only single mothers ===
preserve
keep if single_mother == 1
drdid lf_indicator `covs_sm' if inlist(year, 2021, 2022) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR4
restore

* === Spec 5: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid lf_indicator `covs_main' if inlist(year, 2021, 2022) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR5

restore 
* === Spec 6: mothers of young children ===
preserve
keep if mother_young == 1
drdid lhours `covs_main' if inlist(year, 2021, 2022) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR6
restore


* === Synthetic DiD (Arkhangelsky et al. 2021) ===
preserve
	collapse (mean) lf_indicator `covs_main' [pw=perwt], by(statefip year)
	* Restrict to the chosen pre/post window (>=2 pre-periods needed for time weights):
	* keep if inrange(year, 2019, 2024)
	gen byte treat_2 = (statefip == 50 & year == 2022) 
	xtset statefip year
	sdid lf_indicator statefip year treat_2, vce(placebo) reps(100) ///
		covariates(`covs_main', projected)
	estimates store SDD
restore


*=================================
* Saved Block of Replication Code
*---------------------------------
* used in the event that we need 
* to permute results
*=================================
// keep if inlist(year, 2021, 2022)
// ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// *calls the first element of the outputs of drdid
// 	drdid lf_indicator `covs_main' [iw=perwt], time(year) tr(Treat) drimp
