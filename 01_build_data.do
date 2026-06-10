/****************************************************************************************
 Project: Labour Market Turing Test
 File: 01_build_data.do
 Purpose:
   Build only the processed datasets required to reproduce the paper figures and tables.

 Inputs:
   Data/Raw/Data_Base.dta
   Data/Raw/Reclutadores_tests.dta

 Outputs:
   Data/Processed/IRT_responsedata_question_Majority.dta
   Data/Processed/recruiter_type_temp.dta
   Data/Processed/recruiters_Majority.dta
   Data/Processed/parameters_irt_raw.dta
   Data/Processed/IRT_question_coding_correspondence.dta
   Data/Processed/jobs.dta
   Data/Processed/PairedCVs_all_Ecuador.dta
****************************************************************************************/

version 17
clear all
set more off
set seed 20250611
capture log close

*===============================================================================;
* 0. PATHS ;
*===============================================================================;

* Set root folder to the location where this do-file is being run.
global ROOT "c(pwd)"

global RAW  "$ROOT/Data/Raw"
global PROC "$ROOT/Data/Processed"
global OUT  "$ROOT/Output/Figures"
global TABS "$ROOT/Output/Tables"

capture mkdir "$ROOT/Data"
capture mkdir "$RAW"
capture mkdir "$PROC"
capture mkdir "$ROOT/Output"
capture mkdir "$OUT"
capture mkdir "$TABS"

cd "$ROOT"


*===============================================================================;
* 1. LOAD CLEANED RAW DATABASE AND MERGE RECRUITER TESTS ;
*===============================================================================;
# delimit ;

use "$RAW/Data_Base_Raw.dta", clear ;

capture drop cv_id ;

capture drop neuroticism extroversion openness agreeableness conscientiousness rosenberg wonderlic ;

gen id = id_reclut ;

merge m:1 id using "$RAW/Reclutadores_tests.dta" ;
drop if _merge == 2 ;

gen I_noBIG5_cog = (_merge == 1) ;
drop _merge ;

gen recruiter_id = id_reclut ;
tostring recruiter_id, replace ;
gen l = length(recruiter_id) ;
replace recruiter_id = "00" + recruiter_id if l == 1 ;
replace recruiter_id = "0"  + recruiter_id if l == 2 ;
drop l ;

gen recruiter_type = "human" ;


*===============================================================================;
* 2. FLAG INCOMPLETE SOCIO-EMOTIONAL, COGNITIVE AND DEMOGRAPHIC INFORMATION ;
*===============================================================================;

foreach var in miss_neuroticism miss_extroversion miss_openness miss_agreeableness miss_conscientiousness {;
    gen drop_`var' = (`var' > 0) ;
};

egen zero = rowtotal(drop_miss_neuroticism drop_miss_extroversion drop_miss_openness drop_miss_agreeableness drop_miss_conscientiousness) ;
replace I_noBIG5_cog = 1 if zero > 0 ;
drop zero drop_miss_neuroticism drop_miss_extroversion drop_miss_openness drop_miss_agreeableness drop_miss_conscientiousness ;

replace I_noBIG5_cog = 1 if miss_Swonderlic > 5 ;

replace I_noBIG5_cog = 1 if I_r_age == 1 ;
drop I_r_age ;

egen missing_X = rowmiss(lugar_nacimiento nacionalidad_reclutador genero grado_instruccion carrera anios_laboral industrias_laboral anios_rrhh empleado ultimo_trabajo_rrhh conocimiento_ecu recolec) ;
replace I_noBIG5_cog = 1 if missing_X > 0 ;
drop missing_X ;


*===============================================================================;
* 3. KEEP RECRUITERS WHO COMPLETED ALL 10 TRIALS ;
*===============================================================================;

egen tag = tag(id_reclut recruiter_type cargo_posicion_evaluado), missing ;
egen sum = total(tag), by(id_reclut recruiter_type) ;
keep if sum == 10 ;
drop tag sum ;


*===============================================================================;
* 4. CREATE CANDIDATE, TRIAL AND JOB IDENTIFIERS ;
*===============================================================================;

