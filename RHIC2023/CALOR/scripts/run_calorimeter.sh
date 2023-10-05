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

BUILD=ana.378
sphenix_setup.sh ${BUILD}

# Re-parse from offline main
BUILD=`basename ${OFFLINE_MAIN}`


nevents=0
dir=/sphenix/lustre01/sphnxpro/commissioning/emcal/beam
dirhcal=/sphenix/lustre01/sphnxpro/commissioning/HCal/beam
dirzdc=/sphenix/lustre01/sphnxpro/commissioning/ZDC/beam
dirmbd=/sphenix/lustre01/sphnxpro/commissioning/mbd/beam
topDir=/sphenix/u/sphnxpro/shrek/

submitopt=" --submit --group sphenix --no-uuid"   # --no-timestamp for final/official productions
debugopt=" --debug all "
scope=group.sphenix

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

tag=rn${run}-CALOR-${BUILD}
ts=`date +%Y%h%d-%H%M%S`

echo "RUNNUMBER: " $run
echo "TAG:       " $tag
echo "TIMESTAMP: " $ts
DATASET=${tag}-${ts}

echo "DATASET:   " ${DATASET}
echo "SCOPE:     " ${scope}

# Clean out / create temp directory for filelists
if [ -e /tmp/${USER}/$run ]; then
   rm -r /tmp/${USER}/$run
fi
mkdir /tmp/${USER}/$run -p

#
# Build file lists
#

find ${dir} -type f -name *seb00*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb00
find ${dir} -type f -name *seb01*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb01
find ${dir} -type f -name *seb02*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb02
find ${dir} -type f -name *seb03*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb03
find ${dir} -type f -name *seb04*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb04
find ${dir} -type f -name *seb05*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb05
find ${dir} -type f -name *seb06*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb06
find ${dir} -type f -name *seb07*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.seb07
find ${dirhcal} -type f -name *West*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.hcalwest
find ${dirhcal} -type f -name *East*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.hcaleast
find ${dirzdc} -type f -name *seb14*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.zdc
find ${dirmbd} -type f -name *seb18*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${tag}-${ts}.mbd

#
# Create a directory under lustre / rse BNL_PROD3 for the definition of the workflow inputs
# and populate it with the files which we just discovered
#

TARGETDIR=/sphenix/lustre01/sphnxpro/zfs/rucio/shrek/workflows/${DATASET}
ssh sphnxpro@`hostname -s` mkdir -p ${TARGETDIR}
scp /tmp/${USER}/$run/* sphnxpro@`hostname -s`:${TARGETDIR}/

#
# Build a rucio dataset consisting of these files
#
cat <<EOF | python
from rucio.client import Client
import hashlib
import pprint
import os
import uuid
client = Client()
dataset="${DATASET}"
targetdir="${TARGETDIR}"
client.add_dataset( "group.sphenix", dataset )
client.set_metadata( "group.sphenix", dataset, key='run_number', value="$run")
for f in [ "seb00", "seb01", "seb02", "seb03", "seb04", "seb05", "seb06", "seb07", "hcaleast", "hcalwest", "zdc", "mbd" ]:
    filename = dataset + "." + f 
    filepath = targetdir + "/" + filename 
    pfn="file://localhost" + filepath 
    md5 = hashlib.md5( open(filepath,'rb').read() ).hexdigest()
    sz  = os.path.getsize( filepath )
    replica_ = {
        'scope'  : "group.sphenix", 
        'name'   : filename,
        'pfn'    : pfn,
        'bytes'  : sz,
        'md5'    : md5,
    }
    client.add_files_to_dataset( "group.sphenix", dataset, [replica_], "BNL_PROD3" )
    client.set_metadata( "group.sphenix", filename, 'guid', str(uuid.uuid4()) )
EOF

shrek ${submitopt} ${debugopt} --build=${BUILD} --topDir=${topDir} --nevents=${nevents} --no-pause --tag ${tag} ${workflows}/*.yaml --runNumber=${run} --filelist=run-${run}.filelist --ebinputs=${scope}:${DATASET} \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb00  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb01  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb02  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb03  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb04  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb05  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb06  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.seb07  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.hcaleast  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.hcalwest  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.zdc  \
    --pack  /tmp/${USER}/$run/${tag}-${ts}.mbd 



