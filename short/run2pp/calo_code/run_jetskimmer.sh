#!/usr/bin/env bash

## Tedium common to all run scripts. Important, source, not execute!
echo Sourcing ${SPHENIXPROD_SCRIPT_PATH}/common_runscript_prep.sh
. ${SPHENIXPROD_SCRIPT_PATH}/common_runscript_prep.sh
echo "Initialization done; back in $0"
##

echo "Running JETSKIMMER for run ${run_number}, seg ${segment}"
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

ls -la *.list
echo end of ls -la '*.list'

# Get input file from list (macro expects single file, not file list)
infile=$(head -1 infile.list)

outfile_jetcalo=${logbase}.root
outfile_jet=${logbase/DST_JETCALO/DST_Jet}.root
outhist=${logbase/DST_JETCALO/HIST_JETQA}.root

root_line="Fun4All_JetSkimmedProductionYear2.C(${nevents},\"${infile}\",\"${outfile_jetcalo}\",\"${outfile_jet}\",\"${outhist}\",\"${dbtag}\")"
full_command="root.exe -q -b '${root_line}'"
eval "${full_command}"

for hfile in HIST_*.root; do
    echo stageout.sh ${hfile} to ${histdir}
    ./stageout.sh ${hfile} ${histdir}
done

echo ./stageout.sh ${outfile_jetcalo} ${outdir} ${dbid}
./stageout.sh ${outfile_jetcalo} ${outdir} ${dbid}

echo ./stageout.sh ${outfile_jet} ${outdir} ${dbid}
./stageout.sh ${outfile_jet} ${outdir} ${dbid}

ls -la

echo done
exit ${status_f4a:-1}
