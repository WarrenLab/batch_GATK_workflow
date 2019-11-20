#!/bin/bash
# set defults for unused options
BQSR=false
PERFORM=false
GAPSIZE=100
ARRAYLEN=10

SAMTOOLSMOD=samtools/samtools-1.9-test
GATK=/cluster/software/gatk/gatk-3.8/GenomeAnalysisTK.jar
PICARD=/cluster/software/picard-tools/picard-tools-2.1.1/picard.jar
JAVAMOD=java/openjdk/java-1.8.0-openjdk
PIGZMOD=pigz/pigz-2.4
BWAMOD=bwa/bwa-0.7.17
RMOD=R/R-3.3.3
BEDTOOLSMOD=bedtools/bedtools-2.26.0

bold=$(tput bold)
normal=$(tput sgr0)

# need to read in the config file! 
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
-h | --help )
echo echo "
pre_process_pipeline.sh runs GATK version 3 for germline variants in WGS and WES data.
	${bold}-a, --account${normal}=[STRING]
		Slurm account to for pipeline to use

	${bold}-A, --array-len${normal}=[INTEGER]
		Integer value for size of array to use for dividing jobs, 10 is the default

	${bold}-b, --bam${normal}=[STRING]
		Directory of where to place final bam output

	${bold}-c, --config${normal}=[STRING]
		Config file for individual cat. Tab seperated file must contain a header with the following
		columns:
			
			Sample: Sample name
			Library: Library ID
			Platform: Sequencing platform, eg. ILLUMINA
			Flowcell: Flowcell ID
			Lane: Lane number
			R1: Read one name without .gz file extension
			R2: Read two name without .gz file extension
			D1: Directory for where to find read one file / Directory for where to find uBAM
			D2: Directory for where to find read two file / Filename of uBAM

	${bold}-C, --cwd${normal}=[STRING]
		Working directory for where to process sample. Preferably somewhere in /storage/hpc.

	${bold}-e, --email${normal}=[STRING]
		Email address for where to direct slurm emails.

	${bold}-E, --exomes${normal}=[STRING]
		Full path to bed file containing exonic intervals to be used in WES analysis.

	${bold}-g, --gvcf${normal}=[STRING]
		Directory of where to place final gvcf output.

	${bold}-G, --gap-size${normal}=[INTEGER]
		Integer value for minimum bp size of gap region for dividing genome into segements, 
		default is 100.

	${bold}-l, --log${normal}=[STRING]
		Directory of where to place final log output.

	${bold}-m, --machine-config${normal}=[STRING]
		Machine configuration tab seperated file.
		
		The following columns neet to be included:
			TASK: Task/job name, described below in more detail.
			MEM: Integer value for required memmory for indidual tasks in G. 
			TIME: Time value to be used by slurm for time limits.
			NTASKS: Integer value for number of caused to be used for individual tasks.

		The following shows the individual task names used in the pipeline:
			prepare_dirs
			prepare_reads
			map_reads
			sort
			merge
			mark_duplicates
			index
			unmapped_reads
			realigner_target_creator
			indel_realigner
			first_pass_bqsr
			print_reads
			second_pass_bqsr
			cat_sort_index_bams
			haplotypecaller
			cat_gvcf
			cp_files
			clean_wd

	${bold}-M, --metrics${normal}=[STRING]
		Directory of where to place final metrics output.

	${bold}-p, --partition${normal}=[STRING]
		Lewis partition to use for prcessing. Can be supplied as a comma sepperated list, 
		eg. Lewis,hpc5

	${bold}-P, --perform${normal}
		Record performance metrics every second pipeline is running.

	${bold}-r, --ref${normal}=[STRING]
		Full path to reference genome fasta file.

	${bold}-R, --recal${normal}=[STRING]
		Full path to varaint database for BQSR. If not specified, BQSR will not be performed.

	${bold}-t, --taskdir${normal}=[STRING]
		Full path to directory where indivudal tasks are stored.

	${bold}--bwa${normal}=[STRING]
		BWA module to load. Default is Default is bwa/bwa-0.7.17.

	${bold}--bedtools${normal}=[STRING]
		Bedtools version to load. Default is bedtools/bedtools-2.26.0.

	${bold}--rversion${normal}=[STRING]
		R modulel to load. Default is R/R-3.3.3.

	${bold}--samtools${normal}=[STRING]
		Samtools module to load. Default is samtools/samtools-1.9-test.

	${bold}--picard${normal}=[STRING]
		Full path to picard tools. 
		Default is /cluster/software/picard-tools/picard-tools-2.1.1/picard.jar

	${bold}--pigz${normal}=[STRING]
		Pigz module to load. Default is pigz/pigz-2.4.

	${bold}--gatk${normal}=[STRING]
		Full path to version 3 GATK program. 
		Default is /cluster/software/gatk/gatk-3.8/GenomeAnalysisTK.jar.
