#!/bin/bash
#PBS -l walltime=05:00:00
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

#make tmp folder for java
mkdir tmp

#variant calling with UnifiedGenotyper
echo "Running GATK Unified Genotyper on "$SampleID""
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -Xmx8g -jar "/share/apps/GATK-distros/GATK_3.4-46/GenomeAnalysisTK.jar" \
-T UnifiedGenotyper \
-R "/data/db/human/gatk/2.8/b37/human_g1k_v37.fasta" \
-L /data/diagnostics/pipelines/AgilentHaloPlexEpilepsyPanel/"$Version"/beds/Epilepsy_GeneList_Ensemblv82_sorted_VendorIntersect.bed \
--dbsnp "/data/db/human/gatk/2.8/b37/dbsnp_138.b37.vcf" \
-I "$RunID"_"$SampleID".bam \
-o "$RunID"_"$SampleID".vcf \
-glm BOTH \
-ploidy 2 \
--output_mode EMIT_VARIANTS_ONLY \
-stand_call_conf 10.0 \
-stand_emit_conf 30.0 \
--min_indel_fraction_per_sample 0.1 \
-dt NONE

#clean up
rm -rf tmp

qsub 4_AgilentHaloPlexEpilepsyPanel_VariantProcessing.sh