set seed 20250611 ;
gen random = runiform() ;
sort random ;
drop random ;

egen cv_id = group(nombre_candidato fecha_nacimiento_candidato zona_residencia_candidato form_cand_1 form_cand_2 form_cand_3 exp_laboral_1_candidato experiencia_laboral_2_candidato experiencia_laboral_3_candidato experiencia_laboral_4_candidato profesion_candidato exp_laboral_candidato), missing ;

rename nombre_candidato c_name ;
rename fecha_nacimiento_candidato c_dob ;
rename genero_candidato c_gender ;
rename zona_residencia_candidato c_residarea ;
rename form_cand_1 c_educ1 ;
rename form_cand_2 c_educ2 ;
rename form_cand_3 c_educ3 ;
rename exp_laboral_1_candidato c_expsect1 ;
rename experiencia_laboral_2_candidato c_expsect2 ;
rename experiencia_laboral_3_candidato c_expsect3 ;
rename experiencia_laboral_4_candidato c_expsect4 ;
rename profesion_candidato c_profession ;
rename exp_laboral_candidato c_yrsexp ;
rename minoria_ev c_minoria_ev ;

replace c_dob = dofc(c_dob) ;
format c_dob %td ;

egen trial_id = group(id_reclut cargo_posicion_evaluado), missing ;
tostring trial_id, replace ;
gen l = length(trial_id) ;
replace trial_id = "0"   + trial_id if l == 3 ;
replace trial_id = "00"  + trial_id if l == 2 ;
replace trial_id = "000" + trial_id if l == 1 ;
drop l ;

egen job_id = group(cargo_posicion_evaluado), missing ;
tostring job_id, replace ;
gen l = length(job_id) ;
replace job_id = "0" + job_id if l == 1 ;
drop l ;

gen cv_order = c_minoria_ev ;
egen rank = rank(cv_id), unique by(trial_id) ;
replace cv_order = rank - 1 if missing(cv_order) ;
drop rank ;

compress ;
save "$PROC/all_candidates.dta", replace ;


*===============================================================================;
* 5. CREATE HEAD-TO-HEAD FILE AND MAJORITY-ROBOT REFERENCE ;
*===============================================================================;

preserve ;

keep cv_id c_name c_dob c_gender c_residarea c_educ1 c_educ2 c_educ3 c_expsect1 c_expsect2 c_expsect3 c_expsect4 c_profession c_yrsexp c_minoria_ev resp resp_gama2 resp_gama5 resp_gama6 resp_randomista trial_id ejercicio cv_order job_id recruiter_id ;

tostring cv_order, replace ;
replace cv_order = "_" + cv_order ;

reshape wide cv_id c_name c_dob c_gender c_residarea c_educ1 c_educ2 c_educ3 c_expsect1 c_expsect2 c_expsect3 c_expsect4 c_profession c_yrsexp c_minoria_ev resp resp_gama2 resp_gama5 resp_gama6 resp_randomista, i(trial_id ejercicio job_id recruiter_id) j(cv_order) string ;

gen t0 = cv_id_0 ;
gen t1 = cv_id_1 ;

tostring cv_id_0, replace ;
gen l = length(cv_id_0) ;
replace cv_id_0 = "00" + cv_id_0 if l == 1 ;
replace cv_id_0 = "0"  + cv_id_0 if l == 2 ;
drop l ;

tostring cv_id_1, replace ;
gen l = length(cv_id_1) ;
replace cv_id_1 = "00" + cv_id_1 if l == 1 ;
replace cv_id_1 = "0"  + cv_id_1 if l == 2 ;
drop l ;

gen cv_pair_id = cv_id_0 + cv_id_1 if t0 < t1 ;
replace cv_pair_id = cv_id_1 + cv_id_0 if t0 > t1 ;
drop t0 t1 ;

egen temp = mean(resp_gama6_1), by(cv_pair_id) ;
gen resp_Mrobot_1 = (temp >= .5) ;
gen resp_Mrobot_0 = 1 - resp_Mrobot_1 ;
drop temp ;

