#!/bin/bash
#PBS -l walltime=04:00:00
#PBS -l ncpus=2
PBS_O_WORKDIR=(`echo $PBS_O_WORKDIR | sed "s/^\/state\/partition1//" `)
cd $PBS_O_WORKDIR

#Description: HaloPlex Pipeline for the Infantile Epilepsy Panel
#Author: Sara Rey & Matthew Lyon
#Status: Development
#Mode: BY_SAMPLE
Version=1

#load sample variables
. *.variables

if [[ $(gunzip -t "$Read1Fastq") -ne 0 ]] || [[ $(gunzip -t "$Read2Fastq") -ne 0 ]] ;then
	echo "FASTQ file(s) are corrupt, cannot proceed."
	exit -1
fi

#trim read 1 adapter from R1 and read 2 adapter from R2 as paired end trimming
echo Trimming "$SampleID"
/share/apps/cutadapt-distros/cutadapt-1.9.1/bin/cutadapt \
-a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC \
-A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTCGCCGTATCATT \
-e 0.15 \
-m 40 \
-o "$RunID"_"$SampleID"_R1_trimmed.fastq \
-p "$RunID"_"$SampleID"_R2_trimmed.fastq \
"$Read1Fastq" "$Read2Fastq"

#Remove contaminating Gex adapter from read 1 and remove short reads
/share/apps/cutadapt-distros/cutadapt-1.9.1/bin/cutadapt \
-a ATCTCGTATGCCGTCTTCTGCTTG \
-e 0.15 \
-m 40 \
-o "$RunID"_"$SampleID"_R1_trimmed2.fastq \
-p "$RunID"_"$SampleID"_R2_trimmed2.fastq \
"$RunID"_"$SampleID"_R1_trimmed.fastq "$RunID"_"$SampleID"_R2_trimmed.fastq

#Trim the file of the first 5 and last 5 bases R1 (remove restriction sites)
/share/apps/cutadapt-distros/cutadapt-1.9.1/bin/cutadapt \
-u 5 \
-u -5 \
-o "$RunID"_"$SampleID"_R1_paired.fastq  \
"$RunID"_"$SampleID"_R1_trimmed2.fastq

#Trim the file of the first 5 and last 5 bases R2 (remove restriction sites)
/share/apps/cutadapt-distros/cutadapt-1.9.1/bin/cutadapt \
-u 5 \
-u -5 \
-o "$RunID"_"$SampleID"_R2_paired.fastq  \
"$RunID"_"$SampleID"_R2_trimmed2.fastq

#run fastqc
/share/apps/fastqc-distros/fastqc_v0.11.2/fastqc "$RunID"_"$SampleID"_R1_paired.fastq
/share/apps/fastqc-distros/fastqc_v0.11.2/fastqc "$RunID"_"$SampleID"_R2_paired.fastq

#locally align reads to reference genome
echo Mapping "$SampleID"
/share/apps/bwa-distros/bwa-0.7.10/bwa mem \
-M \
-R '@RG\tID:'"$RunID"'\tSM:'"$SampleID"'\tPL:'"$Platform"'\tLB:'"$ExperimentName"'\tPU:'"$RunID" \
"/data/db/human/mappers/b37/bwa/human_g1k_v37.fasta" \
"$RunID"_"$SampleID"_R1_paired.fastq "$RunID"_"$SampleID"_R2_paired.fastq \
> "$RunID"_"$SampleID".sam

qsub 2_AgilentHaloPlexEpilepsyPanel_IndelRealignment.sh

#clean up
rm "$RunID"_"$SampleID"_R1_paired_fastqc.zip
rm "$RunID"_"$SampleID"_R2_paired_fastqc.zip
rm "$RunID"_"$SampleID"_R1_trimmed.fastq
rm "$RunID"_"$SampleID"_R2_trimmed.fastq
rm "$RunID"_"$SampleID"_R1_trimmed2.fastq
rm "$RunID"_"$SampleID"_R2_trimmed2.fastq
rm "$RunID"_"$SampleID"_R1_paired.fastq
rm "$RunID"_"$SampleID"_R2_paired.fastq
