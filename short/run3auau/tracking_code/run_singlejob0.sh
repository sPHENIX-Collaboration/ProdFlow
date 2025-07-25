#!/usr/bin/env bash

## Tedium common to all run scripts. Important, source, not execute!
echo hello
. ./common_runscript_prep.sh
echo "Initialization done; back in $0"
echo "Running clustering (job0) for run ${run_number}, seg {segment}"
echo "---------------------------------------------"
echo "--- Collecting input files"
echo dataset=$dataset
echo dsttype=$dsttype
echo dbtag=$dbtag
echo run=$run
echo seg=$se
echo "---------------------------------------------"

make_filelists="./create_full_filelist_run_seg.py $dataset $dbtag $dsttype $run $seg"
echo "$make_filelists"
eval "$make_filelists"

shopt -s nullglob
listsfound="$(echo *.list)"
shopt -u nullglob
if [[ -n $listsfound ]]; then
    echo "Found json file(s):" 
    ls -la *.list
    for l in *list; do
	echo ---
	echo cat $l
	cat $l
    done
    echo ---
fi

run_macro='root.exe -q -b Fun4All_SingleJob0.C\(${nevents},${runnumber},\"${logbase}.root\",\"${dbtag}\",\"infile.list\"\);'
echo $run_macro
eval $run_macro
exit
# echo root.exe -q -b Fun4All_SingleJob0.C\(${nevents},${runnumber},\"${logbase}.root\",\"${dbtag}\",\"infile.list\"\)
# root.exe -q -b Fun4All_SingleJob0.C\(${nevents},${runnumber},\"${logbase}.root\",\"${dbtag}\",\"infile.list\"\);  status_f4a=$?

ls -la

echo ./stageout.sh ${logbase}.root ${outdir}
./stageout.sh ${logbase}.root ${outdir}

for hfile in HIST_*.root; do
    echo stageout.sh ${hfile} to ${histdir}
    ./stageout.sh ${hfile} ${histdir}
done

ls -la

echo done
exit ${status_f4a:-1}


# # Flag run as finished. 
# echo ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents ${nevents}  
#      ./cups.py -v -r ${runnumber} -s ${segment} -d ${outbase} finished -e ${status_f4a} --nevents ${nevents}

# echo "bdee bdee bdee, That's All Folks!"

# } >> ${logdir#file:/}/${logbase}.out  2>${logdir#file:/}/${logbase}.err


# exit ${status_f4a:-1}
