#!/bin/sh
set -ex
PGM=covariance_matrix.exe
F90=ifort
OMP=" -openmp "

F90OPT='-convert big_endian -O3' # -Hs' -Kfast,parallel

rm -f *.mod
rm -f *.o

cd ./src/

COMMONDIR=../../../common/

ln -fs $COMMONDIR/SFMT.f90 ./
ln -fs $COMMONDIR/common.f90 ./
#ln -fs $COMMONDIR/common_smooth2d.f90 ./
ln -fs ../../common/module_map_utils.f90 ./


$F90 $OMP $F90OPT -c SFMT.f90
$F90 $OMP $F90OPT -c common.f90
$F90 $OMP $F90OPT -c module_map_utils.f90
$F90 $OMP $F90OPT -c covariance_matrix_tools.f90
$F90 $OMP $F90OPT -c covariance_matrix.f90
$F90 $OMP $F90OPT -o ${PGM} *.o  

rm -f *.mod
rm -f *.o

rm SFMT.f90 
rm common.f90 
rm module_map_utils.f90 
#rm common_smooth2d.f90

mv $PGM ../

echo "NORMAL END"
