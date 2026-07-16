/*------------------------------------------------------------
File:       01_loadclean.do
Purpose:    Load IPUMS ACS extract, restrict to VT + control states,
            and build analysis variables & covariates
Inputs:     data/raw/usa_00005.* (loaded via usa_00005.do)
Outputs:    data/clean/cleaned_dataset.dta
Run order:  First
------------------------------------------------------------*/

version 19                        // pin Stata semantics
clear all
set more off
set seed 12345                    // determinism for any random ops
set sortseed 12345                // stable sort ties across versions
cap log close
cap log close _all


global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"
cap mkdir "$PROJ/scripts/stata/_outputs"
* Loading Data *
cd "$PROJ/data/raw"
do "$PROJ/scripts/stata/usa_00005.do"
compress

// log using "$PROJ/scripts/stata/logs/01_log.log", text replace
*Drop Non-comparison states and years

//drop if inlist(year, 2018, 2019, 2021, 2022) //optional command to drop years as needed
// keep if inlist(statefip, 50, 46, 56, 44, 20, 30, 19, 08) // Keeps only VT and controls *50 = vermont, fully define
drop if inlist(statefip, 02, 15, 23, 24, 25, 33, 35, 51, 36, 06, 34, 09, 44, 27, 08, 11) //drop Maine, Maryland, Mass, NH, NM, Virginia, NY, California, AK, HI, NJ, CT, RI, MN, CO, DC

// *6.25 control set*
// keep if inlist(statefip, 50, 30, 55, 27, 42, 46, 19, 56, 41, 09, 44) // keeps VT, MT, WI, MN, PA, SD, IA, WY, OR, CT & RI (for regional effects)
// *7.14 controls*
// keep if inlist(statefip, 50, 49, 30, 38, 56, 08)

*Define Vermont Treatment Group*
gen byte Treat = (statefip == 50) // generates treatment group for Vermont

*=====================
*Prep Explanatory Vars*
*=====================

gen byte mother = (sex == 2 & nchild > 0)
gen byte mother_young = (mother == 1 & nchlt5 > 0)
gen byte mother_cqual = (mother == 1 & yngch <= 13)
gen byte father = (sex == 1 & nchild > 0)
gen byte father_young = (father == 1 & nchlt5 > 0)
gen byte father_cqual = (father == 1 & yngch <= 13)
label var mother_cqual "Mother with child who qualifies for subsidy"
label var mother_young "Mothers with at least one child under 5 in HH"
label var mother "Women with at least one own child in household"

*Recover the Census poverty threshold by inverting IPUMS POVERTY, which relies on family income
replace ftotinc = . if ftotinc == 9999999 //blank missing family income values
gen double povline = 100 * ftotinc / poverty if inrange(poverty, 50, 500) // recovered threshold per family
bysort year famsize nchild: egen double fpl = median(povline) // threshold by year x family config
gen double pct_fpl = 100 * ftotinc / fpl
gen byte elig_subsidy = (pct_fpl <= 575) if !missing(pct_fpl) & poverty > 0 // restrict to poverty universe
gen byte mother_elig = (mother_cqual == 1 & elig_subsidy == 1)
gen byte father_elig = (father_cqual == 1 & elig_subsidy == 1)
gen byte expansion_group = inrange(pct_fpl, 351, 575) & mother_cqual == 1 & !missing(pct_fpl) & poverty > 0 //defines the expansion group for Act 76
gen byte expansion_group_f = inrange(pct_fpl, 351, 575) & father_cqual == 1 & !missing(pct_fpl) & poverty > 0 // expansion group for fathers 
label var pct_fpl "Family income as % of FPL"
label var elig_subsidy "Family income as % of FPL ≤ 575%"
label var mother_elig "Mother who is eligible for subsidy"
label var expansion_group "Mother between 350 and 575% FPL"

*=====================
*Prep Covariates*
*=====================

*--- Person-level indicators  ---
gen byte white = (race == 1 & hispan == 0) // make sure to drop from cov list
gen byte black = (race == 2 & hispan == 0)
gen byte aian  = (race == 3 & hispan == 0)
gen byte asian = inrange(race, 4, 6) & hispan == 0
gen byte otherr = (race == 7 & hispan == 0)
gen byte mixedr = (race >= 8 & hispan == 0)
gen byte hispanic = inrange(hispan, 1, 4)
gen byte female = (sex == 2)
gen byte is_citizen = inlist(citizen, 0, 1, 2)
gen byte married = (marst == 1) // if it's 2, spouse is absent
gen byte in_school = (school == 2)
gen byte diploma = (educd == 063)
gen byte associate = (educd == 081)
gen byte bachelor = (educd == 101)
gen byte high_degree = inlist(educd, 114, 115, 116)
gen byte rural = (metro == 1)
gen byte single_mother = (mother == 1 & inlist(marst, 2, 3, 4, 5, 6)) // mother, not currently married or with partner (sep/div/wid/never)
gen byte single_father = (father == 1 & inlist(marst, 2, 3, 4, 5, 6))
gen int age2 = age^2
bysort statefip year: egen double pop = total(perwt) //generates a population estimate from weights

* Age^2 For Covariates*


