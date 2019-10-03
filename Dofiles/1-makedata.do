// M1 Household Survey
use "${datadir}/Data/Raw/Maqari1/Household_data2.dta" , clear

	label var roof "Concrete or metal roof"
	label var tv "Television"
	label var water "Piped water"
	label var non_scst "Not Scheduled Caste/Tribe"
	label var bike "Bicycle"
	label var fan "Electric fan"
	label var cooker "Pressure cooker"
	label var mobilephone "Mobile phone"
  label var adultprieduc "Adult primary education"

  replace statename = proper(statename)

hashdata using "${directory}/Constructed/M1_households.dta" ,  replace
	use "${directory}/Constructed/M1_households.dta" , clear

// M1 Private providers

use "${datadir}/Data/Raw/Maqari1/VillageProvider1.dta" ///
  if provtype == 1 | provtype == 6, clear
  drop if s2q6 == 6 // Chemists

	encode statename , gen(state_code)

	replace private = practype - 1

	label def private 0 "Public" 1 "Private"
		label val private private

	tabgen s3q11
		label var s3q11_1 "Have Grade 10 Education"
		label var s3q11_2 "Have Grade 10+2 Education"
		label var s3q11_3 "Have Advanced Education"

	label var male "{bf:Providers Who:} Are Male"
	label var otherjob_none "Have No Other Occupation"

	gen age_2040 = age < 40
		label var age_2040 "Are Now Aged 20-40"
	gen age_4060 = age >= 40 & age <60
		label var age_4060 "Are Now Aged 40-60"
	gen age_60up = age >= 60
		label var age_60up "Are Now Aged 60+"

	gen agestart = s2q14a - s3q1
	gen age_2030 = agestart >=20 & agestart<=30
		label var age_2030 "Began Practice Aged 20-30"

    // U5MR by state (http://rchiips.org/nfhs/NFHS-4Reports/India.pdf Figure 7.2 Under-five Mortality Rate by State/UT)
    gen u5mr = .
      replace u5mr = 41 if state_code == 1
      replace u5mr = 57 if state_code == 2
      replace u5mr = 58 if state_code == 3
      replace u5mr = 64 if state_code == 4
      replace u5mr = 44 if state_code == 5
      replace u5mr = 41 if state_code == 6
      replace u5mr = 38 if state_code == 7
      replace u5mr = 54 if state_code == 8
      replace u5mr = 32 if state_code == 9
      replace u5mr = 7 if state_code == 10
      replace u5mr = 65 if state_code == 11
      replace u5mr = 29 if state_code == 12
      replace u5mr = 48 if state_code == 13
      replace u5mr = 33 if state_code == 14
      replace u5mr = 51 if state_code == 15
      replace u5mr = 27 if state_code == 16
      replace u5mr = 78 if state_code == 17
      replace u5mr = 47 if state_code == 18
      replace u5mr = 32 if state_code == 19
      label var u5mr "State Under-5 Mortality Rate"

      gen type = .
      	replace type = 1 if degreetype == 3
      	replace type = 2 if degreetype == 2
      	replace type = 3 if degreetype == 1
      	replace type = 4 if degreetype == .

      	label def dtype 1 "MBBS" 2 "AYUSH" 3 "Informal" 4 "Unknown" , modify
        label val type dtype

  // IRT

  merge 1:m finclinid_new finprovid_new ///
    using "${datadir}/Data/Raw/Maqari1/Combined_vignettes3.dta" ///
    , keep(1 3)


    egen treat_n = rowmean(treat?)
		egen diag_n = rowmean(correct?)
		egen antibi_n = rowmean(c?antb)

		egen qh_n1 = rowtotal(c1h1 rel11 c1h3 c1h4 c1h5 c1h6 c1h7)
		egen qe_n1 = rowtotal(c1e1 c1e2 c1e3 c1e4 c1e5 c1e6 c1e7 c1e8 c1e9 rel12 c1e11)
			replace qh_n1 = . if c1h1 == .
			replace qe_n1 = . if c1h1 == .

		egen qh_n2 = rowtotal(c2h1 c2h2 c2h3 c2h4 c2h5 c2h6 c2h7 c2h8 c2h9 c2h10 c2h11 c2h12 c2h13 c2h14 c2h15 c2h16 c2h17 c2h18 c2h19 )
		egen qe_n2 = rowtotal(c2e1 c2e2 rel2 c2e4 c2e5 c2e6 c2e7 c2e8 c2e9 c2e10 c2e11 c2e12)
			replace qh_n2 = . if c2h1 == .
			replace qe_n2 = . if c2h1 == .

		egen qh_n3 = rowtotal(c3h1 c3h2 c3h3 rel3 c3h5 )
		egen qe_n3 = rowtotal(c3e1 c3e2 c3e3 c3e4 c3e5 c3e6 c3e7 c3e8 c3e9 c3e10)
			replace qh_n3 = . if c3h1 == .
			replace qe_n3 = . if c3h1 == .

		egen qh_n4 = rowtotal(c4h1 c4h2 c4h3 rel4 c4h5 )
		egen qe_n4 = rowtotal(c4e1 c4e2 c4e3 c4e4 c4e5 c4e6 c4e7 c4e8 c4e9 c4e10)
			replace qh_n4 = . if c4h1 == .
			replace qe_n4 = . if c4h1 == .

		label def mbbs 0 "Non-MBBS" 1 "MBBS"
			label val mbbs mbbs

		gen uid = _n

		lookfor item

	// easyirt `r(varlist)' using "${directory}/Data/Clean/M2_Vignettes_IRT.dta" , id(uid)


		merge 1:1 uid using "${datadir}/Data/Clean/M2_Vignettes_IRT.dta" ///
    , nogen keepusing(theta_mle) keep(3)

    replace theta_mle = . if theta_mle < -4.5
			xtile theta_pct = theta_mle , n(100)
				replace theta_pct = theta_pct / 100

    gen vignette = theta_mle != .
      label var vignette "Completed Vignette"


