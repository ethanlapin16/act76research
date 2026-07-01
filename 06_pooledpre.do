/*------------------------------------------------------------
File:       06_main.do
Purpose:    Pooled Respec
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
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"
use "$PROJ/data/clean/cleaned_dataset.dta", clear

*drop dummy vars and set covariates
cap drop white
cap gen double age2 = age^2

local covs_main age age2 single_mother black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural
local covs_sm  age age2 black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural

*==========Establish Pool==================*
gen byte period = year >= 2023    // 0 = pre, 1 = pooled post
keep if inlist(year, 2022, 2023, 2024)        // 2022 = pre, 2023/24 = post
			   
// *===========Triple  - Runs First before restricting to only eligible mothers -=========*
// gen DDD_treat = (statefip == 50) & (period == 1) & (mother_elig == 1)
// reghdfe lf_indicator DDD_treat [pw=perwt], absorb (statefip#mother_elig statefip#period period#mother_elig)	
			   
*=== Spec 1: all eligible mothers ===
keep if mother_elig == 1
drdid lf_indicator `covs_main' [iw=perwt], time(period) tr(Treat) drimp


* === Spec 2: only expansion group ===
preserve
keep if expansion_group == 1
drdid lf_indicator `covs_main' [iw=perwt], time(period) tr(Treat) drimp
restore

*=== Spec 3: only single mothers ===
preserve
keep if single_mother == 1
drdid lf_indicator `covs_sm' [iw=perwt], time(period) tr(Treat) drimp
restore

*====Spec 4: young mothers ===
preserve
keep if inrange(age, 18, 28)
drdid lf_indicator `covs_main' [iw=perwt], time(period) tr(Treat) drimp
restore 

* === Spec 5: mothers of young children ===
preserve
keep if mother_young == 1
drdid lhours `covs_main' [iw=perwt], time(period) tr(Treat) drimp
restore