"
exit
;;
-a | --account=)
shift; ACCOUNT=$1
;;
-A | --array-len=)
shift; ARRAYLEN=$1 # An interger value of how to break up the analysis
;;
-b | --bam=)
shift; BAM=$1
;;
-c | --config=)
shift; CONFIG=$1
SM=$(cat $CONFIG | sed '2q;d' | awk {'print $1'}) # pulls out first row of config col 1
LB=$(echo $(cat $CONFIG | cut -f2) | sed 's/ /,/g') # pulls out entire col 2 and converts to comma sep values
PL=$(echo $(cat $CONFIG | cut -f3) | sed 's/ /,/g')
FC=$(echo $(cat $CONFIG | cut -f4) | sed 's/ /,/g')
LN=$(echo $(cat $CONFIG | cut -f5) | sed 's/ /,/g')
R1=$(echo $(cat $CONFIG | cut -f6) | sed 's/ /,/g')
R2=$(echo $(cat $CONFIG | cut -f7) | sed 's/ /,/g')
D1=$(echo $(cat $CONFIG | cut -f8) | sed 's/ /,/g')
D2=$(echo $(cat $CONFIG | cut -f9) | sed 's/ /,/g')
runLen=$(expr $(wc -l $CONFIG | cut -d" " -f1) - 1)
;;
-C | --cwd=)
shift; CWD=$1
;;
-e | --email=)
shift; EMAIL=$1
;;
-E | --exomes=)
shift; EXOME=$1
;;
-g | --gvcf=)
shift; GVCF=$1
;;
-G | --gap-size=)
shift; GAPSIZE=$1 # for setting the size of gaps where it is ok to break the genome
;;
-l | --log=)
shift; LOG=$1
;;
-m | --machine-config=)
shift; MACHINE=$1
;;
-M | --metrics=)
shift; METRICS=$1
;;
-p | --partition=)
shift; PARTITION=$1
;;
-P | --perform )
PERFORM=true
;;
-r | --ref=)
shift; REF=$1
;;
-R | --recal=)
shift; RECAL=$1
BQSR=true
;;
-t | --taskdir=)
shift; TASKDIR=$1
;;
--bwa=)
shift; BWAMOD=$1
;;
--bedtools=)
shift; BEDTOOLSMOD=$1
;;
--rversion=)
shift; RMOD=$1
;;
--samtools=)
shift; SAMTOOLSMOD=$1
;;
--picard=)
shift; PICARD=$1
;;
--pigz=)
shift; PIGZMOD=$1
;;
--gatk=)
shift; GATK=$1
;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

# in performance mode we use the entire node for each task
if [[ $PERFORM = true ]]; then
	EXCLUSIVE="--exclusive"
elif [[ $PERFORM = false ]]; then
	EXCLUSIVE=""
fi

if [[ ! -z $EXOME ]]; then
	EXOME=$(echo "--exome $EXOME")	
fi


prepare_dirsMEM=$(cat $MACHINE | grep prepare_dirs | cut -f 2)
prepare_dirsTIME=$(cat $MACHINE | grep prepare_dirs | cut -f 3)
prepare_dirsNTASKS=$(cat $MACHINE | grep prepare_dirs | cut -f 4)
# prepare dirs
sbatch \
--mem=${prepare_dirsMEM}G --time=${prepare_dirsTIME} --nodes=1 --ntasks=${prepare_dirsNTASKS} \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
--mail-user=$EMAIL --mail-type=FAIL,BEGIN --output=prepare_dirs-${SM}-%j.out \
$TASKDIR/prepare_dirs.sh --sample $SM \
--platform $PL --flowcell $FC --lane $LN --library $LB \
--read1 $R1 --read2 $R2 --path1 $D1 --path2 $D2 \
--ref $REF --workdir $CWD --recal $RECAL --bam $BAM \
--gvcf $GVCF --metrics $METRICS --log $LOG \
--bwa $BWAMOD --pigz $PIGZMOD --java $JAVAMOD \
--samtools $SAMTOOLSMOD --gatk $GATK --picard $PICARD \
--runLen $runLen --perform $PERFORM --bqsr $BQSR --taskdir $TASKDIR \
--rversion $RMOD --bedtools $BEDTOOLSMOD --array-len $ARRAYLEN --gap-size $GAPSIZE

