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
    echo "Expected $MIN_ARG_COUNT--$MAX_ARG_COUNT, but received $#."
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
export PRODDB_DBID=$dbid

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
    else
	echo "Unsupported OS $OS"
	return 1
    fi
fi
printenv

echo "---------------------------------------------"
echo "Running eventcombine for run ${run_number} on ${daqhost}"
echo "---------------------------------------------"
echo "--- Collecting input files"
./create_filelist.py $runnumber $daqhost
for f in *list; do
    ls -l $f
    cat $f
done

echo "--- Executing macro"
echo root.exe -q -b Fun4All_Prdf_Combiner.C\(${nevents},\"${daqhost}\",\"${outbase}\",\"${outdir}\"\)
root.exe -q -b Fun4All_Prdf_Combiner.C\(${nevents},\"${daqhost}\",\"${outbase}\",\"${outdir}\"\)

shopt -s nullglob
for hfile in HIST_*.root; do
    echo ./stageout ${hfile} to ${histdir}
    ./stageout.sh ${hfile} ${histdir}
done
shopt -u nullglob

# Signal that the job is done
destname=${output_directory}/${logbase}.finished
# change the destination filename the same way root files are treated for easy parsing
destname="${destname}:nevents:0"
destname="${destname}:first:-1"
destname="${destname}:last:-1"
destname="${destname}:md5:none"
destname="${destname}:dbid:${dbid}"
echo touch $destname
touch $destname

# There should be no output files hanging around  (TODO add number of root files to exit code)
ls -la 

echo "script done"
echo "---------------------------------------------"

exit 0
