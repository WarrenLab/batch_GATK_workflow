# this script needs rewording for the end


#!/bin/bash
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
--sample )
shift; SM=$1
;;
--samtools )
shift; SAMTOOLSMOD=$1
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
--threads )
shift; THREADS=$1
;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

module load $SAMTOOLSMOD

if [[ $PERFORM = true ]]; then
    echo -e "$(date): cat_sort_index_bams.sh is running on $(hostname)" &>>  $CWD/$SM/metrics/perform_cat_sort_index_bams_$SM.txt
    vmstat -twn -S m 1 >> $CWD/$SM/metrics/perform_cat_sort_index_bams_$SM.txt &
fi

LOCI=$(echo $(ls ${REF%/*}/target_loci) |  sed 's/.intervals//g' | sed 's/ /,/g')


echo -e "$(date)\nConcat realigned bams for sample $SM\n" &>> $CWD/$SM/log/$SM.run.log

eval samtools cat -o $CWD/$SM/bam/$SM.realign.bam $CWD/$SM/bam/$SM.{$(echo $LOCI)}.realign.bam &>> $CWD/$SM/log/$SM.cat_sort_index_bams.log

if [[ -s $CWD/$SM/bam/$SM.realign.sort.bam.bai ]]; then
    echo -e "$(date)\nConcat realigned bams for $SM is complete\n" &>> $CWD/$SM/log/$SM.run.log
else
    echo -e "$(date)\nConcat realigned bams for $SM is not found or is empty, exiting\n" &>> $CWD/$SM/log/$SM.run.log
    scancel -n $SM
fi


echo -e "$(date)\nSorting realigned bam for sample $SM\n" &>> $CWD/$SM/log/$SM.run.log

samtools sort --threads $THREADS -o $CWD/$SM/bam/$SM.realign.sort.bam $CWD/$SM/bam/$SM.realign.bam &>> $CWD/$SM/log/$SM.cat_sort_index_bams.log

if [[ -s $CWD/$SM/bam/$SM.realign.sort.bam.bai ]]; then
    echo -e "$(date)\nSorting realigned bam for $SM is complete\n" &>> $CWD/$SM/log/$SM.run.log
else
    echo -e "$(date)\nSorted realigned bam for $SM is not found or is empty, exiting\n" &>> $CWD/$SM/log/$SM.run.log
    scancel -n $SM
fi


echo -e "$(date)\nIndexing bam for sample $SM\n" &>> $CWD/$SM/log/$SM.run.log

samtools index -@ $THREADS $CWD/$SM/bam/$SM.realign.sort.bam

if [[ -s $CWD/$SM/bam/$SM.realign.sort.bam.bai ]]; then
    echo -e "$(date)\nIndexing for $SM is complete\n" &>> $CWD/$SM/log/$SM.run.log
else
    echo -e "$(date)\n$SM bai file not found or empty, exiting\n" &>> $CWD/$SM/log/$SM.run.log
    scancel -n $SM
fi