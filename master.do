* Master for MSP Project

	global directory "/Users/bbdaniels/github/ssm-rhcp-2019/"

	set matsize 5000

* Adofiles

	local adoFiles : dir `"${directory}/adofiles/"' files "*.ado"
	local adoFiles = subinstr(`" `adoFiles' "', `"""' , "" , .)
	foreach adoFile in `adoFiles' {
		qui do "${directory}/adofiles/`adoFile'"
		}

* Globals

  global outputs "${directory}/outputs/manuscript/"
  global outputsa "${directory}/outputs/appendix/"

* Graph options

  // Options for -twoway- graphs
  global graph_opts ///
  	title(, justification(left) color(black) span pos(11)) ///
  	graphregion(color(white) lc(white) lw(med)) bgcolor(white) ///
  	ylab(,angle(0) nogrid) xtit(,placement(left) justification(left)) ///
  	yscale(noline) xscale(noline) legend(region(lc(none) fc(none)))

  // Options for -graph- graphs
  global graph_opts_1 ///
  	title(, justification(left) color(black) span pos(11)) ///
  	graphregion(color(white) lc(white) lw(med)) bgcolor(white) ///
  	ylab(,angle(0) nogrid) ytit(,placement(left) justification(left))  ///
  	yscale(noline) legend(region(lc(none) fc(none)))

  // Options for histograms
  global hist_opts ///
  	ylab(, angle(0) axis(2)) yscale(off alt axis(2)) ///
  	ytit(, axis(2)) ytit(, axis(1))  yscale(alt)

  // Useful stuff

  global pct `" 0 "0%" .25 "25%" .5 "50%" .75 "75%" 1 "100%" "'
  global numbering `""(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)" "(10)""'
  global bar lc(white) lw(thin) la(center) fi(100) // ← Remove la(center) for Stata < 15

	// Personal
	global note_opts justification(left) color(black) span pos(7)
	global pct `" 0 "0%" .25 "25%" .5 "50%" .75 "75%" 1 "100%" "'
	global pctile `" 0 "1st" .25 "25th" .5 "50th" .75 "75th" 1 "99th" "'

* Have a lovely day!
