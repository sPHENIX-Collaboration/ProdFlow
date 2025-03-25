#!/usr/bin/bash

#     arguments             : "$(nevents) {outbase} {logbase} $(run) $(seg) $(outdir) $(buildarg) $(tag) $(inputs) $(ranges) {neventsper} {logdir} {comment} {histdir} {PWD} {rsync}"
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
neventsper=${11}
logdir=${12:-.}
comment=${13}
histdir=${14:-.}
subdir=${15}
payload=(`echo ${16} | tr ","  " "`) # array of files to be rsynced

export cupsid=${@: -1}
echo CUPSID=${cupsid}

## Verify that we can write to the log file.  If not, early exit and flag the error.  Otherwise, message that we were able to succeed.
#echo ${0} started `date`> ${logdir#file:/}/${logbase}.out
#if [ $? -ne 0 ]; then
#    ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message "Unable to write test file to gpfs." --error 'gpfs-failure'
#    exit 10
#else
#    ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} message f"Initialized logfile {logdir}/{logbase}.out"    
#fi


# ---
{
    

export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}
hostname

source /opt/sphenix/core/bin/sphenix_setup.sh -n ${7}

OS=$( hostnamectl | awk '/Operating System/{ print $3" "$4 }' )
#if [[ $OS =~ "Alma" ]]; then
#    echo "Can live with stock pyton on alma9"
#else
#    echo "Need older python on SL7"
#   source /cvmfs/sphenix.sdcc.bnl.gov/gcc-12.1.0/opt/sphenix/core/stow/opt_sphenix_scripts/bin/setup_python-3.6.sh
#fi


echo OFFLINE_MAIN: $OFFLINE_MAIN

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
echo subdir:  ${subdir}
echo payload: ${payload[@]}

echo .............................................................................................. 

for i in ${payload[@]}; do
    echo "Stage in $i:"
    cp --verbose ${subdir}/${i} .
done

# user has supplied an odbc.ini file.  use it.
if [ -e odbc.ini ]; then
echo "Setting user provided odbc.ini file"
export ODBCINI=./odbc.ini
fi


ls *.json
if [ -e sPHENIX_newcdb_test.json ]; then
    echo "... setting user provided conditions database config"
    export NOPAYLOADCLIENT_CONF=./sPHENIX_newcdb_test.json
fi

echo NOPAYLOADCLIENT_CONF=${NOPAYLOADCLIENT_CONF}

#______________________________________________________________________________________ started __
#
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} started
#_________________________________________________________________________________________________


if [[ "${9}" == *"dbinput"* ]]; then
    echo GRABBING DBINPUT $runnumber $segment $outbase
    echo ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} getinputs
    ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} getinputs
    
    for i in $(./cups.py -r ${runnumber} -s ${segment} -d ${outbase} getinputs); do
       cp -v ${i} .
       echo $( basename $i ) >> inlist   
    done
else
    echo WFT???
  for i in ${inputs[@]}; do
     cp -v ${i} .
     echo $( basename $i ) >> inlist   
  done
fi

echo "Here is the input list"
cat inlist

./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running

dstname=${logbase%%-*}
echo "in dir"
pwd
echo root.exe -q -b Fun4All_SingleJob0.C\(${nevents},${runnumber},\"${logbase}.root\",\"${dbtag}\",\"inlist\"\)
     root.exe -q -b Fun4All_SingleJob0.C\(${nevents},${runnumber},\"${logbase}.root\",\"${dbtag}\",\"inlist\"\);  status_f4a=$?

ls -la

echo ./stageout.sh ${logbase}.root ${outdir}
     ./stageout.sh ${logbase}.root ${outdir}

for hfile in `ls HIST_*.root`; do
    echo Stageout ${hfile} to ${histdir}
    ./stageout.sh ${hfile} ${histdir}
done

ls -la

# Flag run as finished. 
echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents ${nevents}  
     ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents ${nevents}

echo "bdee bdee bdee, That's All Folks!"

} >> ${logdir#file:/}/${logbase}.out  2>${logdir#file:/}/${logbase}.err


exit ${status_f4a:-1}
