#!/bin/bash
#author:LiXian
set -e

DEBUG=0
if [ $DEBUG -eq 1 ];then
   set -xv
fi

function usage()
{
    echo "usage:"
    echo "      ./run.sh -f config.sh -d datdir -w workdir -t task -m mixture_num -i iteration"
    echo "      task = ( prepare | train | test )"
	echo "      datdir: feature directory"
    echo "      workdir: gmm training directory"
    echo "---------------------------------------------------------"
    echo "example:./run.sh -f config.sh -d /home/lixian/data -w workdir -t train -i 0"
    echo '         if source speaker is huo, target speaker is sw, directory structure of datdir should be "/home/lixian/huo" and "/home/lixian/sw"'
    exit 1
}

if [ $# -lt 8 ];then
        echo "not enough arguments!"
	usage
	exit 1
fi

ite=0
while getopts 'f:d:t:w:m:i:' OPT; do
    case $OPT in
        d)
            datdir="$OPTARG";;
        f)
            configfile="$OPTARG";;
        w)
            workdir="$OPTARG";;
        t)
            task="$OPTARG";;
        m)
            MIX=`echo "$OPTARG"|bc`;;
        i)
            ite=`echo "$OPTARG"|bc`;;
        ?)
	        usage;;
    esac
done

if [ $task != "prepare" -a $task!="dtw" -a $task!= "train" -a $task!="gv" -a $task!="f0stat" -a $task!="test" ];then
    usage
    exit 1
fi
echo datadir=$datdir
echo workdir=$workdir
echo configfile=$configfile
echo task=$task
echo ite=$ite

source $configfile


workdir=$workdir/$SRC-$TRG

