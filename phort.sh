#!/bin/bash
#
# License
#
# Automatic photo and video file sorter. 
# Copyright (c) 2014 Flexion.Org, http://flexion.org/
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

IFS=$'\n'
VER="1.1"

echo "`basename ${0} .sh` v${VER} - Automatic photo and video file sorter."
echo "Copyright (c) `date +%Y` Flexion.Org, http://flexion.org. MIT License"
echo

logit() {
    echo "${1}" | tee -a "${LOG_FILE}"
}

copyphoto() {
    local SOURCE="${1}"
    local TARGET="${2}"
    
    cp -a "${SOURCE}" "${TARGET}"
    if [ $? -eq 0 ]; then
        logit " - ${SOURCE} -> ${TARGET} success."
    else
        logit " - ${SOURCE} -> ${TARGET} failed."
    fi
}

movephoto() {
    local SOURCE="${1}"
    local TARGET="${2}"
    
    cp -a "${SOURCE}" "${TARGET}"
    if [ $? -eq 0 ]; then
        logit " - ${SOURCE} -> ${TARGET} success."
        rm -f "${SOURCE}"
    else
        logit " - ${SOURCE} -> ${TARGET} failed."
    fi
}

function dedupe() {
    if [ ! -d "${PHORT_DIR}/DUPES" ]; then
        mkdir -p "${PHORT_DIR}/DUPES"
    fi
    
    fdupes -r -f "${PHORT_DIR}" > /tmp/duplicates.txt
    for DUPE in `sort -u /tmp/duplicates.txt | grep -v ".log"`
    do
        if [ -f "${DUPE}" ] && [ ! -f "${PHORT_DIR}/DUPES/`basename ${DUPE}`" ]; then
            movephoto "${DUPE}" "${PHORT_DIR}/DUPES/"
        fi
    done
}

exifsorter() {
    logit "Processing files in `pwd` : "
    for PHOTO in `ls -1 *.{3gp,3gpp,avi,AVI,jpg,JPG,JPEG,M2T,M2TS,MTS,m2t,m2ts,mpg,MPG,mts,m4v,mp4,raw,RAW,tiff,TIFF,ts} 2>/dev/null`
    do
        if [ -f "${PHOTO}" ]; then
            exiftool -CreateDate -DateTimeOriginal -FileType -Make -Model -fast2 "${PHOTO}" > /tmp/exif.txt
            #Create Date                     : 2012:06:17 18:17:44
            #Date/Time Original              : 2012:06:17 18:17:44
            #File Type                       : JPEG
            #Make                            : HTC
            #Camera Model Name               : HTC Desire
            
            local CREATE_DATE=`grep "Date/Time Original" /tmp/exif.txt | cut -d':' -f2- | sed 's/ //'`
            #If 'Date/Time Original' was not available fall back to 'Create Date'
            if [ -z "${CREATE_DATE}" ]; then
                local CREATE_DATE=`grep "Create Date" /tmp/exif.txt | cut -d':' -f2- | sed 's/ //'`
            fi

            local TEST_YEAR=`echo "${CREATE_DATE}" | cut -c1-4`
            if [ "${TEST_YEAR}" == "1904" ] || [ "${TEST_YEAR}" == "1970" ]; then
                local CREATE_DATE=`grep "Create Date" /tmp/exif.txt | cut -d':' -f2- | sed 's/ //'`
            fi

            local MAKE=`grep "Make" /tmp/exif.txt | cut -d':' -f2- | sed -e 's/ //' -e 's/ /-/g' -e's/[,.]//g'`
            if [ -z "${MAKE}" ]; then
                local MAKE="Unknown"
            fi

            local MODEL=`grep "Camera Model Name" /tmp/exif.txt | cut -d':' -f2- | sed -e 's/ //' -e 's/ /-/g'`
            if [ -z "${MODEL}" ]; then
                local MODEL="Camera"
            fi

            local FILE_TYPE=`grep "File Type" /tmp/exif.txt | cut -d':' -f2- | sed 's/ //' | tr '[:upper:]' '[:lower:]'`
            if [ -z "${FILE_TYPE}" ]; then
                local FILE_TYPE="${PHOTO##*.}"
            fi

            if [ "${FILE_TYPE}" == "jpeg" ] || [ "${FILE_TYPE}" == "jpg" ] ||
               [ "${FILE_TYPE}" == "tiff" ] || [ "${FILE_TYPE}" == "tif" ] ||
               [ "${FILE_TYPE}" == "raw" ]; then
                local CATEGORY="Photo"
            else
                local CATEGORY="Video"
            fi

            local YEAR=`echo "${CREATE_DATE}" | cut -c1-4`
            local MONTH=`echo "${CREATE_DATE}" | cut -c6-7`
            local DAY=`echo "${CREATE_DATE}" | cut -c9-10`
            local HH=`echo "${CREATE_DATE}" | cut -c12-13`
            local MM=`echo "${CREATE_DATE}" | cut -c15-16`
            local SS=`echo "${CREATE_DATE}" | cut -c18-19`
            
            if [ -n "${YEAR}${MONTH}${DAY}${HH}${MM}${SS}" ]; then
                # Correct bogus year
                #  - http://redmine.yorba.org/issues/3314
                # The problem in AOSP is they're reporting videos dated 1945
                # in 2011. That's off by 66 years, which is the difference
                # between 1970 (unix) and 1904 (quicktime).
                if [ ${YEAR} -le 1970 ]; then
                    local YEAR=$(( ${YEAR} + 66 ))
                fi
                local NEW_DIRECTORY="${PHORT_DIR}/${CATEGORY}/${YEAR}/${MONTH}"
                local NEW_FILENAME="${YEAR}-${MONTH}-${DAY}-${HH}${MM}${SS}-${MAKE}-${MODEL}.${FILE_TYPE}"
            else
                local NEW_DIRECTORY="${PHORT_DIR}/${CATEGORY}/NOEXIF"
                local NEW_FILENAME="${MAKE}-${MODEL}.${FILE_TYPE}"
            fi

            if [ ! -d "${NEW_DIRECTORY}" ]; then
                mkdir -p "${NEW_DIRECTORY}"
                if [ $? -ne 0 ]; then
                    logit "ERROR! Failed to make directory : ${NEW_DIRECTORY}"
                    exit 1
                fi
            fi

            if [ -f "${NEW_DIRECTORY}/${NEW_FILENAME}" ]; then
                # Compare source and target photos
                cmp --quiet "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                if [ $? -eq 0 ]; then
                    logit " - ${PHOTO} -> ${NEW_DIRECTORY}/${NEW_FILENAME} already imported."
                    if [ "${SORT_MODE}" == "move" ]; then
                        rm "${PHOTO}"
                    fi
                else
                    # Handle file name conflicts.
                    local INCREMENT=0
                    local KEEP_CHECKING=1
                    while [ ${KEEP_CHECKING} -eq 1 ]
                    do
                        local INCREMENT=$(( ${INCREMENT} + 1 ))
                        if [ -n "${YEAR}${MONTH}${DAY}${HH}${MM}${SS}" ]; then
                            local NEW_FILENAME="${YEAR}-${MONTH}-${DAY}-${HH}${MM}${SS}-${MAKE}-${MODEL}-${INCREMENT}.${FILE_TYPE}"
                        else
                            local NEW_FILENAME="${MAKE}-${MODEL}-${INCREMENT}.${FILE_TYPE}"
                        fi

                        if [ -f "${NEW_DIRECTORY}/${NEW_FILENAME}" ]; then
                            # Compare the source with the incremented filename to ensure this photo hasn't already been imported.
                            cmp --quiet "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                            if [ $? -eq 0 ]; then
                                logit " - ${PHOTO} -> ${NEW_DIRECTORY}/${NEW_FILENAME} already imported."
                                if [ "${SORT_MODE}" == "move" ]; then
                                    rm "${PHOTO}"
                                fi
                                local KEEP_CHECKING=0
                            fi
                        else
                            # Photo has not previously been imported, so import it.
                            if [ "${SORT_MODE}" == "copy" ]; then
                                copyphoto "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                            else
                                movephoto "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                            fi
                            local KEEP_CHECKING=0
                        fi
                    done
                fi
            else
                # Photo has not previously been imported, so import it.
                if [ "${SORT_MODE}" == "copy" ]; then
                    copyphoto "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                else
                    movephoto "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                fi
            fi
        fi
    done
}

