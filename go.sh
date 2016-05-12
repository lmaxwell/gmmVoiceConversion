#!/bin/bash
set -e

#mixture number of gmm
MIX=1
config=config.sh

# your data directory, should include directories of source and target speaker
#for example: /highway2/data/vc/huo /highway2/data/vc/wang
datdir=/highway2/data/vc

# gmm training directory, all files generated in training are stored here.
workdir=/highway2/gmmtraining

echo "===========prepare train and test file================"
# prepare train and test files
# automaticaly random select 1/10 files for test, the rest are for training
./run.sh -f $config -d $datdir -w $workdir -t prepare


echo "===========calculate gv of target singer=============="
./run.sh -f $config -d $datdir -w $workdir -t gv



echo "===========statistics of f0 of source and target singer=============="
./run.sh -f $config -d $datdir -w $workdir -t f0stat


echo "===========do iterative training====================================="
for ite in `seq 0 5`
do
    echo "============iteration $ite===================================="
    echo "============dtw align"
    ./run.sh -f $config -d $datdir -w $workdir -t dtw -m $MIX -i $ite
    echo "============gmm training"
    ./run.sh -f $config -d $datdir -w $workdir -t train -m $MIX -i $ite
    echo "============test"
    ./run.sh -f $config -d $datdir -w $workdir -t test -m $MIX -i $ite
done
#

MIX=64
for i in `seq 5 8`
do
    ./run.sh -f $config -d $datdir  -w $workdir -t train -m $MIX -i $i 
    ./run.sh -f $config -d $datdir  -w $workdir -t test -m $MIX -i $i 
    ./run.sh -f $config -d $datdir  -w $workdir -t dtw -m $MIX -i `echo $i+1|bc` 
done
