#!/bin/bash
#$ -cwd 
#$ -q short.qc
#$ -pe shmem 2
#$ -j y

echo "------------------------------------------------"
echo `date`: Executing task ${SGE_TASK_ID} of job ${JOB_ID} on `hostname` as user ${USER}
echo SGE_TASK_FIRST=${SGE_TASK_FIRST}, SGE_TASK_LAST=${SGE_TASK_LAST}, SGE_TASK_STEPSIZE=${SGE_TASK_STEPSIZE}
echo "Run on host: "`hostname`
echo "Operating system: "`uname -s`
echo "Username: "`whoami`
echo "Started at: "`date`
echo "------------------------------------------------"


# load tools
module load SAMtools/1.9-foss-2018b
module load deepTools/3.3.1-foss-2018b-Python-3.6.6


# Set parameters
## source config.sh
if [[ ! -e "output" ]]; then
mkdir ./output
fi

##
Basename=$(cat Sample.key.txt | tail -n+${SGE_TASK_ID} | head -1 | cut -f1 )

echo "########## bedgraph file generated by bamCoverage: " $Basename

### extract Uniquely mapped reads (alignment processed with hisat2)
    samtools view -@ 18  -q 60 -b ${Basename}_merged_chr.bam  > ${Basename}_chrXXX.uniq.mapped.bam

    samtools view -@ 12 -H ${Basename}_chrXXX.uniq.mapped.bam | grep -v @PG | \
samtools reheader - ${Basename}_chrXXX.uniq.mapped.bam > ${Basename}_chr.uniq.mapped.bam
 rm ${Basename}_chrXXX.uniq.mapped.bam
    samtools index -@ 18 ${Basename}_chr.uniq.mapped.bam


###
bamCoverage -b ${Basename}_chr.uniq.mapped.bam --normalizeUsing RPKM \
--numberOfProcessors 12 \
--binSize 20 \
--filterRNAstrand forward \
--outFileFormat bedgraph \
-o ${Basename}_RPKM_fw.bedgraph

###
bamCoverage -b ${Basename}_chr.uniq.mapped.bam --normalizeUsing RPKM \
--numberOfProcessors 12 \
--binSize 20 \
--filterRNAstrand reverse \
--outFileFormat bedgraph \
-o ${Basename}_RPKM_rev.bedgraph

awk '{print $1 "\t" $2 "\t" $3 "\t" (0-$4)}' ${Basename}_RPKM_rev.bedgraph > ${Basename}_RPKM_rev2.bedgraph

# merge biodirectional
/apps/well/bedops/2.4.2/sort-bed ${Basename}_RPKM_fw.bedgraph ${Basename}_RPKM_rev2.bedgraph > ${Basename}_FR.bedgraph

sort -k1,1 -k2,2n ${Basename}_FR.bedgraph | /apps/well/tabix/0.2.6/bgzip > output/${Basename}_FR.bedgraph.gz
/apps/well/tabix/0.2.6/tabix -s 1 -b 2 -e 3 output/${Basename}_FR.bedgraph.gz

rm ${Basename}_RPKM_fw.bedgraph
rm ${Basename}_RPKM_rev.bedgraph
rm ${Basename}_RPKM_rev2.bedgraph
rm ${Basename}_FR.bedgraph



# #---------------- alternatively use SAMtools only -----------------# 
# 
# echo "$SAMPLE Forward strand"
# 
# #---------------- Forward strand ----------------#
# # 1. alignments of the second in pair if they map to the forward strand
# # 2. alignments of the first in pair if they map to the reverse  strand
# samtools view -@ 8 -b -f 128 -F 16 ${SAMPLE} > ${SAMPLE}_fwd1.bam
# samtools view -@ 8 -b -f 80 ${SAMPLE} > ${SAMPLE}_fwd2.bam
# 
# # Combine alignments that originate on the forward strand.
# samtools merge -@ 8 -f ${SAMPLE}_fwd.bam ${SAMPLE}_fwd1.bam ${SAMPLE}_fwd2.bam
# samtools index -@ 8 ${SAMPLE}_fwd.bam
# 
# rm ${SAMPLE}_fwd1.bam
# rm ${SAMPLE}_fwd2.bam
# 
# echo "$SAMPLE Reverse strand"
# 
# #---------------- Reverse strand ----------------#
# # 1. alignments of the second in pair if they map to the reverse strand
# # 2. alignments of the first in pair if they map to the forward strand
# samtools view -@ 8 -b -f 144 ${SAMPLE} > ${SAMPLE}_rev1.bam
# samtools view -@ 8 -b -f 64 -F 16 ${SAMPLE} > ${SAMPLE}_rev2.bam
# 
# # Combine alignments that originate on the reverse strand.
# samtools merge -@ 8 -f ${SAMPLE}_rev.bam ${SAMPLE}_rev1.bam ${SAMPLE}_rev2.bam
# samtools index -@ 8 ${SAMPLE}_rev.bam
# 
# rm ${SAMPLE}_rev1.bam
# rm ${SAMPLE}_rev2.bam
# 
# #echo "$SAMPLE bidirectional bedgraph"
# 
# ##---------------- Normalisation (reads per million) & bidirectional bedgraph  ----------------#
# scaleF=`samtools flagstat ${SAMPLE}_fwd.bam |awk 'NR==1{print 1000000/$1}'`
# scaleR=`samtools flagstat ${SAMPLE}_rev.bam |awk 'NR==1{print 1000000/$1}'`
# 
# /apps/well/bedtools/2.27.0/bin/bedtools genomecov -split -scale $scaleF -ibam ${SAMPLE}_fwd.bam -bg |gawk '{print "chr"$0}'|grep -v chrMT|grep -v chrG|sort -k1,1 -k2,2n > ${SAMPLE}_F.bedgraph
# /apps/well/bedtools/2.27.0/bin/bedtools genomecov -split -scale $scaleR -ibam ${SAMPLE}_rev.bam -bg |gawk '{print "chr"$0}'|grep -v chrMT|grep -v chrG|gawk '{print $1 "\t" $2 "\t" $3 "\t" (0-$4)}'|sort -k1,1 -k2,2n > ${SAMPLE}_R.bedgraph
# 
# /apps/well/bedops/2.4.2/sort-bed ${SAMPLE}_F.bedgraph ${SAMPLE}_R.bedgraph > ${SAMPLE}_FR.bedgraph
# 
# sort -k1,1 -k2,2n ${SAMPLE}_FR.bedgraph | /apps/well/tabix/0.2.6/bgzip > ${SAMPLE}_FR.bedgraph.gz
# /apps/well/tabix/0.2.6/tabix -s 1 -b 2 -e 3 ${SAMPLE}_FR.bedgraph.gz


