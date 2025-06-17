#!/usr/bin/env bash

## Logging details
echo Hostname: `hostname`
echo This script: $0
#echo Arguments: $@
echo Working directory: $_CONDOR_SCRATCH_DIR
echo

MIN_ARG_COUNT=17
MAX_ARG_COUNT=18
if [ "$#" -lt "$MIN_ARG_COUNT" ] || [ "$#" -gt "$MAX_ARG_COUNT" ] ; then
    echo "Error: Incorrect number of arguments."
    echo "Expected $EXPECTED_ARG_COUNT, but received $#."
    echo "Arguments received: $@"
    echo "Usage: $0 <nevents> <outbase> <logbase> <run> <seg> <daqhost> <outdir> <finaldir> <buildarg> <tag> <inputs> <ranges_str> <neventsper> <log_dir> <comment_str> <hist_dir> <condor_rsync_val>"
    exit 1
fi

# Parse arguments using shift
nevents="$1"; shift
outbase="$1"; shift
logbase="$1"; shift
runnumber="$1"; shift
segment="$1"; shift            # Corresponds to {seg}
daqhost="$1"; shift            # Corresponds to {daqhost}
outdir="$1"; shift
finaldir="$1"; shift
build_argument="$1"; shift     # Corresponds to {buildarg}
dbtag="$1"; shift
input_files="$1"; shift        # Corresponds to {inputs}
ranges_string="$1"; shift      # Corresponds to $(ranges)
neventsper="$1"; shift
logdir="$1"; shift
comment="$1"; shift
histdir="$1"; shift # Corresponds to {histdir}

condor_rsync="$1"; shift       # Corresponds to {rsync}
condor_rsync=`echo $condor_rsync|sed 's/,/ /g'` # Change from comma separation

dbid=${1:--1};shift            # dbid for faster db lookup, -1 means no dbid

# Variables for the script
echo "Processing job with the following parameters:"
echo "---------------------------------------------"
echo "Number of events to process (nevents): $nevents"
echo "Output base name (outbase):            $outbase"
echo "Log base name (logbase):               $logbase"
echo "Run number (run):                      $runnumber"
echo "Segment number (seg):                  $segment           (not used)"
echo "DAQ host (daqhost):                    $daqhost"
echo "Output directory (outdir):             $outdir"
echo "Final destination (finaldir):          $finaldir   (not used)"
echo "Build argument (buildarg):             $build_argument"
echo "Tag (tag):                             $dbtag"
echo "Ranges string (ranges):                $ranges_string"
echo "Events per sub-job (neventsper):       $neventsper"
echo "Log directory (logdir):                $logdir"
echo "Job comment (comment):                 $comment"
echo "Histogram directory (histdir):         $histdir"
echo "Condor Rsync Paths (rsync):            $condor_rsync" 
echo "Job database id (dbid):                $dbid"
echo "---------------------------------------------"
echo "Input file(s) (inputs):                $input_files"
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
# Note: Original jobwrapper.sh has more intricate trapping that
# catches more signals and updates the prod db.

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
        source /opt/sphenix/core/bin/sphenix_setup.sh -n $build_argument
    fi
fi
printenv

echo "Offline main "${OFFLINE_MAIN}

if [ -e odbc.ini ]; then
echo export ODBCINI=./odbc.ini
     export ODBCINI=./odbc.ini
else
     echo No odbc.ini file detected.  Using system odbc.ini
fi

# echo "CUPS configuration"
# echo ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} info
#      ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} info
# ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} started

# echo "INPUTS" 
# if [[ "${9}" == *"dbinput"* ]]; then
#    ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} getinputs >> inputfiles.list
# else
#    for i in ${inputs[@]}; do
#       echo $i >> inputfiles.list
#    done
# fi


echo "---------------------------------------------"
echo "Running streaming eventcombine for run ${run_number} on ${daqhost}"
echo "---------------------------------------------"
echo "--- Collecting input files"
./create_filelist.py $runnumber $daqhost

# Should be exactly one gl1 file and one ebdc, mvtx, or intt file
# trying to be flexible here, but we have to assume daqhost will always be lowercase and in this family
# Bit of shell magic here, inspired by
# https://unix.stackexchange.com/questions/472668/how-to-easily-count-the-number-of-matches-of-a-glob-involving-paths-with-spaces
shopt -s nullglob
set -- *gl1*.list
if [[ $# != 1 ]] ; then
    echo "Multiple or no GL1 files found:" >&2
    ls -l `echo $@`                        >$2
    echo Stop.                             >&2
    # ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e 111 --nevents 0 --inc 
    exit 111
fi
gl1file=$1

inttfile=""
mvtxfile=""
ebdcfile=""
tpotfile=""
set -- `find . -maxdepth 1 -name \*.list -a -not -name $gl1file`
if [[ $# != 1 ]] ; then
    echo "Multiple or not enough .list files found:"     >&2
    ls -l `echo $@`                        >$2
    echo Stop.                             >&2
    # ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e 111 --nevents 0 --inc 
    exit 111
fi
[[ $1 == *intt* ]] && inttfile=$1
[[ $1 == *mvtx* ]] && mvtxfile=$1
[[ $1 == *ebdc* ]] && ebdcfile=$1
[[ $1 == *ebdc39* ]] && ebdcfile="" && tpotfile=$1
shopt -u nullglob

# # Flag job as running in production status
# ./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running

echo "--- Executing macro"
echo root.exe -q -b Fun4All_SingleStream_Combiner.C\(${nevents},${runnumber},\"${outdir}\",\"${histdir}\",\"${outbase}\",${neventsper},\"${dbtag}\",\"${gl1file}\",\"${ebdcfile}\",\"${inttfile}\",\"${mvtxfile}\",\"${tpotfile}\"\);
root.exe -q -b Fun4All_SingleStream_Combiner.C\(${nevents},${runnumber},\"${outdir}\",\"${histdir}\",\"${outbase}\",${neventsper},\"${dbtag}\",\"${gl1file}\",\"${ebdcfile}\",\"${inttfile}\",\"${mvtxfile}\",\"${tpotfile}\"\);

shopt -s nullglob
for hfile in HIST_*.root; do
    echo ./stageout ${hfile} to ${histdir}
    ./stageout.sh ${hfile} ${histdir}
done
shopt -u nullglob

# There should be no output files hanging around  (TODO add number of root files to exit code)
ls -la 


# Signal that the job is done
touch ${outdir}/${logbase}.dbid:$dbid.finished

echo "script done"
echo "---------------------------------------------"

exit 0
