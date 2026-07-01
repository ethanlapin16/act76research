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

* Project root (edit this line if the repo moves) *
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"

cap mkdir "$PROJ/scripts/stata/_outputs"

* Loading Data *
cd "$PROJ/data/raw"
do "$PROJ/scripts/stata/usa_00005.do"

*Drop Non-comparison states and years

//drop if inlist(year, 2018, 2019, 2021, 2022) //optional command to drop years as needed
// keep if inlist(statefip, 50, 46, 56, 44, 20, 30, 19, 08) // Keeps only VT and controls *50 = vermont, fully define
// drop if inlist(statefip, 02, 15, 23, 24, 25, 33, 35, 51, 36, 06) //drop Maine, Maryland, Mass, NH, NM, Virginia, NY, California, AK, HI  

*6.25 control set*
keep if inlist(statefip, 50, 30, 55, 27, 42, 46, 19, 56, 41, 09, 44) // keeps VT, MT, WI, MN, PA, SD, IA, WY, OR, CT & RI (for regional effects)

*Define Vermont Treatment Group*
gen byte Treat = (statefip == 50) // generates treatment group for Vermont
gen byte treat_2 = (Treat == 1 & year == 2024) //defines treatment group and timing

*=====================
*Prep Explanatory Vars*
*=====================

gen byte mother = (sex == 2 & nchild > 0)
label var mother "Women with at least one own child in household"
gen byte mother_young = (sex == 2 & nchlt5 > 0)
label var mother_young "Mothers with at least one child under 5 in HH"
gen byte mother_cqual = (sex == 2 & yngch < 13) // MIGHT NEED TO RECODE TO DROP 6 MONTHS
label var mother_cqual "Mother with child who qualifies for subsidy"
replace ftotinc = . if ftotinc == 9999999 //blank missing family income values

*Recover the Census poverty threshold by inverting IPUMS POVERTY (= 100*income/threshold)

gen double povline = 100 * ftotinc / poverty if inrange(poverty, 50, 500) // recovered threshold per family
bysort year famsize nchild: egen double fpl = median(povline) // threshold by year x family config
gen double pct_fpl = 100 * ftotinc / fpl
gen byte elig_subsidy = (pct_fpl <= 575) if !missing(pct_fpl) & poverty > 0 // restrict to poverty universe
gen byte mother_elig = (mother_cqual == 1 & elig_subsidy == 1)
gen byte expansion_group = inrange(pct_fpl, 350, 575) & mother_cqual == 1 & !missing(pct_fpl) //defines the expansion group for Act 76
///
label var pct_fpl "Family income as % of FPL"
label var elig_subsidy "Family income as % of FPL ≤ 575%"
label var mother_elig "Mother who is eligible for subsidy"
label var expansion_group "Mother between 350 and 575% FPL"

*=====================
*Prep Covariates*
*=====================

*--- Person-level indicators  ---
gen byte white = (race == 1 & hispan == 0) //needs dropping later 
gen byte black = (race == 2 & hispan == 0)
gen byte aian  = (race == 3 & hispan == 0)
gen byte asian = inrange(race, 4, 6) & hispan == 0
gen byte otherr = (race == 7 & hispan == 0)
gen byte mixedr = (race >= 8 & hispan == 0)
gen byte hispanic = inrange(hispan, 1, 4)
gen byte in_poverty = (poverty > 0 & poverty < 100)
gen byte is_woman = (sex == 2)
gen byte is_citizen = inlist(citizen, 0, 1, 2)
gen byte married = (marst == 1) // if it's 2, spouse is absent
gen byte in_school = (school == 2)
gen byte diploma = (educd == 063)
gen byte associate = (educd == 081)
gen byte bachelor = (educd == 101)
gen byte high_degree = inlist(educd, 114, 115, 116)
gen byte rural = (metro == 1)
gen byte under_6 = (age < 6)
gen byte prime_age = inrange(age, 25, 54)                          // prime working age
gen byte single_mother = (mother == 1 & inlist(marst, 3, 4, 5, 6)) // mother, not currently married (sep/div/wid/never)

