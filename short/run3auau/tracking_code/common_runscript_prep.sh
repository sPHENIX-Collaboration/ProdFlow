#!/usr/bin/env bash

## Logging details
echo Hostname: `hostname`
echo Working directory: $_CONDOR_SCRATCH_DIR
echo "Calling script is $0"
echo "This script is ${BASH_SOURCE[0]}"


ARG_COUNT=16
if [ "$#" -lt $ARG_COUNT ]  ; then
    echo "Error: Incorrect number of arguments."
    echo "Expected $ARG_COUNT [+1], but received $#."
    echo "Usage: $0 <nevents> <outbase> <logbase> <dsttype> <run> <seg> <daqhost> <outdir> <buildarg> <dbtag> <input> <dataset> <neventsper> <logdir> <histdir> <condor_rsync> [dbid]"
    exit 1
fi

# Parse arguments using shift
nevents="$1"; shift
outbase="$1"; shift
logbase="$1"; shift
dsttype="$1"; shift
run="$1"; shift
seg="$1"; shift
daqhost="$1"; shift
outdir="$1"; shift
buildarg="$1"; shift
dbtag="$1"; shift
input="$1"; shift
dataset="$1"; shift
neventsper="$1"; shift
logdir="$1"; shift
histdir="$1"; shift
condor_rsync="$1"; shift       # Corresponds to {rsync}
dbid=${1:--1};shift            # for prod db, -1 means no dbid (should produce an error soon)

condor_rsync=`echo $condor_rsync|sed 's/,/ /g'` # Change from comma separation
export PRODDB_DBID=$dbid

# Variables for all run scripts
echo "Processing job with the following parameters:"
echo "---------------------------------------------"
echo "Number of events to process (nevents): $nevents"
echo "Output base name (outbase):            $outbase"
echo "Log base name (logbase):               $logbase"
echo "Job type ~ output name stub (dsttype): $dsttype"
echo "Run number (run):                      $run"
echo "Segment number (seg):                  $seg"
echo "DAQ host, leaf (daqhost)               $daqhost"
echo "Output directory (outdir):             $outdir"
echo "Build argument (buildarg):             $buildarg"
echo "Tag (\"triplet\") (dbtag):               $dbtag"
echo "Input mode (input):                    $input (all segments or seg0 only, or list in some cases)"
echo "Dataset:                               $dataset"
echo "Events per sub-job (neventsper):       $neventsper"
echo "Log directory (logdir):                $logdir"
echo "Histogram directory (histdir):         $histdir"
echo "Job database id (dbid):                $dbid"
echo "---------------------------------------------"
echo "Files/directories to stage in (condor_rsync):"
echo "$condor_rsync" 
echo "---------------------------------------------"

## Make sure logfiles are kept even when receiving a signal
## KK: FIXME: Untested and not used enough
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
    cp --verbose -r  $f . 
done
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
	exit 1
    fi
fi

if [ -e odbc.ini ]; then
echo export ODBCINI=./odbc.ini
     export ODBCINI=./odbc.ini
else
     echo No odbc.ini file detected.  Using system odbc.ini
fi

shopt -s nullglob
jsonfound="$(echo *.json)"
shopt -u nullglob
if [[ -n $jsonfound ]]; then
    echo "Found json file(s):"
    ls -la *.json
else
    echo "No .json files found."
fi
if [ -e sPHENIX_newcdb_test.json ]; then
    echo "... setting user provided conditions database config"
    export NOPAYLOADCLIENT_CONF=./sPHENIX_newcdb_test.json
fi
echo NOPAYLOADCLIENT_CONF=${NOPAYLOADCLIENT_CONF}

echo "---------------------------------------------"
echo "Offline main "${OFFLINE_MAIN}
echo pwd is `pwd`
echo ls -lha
ls -lha
# printenv
echo "---------------------------------------------"
return 0  2>/dev/null

echo "Execution of $0 complete "
echo "---------------------------------------------"
exit 


# (return 0 2>/dev/null) && ( echo "Leaving sourced script." ) || (echo Exiting) && exit 0
