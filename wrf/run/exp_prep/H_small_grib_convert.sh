#!/bin/bash

#CONVIERTE A UNA REGION MAS PEQUENIA

ITIME=20060101000000
ETIME=20091231180000
INT=21600
DESTDIR=$HOME/share/DATA//CFSR/
PARALLEL=8

REGNAME="argentina"
LATRANGE="-50:-20"
LONRANGE="270:310"

#REGNAME="japan"
#LATRANGE="25:50"
#LONRANGE="120:150"


source ../util.sh



CTIME=$ITIME
while [ $CTIME -le $ETIME ]
do

 cparallel=1
 while [ $cparallel -le $PARALLEL -a $CTIME -le $ETIME  ]
 do 
  echo "Voy a convertir el CFSR correspondiente a la fecha: $CTIME"
  FECHA=`echo $CTIME | cut -c1-8`
  ANIO=`echo $CTIME | cut -c1-4`
  MES=`echo $CTIME | cut -c5-6`
  DIA=`echo $CTIME | cut -c7-8`
  HORA=`echo $CTIME | cut -c9-10`

  wgrib2 $DESTDIR/pgbh00.gdas.${ANIO}${MES}${DIA}${HORA}.grb2 -set_grib_type jpeg -match ":(UGRD|VGRD|TMP|HGT|RH|PRES|SOILW|PRMSL|LAND|ICEC|WEASD):" -small_grib $LONRANGE $LATRANGE $DESTDIR/${REGNAME}_pgbh00.gdas.${ANIO}${MES}${DIA}${HORA}.grb2  > ./tmp.log  &


  CTIME=`date_edit2 $CTIME $INT`
  cparallel=`expr $cparallel + 1 `
#echo $CTIME
  done
  time wait
done