*--- Weighted state-year shares over TOTAL population ---*
bysort statefip year: egen double pop = total(perwt) //generates a population estimate from weights 
foreach v in white black aian asian otherr mixedr hispanic in_poverty is_woman is_citizen in_school rural under_6 prime_age {
    bysort statefip year: egen double _num = total(perwt * `v')
    gen pct_`v' = 100 * _num / pop
    drop _num
}
rename pct_in_poverty pct_poverty
rename pct_is_woman pct_female

*--- Weighted state-year shares over restricted population (adults 25+) ---*
gen byte adult25 = (age >= 25)
bysort statefip year: egen double pop_adult = total(perwt * adult25)
foreach v in diploma associate bachelor high_degree married single_mother {
    bysort statefip year: egen double _num = total(perwt * `v' * adult25)
    gen pct_`v' = 100 * _num / pop_adult
    drop _num
}

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
gen byte fulltime = (uhrswork >= 35) if uhrswork > 0
label var fulltime "Usually works full-time (>=35 hrs/wk), workers only"
gen byte parttime = (uhrswork < 35) if uhrswork > 0
label var parttime "Usually works part-time (< 35 hrs/wk), workers only"
gen double lhours = ln(uhrswork) if uhrswork > 0
label var lhours "Log usual hours worked per week (workers only)"

* Weeks worked last year (WKSWORK1, continuous)
gen wkswork = wkswork1 if wkswork1 > 0
label var wkswork "Weeks worked last year (workers only)"

* Wage & salary income (INCWAGE; clean N/A 999999 & missing 999998), and its log
replace incwage = . if inlist(incwage, 999998, 999999)
gen double learnings = ln(incwage) if incwage > 0
label var learnings "Log wage & salary income (earners only)"

*Median Household Income (household-level, N/A cleaned)*
replace hhincome = . if hhincome == 9999999          // IPUMS N/A code
gen double _hhinc = hhincome if pernum == 1          // one record per household, not per person
bysort statefip year: egen double median_income = median(_hhinc)
drop _hhinc
label var median_income "Median household income (state-year, households; unweighted)"

*HH Income in Thousands  
gen double hhincome_k = hhincome / 1000 
label var hhincome_k "household income in thousands"

*---Additional state-year aggregates---*
* Single mothers as a share of all mothers (mechanism-relevant family structure)
bysort statefip year: egen double _nmom = total(perwt * mother)
bysort statefip year: egen double _nsm  = total(perwt * single_mother)
gen pct_single_mom = 100 * _nsm / _nmom
drop _nmom _nsm


* Mean own children per household (counted once per household via pernum==1, hhwt-weighted)
bysort statefip year: egen double _kidssum = total(hhwt * nchild * (pernum == 1))
bysort statefip year: egen double _hhsum   = total(hhwt * (pernum == 1))
gen double mean_own_children = _kidssum / _hhsum
drop _kidssum _hhsum
label var mean_own_children "Mean own children per household (state-year)"

* Log state population 
gen double log_pop = ln(pop)
label var log_pop "Log state population (state-year)"

*---Label % Variables---*
label var pct_white    "White alone, non-Hispanic (% of state pop)"
label var pct_black    "Black alone, non-Hispanic (% of state pop)"
label var pct_aian     "American Indian/Alaska Native, non-Hispanic (% of state pop)"
label var pct_asian    "Asian/Pacific Islander, non-Hispanic (% of state pop)"
label var pct_otherr   "Other race, non-Hispanic (% of state pop)"
label var pct_mixedr   "Two or more races, non-Hispanic (% of state pop)"
label var pct_hispanic "Hispanic, any race (% of state pop)"
label var pct_poverty  "Poverty rate (% of state pop)"
label var pct_female   "Female (% of state pop)"
label var pct_is_citizen "U.S. citizen (% of state pop)"
label var pct_in_school  "In school (% of state pop)"
label var pct_rural      "Not in metro area (% of state pop)"
label var pct_diploma     "Highest = HS diploma (% of adults 25+)"
label var pct_associate   "Highest = Associate degree (% of adults 25+)"
label var pct_bachelor    "Highest = Bachelor's degree (% of adults 25+)"
label var pct_high_degree "Graduate/professional degree (% of adults 25+)"
label var pct_married     "Currently married (% of adults 25+)"
label var pct_under_6	"Under 6 (% of State Pop)"
label var pct_prime_age "Prime age 25-54 (% of state pop)"
label var pct_single_mom "Single mothers (% of all mothers)"

*====================
* Save Cleaned Data *
*====================

* Drop aggregation helpers
drop pop pop_adult adult25 labor_force total_unemployed

save "$PROJ/data/clean/cleaned_dataset.dta", replace
