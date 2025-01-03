#!/usr/bin/bash

# "$(nevents) {outbase} {logbase} $(run) $(seg) {outdir} $(build) $(tag) $(inputs) $(ranges) {neventsper}"  
nevents=${1}
outbase=${2}
logbase=${3}
runnumber=${4}
segment=${5}
outdir=${6}
build=${7/./}
dbtag=${8}
inputs=(`echo ${9} | tr "," " "`)  # array of input files 
ranges=(`echo ${10} | tr "," " "`)  # array of input files with ranges appended
neventsper=${11:-1000}
logdir=${12:-.}
pass0dir=${13}
#----
export cupsid=${@: -1}

echo $@ 

{

echo nevents: ${nevents}
echo outbase: ${outbase}
echo logbase: ${logbase}
echo run:     ${runnumber}
echo seg:     ${segment}
echo outdir:  ${outdir}
echo build:   ${build}
echo dbtag:   ${dbtag}
echo inputs:  ${inputs[@]}
echo nevper:  ${neventsper}
echo logdir:  ${logdir}
echo pass0dir: ${pass0dir}

export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}

#source /opt/sphenix/core/bin/sphenix_setup.sh -n ${7}
source sPHENIX_INIT ${7}
echo OFFLINE_MAIN: $OFFLINE_MAIN
echo NOPAYLOADCLIENT_CONF: $NOPAYLOADCLIENT_CONF
#export ODBCINI=./odbc.ini
 
# There ought to be just one here... but ymmv...
echo ${inputs[@]}
for i in ${inputs[@]}; do
    cp -v $i .
done
inputs0=${inputs[0]}

if test -f cupstest.py; then
   mv cupstest.py cups.py
fi

# Flag as started
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} started

################################################
# make calibration directory and fill it
caldir=${PWD}/results/${runnumber}
echo mkdir -p ${caldir}
mkdir -p ${caldir}

################################################
# Stage PASS0 calibrations
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message "Stage in pass0 from ${pass0dir}"
for calib in mbd_shape.calib mbd_sherr.calib mbd_timecorr.calib mbd_slewcorr.calib mbd_tt_t0.calib mbd_tq_t0.calib; do
    echo Stagein ${pass0dir}/${calib} to ${caldir}
    cp ${pass0dir}/${calib} ${caldir}/
done

# Flag as started
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running

################################################
# Pass 1 calibrations
echo "###############################################################################################################"
echo "Running pass1 calibration"
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message "Running PASS 1 calibration (hardcoded 100k events pass1)"
echo root.exe -q -b Fun4All_MBD_CalPass.C\(\"${inputs0}\",1,-1\) 
root.exe -q -b Fun4All_MBD_CalPass.C\(\"${inputs0}\",1,-1\) 

echo "Pass 1 calibration done"
ls -la *.root

# Flag as started
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running

################################################
# Pass 2 calibrations waveforms
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message "Running PASS 2 calibration, process waveforms"
echo root.exe -q -b Fun4All_MBD_CalPass.C\(\"${inputs0}\",2,${nevents}\)
root.exe -q -b Fun4All_MBD_CalPass.C\(\"${inputs0}\",2,${nevents}\)

echo "Pass 2 calibration done (waveforms processed)"
ls -la *.root

# Flag as started
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running

################################################
# Pass 2 calibrations (t0 offsets)
# Pass 2 calibrations mip fits
fname=$(ls -tr DST_UNCALMBD*.root | tail -1)

echo "###############################################################################################################"
echo "Running pass2.1 calibration"
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message "Running PASS 2.1 calibration"
    pass=0
    echo root.exe -q -b cal_mbd.C\(\"${fname}\",${pass},${nevents}\)
    root.exe -q -b cal_mbd.C\(\"${fname}\",${pass},${nevents}\)

echo "###############################################################################################################"
echo "Running pass2.2 calibration"
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message "Running PASS 2.2 calibration"
    pass=3
    runtype=1 # pp200
    echo root.exe -q -b cal_mbd.C\(\"${fname}\",${pass},${nevents},${runtype}\)
    root.exe -q -b cal_mbd.C\(\"${fname}\",${pass},${nevents},${runtype}\)

#done

# Flag as started
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message "Done"
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} finished -e 0

echo "T0 offsets and mip fits"
ls -la *.root

# Copy the entire results directory to outdir
cp -R results/${runnumber} ${outdir}/

for r in *.root; do
    ./stageout.sh ${r} ${outdir} ${outbase}-$(printf "%08d" ${runnumber})-$(printf "%05d" ${segment}).root
done

if [ -e cups.stat ]; then
    cp cups.stat ${logdir#file:/}/${logbase}.dbstat
fi

exit #?????????????


################################################




# Flag run as finished.  Increment nevents by zero
echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e 0 --nevents 0 --inc 
     ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e 0 --nevents 0 --inc 


} >& ${logdir#file:/}/${logbase}.out 

#cp ${logbase}.out  ${logdir}
#cp ${logbase}.err  ${logdir}



