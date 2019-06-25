// Program to infill after tsfill

cap prog drop infill
prog def infill

syntax anything [=/exp], by(varlist) [stat(string asis)]

tempname temp

if "`stat'" == "" {
  local stat "min"
}

if "`exp'" != "" {
  bys `by' : egen `temp' = `stat'(`exp')
  gen `anything' = `temp'
}
else {
  foreach var of varlist `anything' {
    bys `by' : egen `temp' = `stat'(`var')
    replace `var' = .
    replace `var' = `temp' if `var' == .
    drop `temp'
  }
}

end

// Have a lovely day!
