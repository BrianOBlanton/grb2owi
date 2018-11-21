#!/usr/bin
set -e     # exit immediately on error
#set -x     # verbose with command expansion
set -u    # forces exit on undefined variables

# CFSR2owi builder

#  https://www.ncdc.noaa.gov/data-access/model-data/model-datasets/climate-forecast-system-version2-cfsv2

# CFSv2 Operational Analysis 6-Hourly Products
# https://www.ncei.noaa.gov/thredds/catalog/cfs_v2_anl_6h_flxf/catalog.html

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
Usage: cfsr2owi.sh --startdate "<startdate>" --enddate "<enddate>" --skipdownload

Brian Blanton
Renaissance Computing Institute			
Nov 2018

ENDOFMESSAGE
}

date2stamp () {
    $DATE --utc --date "$1" +%s
}

stamp2date (){
    $DATE --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}

dateDiff (){
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

# specify CFSR times
#mainUrl='https://www.ncei.noaa.gov/thredds/dodsC/cfs_v2_anl_6h_flxf/<year>/<year><month>/<year><month><day>/cdas1.t<hour>z.sfluxgrbf00.grib2'
mainUrl='https://www.ncei.noaa.gov/thredds/fileServer/cfs_v2_anl_6h_flxf/<year>/<year><month>/<year><month><day>/cdas1.t<hour>z.sfluxgrbf00.grib2'
CFSR_begin_date="2011-04-01 00:00:00"
CFSR_end_date=$($DATE --date "now -15 days" "+%Y-%m-%d 00:00:00")
CFSR_begin_date_stamp=$(date2stamp "$CFSR_begin_date")
CFSR_end_date_stamp=$(date2stamp "$CFSR_end_date")
echo "CFS V2 start and end dates:"
echo "   $CFSR_begin_date $CFSR_begin_date_stamp"
echo "   $CFSR_end_date $CFSR_end_date_stamp"
time_inc=$(date2stamp "1970-01-01 06:00:00") # 6-hr in secs, past epoch
echo "Time interval set to $time_inc secs"


# process command line args
GETOPT='getopt'
if [[ `uname` == "Darwin" ]]; then 
        GETOPT='/usr/local/Cellar/gnu-getopt/1.1.6/bin/getopt'
fi
OPTS=`$GETOPT -o v,s --long startdate:,enddate:,skipdownload -n 'parse-options' -- "$@"`
if [ $? != 0 ]
then
	echo "Failed to parse commandline."
	Usage
	exit 1
fi
eval set -- "$OPTS"

# set defaults
startdate=$CFSR_begin_date
enddate=$($DATE --date "$startdate + 5 days" "+%Y-%m-%d 00:00:00")
VERBOSE=false
SKIPDOWNLOAD=false
LON1=261
NLON=160
DLON=.25
LAT1=5
NLAT=170
DLAT=.25
presname="PRES:surface:anl"

while true ; do
    case "$1" in
        -v) VERBOSE=true; shift;;
        -s) SKIPDOWNLOAD=true; shift;;
        --verbose) VERBOSE=true; shift;;
        --skipdownload) SKIPDOWNLOAD=true; shift;;
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

start_date_stamp=$(date2stamp "$startdate")
end_date_stamp=$(date2stamp "$enddate")

if [ "$VERBOSE" == true ]; then 
	echo "Updated args:"
	echo "   start=$startdate"
	echo "   end=$enddate"
	echo "   skipdownload=$SKIPDOWNLOAD"
	lon1n=$(echo "$LON1-360" | bc)
	echo "   LON1=$LON1 ($lon1n)" 
	echo "   NLON=$NLON"
	echo "   DLON=$DLON"
	LON2=`echo "$LON1 + $NLON * $DLON" | bc -l`
	lon2n=$(echo "$LON2-360" | bc)
	echo "      LON2=$LON2 ($lon2n) "   
	echo "   LAT1=$LAT1" 
	echo "   NLAT=$NLAT"
	echo "   DLAT=$DLAT"
	LAT2=`echo "$LAT1 + $NLAT * $DLAT" | bc -l`
	echo "      LAT2=$LAT2 " 
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
	if [ "$VERBOSE" == true ]; then 
		echo "$current $d $year $month $day $hour"
	fi
	current=$(( $current+$time_inc ))
	
	url=`echo $mainUrl | sed "s/<year>/\$year/g"`
	url=`echo $url | sed "s/<month>/\$month/g"`
	url=`echo $url | sed "s/<day>/\$day/g"`
	url=`echo $url | sed "s/<hour>/\$hour/g"`
	if [ "$VERBOSE" == true ]; then 
		echo "$url"
	fi
	# get file and mv to unique filename in time-ascending order
	cc=`printf "%04d" $c`
	if [[ "$SKIPDOWNLOAD" == "false" ]]; then
		curl $url > f.$cc
	fi
	filelist+=("f.$cc")
	((c++))
done

# files have been downloaded.  now call grb2owi with this list as input
args="--presname $presname --lon1 $LON1 --nlon $NLON --dlon $DLON --lat1 $LAT1 --nlat $NLAT --dlat $DLAT"
if [ "$VERBOSE" == true ]; then
	#echo "${filelist[*]}"
	args="--verbose $args"
	echo $args
fi
grb2owi.sh $args ${filelist[*]}