recurse() {
    cd "${1}"

    # Are we in a directory that contains photos?
    TEST=`ls -1 2>/dev/null`
    if [ $? -eq 0 ]; then
        exifsorter
    fi

    for dir in *
    do
        if [ -d "${dir}" ]; then
            ( recurse "${dir}" )
        fi;
    done
}

usage() {
    echo
    echo "Usage"
    echo "  ${0} -i input_directory -o output_directory [-h]"
    echo ""
    echo "  -i : The directory containing photos you want to organise."
    echo "  -o : The directory the organised photos should be copied to."
    echo "  -m : Move photos to the output_directory, rather than copy. Default: copy."
    echo "  -h : This help."
    echo
    exit 1
}

# Define the commands we will be using. If you don't have them, get them! ;-)
REQUIRED_TOOLS=`cat << EOF
ls
cut
exiftool
fdupes
pwd
sed
tr
EOF`

for REQUIRED_TOOL in ${REQUIRED_TOOLS}
do
    # Is the required tool in the path?
    which ${REQUIRED_TOOL} >/dev/null

    if [ $? -eq 1 ]; then
        echo "ERROR! \"${REQUIRED_TOOL}\" is missing. ${0} requires it to operate."
        echo "       Please install \"${REQUIRED_TOOL}\"."
        exit 1
    fi
done

PHOTO_DIR=""
PHORT_DIR=""
SORT_MODE="copy"

OPTSTRING=hi:mo:
while getopts ${OPTSTRING} OPT
do
    case ${OPT} in
        h) usage;;
        i) PHOTO_DIR="${OPTARG}";;
        m) SORT_MODE="move";;
        o) PHORT_DIR="${OPTARG}";;
        *) usage;;
    esac
done
shift "$(( $OPTIND - 1 ))"

if [ -z "${PHOTO_DIR}" ] || [ -z "${PHORT_DIR}" ]; then
    echo "ERROR! You must supply both the input and output directories."
    usage
fi

if [ ! -d ${PHOTO_DIR} ]; then
    echo "ERROR! The input directory '${PHOTO_DIR}' was not found."
    usage
fi

LOG_FILE="${PHORT_DIR}/`basename ${0} .sh`-`date +%y%m%d-%H%M%S`.log"
mkdir -p "${PHORT_DIR}"
if [ $? -ne 0 ]; then
    logit "ERROR! Failed to make directory : ${PHORT_DIR}"
    exit 1
fi
touch "${LOG_FILE}"

recurse "${PHOTO_DIR}"
dedupe

echo "All Done!"
