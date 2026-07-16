/*------------------------------------------------------------
File:       05_fathers.do
Purpose:    Runs the 03_main specs on fathers (placebo/comparison).
Inputs:     data/clean/cleaned_dataset.dta (via _config.do)
Outputs:    scripts/stata/_outputs/regresults_fathers_*.tex
            Figures/eventstudy_fathers*_*.pdf
Run order:  Secondary regressors
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
gen int gvar = 2024 if Treat == 1
replace gvar = 0  if Treat == 0        // never-treated controls
gen byte DDD_treat = (statefip == 50) & (year == 2024) & (father_elig == 1)

* === Triple Diffs, must run before we drop ineligible fathers ===
reghdfe lf_indicator DDD_treat [pw=perwt], absorb (statefip#father_elig statefip#year year#father_elig)
estimates store D3_lf_indicator
reghdfe uhrswork DDD_treat [pw=perwt], absorb (statefip#father_elig statefip#year year#father_elig)
estimates store D3_uhrswork


*===Cycle Specs on Y-Vars===*
foreach yv in lf_indicator uhrswork {

* === Spec 1: all eligible fathers ===
cap keep if father_elig == 1
display "`yv': All Eligible Fathers"
drdid `yv' $covs_father if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store DR_`yv'
rit_p `yv' "$covs_father"
local rip = r(p)
estadd scalar ri_p = `rip' : DR_`yv'
hdid_m `yv' "$covs_father" "fathersDR" "Event Study for All Eligible Fathers"
estadd scalar mbreak = r(mbreak) : DR_`yv' //the DR-DiD ATT equals the CS event-study effect at t=0; HonestDiD is applied to that estimate


* === Spec 2: only expansion group ===
preserve
keep if expansion_group_f == 1
display "`yv': Only Expansion Group"
drdid `yv' $covs_father if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store EG_`yv'
rit_p `yv' "$covs_father"
local rip = r(p)
estadd scalar ri_p = `rip' : EG_`yv'
hdid_m `yv' "$covs_father" "fathersEG" "Event Study for Act 76 Expansion Group"
estadd scalar mbreak = r(mbreak) : EG_`yv'
restore

* === Spec 3: only single fathers ===
preserve
keep if single_father == 1
display "`yv': Only Single Fathers"
drdid `yv' $covs_sm if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store SF_`yv'
rit_p `yv' "$covs_sm"
local rip = r(p)
estadd scalar ri_p = `rip' : SF_`yv'
hdid_m `yv' "$covs_sm" "fathersSF" "Event Study for Single Fathers"
estadd scalar mbreak = r(mbreak) : SF_`yv'
restore

* === Spec 4: young fathers ===
preserve
keep if inrange(age, 18, 28)
display "`yv': Only Young Fathers"
drdid `yv' $covs_father if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store YF_`yv'
rit_p `yv' "$covs_father"
local rip = r(p)
estadd scalar ri_p = `rip' : YF_`yv'
hdid_m `yv' "$covs_father" "fathersYF" "Event Study for Young Fathers"
estadd scalar mbreak = r(mbreak) : YF_`yv'
restore

* === Spec 5: fathers of young children ===
preserve
keep if father_young == 1
display "`yv': Fathers of Young Children"
drdid `yv' $covs_father if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store YC_`yv'
rit_p `yv' "$covs_father"
local rip = r(p)
estadd scalar ri_p = `rip' : YC_`yv'
hdid_m `yv' "$covs_father" "fathersYC" "Event Study for Fathers of Young Children"
estadd scalar mbreak = r(mbreak) : YC_`yv'
restore

*===Spec 6: fathers who work full time ===
preserve
keep if fulltime == 1
display "`yv': Fathers who work full time"
drdid `yv' $covs_father if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store FT_`yv'
rit_p `yv' "$covs_father"
local rip = r(p)
estadd scalar ri_p = `rip' : FT_`yv'
hdid_m `yv' "$covs_father" "fathersFT" "Event Study for Full-Time Working Fathers"
estadd scalar mbreak = r(mbreak) : FT_`yv'
restore

*===Spec 7: fathers who work part time ===
preserve
keep if parttime == 1
display "`yv': Fathers who work part time"
drdid `yv' $covs_father if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store PT_`yv'
rit_p `yv' "$covs_father"
local rip = r(p)
estadd scalar ri_p = `rip' : PT_`yv'
hdid_m `yv' "$covs_father" "fathersPT" "Event Study for Part-Time Working Fathers"
estadd scalar mbreak = r(mbreak) : PT_`yv'
restore

*===Spec 8: Lowest Income Band/Pre Expansion ===
preserve
keep if inrange(pct_fpl, 0, 350)
display "`yv': 0–350% FPL"
drdid `yv' $covs_father if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) drimp
estimates store PE_`yv'
rit_p `yv' "$covs_father"
local rip = r(p)
estadd scalar ri_p = `rip' : PE_`yv'
hdid_m `yv' "$covs_father" "fathersPE" "Event Study for Pre-Expansion Group (0-350% FPL)"
estadd scalar mbreak = r(mbreak) : PE_`yv'
restore

* === Spec 9: Synthetic DiD (Arkhangelsky et al. 2021) ===
preserve
	set seed 12345    
	collapse (mean) `yv' $covs_father [pw=perwt], by(statefip year)
	gen byte treat_2 = (statefip == 50 & year == 2024)
	xtset statefip year
	display "`yv': Synthetic DiD"
	sdid `yv' statefip year treat_2, vce(placebo) reps(100) ///
		covariates($covs_father, projected)
	estimates store SDD_`yv'
restore
*=================================
* Table of Regressions Outputs *
*=================================
esttab DR_`yv' D3_`yv' EG_`yv' SF_`yv' YF_`yv' using "$PROJ/scripts/stata/_outputs/regresults_fathers_`yv'.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ATT DDD_treat ATT treat_2 ATT) drop(_cons) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ATT "ATT") eqlabels(none) ///
	mtitles("Doubly Robust DiD" "Triple Differences" "DR: Expansion Group Only" "DR: Single Fathers Only" "DR: Young Fathers Only") ///
	stats(mbreak ri_p N, fmt(%9.2f %9.3f %14.0fc) labels("HonestDiD breakdown $\bar{M}$" "Randomization Inference p" "Observations")) nonumbers

esttab YC_`yv' FT_`yv' PT_`yv' PE_`yv' SDD_`yv' using "$PROJ/scripts/stata/_outputs/regresults_fathers_`yv'_2.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ATT DDD_treat ATT treat_2 ATT) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ATT "ATT") eqlabels(none) ///
	mtitles("DR: Fathers of Young Children Only" "DR: Full Time Employment" "DR: Part Time Employment" "DR: Pre-Expansion" "Synthetic DiD") ///
	stats(mbreak ri_p N, fmt(%9.2f %9.3f %9.0fc) labels("HonestDiD breakdown $\bar{M}$" "Randomization Inference p" "Observations")) nonumbers


}
}
frame drop new //drop the frame