hashdata using "${directory}/Constructed/M1_providers.dta" ,  replace
	use "${directory}/Constructed/M1_providers.dta" , clear

// M1 Villages
use "${datadir}/Data/Raw/Maqari1/VillageProvider1.dta" , clear

  // Cleaning
  drop vtag

  gen type = .
  	replace type = 1 if degreetype == 3
  	replace type = 2 if degreetype == 2
  	replace type = 3 if degreetype == 1
  	replace type = 4 if degreetype == .

  	label def dtype 1 "MBBS" 2 "AYUSH" 3 "Informal" 4 "Unknown" , modify
  		label val type dtype

  replace private = practype - 1
    label var private "Private"
  	label def private 0 "Public" 1 "Private"
  		label val private private

  	tabgen type

  	encode statename , gen(state_code)

		sort state_code villid
		egen vtag = tag(state_code villid)
		bys state_code : egen nvil = sum(vtag)

  // collapse to generate all-village list
  preserve
    // patient counts for public sector
    bys stateid finclinid_new: gen ndocs = _N
    replace patients = patients/ndocs if private == 0

    // collapse setup
    gen check = 1
    collapse (firstnm) smses weight_psu  pop_vill (sum) patients, by(state_code villid private)
    replace private = 1 if private == .
    drop if state_code == .
    egen uvillid = group(state_code villid )
    tsset uvillid private
  	tsfill , full
      bys uvillid : egen check = mean(villid)
      replace villid = check if villid == .
      drop check
    	bys uvillid : egen temp = mode(weight_psu)
    		replace weight_psu = temp if weight_psu == .
    		drop temp
    	bys uvillid : egen temp = mode(smses)
    		replace smses = temp if smses == .
    		drop temp
    	bys uvillid : egen temp = mode(villid)
    		replace villid = temp if villid == .
    		drop temp
    	bys uvillid : egen temp = mode(pop_vill)
    		replace pop_vill = temp if pop_vill == .
    		drop temp
      bys uvillid : egen check = mean(state_code)
      replace state_code = check if state_code == .
      drop check
    tempfile vils
      save `vils' , replace
  restore

// Provider and Paramedical datasets
foreach type in 0 1 {
preserve

  keep if (provtype == 1 | provtype == 6) == `type'
  drop if (s2q6 == 6 | s2q6 == 5) // Chemists and ASHAs

  if `type' {
  // Set up regulation simulation
    // Has MBBS
    bys state_code villid: gen regsim_1 = (type==1)
      label var regsim_1 "Has MBBS"

    // Has IRT > state mean MBBS
  	merge 1:1 stateid finclinid_new finprovid_new ///
      using "${directory}/Constructed/M1_providers.dta" ///
      , nogen keepusing(theta_mle)
    bys state_code: egen mbbsmean = mean(theta_mle) if (type==1)
      infill mbbsmean, by(state_code)
      gen regsim_2 = (theta_mle >= mbbsmean) if (theta_mle != .)
      label var regsim_2 "Quality > Mean MBBS"
      drop mbbsmean

    // Has IRT > mean MBBS (global)
  	merge 1:1 stateid finclinid_new finprovid_new ///
      using "${directory}/Constructed/M1_providers.dta" ///
      , nogen keepusing(theta_mle)
    egen mbbsmean = mean(theta_mle) if (type==1)
      gen temp = 1
      infill mbbsmean , by(temp)
      gen regsim_3 = (theta_mle >= mbbsmean) if (theta_mle != .)
      label var regsim_3 "Quality > Mean MBBS Global"
      drop mbbsmean temp

    if `type' local simulation (max) regsim_1 regsim_2 regsim_3 (mean) theta_mle

  }


	labelcollapse (sum) type_? ///
    `simulation' ///
    , by (state_code villid private)

	merge 1:1 state_code villid private using `vils' , keep(2 3) nogen

  // Disaggregate provider counts
	forvalues i = 1/4 {
    replace type_`i' = 0 if type_`i' == .
		separate type_`i' , by(private)
		// gen type_`i'2 = .
    replace type_`i'0 = 0 if type_`i'0 == .
    replace type_`i'1 = 0 if type_`i'1 == .

    local t2 : var label type_`i'
    label var type_`i'0 "Public `t2'"
    label var type_`i'1 "Private `t2'"
		}

  // U5MR by state (http://rchiips.org/nfhs/NFHS-4Reports/India.pdf Figure 7.2 Under-five Mortality Rate by State/UT)
  gen u5mr = .
    label var u5mr "Under-5 Mortality Rate"
    replace u5mr = 41 if state_code == 1
    replace u5mr = 57 if state_code == 2
    replace u5mr = 58 if state_code == 3
    replace u5mr = 64 if state_code == 4
    replace u5mr = 44 if state_code == 5
    replace u5mr = 41 if state_code == 6
    replace u5mr = 38 if state_code == 7
    replace u5mr = 54 if state_code == 8
    replace u5mr = 32 if state_code == 9
    replace u5mr = 7 if state_code == 10
    replace u5mr = 65 if state_code == 11
    replace u5mr = 29 if state_code == 12
    replace u5mr = 48 if state_code == 13
    replace u5mr = 33 if state_code == 14
    replace u5mr = 51 if state_code == 15
    replace u5mr = 27 if state_code == 16
    replace u5mr = 78 if state_code == 17
    replace u5mr = 47 if state_code == 18
    replace u5mr = 32 if state_code == 19

  // Unique village ID
  drop uvillid
    sort  state_code villid private
    egen uvillid = group(state_code villid)
    label var uvillid "Dataset Unique Village ID"


