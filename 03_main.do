/*------------------------------------------------------------
File:       03_main.do
Purpose:    Main Regression
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
//-----------------------------------------------------------
* Estimator / inference choices (pre-committed; do NOT estimator-shop):
*   dripw -> Sant'Anna-Zhao doubly-robust IPW (the standard DR DiD estimator).
*   The drdid lines report the point estimate only; no cluster()/wboot, because
*     treatment is ONE state (VT) = a single treated cluster, where neither the
*     analytic clustered SE nor the wild cluster bootstrap is valid (MacKinnon-
*     Webb 2017/2018: severe under-rejection with one treated cluster).
*   INFERENCE is design-based: placebo-in-space / randomization inference across
*     the states (program permdid below). With 11 states the minimum attainable
*     two-sided p-value is 1/11 = 0.091.
//-----------------------------------------------------------

*Load data
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"
use "$PROJ/data/clean/cleaned_dataset.dta", clear

*drop dummy vars and set covariates
drop white
gen double age2 = age^2

local covs_main age2 single_mother black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural
local covs_sm  age2 black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural

*===========Triple Diff=========*
gen DDD_treat = (statefip == 50) & (year == 2024) & (mother_elig == 1)
reghdfe lf_indicator DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#year year#mother_elig)
			   
*=== Spec 1: all eligible mothers ===
keep if mother_elig == 1
preserve
keep if inlist(year, 2022, 2023, 2024)        // 2022 = pre, 2023/24 = post
gen byte period = year >= 2023                  // 0 = pre, 1 = pooled post
drdid lf_indicator `covs_main' [iw=perwt], time(period) tr(Treat) dripw
restore
drdid lf_indicator `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw

* --- Synthetic DiD (Arkhangelsky et al. 2021) ---
preserve
	collapse (mean) lf_indicator `covs_main' [aw=perwt], by(statefip year)
	* Restrict to the chosen pre/post window (>=2 pre-periods needed for time weights):
	* keep if inrange(year, 2019, 2024)
	gen byte treat_2 = (statefip == 50 & year == 2024) 
	xtset statefip year
	sdid lf_indicator statefip year treat_2, vce(placebo) reps(100) ///
		covariates(`covs_main', projected)
restore

*Failed Permutation attempt*
local state_var statefip
local true_treated 50
local total_reps 0
drdid lf_indicator `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw cluster(`state_var')
local true_att = e(b)[1,1]
tempname r_results
tempfile permanent_results
postfile `r_results' placebo_att using "`permanent_results'", replace
levelsof `state_var', local(all_states)
local total_reps : word count `all_states'
preserve 
foreach v of local all_states {
if `v' == `true_treated' continue
	qui {
		gen fake_treat = (`state_var' == `v')
		capture drdid lf_indicator `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(fake_treat) dripw cluster(`state_var')
		if _rc == 0 {
			matrix b_placebo = e(b)
			local p_att = b_placebo[1,1]
			post `r_results' (`p_att')
			}
			drop fake_treat
	}
}
postclose `r_results'
restore
preserve
    use "`permanent_results'", clear
   
    * Calculate the exact two-sided p-value
    * Formula: (Number of placebos as or more extreme than True ATT) / Total valid placebos
    gen extreme = (abs(placebo_att) >= abs(`true_att'))
    qui sum extreme
    local ri_p_value = r(mean)
   
    * Display the Results
    di _n(2) "{hline 60}"
    di " RANDOMIZATION INFERENCE RESULTS"
    di "{hline 60}"
    di " True Estimated ATT:   " %8.4f `true_att'
    di " RI-Based p-value:     " %8.4f `ri_p_value'
    di " Total Placebo Reps:   " r(N)
    di "{hline 60}"
   
    * Optional: Visualizing the distribution of placebos against your true effect
    twoway (kdensity placebo_att, color(navy%60) xline(`true_att', lcolor(red) lwidth(medthick))) ///
        (scatteri 0 `true_att', msymbol(none) mlabel("True ATT") mlabcolor(red)), ///
        title("Empirical Distribution of Placebo ATTs") xtitle("Placebo Coefficients") legend(off)
restore

* === Spec 2: only expansion group ===
preserve
keep if expansion_group == 1
drdid lf_indicator `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw
restore

*=== Spec 3: only single mothers ===
preserve
keep if single_mother == 1 & mother_elig == 1
drdid lf_indicator `covs_sm' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw
restore

*====Spec 4: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid lf_indicator `covs_main' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(Treat) dripw
restore 

 *=== Synthetic control (aggregate state-year panel) ===
preserve
xtset, clear
collapse (mean) `covs_main' lf_indicator [aw=perwt], by(statefip year)
egen pseudotime = group(year)
xtset statefip pseudotime
tsfill, full
* synth's keep() re-parses the filename and breaks on spaces in $PROJ;
* cd into the output dir so keep() sees a space-free relative filename.
local here "`c(pwd)'"
qui cd "$PROJ/scripts/stata/_outputs"
synth lf_indicator lf_indicator(1) lf_indicator(2) lf_indicator(3) lf_indicator(4) lf_indicator(5) ///
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
