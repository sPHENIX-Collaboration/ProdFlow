#!/usr/bin/bash

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

{

export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}
hostname

source /opt/sphenix/core/bin/sphenix_setup.sh -n ${7}

export ODBCINI=./odbc.ini

#______________________________________________________________________________________ started __
#
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} started
#_________________________________________________________________________________________________

echo ..............................................................................................
echo $@
echo .............................................................................................. 
echo nevents: $nevents
echo outbase: $outbase
echo logbase: $logbase
echo runnumb: $runnumber
echo segment: $segment
echo outdir:  $outdir
echo build:   $build
echo dbtag:   $dbtag
echo inputs:  ${inputs[@]}
echo nper:    $neventsper
echo .............................................................................................. 

ls ${inputs[@]} > input.list

#______________________________________________________________________________________ running __
#
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} inputs --files ${inputlist}
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running
#_________________________________________________________________________________________________



out0=${logbase}.root
out1=HIST_HCALOUT_${logbase#DST_}.root
out2=HIST_HCALIN_${logbase#DST_}.root


echo root.exe -q -b Fun4All_HCalCosmics.C\(${nevents},\"input.list\",\"${outdir}\",\"${out0}\",\"${out1}\",\"${out2}\"\);
     root.exe -q -b Fun4All_HCalCosmics.C\(${nevents},\"input.list\",\"${outdir}\",\"${out0}\",\"${out1}\",\"${out2}\"\);


ls -lah

   # Stage each output file to output directory
   for filename in *.root; do
     echo Stageout $filename
     ./stageout.sh ${filename} ${outdir}
   done



#______________________________________________________________________________________ finished __
echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents 0 --inc 
     ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents 0 --inc 
#_________________________________________________________________________________________________



echo "bdee bdee bdee, That's All Folks!"
}  >${logbase}.out 2>${logbase}.err

exit ${status_f4a}




