#!/bin/bash
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
--sample )
shift; SM=$1
;;
--gatk )
shift; GATK=$1
;;
--loci )
shift; LOCI=$1
IFS=', ' read -r -a LOCIarr <<< "$(echo ,$LOCI)"
;;
--java )
shift; JAVAMOD=$1
;;
--ref )
shift; REF=$1
;;
--bqsr )
shift; BQSR=$1
;;
--threads )
shift; THREADS=$1
;;
--perform )
shift; PERFORM=$1
;;
--workdir )
shift; CWD=$1
;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

sleep $((RANDOM % 10))

module load $JAVAMOD

TASK=${SLURM_ARRAY_TASK_ID}
TARGET=${LOCIarr[$TASK]}

# take two different inputs
if [[ $BQSR = true ]]; then
	inStatus=recal
elif [[ $BQSR = false ]]; then
	inStatus=realign
fi

if [[ $PERFORM = true ]]; then
    echo -e "$(date) haplotypecaller.sh is running on $(hostname)" &>> $CWD/$SM/metrics/perform_haplotypecaller_$SM_${TARGET%\.intervals}.txt
    scontrol show jobid -dd ${SLURM_JOB_ID} &>> $CWD/$SM/metrics/perform_haplotypecaller_$SM_${TARGET%\.intervals}.txt
    echo -e "\n\n\n" &>> $CWD/$SM/metrics/perform_haplotypecaller_$SM_${TARGET%\.intervals}.txt
    vmstat -twn -S m 1 >> $CWD/$SM/metrics/perform_haplotypecaller_$SM_${TARGET%\.intervals}.txt &
fi

echo -e "$(date)\tbegin\thaplotypecaller.sh\t$SM\t${TARGET%\.intervals}" &>> $CWD/$SM/log/$SM.run.log


java -Djava.io.tmpdir=$CWD/$SM/tmp -jar $GATK \
-nct $THREADS \
-ERC GVCF \
-T HaplotypeCaller \
-R $REF \
-L ${REF%/*}/target_loci/$TARGET \
-I $CWD/$SM/bam/$SM.${TARGET%\.intervals}.$inStatus.bam \
-o $CWD/$SM/gvcf/$SM.${TARGET%\.intervals}.g.vcf.gz

if [[ -s $CWD/$SM/gvcf/$SM.${TARGET%\.intervals}.g.vcf.gz ]]; then
    echo -e "$(date)\tend\thaplotypecaller.sh\t$SM\t${TARGET%\.intervals}" &>> $CWD/$SM/log/$SM.run.log
else
    echo -e "$(date)\tfail\thaplotypecaller.sh\t$SM\t${TARGET%\.intervals}" &>> $CWD/$SM/log/$SM.run.log
    scancel -n $SM
fi
