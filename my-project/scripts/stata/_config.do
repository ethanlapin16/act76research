/*------------------------------------------------------------
File:       _config.do
Purpose:    Load data, define covariate globals, and define shared
            programs (rit_p: MacKinnon-Webb RI-t p-value;
            hdid_m: HonestDiD breakdown M-bar;
            rit_45 / hdid_45: Act-45 (pooled, gvar=2022) analogues).
Run order:  Run by all regression scripts (after their clear all)
------------------------------------------------------------*/
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"
use "$PROJ/data/clean/cleaned_dataset.dta", clear
* Keep only the variables you need for analysis, this just has to be a running list* 
* without this, my M2 Macbook Air's RAM gets choked running regressions, but if you*
* have a more capable computer, this can be omitted*
global keepvars ///
    statefip year perwt Treat ///
    lf_indicator lhours uhrswork ///
    age age2 single_mother single_father black aian asian otherr mixedr hispanic ///
    is_citizen diploma associate bachelor high_degree rural nchild ///
    mother_elig father_elig mother_young father_young ///
    expansion_group expansion_group_f fulltime parttime mother ///
    pct_fpl 

//don't include white, will dummy var trap
global covs_main age age2 single_mother black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural nchild
			   
global covs_sm  age age2 black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural nchild 
			   
global covs_father age age2 single_father black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural nchild

*--- RI-t p-value (MacKinnon & Webb 2019): exact enumeration over the G ---*
*--- single-state assignments; cluster-robust t as the test statistic.    ---*
*--- Call on a sample already restricted to the 2 estimation years.        ---*
cap program drop rit_p
program define rit_p, rclass
    args y covs
    tempvar post pt
    tempname T
    qui levelsof statefip if Treat == 0, local(ctrls) // saves all non treated states into a list of controls
    local states 50 `ctrls'                       // builds a list of all states, w/Vermont first
    local G : word count `states'				 // save WC of that state list 
    matrix `T' = J(`G', 1, .)					//constructs a matrix of values for each state
    local i = 0
    foreach s of local states {
        local ++i
        cap drop `pt'
        gen byte `pt' = (statefip == `s') //creates a new treatment variable for each state in the list
		cap qui drdid `y' `covs' if inlist(year, 2023, 2024) [iw=perwt], time(year) tr(`pt') drimp // quitely runs the DR DiD
        if _rc == 0 & el(e(V),1,1) < . & el(e(V),1,1) > 0 ///
        matrix `T'[`i',1] = el(e(b),1,1)/sqrt(el(e(V),1,1)) //if there is an output, computes t statistic for just the treatment indicator, puts it into T
    }
    local c = 0 // number of more extreme observations 
    local nv = 0 // number of valid observations counter
    forvalues r = 1/`G' {
        if !missing(`T'[`r',1]) { //if there is a T stat filled into the T matrix, proceed
            local ++nv // increase number of valid observations 
            if abs(`T'[`r',1]) >= abs(`T'[1,1]) local ++c // if more extreme than the T-stat for Vermont, increase C
        }
    }
    return scalar p = `c'/`nv'                     // creates p value from c/nv
end

