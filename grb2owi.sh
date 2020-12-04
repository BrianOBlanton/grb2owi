#!/bin/bash
#set -x
set -e
set -u    # forces exit on undefined variables

Usage()
{
cat <<-ENDOFMESSAGE

Usage: grb2owi.sh <options> gribfiles

Version 0.1

grb2owi converts grib2 files in standard NCEP projections to OWI files (221, 222) 
on an equidistant lonlat grid.  It uses wgrib2 to extract pressure, u10 and v10 
from a sequence of grib2 files, interpolate from the grib2 grid to the user-defined 
grid, write out each time step (snap) to OWI text files, and concatenate the 
results into consolidated 221,222 files.  

By default, it assumes that:
        * UVP records are in each grib2 file
        * Each file contains only one time level
        * The files are named in a sequence that represents strictly increasing times, 
        *       such that the wildcard expansion of the name is in the proper time order;
        *       if this is NOT true, then the user must put the files in the correct 
        *       order on the commandline explicitly, e.g.,  ... file1.grb2 file2.grb2 ...
        * The default variable names looked for in the grib2 files are: PRES UGRD VGRD
        * The variables'' vertical levels are assumed to be "mean sea level", 
        *       "10 m above ground", and "10 m above ground", respectively.
        * The default variable:level combinations are thus:
        *    --presname "PRES:mean sea level"
        *    --ugrdname "UGRD:10 m above ground"
        *    --vgrdname "VGRD:10 m above ground"

Options:
        --ugrdname : name of e/w wind speed variable in grib file (def="UGRD:10 m above ground")
        --vgrdname : name of n/s wind speed variable in grib file (def="VGRD:10 m above ground")
        --presname : name of MSL pressure variable in grib file (def="PRES:mean sea level")
        --lon1     : longitude of lower left corner of lonlat box (def=276)
        --nlon     : number of points in lon direction (def=100)
        --dlon     : longitude increment for interpolation (def=.0267)
        --lat1     : latitude of lower left corner of lonlat box (def=24)
        --nlat     : number of points in lat direction (def=100)
        --dlat     : latitude increment for interpolation (def=.0267)

Outputs:
        f.221, f.222 in OWI format

Notes:
        *) The grib interpolation process will convert longitudes to negative-west 
          	convention if lon1 > 0
        *) User should use wgrib2 to investigate grib grid so appropriately set 
         	equidistant grid parameters

Examples:
        1) Convert files matching wildcard to OWI, using default regular grid parameters:
                grb2owi.sh sfc_2016100620_*.grb2
        2) Convert files matching wildcard to OWI, with 200 points in each direction, 
           starting at lower-left corner == (278,22)
                grb2owi.sh --nlon 200 -nlan 200 -lon1 278 -lat1 22 sfc_2016100620_*.grb2
        3) Convert three files explicitly named on the commandline, using defaults: 
                grb2owi.sh file234.grb2 file9873.grb2 file1.grb2
        4) Convert files using a non-default pressure varuable:level: 
                grb2owi.sh --presname="PRMSL:mean sea level" nam_2016100620_*.grb2
                
                
Brian Blanton
Renaissance Computing Institute			
Oct 2016

ENDOFMESSAGE
}

#####
#####  parse input arguments
#####
if [ "$#" -eq 0 ] ; then
        Usage
        exit 0
fi

GETOPT='getopt'
if [[ `uname` == "Darwin" ]]; then 
        #GETOPT='/usr/local/Cellar/gnu-getopt/1.1.6/bin/getopt'
        GETOPT='/usr/local/opt/gnu-getopt/bin/getopt'
fi

OPTS=`$GETOPT -o v --long ugrdname:,vgrdname:,presname:,lon1:,nlon:,dlon:,lat1:,nlat:,dlat:,verbose -n 'parse-options' -- "$@"`

if [ $? != 0 ]
then
    echo "Failed to parse commandline."
    exit 1
fi

eval set -- "$OPTS"

ugrdname="UGRD:10 m above ground"
vgrdname="VGRD:10 m above ground"
presname="PRES:mean sea level"
LON1=276
NLON=100
DLON=.0267
LAT1=24
NLAT=100
DLAT=.0267
VERBOSE=false

