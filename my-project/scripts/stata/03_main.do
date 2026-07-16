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

*Load data*
do "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project/scripts/stata/_config.do"

*IMPORTANT: FRAME*
frame put $keepvars, into(new)
frame new {


*=========Regressions=======*

*== Pre-Reg Cleaning === 
gen gvar = 2024 if Treat == 1
replace gvar = 0  if Treat == 0        // never-treated controls
gen byte DDD_treat = (statefip == 50) & (year == 2024) & (mother_elig == 1)

* === Triple Diffs, must run before we drop ineligible mothers ===
reghdfe lf_indicator DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#year year#mother_elig)
estimates store D3_lf_indicator
reghdfe uhrswork DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#year year#mother_elig)
estimates store D3_uhrswork


*===Cycle Specs on Y-Vars===*
foreach yv in lf_indicator uhrswork {
			   
* === Spec 1: all eligible mothers ===
cap keep if mother_elig == 1
display "`yv': All Eligible Mothers"
drdid `yv' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR_`yv'
rit_p `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : DR_`yv'
hdid_m `yv' "$covs_main" "DR" "Event Study for All Eligible Mothers"
estadd scalar mbreak = r(mbreak) : DR_`yv' //the DR-DiD ITT equals the CS event-study effect at t=0; HonestDiD is applied to that estimate


* === Spec 2: only expansion group ===
preserve
keep if expansion_group == 1
display "`yv': Only Expansion Group"
drdid `yv' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store EG_`yv'
rit_p `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : EG_`yv'
hdid_m `yv' "$covs_main" "EG" "Event Study for Act 76 Expansion Group"
estadd scalar mbreak = r(mbreak) : EG_`yv'
restore

* === Spec 3: only single mothers ===
preserve
keep if single_mother == 1
display "`yv': Only Single Mothers"
drdid `yv' $covs_sm if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store SM_`yv'
rit_p `yv' "$covs_sm"
local rip = r(p)
estadd scalar ri_p = `rip' : SM_`yv'
hdid_m `yv' "$covs_sm" "SM" "Event Study for Single Mothers"
estadd scalar mbreak = r(mbreak) : SM_`yv'
restore

* === Spec 4: young mothers ===
preserve
keep if inrange(age, 18, 28)
display "`yv': Only Young Mothers"
drdid `yv' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store YM_`yv'
rit_p `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : YM_`yv'
hdid_m `yv' "$covs_main" "YM" "Event Study for Young Mothers"
estadd scalar mbreak = r(mbreak) : YM_`yv'
restore
* === Spec 5: mothers of young children ===
preserve
keep if mother_young == 1
display "`yv': Mothers of Young Children"
drdid `yv' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store YC_`yv'
rit_p `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : YC_`yv'
hdid_m `yv' "$covs_main" "YC" "Event Study for Mothers of Young Children"
estadd scalar mbreak = r(mbreak) : YC_`yv'
restore

*===Spec 6: mothers who work full time ===
preserve
keep if fulltime == 1
display "`yv': Mothers who work full time"
drdid `yv' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store FT_`yv'
rit_p `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : FT_`yv'
hdid_m `yv' "$covs_main" "FT" "Event Study for Full-Time Working Mothers"
estadd scalar mbreak = r(mbreak) : FT_`yv'
restore 

*===Spec 7: mothers who work part time ===
preserve
keep if parttime == 1
display "`yv': Mothers who work part time"
drdid `yv' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store PT_`yv'
rit_p `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : PT_`yv'
hdid_m `yv' "$covs_main" "PT" "Event Study for Part-Time Working Mothers"
estadd scalar mbreak = r(mbreak) : PT_`yv'
restore 

*===Spec 8: Lowest Income Band/Pre Expansion === 
preserve 
keep if inrange(pct_fpl, 0, 350)
display "`yv': 0–350% FPL"
drdid `yv' $covs_main if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store PE_`yv'
rit_p `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : PE_`yv'
hdid_m `yv' "$covs_main" "PE" "Event Study for Pre-Expansion Group (0-350% FPL)"
estadd scalar mbreak = r(mbreak) : PE_`yv'
restore

* === Spec 9: Synthetic DiD (Arkhangelsky et al. 2021) ===
preserve
	set seed 12345    
	collapse (mean) `yv' $covs_main [pw=perwt], by(statefip year)
	gen byte treat_2 = (statefip == 50 & year == 2024) 
	xtset statefip year
	display "`yv': Synthetic DiD"
	sdid `yv' statefip year treat_2, vce(placebo) reps(100) ///
		covariates($covs_main, projected)
	estimates store SDD_`yv'
restore
*=================================
* Table of Regressions Outputs *
*=================================
esttab DR_`yv' D3_`yv' EG_`yv' SM_`yv' YM_`yv' using "$PROJ/scripts/stata/_outputs/regresults_main_`yv'.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ITT DDD_treat ITT treat_2 ITT) drop(_cons) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ITT "ITT") eqlabels(none) ///
	mtitles("Doubly Robust DiD" "Triple Differences" "DR: Expansion Group Only" "DR: Single Mothers Only" "DR: Young Mothers Only") ///
	stats(mbreak ri_p N, fmt(%9.2f %9.3f %14.0fc) labels("HonestDiD breakdown $\bar{M}$" "Randomization Inference p" "Observations")) nonumbers

esttab YC_`yv' FT_`yv' PT_`yv' PE_`yv' SDD_`yv' using "$PROJ/scripts/stata/_outputs/regresults_main_`yv'_2.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ITT DDD_treat ITT treat_2 ITT) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ITT "ITT") eqlabels(none) ///
	mtitles("DR: Mothers of Young Children Only" "DR: Full Time Employment" "DR: Part Time Employment" "DR: Pre-Expansion" "Synthetic DiD") ///
	stats(mbreak ri_p N, fmt(%9.2f %9.3f %9.0fc) labels("HonestDiD breakdown $\bar{M}$" "Randomization Inference p" "Observations")) nonumbers
	
}
est clear
*===================
*Propensity Scores*
*===================
// use "$PROJ/data/clean/cleaned_dataset.dta", clear //reload data to make this easier
// keep if mother_elig == 1
// keep if year == 2023
//
// 	*Weighted p-score model on baseline covariates
// 	eststo ps2: logit Treat $covs_main [pw=perwt], vce(cluster statefip)
//
// 	predict pscore_w
//
// 	* Define groups for legend
// 	gen group = cond(Treat == 1, "Vermont", "Control")
//
// 	qui sum pscore_w if inlist(Treat,0,1)
// 	local min = r(min)
// 	local max = r(max)
// 	local w   = (`max' - `min')/30
// 	local s   = floor(`min'/`w')*`w'   // align start to a bin edge
//
// 	* histogram only takes integer fweights
// 	gen long perwt_int = round(perwt)
//
// 	twoway 	histogram pscore_w if Treat == 1 [fw=perwt_int], width(`w') start(`s') fcolor(none) lcolor(red) || ///
// 			histogram pscore_w if Treat == 0 [fw=perwt_int], width(`w') start(`s') fcolor(none) lcolor(blue) ///
// 			ytitle("Density") xtitle("Propensity Score") title("Weighted") ///
// 			legend(order(1 "Vermont" 2 "Control") rows(1)) xlabel(, nogrid)
//
// 	graph save "$PROJ/figures/pscore_w.gph", replace
// 	graph use "$PROJ/figures/pscore_w.gph"
// 	graph export "$PROJ/figures/pscore_graph.png", as (png) replace
}
frame drop new //drop the frame


