#!/usr/bin/bash
export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}

this_script=$BASH_SOURCE
this_script=`readlink -f $this_script`
this_dir=`dirname $this_script`
echo rsyncing from $this_dir

source /opt/sphenix/core/bin/sphenix_setup.sh -n new

hostname

echo running: run_waveformfitting.sh $*

if [[ ! -z "$_CONDOR_SCRATCH_DIR" && -d $_CONDOR_SCRATCH_DIR ]]
then
    cd $_CONDOR_SCRATCH_DIR
    rsync -av $this_dir/* .
else
    echo condor scratch NOT set
    exit 1
fi

# arguments 
# $1: number of events
# $2: dst outfile
# $3: dst outdir
# $4: qa outfile
# $5: qa outdir


echo 'here comes your environment'

printenv

echo arg1 \(events\) : $1
echo arg2 \(run number\) : $2
echo arg3 \(segment\) : $3
echo arg4 \(dst outfile\): $4
echo arg5 \(dst outdir\): $5
echo arg6 \(qa outfile\): $6
echo arg7 \(qa outdir\): $7

runnumber=$(printf "%010d" $2)

perl CreateListFiles.pl $2 $3
getinputfiles.pl --dd  --filelist files.list
if [ $? -ne 0 ]
then
    cat inputfiles.list
    echo error from getinputfiles.pl  --dd --filelist inputfiles.list, exiting
    exit -1
fi
ls -l
echo running root.exe -q -b Fun4All_Year2_Fitting.C\($1,\"files.list\",\"$4\",\"$6\"\)
root.exe -q -b Fun4All_Year2_Fitting.C\($1,\"files.list\",\"$4\",\"$6\"\)
ls -l
if [ -f $4 ]
then
    copyscript.pl $4 -mv -dd -outdir $5
else
    echo could not find $4
fi
if [ -f $6 ]
then
    copyscript.pl $6 -mv -dd -outdir $7
else
    echo could not find $6
fi

echo "script done"