egen tag = tag(trial_id) ;
keep if tag == 1 ;
keep cv_pair_id trial_id resp_Mrobot_0 resp_Mrobot_1 ;
save "$PROC/mrobot_triallevel_working.dta", replace ;

egen tag2 = tag(cv_pair_id) ;
keep if tag2 == 1 ;
keep cv_pair_id resp_Mrobot_0 resp_Mrobot_1 ;
save "$PROC/mrobot_working.dta", replace ;

restore ;


*===============================================================================;
* 6. MERGE MAJORITY-ROBOT REFERENCE BACK TO CANDIDATE-LEVEL FILE ;
*===============================================================================;

merge m:1 trial_id using "$PROC/mrobot_triallevel_working.dta", keepusing(resp_Mrobot_1) ;
drop _merge ;

gen resp_Mrobot = 1 if resp_Mrobot_1 == 1 & cv_order == 1 ;
replace resp_Mrobot = 0 if resp_Mrobot_1 == 0 & cv_order == 1 ;
replace resp_Mrobot = 0 if resp_Mrobot_1 == 1 & cv_order == 0 ;
replace resp_Mrobot = 1 if resp_Mrobot_1 == 0 & cv_order == 0 ;
drop resp_Mrobot_1 ;

save "$PROC/all_candidates.dta", replace ;


*===============================================================================;
* 7. CREATE AI AND RANDOMISTA RECRUITER FILES USED BY FIGURES/TABLES ;
*===============================================================================;

foreach j in 2 5 {;
    preserve ;
        replace recruiter_type = "clone-gamma`j'" ;
        replace resp = resp_gama`j' ;
        capture drop resp_gama* resp_randomista ;
        replace recruiter_id = "AI0`j'" + recruiter_id ;

        if `j' == 2 {;
            replace lugar_nacimiento = "Ecuador" ;
            replace nacionalidad_reclutador = "Ecuador" ;
        };

        compress ;
        save "$PROC/gamma`j'_temp.dta", replace ;
    restore ;
};

foreach j in 6 {;
    preserve ;
        replace recruiter_type = "robot-gamma`j'" ;
        replace resp = resp_gama`j' ;
        capture drop resp_gama* resp_randomista ;
        replace recruiter_id = "RO0`j'" + recruiter_id ;
        capture drop lugar_nacimiento nacionalidad_reclutador fecha_nacimiento genero grado_instruccion carrera anios_laboral industrias_laboral anios_rrhh anios_rrhh_extranjero empleado ultimo_trabajo_rrhh conocimiento_ecu neuroticism extroversion openness agreeableness conscientiousness rosenberg wonderlic recolec ;
        compress ;
        save "$PROC/gamma`j'_temp.dta", replace ;
    restore ;
};

foreach i in 0 {;
    preserve ;
        replace recruiter_type = "randomista" ;
        replace resp = resp_randomista ;
        replace recruiter_id = "RR0`i'" + recruiter_id ;
        capture drop resp_gama* resp_randomista ;
        capture drop lugar_nacimiento nacionalidad_reclutador fecha_nacimiento genero grado_instruccion carrera anios_laboral industrias_laboral anios_rrhh anios_rrhh_extranjero empleado ultimo_trabajo_rrhh conocimiento_ecu neuroticism extroversion openness agreeableness conscientiousness rosenberg wonderlic recolec ;
        compress ;
        save "$PROC/gammaRANDOM`i'_temp.dta", replace ;
    restore ;
};


*===============================================================================;
* 8. APPEND HUMANS, AI RECRUITERS AND RANDOMISTAS ;
*===============================================================================;

capture drop resp_gama* resp_randomista ;
replace recruiter_id = "HU00" + recruiter_id ;

append using "$PROC/gamma2_temp.dta" ;
append using "$PROC/gamma5_temp.dta" ;
append using "$PROC/gamma6_temp.dta" ;
append using "$PROC/gammaRANDOM0_temp.dta" ;

drop id_reclut ;
order recruiter_id recruiter_type ;


*===============================================================================;
* 9. CREATE RECRUITER TYPE FILE ;
*===============================================================================;

