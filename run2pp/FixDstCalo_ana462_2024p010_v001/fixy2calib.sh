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
logdir=${12:-.}
histdir=${13:-.}
subdir=${14}
payload=(`echo ${15} | tr ","  " "`) # array of files to be rsynced
#-----
export cupsid=${@: -1}

sighandler()
{
echo "signal handler"
mv ${logbase}.out ${logdir#file:/}
mv ${logbase}.err ${logdir#file:/}
echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents 0 --inc 
     ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e 255 --nevents 0 
}

# On evict (term,stp) or hold (kill) branch to signal handler
trap sighandler SIGTERM SIGINT SIGKILL  

{

export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}
hostname

source /opt/sphenix/core/bin/sphenix_setup.sh -n ${7}
echo OFFLINE_MAIN: $OFFLINE_MAIN
#export ODBCINI=./odbc.ini

# Stagein
for i in ${payload[@]}; do
    cp --verbose ${subdir}/${i} .
done

if [ -e odbc.ini ]; then
echo export ODBCINI=./odbc.ini
     export ODBCINI=./odbc.ini
else
     echo No odbc.ini file detected.  Using system odbc.ini
fi

if [[ "${inputs}" == *"dbinput"* ]]; then
    echo "Getting inputs via cups.  ranges is not set."
    inputs=( $(./cups.py -r ${runnumber} -s ${segment} -d ${outbase} getinputs) )
fi

# Debugging info
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} info

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
echo logdir:  $logdir
echo histdir: $histdir
echo .............................................................................................. 

#______________________________________________________________________________________ running __
#
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running
#_________________________________________________________________________________________________

nevents=-1
status_f4a=0

echo "The DST_CALO_run2pp_ana462_2024p010_v001 production was created with the wrong output filename."
echo "Renaming each file for run ${runnumber}.  Catalog to be updated one all files are moved."

for infile_ in ${inputs[@]}; do

    base=$( basename ${infile_} )

    export dst0=${infile_}
    export dstB=${base/DST_CALO_run2pp_ana446_2024p007/${outbase}}
    export dstF=${outdir}/${dstB}
    
    export hist0=${histdir}/${base/DST_CALO/HIST_CALOQA}
    export histF=${histdir}/${dstB/DST_CALO/HIST_CALOQA}

#   echo mv --verbose ${dst0}  ${dstF}
    mv --verbose ${dst0}  ${dstF}
#   echo mv --verbose ${hist0} ${histF}
    mv --verbose ${hist0} ${histF}

#   random sleep for up to 30s between copies
    sleep $(( RANDOM % 30 ))

done

ls -lah

#______________________________________________________________________________________ finished __
echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents -1 
     ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents -1 
#_________________________________________________________________________________________________



echo "bdee bdee bdee, That's All Folks!"
} >  ${logdir#file:/}/${logbase}.out 2> ${logdir#file:/}/${logbase}.err

if [ -e cups.stat ]; then
    cp cups.stat ${logdir#file:/}/${logbase}.dbstat
fi

exit $status_f4a