while true ; do
    case "$1" in
        -v) VERBOSE=true; shift;;
        --verbose) VERBOSE=true; shift;;
        --lon1) LON1=$2; shift 2;;
        --nlon) NLON=$2; shift 2;;
        --dlon) DLON=$2; shift 2;;
        --lat1) LAT1=$2; shift 2;;
        --nlat) NLAT=$2; shift 2;;
        --dlat) DLAT=$2; shift 2;;
        --ugrdname) ugrdname=$2; shift 2;;
        --vgrdname) vgrdname=$2; shift 2;;
        --presname) presname=$2; shift 2;;
        --) shift; break;;
    esac
done

if [ "$VERBOSE" == true ]; then 
        echo VERBOSE = $VERBOSE
        echo LON1 = $LON1
        echo NLON = $NLON
        echo DLON = $DLON
        echo LAT1 = $LAT1
        echo NLAT = $NLAT
        echo DLAT = $DLAT
        echo Pressure Variable Name = $presname
        echo UGRD Variable Name = $ugrdname
        echo VGRD Variable Name = $vgrdname
        echo "Remaining Args:"
        echo $@
fi

#####
#####  done parsing input arguments
#####

WGRIB2=`which wgrib2`
if [ $? -eq 0 ]; then
        if [ "$VERBOSE" == true ]; then 
                echo "Found wgrib2 at $WGRIB2"
        fi
else
        echo "Cant find wgrib2"
        exit 1
fi

FirstFile=$1
nfiles="$#"
echo "$nfiles grb2 files to process.  Go get coffee..."
echo " " 

if [ $nfiles -lt 2 ]; then
        LastFile=$FirstFile
else
        LastFile=${!nfiles}
fi
echo "FirstFile=$FirstFile"
echo "LastFile =$LastFile"
echo " " 

#####
##### Check for variables in first grib file
#####

tt=`$WGRIB2  -match "$presname" "$FirstFile" `
if [ -z "$tt" ] ; then 
	echo "Pressure variable ($presname) not found in $FirstFile"
	exit 1
fi
tt=`$WGRIB2  -match "$ugrdname" "$FirstFile" `
if [ -z "$tt" ] ; then 
	echo "UGRD variable ($ugrdname) not found in $FirstFile"
	exit 1
fi
tt=`$WGRIB2  -match "$vgrdname" "$FirstFile" `
if [ -z "$tt" ] ; then 
	echo "VGRD variable ($vgrdname) not found in $FirstFile"
	exit 1
fi
		
#####
##### build header line
#####

t1=`$WGRIB2 -d 1 -end_FT  "$FirstFile"  | cut -d = -f 2`
t1=`echo ${t1:0:12}`
if [ "$VERBOSE" == true ]; then echo "Starting Time = $t1"; fi
t2=`$WGRIB2 -d 1 -end_FT  "$LastFile"  | cut -d = -f 2`
t2=`echo ${t2:0:12}`
if [ "$VERBOSE" == true ]; then echo "Ending Time   = $t2"; fi

IFS=';'
hline='Oceanweather WIN/PRE Format                        %12s     %12s\n'
printf $hline "$t1" "$t2" > h_main.txt
unset IFS
echo "OWI Header line:"
cat h_main.txt
echo " " 

#####
##### build individual snap files
#####

let c=10000
for f in "$@"
do
        dd=`$WGRIB2  -d 1 -end_FT  $f |awk 'BEGIN { FS = "=" } ; { print $2 }' `
        echo "Processing $f @ $dd ..."
        com="sh grb2owi_snap.sh $LON1 $NLON $DLON $LAT1 $NLAT $DLAT $f \"$presname\" \"$ugrdname\" \"$vgrdname\""
        if [ "$VERBOSE" == true ]; then 
                echo "$com"
        fi
        sh grb2owi_snap.sh $LON1 $NLON $DLON $LAT1 $NLAT $DLAT $f "$presname" "$ugrdname" "$vgrdname"   
        if [ $? != 0 ]; then
        	echo grb2owi_snap.sh  failed with these parameters:
        	echo "$LON1 $NLON $DLON $LAT1 $NLAT $DLAT $f $presname $ugrdname $vgrdname"
        	exit 1
        fi

	mv p.txt p.txt.$c
        mv uv.txt uv.txt.$c
        let "c++" 

done

#####
##### build final file
#####
echo "Assembling final fort.22{1,2} files ..."
cat h_main.txt > fort.221
cat p.txt.* >> fort.221
cat h_main.txt > fort.222
cat uv.txt.* >> fort.222

rm *.txt.1* h_main.txt

