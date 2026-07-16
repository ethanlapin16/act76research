/*------------------------------------------------------------
File:       04_act45pooled.do
Purpose:    Act 45 pooled-post DR-DiD on eligible mothers
			with RI-t p-values (rit_45) and HonestDiD M-bar (hdid_45).
Inputs:     data/clean/cleaned_dataset.dta (via _config.do)
Outputs:    scripts/stata/_outputs/regresults_a45pool_*.tex
            Figures/eventstudy_a45*_*.pdf
Run order:  After 03, secondary regressor
------------------------------------------------------------*/
version 19                        // pin Stata semantics
clear all
set more off
set seed 12345                    // determinism for any random ops
set sortseed 12345                // stable sort ties across versions
cap log close
cap log close _all
estimates clear

*Load data*
do "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project/scripts/stata/_config.do"

*IMPORTANT: FRAME*
frame put $keepvars, into(new)
frame new {

*==========Establish Pool & Prep ==================*
drop if year == 2024
gen byte period = year >= 2022   // 0 = pre, 1 = pooled post
replace period = . if inlist(year, 2018, 2019)
keep if mother_elig == 1
gen byte band_45 = (pct_fpl < 350)
keep if band_45 == 1
gen int gvar = 0
replace gvar = 2022 if Treat == 1 & band_45 == 1

*===Cycle Specs on Y-Vars===*
foreach yv in uhrswork {

* === Spec 1: all eligible mothers ===
display "`yv': All Eligible Mothers"
drdid `yv' $covs_main if inlist(period, 0, 1) [iw=perwt], time(period) tr(Treat) drimp
estimates store DR_`yv'
rit_45 `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : DR_`yv'
hdid_45 `yv' "$covs_main" "a45DR" "Event Study for All Eligible Mothers"
estadd scalar mbreak = r(mbreak) : DR_`yv' //DR-DiD ITT equals the CS event-study effect at t=0; HonestDiD is applied to that estimate

* === Spec 2: only single mothers ===
preserve
keep if single_mother == 1
display "`yv': Only Single Mothers"
drdid `yv' $covs_sm if inlist(period, 0, 1) [iw=perwt], time(period) tr(Treat) drimp
estimates store SM_`yv'
rit_45 `yv' "$covs_sm"
local rip = r(p)
estadd scalar ri_p = `rip' : SM_`yv'
hdid_45 `yv' "$covs_sm" "a45SM" "Event Study for Single Mothers"
estadd scalar mbreak = r(mbreak) : SM_`yv'
restore

* === Spec 3: young mothers ===
preserve
keep if inrange(age, 18, 28)
display "`yv': Only Young Mothers"
drdid `yv' $covs_main if inlist(period, 0, 1) [iw=perwt], time(period) tr(Treat) drimp
estimates store YM_`yv'
rit_45 `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : YM_`yv'
hdid_45 `yv' "$covs_main" "a45YM" "Event Study for Young Mothers"
estadd scalar mbreak = r(mbreak) : YM_`yv'
restore

* === Spec 4: mothers of young children ===
preserve
keep if mother_young == 1
display "`yv': Mothers of Young Children"
drdid `yv' $covs_main if inlist(period, 0, 1) [iw=perwt], time(period) tr(Treat) drimp
estimates store YC_`yv'
rit_45 `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : YC_`yv'
hdid_45 `yv' "$covs_main" "a45YC" "Event Study for Mothers of Young Children"
estadd scalar mbreak = r(mbreak) : YC_`yv'
restore

*===Spec 5: mothers who work full time ===
preserve
keep if fulltime == 1
display "`yv': Mothers who work full time"
drdid `yv' $covs_main if inlist(period, 0, 1) [iw=perwt], time(period) tr(Treat) drimp
estimates store FT_`yv'
rit_45 `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : FT_`yv'
hdid_45 `yv' "$covs_main" "a45FT" "Event Study for Full-Time Working Mothers"
estadd scalar mbreak = r(mbreak) : FT_`yv'
restore

*===Spec 6: mothers who work part time ===
preserve
keep if parttime == 1
display "`yv': Mothers who work part time"
drdid `yv' $covs_main if inlist(period, 0, 1) [iw=perwt], time(period) tr(Treat) drimp
estimates store PT_`yv'
rit_45 `yv' "$covs_main"
local rip = r(p)
estadd scalar ri_p = `rip' : PT_`yv'
hdid_45 `yv' "$covs_main" "a45PT" "Event Study for Part-Time Working Mothers"
estadd scalar mbreak = r(mbreak) : PT_`yv'
restore

*=================================
* Table of Regressions Outputs *
*=================================
esttab DR_`yv' SM_`yv' YM_`yv' using "$PROJ/scripts/stata/_outputs/regresults_a45pool_`yv'.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ITT) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ITT "ITT") eqlabels(none) ///
	mtitles("Doubly Robust DiD" "DR: Single Mothers Only" "DR: Young Mothers Only") ///
	stats(mbreak ri_p N, fmt(%9.2f %9.3f %14.0fc) labels("HonestDiD breakdown $\bar{M}$" "Randomization Inference $p$" "Observations")) nonumbers

esttab YC_`yv' FT_`yv' PT_`yv' using "$PROJ/scripts/stata/_outputs/regresults_a45pool_`yv'_2.tex", ///
	replace booktabs label ///
	rename(r1vs0.Treat ITT) ///
	b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
	coeflabel(ITT "ITT") eqlabels(none) ///
	mtitles("DR: Mothers of Young Children Only" "DR: Full Time Employment" "DR: Part Time Employment") ///
	stats(mbreak ri_p N, fmt(%9.2f %9.3f %14.0fc) labels("HonestDiD breakdown $\bar{M}$" "Randomization Inference p" "Observations")) nonumbers

}
}
frame drop new //drop the frame