preserve ;
    egen tag = tag(recruiter_id recruiter_type) ;
    keep if tag == 1 ;
    keep recruiter_id recruiter_type ;
    compress ;
    save "$PROC/recruiter_type_temp.dta", replace ;
restore ;


*===============================================================================;
* 10. CREATE JOB VACANCY FILE ;
*===============================================================================;

preserve ;

egen tag = tag(job_id) ;
keep if tag == 1 ;
drop tag ;

keep job_id cargo_posicion_evaluado ;

rename cargo_posicion_evaluado j_jobname ;

replace j_jobname = "Accountant" if j_jobname == "Contador CPA" ;
replace j_jobname = "Sales manager" if j_jobname == "Asesor Comercial" ;
replace j_jobname = "Grocery manager" if j_jobname == "Bodeguero" ;
replace j_jobname = "Software Developer" if j_jobname == "Desarrollador de Software" ;
replace j_jobname = "Systems Engineer" if j_jobname == "Ingeniero en Sistemas" ;
replace j_jobname = "Call Center Operator" if j_jobname == "Operador de Call Center" ;
replace j_jobname = "Technical Project Manager" if j_jobname == "Jefe Técnico de Proyectos" ;
replace j_jobname = "Maintenance Technician" if j_jobname == "Técnico de Mantenimiento" ;
replace j_jobname = "Production Supervisor (Manufacturing)" if j_jobname == "Supervisor de Producción (Manufactura)" ;
replace j_jobname = "General Janitorial Services Manager" if j_jobname == "Auxiliar Servicios Generales - Limpieza" ;

tostring job_id, replace format(%02.0f) ;
compress ;
label data "Job vacancy names used for figures and tables" ;
save "$PROC/jobs.dta", replace ;

restore ;


*===============================================================================;
* 11. CREATE HUMAN RECRUITER CHARACTERISTICS FILE ;
*===============================================================================;

preserve ;

sort recruiter_id ;
egen tag = tag(recruiter_id recruiter_type) ;
keep if tag == 1 & recruiter_type == "human" ;
drop tag ;

keep recruiter_id recruiter_type genero grado_instruccion carrera anios_laboral industrias_laboral anios_rrhh anios_rrhh_extranjero empleado ultimo_trabajo_rrhh conocimiento_ecu r_age neuroticism miss_neuroticism extroversion miss_extroversion openness miss_openness agreeableness miss_agreeableness conscientiousness miss_conscientiousness rosenberg wonderlic miss_wonderlic Swonderlic miss_Swonderlic recolec I_noBIG5_cog r_zona_SES_cd ;

keep if I_noBIG5_cog == 0 ;

gen r_male = (genero == "Male") ;
drop genero ;

rename grado_instruccion grado_inst ;

gen r_postgrad  = (grado_inst == "Doctorate" | grado_inst == "Master") ;
gen r_college   = (grado_inst == "University") ;
gen r_trainingHR = (carrera == "Recursos Humanos") ;
drop grado_inst carrera ;

gen r_sectorexp = industrias_laboral ;
replace r_sectorexp = "Missing" if r_sectorexp == "" ;
drop industrias_laboral ;

gen I_r_laborexp = missing(anios_laboral) ;
drop anios_laboral ;

gen I_r_yrsRHexp = missing(anios_rrhh) ;
gen r_yrsRHexp = anios_rrhh ;
quietly summarize anios_rrhh ;
replace r_yrsRHexp = round(r(mean)) if I_r_yrsRHexp == 1 ;
drop anios_rrhh ;

gen r_expRHabroad = 0 ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "1" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "1 año" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "1 años" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "1 proyecto que hice" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "10" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "2" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "2 meses" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "3" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "4" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "5" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "6 meses" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "Mes en recursos huma" ;
replace r_expRHabroad = 1 if anios_rrhh_extranjero == "Salud" ;
drop anios_rrhh_extranjero ;

gen I_r_curremp = (empleado == "") ;
gen r_curremp = (empleado == "Employee") ;
drop empleado ;

