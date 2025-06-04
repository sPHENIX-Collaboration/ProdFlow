#!/usr/bin/bash

nevents=${1}
outbase=${2}
logbase=${3}
runnumber=${4}
segment=${5}
outdir=${6}
echo "build first "${7}
build=${7/./}
echo "build after "${7}
dbtag=${8}
inputs=(`echo ${9} | tr "," " "`)  # array of input files 
ranges=(`echo ${10} | tr "," " "`)  # array of input files with ranges appended
neventsper=${11:-1000}
logdir=${12:-.}
nendpoint=${13}
histdir=${14:-.}
subdir=${15}
payload=(`echo ${16} | tr ","  " "`) # array of files to be rsynced
#-----
export cupsid=${@: -1}
echo cupsid = $cupsid

{

export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}

source /opt/sphenix/core/bin/sphenix_setup.sh -n ${7}

echo "Offline main "${OFFLINE_MAIN}


echo "PAYLOAD"
for i in ${payload[@]}; do
    cp --verbose ${subdir}/${i} .
done

if [ -e odbc.ini ]; then
echo export ODBCINI=./odbc.ini
     export ODBCINI=./odbc.ini
else
     echo No odbc.ini file detected.  Using system odbc.ini
fi

echo "CUPS configuration"
echo ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} info
     ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} info


./cups.py -r ${runnumber} -s ${segment} -d ${outbase} started

echo "INPUTS" 
if [[ "${9}" == *"dbinput"* ]]; then
   ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} getinputs >> inputfiles.list
else
   for i in ${inputs[@]}; do
      echo $i >> inputfiles.list
   done
fi

echo Postprocessing on logfile
tgtfile=$(cat inputfiles.list)

logdst=${logdir#file:/}
tgtdir=${logdst/POST/DST}
echo In directory ${tgtdir}

counter=0
suffix=".gz"
while [ -e ${tgtdir}/${tgtfile}.${suffix} ]; do
    counter=$((counter + 1))
    suffix=".gz.${counter}"
done
gzip -v --best ${tgtdir}/${tgtfile} --suffix ${suffix} >& message.txt

./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e $? --nevents 0 --inc 
./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} message "$(cat message.txt)" --flag 0

} >& ${logdir#file:/}/${logbase}.out 
