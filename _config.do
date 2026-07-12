/*------------------------------------------------------------
File:       _config.do
Purpose:    Load data, define covariate globals, and define shared
            programs (rit_p: MacKinnon-Webb RI-t p-value;
            hdid_p: HonestDiD breakdown M-bar).
Run order:  Run by all regression scripts (after their clear all)
------------------------------------------------------------*/
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"
use "$PROJ/data/clean/cleaned_dataset.dta", clear

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
    gen byte `post' = (year == 2024)
    levelsof statefip if Treat == 0, local(ctrls)
    local states 50 `ctrls'                       // Vermont (actual) first
    local G : word count `states'
    matrix `T' = J(`G', 1, .)
    local i = 0
    foreach s of local states {
        local ++i
        cap drop `pt'
        gen byte `pt' = (statefip == `s') & `post'
        cap qui reghdfe `y' `pt' `covs' [pw=perwt], absorb(statefip year) cluster(statefip)
        if _rc == 0 cap matrix `T'[`i',1] = _b[`pt']/_se[`pt']
    }
    local c = 0
    local nv = 0
    forvalues r = 1/`G' {
        if !missing(`T'[`r',1]) {
            local ++nv
            if abs(`T'[`r',1]) >= abs(`T'[1,1]) local ++c
        }
    }
    return scalar p = `c'/`nv'                     // include-original; floor = 1/nv
end

*--- HonestDiD breakdown M-bar (Rambachan & Roth 2023): run the CS event  ---*
*--- study, export the event-study plot, apply honestdid, return the      ---*
*--- smallest M-bar whose robust CI still covers 0. Args: outcome, covs,   ---*
*--- tag (filename), title (plot). Needs full panel (>=4 pre-periods).     ---*
cap program drop hdid_p
program define hdid_p, rclass
    args y covs tag title
    qui csdid `y' `covs' [iw=perwt], time(year) gvar(gvar) method(drimp) long2
    estat event
    csdid_plot, ///
        title("`title'") ///
        xtitle("Years Relative to Act 76 Enactment") ///
        ytitle("Effect on avg. log weekly hours") ///
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
    return scalar mbreak = mbreak
end