gen r_lastwrokHR = (ultimo_trabajo_rrhh == "Yes") ;
drop ultimo_trabajo_rrhh ;

gen I_r_knowECU = missing(conocimiento_ecu) ;
gen r_knowECU1 = (conocimiento_ecu == 0 | conocimiento_ecu == 1) ;
gen r_knowECU2 = (conocimiento_ecu == 2) ;
gen r_knowECU3 = (conocimiento_ecu == 3) ;
drop conocimiento_ecu ;

rename recolec r_recolec ;
gen r_Linkedin = (r_recolec == "Linkedin") ;
drop r_recolec ;

rename neuroticism r_neuroticism ;
rename extroversion r_extroversion ;
rename openness r_openness ;
rename agreeableness r_agreeableness ;
rename conscientiousness r_conscientiousness ;
rename rosenberg r_rosenberg ;
rename wonderlic r_wonderlic ;

pca r_neuroticism r_extroversion r_openness r_agreeableness r_conscientiousness ;
predict r_big5_pca1 r_big5_pca2 r_big5_pca3 r_big5_pca4 r_big5_pca5 ;

pca r_wonderlic miss_wonderlic Swonderlic miss_Swonderlic ;
predict r_wonder_pca ;

egen z_neuroticism       = std(r_neuroticism) ;
egen z_extroversion      = std(r_extroversion) ;
egen z_openness          = std(r_openness) ;
egen z_agreeableness     = std(r_agreeableness) ;
egen z_conscientiousness = std(r_conscientiousness) ;
egen z_conscientio       = std(r_conscientiousness) ;
egen z_rosenberg         = std(r_rosenberg) ;
egen z_wonder_pca        = std(r_wonder_pca) ;

gen neuroticism       = r_neuroticism ;
gen extroversion      = r_extroversion ;
gen openness          = r_openness ;
gen agreeableness     = r_agreeableness ;
gen conscientiousness = r_conscientiousness ;
gen rosenberg         = r_rosenberg ;
gen wonderlic         = r_wonderlic ;

keep recruiter_id recruiter_type r_sectorexp r_Linkedin r_male r_age r_zona_SES_cd r_postgrad r_college r_trainingHR r_yrsRHexp r_curremp r_lastwrokHR r_expRHabroad r_knowECU3 neuroticism extroversion openness agreeableness conscientiousness rosenberg wonderlic z_neuroticism z_extroversion z_openness z_agreeableness z_conscientio z_rosenberg z_wonder_pca ;

compress ;
label data "Human recruiters used for figures and tables" ;
save "$PROC/recruiters_Majority.dta", replace ;

restore ;


*===============================================================================;
* 12. CREATE TRIAL-LEVEL FILES AND QUESTION CODING ;
*===============================================================================;

capture drop lugar_nacimiento nacionalidad_reclutador fecha_nacimiento genero grado_instruccion carrera anios_laboral industrias_laboral anios_rrhh anios_rrhh_extranjero empleado ultimo_trabajo_rrhh conocimiento_ecu neuroticism extroversion openness agreeableness conscientiousness rosenberg wonderlic recolec miss_neuroticism miss_extroversion miss_openness miss_agreeableness miss_conscientiousness miss_wonderlic Swonderlic miss_Swonderlic id r_age r_zona_SES_cd ;

order trial_id recruiter_id recruiter_type job_id cargo_posicion_evaluado cv_order ;

tostring cv_order, replace ;
replace cv_order = "_" + cv_order ;

keep trial_id recruiter_id recruiter_type job_id cargo_posicion_evaluado ejercicio cv_order I_noBIG5_cog ///
     cv_id c_name c_dob c_gender c_residarea c_educ1 c_educ2 c_educ3 ///
     c_expsect1 c_expsect2 c_expsect3 c_expsect4 c_profession c_yrsexp ///
     c_minoria_ev resp resp_Mrobot ;

reshape wide cv_id c_name c_dob c_gender c_residarea c_educ1 c_educ2 c_educ3 ///
    c_expsect1 c_expsect2 c_expsect3 c_expsect4 c_profession c_yrsexp ///
    c_minoria_ev resp resp_Mrobot, ///
    i(trial_id recruiter_id recruiter_type job_id cargo_posicion_evaluado ejercicio I_noBIG5_cog) ///
    j(cv_order) string ;