prepare_readsMEM=$(cat $MACHINE | grep prepare_reads | cut -f 2)
prepare_readsTIME=$(cat $MACHINE | grep prepare_reads | cut -f 3)
prepare_readsNTASKS=$(cat $MACHINE | grep prepare_reads | cut -f 4)
# prepare reads
# this may use some samtools options
sbatch \
--mem=${prepare_readsMEM}G --time=${prepare_readsTIME} --nodes=1 --ntasks=${prepare_readsNTASKS} \
--array=1-$runLen \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/prepare_reads-${SM}-%A-%a-%j.out \
$TASKDIR/prepare_reads.sh --sample $SM \
--read1 $R1 --read2 $R2 --path1 $D1 --path2 $D2 --threads ${prepare_readsNTASKS} \
--workdir $CWD --pigz $PIGZMOD \
--samtools $SAMTOOLSMOD --perform $PERFORM \


map_readsMEM=$(cat $MACHINE | grep map_reads | cut -f 2)
map_readsTIME=$(cat $MACHINE | grep map_reads | cut -f 3)
map_readsNTASKS=$(cat $MACHINE | grep map_reads | cut -f 4)
# Map reads
# bwa does not offer mem usage options but scales proportinally with threads
sbatch \
--mem=${map_readsMEM}G --time=${map_readsTIME} --nodes=1 --ntasks=${map_readsNTASKS} \
--array=1-$runLen --job-name=$SM --account=$ACCOUNT \
--partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/map_reads-${SM}-%A-%a-%j.out \
$TASKDIR/map_reads.sh --sample $SM \
--read1 $R1 --read2 $R2 --threads ${map_readsNTASKS} \
--workdir $CWD --bwa $BWAMOD --samtools $SAMTOOLSMOD --perform $PERFORM \
--flowcell $FC --lane $LN --library $LB --platform $PL --ref $REF \


sort_MEM=$(cat $MACHINE | grep -P "^sort\t" | cut -f 2)
sort_TIME=$(cat $MACHINE | grep -P "^sort\t" | cut -f 3)
sort_NTASKS=$(cat $MACHINE | grep -P "^sort\t" | cut -f 4)
# sort
sbatch \
--mem=${sort_MEM}G --time=${sort_TIME} --nodes=1 --ntasks=${sort_NTASKS} --array=1-$runLen \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/sort-${SM}-%A-%a-%j.out \
$TASKDIR/sort.sh --sample $SM \
--threads ${sort_NTASKS} --memrequest ${sort_MEM} \
--workdir $CWD --samtools $SAMTOOLSMOD --perform $PERFORM \


merge_MEM=$(cat $MACHINE | grep -P "^merge\t" | cut -f 2)
merge_TIME=$(cat $MACHINE | grep -P "^merge\t" | cut -f 3)
merge_NTASKS=$(cat $MACHINE | grep -P "^merge\t" | cut -f 4)
# merge
sbatch \
--mem=${merge_MEM}G --time=${merge_TIME} --nodes=1 --ntasks=${merge_NTASKS} \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/merge-${SM}-%j.out \
$TASKDIR/merge.sh --sample $SM \
--threads ${merge_NTASKS} --runLen $runLen \
--workdir $CWD --samtools $SAMTOOLSMOD --perform $PERFORM \

