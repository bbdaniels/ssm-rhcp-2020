* gitSuite

* gitReady

	cap prog drop gitReady
	prog def gitReady

	syntax anything

		! git --version
		global git `anything'

	end

* gitSet

	cap prog drop gitSet
	prog def gitSet

	syntax [anything]

		cd "${git}"
		! git pull

	end

* gitGo

	cap prog drop gitGo
	prog def gitGo

	syntax [anything]

		cd "${git}"

		* Change all xls outputs to magic csvs

			cap confirm file "${git}/csv.lua"
			if _rc != 0 ///
				cap copy "https://gist.githubusercontent.com/bbdaniels/089fa74cb312eac2694fbe683b9a9dc8/raw/d3416242d10ec3551e17253fa924cdf6bdf1677b/csv.lua" ///
				"${git}/csv.lua" , replace // <-- installs rendering luacode to overleaf : must set rendering to LuaTeX

		* Push to remote

			! git add -A
			! git commit -m "Updated from Stata at $S_DATE $S_TIME: `anything'"
			! git push

	end

* CSV converter

	cap prog drop xls2csv
	prog def xls2csv

	syntax anything , [dec(integer 2)] [stars]

	preserve

	cd "${git}"

	! /Applications/LibreOffice.app/Contents/MacOS/soffice ///
		--headless -convert-to xlsx:"Calc MS Excel 2007 XML" ///
			`anything'

	qui if "`stars'" != "" { // <-- load matrix of p values
		local anything_p = subinstr(`"`anything'"',".xls","_p.xls",.)

		! /Applications/LibreOffice.app/Contents/MacOS/soffice ///
			--headless -convert-to xlsx:"Calc MS Excel 2007 XML" ///
				`anything_p'

		sleep 5000
		import excel using "`anything_p'x" , clear allstring

			destring * ,force replace
			gen x = mod(_n,2)
			foreach var of varlist * {
				replace `var' = . if x == 1
				replace `var' = . if `var' >= 1
				}
			drop x
			mkmat * , matrix(themat)

		}

	sleep 5000
	import excel using "`anything'x" , clear allstring

	local zeroes "0."
	qui forvalues i = 1/`dec' {
		local zeroes "`zeroes'0"
		}
	qui foreach var of varlist * {
		replace `var' = "`zeroes'" if regexm(`var',"e-")
		replace `var' = substr(`var',1,strpos(`var',".")+`dec') if strpos(`var',".")
		replace `var' = "0" + `var' if strpos(`var',".") == 1
		replace `var' = subinstr(`var',"-.","-0.",1) if strpos(`var',"-.") == 1
		replace `var' = "`zeroes'" if `var' == "0"
		}

	qui	if "`stars'" != "" {

				qui count
				local nrows = `r(N)'
				local c = 0

				foreach var of varlist * {
					local ++c
					local r = 0

					forvalues i = 1/`r(N)' {
						local ++r
						local pv = themat[`r'+1,`c']
						replace `var' = `var' + "*" in `r' if `pv' <= .1
						replace `var' = `var' + "*" in `r' if `pv' <= .05
						replace `var' = `var' + "*" in `r' if `pv' <= .01

					}
				}

				drop in 2

				foreach var of varlist * {
					replace `var' = `var' + `"\phantom{***}"'
					replace `var' = subinstr(`var',`"***\phantom{***}"',"***",.)
					replace `var' = subinstr(`var',`"**\phantom{***}"',"**\phantom{*}",.)
					replace `var' = subinstr(`var',`"*\phantom{***}"',"*\phantom{**}",.)
				}
			}


	local theCSV = subinstr("`anything'","xls","csv",.)

	outsheet using "`theCSV'" , c replace noq non
	!rm `anything'
	!rm `anything'x
	!rm `anything_p'
	!rm `anything_p'x

	end

* Have a lovely day!