hashdata using "${directory}/Constructed/M1_Villages_prov`type'.dta" ,  replace
restore
}

use "${directory}/Constructed/M1_Villages_prov0.dta" , clear
use "${directory}/Constructed/M1_Villages_prov1.dta" , clear

// Cost simulations data setup

  use "${directory}/Constructed/M1_providers.dta" , clear
  replace public = 1-private

  // Create categories
  egen check = group(type private) , label

  // Calculate patients and adjust for public clinics
  gen ppd = patients
    bys stateid finclinid_new: gen ndocs = _N
    replace ppd = ppd/ndocs if public == 1
    replace patients = patients/ndocs if public == 1

  // Flag for public sector MBBS availability and shares calculation
  gen pubdoc = type == 1
    bys state_code villid: egen anypub = max(pubdoc)
    gen ppd2 = patients if anypub == 1

  // Collapse to average village shares within state
  gen n = 1
    drop vtag
    egen vtag = tag(state_code villid)
  collapse (rawsum) vtag n ppd ppd2 medincome (mean)  fees_total theta_pct theta_mle private , by(state_code check) fast
      bys state_code: egen vills = sum(vtag)
      drop vtag
      rename check type

  hashdata using "${directory}/Constructed/M1_providers-simulations.dta" ,  replace

// Get vignettes data

  hashdata "${datadir}/Constructed/M2_Vignettes.dta" ///
    using "${directory}/Constructed/M2_Vignettes.dta" , replace

  hashdata "${datadir}/Constructed/M2_Vignettes_long.dta" ///
    using "${directory}/Constructed/M2_Vignettes_long.dta" , replace

  hashdata "${datadir}/Data/Raw/Maqari1/Combined_vignettes3.dta" ///
    using "${directory}/Constructed/Combined_vignettes3.dta" , replace

// PHC data

import excel using "${datadir}/Data/Raw/PHC-Provider/PHC_ProviderLong.xlsx" ///
  , first clear

  foreach var of varlist * {
    local theLabel = `var'[1]
    lab var `var' "`theLabel'"
  }
    drop in 1/2

  destring s6q12 , replace force
    replace s6q12 = . if s6q12 < 0

  encode s1q3 , gen(state_code)

  compress
  hashdata using "${directory}/Constructed/M2_providers.dta" , replace reset

* Have a lovely day!
