// ---------------------------------------------------------------------------------------------
// NEW R&R -------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------

// Prices comparisons
use "${directory}/Constructed/M1_providers.dta" if private == 1  , clear

  // Calculate provider costs
  gen ppd = patients
  gen cpd = medincome/20    // cost per day for provider = monthly income / 20 days
  gen cpp = cpd/ppd         // cost per patient = (monthly income)/(20 days * patients)
    // Assign the higher of calculated cost or stated total fees to private provider
    replace cpp = fees_total if private == 1 & cpp < fees_total

// Time heaping

	use "${directory}/Constructed/M1_providers.dta" if private == 1 | mbbs == 1 , clear
  count
  recode s1q15 (-99 = .)
  count if s2q15 != . & s2q16 != .

  // Adjust number of patients for public clinics
  egen group = group(private mbbs) , label
      replace group = 2 if group == .
  bys finclinid: gen n = _N
   bys stateid finclinid_new: gen ndocs = _N
   replace patients = patients/ndocs if public == 1
	gen check = patients
    drop if (check > 120 | s2q16 == 0)

    gen check2 = s2q16 - 0.5
  histogram check2 if check2 <= 30, s(0.5) w(1) xlab(5(5)25) ///
    xtit("Minutes per Patient") freq fc(black) lc(white) la(center)

     recode s2q16 (1/5 = 5)(6/10 = 10)(11/15 = 15)(16/20 = 20)(26/max=30) , gen(minpp)
     gen hours = check*s2q16/60
       gen pct = hours / 6

     histogram hours, by(group, c(1)) frac

// MBBS-SES correlation
  use "${directory}/Constructed/M2_Vignettes.dta" ///
    if (provtype == 1 | provtype == 6) & public == 1, clear

  preserve
    collapse (mean) dmses theta_mle (firstnm) statename , by(state_code) fast
    rename dmses smses
    rename theta_mle stheta
    tempfile state
    save `state'
  restore

  collapse (mean) theta_mle state_code, by(dmses) fast
    merge m:1 state_code using `state' , keep(3)

  tw (lpolyci theta_mle dmses)(scatter theta_mle dmses if theta_mle < 2) ///
  ,  ///
    xtit("District SES") ytit("Mean Public Competence")

    graph save "${outputsa}/ses-1.gph" , replace

  sort state_code dmses
    bys state_code : gen include = _n == _N
  levelsof state_code , local(states)
  foreach state in `states' {
    local theGraphs "`theGraphs' (lfit theta_mle dmses if state_code == `state' , lc(black))"
  }

  tw (lpolyci theta_mle dmses) `theGraphs'  ///
    (scatter stheta smses if include == 1 ///
      , m(none) mlab(statename) mlabc(black) mlabpos(6)) ///
  ,   xtit("District SES") ytit("Mean Public Competence")

    graph save "${outputsa}/ses-2.gph" , replace

  graph combine ///
    "${outputsa}/ses-1.gph" ///
    "${outputsa}/ses-2.gph" ///
  , r(1) xsize(10) ycom

  graph export  "${outputsa}/ses-competence.eps" , replace


// MBBS composition
use "${directory}/Constructed/M1_providers.dta" , clear

  binscatter public dmses ///
  , ${graph_opts} xtit("District SES (20 Equal Bins)") ytit("Mean Public Share") ///
    ylab(0 "0%" .05 "5%" .1 "10%" .15 "15%" .2 "20%") title("District SES and Public Share")

use "${directory}/Constructed/M1_providers.dta" , clear
  keep if private == 1
  collapse (mean) mbbs dmses theta_mle (firstnm) statename, by(state_code)
  tw (lfit mbbs dmses) (scatter mbbs dmses  ///
     , m(.) mlab(statename) mlabc(black) mlabangle(30) mlabsize(small) mlabpos(3)) ///
  , xtit("District SES") ytit("Mean MBBS Share of Private Sector") ///
    ylab(0 "0%" .1 "10%" .2 "20%" .3 "30%" .4 "40%")

use "${directory}/Constructed/M1_providers.dta" , clear
  keep if private == 1

  ta state_code mbbs

//  MBBS-NON-MBBS DIFFFERENCES STATE-BY-STATE

  // Graph
  use "${directory}/Constructed/M2_Vignettes.dta" ///
    if provtype == 1 | provtype == 6, clear

  reg theta_mle mbbs#i.state_code

    margins state_code , dydx(mbbs)
    marginsplot , title("") ${graph_opts} horizontal ///
      plotopts(connect(none) yscale(reverse) ytit("") ///
        xtit("MBBS difference within state (SDs)") xline(0)) ///
        xsize(10)

      graph export "${outputsa}/mbbs-competence.eps" , replace


  // Counts
  use "${directory}/Constructed/M2_Vignettes.dta" ///
    if provtype == 1 | provtype == 6, clear

  gen nonmbbs = 1-mbbs

  bys state_code : egen mbbs_score = mean(theta_mle) if mbbs
  bys state_code : egen nonmbbs_score = mean(theta_mle) if nonmbbs

  collapse (sum) mbbs nonmbbs (mean) mbbs_score nonmbbs_score, by(state_code) fast // State totals
  gen mbbs_pct = string(round((mbbs/(mbbs+nonmbbs)),.001)*100) + "%"
  gen nonmbbs_pct = string(round((nonmbbs/(mbbs+nonmbbs)),.001)*100) + "%"
  tostring mbbs_score, gen(mbbs_lvl) format(%9.2f) force
  tostring nonmbbs_score, gen(nonmbbs_lvl) format(%9.2f) force

  lab var state_code "State"
  lab var mbbs "MBBS Providers"
  lab var mbbs_pct "MBBS Share"
  lab var nonmbbs "Non-MBBS Providers"
  lab var nonmbbs_pct "Non-MBBS Share"
  lab var mbbs_lvl "MBBS Mean Competence"
  lab var nonmbbs_lvl "Non-MBBS Mean Competence"

  export excel ///
    state_code mbbs mbbs_pct nonmbbs nonmbbs_pct mbbs_lvl nonmbbs_lvl ///
    using "${outputsa}/t-shares.xlsx" , first(varl) replace


// Table: vignette sampling and completion
use "${directory}/Constructed/M1_providers.dta" , clear

  // Cleaning
  lab var male "Male"
  tabgen type
  gen priv = practype == 2
    label var priv "Private"
  lab var patients "Caseload x10"
    replace patients = patients/10
  lab var fees_total "Total Fee x10"
    replace fees_total = fees_total/10
  lab var s2q16 "Time per Patient x10"
    replace s2q16 = s2q16/10
  lab var public "Public
  lab var age "Age"

  lab def vignette 0 "No Followup" 1 "Vignette"

  // Varlist
  local covars male s3q11_* otherjob_none age ///
    patients fees_total s2q16

  // Balance tables
    iebaltab  ///
       `covars' ///
      type_1 type_2 type_3 priv ///
    if survey == 1 ///
    , grpvar(vignette) save("${outputsa}/t-vignettes.xlsx") co(1) replace rowv

    iebaltab  ///
      `covars' ///
      priv ///
    if survey == 1 & type_1 == 1 ///
    , grpvar(vignette) save("${outputsa}/t-vignettes-mbbs.xlsx") co(1) replace rowv

    iebaltab  ///
      `covars' ///
      priv ///
    if survey == 1 & type_1 == 0 ///
    , grpvar(vignette) save("${outputsa}/t-vignettes-nonmbbs.xlsx") co(1) replace rowv

  // LASSO
    qui elasticnet linear vignette ///
      public mbbs male s3q11_* otherjob_none age ///
      patients fees_total s2q16 ///
      i.s3q4 i.s3q5 i.s2q20a i.s3q2

      lassoselect id = `e(ID_sel)'
        local covars = "`e(othervars_sel)'"
      reg vignette `covars'
        est sto Completion
      reg theta_mle `covars'
        est sto Performance

      coefplot Completion Performance, $graph_opts xline(0) ///
        title(Effect of Selected Variables on Vignettes) ///
        legend(on pos(11))

