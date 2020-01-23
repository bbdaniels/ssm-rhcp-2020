// Final figures and tables for M1 paper to SSM ------------------------------------------------

// ---------------------------------------------------------------------------------------------
// Figures -------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------

// Figure 1: Village-level provider counts -----------------------------------------------------
use "${directory}/Constructed/M1_Villages_prov1.dta" , clear

  // Create all-India category
  expand 2 , gen(false)
    replace state_code = 0 if false == 1
    lab def state_code 0 "All India" , modify
    replace u5mr = 100 if state_code == 0

  // Add U5MR to titles
  qui levelsof state_code , local(levels)
  foreach state in `levels' {
    local theLabel : label (state_code) `state'
    qui su u5mr if state_code == `state'
    if `state' != 0 lab def state_code `state' "`theLabel' [`r(mean)']" , modify
  }

  // Graph
  local opts  lc(black) lp(solid) lw(vthin) la(center) fc("0 109 219")
  local opts2 lc(black) lp(solid) lw(vthin) la(center) fc("146 0 0")

  graph bar (mean) type_?0 type_?1  [pweight = weight_psu]  ///
  , over(private, gap(*.5) label(labsize(tiny))) ///
    over(state_code , gap(*.5) label(labsize(vsmall)) sort((mean) u5mr) ) ///
    stack hor yscale(noline) ///
    $graph_opts_1 ysize(6) xoverhang ///
    ytit("Providers per Village {&rarr}" , placement(left) justification(left))  ///
    legend(on ring(1) pos(7) r(2) size(small) symysize(small) symxsize(small) ///
     order(13 "Public:"  1 "MBBS" 2 "AYUSH" 3 "Other" 4 "Unknown"  ///
           13 "Private:" 5 "MBBS" 6 "AYUSH" 7 "Other" 8 "Unknown") ///
    ) ///
    bar(1, fi(100) `opts') bar(2, fi(75) `opts') ///
    bar(3, fi(50) `opts') bar(4, fi(25) `opts') ///
    bar(5, fi(100) `opts2') bar(6, fi(75) `opts2') ///
    bar(7, fi(50) `opts2') bar(8,  fi(25) `opts2')

    graph export "${outputs}/f1-counts.eps" , replace

// Figure 2: Provider demographics -------------------------------------------------------------
use "${directory}/Constructed/M1_providers.dta" ///
  if private == 1 | mbbs == 1 , clear

	replace mbbs = 2 if private == 0 & mbbs == 1
	replace mbbs = 0 if private == 1 & mbbs != 1

  local opts lc(black) lw(thin) la(center) fi(100)

	weightab ///
		male s3q11_* otherjob_none age_* ///
		[pweight = weight_psu]  ///
		, se ${graph_opts} graph barlab xlab(${pct}) over(mbbs) ///
    barlook(1 fc(gs16) `opts' 2 fc(gs12) `opts' 3 fc(gs8) `opts' ) ///
		legend(on r(1) order(1 "Public MBBS" 3 "Private MBBS" 5 "Private Non-MBBS" ) ///
      symxsize(small) symysize(small)) ///
		yscale(noline) xscale(noline) xsize(6) legend(on)

		graph export "${outputs}/f2-demographics.eps" , replace

// Figure 3: SES - IP relationship -------------------------------------------------------------
use "${directory}/Constructed/M1_Villages_prov1.dta" , clear

	keep uvillid private state_code type_1 type_2 type_3 type_4 smses weight_psu u5mr
	reshape wide type_? , i(uvillid)  j(private) // Reduce to village level
		drop type_4? // Exclude unknown providers

  // Total number of providers per village
	egen nprov = rowtotal(type*)

  // Collapse to state level
	collapse ///
    (firstnm) smses u5mr  ///
    (mean) type* nprov    /// average numbers of providers per village
    [pweight = weight_psu] , by(state_code)

  // Calculate share of non-mbbs private providers
	gen nonmbbs = (type_31 + type_21) / nprov

  // Normalize state-mean SES
	egen norm = std(smses)

  // Calculate regression coefficients
  reg nonmbbs norm
    mat a = r(table)
    local b1 = a[1,1]
    local p1 = a[4,1]
    local r1 = e(r2)
  reg nonmbbs norm if nonmbbs > 0.4 // Exclude Kerala
    mat a = r(table)
    local b2 = a[1,1]
    local p2 = a[4,1]
    local r2 = e(r2)

    foreach param in b1 p1 b2 p2 r1 r2 {
      local `param' : di %3.2f ``param''
    }

  // Graph
	tw ///
    (lfitci  nonmbbs norm  , lc(black) lp(dash) acolor(gs14) alp(none) ) ///
    (lpoly   nonmbbs norm  , lw(thick) lc(maroon) ) ///
		(scatter nonmbbs norm  , m(.) mc(black) mlab(state_code) mlabangle(20) mlabc(black) mlabpos(9) mlabsize(vsmall)) ///
    (scatteri 0.10 -2 "Regression Coefficient: `b1' (p=`p1', R{superscript:2}=`r1')" , m(none) mlabc(black)) ///
    (scatteri 0.05 -2 "Regression Ex. Kerala: `b2' (p=`p2', R{superscript:2}=`r2')" , m(none) mlabc(black)) ///
	   , title("") note("") legend(off)  ///
		ylab($pct) ytit("Share of Private Non-MBBS Providers" , placement(left) justification(left)) ///
		xlab(-2 "-2 SD" -1 "-1 SD" 0 `""Average" "{&larr} State SES {&rarr}""' 1 "+1 SD" 2 "+2 SD") xtit("")

	  graph export "${outputs}/f3-sesshare.eps" , replace

// Figure 4: Excess capacity -------------------------------------------------------------------
use "${directory}/Constructed/M1_providers.dta" ///
  if private == 1 | mbbs == 1 , clear

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

  // bin minutes per patient and calculate hours per day
  recode s2q16 (1/5 = 5)(6/10 = 10)(11/15 = 15)(16/20 = 20)(26/max=30) , gen(minpp)
  gen hours = check*s2q16/60
    gen pct = hours / 6
    mean hours pct patients s2q16 [pweight = weight_psu] , over(group) // average utilization

  // Graph
  replace minpp = minpp+1 if group == 1 // Public MBBS
  replace minpp = minpp-1 if group == 2 // Private non-MBBS

  local opts lc(gray) lw(thin)

  isid uid , sort
  version 13

  gen blank = .

  tw ///
    /// Invisible cheaters for legend
    (scatter blank blank in 1 , m(.) mc(black) msize(*2)) ///
    (scatter blank blank in 1 , m(T) mc("0 109 219") msize(*4)) ///
    (scatter blank blank in 1 , m(S) mc("146 0 0") msize(*4)) ///
    /// Actual graph points
    (scatter check minpp if private == 1 & mbbs == 0, ///
        jitter(2) jitterseed(382375) m(.) mc("0 0 0") msize(*.1)) ///
    (scatter check minpp if private == 1 & mbbs == 1, ///
        jitter(2) jitterseed(382375) m(T) mc("0 109 219") msize(*.4)) ///
    (scatter check minpp if private == 0 & mbbs == 1, ///
        jitter(2) jitterseed(382375) m(S) mc("146 0 0") msize(*.4)) ///
    /// Reference line
    (function 72, range(3 7.5) `opts') ///
    (pci 36 7.5 72 7.5 , `opts') ///
    (function 36, range(7.5 12.5) `opts') ///
    (pci 36 12.5 24 12.5 , `opts') ///
    (function 24, range(12.5 17.5) `opts') ///
    (pci 24 17.5 18 17.5 , `opts') ///
    (function 18, range(17.5 22.5) `opts') ///
    (pci 18 22.5 14.4 22.5 , `opts') ///
    (function 14.4, range(22.5 27.5) `opts') ///
    (pci 14.4 27.5 12 27.5 , `opts') ///
    (function 12, range(27.5 32) `opts') ///
    (scatteri 12 32 "6 Hour Workday" , m(none) mlabc(gray)) ///
    (scatteri 12 40  , m(none) mlabc(gray)) ///
  ,  /// Design options
    legend(r(1) on order(1 "Private Non-MBBS" 2 "Private MBBS" 3 "Public MBBS")) ///
    xtit("Minutes per Patient {&rarr}")  ytit("Patients per Provider Day") ///
    xlab(5 ":05" 10 ":10" 15 ":15" 20 ":20" 25 ":25" 30 ":30+" , notick) ///
    legend(region(lc(none) fc(none))) xtit(,placement(left) justification(left))

		graph export "${outputs}/f4-capacity.eps" , replace

// Figure 5: MBBS - IP Quality correlations ----------------------------------------------------
use "${directory}/Constructed/M2_Vignettes.dta" ///
  if provtype == 1 | provtype == 6, clear

  // Get graphing points
  gen count = 1
  collapse (sum) count (mean) mean = theta_mle (sem) sem = theta_mle , by(mbbs statename)
    gen ul = mean + 1.96*sem
    gen ll = mean - 1.96*sem

  // Set up labelling and ordering
  bys statename : egen check = max(mean)
    sort check mbbs
    gen n = _n

    local x = 0
    local y = 0
    forv i = 1/`c(N)' {
      replace n = n + `x' in `i'
      local ++y
      if `y' == 2 {
        local x = `x' + 4
        local y = 0
      }
    }

    gen pos = -4.5
    gen pos2 = n

  // Graph
  dlab treat ///
    using "${directory}/Constructed/M2_Vignettes_long.dta" ///
    , x(theta_mle) range(-3(1)2) lab(-4) p
	tw ///
    (rcap ll ul n , lw(thin) lc(black) hor) ///
    (scatter n mean if mbbs == 0, mc(white) mlc(black) mlw(thin) m(s) msize(med)) ///
    (scatter n mean if mbbs == 1, mc(black) m(.) mlw(none) msize(medsmall)) ///
    (scatter pos2 pos if mbbs == 1, mlabpos(3) m(none) ml(statename) mlabc(black)) ///
  , yscale(off) xlab(-4.5 " " `r(theLabels)', labsize(small)) ysize(6) ///
    legend(on size(small) order (2 "Non-MBBS" 3 "MBBS") ring(0) pos(5) c(1)) ///
    xtit("{&larr} Average Provider Competence {&rarr}")

		graph export "${outputs}/f5-mbbs-ip-quality.eps" , replace

// Figure 6: Quality cutoffs -------------------------------------------------------------------
use "${directory}/Constructed/M1_Villages_prov1.dta" , clear

  egen total = rsum(type_?)
  gen any = (total>0)

  collapse (max) any regsim_? (mean) weight_psu , by(state_code villid) fast
  collapse (mean) any (mean) regsim_? , by(state_code)

  forvalues i = 1/3 {
    replace regsim_`i' = regsim_`i'*any
  }

  egen check = rank(regsim_3) , unique
    sort check
  decode state_code , gen(state)

  qui count
  forvalues i = 1/`r(N)' {
    local theState = state[`i']
    local theRank = check[`i']
    local theLabels = `"`theLabels' `theRank' "`theState'" "'
  }

  graph dot any regsim_1 regsim_2 regsim_3 ///
  , over(state, sort(4) descending axis(noline) label(labsize(small))) ///
      marker(1, m(T) msize(*3) mlc(white) mlw(vthin) mla(center)) ///
      marker(2, m(O) msize(*3) mlc(white) mlw(vthin) mla(center)) ///
      marker(3, m(S) msize(*3) mlc(white) mlw(vthin) mla(center)) ///
      marker(4, m(D) msize(*3) mlc(white) mlw(vthin) mla(center)) ///
    linetype(line) line(lw(thin) lc(gs14)) ///
    legend(on span c(1) size(small) order( ///
        1 "Villages with any providers" ///
        2 "Villages with MBBS providers" ///
        3 "Villages with providers better than state average MBBS" ///
        4 "Villages with providers better than national average MBBS")) ///
    ylab(${pct}) ytit("Proportion of villages {&rarr}") yscale(r(0) noline) ///
    legend(region(lc(none) fc(none))) noextendline ysize(6) ///
    ytit(,placement(left) justification(left))

    graph export "${outputs}/f6-quality-regulation.eps" ,  replace

// ---------------------------------------------------------------------------------------------
// Simulations ---------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------

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

// Figure 7: Status quo cost and quality -------------------------------------------------------
use "${directory}/Constructed/M1_providers-simulations.dta", clear
  pq Status Quo

  dlab treat ///
    using "${directory}/Constructed/M2_Vignettes_long.dta" ///
    , x(theta_mle) range(-1(1)2) lab(-1.5) p

  tw ///
    (function y=3^((x+2))+20 , ra(-1 1) lp(dash) lc(black)) ///
    (function y=3^((x+1.5))+10 , ra(-.5 1.5) lp(dash) lc(black)) ///
    (scatter cpp theta_mle , m(none) mlab(state_code) mlabc(black) mlabpos(0)) ///
  , xtit("{&larr} Average Interaction Provider Competence {&rarr}") ytit("Cost per Patient (Rs.)") ///
    yscale(r(0)) ylab(#6) xlab(`r(theLabels)')

     graph export "${outputs}/f7-status-quo.eps" ,  replace

  save "${directory}/constructed/sim-status-quo.dta" , replace

// Figure 8: AYUSH into public sector ----------------------------------------------------------
use "${directory}/Constructed/M1_providers-simulations.dta", clear

  gen ppd_old = ppd // Preserve old costs

  // Calculate patients and providers to relocate
  bys state_code: gen mpats = ppd if type == 4  // Total patients for private ayush
  bys state_code: gen mdocs = n if type == 4    // Total number of private ayush
  bys state_code: gen fee = medincome/n if type == 3 // Fee for public ayush
    infill mpats mdocs fee, by(state_code)           // For each state

  // Relocate patients
  replace ppd = ppd - (0.5*mpats) if type == 6    // Take from private IPs
      replace ppd = 0 if ppd < 0                  // Set as 0 if negative
    replace ppd = ppd + (0.5*mpats) if type == 4  // Give to new public ayush
  // Move ayush to public
  replace medincome = fee * n if type == 4        // Reset total public income
  replace medincome = ppd/ppd_old if type == 6    // Rescale private income
  replace private = 0 if type == 4

  // Calculate and tabulate
  pq Public AYUSH
    append using "${directory}/constructed/sim-status-quo.dta"
    encode case, gen(c)
    drop case
    reshape wide theta_mle cpp , i(state_code) j(c)

  dlab treat ///
    using "${directory}/Constructed/M2_Vignettes_long.dta" ///
    , x(theta_mle) range(-1(1)2) lab(-1.5) p

  twoway ///
    (pcarrow  cpp2 theta_mle2 cpp1 theta_mle1 , lc(black) mc(black)) ///
    (scatter cpp1 theta_mle1 , m(none) mlab(state_code) mlabpos(12) mlabc(black)) ///
  , legend(on order(1 "Policy: Public AYUSH") ring(0) pos(11) textfirst) ///
    xtit("{&larr} Average Interaction Provider Competence {&rarr}") ytit("Cost per Patient (Rs.)") ///
     yscale(r(0)) ylab(#6) xlab(`r(theLabels)')

  graph export "${outputs}/f8-public-ayush.eps" ,  replace

// Figure 9: Build out public sector -----------------------------------------------------------
use "${directory}/Constructed/M1_providers-simulations.dta", clear

  gen ppd_old = ppd // Preserve old costs

  // Calculate new share based on villages with public sector presence
  bys state_code: egen total = sum(ppd2)
    gen share = ppd2/total
    replace share = 0 if share == .
    drop total

  // Place new public sector MBBS providers in all villages
  gen n2 = vills if type == 1
    replace n2 = n if n2 == .
    replace medincome = medincome*(n2/n) if type == 1 // Scale salary costs

  // Reassign patients
  bys state_code: egen total = sum(ppd)
    replace ppd = total * share
    replace medincome = medincome*(ppd/ppd_old) if private == 1 // Scale fee costs

  // Calculate and tabulate
  pq PHCs Everywhere
    append using "${directory}/constructed/sim-status-quo.dta"
    encode case, gen(c)
    drop case
    reshape wide theta_mle cpp , i(state_code) j(c)

  replace cpp1 = 95 if state_code == 5 // Gujarat OVERFLOW
    label def state_code 5 "Gujarat* (132)" , modify

  dlab treat ///
    using "${directory}/Constructed/M2_Vignettes_long.dta" ///
    , x(theta_mle) range(-1(1)2) lab(-1.5) p

  twoway ///
    (pcarrow  cpp2 theta_mle2 cpp1 theta_mle1 , lc(black) mc(black)) ///
    (scatter cpp1 theta_mle1 , m(none) mlab(state_code) mlabpos(12) mlabc(black)) ///
  , legend(on order(1 "Policy: PHCs everywhere") ring(0) pos(11) textfirst) ///
    xtit("{&larr} Average Interaction Provider Competence {&rarr}") ytit("Cost per Patient (Rs.)") ///
     yscale(r(0)) ylab(#6) xlab(`r(theLabels)')

     graph export "${outputs}/f9-phcs-everywhere.eps" ,  replace

// ---------------------------------------------------------------------------------------------
// Tables --------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------

// Table 1: Village accessibility to provider types, by state ----------------------------------
use "${directory}/Constructed/M1_Villages_prov1.dta" , clear

  // Add public + private
  labelcollapse (max) regsim*  (sum) type_* patients (mean) weight_psu ///
    , by(state_code villid) fast

  gen mbbs_pri = type_11 > 0
    label var mbbs_pri "Private MBBS"
  gen mbbs_pub = type_10 > 0
    label var mbbs_pub "Public MBBS"

  gen mbbs = type_1 > 0
    label var mbbs "Any MBBS"

  egen temp = rsum(type_2 type_3 type_4)
    gen nonmbbs = temp > 0
    label var nonmbbs "Non-MBBS"
    drop temp

  egen temp = rsum(type_1 type_2 type_3 type_4)
    gen none = temp == 0
    label var none "No Providers"
    drop temp

  expand 2 , gen(false)
    replace state_code = 20 if false == 1
    label def state_code 20 "India Total" , modify


  labelcollapse (mean) mbbs_pub mbbs_pri mbbs nonmbbs none ///
    [pweight = weight_psu] , by(state_code)

  export excel using "${outputs}/t1-availability.xlsx" , first(varl) replace

// Table 2: Caseload regressions ---------------------------------------------------------------
use "${directory}/Constructed/M1_providers.dta" ///
  if private == 1 | mbbs == 1 , clear

  recode s1q15 (-99 = .)

  replace public = 1-private
  label var public "Public Sector"
  label var mbbs "MBBS Degree"
  label var male "Provider Who: Is Male"

  // Adjust number of patients for public clinics
  egen group = group(private mbbs) , label
      replace group = 2 if group == .
  bys finclinid : gen n = _N
    bys stateid finclinid_new : gen ndocs = _N
    replace patients = patients/ndocs if public == 1

  // Covariates
  local covars mbbs pop_vill male  ///
    s3q11_1 s3q11_2 s3q11_3 ///
    otherjob_none age_4060 age_60up

  // Stats
    su patients
      local mean = r(mean)
      local sd = r(sd)

  // Regressions
    // Column 1: Caseload
    reg patients public `covars' [pweight = weight_psu]
      est sto reg1
      estadd scalar mean = `mean'
      estadd scalar sd = `sd'

    // Column 2: State Characteristics
    reg patients public `covars' smses u5mr [pweight = weight_psu]
      est sto reg2
      estadd scalar mean = `mean'
      estadd scalar sd = `sd'

    // Column 3: State FE
    areg patients public `covars' [pweight = weight_psu] , a(state_code)
      est sto reg3
      estadd scalar mean = `mean'
      estadd scalar sd = `sd'

  // Output
  outwrite reg1 reg2 reg3 ///
    using "${outputs}/t2-caseload.xlsx" ///
    , replace stats(N mean sd)

// Table 3: Competence regressions -------------------------------------------------------------

// Calculate mean public competence in district
use "${directory}/Constructed/M2_Vignettes.dta" ///
  if (provtype == 1 | provtype == 6) & (public == 1), clear

  collapse (mean) pcomp = theta_mle , by(uniqdistid)
    label var pcomp "Mean District Public Competence"

  tempfile dist
    save `dist' , replace

// Regressions
use "${directory}/Constructed/M1_providers.dta" , clear
  merge m:1 uniqdistid using `dist' , nogen keep(3)

  label var public "Public Sector"
  label var mbbs "MBBS Degree"
  label var male "Provider Is Male"
  label var age "Provider Age"
  label var dmses "District SES"

  // Covariates
  local covars  mbbs male age public dmses

  // Stats program
  cap prog drop getstats
  prog def getstats
    syntax anything
    qui {
      est sto `anything'
      su theta_mle if e(sample) == 1
      estadd scalar mean = `r(mean)'
      estadd scalar sd = `r(sd)'
    }
  end

  // Regressions
    // Column 1: Base
    reg theta_mle `covars' [pweight = weight_psu]
      getstats reg1

    // Column 2: Public
    reg theta_mle `covars' if private == 0 [pweight = weight_psu]
      getstats reg1b

    // Column 3: Private Only
    reg theta_mle `covars'  if private == 1 [pweight = weight_psu]
      getstats reg2

    // Column 4: Private Only
    reg theta_mle `covars' pcomp if private == 1 [pweight = weight_psu]
      getstats reg2b

    // Column 5: Private IP Only
    reg theta_mle `covars' pcomp if private == 1 & mbbs == 0 [pweight = weight_psu]
      getstats reg3

    // Column 6: Base State FE
    areg theta_mle `covars' [pweight = weight_psu] , a(state_code)
      getstats reg4

    // Column 7: Public FE
    areg theta_mle `covars' if private == 0 [pweight = weight_psu] , a(state_code)
      getstats reg4b

    // Column 8: Private Only State FE
    areg theta_mle `covars' if private == 1 [pweight = weight_psu] , a(state_code)
      getstats reg5

    // Column 9: Private Only State FE
    areg theta_mle `covars' pcomp if private == 1 [pweight = weight_psu] , a(state_code)
      getstats reg5b

    // Column 10: Private IP Only State FE
    areg theta_mle `covars' pcomp if private == 1 & mbbs == 0 [pweight = weight_psu] , a(state_code)
      getstats reg6

  // Output
  outwrite reg1 reg1b reg2 reg2b reg3 reg4 reg4b reg5 reg5b reg6 ///
    using "${outputs}/t3-vignettes.xlsx" ///
    , replace stats(N mean sd r2) ///
    col("Full Sample" "Public Providers" "Private Providers" "Private Providers" "Private non-MBBS" ///
      "Full Sample" "Public Providers" "Private Providers" "Private Providers" "Private non-MBBS")

// Have a lovely day!
