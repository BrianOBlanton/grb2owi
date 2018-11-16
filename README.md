# grb2owi
converter from grib2 to OWI format wind/pre files



Usage: grb2owi.sh <options> gribfiles

Version 0.1

grb2owi converts grib2 files in standard NCEP projections to OWI files (221, 222)
on an equidistant lonlat grid.  It uses wgrib2 to extract pressure, u10 and v10
from a sequence of grib2 files, interpolate from the grib2 grid to the user-defined
grid, write out each time step (snap) to OWI text files, and concatenate the
results into consolidated 221,222 files.

## Assumptions

* UVP records are in each grib2 file
* Each file contains only one time level (split them into parts if needed)
* The files are named in a sequence that represents strictly increasing times, such that the wildcard expansion of the name is in the proper time order;
* If this is NOT true, then the user must put the files in the correct order on the commandline explicitly, e.g.,  ... file1.grb2 file2.grb2 ...
* The default variable names looked for in the grib2 files are: PRES UGRD VGRD
* The variables'' vertical levels are assumed to be "mean sea level", "10 m above ground", and "10 m above ground", respectively.
* The default variable:level combinations are thus:
	*    --presname "PRES:mean sea level"
	*    --ugrdname "UGRD:10 m above ground"
	*    --vgrdname "VGRD:10 m above ground"

## Options
<span style="font-family:Courier; font-size:1em;">
 `--`ugrdname : name of e/w wind speed variable in grib file (def="UGRD:10 m above ground")  
 `--`vgrdname : name of n/s wind speed variable in grib file (def="VGRD:10 m above ground")  
 `--`presname : name of MSL pressure variable in grib file (def="PRES:mean sea level")  
 `--`lon1     : longitude of lower left corner of lonlat box (def=276)  
 `--`nlon     : number of points in lon direction (def=100)  
 `--`dlon     : longitude increment for interpolation (def=.0267)  
 `--`lat1     : latitude of lower left corner of lonlat box (def=24)  
 `--`nlat     : number of points in lat direction (def=100)  
 `--`dlat     : latitude increment for interpolation (def=.0267)  
</span>

## Outputs
f.221, f.222 in OWI format


## Notes
* The grib interpolation process will convert longitudes to negative-west convention if lon1 > 0
* User should use wgrib2 to investigate grib grid so as to appropriately set equidistant grid parameters

## Examples
1. Convert files matching wildcard to OWI, using default regular grid parameters:  
<span style="font-family:Courier; font-size:1em;">
	 prompt> grb2owi.sh sfc_2016100620_*.grb2
</span>

1. Convert files matching wildcard to OWI, with 200 points in each direction, starting at lower-left corner == (278,22)  
<span style="font-family:Courier; font-size:1em;">
	prompt> grb2owi.sh --nlon 200 -nlan 200 -lon1 278 -lat1 22 sfc_2016100620_*.grb2
</span>

1. Convert three files explicitly named on the commandline, using defaults:   
<span style="font-family:Courier; font-size:1em;">
	prompt> grb2owi.sh file234.grb2 file9873.grb2 file1.grb2
</span>

1. Convert files using a non-default pressure variable:level:  
<span style="font-family:Courier; font-size:1em;">
	prompt> grb2owi.sh --presname="PRMSL:mean sea level" nam_2016100620_*.grb2
</span>
##   

---
         
Brian Blanton <Brian_Blanton@Renci.Org> `<Brian_Blanton@Renci.Org>`

Renaissance Computing Institute  
Oct 2018

