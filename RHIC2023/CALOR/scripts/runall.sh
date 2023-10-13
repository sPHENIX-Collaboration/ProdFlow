#!/usr/bin/bash -f

input="ProdFlow/RHIC2023/CALOR/scripts/runnumbers"
#input="failed_runs_short.txt"
while IFS= read -r line
do
  echo "$line"
  #runno="000"$line
  #echo $runno
  echo ------------------------------------------------------------ 
  echo $line                                                        
  source ProdFlow/RHIC2023/CALOR/scripts/run_calorimeter.sh $line 
done < "$input"

