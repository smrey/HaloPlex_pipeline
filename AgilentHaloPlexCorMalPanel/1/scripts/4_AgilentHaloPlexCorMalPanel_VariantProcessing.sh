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

#filter calls
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -Xmx2g -jar /share/apps/GATK-distros/GATK_3.4-46/GenomeAnalysisTK.jar \
-R /data/db/human/gatk/2.8/b37/human_g1k_v37.fasta \
-T VariantFiltration \
-o "$RunID"_"$SampleID"_Filtered.vcf \
--variant "$RunID"_"$SampleID".vcf \
--filterExpression "QUAL < 30.0" \
--filterName "LowQual" \
-L /data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/beds/Cormal_GeneList_Ensemblv82_sorted_VendorIntersect.bed \
-dt NONE

#add variant classification
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -Xmx2g -jar /share/apps/GATK-distros/GATK_3.4-46/GenomeAnalysisTK.jar \
-R /data/db/human/gatk/2.8/b37/human_g1k_v37.fasta \
-T VariantAnnotator \
-V "$RunID"_"$SampleID"_Filtered.vcf \
-o "$RunID"_"$SampleID"_Filtered_Classified.vcf \
--resource:known_variants /data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/AgilentHaloPlexCorMalPanel_KnownVariants.vcf \
-E known_variants.Classification \
-L /data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/beds/Cormal_GeneList_Ensemblv82_sorted_VendorIntersect.bed \
-dt NONE

#add unique ID to ID column
perl /data/diagnostics/scripts/AddVariantID.pl "$RunID"_"$SampleID"_Filtered_Classified.vcf

#annotate VCF
perl /share/apps/vep-distros/ensembl-tools-release-75/scripts/variant_effect_predictor/variant_effect_predictor.pl \
-i "$RunID"_"$SampleID"_Filtered_Classified_ID.vcf \
--fasta /share/apps/vep-distros/ensembl-tools-release-75/scripts/variant_effect_predictor/annotations/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa \
--dir /share/apps/vep-distros/ensembl-tools-release-75/scripts/variant_effect_predictor/annotations \
--output "$RunID"_"$SampleID"_VEP.txt \
--refseq \
--offline \
--force_overwrite \
--no_stats \
--sift b \
--polyphen b \
--numbers \
--hgvs \
--symbol \
--gmaf \
--maf_1kg \
--maf_esp \
--fields Uploaded_variation,Location,Allele,AFR_MAF,AMR_MAF,ASN_MAF,EUR_MAF,AA_MAF,EA_MAF,Consequence,SYMBOL,Feature,HGVSc,HGVSp,PolyPhen,SIFT,EXON,INTRON

#write variant report
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -jar /data/diagnostics/apps/VariantReporter.jar \
"$RunID"_"$SampleID"_Filtered_Classified.vcf \
"$RunID"_"$SampleID"_VEP.txt \
/data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/AgilentHaloPlexCorMalPanel_PreferredTranscripts.txt

#generate per-base coverage
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -Xmx8g -jar /share/apps/GATK-distros/GATK_3.4-46/GenomeAnalysisTK.jar \
-T DepthOfCoverage \
-R /data/db/human/gatk/2.8/b37/human_g1k_v37.fasta \
-o "$RunID"_"$SampleID"_DepthOfCoverage \
-I "$RunID"_"$SampleID".bam \
-L /data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/beds/Cormal_GeneList_Ensemblv82_sorted_VendorIntersect.bed \
--countType COUNT_FRAGMENTS \
--minBaseQuality 20 \
--minMappingQuality 40 \
-ct 30 \
-dt NONE

#calculate gene percentage coverage
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -Xmx8g -jar /data/diagnostics/apps/CoverageCalculator2.jar \
"$RunID"_"$SampleID"_DepthOfCoverage \
/data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/AgilentHaloPlexCorMalPanel_Gene_List.txt \
/data/db/human/ensembl/Homo_sapiens.GRCh37.82.gtf > "$RunID"_"$SampleID"_PercentageCoverage.txt

#annotate gaps with HGVS & gene
perl /data/diagnostics/scripts/bed2vcf.pl "$SampleID"_gaps.bed > "$RunID"_"$SampleID"_Gaps.vcf

#annotate gap VCF
perl /share/apps/vep-distros/ensembl-tools-release-75/scripts/variant_effect_predictor/variant_effect_predictor.pl \
-i "$RunID"_"$SampleID"_Gaps.vcf \
--fasta /share/apps/vep-distros/ensembl-tools-release-75/scripts/variant_effect_predictor/annotations/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa \
--dir /share/apps/vep-distros/ensembl-tools-release-75/scripts/variant_effect_predictor/annotations \
--output "$RunID"_"$SampleID"_Gaps_VEP.txt \
--refseq \
--offline \
--force_overwrite \
--no_stats \
--sift b \
--polyphen b \
--numbers \
--hgvs \
--symbol \
--gmaf \
--maf_1kg \
--maf_esp \
--fields Uploaded_variation,Location,Allele,AFR_MAF,AMR_MAF,ASN_MAF,EUR_MAF,AA_MAF,EA_MAF,Consequence,SYMBOL,Feature,HGVSc,HGVSp,PolyPhen,SIFT,EXON,INTRON

#convert back to BED format
/usr/java/jdk1.7.0_51/bin/java -Djava.io.tmpdir=tmp -jar /data/diagnostics/apps/RegionAnnotator.jar "$SampleID"_gaps.bed "$RunID"_"$SampleID"_Gaps_VEP.txt /data/diagnostics/pipelines/AgilentHaloPlexCorMalPanel/"$Version"/AgilentHaloPlexCorMalPanel_PreferredTranscripts.txt

#clean up
rm "$RunID"_"$SampleID".vcf
rm "$RunID"_"$SampleID"_Filtered.vcf
rm -rf tmp
