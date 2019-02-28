#!/bin/sh
cd /home/disk/eos4/rachel/git/NCL/cesm_scripts/Analysis//scripts/
#dir="/home/disk/eos4/rachel/CESM_outfiles/"
dir="/home/disk/rachel/ShiftAtl/"
numexps="2"
exps=("CAM4_f19f19_SAM10E" "CAM4_f19f19_CTL") 
start="2"
end="31"
nsecs="00000"


export NCL_ARG_lonstart=0
export NCL_ARG_lonend=360

export NCL_dirstr="/"
export NCL_Mtrans=0
export NCL_N_ARGS=$#

# save command line arguments to environment variable NCL_ARG_#
export NCL_ARG_1=$dir
export NCL_ARG_2=$numexps

# save command line arguments to environment variable NCL_ARG_#
for ((index=3; index<=2+$numexps; index++))
do
  eval export NCL_ARG_$index=${exps[index-3]}
done
echo $index
eval export NCL_ARG_$index=$start
((index++))
echo $index
eval export NCL_ARG_$index=$end
((index++))
echo $index
eval export NCL_ARG_$index=$nsecs

echo "Initial_analysis_means.ncl"
ncl Initial_analysis_means.ncl

echo 'finished'