mark_duplicatesMEM=$(cat $MACHINE | grep mark_duplicates | cut -f 2)
mark_duplicatesTIME=$(cat $MACHINE | grep mark_duplicates | cut -f 3)
mark_duplicatesNTASKS=$(cat $MACHINE | grep mark_duplicates | cut -f 4)
# mark_duplicates.sh
sbatch \
--mem=${mark_duplicatesMEM}G --time=${mark_duplicatesTIME} --nodes=1 --ntasks=${mark_duplicatesNTASKS} \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/mark_duplicates-${SM}-%j.out \
$TASKDIR/mark_duplicates.sh --sample $SM \
--workdir $CWD --picard $PICARD --java $JAVAMOD --perform $PERFORM --memrequest ${mark_duplicatesMEM}


indexMEM=$(cat $MACHINE | grep -P "^index\t" | cut -f 2)
indexTIME=$(cat $MACHINE | grep -P "^index\t" | cut -f 3)
indexNTASKS=$(cat $MACHINE | grep -P "^index\t" | cut -f 4)
# index.sh
IDXJOB=$(sbatch \
--mem=${indexMEM}G --time=${indexTIME} --nodes=1 --ntasks=${indexNTASKS} \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/index-${SM}-%j.out \
$TASKDIR/index.sh --sample $SM \
--workdir $CWD --samtools $SAMTOOLSMOD --perform $PERFORM --threads ${indexNTASKS} | cut -f 4 -d ' ')

echo $IDXJOB


unmapped_readsMEM=$(cat $MACHINE | grep unmapped_reads | cut -f 2)
unmapped_readsTIME=$(cat $MACHINE | grep unmapped_reads | cut -f 3)
unmapped_readsNTASKS=$(cat $MACHINE | grep unmapped_reads | cut -f 4)
# unmapped_reads.sh
sbatch \
--mem=${unmapped_readsMEM}G --time=${unmapped_readsTIME} --nodes=1 --ntasks=${unmapped_readsNTASKS} \
--job-name=${SM}-unmapped --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d afterok:$IDXJOB \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/unmapped_reads-${SM}-%j.out \
$TASKDIR/unmapped_reads.sh --sample $SM --memrequest ${unmapped_readsMEM} \
--workdir $CWD --samtools $SAMTOOLSMOD --perform $PERFORM --threads ${unmapped_readsNTASKS}


realigner_target_creatorMEM=$(cat $MACHINE | grep realigner_target_creator | cut -f 2)
realigner_target_creatorTIME=$(cat $MACHINE | grep realigner_target_creator | cut -f 3)
realigner_target_creatorNTASKS=$(cat $MACHINE | grep realigner_target_creator | cut -f 4)
# realigner_target_creator
# need to check nt and nct defs to determine how to set max mem usage for java 
sbatch \
--mem=${realigner_target_creatorMEM}G --time=${realigner_target_creatorTIME} --nodes=1 \
--ntasks=${realigner_target_creatorNTASKS} \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/realigner_target_creator-${SM}-%j.out \
$TASKDIR/realigner_target_creator.sh --sample $SM \
--workdir $CWD --gatk $GATK --java $JAVAMOD --ref $REF --perform $PERFORM \
--threads ${realigner_target_creatorNTASKS} --memrequest ${realigner_target_creatorMEM}

#indel realignment
indel_realignerMEM=$(cat $MACHINE | grep indel_realigner | cut -f 2)
indel_realignerTIME=$(cat $MACHINE | grep indel_realigner | cut -f 3)
indel_realignerNTASKS=$(cat $MACHINE | grep indel_realigner | cut -f 4)
# needs a job id for cat_sort_index_bams.sh
CATBAMID=$(sbatch \
--mem=${indel_realignerMEM}G --time=${indel_realignerTIME} --nodes=1 --ntasks=${indel_realignerNTASKS} \
--array=1-$ARRAYLEN \
--job-name=$SM --account=$ACCOUNT --partition=hpc4,hpc5 $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/indel_realigner-${SM}-%A-%a-%j.out \
$TASKDIR/indel_realigner.sh --sample $SM \
--workdir $CWD --gatk $GATK --java $JAVAMOD --ref $REF --perform $PERFORM \
--memrequest ${indel_realignerMEM} | cut -f 4 -d ' ')

echo $CATBAMID

if [[ $BQSR = true ]]; then
CATBAMID=""

