/*------------------------------------------------------------
File:       04_hours.do
Purpose:    Same Regressions on Hours
Inputs:     data/clean/cleaned_dataset.dta
Outputs:    Regression results tables
Run order:  After 03_main.do
Note: If the full do-file is run, you must re-run the
keep if mother_elig == 1 command before running individual 
regressions as the propensity score table resets the data
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

*IMPORTANT: FRAME*
frame copy default new 
frame new {


// *===========Triple Diff=========*
// gen DDD_treat = (statefip == 50) & (year == 2024) & (mother_elig == 1)
// reghdfe lhours DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#year year#mother_elig)
// eststo D3
//
// * === Spec 0: Quick Robustness Check ===
// preserve 
// gen byte mother_noqual = (mother_cqual == 1 & pct_fpl > 575) 
// drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
// eststo D0
// restore	

	   
*=== Spec 1: all eligible mothers ===
keep if mother_elig == 1
*=====================================

* Standard Spec * 
drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo DR1
preserve
keep if inlist(year, 2023, 2024)
ritest Treat (att: el(e(b),1,1)), reps(1000) cluster(statefip) force: ///
	drdid lhours $covs_main [iw=perwt], time(year) tr(Treat) drimp
local ri_p = el(r(p), 1, 1)     // grab RI p while ritest's r() is active
restore
estadd scalar ri_p = `ri_p' : DR1

* === Spec 2: only expansion group ===
preserve
keep if expansion_group == 1
keep if inlist(year, 2023, 2024)
drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo EG
ritest Treat (att: el(e(b),1,1)), reps(1000) cluster(statefip) force: ///
	drdid lhours $covs_main [iw=perwt], time(year) tr(Treat) drimp
local ri_p = el(r(p), 1, 1)
restore
estadd scalar ri_p = `ri_p' : EG

*=== Spec 3: only single mothers ===
preserve
keep if single_mother == 1
drdid lhours $covs_sm if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo SM
restore

*====Spec 4: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo YM
keep if inlist(year, 2023, 2024)
ritest Treat (att: el(e(b),1,1)), reps(1000) cluster(statefip) force: ///
	drdid lhours $covs_main [iw=perwt], time(year) tr(Treat) drimp
local ri_p = el(r(p), 1, 1)
restore
estadd scalar ri_p = `ri_p' : YM

*===Spec 5: Mothers of young children ===
preserve
keep if mother_young == 1
drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo YC
keep if inlist(year, 2023, 2024)
ritest Treat (att: el(e(b),1,1)), reps(1000) cluster(statefip) force: ///
	drdid lhours $covs_main [iw=perwt], time(year) tr(Treat) drimp
local ri_p = el(r(p), 1, 1)
restore
estadd scalar ri_p = `ri_p' : YC

*===Spec 6: Mothers who work full time ===
preserve
keep if fulltime == 1
drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo FT
restore 

*===Spec 7: Mothers who work part time ===
preserve
keep if parttime == 1
drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo PT
restore 

*===Spec 8 No Covs ===
drdid lhours if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
eststo NC

*===Spec 9: Only First Band ===
preserve 
keep if inrange(pct_fpl, 0, 400)
drdid lhours $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store FB
restore

* --- Synthetic DiD (Arkhangelsky et al. 2021) ---
preserve
	collapse (mean) lhours $covs_main [pw=perwt], by(statefip year)
	gen byte treat_2 = (statefip == 50 & year == 2024) 
	xtset statefip year
	sdid lhours statefip year treat_2, vce(placebo) reps(100) ///
		covariates($covs_main, projected)
restore


 *=== Synthetic control (aggregate state-year panel) ===
preserve
xtset, clear
collapse (mean) $covs_main lhours [pw=perwt], by(statefip year)
egen pseudotime = group(year)
xtset statefip pseudotime
tsfill, full
* synth's keep() re-parses the filename and breaks on spaces in $PROJ;
* cd into the output dir so keep() sees a space-free relative filename.
local here "`c(pwd)'"
qui cd "$PROJ/scripts/stata/_outputs"
synth lhours lhours(1) lhours(2) lhours(3) lhours(4) lhours(5) ///
    $covs_main, trunit(50) trperiod(6) xperiod(1(1)5) msperiod(1(1)5) resultsperiod(1(1)6) ///
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

*=================================
* Saved Block of Replication Code
*---------------------------------
* used in the event that we need 
* to permute results set to a low 
* rep count for ease  of use, 
* for robustness, turn it up, 
* but prepare to wait
*=================================*
// keep if inlist(year, 2023, 2024)
// ritest Treat (att: el(e(b),1,1)), reps(100) cluster(statefip) force: /// 
// 	drdid lhours $covs_main [iw=perwt], time(year) tr(Treat) drimp

*===================
*Propensity Scores*
*===================
use "$PROJ/data/clean/cleaned_dataset.dta", clear //reload data to make this easier
cap drop white
cap gen double age2 = age^2
keep if mother_elig == 1
keep if year == 2023

	*Weighted p-score model on baseline covariates
	eststo ps2: logit Treat $covs_main [pw=perwt], vce(cluster statefip)

	predict pscore_w

	* Define groups for legend
	gen group = cond(Treat == 1, "Vermont", "Control")

	qui sum pscore_w if inlist(Treat,0,1)
	local min = r(min)
	local max = r(max)
	local w   = (`max' - `min')/30
	local s   = floor(`min'/`w')*`w'   // align start to a bin edge

	* histogram only takes integer fweights
	gen long perwt_int = round(perwt)

	twoway 	histogram pscore_w if Treat == 1 [fw=perwt_int], width(`w') start(`s') fcolor(none) lcolor(red) || ///
			histogram pscore_w if Treat == 0 [fw=perwt_int], width(`w') start(`s') fcolor(none) lcolor(blue) ///
			ytitle("Density") xtitle("Propensity Score") title("Weighted") ///
			legend(order(1 "Vermont" 2 "Control") rows(1)) xlabel(, nogrid)

	graph save "$PROJ/figures/pscore_w.gph", replace
	graph use "$PROJ/figures/pscore_w.gph"
	graph export "$PROJ/figures/pscore_graph.png", as (png) replace
*===================
*Outcomes Table*
*===================	
esttab DR1 EG YM YC using "$PROJ/scripts/stata/_outputs/reg_results_lhours.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ATT) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ATT "ATT") eqlabels(none) ///
	mtitles("Doubly Robust DiD" "Doubly Robust: Expansion Group Only" "Doubly Robust: Young Mothers Only" "Doubly Robust: Mothers of Young Children Only") ///
	stats(ri_p N, fmt(%9.3f %9.0fc) labels("Randomization Inference $p$" "Observations"))
}

frame drop new //drop the frame
