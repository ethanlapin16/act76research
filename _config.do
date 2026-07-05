/*------------------------------------------------------------
File:       _config.do
Purpose:    More Easily Define Covariates
Run order:  Run by all regression scripts
------------------------------------------------------------*/
global PROJ "/Users/ethanlapin/Desktop/Summer Research 26/Data and Code/my-project"
use "$PROJ/data/clean/cleaned_dataset.dta", clear

//don't include white, will dummy var trap
global covs_main age age2 single_mother black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural married nchild
global covs_sm  age age2 black aian asian otherr mixedr hispanic ///
	           is_citizen diploma associate bachelor high_degree rural married nchild
