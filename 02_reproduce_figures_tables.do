/****************************************************************************************
 Project: Labour Market Turing Test
 Purpose: Reproduce paper figures 2 to 7 in one organized Stata do-file
 Notes:
   - Figure 1 is an infographic/table and is not generated here.
****************************************************************************************/

version 17
clear all
set more off
set seed 20250611
capture log close

*===============================================================================;
* 0. PATHS AND OUTPUT SETTINGS ;
*===============================================================================;

* Set root folder to the location where this do-file is being run.
global ROOT "c(pwd)"

* Processed data folder created by 01_build_data.do.
global DIR_IRT "$ROOT/Data/Processed"

* Output folders.
global OUT "$ROOT/Output/Figures"
global TABLEOUT "$ROOT/Output/Tables"

capture mkdir "$ROOT/Output"
capture mkdir "$OUT"
capture mkdir "$TABLEOUT"

* Optional package checks
# delimit ;

capture which coefplot ;
if _rc display as error "Package coefplot is not installed. Run: ssc install coefplot" ;

capture which esttab ;
if _rc display as error "Package estout is not installed. Run: ssc install estout" ;

graph set window fontface "Arial" ;


*===============================================================================;
* 1. IRT ESTIMATION FOR FIGURES 2 AND 7 ;
*    Data source: IRT_responsedata_question_Majority.dta ;
*===============================================================================;

cd "$DIR_IRT" ;

use "IRT_responsedata_question_Majority.dta", clear ;

merge 1:1 recruiter_id using "recruiter_type_temp.dta" ;
drop _merge ;

keep if recruiter_type=="human" ///
     | recruiter_type=="robot-gamma6" ///
     | recruiter_type=="clone-gamma2" ///
     | recruiter_type=="clone-gamma5" ///
     | recruiter_type=="randomista" ;

drop if I_noBIG5_cog==1 ;

set seed 20250611 ;
sort recruiter_id ;
set seed 20250611 ;

irt 2pl binary_M_r*,
    intmethod(mvaghermite)
    level(99)
    iterate(100)
    vce(robust)
    technique(nr)
    intpoints(20)
    difficult
    startvalues(ivloadings) ;

predict machina_latent, latent ebmeans se(latent_se) tolerance(0.0001) ;
est store irt_parameters ;
predict agree_prob, pr ;

gen precise = 1/latent_se ;