order trial_id recruiter_id recruiter_type cargo_posicion_evaluado ejercicio ;

gen t0 = cv_id_0 ;
gen t1 = cv_id_1 ;

tostring cv_id_0, replace ;
gen l = length(cv_id_0) ;
replace cv_id_0 = "00" + cv_id_0 if l == 1 ;
replace cv_id_0 = "0"  + cv_id_0 if l == 2 ;
drop l ;

tostring cv_id_1, replace ;
gen l = length(cv_id_1) ;
replace cv_id_1 = "00" + cv_id_1 if l == 1 ;
replace cv_id_1 = "0"  + cv_id_1 if l == 2 ;
drop l ;

gen cv_pair_id = cv_id_0 + cv_id_1 if t0 < t1 ;
replace cv_pair_id = cv_id_1 + cv_id_0 if t0 > t1 ;
drop t0 t1 ;

gen subject_cd = "1" if ejercicio == "Gender" ;
replace subject_cd = "2" if ejercicio == "Lgbt" ;
replace subject_cd = "3" if ejercicio == "Nacionality" ;
replace subject_cd = "4" if ejercicio == "Placebo" ;

gen dsubject_cd = "1" if ejercicio == "Gender" ;
replace dsubject_cd = "2" if ejercicio == "Lgbt" & c_gender_0 == "Male" ;
replace dsubject_cd = "3" if ejercicio == "Lgbt" & c_gender_0 == "Female" ;
replace dsubject_cd = "4" if ejercicio == "Nacionality" & c_gender_0 == "Female" ;
replace dsubject_cd = "5" if ejercicio == "Nacionality" & c_gender_0 == "Male" ;
replace dsubject_cd = "6" if ejercicio == "Placebo" ;

gen theme_pair_id = subject_cd + cv_pair_id ;
gen dtheme_pair_id = dsubject_cd + cv_pair_id ;

preserve ;
    egen tag = tag(dtheme_pair_id) ;
    keep if tag == 1 ;
    drop tag ;
    sort dtheme_pair_id ;

    gen diff_exp = abs(c_yrsexp_1 - c_yrsexp_0) ;
    gen diff_age = abs(c_dob_1 - c_dob_0) / 365.25 ;

    keep cv_pair_id diff_exp diff_age ;
    compress ;
    save "$PROC/PairedCVs_all_Ecuador.dta", replace ;
restore ;

merge m:1 cv_pair_id using "$PROC/mrobot_working.dta", keepusing(resp_Mrobot_1 resp_Mrobot_0) ;
drop _merge ;

egen group = group(dtheme_pair_id) ;
tostring group, replace ;
gen l = length(group) ;
replace group = "00" + group if l == 1 ;
replace group = "0"  + group if l == 2 ;
drop l ;
replace group = job_id + group ;

egen q = group(group) ;
drop group ;

preserve ;
    egen tag = tag(q) ;
    keep if tag == 1 ;
    keep q dsubject_cd cv_pair_id job_id ;
    compress ;
    save "$PROC/IRT_question_coding_correspondence.dta", replace ;
restore ;

sort recruiter_id q ;

* Optional validated correction retained from the previous replication check.
* It is applied at the trial level, before creating the final wide response matrix.
replace resp_0 = 1 if recruiter_id == "AI02099" & q == 31 ;

gen binary_M_r = (resp_0 == resp_Mrobot_0) ;

keep recruiter_id q binary_M_r I_noBIG5_cog ;

reshape wide binary_M_r, i(recruiter_id I_noBIG5_cog) j(q) ;

order recruiter_id I_noBIG5_cog binary_M_r* ;

compress ;
save "$PROC/IRT_responsedata_question_Majority.dta", replace ;


*===============================================================================;
* 13. ESTIMATE IRT AND SAVE TRIAL-LEVEL PARAMETERS ;
*===============================================================================;