// Table : Regression PHC ----------------------------------------------------------------------

use "/Users/bbdaniels/Dropbox/Research/_Archive/Maqari1/Data/PHC_ProviderLong/Split/PHC_ProviderLong_clean_share.dta" , clear

gen age = 2010 - s3q2
clonevar num_patients = s4q12
clonevar time_patients = s4q13

reg s6q5 b11.s2q2 age num_patients time_patients i.s5q2
  est sto salary
  xml_tab salary  , replace save( "${outputsa}/t-salary.xlsx")



use "${directory}/Constructed/Combined_vignettes3.dta" , clear

  lab def stateid ///
     1   "Andhra Pradesh" ///
     2   "Assam" ///
     3   "Bihar" ///
     4   "Chhattisgarh" ///
     5   "Gujarat" ///
     6   "Haryana" ///
     7   "Himachal Pradesh" ///
     8   "Jharkhand" ///
     9   "Karnataka" ///
    10   "Kerala" ///
    11   "Madhya Pradesh" ///
    12   "Maharashtra" ///
    13   "Odisha" ///
    14   "Punjab" ///
    15   "Rajasthan" ///
    16   "Tamil Nadu" ///
    17   "Uttar Pradesh" ///
    18   "Uttarakhand" ///
    19   "West Bengal"
  lab val stateid stateid


  reg comp dmses if (public==1)  [pweight = weight_vig]
  reg comp dmses mbbs age i.male i.stateid if (public==1)  [pweight = weight_vig]

use "${directory}/Constructed/M1_providers.dta" , clear
  areg medincome age i.s3q11 i.male i.otherjob_none i.degreetype i.provtype if public == 1 [pweight = weight_psu] , a(state_code)