if [ $task == "prepare" ];then
    mkdir -p $workdir $workdir/list
    rm -f $workdir/list/filelist
    file_num=0
    for f in $datdir/$SRC/mcep/*.mcep
    do
        base=`basename $f .mcep`
        if [ -s $datdir/$TRG/mcep/${base}.mcep ];then
            file_num=`echo $file_num+1|bc`
            echo $base >> $workdir/list/filelist  
        fi
    done
    test_num=`echo $file_num/10|bc`
    train_num=`echo "$file_num - $test_num"|bc`
    
    echo "totally $file_num files,$train_num for training, $test_num for test"
    echo "random select $test_num files for test"
    rm -f $workdir/list/testlist
    for i in `seq 1 $test_num`
    do
        line=`echo $RANDOM*$file_num/32768|bc`
        sed -n -e "${line}p" $workdir/list/filelist >> $workdir/list/testlist
    done
    cp $workdir/list/filelist $workdir/list/trainlist
    cat $workdir/list/testlist | while read line;
    do
        sed -i "/$line/d" $workdir/list/trainlist
    done
    echo "test file list saved to $workdir/list/testlist"
    echo "train file list saved to $workdir/list/trainlist"
fi

if [ $task == "dtw" ];then
    mkdir -p $workdir/align $workdir/temp
    rm -f $workdir/align/dtw.mcep.ite$ite
    if [ ! -s $workdir/list/trainlist ];then
        echo "!!ERROR!!pls run prepare task first"
        exit 1
    fi
    if [ $ite -eq 0 ];then
        for f in `cat $workdir/list/trainlist`
        do
            $SPTK/bcp -l `echo ${MGCORDER}+1|bc` -s 1 $datdir/$SRC/mcep/$f.mcep >$workdir/temp/$SRC.$f.mcep
            $SPTK/bcp -l `echo ${MGCORDER}+1|bc` -s 1 $datdir/$TRG/mcep/$f.mcep >$workdir/temp/$TRG.$f.mcep
            $SPTK/delta -l $MGCORDER     -r 2 1 1  $workdir/temp/$SRC.$f.mcep > $workdir/temp/$SRC.$f.mcep.delta
            $SPTK/delta -l $MGCORDER  -r 2 1 1 $workdir/temp/$TRG.$f.mcep > $workdir/temp/$TRG.$f.mcep.delta
            #perl scripts/window.pl $MGCORDER $workdir/temp/$SRC.$f.mcep win/mgc.win1 win/mgc.win2 win/mgc.win3 >$workdir/temp/$SRC.$f.mcep.delta
            #perl scripts/window.pl $MGCORDER $workdir/temp/$TRG.$f.mcep win/mgc.win1 win/mgc.win2 win/mgc.win3 >$workdir/temp/$TRG.$f.mcep.delta
            $SPTK/dtw -l ${MGCORDER} -p 5 -n 2 -v $workdir/temp/viterbi.$f.mcep $workdir/temp/$TRG.$f.mcep  < $workdir/temp/$SRC.$f.mcep >$workdir/temp/$f.dtw         
            $SPTK/dtw -l `echo ${MGCORDER}\*3|bc`  -V $workdir/temp/viterbi.$f.mcep $workdir/temp/$TRG.$f.mcep.delta < $workdir/temp/$SRC.$f.mcep.delta   >>$workdir/align/dtw.mcep.ite$ite
        done
    else
        for f in `cat $workdir/list/trainlist`
        do
            $SPTK/bcp -l `echo ${MGCORDER}+1|bc` -s 1 $datdir/$SRC/mcep/$f.mcep >$workdir/temp/$SRC.$f.mcep
            $SPTK/vc_cd -r 2 1 1     -l ${MGCORDER} -m ${MIX}   $workdir/gmmmodel/$SRC-$TRG-$MIX.gmm.ite`echo "$ite-1"|bc` $workdir/temp/$SRC.$f.mcep > $workdir/temp/conv.$f.mcep
            $SPTK/bcp -l `echo ${MGCORDER}+1|bc` -s 1 $datdir/$TRG/mcep/$f.mcep >$workdir/temp/$TRG.$f.mcep
        $SPTK/delta -l $MGCORDER  -r 2 1 1   $workdir/temp/$SRC.$f.mcep > $workdir/temp/$SRC.$f.mcep.delta
        $SPTK/delta -l $MGCORDER  -r 2 1 1  $workdir/temp/$TRG.$f.mcep > $workdir/temp/$TRG.$f.mcep.delta
            #perl scripts/window.pl $MGCORDER $workdir/temp/conv.$f.mcep win/mgc.win1 win/mgc.win2 win/mgc.win3 >$workdir/temp/conv.$f.mcep.delta
            #perl scripts/window.pl $MGCORDER $workdir/temp/$TRG.$f.mcep win/mgc.win1 win/mgc.win2 win/mgc.win3 >$workdir/temp/$TRG.$f.mcep.delta
            $SPTK/dtw -l ${MGCORDER} -p 4 -n 2 -v $workdir/temp/viterbi.$f.mcep $workdir/temp/$TRG.$f.mcep  < $workdir/temp/$SRC.$f.mcep >$workdir/temp/$f.dtw         
        $SPTK/dtw -l `echo ${MGCORDER}|bc` -p 5 -n 2 -v $workdir/temp/viterbi.$f.mcep $workdir/temp/$TRG.$f.mcep< $workdir/temp/conv.$f.mcep>$workdir/temp/$f.dtw
        $SPTK/dtw -l `echo ${MGCORDER}\*3|bc`  -V $workdir/temp/viterbi.$f.mcep $workdir/temp/$TRG.$f.mcep.delta < $workdir/temp/$SRC.$f.mcep.delta >>$workdir/align/dtw.mcep.ite$ite 
        done
    fi
    rm -rf $workdir/temp
fi

if [ $task == "train" ];then
    mkdir -p $workdir/gmmmodel
    $SPTK/gmm   -l `echo ${MGCORDER}\*6|bc` -m ${MIX} -B   ${MGCORDER} ${MGCORDER} ${MGCORDER} ${MGCORDER}  ${MGCORDER} ${MGCORDER} -c1 $workdir/align/dtw.mcep.ite$ite > $workdir/gmmmodel/$SRC-$TRG-$MIX.gmm.ite$ite
fi

if [ $task == "gv" ];then
    mkdir -p $workdir/temp $workdir/gvmodel
    rm -f $workdir/temp/$TRG.gv
    for f in `cat $workdir/list/trainlist`
    do
        $SPTK/bcp -l `echo ${MGCORDER}+1|bc` -s 1 $datdir/$TRG/mcep/$f.mcep >$workdir/temp/$TRG.$f.mcep
        $SPTK/vstat -l  ${MGCORDER} $workdir/temp/$TRG.$f.mcep -d -o 2 > $workdir/temp/$TRG.$f.gv
        if [ -n "`$SPTK/nan $workdir/temp/$TRG.$f.gv`" ];then
            echo "nan in $TRG.$f.gv"
        else
            cat $workdir/temp/$TRG.$f.gv >> $workdir/temp/$TRG.gv
        fi
    done
    $SPTK/vstat -l ${MGCORDER} -d $workdir/temp/$TRG.gv > $workdir/gvmodel/$TRG.gv
fi


if [ $task == "f0stat" ];then
    mkdir -p $workdir/temp $workdir/f0stat
    rm -f $workdir/temp/$SRC.lf0 $workdir/temp/$TRG.lf0
    for f in `cat $workdir/list/testlist`
    do
        $SPTK/sopr -magic -1.0e+10 $datdir/$SRC/lf0/$f.lf0 >>$workdir/temp/$SRC.lf0
        $SPTK/sopr -magic -1.0e+10 $datdir/$TRG/lf0/$f.lf0 >>$workdir/temp/$TRG.lf0
    done
    echo "`$SPTK/vstat -l 1 -o 1 $workdir/temp/$SRC.lf0 |$SPTK/x2x +fa`- `$SPTK/vstat -l 1 -o 1 $workdir/temp/$TRG.lf0 |$SPTK/x2x +fa`"|bc |$SPTK/x2x +af  > $workdir/f0stat/$SRC-$TRG
fi

if [ $task == "test" ];then
    mkdir -p $workdir/test $workdir/test/ite$ite-${MIX}mix
    for f in `cat $workdir/list/testlist`
    do
        echo "test $f"
        $SPTK/bcp -l `echo ${MGCORDER}+1|bc` -s 1 $datdir/$SRC/mcep/$f.mcep >$workdir/test/ite$ite-${MIX}mix/$SRC.$f.mcep
        $SPTK/vc   -r 2 1 1    -l ${MGCORDER} -m ${MIX}  -g $workdir/gvmodel/$TRG.gv $workdir/gmmmodel/$SRC-$TRG-$MIX.gmm.ite$ite $workdir/test/ite$ite-${MIX}mix/$SRC.$f.mcep > $workdir/test/ite$ite-${MIX}mix/conv.$f.mcep
        $SPTK/bcp -l `echo ${MGCORDER}+1|bc` -s 0 -e 0  $datdir/$SRC/mcep/$f.mcep >$workdir/test/ite$ite-${MIX}mix/$SRC.$f.pow
        $SPTK/merge -s 0 -l ${MGCORDER} -L 1 $workdir/test/ite$ite-${MIX}mix/$SRC.$f.pow $workdir/test/ite$ite-${MIX}mix/conv.$f.mcep >$workdir/test/ite$ite-${MIX}mix/conv.$f.mcepw0
        $SPTK/sopr -magic -1e+10 -s `$SPTK/x2x +fa $workdir/f0stat/$SRC-$TRG` -MAGIC -1e+10  $datdir/$SRC/lf0/$f.lf0 >$workdir/test/ite$ite-${MIX}mix/conv.$f.lf0
		$MGCVocoder -im $workdir/test/ite$ite-${MIX}mix/conv.$f.mcepw0 -if $workdir/test/ite$ite-${MIX}mix/conv.$f.lf0 -ow $workdir/test/ite$ite-${MIX}mix/conv.$f.wav -m $MGCORDER -s $SAMPFREQ -p $FRAMESHIFT -a $ALPHA -g 0 -l
       $SPTK/vopr -s $workdir/test/ite$ite-${MIX}mix/conv.$f.mcepw0 $datdir/$SRC/mcep/$f.mcep > $workdir/test/ite$ite-${MIX}mix/$f.diff.mcepw0
        $SPTK/x2x +sf $datdir/$SRC/raw/$f.raw | $SPTK/mlsadf -m $MGCORDER -p $FRAMESHIFT -a $ALPHA  $workdir/test/ite$ite-${MIX}mix/$f.diff.mcepw0 |$SPTK/x2x +fs -o >$workdir/test/ite$ite-${MIX}mix/$f.diff.raw
        $SPTK/raw2wav -d $workdir/test/ite$ite-${MIX}mix $workdir/test/ite$ite-${MIX}mix/$f.diff.raw

    done
fi 

