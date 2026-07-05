/*------------------------------------------------------------
File:       03_main.do
Purpose:    Main Regression - LF Indicator
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
			   
* === Triple  Diff- Runs First before restricting to only eligible mothers ===
gen DDD_treat = (statefip == 50) & (year == 2024) & (mother_elig == 1)
reghdfe `y_var' DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#year year#mother_elig)
estimates store D3		   


* === Spec 1: all eligible mothers ===
keep if mother_elig == 1
* DR DiD * 
drdid `y_var' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR1


* === Spec 2: Pooled Post Period === 
preserve
	keep if inlist(year, 2022, 2023, 2024)        // 2022 = pre, 2023/24 = post
	gen byte period = year >= 2023                  // 0 = pre, 1 = pooled post
	drdid `y_var' $covs_main [iw=perwt], time(period) tr(Treat) drimp
	estimates store DR2
restore

* === Spec 3: only expansion group ===
preserve
keep if expansion_group == 1
drdid `y_var' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR3
restore

* === Spec 4: only single mothers ===
preserve
keep if single_mother == 1
drdid `y_var' $covs_sm if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR4
restore

* === Spec 5: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid `y_var' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR5

restore 
* === Spec 6: mothers of young children ===
preserve
keep if mother_young == 1
drdid `y_var' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR6
restore

*===Spec 7: Mothers who work full time ===
preserve
keep if fulltime == 1
drdid `y_var' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR7
restore 

*===Spec 8 Mothers who work part time ===
preserve
keep if parttime == 1
drdid `y_var' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR8
restore 

*===Spec 9 No Covs ===
drdid `y_var' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR9

*===Spec 10: Only Band 1===
preserve 
keep if inrange(pct_fpl, 0, 400)
drdid `y_var' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR10
restore

* === Synthetic DiD (Arkhangelsky et al. 2021) ===
preserve
	collapse (mean) `y_var' $covs_main [pw=perwt], by(statefip year)
	* Restrict to the chosen pre/post window (>=2 pre-periods needed for time weights):
	* keep if inrange(year, 2019, 2024)
	gen byte treat_2 = (statefip == 50 & year == 2024) 
	xtset statefip year
	sdid `y_var' statefip year treat_2, vce(placebo) reps(100) ///
		covariates($covs_main, projected)
	estimates store SDD
restore

//
// * === Synthetic Control Method (aggregate state-year panel) === 
// preserve
// xtset, clear
// collapse (mean) $covs_main `y_var' [pw=perwt], by(statefip year)
// egen pseudotime = group(year)
// xtset statefip pseudotime
// tsfill, full
// local here "`c(pwd)'"
// qui cd "$PROJ/scripts/stata/_outputs"
// synth `y_var' `y_var'(1) `y_var'(2) `y_var'(3) `y_var'(4) `y_var'(5) ///
//     $covs_main, trunit(50) trperiod(6) xperiod(1(1)5) msperiod(1(1)5) resultsperiod(1(1)6) ///
//     keep(synth_vt.dta, replace)
// qui cd "`here'"
// restore
//
// * --- Read the SCM effect off a table: per-period gaps + pre/post RMSPE ratio ---
// preserve
// 	use "$PROJ/scripts/stata/_outputs/synth_vt.dta", clear
// 	keep if !missing(_time)
// 	gen double gap = _Y_treated - _Y_synthetic
// 	gen byte post = _time >= 6
// 	list _time _Y_treated _Y_synthetic gap, sepby(post) noobs
//
// 	* RMSPE = root-mean-square of the gaps, by pre/post
// 	gen double gap2 = gap^2
// 	qui sum gap2 if post == 0
// 	local rmspe_pre = sqrt(r(mean))
// 	qui sum gap2 if post == 1
// 	local rmspe_post = sqrt(r(mean))
// 	local rmspe_ratio = `rmspe_post' / `rmspe_pre'
//
// 	display _n "{hline 60}"
// 	di " SCM FIT / EFFECT SUMMARY (Vermont, statefip 50)"
// 	di "{hline 60}"
// 	di " Pre-treatment RMSPE:   " %9.5f `rmspe_pre'
// 	di " Post-treatment RMSPE:  " %9.5f `rmspe_post'
// 	di " Post/Pre RMSPE ratio:  " %9.4f `rmspe_ratio'
// 	di " Post-period gap (ATT): " %9.5f `=gap[_N]'
// 	di "{hline 60}"
// restore


*=================================
* Saved Block of Replication Code
*---------------------------------
* used in the event that we need 
* to permute results
*=================================
// keep if inlist(year, 2023, 2024)
// ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// *calls the first element of the outputs of drdid
// 	drdid `y_var' $covs_main [iw=perwt], time(year) tr(Treat) drimp

*=================================
* Table of Regressions Outputs *
*=================================
esttab DR1 D3 DR2 DR3 DR4 DR5 DR6 SDD using "$PROJ/scripts/stata/_outputs/reg_results1.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ATT DDD_treat ATT treat_2 ATT) drop(_cons) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ATT "ATT") eqlabels(none) ///
	mtitles("Doubly Robust DiD" "Triple Differences" "DR: Pooled Post-Period" "DR: Expansion Group Only" "DR: Single Mothers Only" "DR: Young Mothers Only" "DR: Mother of Young Children" "Synthetic DiD") ///
	stats(N, fmt(%9.0fc) labels("Observations")) nonumbers

	
} 
frame drop new //drop the frame
	