// *--- Industry sector dummies (from IPUMS IND) ---*
// gen indcat = .
// replace indcat = 1  if inrange(ind, 170, 490)     // Agriculture, forestry, fishing, mining
// replace indcat = 2  if inrange(ind, 570, 690)     // Utilities
// replace indcat = 3  if ind == 770                  // Construction
// replace indcat = 4  if inrange(ind, 1070, 3990)   // Manufacturing
// replace indcat = 5  if inrange(ind, 4070, 4590)   // Wholesale trade
// replace indcat = 6  if inrange(ind, 4670, 5791)   // Retail trade
// replace indcat = 7  if inrange(ind, 6070, 6390)   // Transportation & warehousing
// replace indcat = 8  if inrange(ind, 6470, 6781)   // Information
// replace indcat = 9  if inrange(ind, 6870, 6992)   // Finance & insurance
// replace indcat = 10 if inrange(ind, 7071, 7190)   // Real estate & rental/leasing
// replace indcat = 11 if inrange(ind, 7270, 7790)   // Professional/admin/waste mgmt
// replace indcat = 12 if inrange(ind, 7860, 7890)   // Educational services
// replace indcat = 13 if inrange(ind, 7970, 8470)   // Health care & social assistance
// replace indcat = 14 if inrange(ind, 8560, 8590)   // Arts, entertainment, recreation
// replace indcat = 15 if inrange(ind, 8660, 8690)   // Accommodation & food services
// replace indcat = 16 if inrange(ind, 8770, 9290)   // Other services
// replace indcat = 17 if inrange(ind, 9370, 9590)   // Public administration
// replace indcat = 18 if inrange(ind, 9670, 9870)   // Military
// replace indcat = 0  if ind == 0 | ind == 9920      // N/A, unemployed/never worked
//
// label define indcat_lbl 0 "N/A" 1 "Ag/Mining" 2 "Utilities" 3 "Construction" ///
//   4 "Manufacturing" 5 "Wholesale" 6 "Retail" 7 "Transport" 8 "Information" ///
//   9 "Finance" 10 "RealEstate" 11 "Professional" 12 "Education" 13 "Health" ///
//   14 "Arts" 15 "Accommodation" 16 "OtherSvc" 17 "PublicAdmin" 18 "Military"
// label values indcat indcat_lbl
// label var indcat "Broad industry sector (from IPUMS IND)"
// qui tab indcat, gen(indd)   // indd1 = N/A, indd2..indd19 = sectors

*---Economic Indicators---*
*Unemployment Rate*
gen byte unemp_indicator = (empstat == 2)
gen byte lf_indicator = (labforce == 2)
label var lf_indicator "Indicator of whether one is in the labor force"
bysort statefip year: egen labor_force = total(perwt * lf_indicator)
bysort statefip year: egen total_unemployed = total(perwt * unemp_indicator)
gen unemp_rate = 100 * total_unemployed / labor_force
label var unemp_rate "Unemployment rate (% of labor force)"

*---Labor-Market Outcomes (dependent variables)---*
gen byte employed = (empstat == 1)
label var employed "Employed (=1)"

* Usual hours/week (UHRSWORK; 0 = not working/NA). Logs & full-time among workers.
replace uhrswork = . if uhrswork == 00
gen byte fulltime = (uhrswork >= 35) if uhrswork > 0
label var fulltime "Usually works full-time (>=35 hrs/wk), workers only"
gen byte parttime = (uhrswork < 35) if uhrswork > 0
label var parttime "Usually works part-time (< 35 hrs/wk), workers only"
gen double lhours = ln(uhrswork) if uhrswork > 0
label var lhours "Log usual hours worked per week (workers only)"

* Weeks worked last year (WKSWORK1, continuous)
gen byte wkswork = wkswork1 if wkswork1 > 0
label var wkswork "Weeks worked last year (workers only)"

// *Median Household Income (household-level, N/A cleaned)* // chokes the fuck out of code
// replace hhincome = . if hhincome == 9999999          // IPUMS N/A code
// gen double _hhinc = hhincome if pernum == 1          // one record per household, not per person
// bysort statefip year: egen double median_income = median(_hhinc)
// drop _hhinc
// label var median_income "Median household income (state-year, households; unweighted)"

*HH Income in Thousands  
gen double hhincome_k = hhincome / 1000 
label var hhincome_k "household income in thousands"

* Log Wage Income
replace incwage = . if inlist(incwage, 999998, 999999) // IPUMS N/A and Missing
gen double lincome = ln(incwage) if incwage > 0
label var lincome "Log individual wage income"

*External Income*
gen long extincome = ftotinc - incwage if !missing(ftotinc)
replace extincome = ftotinc if missing(incwage)
gen double extincome_k = extincome/1000 if extincome > 0
label var extincome "Family income net of own earnings"
label var extincome_k "Family income net of own earnings in thousands"
*---Additional state-year aggregates---*

* Child Related Vars
bysort statefip year: egen double _kidssum = total(hhwt * nchild * (pernum == 1))
bysort statefip year: egen double _hhsum   = total(hhwt * (pernum == 1))
gen double mean_own_children = _kidssum / _hhsum
drop _kidssum _hhsum
label var mean_own_children "Mean own children per household (state-year)"
gen byte yngch_u3 = inrange(yngch, 0, 2)   // infant/toddler
gen byte yngch_35 = inrange(yngch, 3, 5)   // preschool
label var yngch_u3 "Youngest child aged 0-2"
label var yngch_35 "Youngest child aged 3-5"

* Log state population 
gen double log_pop = ln(pop)
label var log_pop "Log state population (state-year)"

*====================
* Save Cleaned Data *
*====================

* Drop aggregation helpers
drop pop labor_force total_unemployed

*Optional compress to check my work*
compress

save "$PROJ/data/clean/cleaned_dataset.dta", replace
// log close
