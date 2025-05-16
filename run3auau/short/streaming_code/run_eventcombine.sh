#!/usr/bin/env bash

## Logging details
echo Hostname: `hostname`
echo This script: $0
echo Arguments: $@
echo Working directrory: $_CONDOR_SCRATCH_DIR
echo

EXPECTED_ARG_COUNT=17
if [ "$#" -ne "$EXPECTED_ARG_COUNT" ]; then
    echo "Error: Incorrect number of arguments."
    echo "Expected $EXPECTED_ARG_COUNT, but received $#."
    echo "Arguments received: $@"
    echo "Usage: $0 <nevents> <outbase> <logbase> <run> <seg> <outdir> <finaldir> <buildarg> <tag> <inputs> <ranges_str> <neventsper> <log_dir> <comment_str> <hist_dir> <condor_rsync_val>"
    exit 1
fi

# Parse arguments using shift
nevents="$1"; shift
outbase="$1"; shift
logbase="$1"; shift
run_number="$1"; shift         # Corresponds to {run}
segment="$1"; shift            # Corresponds to {seg}
daqhost="$1"; shift            # Corresponds to {daqhost}
output_directory="$1"; shift   # Corresponds to {outdir}
final_directory="$1"; shift    # Corresponds to {finaldir}
build_argument="$1"; shift     # Corresponds to {buildarg}
tag_value="$1"; shift          # Corresponds to {tag}
input_files="$1"; shift        # Corresponds to {inputs}
ranges_string="$1"; shift      # Corresponds to $(ranges)
nevents_per_job="$1"; shift    # Corresponds to {neventsper}
log_directory="$1"; shift      # Corresponds to {logdir}
job_comment="$1"; shift        # Corresponds to {comment}
histogram_directory="$1"; shift # Corresponds to {histdir}
condor_rsync=`echo $1|sed 's/,/ /g'`; shift       # Corresponds to {rsync}, change from comma separation

# Variables for the script
echo "Processing job with the following parameters:"
echo "---------------------------------------------"
echo "Number of events to process (nevents): $nevents"
echo "Output base name (outbase):            $outbase"
echo "Log base name (logbase):               $logbase"
echo "Run number (run):                      $run_number"
echo "Segment number (seg):                  $segment           (not used)"
echo "DAQ host (daqhost):                    $daqhost"
echo "Output directory (outdir):             $output_directory"
echo "Final destination (finaldir):          $final_directory   (not used)"
echo "Build argument (buildarg):             $build_argument"
echo "Tag (tag):                             $tag_value"
echo "Ranges string (ranges):                $ranges_string"
echo "Events per sub-job (neventsper):       $nevents_per_job"
echo "Log directory (logdir):                $log_directory"
echo "Job comment (comment):                 $job_comment"
echo "Histogram directory (histdir):         $histogram_directory"
echo "Condor Rsync Paths (rsync):            $condor_rsync" 
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

# OS=$( hostnamectl | awk '/Operating System/{ print $3" "$4 }' ) # doesn't work on some worker nodes

OS=$( grep ^PRETTY_NAME /etc/os-release | sed 's/"//g'| cut -f2- -d'=' ) # Works better, though still mostly for RHEL
if [[ $OS == "" ]]; then
    echo "Unable to determine OS version."
else
    # Set up environment
    if [[ "$_CONDOR_JOB_IWD" =~ "/Users/eickolja" ]]; then
        echo "Setting up Development software for ${OS} on MacOS"
        source /Users/eickolja/sphenix/sphenixprod/mac_this_sphenixprod.sh
    elif [[ $OS =~ "AlmaLinux" ]]; then
        echo "Setting up Production software for ${OS}"
        source /opt/sphenix/core/bin/sphenix_setup.sh -n $build_argument
    fi
fi
printenv

# TODO: Need cupsid - assigned at job registration in the prod db for efficient updates
# echo cupsid:     ${cupsid}

echo "Collecting input files for ${run} from ${daqhost}"
# make input file list
# perl CreateListFiles.pl $runnumber $daqhost
./create_filelist.py $run_number $daqhost

ls -l *list

exit 0
