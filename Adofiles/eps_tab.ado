* Convert xml_tab table to .eps


cap prog drop eps_tab
prog def eps_tab

syntax anything


cd /users/bbdaniels/desktop

copy "https://gist.githubusercontent.com/bbdaniels/089fa74cb312eac2694fbe683b9a9dc8/raw/d3416242d10ec3551e17253fa924cdf6bdf1677b/csv.lua" ///
  "/Users/bbdaniels/desktop/csv.lua" , replace

! /Applications/LibreOffice.app/Contents/MacOS/soffice ///
  --headless -convert-to xlsx:"Calc MS Excel 2007 XML" ///
    /Users/bbdaniels/Dropbox/WorldBank/SSM-Papers/Outputs/3_rhcp_pope/tab1.xls

import excel using "/Users/bbdaniels/Desktop/tab1.xlsx" , clear

qui foreach var of varlist * {
  replace `var' = "0.00" if regexm(`var',"e-")
  replace `var' = substr(`var',1,strpos(`var',".")+2) if strpos(`var',".")
  replace `var' = "0" + `var' if strpos(`var',".") == 1
  replace `var' = subinstr(`var',"-.","-0.",1) if strpos(`var',"-.") == 1
  }

outsheet using "/Users/bbdaniels/Desktop/tab1.csv" , c replace noq non

end

* Have a lovely day!
