#!/bin/bash

if [ "$#" -eq 10 ]
then
        lon1=$1
        nlon=$2
        dlon=$3
        lat1=$4
        nlat=$5
        dlat=$6
        INgrb=$7
        pname=$8
        uname=$9
        vname=${10}
else
        echo "Usage: grb2owi_snap.sh lon1 nlon dlon lat1 nlat dlat grib2file presname uname vname"
        exit 1
fi

# test lon1 for >0, sub 360 if so (assumes western hemis).
if (( $(bc <<< "$lon1 > 0") ))
then
        neglon=`echo $lon1-360 | bc`
else
        neglon=$lon1
fi

#echo lon="$lon1:$nlon:$dlon" lat="$lat1:$nlat:$dlat" 

# reduce to uvp
wgrib2 $INgrb -match "($pname|$uname|$vname)" -grib temp.grb &>/dev/null

# convert p from Pa to mb
wgrib2 temp.grb -if "$pname" -rpn "100:/" -fi -grib_out temp2.grb  &>/dev/null
#wgrib2 temp.grb -if "$pname" -rpn "0:*" -fi -grib_out temp2.grb  &>/dev/null

# interp to equidistant grid
wgrib2 temp2.grb -set_grib_type same -new_grid_winds earth -new_grid latlon $lon1:$nlon:$dlon $lat1:$nlat:$dlat   temp3.grb  &>/dev/null
#wgrib2 temp3.grb -gridout ll.dat

# time interpolation
# http://www.cpc.ncep.noaa.gov/products/wesley/wgrib2/time_interpolation.html

wgrib2 temp3.grb -match "$pname" -no_header -text_fmt '%9.4f' -text_col 8 -text p.txt &>/dev/null
wgrib2 temp3.grb -match "$uname" -no_header -text_fmt '%9.4f' -text_col 8 -text u.txt &>/dev/null
wgrib2 temp3.grb -match "$vname" -no_header -text_fmt '%9.4f' -text_col 8 -text v.txt &>/dev/null

# add eol just in case the last line has fewer than 8 columns
sed -i -e '$a\' p.txt
sed -i -e '$a\' u.txt
sed -i -e '$a\' v.txt
cat u.txt v.txt > uv.txt

# add a blank column on text files
#0        1         2         3         4         5         6         7         8
#12345678901234567890123456789012345678901234567890123456789012345678901234567890
#Oceanweather WIN/PRE Format                        200809030500     200809101650
#iLat= 601iLong= 601DX=0.0500DY=0.0500SWLat=20.00000SWLon=-90.0000DT=200809030500
# 1012.6060 1012.6050 1012.6050 1012.6050 1012.6050 1012.6050 1012.6040 1012.6040
awk '{print " "$0}' p.txt > p.txt2
awk '{print " "$0}' uv.txt > uv.txt2

# get time for tline
# need to check here if this is an analysis file, 
# in which case use the verificaiton time
# otherwise, use the forecast time
#ftype=`wgrib2 -d 1 -ftime  $INgrb  | cut -d : -f 3`
#if [ "$ftype" = "anl" ]; then
        dd=`wgrib2  -d 1 -end_FT  temp.grb  |awk 'BEGIN { FS = "=" } ; { print $2 }' `
        dd=`echo ${dd:0:12}`
#else
#        dd=`wgrib2  -d 1 -end_FT temp.grb  | cut -d = -f 2`
#        dd=`echo ${dd:0:12}`
#fi
tline="iLat=%4diLong=%4dDX=%6.4fDY=%6.4fSWLat=%8.5fSWLon=%8.4fDT=%12d\n"
printf $tline "$nlat" "$nlon" "$dlat" "$dlon" "$lat1" "$neglon" "$dd"> h.txt

# add headers to txt snaps
cat h.txt p.txt2 > p.txt3
cat h.txt uv.txt2 > uv.txt3

#cleanup
rm -f temp.grb temp2.grb temp3.grb p.txt2 uv.txt uv.txt2 p.txt u.txt v.txt *.txt-e h.txt

mv p.txt3 p.txt
mv uv.txt3 uv.txt

