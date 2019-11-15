
/* ---------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

M1 RHCP Paper Appendix

PURPOSE:  Appendix materials for M1 RHCP Paper

OUTLINE:
  PART 1:  Tables for appendix
  PART 2:  Figures for appendix

------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------*/

// Calculator ----------------------------------------------------------------------------------

  cap prog drop pq
  prog def pq
    syntax anything

    // Calculate provider loads and costs
    gen cpd = medincome/20    // cost per day for provider = monthly income / 20 days
    gen cpp = cpd/ppd         // cost per patient = (monthly income)/(20 days * patients)
      // Assign the higher of calculated cost or stated total fees to private provider
      replace cpp = fees_total if private == 1 & cpp < fees_total

    // Reweight by patient load and collapse cost and quality
    replace ppd = round(ppd,1)
     gen weight = ppd
     collapse (mean) cpp theta_mle [fweight = weight] , by(state_code) fast
     gen case = "`anything'"
  end

// Table 1: Sampling and survey completion -----------------------------------------------------
use "${directory}/Constructed/M1_providers.dta" , clear

gen n = 1

labelcollapse (sum) n survey vignette nosurvey permagone tempgone refuse noreason, by(statename)

  export excel ///
    using "${outputsa}/t-sampling.xlsx" , replace first(varl)

// Table 2: SES summary statistics -------------------------------------------------------------
use "${directory}/Constructed/M1_households.dta" ///
  if htag == 1 /// Household level
  , clear

  local vars roof water fan cooker mobilephone tv bike non_scst adultprieduc

  labelcollapse (mean) `vars' , by(statename) fast

  export excel ///
    using "${outputsa}/t-ses.xlsx" , replace first(varl)

// Table 3: Specific behaviors by vignette performance quintile --------------------------------

use "${directory}/Constructed/M2_Vignettes.dta" ///
    if (provtype == 1 | provtype == 6) & (theta_mle > -4.9), clear

    xtile quintile = theta_mle , n(5)
      lab def quintile 1 "Lowest Quintile" 2 "2nd Quintile" 3 "3rd Quintile" ///
        4 "4th Quintile" 5 "Highest Quintile"
      lab val quintile quintile

    egen diarrhea_freq = rmin(c3h3 c4h3)
    egen diarrhea_treat = rmin(treat3 treat4)
    egen diarrhea_correct = rmin(correct3 correct4)


    labelcollapse ///
      theta_mle c1e9 correct1 treat1 c2h4 c2e5  correct2 treat2 diarrhea_freq diarrhea_correct diarrhea_treat ///
    , by(quintile)

    label var theta_mle "Average Knowledge Score"
    label var diarrhea_freq "Diarrhea: Asked Frequency of Stool"
    label var diarrhea_treat "Diarrhea: Correct Management (ORS)"
    label var diarrhea_correct "Diarrhea: Correct Diagnosis"
    label var treat1 "TB: Correct Management (Medication)"
    label var correct2 "TB: Correct Diagnosis"
    label var treat2 "Pre-eclampsia: Correct Management (Medication)"
    label var correct2 "Pre-eclampsia: Correct Diagnosis"
    label var c1e9 "TB: Order Sputum AFB Test"
    label var c2h4 "Pre-eclampsia: Ask Swelling in Feet"
    label var c2e5 "Pre-eclampsia: Check Edema in Feet"
    label var antibiotic "Used antibiotics in any case"

    export excel ///
      using "${outputsa}/t-theta.xlsx" , replace first(varl)


// Table 3: Cost & quality as observed----------------------------------------------------------

// Calculate public sector salaries and patient shares
use "${directory}/Constructed/M1_providers.dta" if mbbs != . , clear
  // keep if mbbs == 1 | private == 1
  drop public type
  gen public = 1-private

  // Setup
  gen type = 3
    replace type = 1 if mbbs == 1 & private == 0
    replace type = 2 if mbbs == 1 & private == 1
    replace type = 4 if mbbs == 0 & private == 1
    label def type2 1 "Public MBBS" 2 "Private MBBS" 3 "Public non-MBBS" 4 "Private non-MBBS"
    label val type type2

  // Adjust for public providers
  gen ppd = patients     // patients per provider day = patients / providers at facility
    bys stateid finclinid_new: gen ndocs = _N
    replace ppd = ppd/ndocs if public == 1
    replace patients = patients/ndocs if public == 1

  // Calculate shares
  collapse (sum) ppd cost = medincome (mean) patients medincome private fees_total ///
    , by(state_code type) fast

    bys state_code: egen tot = sum(ppd)
    bys state_code: egen pub_total = sum(cost) if (private == 0)
    bys state_code: egen pub = sum(ppd) if (private == 0)

    gen pub_cost = pub_total/(pub*20)

    replace fees_total = . if type != 4
      infill fees_total , by(state_code)

    keep if type == 1

    gen pubshare = pub/tot
    replace patients = patients * 20

    lab var patients "Estimated Monthly Patients per Public MBBS"
    lab var pubshare "Public Sector Patient Share"
    lab var pub_cost "Public Sector Patient Cost"
    lab var medincome "Average Monthly Public MBBS Salary"
    lab var fees_total "Average Private Non-MBBS Fee"
    keep state_code pubshare medincome patients fees_total pub_cost
    tempfile costs
      save `costs' , replace

