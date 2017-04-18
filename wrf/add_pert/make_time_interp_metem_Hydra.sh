#!/bin/sh
set -ex

#. /usr/share/modules/init/sh
#module unload pgi-12.10
#module load intel-2013.1.117

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH

#LIB_NETCDF="-L/usr/local/lib/ -lnetcdff"
#INC_NETCDF="-I/usr/local/include/ "

LIB_NETCDF="-L/usr/local/lib/ -lnetcdff"
INC_NETCDF="-I/usr/local/include/ "

cd ./src

PGM=./time_interp_metem.exe
F90=ifort  #mpif90



OMP=
F90OPT='-convert big_endian -O3 ' #  -g -traceback'

#cd ./src

#PRE CLEAN
rm -f *.mod
rm -f *.o


#COMPILIN
$F90 $OMP $F90OPT -c SFMT.f90
$F90 $OMP $F90OPT -c common.f90
$F90 $OMP $F90OPT -c common_smooth2d.f90
$F90 $OMP $F90OPT $INC_NETCDF -c common_metem_memnc.f90
$F90 $OMP $F90OPT -c common_namelist.f90
$F90 $OMP $F90OPT -c common_perturb_ensemble_metem.f90
$F90 $OMP $F90OPT -c main_time_interp_metem.f90
$F90 $OMP $F90OPT -o ${PGM} *.o  ${LIB_NETCDF}

#mv *.exe ../

#CLEAN UP
rm -f *.mod
rm -f *.o

mv $PGM ../


echo "NORMAL END"
