#!/usr/bin/bash -f
#________________________________________________________________
#
# Script to re-process calorimeter from prdf inputs
#
#________________________________________________________________

nevents=0
BUILD=ana.383
#DBTAG=TESTp001p42
DBTAG=2023p002
scope="group.sphenix"
INPUT_SCOPE=group.sphenix
INPUT_CONTAINER=RHIC2023-sPHENIX-CALOR-EVENTS
workflows=ProdFlow/RHIC2023/CALOR/yaml

source /opt/sphenix/core/bin/sphenix_setup.sh -n ${BUILD}
DBOPT=" --dbtag=${DBTAG} "
submitopt=" --submit --group sphenix --no-uuid --no-timestamp "
debugopt=" --debug all "


#_________________________________________________________________________________________
main() {

    regex="group.sphenix.rn(\d+)"

    for RUN in `rucio list-content --short ${INPUT_SCOPE}:${INPUT_CONTAINER}`; do

   # group.sphenix:group.sphenix.rn00021587-CALOR-ana381-20231014-203835_000_EventCombine_0

	# Regex does not like to work here so just strip away the left and right...
	run=${RUN#*.rn}
	run=${run%-CALOR*}

	tag=rn${run}-CALOR-${BUILD//./}

DATASET=${tag}-${DBTAG}
DATASET_EXISTS=`rucio ls --short ${scope}:${DATASET}`
if [[ -z "${DATASET_EXISTS}" ]]; 
then
   echo "Create ${scope}:${DATASET} for workflow submission"
else
   echo "========================================================================\n"
   echo "-]${DATASET_EXISTS}[-\n"
   echo
   echo "The dataset ${DATASET} is already registered in rucio.  This may\n"
   echo "indicate that the given run has alread been produced with the\n"
   echo "requested analysis build and/or database configuration.  You will\n"
   echo "need to remove the submission dataset, and the resultant datasets\n"
   echo "in order to proceed."
   echo "========================================================================\n"
   echo 
   return 100
fi

cat <<EOF | python
from rucio.client import Client
import hashlib
import pprint
import os
import uuid
client = Client()

dataset="${DATASET}"
client.add_dataset( "group.sphenix", dataset )
client.set_metadata( "group.sphenix",  dataset, key='run_number', value="$run")

EOF

shrek ${submitopt} --inputds=${RUN} ${debugopt} --build=${BUILD} ${DBOPT} --nevents=${nevents} --no-pause --tag ${tag}-${DBTAG} ${workflows}/rerunCalorimeter.yaml --runNumber=${run} 


    done

}

#_________________________________________________________________________________________
main
