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


//  MBBS-NON-MBBS DIFFFERENCES STATE-BY-STATE

  // Graph
  use "${directory}/Constructed/M2_Vignettes.dta" ///
    if provtype == 1 | provtype == 6, clear

  reg theta_mle mbbs i.state_code

    margins state_code , dydx(mbbs)
    marginsplot , title("") ${graph_opts} horizontal ///
      plotopts(connect(none) yscale(reverse) ytit("") ///
        xtit("MBBS difference within state (SDs)") xline(0))

  // Counts
  use "${directory}/Constructed/M2_Vignettes.dta" ///
    if provtype == 1 | provtype == 6, clear

  gen nonmbbs = 1-mbbs

  collapse (sum) mbbs nonmbbs , by(state_code) fast // State totals
  gen mbbs_pct = string(round((mbbs/(mbbs+nonmbbs)),.001)*100) + "%"
  gen nonmbbs_pct = string(round((nonmbbs/(mbbs+nonmbbs)),.001)*100) + "%"

  lab var state_code "State"
  lab var mbbs "MBBS Providers"
  lab var mbbs_pct "MBBS Share"
  lab var nonmbbs "Non-MBBS Providers"
  lab var nonmbbs_pct "Non-MBBS Share"

  export excel using "${outputsa}/t-shares.xlsx" , first(varl) replace


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