first_pass_bqsrMEM=$(cat $MACHINE | grep first_pass_bqsr | cut -f 2)
first_pass_bqsrTIME=$(cat $MACHINE | grep first_pass_bqsr | cut -f 3)
first_pass_bqsrNTASKS=$(cat $MACHINE | grep first_pass_bqsr | cut -f 4)
#first_pass_bqsr.s
BQSRID=$(sbatch \
--mem=${first_pass_bqsrMEM}G --time=${first_pass_bqsrTIME} --nodes=1 --ntasks=${first_pass_bqsrNTASKS} \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/first_pass_bqsr-${SM}-%j.out \
$TASKDIR/first_pass_bqsr.sh --sample $SM \
--workdir $CWD --gatk $GATK --java $JAVAMOD --recal $RECAL --ref $REF \
--perform $PERFORM --threads ${first_pass_bqsrNTASKS} --array-len $ARRAYLEN \
--memrequest ${first_pass_bqsrMEM} $EXOME | cut -f 4 -d ' ')

echo $BQSRID

print_readsMEM=$(cat $MACHINE | grep print_reads | cut -f 2)
print_readsTIME=$(cat $MACHINE | grep print_reads | cut -f 3)
print_readsNTASKS=$(cat $MACHINE | grep print_reads | cut -f 4)
# print_reads.sh
# needs a job id for cat_sort_index_bams.sh
CATBAMID=$(sbatch \
--mem=${print_readsMEM}G --time=${print_readsTIME} --nodes=1 --ntasks=${print_readsNTASKS} \
--array=1-$ARRAYLEN \
--job-name=$SM --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE -d singleton \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/print_reads-${SM}-%A-%a-%j.out \
$TASKDIR/print_reads.sh --sample $SM \
--workdir $CWD --gatk $GATK --java $JAVAMOD --ref $REF --perform $PERFORM \
--memrequest ${print_readsMEM} --threads ${print_readsNTASKS}| cut -f 4 -d ' ')

echo $CATBAMID

second_pass_bqsrMEM=$(cat $MACHINE | grep second_pass_bqsr | cut -f 2)
second_pass_bqsrTIME=$(cat $MACHINE | grep second_pass_bqsr | cut -f 3)
second_pass_bqsrNTASKS=$(cat $MACHINE | grep second_pass_bqsr | cut -f 4)
# second_pass_bqsr.sh
SECONDBQSRID=$(sbatch \
--mem=${second_pass_bqsrMEM}G --time=${second_pass_bqsrTIME} --ntasks=${second_pass_bqsrNTASKS} \
-d afterok:$BQSRID  --nodes=1 \
--job-name=${SM}-recal-plots --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/second_pass_bqsr-${SM}-%j.out \
$TASKDIR/second_pass_bqsr.sh --sample $SM \
--workdir $CWD --gatk $GATK --java $JAVAMOD --recal $RECAL --ref $REF \
--perform $PERFORM --threads ${second_pass_bqsrNTASKS} \
 --rversion $RMOD --memrequest ${second_pass_bqsrMEM} $EXOME | cut -f 4 -d ' ')

echo $SECONDBQSRID

fi

cat_sort_index_bamsMEM=$(cat $MACHINE | grep cat_sort_index_bams | cut -f 2)
cat_sort_index_bamsTIME=$(cat $MACHINE | grep cat_sort_index_bams | cut -f 3)
cat_sort_index_bamsNTASKS=$(cat $MACHINE | grep cat_sort_index_bams | cut -f 4)
# cat_sort_index.sh
# this can run parallele to haplotype caller
# needs to take two alternative jobIDs, no we can just overwrite the variable if bqsr is true
# push the output to final destination
# then get an md5sum
FINISHBAMID=$(sbatch \
--mem=${cat_sort_index_bamsMEM}G --time=${cat_sort_index_bamsTIME} --nodes=1 \
--ntasks=${cat_sort_index_bamsNTASKS} \
--job-name=${SM}-cat-bams --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
-d afterok:$CATBAMID \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/cat_sort_index_bams-${SM}-%j.out \
$TASKDIR/cat_sort_index_bams.sh --sample $SM \
--ref $REF --workdir $CWD --samtools $SAMTOOLSMOD --perform $PERFORM --threads ${cat_sort_index_bamsNTASKS} \
--bqsr $BQSR --memrequest $cat_sort_index_bamsMEM --rversion $RMOD \
--picard $PICARD --array-len $ARRAYLEN | cut -f 4 -d ' ')


