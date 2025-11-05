#!/usr/bin/env bash

## Tedium common to all run scripts. Important, source, not execute!
echo Sourcing ${SPHENIXPROD_SCRIPT_PATH}/common_runscript_prep.sh
. ${SPHENIXPROD_SCRIPT_PATH}/common_runscript_prep.sh
echo "Initialization done; back in $0"
##

echo "Running clustering (job0) for run ${run}, seg ${seg}"
echo "---------------------------------------------"
echo "--- Collecting input files"
echo dataset=$dataset
echo dsttype=$dsttype
echo intriplet=$intriplet
echo run=$run
echo seg=$seg
echo "---------------------------------------------"

make_filelists="./create_full_filelist_run_seg.py $dataset $intriplet $dsttype $run $seg"
echo "$make_filelists"
eval "$make_filelists"

shopt -s nullglob
listsfound="$(echo *.list)"
shopt -u nullglob
if [[ -n $listsfound ]]; then
    echo "Found list file(s):" 
    ls -la *.list
    for l in *list; do
	echo ---
	echo cat $l
	cat $l
    done
    echo ---
fi

# ls -la *.list
# echo end of ls -la '*.list'

# ### Stage input to local
# for infile in `cat infile_paths.list`; do
#     cp -v $infile .
# done

root_line="Fun4All_ana515_SingleJob0.C(${nevents},${run},\"${logbase}.root\",\"${dbtag}\",\"infile.list\")"
full_command="root.exe -q -b '${root_line}'"

echo "--- Executing macro"
echo "${full_command}"
eval "${full_command}" ;  status_f4a=$?

ls -la

echo ./stageout.sh ${logbase}.root ${outdir}
./stageout.sh ${logbase}.root ${outdir}

for hfile in HIST_*.root; do
    echo stageout.sh ${hfile} to ${histdir}
    ./stageout.sh ${hfile} ${histdir}
done

ls -la

echo All done
exit ${status_f4a:-1}

