#!/bin/bash
#PBS -l walltime=05:00:00
#PBS -l ncpus=2
PBS_O_WORKDIR=(`echo $PBS_O_WORKDIR | sed "s/^\/state\/partition1//" `)
cd $PBS_O_WORKDIR

#Description: HaloPlex Pipeline for the Cortical Malformations Panel
#Author: Sara Rey & Matthew Lyon
#Status: Development
#Mode: BY_SAMPLE
Version=1

#load sample variables
. *.variables

#make tmp folder for java
mkdir tmp

#Run samtools to convert sam to bam
/share/apps/samtools-distros/samtools-1.1/samtools view -bS "$RunID"_"$SampleID".sam > "$RunID"_"$SampleID"_aligned.bam 

#Run samtools to sort the bam file
/share/apps/samtools-distros/samtools-1.1/samtools sort "$RunID"_"$SampleID"_aligned.bam "$RunID"_"$SampleID"_sorted

#Run samtools to index the bam file
/share/apps/samtools-distros/samtools-1.1/samtools index "$RunID"_"$SampleID"_sorted.bam

#Identify regions requiring realignment
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -Xmx2g -jar "/share/apps/GATK-distros/GATK_3.4-46/GenomeAnalysisTK.jar" \
-T RealignerTargetCreator \
-R "/data/db/human/gatk/2.8/b37/human_g1k_v37.fasta" \
-known "/data/db/human/gatk/2.8/b37/1000G_phase1.indels.b37.vcf" \
-known "/data/db/human/gatk/2.8/b37/Mills_and_1000G_gold_standard.indels.b37.vcf" \
-I "$RunID"_"$SampleID"_sorted.bam \
-o "$RunID"_"$SampleID".intervals \
-L /data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/beds/Cormal_GeneList_Ensemblv82_sorted_VendorIntersect.bed \
-ip 100 \
-dt NONE

#Realign around indels
echo "Indel Realignment for "$SampleID""
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -Xmx8g -jar "/share/apps/GATK-distros/GATK_3.4-46/GenomeAnalysisTK.jar" \
-T IndelRealigner \
-R "/data/db/human/gatk/2.8/b37/human_g1k_v37.fasta" \
-known "/data/db/human/gatk/2.8/b37/1000G_phase1.indels.b37.vcf" \
-known "/data/db/human/gatk/2.8/b37/Mills_and_1000G_gold_standard.indels.b37.vcf" \
-targetIntervals "$RunID"_"$SampleID".intervals \
-I "$RunID"_"$SampleID"_sorted.bam \
-o "$RunID"_"$SampleID".bam \
--consensusDeterminationModel USE_READS \
--LODThresholdForCleaning 0.4 \
--maxReadsForRealignment 5000000 \
--maxConsensuses 2500 \
--maxReadsForConsensuses 10000 \
--maxReadsInMemory 300000 \
-dt NONE

#cleanup
rm "$RunID"_"$SampleID".sam
rm "$RunID"_"$SampleID"_aligned.bam
rm "$RunID"_"$SampleID"_sorted.bam
rm "$RunID"_"$SampleID"_sorted.bam.bai
rm -rf tmp

qsub 3_AgilentHaloPlexCorMalPanel_VariantCalling.sh
