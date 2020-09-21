#!/bin/env perl
use strict;
use warnings;

use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use List::MoreUtils qw(natatime);

use File::Slurper 'write_text';

my $root_dir ='/storage/hpc/group/warrenlab/users/alanarodney/exomes/buckleypipeline';

my $ref_fasta = '/storage/hpc/group/warrenlab/raw/191203__64864848400199__cat-cancer-exomes/Felis_catus_9.0.fa';

my $metrics_dir = "$root_dir/metrics";
my $log_dir     = "$root_dir/log";
my $bam_dir     = "$root_dir/BAM";
my $vcf_dir     = "$root_dir/VCF";

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
        my $command = "bash ../../pre_process_pipeline.sh -c $sample_config -m TASK_allocations.tsv -a warrenlab -p BioCompute -e \$USER\@umsystem.edu -t ../tasks -r $ref_fasta -R /storage/htc/warrenlab/reference_files/BQSR_db/Felis_catus_9.0/190823_domestic/190823_Felis_catus_9.0.db.vcf.gz -C $root_dir -b $bam_dir -g $vcf_dir -M $metrics_dir -l $log_dir -A 10 -G 100";
        #system("echo '$command'");
        system($command);
    }
}

sub create_config_file_for ($sample_name) {

    my $contents = <<"END";
Sample	Library	Platform	Flowcell	Lane	R1	R2	D1	D2	REF	Recal	CWD	BAM	GVCF	METRICS	LOG
$sample_name	$sample_name	ILLUMINA	HVWFLDSXX	4	${sample_name}_R1.fq	${sample_name}_R2.fq	/storage/hpc/group/warrenlab/users/alanarodney/exomes/catcancer2/BAM	${sample_name}.sorted.bam	$ref_fasta	/storage/htc/warrenlab/reference_files/BQSR_db/Felis_catus_9.0/v9_vcf/GATK/SRA_99_Lives.chrE3.vcf.gz	$root_dir	$bam_dir	$vcf_dir	$metrics_dir	$log_dir
END
    my $filename = "$sample_name.config.tsv";
    write_text($filename, $contents);
    return $filename;
}
