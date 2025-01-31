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



#______________________________________________________________________________________ started __
#
# $$$ ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} started
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
echo logdir:  $logdir
echo histdir: $histdir
echo .............................................................................................. 

#______________________________________________________________________________________ running __
#
#./cups.py -r ${runnumber} -s ${segment} -d ${outbase} inputs --files ${inputs[@]}
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running
#_________________________________________________________________________________________________


dstname=${logbase%%-*}

out0=${logbase}.root
out1=HIST_${logbase#DST_}.root

nevents=-1
status_f4a=0

for infile_ in ${inputs[@]}; do
    infile=$( basename ${infile_} )
    cp -v ${infile_} .
    outfile1=${infile/CALOFITTING/JETCALO}
    outfile2=${infile/CALOFITTING/JET}
    outhist=${infile/DST_CALOFITTING/HIST_CALOQASKIMMED}
    root.exe -q -b Fun4All_JetSkimmedProductionYear2.C\(${nevents},\"${infile}\",\"${outfile1}\",\"${outfile2}\",\"${outhist}\",\"${dbtag}\"\);  status_f4a=$?

    # Stageout the (single) DST created in the macro run
    #for rfile in ${outfile}; do 
    #    #nevents_=$( root.exe -q -b GetEntries.C\(\"${filename}\"\) | awk '/Number of Entries/{ print $4; }' )
        nevents=${nevents_:--1}
	echo Stageout ${outfile1} to ${outdir}
        ./stageout.sh ${outfile1} ${outdir}

        echo Stageout ${outfile2} to ${outdir}
        ./stageout.sh ${outfile2} ${outdir}

    #done
    for hfile in `ls HIST_*.root`; do
	echo Stageout ${hfile} to ${histdir}
        ./stageout.sh ${hfile} ${histdir}
    done
done

ls -lah

#______________________________________________________________________________________ finished __
echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents ${nevents} --inc 
     ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents ${nevents} --inc 
#_________________________________________________________________________________________________



echo "bdee bdee bdee, That's All Folks!"
} >  ${logdir#file:/}/${logbase}.out 2> ${logdir#file:/}/${logbase}.err

if [ -e cups.stat ]; then
    cp cups.stat ${logdir#file:/}/${logbase}.dbstat
fi

exit $status_f4a
