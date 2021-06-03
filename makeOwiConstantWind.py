#!/usr/bin/env python

import datetime
import numpy as np
#import sys, os
import getopt, sys

def usage():
    print "makeOwiConstantWind.py --wspd <spd>   --wdir <dir>   --wfac=<wfac>"
    print "	<spd> in mph, def=74" 
    print "	<dir> in deg CCW from TE, def=180"
    print "	<wfac> wind multiplier, in fort.22, def=1.0"
    print "	Settings: iLon=2, iLat=2"
    print "		  SWLon=-99, SWLat=5 [covers large-scale NA ADCIRC grid extents]"
    print "		  DX=60, DY=60 [covers large-scale NA ADCIRC grid extents]"
    print "		  <t1> start time, def=2000-09-01 00:00:00"
    print "		  <t2> end time, def=2100-09-01 00:00:00"
    sys.exit()

def main():

    try:
        opts, args = getopt.getopt(sys.argv[1:],"hs:d:f:",["help","wspd=","wdir=","wfac="])
    except getopt.GetoptError as err:
        print "\n"+str(err)+"\n"
        usage();

    wfac=1.0
    wspd=74.
    wdir=180.
    t1=datetime.datetime(2000,9,1,0,0,0)
    t2=datetime.datetime(2100,9,1,0,0,0)
    iLat=2
    iLon=2
    SWLat=0
    SWLon=-99
    DX=60
    DY=60
    header="Oceanweather WIN/PRE Format                        "\
        "{d1.year}{d1.month:02}{d1.day:02}{d1.hour:02}{d1.minute:02}     "\
        "{d2.year}{d2.month:02}{d2.day:02}{d2.hour:02}{d2.minute:02}".format(d1=t1,d2=t2)

    for opt, arg in opts:
        if opt == '-h':
            usage();
            sys.exit()
        elif opt in ("-s", "--wspd"):
            wspd = float(arg)
        elif opt in ("-d", "--wdir"):
            wdir = float(arg)
        elif opt in ("-f", "--wfac"):
            wfac = arg
        else:
            assert False, "unhandled option"
            usage();

    wspd=wspd/2.23694

    print "wspd={} [mps], wdir={} deg CCW TE".format(wspd,wdir)
    print "t1={}, t2={}".format(t1,t2)

    u=wspd*np.cos(wdir*np.pi/180)
    v=wspd*np.sin(wdir*np.pi/180)

    f22  = open('fort.22', 'w')
    f22.write("1\n0\n{}\n".format(wfac))
    f22.close()

    f221  = open('fort.221', 'w')
    f222  = open('fort.222', 'w')

    f221.write(header + '\n')
    f222.write(header + '\n')

    static_part="iLat={a1:4d}iLong={a2:4d}DX={a3:6.3f}DY={a4:6.3f}SWLat={a5:8.4f}SWLon={a6:8.4f}".format(a1=iLat, a2=iLon,a3=DX,a4=DY,a5=SWLat,a6=SWLon)

    tl="{a0}DT={d1.year}{d1.month:02}{d1.day:02}{d1.hour:02}{d1.minute:02}".format(a0=static_part,a1=iLat, a2=iLon,a3=DX,a4=DY,a5=SWLat,a6=SWLon,d1=t1)
    f221.write(tl + '\n')
    f221.write("{:10.4f}{:10.4f}{:10.4f}{:10.4f}\n".format(1013,1013,1013,1013))

    f222.write(tl + '\n')
    f222.write("{:10.4f}{:10.4f}{:10.4f}{:10.4f}\n".format(u,u,u,u))
    f222.write("{:10.4f}{:10.4f}{:10.4f}{:10.4f}\n".format(v,v,v,v))

    tl="{a0}DT={d1.year}{d1.month:02}{d1.day:02}{d1.hour:02}{d1.minute:02}".format(a0=static_part,a1=iLat, a2=iLon,a3=DX,a4=DY,a5=SWLat,a6=SWLon,d1=t2)
    f221.write(tl + '\n')
    f221.write("{:10.4f}{:10.4f}{:10.4f}{:10.4f}\n".format(1013,1013,1013,1013))

    f222.write(tl + '\n')
    f222.write("{:10.4f}{:10.4f}{:10.4f}{:10.4f}\n".format(u,u,u,u))
    f222.write("{:10.4f}{:10.4f}{:10.4f}{:10.4f}\n".format(v,v,v,v))

    f221.close()
    f222.close()

if __name__ == "__main__":
    main()
