#!/usr/bin/env bash

## Logging details
echo Hostname: `hostname`
echo This script: $0
echo Working directory: $_CONDOR_SCRATCH_DIR
echo

MIN_ARG_COUNT=17
MAX_ARG_COUNT=18
if [ "$#" -lt "$MIN_ARG_COUNT" ] || [ "$#" -gt "$MAX_ARG_COUNT" ] ; then
    echo "Error: Incorrect number of arguments."
    echo "Expected $MIN_ARG_COUNT--$MAX_ARG_COUNT, but received $#."
    echo "Arguments received: $@"
    echo "Usage: $0 <nevents> <outbase> <logbase> <inbase> <run> <seg> <outdir> <finaldir> <buildarg> <tag> <inputs> <ranges_str> <neventsper> <log_dir> <comment_str> <hist_dir> <condor_rsync_val>"
    exit 1
fi


# Parse arguments using shift
nevents="$1"; shift
outbase="$1"; shift
logbase="$1"; shift
inbase="$1"; shift
runnumber="$1"; shift
segment="$1"; shift
outdir="$1"; shift
finaldir="$1"; shift
buildarg="$1"; shift
dbtag="$1"; shift
inputs="$1"; shift
ranges="$1"; shift
neventsper="$1"; shift
logdir="$1"; shift
comment="$1"; shift
histdir="$1"; shift

condor_rsync="$1"; shift       # Corresponds to {rsync}
condor_rsync=`echo $condor_rsync|sed 's/,/ /g'` # Change from comma separation

dbid=${1:--1};shift            # dbid for faster db lookup, -1 means no dbid
export PRODDB_DBID=$dbid


# Variables for the script
echo "Processing job with the following parameters:"
echo "---------------------------------------------"
echo "Number of events to process (nevents): $nevents"
echo "Output base name (outbase):            $outbase"
echo "Log base name (logbase):               $logbase"
echo "Input name maske (inbase):             $inbase"
echo "Run number (run):                      $runnumber"
echo "Segment number (seg):                  $segment"
echo "Output directory (outdir):             $outdir"
echo "Final destination (finaldir):          $finaldir   (not used)"
echo "Build argument (buildarg):             $buildarg"
echo "Tag (tag):                             $dbtag"
echo "Ranges string (ranges):                $ranges_string"
echo "Events per sub-job (neventsper):       $neventsper"
echo "Log directory (logdir):                $logdir"
echo "Job comment (comment):                 $comment"
echo "Histogram directory (histdir):         $histdir"
echo "Condor Rsync Paths (rsync):            $condor_rsync" 
echo "Job database id (dbid):                $dbid"
echo "---------------------------------------------"

## Make sure logfiles are kept even when receiving a signal
sighandler()
{
mv ${logbase}.out ${logdir#file:/}
mv ${logbase}.err ${logdir#file:/}
}
trap sighandler SIGTERM 
trap sighandler SIGSTOP 
trap sighandler SIGINT 
# SIGKILL can't be trapped

# stage in the payload files
cd $_CONDOR_SCRATCH_DIR
echo Copying payload data to `pwd`
for f in ${condor_rsync}; do
    cp --verbose -r $f . 
done
ls -ltra
echo "---------------------------------------------"



export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}

OS=$( grep ^PRETTY_NAME /etc/os-release | sed 's/"//g'| cut -f2- -d'=' ) # Works better, though still mostly for RHEL
if [[ $OS == "" ]]; then
    echo "Unable to determine OS version."
else
    # Set up environment
    if [[ "$_CONDOR_JOB_IWD" =~ "/Users/eickolja" ]]; then
        source /Users/eickolja/sphenix/sphenixprod/mac_this_sphenixprod.sh
    elif [[ $OS =~ "AlmaLinux" ]]; then
        echo "Setting up Production software for ${OS}"
        source /opt/sphenix/core/bin/sphenix_setup.sh -n $buildarg
    else
	echo "Unsupported OS $OS"
	return 1
    fi
fi
# printenv

echo "Offline main "${OFFLINE_MAIN}

if [ -e odbc.ini ]; then
echo export ODBCINI=./odbc.ini
     export ODBCINI=./odbc.ini
else
     echo No odbc.ini file detected.  Using system odbc.ini
fi


echo "---------------------------------------------"
echo "Running CALOFITTING for run ${run_number}, seg {segment}"
echo "---------------------------------------------"
echo "--- Collecting input files"
echo inbase=$inbase
echo runnumber=$runnumber
echo segment=$segment

echo 'create_filelist_run_seg.py $inbase $runnumber $segment'
./create_filelist_run_seg.py $inbase $runnumber $segment
ls -la *.list
echo end of ls -la '*.list'
for l in *list; do
    echo cat $l
    cat $l
done

exit



nevents=-1
status_f4a=0

for infile_ in ${inputs[@]}; do
    outfile=${logbase}.root
    outhist=${outfile/DST_CALOFITTING/HIST_CALOFITTINGQA}
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running
    
    root.exe -q -b Fun4All_Year2_Fitting.C\(${nevents},\"${infile}\",\"${outfile}\",\"${outhist}\",\"${dbtag}\"\);  status_f4a=$?

    nevents=${nevents_:--1}
    echo Stageout ${outfile} to ${outdir}
        ./stageout.sh ${outfile} ${outdir}
 
    for hfile in `ls HIST_*.root`; do
	echo Stageout ${hfile} to ${histdir}
        ./stageout.sh ${hfile} ${histdir}
    done

done
    

exit ${status_f4a}











dstname=${logbase%%-*}

out0=${logbase}.root
out1=HIST_${logbase#DST_}.root

nevents=-1
status_f4a=0

for infile_ in ${inputs[@]}; do

#   infile=$( basename ${infile_} )
#   cp -v ${infile_} .
    infile=$infile_
    
    outfile=${logbase}.root
    outhist=${outfile/DST_CALOFITTING/HIST_CALOFITTINGQA}
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running
    
    root.exe -q -b Fun4All_Year2_Fitting.C\(${nevents},\"${infile}\",\"${outfile}\",\"${outhist}\",\"${dbtag}\"\);  status_f4a=$?

    nevents=${nevents_:--1}
    echo Stageout ${outfile} to ${outdir}
        ./stageout.sh ${outfile} ${outdir}
 
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

} > ${logdir#file:/}/${logbase}.out 2> ${logdir#file:/}/${logbase}.err

if [ -e cups.stat ]; then
    cp cups.stat ${logdir#file:/}/${logbase}.dbstat
fi


exit ${status_f4a}
