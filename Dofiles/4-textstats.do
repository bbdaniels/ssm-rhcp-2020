// Text statistics for M1 SSM paper

// Breakdown per village

  use "${directory}/Constructed/M1_Villages_prov1.dta" , clear

  egen nonmbbs = rsum(type_2 type_3 type_4 )
  mean nonmbbs [pweight = weight_psu] if private == 1
  mean type_3 [pweight = weight_psu] if private == 1

  collapse (sum) type_? (mean) weight_psu , by(state_code villid) fast // Add public + private
  egen total = rsum(type_?)
  mean total [pweight = weight_psu]
  mean total [pweight = weight_psu] , over(state_code)

  collapse (sum) type_? , by(state_code)

// All-providers stats

  use "${directory}/Constructed/M1_providers.dta" , clear

  ta othernone if survey == 1
  ta mbbs if survey == 1
  ta ayush if survey == 1

// Village accessibility

   use "${directory}/Constructed/M1_Villages_prov1.dta" , clear

   gen anymbbs = type_1 > 0

   mean anymbbs [pweight = weight_psu] , over(private)

   collapse (sum) type_? patients (mean) weight_psu , by(state_code villid) fast // Add public + private

   gen anymbbs = type_1 > 0
   gen anyip = type_3 > 0

   egen total = rsum(type_?)
    gen many = total > 3

   mean anymbbs anyip [pweight = weight_psu]

   collapse (sum) patients [pweight = weight_psu] , by(many)

   mean many [pweight = patients] // Patient share in competitive markets

// Excess capacity

  use "${directory}/Constructed/M1_providers.dta" if private == 1 | mbbs == 1 , clear
  count
  recode s1q15 (-99 = .)
  count if s2q15 != . & s2q16 != .

  // Adjust number of patients for public clinics
  egen group = group(private mbbs) , label
  bys finclinid: gen n = _N
   bys stateid finclinid_new: gen ndocs = _N
   replace patients = patients/ndocs if public == 1
	gen check = patients
    drop if (check > 120 | s2q16 == 0)

  // bin minutes per patient and calculate hours per day
  recode s2q16 (1/5 = 5)(6/10 = 10)(11/15 = 15)(16/20 = 20)(26/max=30) , gen(minpp)
  gen hours = check*s2q16/60
    gen pct = hours / 6
    mean pct patients s2q16 [pweight = weight_psu] , over(group) // average utilization

// Have a lovely day!
