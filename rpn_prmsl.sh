#!/bin/bash
Z2="HGT:surface:anl"
T="TMP:2 m above ground"
Psurfaceanl="PRES:surface:anl"
file='cdas1.t00z.sfluxgrbf00_small.grib2'
wgrib2 $file -grib temp \
	-if "$T" -rpn "29.3:*:sto_1" -print "saved $T to reg1" -fi  \
	-if "$Z2" -rpn "sto_2" -print "saved $Z2 to reg2" -fi \
	-if "$Psurfaceanl" -rpn "sto_3" -print "saved $Psurfaceanl to reg3" -fi  \
	-if_reg "1:2:3" \
		-rpn "rcl_2:rcl_1:/:exp:rcl_3:*" -set_lev "mean sea level" -set_var PRES -grib_out temp  

#	-if "$T" -rpn "sto_1" -print "saved $T to reg1" -fi  \
#	-if "$Z2" -rpn "sto_2" -print "saved $Z2 to reg2" -fi \
#	-if "$Psurfaceanl" -rpn "sto_3" -print "saved $Psurfaceanl to reg3" -fi  \
#	-if_reg "1:2:3" \
#		-rpn "rcl_3:exp:rcl_2:29.3:rcl_1:*:/:*" -set_lev "mean sea level" -set_var PRMSL -grib_out temp  
