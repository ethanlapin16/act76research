/*------------------------------------------------------------
File:       04_lhours.do
Purpose:    Same Regressions on Hours
Inputs:     data/clean/cleaned_dataset.dta
Outputs:    Regression results tables
Run order:  After 03_main.do
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

*drop dummy vars and set covariates
cap drop white
cap gen double age2 = age^2

local covs_main age2 single_mother black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural
local covs_sm  age2 black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural

*===========Triple Diff=========*
gen DDD_treat = (statefip == 50) & (year == 2024) & (mother_elig == 1)
reghdfe lhours DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#year year#mother_elig)
			   
*=== Spec 1: all eligible mothers ===
keep if mother_elig == 1
// preserve
// keep if inlist(year, 2022, 2023, 2024)        // 2022 = pre, 2023/24 = post
// gen byte period = year >= 2023                  // 0 = pre, 1 = pooled post
// drdid lhours `covs_main' [iw=perwt], robust time(period) tr(Treat) dripw
// restore
drdid lhours `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw
preserve
keep if inlist(year, 2023, 2024)
ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// *calls the first element of the outputs of drdid
	drdid lhours `covs_main' [iw=perwt], time(year) tr(Treat) dripw
restore

* === Spec 2: only expansion group ===
preserve
keep if expansion_group == 1
drdid lhours `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw
keep if inlist(year, 2023, 2024)
ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// *calls the first element of the outputs of drdid
	drdid lhours `covs_main' [iw=perwt], time(year) tr(Treat) dripw
restore

*=== Spec 3: only single mothers ===
preserve
keep if single_mother == 1
drdid lhours `covs_sm' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw
keep if inlist(year, 2023, 2024)
ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// *calls the first element of the outputs of drdid
	drdid lhours `covs_sm' [iw=perwt], time(year) tr(Treat) dripw
restore

*====Spec 4: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid lhours `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw
keep if inlist(year, 2023, 2024)
ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// *calls the first element of the outputs of drdid
	drdid lhours `covs_main' [iw=perwt], time(year) tr(Treat) dripw
restore 

* --- Synthetic DiD (Arkhangelsky et al. 2021) ---
preserve
	collapse (mean) lhours `covs_main' [pw=perwt], by(statefip year)
	* Restrict to the chosen pre/post window (>=2 pre-periods needed for time weights):
	* keep if inrange(year, 2019, 2024)
	gen byte treat_2 = (statefip == 50 & year == 2024) 
	xtset statefip year
	sdid lhours statefip year treat_2, vce(placebo) reps(100) ///
		covariates(`covs_main', projected)
restore


 *=== Synthetic control (aggregate state-year panel) ===
preserve
xtset, clear
collapse (mean) `covs_main' lhours [pw=perwt], by(statefip year)
egen pseudotime = group(year)
xtset statefip pseudotime
tsfill, full
* synth's keep() re-parses the filename and breaks on spaces in $PROJ;
* cd into the output dir so keep() sees a space-free relative filename.
local here "`c(pwd)'"
qui cd "$PROJ/scripts/stata/_outputs"
synth lhours lhours(1) lhours(2) lhours(3) lhours(4) lhours(5) ///
    `covs_main', trunit(50) trperiod(6) xperiod(1(1)5) msperiod(1(1)5) resultsperiod(1(1)6) ///
    keep(synth_vt.dta, replace)
qui cd "`here'"
restore

* --- Read the SCM effect off a table: per-period gaps + pre/post RMSPE ratio ---
preserve
	use "$PROJ/scripts/stata/_outputs/synth_vt.dta", clear
	keep if !missing(_time)
	gen double gap = _Y_treated - _Y_synthetic
	gen byte post = _time >= 6
	list _time _Y_treated _Y_synthetic gap, sepby(post) noobs

	* RMSPE = root-mean-square of the gaps, by pre/post
	gen double gap2 = gap^2
	qui sum gap2 if post == 0
	local rmspe_pre = sqrt(r(mean))
	qui sum gap2 if post == 1
	local rmspe_post = sqrt(r(mean))
	local rmspe_ratio = `rmspe_post' / `rmspe_pre'

	display _n "{hline 60}"
	di " SCM FIT / EFFECT SUMMARY (Vermont, statefip 50)"
	di "{hline 60}"
	di " Pre-treatment RMSPE:   " %9.5f `rmspe_pre'
	di " Post-treatment RMSPE:  " %9.5f `rmspe_post'
	di " Post/Pre RMSPE ratio:  " %9.4f `rmspe_ratio'
	di " Post-period gap (ATT): " %9.5f `=gap[_N]'
	di "{hline 60}"
restore
//SCM gives a RMSPE that is too high I think
