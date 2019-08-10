#!/bin/bash
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
--sample )
shift; SM=$1
;;
--loci )
shift; LOCI=$1
IFS=', ' read -r -a LOCIarr <<< "$(echo ,$LOCI)"
;;
--gatk )
shift; GATK=$1
;;
--java )
shift; JAVAMOD=$1
;;
--ref )
shift; REF=$1
;;
--perform )
shift; PERFORM=$1
;;
--workdir )
shift; CWD=$1
;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

module load $JAVAMOD

#echo ${LOCIarr[@]:1:${#LOCIarr[@]}}

TASK=${SLURM_ARRAY_TASK_ID}

TARGET=${LOCIarr[$TASK]}

if [[ $PERFORM = true ]]; then
    echo -e "$(date): indel_realigner.sh for ${TARGET%\.intervals} is running on $(hostname)" &>>  $CWD/$SM/metrics/perform_indel_realigner_$SM_${TARGET%\.intervals}.txt
    vmstat -twn -S m 1 >> $CWD/$SM/metrics/perform_indel_realigner_$SM_${TARGET%\.intervals}.txt &
fi

echo -e "$(date)\nRealigning indels on ${TARGET%\.intervals} for sample $SM\n" &>> $CWD/$SM/log/$SM.run.log


java -Djava.io.tmpdir=$CWD/$SM/tmp -jar $GATK \
-T IndelRealigner \
-R $REF \
-I $CWD/$SM/bam/$SM.markdup.bam \
-targetIntervals $CWD/$SM/fastq/$SM.indelTarget.intervals \
-L ${REF%/*}/target_loci/$TARGET \
-o $CWD/$SM/bam/$SM.${TARGET%\.intervals}.realign.bam &>> $CWD/$SM/log/$SM.realign.${TARGET%\.intervals}.log

if [[ $(wc -c <$CWD/$SM/bam/$SM.${TARGET%\.intervals}.realign.bam) -ge 1000 ]]; then
    echo -e "$(date)\nIndel realignment for ${TARGET%\.intervals} in $SM is complete\n" &>> $CWD/$SM/log/$SM.run.log
else
    echo -e "$(date)\n$SM ${TARGET%\.intervals} indel realigned bam not found or too small, exiting\n" &>> $CWD/$SM/log/$SM.run.log
    scancel -n $SM
fi