haplotypecallerMEM=$(cat $MACHINE | grep haplotypecaller | cut -f 2)
haplotypecallerTIME=$(cat $MACHINE | grep haplotypecaller | cut -f 3)
haplotypecallerNTASKS=$(cat $MACHINE | grep haplotypecaller | cut -f 4)
# haplotype caller
sbatch \
--mem=${haplotypecallerMEM}G --time=${haplotypecallerTIME} --ntasks=${haplotypecallerNTASKS} \
-d singleton --array 1-$ARRAYLEN --nodes=1 \
--job-name=${SM} --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/haplotypecaller-${SM}-%A-%a-%j.out \
$TASKDIR/haplotypecaller.sh --sample $SM \
--workdir $CWD --gatk $GATK --java $JAVAMOD --ref $REF --bqsr $BQSR \
--perform $PERFORM --threads ${haplotypecallerNTASKS} --memrequest ${haplotypecallerMEM} $EXOME


cat_gvcfMEM=$(cat $MACHINE | grep cat_gvcf | cut -f 2)
cat_gvcfTIME=$(cat $MACHINE | grep cat_gvcf | cut -f 3)
cat_gvcfNTASKS=$(cat $MACHINE | grep cat_gvcf | cut -f 4)

# cat gvcfs
# for samtools tasks we could put more into mem
VARCALLID=$(sbatch \
--mem=${cat_gvcfMEM}G --time=${cat_gvcfTIME} --ntasks=${cat_gvcfNTASKS} \
-d singleton --nodes=1 --job-name=${SM} \
--account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/cat_gvcf-${SM}-%j.out \
$TASKDIR/cat_gvcf.sh --sample $SM \
--workdir $CWD --picard $PICARD --java $JAVAMOD --ref $REF --array-len $ARRAYLEN \
--perform $PERFORM --memrequest ${cat_gvcfMEM} | cut -f 4 -d ' ')
echo $VARCALLID


cp_filesMEM=$(cat $MACHINE | grep cp_files | cut -f 2)
cp_filesTIME=$(cat $MACHINE | grep cp_files | cut -f 3)
cp_filesNTASKS=$(cat $MACHINE | grep cp_files | cut -f 4)
# move everything to final place

if [[ $BQSR = true ]]; then

FINALID=$(sbatch \
--mem=${cp_filesMEM}G --time=${cp_filesTIME} --nodes=1 --ntasks=${cp_filesNTASKS} \
-d afterok:${VARCALLID}:${SECONDBQSRID}:${FINISHBAMID} --job-name=${SM} --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/cp_files-${SM}-%j.out \
$TASKDIR/cp_files.sh --sample $SM \
--workdir $CWD --bam $BAM --metrics $METRICS --log $LOG --gvcf $GVCF --bqsr $BQSR | cut -f 4 -d ' ')

else

FINALID=$(sbatch \
--mem=${cp_filesMEM}G --time=${cp_filesTIME} --nodes=1 --ntasks=${cp_filesNTASKS} \
-d afterok:${VARCALLID}:${FINISHBAMID} --job-name=${SM} --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
--mail-user=$EMAIL --mail-type=FAIL --output=$CWD/$SM/log/cp_files-${SM}-%j.out \
$TASKDIR/cp_files.sh --sample $SM \
--workdir $CWD --bam $BAM --metrics $METRICS --log $LOG --gvcf $GVCF --bqsr $BQSR | cut -f 4 -d ' ')

fi

echo $FINALID

clean_wdMEM=$(cat $MACHINE | grep clean_wd | cut -f 2)
clean_wdTIME=$(cat $MACHINE | grep clean_wd | cut -f 3)
clean_wdNTASKS=$(cat $MACHINE | grep clean_wd | cut -f 4)
#clean the working dir
sbatch \
--mem=${clean_wdMEM}G --time=${clean_wdTIME} --nodes=1 --ntasks=${clean_wdNTASKS} \
-d afterok:${FINALID} \
--job-name=${SM} --account=$ACCOUNT --partition=$PARTITION $EXCLUSIVE \
--mail-user=$EMAIL --mail-type=FAIL,END --output=clean_wd-${SM}-%j.out \
$TASKDIR/clean_wd.sh --sample $SM \
--workdir $CWD