// Calculate overall patient costs
use "${directory}/Constructed/M1_providers-simulations.dta", clear
  pq Status Quo
  merge 1:1 state_code using `costs'

  lab var cpp "Cost Per Patient"
  lab var theta_mle "Average Provider Competence"

  // Export
  export excel ///
    state_code patients medincome pubshare pub_cost fees_total cpp theta_mle ///
    using "${outputsa}/t-costs.xlsx" , replace first(varl)

// Figure 1: Paramedical provider counts -------------------------------------------------------
use "${directory}/Constructed/M1_Villages_prov0.dta" , clear

  // Add U5MR to titles
  qui levelsof state_code , local(levels)
  foreach state in `levels' {
    local theLabel : label (state_code) `state'
    qui su u5mr if state_code == `state'
    lab def state_code `state' "`theLabel' [`r(mean)']" , modify
  }

  // Graph counts
  local opts lc(white) lw(none) la(center)

  graph bar (mean) type_?0 type_?1  [pweight = weight_psu]  ///
  , over(private, gap(*0) label(labsize(tiny))) ///
    over(state_code , gap(*.5) label(labsize(vsmall)) sort((mean) u5mr) ) ///
    stack hor yscale(noline) ///
    $graph_opts_1 ysize(6) ///
    ytit("Providers per Village {&rarr}" , placement(left) justification(left))  ///
    legend(on ring(1) pos(7) r(2) size(small) symysize(small) symxsize(small) ///
      order(13 "Public:"  1 "MBBS" 2 "AYUSH" 3 "Other" 4 "Unknown"  ///
            13 "Private:" 5 "MBBS" 6 "AYUSH" 7 "Other" 8 "Unknown") ///
    ) ///
    bar(1, fc(navy) fi(100) `opts') bar(2, fc(navy) fi(75) `opts') ///
    bar(3, fc(navy) fi(50) `opts') bar(4, fc(navy) fi(25) `opts') ///
    bar(5, fc(maroon) fi(100) `opts') bar(6, fc(maroon) fi(75) `opts') ///
    bar(7, fc(maroon) fi(50) `opts') bar(8, fc(maroon) fi(25) `opts')

    graph export "${outputsa}/f-paramedical.eps" , replace

// Figure 2: IRT score correlation with specific activities -------------------------------------
use "${directory}/Constructed/M2_Vignettes.dta" ///
   if (provtype == 1 | provtype == 6) & (theta_mle > -4.9), clear

   rename c?steroid ster?
   rename c?antb anti?
   rename c?med_total meds?

   reshape long treat anti ster meds, i(uid) j(case)


  xtile tpct = theta_mle , n(10)
    infill treat , by(tpct) stat(mean)
    infill anti , by(tpct) stat(mean)
    infill score = theta_mle , by(tpct) stat(mean)

    tw ///
      (histogram theta_mle, lc(white) la(center) fc(gs14) ///
        yaxis(2) w(.25) start(-5)) ///
      (lfit treat score , lc(maroon)) ///
      (lfit anti score, lc(navy)) ///
      (scatter treat score , mc(black)) ///
      (scatter anti score, mc(black)) ///
    , yscale(r(0)) ${hist_opts} ylab(${pct}) xlab(-5(1)5) ///
      xtit("Provider competence score") ytit(" ") ///
      legend(on r(1) ///
        order(1 "Distribution" 4 "Deciles " 2 "Correct" 3 "Antibiotics" ))

    graph export "${outputsa}/f-irt.eps" , replace

// Figure 3: Clinic visits within own village (HH Survey) --------------------------------------
use "${directory}/Constructed/M1_households.dta" ///
  if (s4q3==1) & (s4q4==1) /// Only primary medical care
  , clear

  gen priv = (s4q5>=5 & s4q5<=7 )

  gen invil = (s4q6 == 1 | s4q6 == 2) if !missing(s4q6)
  replace statename = proper(statename)

  replace invil=invil*100 // For percent labels

  graph hbar ///
    invil if (priv == 1) ///
  , over(statename , sort(1) descending ) blabel(bar, format(%9.0f)) ///
    ylab(0 "0%" 25 "25%" 50 "50%" 75 "75%" 100 "100%") ///
    ytit("Share of private primary care visits made in own village")

    local nb = `.Graph.plotregion1.barlabels.arrnels'
    qui forval i = 1/`nb' {
      .Graph.plotregion1.barlabels[`i'].text[1]="`.Graph.plotregion1.barlabels[`i'].text[1]'%"
    }
    .Graph.drawgraph

    graph export "${outputsa}/f-invillage.eps" , replace

// Figure 4/5: Self reported patient loads vs observed patients --------------------------------

use "${directory}/Constructed/birbhum-demand.dta" , clear

  tw ///
    (function x , range(0 40) lp(dash) lc(gray)) ///
    (scatter po_n prov_n, jitter(2)) ///
    (lpoly po_n prov_n, lc(black)) ///
  , ytit("Observed Caseload") xtit("Self-Reported Daily Caseload") ///
    legend(on order(3 "Relationship in Data") ring(0) pos(11))

    graph export "${outputsa}/f-caseload.eps" , replace

  tw ///
    (function x , range(0 40) lp(dash) lc(gray)) ///
    (scatter po_timetot prov_timetot, jitter(2)) ///
    (lpoly po_timetot prov_timetot, lc(black)) ///
  , ytit("Observed Time per Patient") xtit("Self-Reported Time per Patient") ///
    legend(on order(3 "Relationship in Data") ring(0) pos(11))

    graph export "${outputsa}/f-time.eps" , replace

// Figure 6: Time heaping ----------------------------------------------------------------------
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

    graph export "${outputsa}/f-time-heaping.eps" , replace

// Figure 7: MBBS-SES correlation --------------------------------------------------------------
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
  , r(1) ycom

  graph export  "${outputsa}/f-ses-competence.eps" , replace

// Figure 8: MBBS-SES correlation --------------------------------------------------------------
use "${directory}/Constructed/M1_providers.dta" if private == 1 | mbbs == 1 , clear
collapse (mean) mbbs theta_mle , by(state_code)

  tw ///
    (scatter theta_mle mbbs , mc(black) mlab(state_code) ///
      mlabc(black) mlabangle(30)) ///
    (lowess theta_mle mbbs) ///
  , xtit("MBBS Share of Providers Surveyed") ///
    ytit("Average Provider Competence") ///
    xlab(${pct})

    graph export  "${outputsa}/f-mbbs-competence.eps" , replace

// Figure 9: MBBS Differences by state  --------------------------------------------------------

  // Graph
  use "${directory}/Constructed/M2_Vignettes.dta" ///
    if provtype == 1 | provtype == 6, clear

  reg theta_mle mbbs#i.state_code

    margins state_code , dydx(mbbs)
    marginsplot , title("") horizontal ///
      plotopts(connect(none) yscale(reverse) ytit("") ///
        xtit("MBBS difference within state (SDs)") xline(0)  ///
        mc(black) msize(med) m(o)) ///
      ciopts(recast(rspike) lc(gs12))


      graph export "${outputsa}/f-mbbs-statewise.eps" , replace

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
      private mbbs male s3q11_* otherjob_none age ///
      patients fees_total s2q16 ///
      i.s3q4 i.s3q5 i.s2q20a i.s3q2

      // s3q4 s3q5 s2q20a s3q2

      lassoselect id = `e(ID_sel)'
        local covars = "`e(othervars_sel)'"
      reg vignette `covars'
        est sto Completion
        predict completion
      reg theta_mle `covars'
        est sto Performance
        predict performance

      coefplot Completion Performance, $graph_opts xline(0) ///
        title(Effect of Selected Variables on Vignettes) ///
        legend(on pos(11))


     // IPW
      reg theta_mle mbbs#i.state_code [pweight=completion]

        margins state_code , dydx(mbbs)
        marginsplot , title("") horizontal ///
          plotopts(connect(none) yscale(reverse) ytit("") ///
            xtit("MBBS difference within state (SDs)") xline(0)  ///
            mc(black) msize(med) m(o)) ///
          ciopts(recast(rspike) lc(gs12))




// Have a lovely day! --------------------------------------------------------------------------
