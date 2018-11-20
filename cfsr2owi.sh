#!/usr/bin
set -e     # exit immediately on error
#set -x     # verbose with command expansion
set -u    # forces exit on undefined variables

# CFSR2owi builder

#  https://www.ncdc.noaa.gov/data-access/model-data/model-datasets/climate-forecast-system-version2-cfsv2

# CFSv2 Operational Analysis 6-Hourly Products
# https://www.ncei.noaa.gov/thredds/catalog/cfs_v2_anl_6h_flxf/catalog.html

# specify gnu date command
DATE="/usr/local/bin/gdate"

Usage()
{
cat  <<-ENDOFMESSAGE
Usage: cfsr2owi.sh --startdate "<startdate>" --enddate "<enddate>"

Brian Blanton
Renaissance Computing Institute			
Oct 2016

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
OPTS=`$GETOPT -o v --long startdate:,enddate: -n 'parse-options' -- "$@"`
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

while true ; do
    case "$1" in
        -v) VERBOSE=true; shift;;
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

echo "Times to retrieve/process:"
echo "   start=$startdate"
echo "   end=$enddate"

current="$start_date_stamp"
c=0
#declare -a filelist
filelist=()
while [ $current -le  $end_date_stamp ] ; do
	d=$(stamp2date "$current")
	year=${d:0:4}
	month=${d:5:2}
	day=${d:8:2}
	hour=${d:11:2}
	echo "$current $d $year $month $day $hour"
	current=$(( $current+$time_inc ))
	
	url=`echo $mainUrl | sed "s/<year>/\$year/g"`
	url=`echo $url | sed "s/<month>/\$month/g"`
	url=`echo $url | sed "s/<day>/\$day/g"`
	url=`echo $url | sed "s/<hour>/\$hour/g"`
	echo "$url"
	# get file and mv to unique filename in time-ascending order
	cc=`printf "%04d" $c`
	#curl $url > f.$cc
	filelist+=("f.$cc")
	#filelist[$c]="f.$cc"
	((c++))
done

# files have been downloaded.  now call grb2owi with this list as input
echo "${filelist[*]}"

grb2owi.sh --presname "PRES:surface:anl" ${filelist[*]}

