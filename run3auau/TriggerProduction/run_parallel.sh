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
comment=${13}
histdir=${14:-.}
subdir=${15}
payload=(`echo ${16} | tr ","  " "`) # array of files to be rsynced
#-----
export cupsid=${@: -1}
echo cupsid = $cupsid

#sighandler()
#{
#mv ${logbase}.out ${logdir#file:/}
#mv ${logbase}.err ${logdir#file:/}
#}
#trap sighandler SIGTERM 
#trap sighandler SIGSTOP 
#trap sighandler SIGINT 
#trap sighandler SIGKILL


{

export USER="$(id -u -n)"
export LOGNAME=${USER}
export HOME=/sphenix/u/${USER}

source /opt/sphenix/core/bin/sphenix_setup.sh -n ${7}

#OS=$( hostnamectl | awk '/Operating System/{ print $3" "$4 }' )
#if [[ $OS =~ "Alma" ]]; then
#    echo "Can live with stock pyton on alma9"
#else
#    echo "Need older python on SL7"
#   source /cvmfs/sphenix.sdcc.bnl.gov/gcc-12.1.0/opt/sphenix/core/stow/opt_sphenix_scripts/bin/setup_python-3.6.sh
#fi

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

echo "Got the input files"
cat inputfiles.list


# Sort input files by seb
for i in $( cat inputfiles.list ); do

# Matches SEB files
if [[ $i =~ seb(00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20) ]]; then
       nn=${BASH_REMATCH[1]}
       echo ${i} >> seb${nn}.list
       echo Add ${i}  to seb${nn}.list
fi

# Matches GL1 files
if [[ $i =~ "GL1" ]]; then
    echo ${i} >> gl1daq.list
    echo Add ${i}  to gl1daq.list
fi
    
done


# Set state to running
./cups.py -r ${runnumber} -s ${segment} -d ${outbase} running

echo "Running on the following input filelists"
ls -l seb*.list gl1daq.list

# Run fun4all
echo root.exe -q -b Fun4All_New_Prdf_Combiner.C\(${nevents},\"${outbase}.root\",\"${outdir}\"\)
     root.exe -q -b Fun4All_New_Prdf_Combiner.C\(${nevents},\"${outbase}.root\",\"${outdir}\"\); status_f4a=$?

# Flag run as finished.  Increment nevents by zero
echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents 0 --inc 
     ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents 0 --inc 

if [ "${status_f4a}" -eq 0 ]; then

   echo   stageout.sh ${logbase}.root ${outdir}
          stageout.sh ${logbase}.root ${outdir}

else

   echo Fun4All exited with status ${status_f4a}
   echo ... list cwd ...
   ls -la

fi

echo "script done"
} >& ${logdir#file:/}/${logbase}.out

if [ -e cups.stat ]; then
    cp cups.stat ${logdir#file:/}/${logbase}.dbstat
fi

exit ${status_f4a}


