#!/cluster/biocompute/software/perl/perl-5.30.3/bin/perl
use strict;
use warnings;

use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use List::MoreUtils qw(natatime);

use File::Slurper 'write_text';

# Create job param config file named TASK_allocations.tsv
create_job_params_config();

my $out_dir ='outs';
mkdir $out_dir;

my $ref_fasta = '/storage/hpc/group/warrenlab/raw/191203__64864848400199__cat-cancer-exomes/Felis_catus_9.0.fa';

my $metrics_dir = "$out_dir/metrics";
my $log_dir     = "$out_dir/log";
my $bam_dir     = "$out_dir/BAM";
my $vcf_dir     = "$out_dir/VCF";

for my $DIR ($metrics_dir, $log_dir, $bam_dir, $vcf_dir) {
    mkdir $DIR; 
}

my @id = qw(
    FCBO-24147-100241
    FCBO-24147-100242
);

#my @id = qw(
#    FCBO-12918-100249
#    FCBO-12918-100250
#    FCBO-18406-100253
#    FCBO-18406-100254
#    FCBO-21308-100236
#    FCBO-21308-100237
#    FCBO-23263-100234
#    FCBO-23263-100235
#    FCBO-24147-100241
#    FCBO-24147-100242
#    FCBO-26089-100243
#    FCBO-26089-100244
#    FCBO-26903-100245
#    FCBO-26903-100246
#    FCBO-7741-100247
#    FCBO-7741-100248
#    FCBO-9895-100251
#    FCBO-9895-100252
#    FCBO-Pebbles-100303
#    FCBO-Pebbles-100304
#    FCBO-605591-100313
#    FCBO-605591-100314
#);

# Might want to skip???
#    FCBO-605591-100313
#    FCBO-605591-100314
#

my $it = natatime 2, @id;

while (my ($matched_normal, $tumor) = $it->()) {
    for my $sample ($matched_normal, $tumor) {
        my $sample_config = create_config_file_for($sample);
        my $command = "sbatch -- /storage/htc/warrenlab/scripts/batch_GATK_workflow/pre_process_pipeline.sh -c $sample_config -m TASK_allocations.tsv -a warrenlab -p BioCompute -e \$USER\@umsystem.edu -t /storage/htc/warrenlab/scripts/batch_GATK_workflow/tasks -r $ref_fasta -R /storage/htc/warrenlab/reference_files/BQSR_db/Felis_catus_9.0/190823_domestic/190823_Felis_catus_9.0.db.vcf.gz -C $out_dir -b $bam_dir -g $vcf_dir -M $metrics_dir -l $log_dir -A 10 -G 100";
        #system("echo '$command'");
        system($command);
    }
}

sub create_config_file_for ($sample_name) {

    # CAUTION: Below contains literal tabs. Be sure to fix them if you edit the text. 
    my $contents = <<"END";
Sample	Library	Platform	Flowcell	Lane	R1	R2	D1	D2	REF	Recal	CWD	BAM	GVCF	METRICS	LOG
$sample_name	$sample_name	ILLUMINA	HVWFLDSXX	4	${sample_name}_R1.fq	${sample_name}_R2.fq	/storage/hpc/group/warrenlab/users/alanarodney/exomes/catcancer2/BAM	${sample_name}.sorted.bam	$ref_fasta	/storage/htc/warrenlab/reference_files/BQSR_db/Felis_catus_9.0/v9_vcf/GATK/SRA_99_Lives.chrE3.vcf.gz	$out_dir	$bam_dir	$vcf_dir	$metrics_dir	$log_dir
END
    my $filename = "$sample_name.config.tsv";
    write_text($filename, $contents);
    return $filename;
}

sub create_job_params_config {
    # CAUTION: Below contains literal tabs. Be sure to fix them if you edit the text. 
    my $contents = <<"END";
TASK	MEM	TIME	NTASKS
prepare_dirs	10	1-01:00	1
prepare_reads	11	1-00:00	20
map_reads	12	1-01:00	20
sort	13	1-01:00	5
merge	13	1-01:00	5
mark_duplicates	14	1-01:00	2
index	15	1-01:00	5
unmapped_reads	16	1-01:00	2
realigner_target_creator	17	0-01:00	10
indel_realigner	18	1-01:00	10
first_pass_bqsr	19	1-01:00	10
print_reads	20	1-01:00	10
second_pass_bqsr	21	1-01:00	10
cat_sort_index_bams	22	1-01:00	5
haplotypecaller	23	1-01:00	10
cat_gvcf	24	1-01:00	5
cp_files	25	1-01:00	5
clean_wd	26	1-01:00	5
END
    write_text('TASK_allocations.tsv',$contents);  
    return;
}
