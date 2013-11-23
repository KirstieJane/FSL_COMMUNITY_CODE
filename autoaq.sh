#!/bin/bash

# Print usage if no argument is given
if [ -z "$1" ]; then
cat <<EOU
Generate a report from the results of FSL's randomise showing the
structures to which they belong, using the names from a given atlas.
In other words automatically make an atlas query.

Usage:
autoaq -i <input image> -a "<atlas name>" -t <threshold> -o <output.txt>

Note that temporary files will be written to the current directory
(i.e. the directory from where this command is called). Therefore,
execute it from a directory which you have permissions to write to.

_____________________________________
Anderson Winkler & Margaret Brumbaugh
Institute of Living / Yale University
Mar/2011
http://brainder.org
EOU
exit
fi

IN=""
ATLAS=""
OUT=""

# Check and accept the arguments
while getopts 'i:a:t:o:' OPTION
do
  case ${OPTION} in
    i) IN=${OPTARG} ;;
    a) ATLAS="${OPTARG}" ;;
    t) THR=${OPTARG} ;;
    o) OUT=${OPTARG} ;;
  esac
done

# Prepare a random string to save temporary files
md5cmd=$(which md5sum)
if [ "${md5cmd}" == "" ] ; then
   md5cmd=$(which md5)
fi
if [ "${md5cmd}" == "" ] ; then
   RNDSTR=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
else
   RNDSTR0=$(cat /dev/urandom | head -n 10 | ${md5cmd})
   RNDSTR=${RNDSTR0:0:8}
fi

# Define a function for Ctrl+C as soon as the RNDSTR is defined
function bashtrap {
   break
   rm -rf tmp_${RNDSTR}*
   exit 1
} # end bashtrap
trap bashtrap INT

# Get cluster stats
${FSLDIR}/bin/cluster --in=${IN} --thresh=${THR} --mm --oindex=tmp_${RNDSTR} > ${OUT}

# Put a separator for clarity
cat <<EOS >> ${OUT}
==========================================
Structures to which each cluster peak belongs to:
EOS

# Produce names for the peaks
if [ $(cat ${OUT} | wc -l) -gt 1 ] ; then

   # Number of clusters
   NC=$(head -n 2 ${OUT} | tail -n 1 | awk '{ print $1 }')
   head -n $(echo ${NC} 1 + p |dc) ${OUT} > tmp_${RNDSTR}.txt

   for (( r=1 ; r<=${NC} ; r++ )) ; do
      X=$(awk "NR==${r}+1 {print \$7}" tmp_${RNDSTR}.txt)
      Y=$(awk "NR==${r}+1 {print \$8}" tmp_${RNDSTR}.txt)
      Z=$(awk "NR==${r}+1 {print \$9}" tmp_${RNDSTR}.txt)
      echo -n "${X},${Y},${Z}," >> ${OUT}
      ${FSLDIR}/bin/atlasquery -a "${ATLAS}" -c ${X},${Y},${Z} | sed 's/<b>//g' | sed 's/<\/b><br>/\,/g' >> ${OUT}
   done

   # Cleanup
   rm tmp_${RNDSTR}.txt
fi

# Count again the number of clusters, for sanity check
NC2=$(${FSLDIR}/bin/fslstats tmp_${RNDSTR} -R | awk '{ print $2 }' | awk -F. '{ print $1 }')
if [ ${NC} != ${NC2} ] ; then
   # This line should never be printed...
   echo "Warning: The number of clusters in the report table isn't the same as in the image."
fi

# Put a separator for clarity
cat <<EOS >> ${OUT}
==========================================
Structures to which each cluster belongs to:
EOS

# Split the clusters into independent images and query the atlas
for (( c=${NC} ; c>=1 ; c-=1 )) ; do

   # Suffix string
   cstr=$(printf %04d ${c})

   # Split!
   ${FSLDIR}/bin/fslmaths tmp_${RNDSTR} -thr ${c} -uthr ${c} -bin tmp_${RNDSTR}_${cstr}

   # Get the structure names and output to the report file
   echo "" >> ${OUT}
   echo "Cluster #${c}" >> ${OUT}
   ${FSLDIR}/bin/atlasquery -a "${ATLAS}" -m tmp_${RNDSTR}_${cstr} >> ${OUT}

   # Cleanup
   ${FSLDIR}/bin/imrm tmp_${RNDSTR}_${cstr}
done

# More cleanup
${FSLDIR}/bin/imrm tmp_${RNDSTR}*

exit 0
