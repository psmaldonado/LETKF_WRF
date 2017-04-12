#!/bin/sh

BASEDIR=${HOME}/share/LETKF_WRF/
rm make_exec.log

#Generate pert_metem.exe
cd ${BASEDIR}/wrf/add_pert
nohup ./make_pert_metem_Hydra.sh > ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file pert_metem.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE pert_metem.exe"
  echo "======================"
fi

#Generate time_interp_metem.exe
cd ${BASEDIR}/wrf/add_pert
nohup ./make_time_interp_metem_Hintel.sh > ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file time_interp_metem.exe"
  echo "========================================================"
else
  echo "=========================="
  echo "DONE time_interp_metem.exe"
  echo "=========================="
fi

#Generate interpwrfout.exe
cd ${BASEDIR}/wrf/interpwrfout
nohup ./make_interpwrfout_Hintel.sh > ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file interpwrfout.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE interpwrfout.exe"
  echo "======================"
fi

#Generate letkf.exe
cd ${BASEDIR}/wrf/letkf
nohup ./make_letkf_Hydra.sh >> ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file letkf.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE letkf.exe"
  echo "======================"
fi

#Generate radar_prep.exe
cd ${BASEDIR}/wrf/obs/radar/radar_prep
nohup ./make_radar_prep_Hintel.sh >> ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file radar_prep.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE radar_prep.exe"
  echo "======================"
fi

#Generate wrf_to_radar.exe
cd ${BASEDIR}/wrf/obs/radar/wrf_to_radar
nohup ./H_make_wrf_to_radar.sh >> ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file wrf_to_radar.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE wrf_to_radar.exe"
  echo "======================"
fi

#Generate round_seconds.exe
cd ${BASEDIR}/wrf/tools/round_seconds
nohup ./make_round_second_Hintel.sh >> ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file round_seconds.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE round_seconds.exe"
  echo "======================"
fi

#Generate covariance_matrix.exe
cd ${BASEDIR}/wrf/verification/covmatrix
nohup ./make_covmatrix_Hintel.sh >> ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file covariance_matrix.exe"
  echo "========================================================"
else
  echo "==========================="
  echo "DONE covariance_matrix.exe"
  echo "==========================="
fi

#Generate obsope.exe
cd ${BASEDIR}/wrf/verification/obsope
nohup ./make_obsop_Hintel.sh >> ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file obsope.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE obsope.exe"
  echo "======================"
fi

#Generate verify.exe
cd ${BASEDIR}/wrf/verification/verify
nohup ./make_verify_Hintel.sh >> ${BASEDIR}/make_exec.log
grep  "NORMAL END" ${BASEDIR}/make_exec.log > null
if [ $? -ne 0 ] ; then
  echo "[Error]: Cannot create output file verify.exe"
  echo "======================================================="
else
  echo "======================"
  echo "DONE verify.exe"
  echo "======================"
fi


 


