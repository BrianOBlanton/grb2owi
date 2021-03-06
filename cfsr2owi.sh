#!/usr/bin
set -e     # exit immediately on error
#set -x     # verbose with command expansion
set -u    # forces exit on undefined variables

#
# CFSR2owi builder
#
#  https://www.ncdc.noaa.gov/data-access/model-data/model-datasets/climate-forecast-system-version2-cfsv2
#
# CFSv2 Operational Analysis 6-Hourly Products
# https://www.ncei.noaa.gov/thredds/catalog/model-cfs_v2_anl_6h_flxf/catalog.html
#

# specify gnu date command
arch=`uname`
if [ "$arch" == "Darwin" ]; then
        DATE="gdate"
else
	DATE="date" 
fi

Usage()
{
cat  <<-ENDOFMESSAGE
Usage: cfsr2owi.sh --startdate "<startdate>" --enddate "<enddate>" [--skipdownload --verbose --debug --zeropres]

Brian Blanton
Renaissance Computing Institute			
Nov 2018

ENDOFMESSAGE
}

date2stamp ()
{
    $DATE --utc --date "$1" +%s
}

stamp2date ()
{
    $DATE --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}

dateDiff ()
{
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp "$1")
    dte2=$(date2stamp "$2")
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec/sec*abs))
}

if [ "$#" -eq 0 ] ; then
        Usage
        exit 0
fi

echo "**********************************************"
echo "*                                            *"
echo "* CFSv2 to OWI converter                     *"
echo "* Version 1.0                                *" 
echo "* mainUrl=https://www.ncei.noaa.gov/thredds/\\*"
echo "*       fileServer/model-cfs_v2_anl_6h_flxf/ *"
echo "*                                            *"
echo "**********************************************"

# main NCEI URL 
#mainUrl='https://www.ncei.noaa.gov/thredds/dodsC/cfs_v2_anl_6h_flxf/<year>/<year><month>/<year><month><day>/cdas1.t<hour>z.sfluxgrbf00.grib2'
#mainUrl='https://www.ncei.noaa.gov/thredds/fileServer/cfs_v2_anl_6h_flxf/<year>/<year><month>/<year><month><day>/cdas1.t<hour>z.sfluxgrbf00.grib2'
mainUrl='https://www.ncei.noaa.gov/thredds/fileServer/model-cfs_v2_anl_6h_flxf/<year>/<year><month>/<year><month><day>/cdas1.t<hour>z.sfluxgrbf00.grib2'

#set defaults
CFSR_begin_date=$($DATE --date "now" "+%Y-%m-%d 00:00:00")
CFSR_end_date=$($DATE --date "now -15 days" "+%Y-%m-%d 00:00:00")
CFSR_begin_date_stamp=$(date2stamp "$CFSR_begin_date")
CFSR_end_date_stamp=$(date2stamp "$CFSR_end_date")
time_inc=$(date2stamp "1970-01-01 06:00:00") # 6-hr in secs, past epoch

startdate=$CFSR_begin_date
enddate=$($DATE --date "$startdate + 5 days" "+%Y-%m-%d 00:00:00")
VERBOSE="false"
DEBUG="false"
SKIPDOWNLOAD="false"
ZEROPRES="false"
LON1=261
NLON=197
DLON=.25
LAT1=5
NLAT=181
DLAT=.25

presname="PRES:surface:anl"
ugrdname="UGRD:10 m above ground"
vgrdname="VGRD:10 m above ground"
hgtname="HGT:surface:anl"
tmpname="TMP:2 m above ground"
prmslname="PRES:mean sea level:anl"

# process command line args
GETOPT='getopt'
if [[ `uname` == "Darwin" ]]; then 
        GETOPT='/usr/local/opt/gnu-getopt/bin/getopt'
fi
OPTS=`$GETOPT -o d,s,v --long startdate:,enddate:,skipdownload,verbose,debug,zeropres: -n 'parse-options' -- "$@"`
if [ $? != 0 ]
then
	echo "Failed to parse commandline."
	Usage
	exit 1
fi
eval set -- "$OPTS"

while true ; do
    case "$1" in
        -v) VERBOSE=true; shift;;
        -s) SKIPDOWNLOAD=true; shift;;
        -d) DEBUG=true; shift;;
        --verbose) VERBOSE=true; shift;;
        --debug) DEBUG=true; shift;;
        --skipdownload) SKIPDOWNLOAD=true; shift;;
        --zeropres) presscale=$2; shift 2;;
        --startdate) startdate=$2; shift 2;;
        --enddate) enddate=$2; shift 2;;
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

