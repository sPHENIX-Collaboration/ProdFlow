#!/usr/bin/bash -f

# Usage
#
# run_calorimeter.sh <run number> <nevents> <input directory> <out/link directory> <debugopt>
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
BUILD=ana.385
#DBTAG=TESTp001p23
DBTAG=2023p003
#DBTAG=TESTp001v32
source /opt/sphenix/core/bin/sphenix_setup.sh -n ${BUILD}
DBOPT=" --dbtag=${DBTAG} "
#DBOPT=""


# Re-parse from offline main (ensures that we get a valid build)
#CHECK_BUILD=`basename ${OFFLINE_MAIN}`

#if [[ ! BUILD == CHECK_BUILD ]]; then
#   echo "Requested build ]${BUILD}[ does not match setup build ]${CHECK_BUILD}[."
#   return
#fi


dir=/sphenix/lustre01/sphnxpro/commissioning/emcal/beam
dirhcal=/sphenix/lustre01/sphnxpro/commissioning/HCal/beam
dirzdc=/sphenix/lustre01/sphnxpro/commissioning/ZDC/beam
dirmbd=/sphenix/lustre01/sphnxpro/commissioning/mbd/beam

#topDir=/sphenix/u/sphnxpro/shrek/

# Target directory for the softlinks
topDir=/sphenix/lustre01/sphnxpro/production/2023/
ssh sphnxpro@`hostname -s` mkdir -p ${topDir}

submitopt=" --submit --group sphenix --no-uuid --no-timestamp "   
debugopt=" --debug all "
scope="group.sphenix"


workflows=ProdFlow/RHIC2023/CALOR/yaml

if [[ $1 ]]; then
   run=$( printf "%08d" $1 )
fi
if [[ $2 ]]; then
   nevents=$2
fi
if [[ $3 ]]; then
   dir=$3
fi
if [[ $4 ]]; then
   topDir=$4
fi
if [[ $5 ]]; then
   debugopt=$5
fi

tag=rn${run}-CALOR-${BUILD//./}
ts=`date +%Y%h%d-%H%M%S`

echo "RUNNUMBER: " $run
echo "TAG:       " $tag
echo "TIMESTAMP: " $ts
DATASET=${tag}-${DBTAG}
echo "DATASET:   " ${DATASET}
echo "SCOPE:     " ${scope}


DATASET_EXISTS=`rucio ls --short ${scope}:${DATASET}`
if [[ -z "${DATASET_EXISTS}" ]]; 
then
   echo "Create and populate ${scope}:${DATASET} for workflow submission"
else
   echo "-]${DATASET_EXISTS}[-"
   echo
   echo "The dataset ${DATASET} is already registered in rucio.  This may"
   echo "indicate that the given run has alread been produced with the"
   echo "requested analysis build and/or database configuration.  You will"
   echo "need to remove the submission dataset, and the resultant datasets"
   echo "in order to proceed."
   echo 
   return 12345
fi

# Clean out / create temp directory for filelists
if [ -e /tmp/${USER}/$run ]; then
   rm -r /tmp/${USER}/$run
fi
mkdir /tmp/${USER}/$run -p


#
# Build file lists
#

find ${dir} -type f -name *seb00*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb00
find ${dir} -type f -name *seb01*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb01
find ${dir} -type f -name *seb02*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb02
find ${dir} -type f -name *seb03*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb03
find ${dir} -type f -name *seb04*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb04
find ${dir} -type f -name *seb05*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb05
find ${dir} -type f -name *seb06*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb06
find ${dir} -type f -name *seb07*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.seb07
find ${dirhcal} -type f -name *West*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.hcalwest
find ${dirhcal} -type f -name *East*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.hcaleast
find ${dirzdc} -type f -name *seb14*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.zdc
find ${dirmbd} -type f -name *seb18*${run}-????.prdf -print | sort > /tmp/${USER}/$run/${DATASET}.mbd

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
echo CREATING DATASET=${DATASET}
ls -l ${TARGETDIR}

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

    ls  /tmp/${USER}/$run/${DATASET}.seb00  > ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.seb01  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.seb02  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.seb03  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.seb04  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.seb05  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.seb06  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.seb07  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.hcaleast  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.hcalwest  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.zdc  >> ${DATASET}.list
    ls  /tmp/${USER}/$run/${DATASET}.mbd >> ${DATASET}.list

shrek ${submitopt} ${debugopt} --build=${BUILD} ${DBOPT} --topDir=${topDir} --nevents=${nevents} --no-pause --tag ${tag}-${DBTAG} ${workflows}/runEvent*.yaml --runNumber=${run} --filelist=${DATASET}.list --ebinputs=${scope}:${DATASET} \
    --pack  /tmp/${USER}/$run/${DATASET}.seb00  \
    --pack  /tmp/${USER}/$run/${DATASET}.seb01  \
    --pack  /tmp/${USER}/$run/${DATASET}.seb02  \
    --pack  /tmp/${USER}/$run/${DATASET}.seb03  \
    --pack  /tmp/${USER}/$run/${DATASET}.seb04  \
    --pack  /tmp/${USER}/$run/${DATASET}.seb05  \
    --pack  /tmp/${USER}/$run/${DATASET}.seb06  \
    --pack  /tmp/${USER}/$run/${DATASET}.seb07  \
    --pack  /tmp/${USER}/$run/${DATASET}.hcaleast  \
    --pack  /tmp/${USER}/$run/${DATASET}.hcalwest  \
    --pack  /tmp/${USER}/$run/${DATASET}.zdc  \
    --pack  /tmp/${USER}/$run/${DATASET}.mbd 

# And cleanup the temp directory
rm /tmp/${USER}/$run/${DATASET}.*