use "$PROC/IRT_responsedata_question_Majority.dta", clear ;

merge 1:1 recruiter_id using "$PROC/recruiter_type_temp.dta" ;
drop _merge ;

keep if recruiter_type == "human" ///
     | recruiter_type == "robot-gamma6" ///
     | recruiter_type == "clone-gamma2" ///
     | recruiter_type == "clone-gamma5" ///
     | recruiter_type == "randomista" ;

drop if I_noBIG5_cog == 1 ;

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

matrix b = e(b) ;
matrix V = e(V) ;

local cn : colfullnames b ;
local n : word count `cn' ;

clear ;
set obs `n' ;

gen int idx = _n ;
gen str160 parm_full = "" ;
gen double estimate = . ;
gen double se = . ;

forvalues i = 1/`n' {;
    local nm : word `i' of `cn' ;
    replace parm_full = "`nm'" in `i' ;
    replace estimate = b[1,`i'] in `i' ;
    replace se = sqrt(V[`i',`i']) in `i' ;
};

gen str30 item = "" ;
replace item = regexs(1) if regexm(parm_full, "(binary_M_r[0-9]+)") ;

gen str160 parm_lower = lower(parm_full) ;

gen byte is_cons = strpos(parm_lower, "_cons") > 0 ;

gen str10 ptype = "" ;
replace ptype = "cons" if is_cons == 1 ;
replace ptype = "disc" if item != "" & is_cons == 0 ;

keep if item != "" & ptype != "" ;

gen double bval = estimate ;
gen double seval = se ;
gen int idxval = idx ;
gen str160 pname = parm_lower ;

keep item ptype bval seval idxval pname ;

reshape wide bval seval idxval pname, i(item) j(ptype) string ;

count if missing(bvalcons) | missing(bvaldisc) ;
if r(N) > 0 {;
    display as error "Some IRT items do not have both _cons and discrimination parameters." ;
    list item bvalcons bvaldisc if missing(bvalcons) | missing(bvaldisc) ;
    exit 459 ;
};

gen double cov_cons_disc = . ;

local N = _N ;
forvalues r = 1/`N' {;
    local i = idxvalcons[`r'] ;
    local j = idxvaldisc[`r'] ;
    replace cov_cons_disc = V[`i',`j'] in `r' ;
};

gen double cons = bvalcons ;
gen double cons_se = sevalcons ;

gen double disc_raw = bvaldisc ;
gen double disc_raw_se = sevaldisc ;

gen byte disc_is_log = strpos(pnamedisc, "ln") > 0 | strpos(pnamedisc, "log") > 0 ;

gen double different = disc_raw ;
gen double diff_se = disc_raw_se ;

replace different = exp(disc_raw) if disc_is_log == 1 ;
replace diff_se = exp(disc_raw) * disc_raw_se if disc_is_log == 1 ;

gen double location = -cons / different ;

gen double loc_var = ///
    (cons_se^2 / different^2) + ///
    ((cons^2 / different^4) * diff_se^2) - ///
    ((2 * cons / different^3) * cov_cons_disc) ;

gen double loc_se = sqrt(loc_var) ;
replace loc_se = . if loc_var < 0 ;

gen str30 trial = subinstr(item, "binary_M_r", "q", .) ;

keep trial location loc_se different diff_se ;
order trial location loc_se different diff_se ;

compress ;
save "$PROC/parameters_irt_raw.dta", replace ;


*===============================================================================;
* 14. VALIDATION CHECKS ;
*===============================================================================;

display as text "Processed files created in: $PROC" ;

foreach f in ///
    IRT_responsedata_question_Majority.dta ///
    recruiter_type_temp.dta ///
    recruiters_Majority.dta ///
    parameters_irt_raw.dta ///
    IRT_question_coding_correspondence.dta ///
    jobs.dta ///
    PairedCVs_all_Ecuador.dta {;

    capture confirm file "$PROC/`f'" ;
    if _rc {;
        display as error "Missing processed file: `f'" ;
        exit 601 ;
    };
    else {;
        display as result "OK: `f'" ;
    };
};

# delimit cr