lon1n=$(echo "$LON1-360" | bc)
LON2=`echo "$LON1 + $NLON * $DLON" | bc -l`
lon2n=$(echo "$LON2-360" | bc)
LAT2=`echo "$LAT1 + $NLAT * $DLAT" | bc -l`

#if [ "$VERBOSE" == "true" ]; then 
	echo "* Final args:"
	echo "*    CFSv2 start = $startdate"
	echo "*    CFSv2 end   = $enddate"
        echo "*    Time interval $time_inc secs"
	echo "*    skipdownload=$SKIPDOWNLOAD"
	echo "*    verbose=$VERBOSE"
	echo "*    debug=$DEBUG"
	echo "*    DATE command=$DATE"
	echo "*    LON1=$LON1 ($lon1n)" 
	echo "*    NLON=$NLON"
	echo "*    DLON=$DLON"
	echo "*    LON2=$LON2 ($lon2n) "   
	echo "*    LAT1=$LAT1" 
	echo "*    NLAT=$NLAT"
	echo "*    DLAT=$DLAT"
	echo "*    LAT2=$LAT2 " 
        echo "*                                            *"
        echo "**********************************************"
#fi
if [ "$DEBUG" == "true" ]; then 
        set -x
fi

start_date_stamp=$(date2stamp "$startdate")
end_date_stamp=$(date2stamp "$enddate")
if [ $start_date_stamp -ge  $end_date_stamp ] ; then
	echo "start date must **PRECEED** end date."
	echo "startdate=$startdate"
	echo "enddate=$enddate"
	exit 1
fi

current="$start_date_stamp"
c=0
filelist=()

while [ $current -le  $end_date_stamp ] ; do

	d=$(stamp2date "$current")
	year=${d:0:4}
	month=${d:5:2}
	day=${d:8:2}
	hour=${d:11:2}

        echo "Processing $d $year $month $day $hour (epoch time=$current)"

	url=`echo $mainUrl | sed "s/<year>/\$year/g"`
	url=`echo $url | sed "s/<month>/\$month/g"`
	url=`echo $url | sed "s/<day>/\$day/g"`
	url=`echo $url | sed "s/<hour>/\$hour/g"`

	# get file and mv to unique filename in time-ascending order
	cc=`printf "%04d" $c`
	fbase=`printf "cdas1.t%02dz.sfluxgrbf00.grib2.%04d.%02d.%02d" ${hour#0} ${year#0} ${month#0} ${day#0} `   # "${a#0}" 
	f_small=`printf "%s.small.%s" $fbase $cc `
	f=`printf "%s.%s" $fbase $cc`

	#if [ "$VERBOSE" == "true" ]; then 
		echo "   +++ Retrieving $f"
	#fi

	if [[ "$SKIPDOWNLOAD" == "false" ]]; then

		curl $url --output $f  > curl.log 2>&1 

		# reduce size
		wgrib2 $f -match "($presname|$ugrdname|$vgrdname|$hgtname|$tmpname)"  -grib temp > /dev/null 2>&1
		
		# compute PRMSL
		wgrib2 temp -grib $f_small \
			-if "$tmpname"  -rpn "29.3:*:sto_1" -print "saved $tmpname to reg1" -fi  \
			-if "$hgtname"  -rpn "sto_2" -print "saved $hgtname to reg2" -fi \
			-if "$presname" -rpn "sto_3" -print "saved $presname to reg3" -fi  \
			-if_reg "1:2:3" \
				-rpn "rcl_2:rcl_1:/:exp:rcl_3:*" -set_var PRES -set_lev "mean sea level" -grib_out $f_small  > /dev/null 2>&1
        else
                echo Skipping download.  Only building filelist...
	fi
        
	filelist+=("$f_small")

	# increment 
	current=$(( $current + $time_inc ))
	c=$((c+1)) # ((c++))
done

# files have been downloaded.  now call grb2owi with this list as input
#args="--presname $presname --lon1 $LON1 --nlon $NLON --dlon $DLON --lat1 $LAT1 --nlat $NLAT --dlat $DLAT"
args="--lon1 $LON1 --nlon $NLON --dlon $DLON --lat1 $LAT1 --nlat $NLAT --dlat $DLAT"
echo Sending file list to grb2owi.sh
if [ "$VERBOSE" == "true" ]; then
	args="--verbose $args"
	echo $args
        echo "${filelist[*]}"
fi

echo " " 
sh grb2owi.sh $args ${filelist[*]}

# clean up