*--- HonestDiD breakdown M-bar (Rambachan & Roth 2023): run the CS event  ---*
*--- study, export the event-study plot, apply honestdid, return the      ---*
*--- smallest M-bar whose robust CI still covers 0. Args: outcome, covs,   ---*
*--- tag (filename), title (plot). Needs full panel (>=4 pre-periods).     ---*
cap program drop hdid_m
program define hdid_m, rclass
    args y covs tag title
    qui csdid `y' `covs' [iw=perwt], time(year) gvar(gvar) method(drimp) long2
    estat event
    csdid_plot, ///
        title("`title'") ///
        xtitle("Years Relative to Act 76 Enactment") ///
        ytitle("Effect on `y'") ///
        yline(0, lpattern(dash) lcolor(gs8)) ///
        legend(off) ///
        scheme(s2color)
    graph export "$PROJ/Figures/eventstudy_`tag'_`y'.pdf", replace
    set seed 12345
    honestdid, l_bounds(-1) u_bounds(1) numpre(4) ///
               delta(rm) bptype(hybrid) ///
               preplotcoefs(-6 -5 -3 -2) postplotcoefs(0) mvec(0(0.1)2)
    tempname CI
    qui mata: st_matrix("`CI'", `s(HonestEventStudy)'.CI)
    scalar mbreak = .
    forvalues i = 1/`=rowsof(`CI')' {         // cols: 1 M-bar, 2 lower CI, 3 upper CI
        if !missing(`CI'[`i',1]) & `CI'[`i',2] <= 0 & `CI'[`i',3] >= 0 & missing(mbreak) {
            scalar mbreak = `CI'[`i',1]
        }
    }
	graph drop _all  
    return scalar mbreak = mbreak
end


*Rit_p for act 45*
cap program drop rit_45
program define rit_45, rclass
    args y covs
    tempvar post pt
    tempname T
    qui levelsof statefip if Treat == 0, local(ctrls) // saves all non treated states into a list of controls
    local states 50 `ctrls'                       // builds a list of all states, w/Vermont first
    local G : word count `states'				 // save WC of that state list 
    matrix `T' = J(`G', 1, .)					//constructs a matrix of values for each state
    local i = 0
    foreach s of local states {
        local ++i
        cap drop `pt'
        gen byte `pt' = (statefip == `s') //creates a new treatment variable for each state in the list
		cap qui drdid `y' `covs' if inlist(period, 0, 1) [iw=perwt], time(period) tr(`pt') drimp // quitely runs the DR DiD
        if _rc == 0 & el(e(V),1,1) < . & el(e(V),1,1) > 0 ///
        matrix `T'[`i',1] = el(e(b),1,1)/sqrt(el(e(V),1,1)) //if there is an output, computes t statistic for just the treatment indicator, puts it into T
    }
    local c = 0 // number of more extreme observations 
    local nv = 0 // number of valid observations counter
    forvalues r = 1/`G' {
        if !missing(`T'[`r',1]) { //if there is a T stat filled into the T matrix, proceed
            local ++nv // increase number of valid observations 
            if abs(`T'[`r',1]) >= abs(`T'[1,1]) local ++c // if more extreme than the T-stat for Vermont, increase C
        }
    }
    return scalar p = `c'/`nv'                     // creates p value from c/nv
end

cap program drop hdid_45
program define hdid_45, rclass
    args y covs tag title
    qui csdid `y' `covs' [iw=perwt], time(year) gvar(gvar) method(drimp) long2
    estat event
    csdid_plot, ///
        title("`title'") ///
        xtitle("Years Relative to Act 45 Enactment") ///
        ytitle("Effect on `y'") ///
        yline(0, lpattern(dash) lcolor(gs8)) ///
        legend(off) ///
        scheme(s2color)
    graph export "$PROJ/Figures/eventstudy_`tag'_`y'.pdf", replace
    set seed 12345
    honestdid, l_bounds(-1) u_bounds(1) numpre(2) ///
               delta(rm) bptype(hybrid) ///
               preplotcoefs(-4 -3) postplotcoefs(0) mvec(0(0.1)2)
    tempname CI
    qui mata: st_matrix("`CI'", `s(HonestEventStudy)'.CI)
    scalar mbreak = .
    forvalues i = 1/`=rowsof(`CI')' {         // cols: 1 M-bar, 2 lower CI, 3 upper CI
        if !missing(`CI'[`i',1]) & `CI'[`i',2] <= 0 & `CI'[`i',3] >= 0 & missing(mbreak) {
            scalar mbreak = `CI'[`i',1]
        }
    }
	graph drop _all  
    return scalar mbreak = mbreak
end
