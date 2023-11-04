#!/usr/bin/bash -f

input="ProdFlow/RHIC2023/CALOR/scripts/runnumbers-11-03-2023"
#input="failed_runs_short.txt"
#input="ProdFlow/RHIC2023/CALOR/scripts/mia.runs"

#while IFS= read -r line
#do
#  echo $line                                                        
#  set +e
#  source ProdFlow/RHIC2023/CALOR/scripts/run_calorimeter.sh $line 
#done < "$input"

for line in $(cat $input); do
    echo $line
    source ProdFlow/RHIC2023/CALOR/scripts/run_calorimeter.sh $line 
done



