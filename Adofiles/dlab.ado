// Set up multiple label option based on linear regression

cap prog drop dlab
prog def dlab , rclass

syntax anything [using/], ///
  Range(string asis)      ///
  Xvar(string asis)       ///
  LABval(string asis)     ///
  [Percent]

if `"`using'"' != `""' {
  preserve
  use `"`using'"' , clear
}

// Loop over variables and accumulate marginal values
cap mat drop results
qui foreach var of varlist `xvar' `anything' {
  reg `var' `xvar'
  margins , at(`xvar'=(`range'))
    mat a = r(table)'

  mat results = nullmat(results) ///
    , a[....,1]
}

// Variable labels
qui foreach var of varlist `xvar' `anything' {

  local lab : var label `var'
  local thisLabel = `"`thisLabel' "`lab':" "'

}
local theLabels = `"`labval'  `"`thisLabel'"'"'


// Loop over values and create labels
local row = 1
forvalues i = `range' {
  local col = 1
  local thisLabel ""
  qui foreach var of varlist `xvar' `anything' {

    local theValue = results[`row',`col']
    local theValue : di %3.2f `theValue'

    // Convert to percent
    if ("`percent'" != "") & (`col' > 1) {
      local theValue = subinstr("`theValue'","0.","",.) + "%"
    }

    local thisLabel = `"`thisLabel' "`theValue'" "'

  local ++col
  }
  local theLabels = `"`theLabels' `i'  `"`thisLabel'"'"'
local ++row
}

return local theLabels = `"`theLabels'"'

end

// End
