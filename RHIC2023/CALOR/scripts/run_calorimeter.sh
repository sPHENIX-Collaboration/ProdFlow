#!/usr/bin/bash -f

# Usage
#
# run_calorimeter.sh <run number> <input directory> <out/link directory> <nevents> <debugopt>
#
# where 
#
# <run number> is the run number to prcess (in quotes)
# <input directory> is the path to the input files
# <out/link directory> is the path to the top-level output directory
# <nevents> number of events to process
# <debugopt> "--debug taskname" enables realtime logging for taskname
#


nevents=0
dir=/sphenix/lustre01/sphnxpro/commissioning/emcal/beam
dirhcal=/sphenix/lustre01/sphnxpro/commissioning/HCal/beam
dirzdc=/sphenix/lustre01/sphnxpro/commissioning/ZDC/beam
dirmbd=/sphenix/lustre01/sphnxpro/commissioning/mbd/beam
topDir=/sphenix/u/sphnxpro/shrek/

submitopt=" --no-submit --group sphenix --no-uuid"   # --no-timestamp for final/official productions
debugopt=" --debug ALL "
scope=user.lebedev

workflows=ProdFlow/RHIC2023/CALOR/yaml

if [[ $1 ]]; then
   run=$( printf "%08d" $1 )
fi
if [[ $2 ]]; then
   dir=$2
fi
if [[ $3 ]]; then
   topDir=$3
fi
if [[ $4 ]]; then
   nevents=$3
fi
if [[ $5 ]]; then
   debugopt=$5
fi

tag=sP23x-CALOR-${run}

echo "RUNNUMBER: " $run
echo "TAG:       " $tag


# Clean out / create temp directory for filelists
if [ -e /tmp/${USER}/$run ]; then
   rm -r /tmp/${USER}/$run
fi
mkdir /tmp/${USER}/$run -p

find ${dir} -type f -name *seb00*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb00.list
find ${dir} -type f -name *seb01*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb01.list
find ${dir} -type f -name *seb02*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb02.list
find ${dir} -type f -name *seb03*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb03.list
find ${dir} -type f -name *seb04*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb04.list
find ${dir} -type f -name *seb05*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb05.list
find ${dir} -type f -name *seb06*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb06.list
find ${dir} -type f -name *seb07*${run}-????.prdf -print | sort > /tmp/${USER}/$run/seb07.list

find ${dirhcal} -type f -name *West*${run}-????.prdf -print | sort > /tmp/${USER}/$run/hcalwest.list
find ${dirhcal} -type f -name *East*${run}-????.prdf -print | sort > /tmp/${USER}/$run/hcaleast.list

find ${dirzdc} -type f -name *seb14*${run}-????.prdf -print | sort > /tmp/${USER}/$run/zdc.list

find ${dirmbd} -type f -name *seb18*${run}-????.prdf -print | sort > /tmp/${USER}/$run/mbd.list

ls /tmp/${USER}/$run/seb00.list  > run-${run}.filelist
ls /tmp/${USER}/$run/seb01.list >> run-${run}.filelist
ls /tmp/${USER}/$run/seb02.list >> run-${run}.filelist
ls /tmp/${USER}/$run/seb03.list >> run-${run}.filelist
ls /tmp/${USER}/$run/seb04.list >> run-${run}.filelist
ls /tmp/${USER}/$run/seb05.list >> run-${run}.filelist
ls /tmp/${USER}/$run/seb06.list >> run-${run}.filelist
ls /tmp/${USER}/$run/seb07.list >> run-${run}.filelist
ls /tmp/${USER}/$run/hcaleast.list >> run-${run}.filelist
ls /tmp/${USER}/$run/hcalwest.list >> run-${run}.filelist
ls /tmp/${USER}/$run/zdc.list >> run-${run}.filelist
ls /tmp/${USER}/$run/mbd.list >> run-${run}.filelist

shrek ${submitopt} ${debugopt} --topDir=${topDir} --nevents=${nevents} --no-pause --tag ${tag} ${workflows}/*.yaml --runNumber=${run} --filelist=run-${run}.filelist 


