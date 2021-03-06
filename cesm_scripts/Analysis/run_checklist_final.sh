#!/bin/sh
cd /home/disk/eos4/rachel/git/NCL/cesm_scripts/Analysis//scripts/
dir="/home/disk/eos4/rachel/CESM_outfiles/HYAK/"
#dir="/home/disk/rachel/CESM_outfiles/"
numexps="1"
exps=("WACCM_f19_LGM") # "CESM_IG58N_ZRGH") # "CAM4SOM4_4xCO2_noMT") 
# "CESM_IG39_West" "CESM_IG49N_West")
#exps=("CESM_Topo_R_2km_40_0" "CESM_Topo_R_2km_50_0" "CESM_Topo_R_2km_60_0")
#exps=("CESMnotopof19" "CESM_IG29" "CESM_IG34" "CESM_onlyITSh" "CESM_IG44" "CESM_IG49")
start="15"
end="25"
nsecs="21600" #"00000"

export NCL_N_ARGS=$#
export NCL_dirstr="/atm/hist/"
export NCL_Mtrans=0


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

echo NCL_N_ARGS 
ncl Create_all_means.ncl 
echo 'Create_all_means.ncl'
#ncl Calc_VertGrad.ncl
#echo 'Calc_VertGrad.ncl'
ncl hybrid2pres_morelev.ncl
echo 'hybrid2pres_morelev.ncl'
#ncl Calc_Eady.ncl
#echo 'Calc_Eady.ncl'
#ncl LanczosF_Z850.ncl
#echo 'LanczosF_Z850.ncl'
#ncl Calc_varZ850.ncl
#echo 'Calc_varZ850.ncl'
#echo 'Calc_dTHdy.ncl'
#ncl Calc_dTHdy.ncl
#echo 'Calc_Vpr_Upr_THpr'
#ncl Calc_Vpr_Upr_THpr.ncl
#echo 'Calc_VprTHpr_UprTHpr.ncl'
#ncl Calc_VprTHpr_UprTHpr.ncl
#echo 'Calc_Vpr_Upr_THpr_annual.ncl'
#ncl Calc_Vpr_Upr_THpr_annual.ncl
#echo 'Calc_VprTHpr_UprTHpr_annual.ncl'
#ncl Calc_VprTHpr_UprTHpr_annual.ncl

echo 'finished'