sum machina_latent [aweight=precise] if recruiter_type=="human", d ;
gen z_machina = (machina_latent - `r(mean)')/`r(sd)' ;

gen core_id = substr(recruiter_id,5,3) ;

gen recruiter = 0 if recruiter_type=="human" ;
replace recruiter = 1 if recruiter_type=="robot-gamma6" ;
replace recruiter = 2 if recruiter_type=="clone-gamma2" ;
replace recruiter = 3 if recruiter_type=="clone-gamma5" ;
replace recruiter = 4 if recruiter_type=="randomista" ;


*-------------------------------------------------------------------------------;
* FIGURE 2: SELECTED ITEM CHARACTERISTIC CURVES ;
*-------------------------------------------------------------------------------;

sum machina_latent [aweight=precise] if recruiter_type=="human" ;

sum machina_latent if recruiter_type=="human", d ;

irtgraph icc binary_M_r36 binary_M_r47,
    lcolor(stblue)
    range(-4 4)
    scheme(s1mono)
    yline(0.5, lcolor(black) lpattern(solid))
    ylabel(#10)
    xlabel(#14, nogrid)
    xline(`r(p50)', lcolor(stblue*.1) lpattern(solid) lwidth(thick))
    ytitle("Probability of selecting as AI-reference (Skynet)" " ")
    xtitle(" " "Machina trait")
    legend(pos(4) row(4)
           order(1 "Vacancy 1, Candidates A and B"
                 2 "Vacancy 2, Candidates C and D")
           region(style(none)) ring(0))
    title("  " " ")
    text(.95 -3.8 "A", size(*2.5))
;

graph save "$OUT/temp_icc_panel_A.gph", replace ;

sum machina_latent if recruiter_type=="human", d ;

irtgraph icc binary_M_r4 binary_M_r81,
    lcolor(stred)
    range(-4 4)
    scheme(s1mono)
    yline(0.5, lcolor(black) lpattern(solid))
    xline(`r(p50)', lcolor(stred*.1) lpattern(solid) lwidth(thick))
    ylabel(#10)
    xlabel(#14, nogrid)
    ytitle("Probability of selecting as AI-reference (Skynet)" " ")
    xtitle(" " "Machina trait")
    legend(pos(4) row(2)
           order(1 "Vacancy 3, Candidates E and F"
                 2 "Vacancy 4, Candidates G and H")
           region(style(none)) ring(0))
    title("  " " ")
    text(.95 -3.8 "B", size(*2.5))
;

graph save "$OUT/temp_icc_panel_B.gph", replace ;

graph combine
    "$OUT/temp_icc_panel_A.gph"
    "$OUT/temp_icc_panel_B.gph",
    rows(1)
    iscale(0.70)
    ycommon
    xcommon
;

graph export "$OUT/Figure 2.pdf", replace ;


*-------------------------------------------------------------------------------;
* FIGURE 7: DENSITY OF MACHINA TRAIT BY RECRUITER TEAM ;
*-------------------------------------------------------------------------------;

twoway
    (kdensity z_machina [aweight=precise] if recruiter_type=="robot-gamma6",
        bwidth(0.25) n(277) lcolor(gold) lpattern(dash) lwidth(thick))
    (kdensity z_machina [aweight=precise] if recruiter_type=="clone-gamma2",
        bwidth(0.25) n(277) lcolor(magenta))
    (kdensity z_machina [aweight=precise] if recruiter_type=="clone-gamma5",
        bwidth(0.25) n(277) lcolor(green) lpattern(dash_dot))
    (kdensity z_machina [aweight=precise] if recruiter_type=="human",
        bwidth(0.25) n(277) lwidth(thick) lcolor(red))
    (kdensity z_machina [aweight=precise] if recruiter_type=="randomista",
        bwidth(0.25) n(277) lcolor(blue) lpattern(dot) lwidth(thick))
,
    xline(0)
    legend(region(color(none))
           ring(0)
           pos(11)
           row(5)
           order(1 "Robots"
                 2 "Avatars"
                 3 "Clones"
                 4 "Humans"
                 5 "Randomistas"))
    ylabel(#10)
    xlabel(#14, grid)
    ytitle("Density of recruiters" " ")
    xtitle(" " "Machina (z-score)")
;

graph export "$OUT/Figure 7.pdf", replace ;


*===============================================================================;
* 2. TRIAL-LEVEL IRT PARAMETERS FOR FIGURES 3, 4, 5 AND 6 ;
*    Data source: parameters_irt_raw.dta ;
*===============================================================================;

cd "$DIR_IRT" ;

use "parameters_irt_raw.dta", clear ;

replace trial = subinstr(trial,"q","",.) ;
destring trial, replace ;
rename trial q ;

merge m:1 q using "IRT_question_coding_correspondence.dta" ;
drop _merge ;

merge m:1 job_id using "jobs.dta", keepusing(j_jobname) ;
drop _merge ;

merge 1:1 cv_pair_id using "PairedCVs_all_Ecuador.dta" ;
drop _merge ;

gen precise_d = 1/diff_se ;
gen precise_l = 1/loc_se ;

sum location [aweight=precise_l], d ;
gen z_location = (location - `r(mean)')/`r(sd)' ;

sort location q ;
cumul location, generate(cdf_loc) ;

sort different q ;
cumul different, generate(cdf_diff) ;

destring job_id, replace ;
xi, prefix(JOB) noomit i.job_id ;

replace j_jobname = "Sales Representative Vacancies" if job_id==1 ;
replace j_jobname = "Services Assistant (Janitorial) Vacancies" if job_id==2 ;
replace j_jobname = "Warehouse Assistant Vacancies" if job_id==3 ;
replace j_jobname = "Certified Accountant Vacancies" if job_id==4 ;
replace j_jobname = "Software Developer Vacancies" if job_id==5 ;
replace j_jobname = "Systems Engineer Vacancies" if job_id==6 ;
replace j_jobname = "Technical Project Manager Vacancies" if job_id==7 ;
replace j_jobname = "Call Center Operator Vacancies" if job_id==8 ;
replace j_jobname = "Manufacturing Production Supervisor Vacancies" if job_id==9 ;
replace j_jobname = "Maintenance Technician Vacancies" if job_id==10 ;


*-------------------------------------------------------------------------------;
* FIGURE 3: AVERAGE LOCATION BY JOB VACANCY TYPE ;
*-------------------------------------------------------------------------------;

regress cdf_loc
    JOBjob_id_3
    JOBjob_id_1
    JOBjob_id_2
    JOBjob_id_8
    JOBjob_id_10
    JOBjob_id_4
    JOBjob_id_6
    JOBjob_id_9
    JOBjob_id_5
    JOBjob_id_7
    [aweight=precise_l],
    noconst
    robust
;

est store fig5_location_by_vacancy ;

coefplot fig5_location_by_vacancy,
    keep(JOBjob_id_3
         JOBjob_id_1
         JOBjob_id_2
         JOBjob_id_8
         JOBjob_id_10
         JOBjob_id_4
         JOBjob_id_6
         JOBjob_id_9
         JOBjob_id_5
         JOBjob_id_7)
    title("")
    scheme(s1color)
    ci(95)
    horizontal
    ytitle("Job vancancy")
    xtitle("Location parameter" "(relative stance)")
    ciopts(lwidth(3 ..) lcolor(*.2) fcolor(%40) color(green%60))
    msymbol(circle)
    mcolor(white)
    mlcolor(green*.2)
    msize(large)
    xlabel(#10, angle(horizontal) labsize(small) format(%4.2f) grid)
    ylabel(1 "Warehouse Assistant"
           2 "Sales Representative"
           3 "Services Assistant (Janitorial)"
           4 "Call Center Operator"
           5 "Maintenance Technician"
           6 "Certified Accountant"
           7 "Systems Engineer"
           8 "Manufacturing Production Supervisor"
           9 "Software Developer"
           10 "Technical Project Manager",
           labsize(small))
    legend(off)
    graphregion(color(white))
    plotregion(fcolor(white) lcolor(black) lwidth(thin))
;

graph export "$OUT/Figure 3.pdf", replace ;


*-------------------------------------------------------------------------------;
* JOB REQUIREMENT INDEX USED IN FIGURES 4 AND 6 ;
*-------------------------------------------------------------------------------;

gen college_requ = 1 if job_id==1 | job_id==4 | job_id==5 | job_id==6 | job_id==7 | job_id==9 ;
replace college_requ = 0 if college_requ==. ;

gen ncollege_requ = (college_requ==0) ;

gen minexp_requ = 1 if job_id==2 ;
replace minexp_requ = 3 if job_id==1 | job_id==4 | job_id==10 ;
replace minexp_requ = 2 if job_id==3 | job_id==5 | job_id==8 | job_id==9 ;
replace minexp_requ = 4 if job_id==6 | job_id==7 ;

pca minexp_requ college_requ ;
predict pca1 ;

sort pca1 q ;
cumul pca1, generate(cdf_pca1) ;


*-------------------------------------------------------------------------------;
* FIGURE 4: AVERAGE LOCATION BY SKILL REQUIREMENT ;
*-------------------------------------------------------------------------------;

twoway
    (lpolyci cdf_loc cdf_pca1 [aweight=precise_l],
        degree(1)
        bwidth(.27)
        clcolor(green)
        clwidth(thick)
        ciplot(rarea)
        fcolor(green%25)
        lcolor(green))
,
    title("")
    scheme(s1color)
    ytitle("Location parameter" "(relative stance)")
    xtitle("Vacancy's skill-requirement")
    xlabel(0(.1)1, angle(horizontal) labsize(small) format(%4.2f) grid)
    ylabel(.30(.10).90, angle(horizontal) labsize(small) format(%4.2f) grid)
    legend(off)
    graphregion(color(white))
    plotregion(fcolor(white) lcolor(black) lwidth(thin))
;

graph export "$OUT/Figure 4.pdf", replace ;


*-------------------------------------------------------------------------------;
* FIGURE 5: AVERAGE DIFFERENTIATION BY JOB VACANCY TYPE ;
*-------------------------------------------------------------------------------;

regress cdf_diff
    JOBjob_id_10
    JOBjob_id_8
    JOBjob_id_3
    JOBjob_id_5
    JOBjob_id_7
    JOBjob_id_2
    JOBjob_id_1
    JOBjob_id_9
    JOBjob_id_6
    JOBjob_id_4
    [aweight=precise_l],
    noconst
    robust
;

est store fig7_diff_by_vacancy ;

coefplot fig7_diff_by_vacancy,
    keep(JOBjob_id_10
         JOBjob_id_8
         JOBjob_id_3
         JOBjob_id_5
         JOBjob_id_7
         JOBjob_id_2
         JOBjob_id_1
         JOBjob_id_9
         JOBjob_id_6
         JOBjob_id_4)
    title("")
    scheme(s1color)
    ci(95)
    horizontal
    ytitle("Job vancancy")
    xtitle("Differentiation parameter" "(relative stance)")
    ciopts(lwidth(3 ..) lcolor(*.2) fcolor(%40) color(navy%60))
    msymbol(circle)
    mcolor(white)
    mlcolor(navy*.2)
    msize(large)
    xlabel(#10, angle(horizontal) labsize(small) format(%4.2f) grid)
    ylabel(1 "Maintenance Technician"
           2 "Call Center Operator"
           3 "Warehouse Assistant"
           4 "Software Developer"
           5 "Technical Project Manager"
           6 "Services Assistant (Janitorial)"
           7 "Sales Representative"
           8 "Manufacturing Production Supervisor"
           9 "Systems Engineer"
           10 "Certified Accountant",
           labsize(small))
    legend(off)
    graphregion(color(white))
    plotregion(fcolor(white) lcolor(black) lwidth(thin))
;

graph export "$OUT/Figure 5.pdf", replace ;


*-------------------------------------------------------------------------------;
* FIGURE 6: AVERAGE DIFFERENTIATION BY SKILL REQUIREMENT ;
*-------------------------------------------------------------------------------;

twoway
    (lpolyci cdf_diff cdf_pca1 [aweight=precise_l],
        degree(1)
        bwidth(.27)
        clcolor(navy)
        clwidth(thick)
        ciplot(rarea)
        fcolor(navy%25)
        lcolor(navy))
,
    title("")
    scheme(s1color)
    ytitle("Differentiation parameter" "(relative stance)")
    xtitle("Vacancy's skill-requirement")
    xlabel(0(.1)1, angle(horizontal) labsize(small) format(%4.2f) grid)
    ylabel(.45(.05).85, angle(horizontal) labsize(small) format(%4.2f) grid)
    legend(off)
    graphregion(color(white))
    plotregion(fcolor(white) lcolor(black) lwidth(thin))
;

graph export "$OUT/Figure 6.pdf", replace ;



*===============================================================================;
* 3. TABLES;
*===============================================================================;

*-------------------------------------------------------------------------------;
* TABLES 1, 4 AND 5: RECRUITER-LEVEL IRT DATA ;
*-------------------------------------------------------------------------------;

cd "$DIR_IRT" ;

use "IRT_responsedata_question_Majority.dta", clear ;

merge 1:1 recruiter_id using "recruiter_type_temp.dta" ;
drop _merge ;

keep if recruiter_type=="human" ///
     | recruiter_type=="robot-gamma6" ///
     | recruiter_type=="clone-gamma2" ///
     | recruiter_type=="clone-gamma5" ///
     | recruiter_type=="randomista" ;

drop if I_noBIG5_cog==1 ;

set seed 20250611 ;
sort recruiter_id ;
set seed 20250611 ;

irt 2pl binary_M_r*,
    intmethod(mvaghermite)
    level(99)
    iterate(100)
    vce(robust)
    technique(nr)
    intpoints(20)
    difficult
    startvalues(ivloadings) ;

predict machina_latent, latent ebmeans se(latent_se) tolerance(0.0001) ;
predict agree_prob, pr ;

gen precise = 1/latent_se ;

sum machina_latent [aweight=precise] if recruiter_type=="human", d ;
gen z_machina = (machina_latent - `r(mean)')/`r(sd)' ;

gen core_id = substr(recruiter_id,5,3) ;

gen recruiter = 0 if recruiter_type=="human" ;
replace recruiter = 1 if recruiter_type=="robot-gamma6" ;
replace recruiter = 2 if recruiter_type=="clone-gamma2" ;
replace recruiter = 3 if recruiter_type=="clone-gamma5" ;
replace recruiter = 4 if recruiter_type=="randomista" ;


*-------------------------------------------------------------------------------;
* TABLE 4: CONTRASTING MACHINA TRAIT DISTRIBUTION ACROSS RECRUITER TEAMS ;
*-------------------------------------------------------------------------------;

capture file close tex ;

file open tex using "$TABLEOUT/Table 4.tex", write replace ;

file write tex "\begin{table}[!htbp]\centering" _n ;
file write tex "\caption{Contrasting machina trait distribution across recruiter teams}" _n ;
file write tex "\begin{tabular}{lccccc}" _n ;
file write tex "\toprule" _n ;
file write tex " & Mean & SD & Kolmogorov-Smirnov & Mean equality & Variance equality \\" _n ;
file write tex " &  &  & test p-value & test p-value & test p-value \\" _n ;
file write tex "\midrule" _n ;

foreach g in 1 2 3 0 4 {;

    if `g'==1 local teamname "Robots" ;
    if `g'==2 local teamname "Avatars" ;
    if `g'==3 local teamname "Clones" ;
    if `g'==0 local teamname "Humans" ;
    if `g'==4 local teamname "Randomistas" ;

    quietly summarize z_machina [aweight=precise] if recruiter==`g' ;
    local mean_s : display %4.2f r(mean) ;
    local sd_s   : display %4.2f r(sd) ;
    local mean_s = trim("`mean_s'") ;
    local sd_s   = trim("`sd_s'") ;

    if `g'==0 {;
        local ks_s    "REF" ;
        local meanp_s "REF" ;
        local varp_s  "REF" ;
    };
    else {;

        preserve ;
            keep if recruiter==0 | recruiter==`g' ;
            gen nonhuman = (recruiter!=0) ;
            quietly regress z_machina nonhuman [aweight=precise], hc3 ;
            quietly test nonhuman ;
            scalar mean_p = r(p) ;
        restore ;

        preserve ;
            keep if recruiter==0 | recruiter==`g' ;
            scalar var_p = . ;
            quietly robvar z_machina, by(recruiter) ;
            capture scalar var_p = r(p_w0) ;
            if missing(var_p) {;
                capture scalar var_p = r(p) ;
            };
        restore ;

        preserve ;
            keep if recruiter==0 | recruiter==`g' ;
            scalar ks_p = . ;
            quietly ksmirnov z_machina, by(recruiter) exact ;
            capture scalar ks_p = r(p_exact) ;
            if missing(ks_p) {;
                capture scalar ks_p = r(p) ;
            };
        restore ;

        if scalar(ks_p)<0.0005 local ks_s "0.000" ;
        else {;
            local ks_s : display %4.3f scalar(ks_p) ;
            local ks_s = trim("`ks_s'") ;
        };

        if scalar(mean_p)<0.0005 local meanp_s "0.000" ;
        else {;
            local meanp_s : display %4.3f scalar(mean_p) ;
            local meanp_s = trim("`meanp_s'") ;
        };

        if scalar(var_p)<0.0005 local varp_s "0.000" ;
        else {;
            local varp_s : display %4.3f scalar(var_p) ;
            local varp_s = trim("`varp_s'") ;
        };

    };

    file write tex "`teamname' & `mean_s' & `sd_s' & `ks_s' & `meanp_s' & `varp_s' \\" _n ;

};

file write tex "\bottomrule" _n ;
file write tex "\multicolumn{6}{l}{\footnotesize Note: Means and standard deviations are computed using precision weights.} \\" _n ;
file write tex "\multicolumn{6}{l}{\footnotesize Tests compare each recruiter team against the human recruiter distribution.} \\" _n ;
file write tex "\end{tabular}" _n ;
file write tex "\end{table}" _n ;

file close tex ;


*-------------------------------------------------------------------------------;
* TABLES 1 AND 5: HUMAN RECRUITER DESCRIPTIVES AND MACHINA DESCRIPTORS ;
*-------------------------------------------------------------------------------;

merge 1:1 recruiter_id using "recruiters_Majority.dta" ;
keep if recruiter_type=="human" ;
keep if _merge==3 ;
drop _merge ;

egen sector = group(r_sectorexp) ;

forvalues i = 1(1)9 {;
    gen sec`i' = (sector==`i') ;
};


*-------------------------------------------------------------------------------;
* TABLE 1: HUMAN RECRUITERS DESCRIPTIVE STATISTICS ;
*-------------------------------------------------------------------------------;

preserve ;

capture confirm variable neuroticism ;
if _rc {;
    capture confirm variable r_neuroticism ;
    if !_rc gen neuroticism = r_neuroticism ;
};

capture confirm variable extroversion ;
if _rc {;
    capture confirm variable r_extroversion ;
    if !_rc gen extroversion = r_extroversion ;
};

capture confirm variable openness ;
if _rc {;
    capture confirm variable r_openness ;
    if !_rc gen openness = r_openness ;
};

capture confirm variable agreeableness ;
if _rc {;
    capture confirm variable r_agreeableness ;
    if !_rc gen agreeableness = r_agreeableness ;
};

capture confirm variable conscientiousness ;
if _rc {;
    capture confirm variable r_conscientio ;
    if !_rc gen conscientiousness = r_conscientio ;
};

capture confirm variable rosenberg ;
if _rc {;
    capture confirm variable r_rosenberg ;
    if !_rc gen rosenberg = r_rosenberg ;
};

capture confirm variable wonderlic ;
if _rc {;
    capture confirm variable r_wonderlic ;
    if !_rc gen wonderlic = r_wonderlic ;
};

capture drop r_mediumhighSES ;
capture drop r_highSES ;

gen r_mediumhighSES = (r_zona_SES_cd==4) if !missing(r_zona_SES_cd) ;
gen r_highSES       = (r_zona_SES_cd==5) if !missing(r_zona_SES_cd) ;

label variable r_Linkedin       "Recruited via LinkedIn (=1)" ;
label variable r_male           "Male (=1)" ;
label variable r_age            "Age (years)" ;
label variable r_mediumhighSES  "Medium-high SES (=1)" ;
label variable r_highSES        "High-SES (=1)" ;
label variable r_postgrad       "Postgraduate degree (=1)" ;
label variable r_college        "College degree (=1)" ;
label variable r_trainingHR     "HR-related major/degree (=1)" ;
label variable r_yrsRHexp       "Work experience in HR (years)" ;
label variable r_curremp        "Currently employed (=1)" ;
label variable r_lastwrokHR     "HR-related current/last job (=1)" ;
label variable r_expRHabroad    "HR experience abroad (=1)" ;
label variable r_knowECU3       "High knowledge of Ecuadorian market (=1)" ;

capture label variable neuroticism        "Neuroticism (0-48)" ;
capture label variable extroversion       "Extroversion (0-48)" ;
capture label variable openness           "Openness (0-48)" ;
capture label variable agreeableness      "Agreeableness (0-48)" ;
capture label variable conscientiousness  "Conscientiousness (0-48)" ;
capture label variable rosenberg          "Rosenberg Self-esteem (10-40)" ;
capture label variable wonderlic          "Wonderlic Cognitive test (1-46)" ;

local tab1_vars
    r_Linkedin
    r_male
    r_age
    r_mediumhighSES
    r_highSES
    r_postgrad
    r_college
    r_trainingHR
    r_yrsRHexp
    r_curremp
    r_lastwrokHR
    r_expRHabroad
    r_knowECU3
    neuroticism
    extroversion
    openness
    agreeableness
    conscientiousness
    rosenberg
    wonderlic
;

estpost tabstat `tab1_vars',
    statistics(mean sd skewness p25 p50 p75)
    columns(statistics)
;

esttab using "$TABLEOUT/Table 1.tex",
    replace
    booktabs
    label
    noobs
    nonumber
    nomtitle
    cells("mean(fmt(2)) sd(fmt(2)) skewness(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2))")
    collabels("Mean" "Standard Deviation" "Skewness" "Percentile 25" "Percentile 50" "Percentile 75")
    refcat(
        r_Linkedin "\addlinespace \multicolumn{7}{l}{\textit{Recruitment method}} \\"
        r_male "\addlinespace \multicolumn{7}{l}{\textit{Demographics and SES}} \\"
        r_postgrad "\addlinespace \multicolumn{7}{l}{\textit{Education}} \\"
        r_yrsRHexp "\addlinespace \multicolumn{7}{l}{\textit{Work experience}} \\"
        neuroticism "\addlinespace \multicolumn{7}{l}{\textit{Socio-emotional and Cognitive Scores}} \\",
        nolabel)
    prehead("\begin{table}[!htbp]\centering" "\caption{Human recruiters: descriptive statistics}" "\begin{tabular}{lcccccc}" "\toprule")
    posthead(" & Mean & Standard & Skewness & Percentile & Percentile & Percentile \\" " &  & Deviation &  & 25 & 50 & 75 \\" "\midrule")
    prefoot("\midrule")
    postfoot("\bottomrule" "\multicolumn{7}{l}{\footnotesize Note: Statistics based on 277 unique human recruiter observations.} \\" "\end{tabular}" "\end{table}")
;

restore ;


*-------------------------------------------------------------------------------;
* TABLE 5: MACHINA TRAIT VERSUS OBSERVABLE HUMAN CHARACTERISTICS ;
*-------------------------------------------------------------------------------;

label variable r_male           "Male (=1)" ;
label variable r_age            "Age (years)" ;
label variable r_postgrad       "Postgraduate degree (=1)" ;
label variable r_college        "College degree (=1)" ;
label variable r_trainingHR     "HR-related major/degree (=1)" ;
label variable r_yrsRHexp       "Work experience in HR (years)" ;
label variable r_curremp        "Currently employed (=1)" ;
label variable r_lastwrokHR     "HR-related current/last job (=1)" ;
label variable r_expRHabroad    "HR experience abroad (=1)" ;
label variable r_knowECU3       "High knowledge of Ecuadorian market (=1)" ;
label variable z_neuroticism    "Neuroticism" ;
label variable z_extroversion   "Extroversion" ;
label variable z_openness       "Openness" ;
label variable z_agreeableness  "Agreeableness" ;
label variable z_conscientio    "Conscientiousness" ;
label variable z_rosenberg      "Rosenberg Self-esteem" ;
label variable z_wonder_pca     "Wonderlic Cognitive test" ;

regress z_machina
    r_Linkedin
    r_male
    r_age
    r_postgrad
    r_college
    r_trainingHR
    r_yrsRHexp
    r_curremp
    r_lastwrokHR
    r_expRHabroad
    r_knowECU3
    sec2 sec3 sec4 sec5 sec6 sec7 sec8 sec9
    z_neuroticism
    z_extroversion
    z_openness
    z_agreeableness
    z_conscientio
    z_rosenberg
    z_wonder_pca
    [aweight=precise],
    robust ;

est store irt_human ;
estadd local sectorFE "YES" ;
estadd scalar r2show = e(r2) ;

regress z_machina
    r_Linkedin
    r_male
    r_age
    r_postgrad
    r_college
    r_trainingHR
    r_yrsRHexp
    r_curremp
    r_lastwrokHR
    r_expRHabroad
    r_knowECU3
    sec2 sec3 sec4 sec5 sec6 sec7 sec8 sec9
    z_neuroticism
    z_extroversion
    z_openness
    z_agreeableness
    z_conscientio
    z_rosenberg
    z_wonder_pca,
    robust ;

est store irt_humanB ;
estadd local sectorFE "YES" ;
estadd scalar r2show = e(r2) ;

qreg z_machina
    r_Linkedin
    r_male
    r_age
    r_postgrad
    r_college
    r_trainingHR
    r_yrsRHexp
    r_curremp
    r_lastwrokHR
    r_expRHabroad
    r_knowECU3
    sec2 sec3 sec4 sec5 sec6 sec7 sec8 sec9
    z_neuroticism
    z_extroversion
    z_openness
    z_agreeableness
    z_conscientio
    z_rosenberg
    z_wonder_pca,
    quantile(50)
    vce(robust) ;

est store irt_human_q50 ;
estadd local sectorFE "YES" ;
estadd scalar r2show = e(r2_p) ;

esttab irt_human irt_humanB irt_human_q50
    using "$TABLEOUT/Table 5.tex",
    replace
    label
    booktabs
    b(3)
    se(3)
    star(* 0.10 ** 0.05 *** 0.01)
    eqlabels(none)
    alignment(D{.}{.}{-1})
    cells("b(fmt(3)star)" "se(fmt(3)par)")
    mlabels("[1]" "[2]" "[3]")
    order(
        r_male
        r_age
        r_postgrad
        r_college
        r_trainingHR
        r_yrsRHexp
        r_curremp
        r_lastwrokHR
        r_expRHabroad
        r_knowECU3
        z_neuroticism
        z_extroversion
        z_openness
        z_agreeableness
        z_conscientio
        z_rosenberg
        z_wonder_pca
    )
    keep(
        r_male
        r_age
        r_postgrad
        r_college
        r_trainingHR
        r_yrsRHexp
        r_curremp
        r_lastwrokHR
        r_expRHabroad
        r_knowECU3
        z_neuroticism
        z_extroversion
        z_openness
        z_agreeableness
        z_conscientio
        z_rosenberg
        z_wonder_pca
    )
    coeflabels(
        r_male           "Male (=1)"
        r_age            "Age (years)"
        r_postgrad       "Postgraduate degree (=1)"
        r_college        "College degree (=1)"
        r_trainingHR     "HR-related major/degree (=1)"
        r_yrsRHexp       "Work experience in HR (years)"
        r_curremp        "Currently employed (=1)"
        r_lastwrokHR     "HR-related current/last job (=1)"
        r_expRHabroad    "HR experience abroad (=1)"
        r_knowECU3       "High knowledge of Ecuadorian market (=1)"
        z_neuroticism    "Neuroticism"
        z_extroversion   "Extroversion"
        z_openness       "Openness"
        z_agreeableness  "Agreeableness"
        z_conscientio    "Conscientiousness"
        z_rosenberg      "Rosenberg Self-esteem"
        z_wonder_pca     "Wonderlic Cognitive test"
    )
    refcat(
        r_male           "\addlinespace \multicolumn{4}{l}{\textit{Demographics}} \\"
        r_postgrad       "\addlinespace \multicolumn{4}{l}{\textit{Education}} \\"
        r_yrsRHexp       "\addlinespace \multicolumn{4}{l}{\textit{Work experience}} \\"
        z_neuroticism    "\addlinespace \multicolumn{4}{l}{\textit{Socio-emotional and cognitive scores}} \\",
        nolabel
    )
    stats(sectorFE N r2show,
        fmt(%s 0 3)
        layout("\multicolumn{1}{c}{@}"
               "\multicolumn{1}{c}{@}"
               "\multicolumn{1}{c}{@}")
        labels("Sector fixed-effects"
               "Observations"
               "R2 / Pseudo R2"))
    nonotes
;


*-------------------------------------------------------------------------------;
* TABLES 2 AND 3: TRIAL-LEVEL LOCATION AND DIFFERENTIATION PARAMETERS ;
*-------------------------------------------------------------------------------;

cd "$DIR_IRT" ;

use "parameters_irt_raw.dta", clear ;

replace trial = subinstr(trial,"q","",.) ;
destring trial, replace ;
rename trial q ;

merge m:1 q using "IRT_question_coding_correspondence.dta" ;
drop _merge ;

merge m:1 job_id using "jobs.dta", keepusing(j_jobname) ;
drop _merge ;

merge 1:1 cv_pair_id using "PairedCVs_all_Ecuador.dta" ;
drop _merge ;

gen precise_d = 1/diff_se ;
gen precise_l = 1/loc_se ;

sort location q ;
cumul location, generate(cdf_loc) ;

sort different q ;
cumul different, generate(cdf_diff) ;

destring job_id, replace ;
xi, prefix(JOB) noomit i.job_id ;

gen college_requ = 1 if job_id==1 | job_id==4 | job_id==5 | job_id==6 | job_id==7 | job_id==9 ;
replace college_requ = 0 if college_requ==. ;

gen minexp_requ = 1 if job_id==2 ;
replace minexp_requ = 3 if job_id==1 | job_id==4 | job_id==10 ;
replace minexp_requ = 2 if job_id==3 | job_id==5 | job_id==8 | job_id==9 ;
replace minexp_requ = 4 if job_id==6 | job_id==7 ;

pca minexp_requ college_requ ;
predict pca1 ;

sort pca1 q ;
cumul pca1, generate(cdf_pca1) ;

gen diff_exp_u2   = (diff_exp<=.16) ;
gen diff_exp_2to3 = (diff_exp>.16 & diff_exp<.25) ;
gen diff_exp_3to4 = (diff_exp>=.25) ;

gen diff_age_u6m    = (diff_age<=.5) ;
gen diff_age_6mto12m = (diff_age>.5 & diff_age<=1) ;
gen diff_age_a12m   = (diff_age>1) ;

destring dsubject_cd, replace ;
gen placebo   = (dsubject_cd==6) ;
gen immigrant = (dsubject_cd==4 | dsubject_cd==5) ;
gen sexorient = (dsubject_cd==3 | dsubject_cd==2) ;
gen gender    = (dsubject_cd==1) ;

label variable cdf_pca1          "Vacancy's skill requirement (CDF)" ;
label variable diff_age_a12m     "Age difference between candidates (12 mths+)" ;
label variable diff_age_6mto12m  "Age difference between candidates (6 to 12 mths)" ;
label variable diff_exp_3to4     "Experience difference between candidates (3 to 4 mths)" ;
label variable diff_exp_2to3     "Experience difference between candidates (2 to 3 mths)" ;
label variable gender            "Gender difference between candidates" ;
label variable immigrant         "Immig. status difference between candidates" ;
label variable sexorient         "Sexual-orientation difference between candidates" ;


*-------------------------------------------------------------------------------;
* TABLE 2: LOCATION PARAMETER HETEROGENEITY ;
*-------------------------------------------------------------------------------;

regress cdf_loc
    cdf_pca1
    [aweight=precise_l],
    robust ;

est store irt_locationA ;
estadd local vacancyFE " " ;

regress cdf_loc
    cdf_pca1
    diff_age_a12m diff_age_6mto12m
    diff_exp_3to4 diff_exp_2to3
    gender immigrant sexorient
    [aweight=precise_l],
    robust ;

est store irt_locationB ;
estadd local vacancyFE " " ;

regress cdf_loc
    diff_age_a12m diff_age_6mto12m
    diff_exp_3to4 diff_exp_2to3
    gender immigrant sexorient
    JOBjob_id_1 JOBjob_id_2 JOBjob_id_8 JOBjob_id_10 JOBjob_id_4 JOBjob_id_6 JOBjob_id_9 JOBjob_id_5 JOBjob_id_7
    [aweight=precise_l],
    robust ;

est store irt_locationC ;
estadd local vacancyFE "YES" ;

esttab irt_locationA irt_locationB irt_locationC
    using "$TABLEOUT/Table 2.tex",
    replace
    label
    booktabs
    b(3)
    se(3)
    star(* 0.10 ** 0.05 *** 0.01)
    eqlabels(none)
    alignment(D{.}{.}{-1})
    order(
        cdf_pca1
        diff_age_a12m
        diff_age_6mto12m
        diff_exp_3to4
        diff_exp_2to3
        gender
        immigrant
        sexorient
    )
    keep(
        cdf_pca1
        diff_age_a12m
        diff_age_6mto12m
        diff_exp_3to4
        diff_exp_2to3
        gender
        immigrant
        sexorient
    )
    coeflabels(
        cdf_pca1          "Vacancy's skill requirement (CDF)"
        diff_age_a12m     "Age difference between candidates (12 mths+)"
        diff_age_6mto12m  "Age difference between candidates (6 to 12 mths)"
        diff_exp_3to4     "Experience difference between candidates (3 to 4 mths)"
        diff_exp_2to3     "Experience difference between candidates (2 to 3 mths)"
        gender            "Gender difference between candidates"
        immigrant         "Immig. status difference between candidates"
        sexorient         "Sexual-orientation difference between candidates"
    )
    refcat(
        diff_age_a12m     "Age difference between candidates (under 6 mths) & REF & REF &  \\"
        diff_exp_3to4     "Experience difference between candidates (under 2 mths) & REF & REF &  \\"
        gender            "No identity difference between candidates & REF & REF &  \\",
        nolabel
    )
    stats(vacancyFE N r2,
        fmt(%s 0 3)
        labels("Vacancy fixed-effects" "Observations" "R2"))
    nomtitles
    nonotes
;


*-------------------------------------------------------------------------------;
* TABLE 3: DIFFERENTIATION PARAMETER HETEROGENEITY ;
*-------------------------------------------------------------------------------;

regress cdf_diff
    cdf_pca1
    [aweight=precise_l],
    robust ;

est store irt_diffA ;
estadd local vacancyFE " " ;

regress cdf_diff
    cdf_pca1
    diff_age_a12m diff_age_6mto12m
    diff_exp_3to4 diff_exp_2to3
    gender immigrant sexorient
    [aweight=precise_l],
    robust ;

est store irt_diffB ;
estadd local vacancyFE " " ;

regress cdf_diff
    diff_age_a12m diff_age_6mto12m
    diff_exp_3to4 diff_exp_2to3
    gender immigrant sexorient
    JOBjob_id_1 JOBjob_id_2 JOBjob_id_8 JOBjob_id_10 JOBjob_id_4 JOBjob_id_6 JOBjob_id_9 JOBjob_id_5 JOBjob_id_7
    [aweight=precise_l],
    robust ;

est store irt_diffC ;
estadd local vacancyFE "YES" ;

esttab irt_diffA irt_diffB irt_diffC
    using "$TABLEOUT/Table 3.tex",
    replace
    label
    booktabs
    b(3)
    se(3)
    star(* 0.10 ** 0.05 *** 0.01)
    eqlabels(none)
    alignment(D{.}{.}{-1})
    order(
        cdf_pca1
        diff_age_a12m
        diff_age_6mto12m
        diff_exp_3to4
        diff_exp_2to3
        gender
        immigrant
        sexorient
    )
    keep(
        cdf_pca1
        diff_age_a12m
        diff_age_6mto12m
        diff_exp_3to4
        diff_exp_2to3
        gender
        immigrant
        sexorient
    )
    coeflabels(
        cdf_pca1          "Vacancy's skill requirement (CDF)"
        diff_age_a12m     "Age difference between candidates (12 mths+)"
        diff_age_6mto12m  "Age difference between candidates (6 to 12 mths)"
        diff_exp_3to4     "Experience difference between candidates (3 to 4 mths)"
        diff_exp_2to3     "Experience difference between candidates (2 to 3 mths)"
        gender            "Gender difference between candidates"
        immigrant         "Immig. status difference between candidates"
        sexorient         "Sexual-orientation difference between candidates"
    )
    refcat(
        diff_age_a12m     "Age difference between candidates (under 6 mths) & REF & REF &  \\"
        diff_exp_3to4     "Experience difference between candidates (under 2 mths) & REF & REF &  \\"
        gender            "No identity difference between candidates & REF & REF &  \\",
        nolabel
    )
    stats(vacancyFE N r2,
        fmt(%s 0 3)
        labels("Vacancy fixed-effects" "Observations" "R2"))
    nomtitles
    nonotes
;

# delimit cr
