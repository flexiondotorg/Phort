#!/bin/bash
#
# License
#
# Automatic photo and video file sorter. 
# Copyright (c) 2013 Flexion.Org, http://flexion.org/
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
VER="1.0"
PHORT_DIR="/media/active/Phort"
PHORT_DIR="${HOME}/Phort"
LOG_FILE="${PHORT_DIR}/`basename ${0} .sh`-`date +%y%m%d-%H%M%S`.log"

echo "`basename ${0} .sh` v${VER} - Automatic photo and video file sorter."
echo "Copyright (c) `date +%Y` Flexion.Org, http://flexion.org. MIT License"
echo

logit() {
    echo "${1}" | tee -a "${LOG_FILE}"
}

exifsorter() {
    echo "Processing files in `pwd` : "
    for TYPE in 3gp jpg JPG m4v mp4
    do
        for PHOTO in *.${TYPE}
        do
            if [ -f "${PHOTO}" ]; then
                exiftool -CreateDate -DateTimeOriginal -FileType -Make -Model -fast2 "${PHOTO}" > /tmp/exif.txt
                #Create Date                     : 2012:06:17 18:17:44
                #Date/Time Original              : 2012:06:17 18:17:44
                #File Type                       : JPEG
                #Make                            : HTC
                #Camera Model Name               : HTC Desire
                
                local CREATE_DATE=`grep "Date/Time Original" /tmp/exif.txt | cut -d':' -f2- | sed 's/ //'`

                #If DateTimeOriginal was not available fall back to 'Create Date'
                if [ -z "${CREATE_DATE}" ]; then
                    local CREATE_DATE=`grep "Create Date" /tmp/exif.txt | cut -d':' -f2- | sed 's/ //'`
                fi

                local MODEL=`grep "Camera Model Name" /tmp/exif.txt | cut -d':' -f2- | sed -e 's/ //' -e 's/ /-/g'`
                if [ -z "${MODEL}" ]; then
                    local MODEL="Device"
                fi

                local MAKE=`grep "Make" /tmp/exif.txt | cut -d':' -f2- | sed -e 's/ //' -e 's/ /-/g' -e's/[,.]//g'`
                if [ -z "${MAKE}" ]; then
                    local MAKE="Unknown"
                fi

                local FILE_TYPE=`grep "File Type" /tmp/exif.txt | cut -d':' -f2- | sed 's/ //' | tr '[:upper:]' '[:lower:]'`
                if [ -z "${FILE_TYPE}" ]; then
                    local FILE_TYPE="${PHOTO##*.}"
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
                    # The problem in AOSP is they're all reporting videos dated 1945
                    # in 2011. That's off by 66 years, which is the difference
                    # between 1970 (unix) and 1904 (quicktime).
                    if [ ${YEAR} -le 1970 ]; then
                        local YEAR=$((  ${YEAR} + 66 ))
                    fi
                    local NEW_DIRECTORY="${PHORT_DIR}/${YEAR}/${MONTH}"
                    local NEW_FILENAME="${YEAR}-${MONTH}-${DAY}-${HH}-${MM}-${SS}-${MAKE}-${MODEL}.${FILE_TYPE}"
                else
                    local NEW_DIRECTORY="${PHORT_DIR}/NOEXIF"
                    local NEW_FILENAME="${MAKE}-${MODEL}.${FILE_TYPE}"
                fi

                if [ ! -d "${NEW_DIRECTORY}" ]; then
                    mkdir -p "${NEW_DIRECTORY}"
                fi

                if [ -f "${NEW_DIRECTORY}/${NEW_FILENAME}" ]; then
                    # Compare source and target photos
                    cmp --quiet "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                    if [ $? -eq 0 ]; then
                        echo "‘${PHOTO}’ -> ‘${NEW_DIRECTORY}/${NEW_FILENAME}’ already imported."
                    else
                        # Handle file name conflicts.
                        local INCREMENT=0
                        local KEEP_CHECKING=1
                        while [ ${KEEP_CHECKING} -eq 1 ]
                        do
                            local INCREMENT=$(( ${INCREMENT} + 1 ))
                            if [ -n "${YEAR}${MONTH}${DAY}${HH}${MM}${SS}" ]; then
                                local NEW_FILENAME="${YEAR}-${MONTH}-${DAY}-${HH}-${MM}-${SS}-${MAKE}-${MODEL}-${INCREMENT}.${FILE_TYPE}"
                            else
                                local NEW_FILENAME="${MAKE}-${MODEL}-${INCREMENT}.${FILE_TYPE}"
                            fi

                            if [ -f "${NEW_DIRECTORY}/${NEW_FILENAME}" ]; then
                                # Compare the source with the incremented filename to ensure this photo hasn't already been imported.
                                cmp --quiet "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                                if [ $? -eq 0 ]; then
                                    echo "‘${PHOTO}’ -> ‘${NEW_DIRECTORY}/${NEW_FILENAME}’ already imported."
                                    local KEEP_CHECKING=0
                                fi
                            else
                                # Photo has not previously been imported, so import it.
                                cp -v "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                                local KEEP_CHECKING=0
                            fi
                        done
                    fi
                else
                    # Photo has not previously been imported, so import it.
                    cp -v "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
                fi
            fi
        done
    done
}

recurse() {
    cd "${1}"

    # Are we in a directory that contains MP3s?
    TEST=`ls -1 *.jpg 2>/dev/null`
    if [ "$?" = "0" ]; then
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
    echo "  ${0} photodirectory [--help]"
    echo ""
    echo "  --help  : This help."
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

# Get the first parameter passed in and validate it.
if [ $# -ne 1 ]; then
    echo "ERROR! ${0} requires a photo directory as input"
    usage
fi

if [ "${1}" == "-h" ] || [ "${1}" == "--h" ] || [ "${1}" == "-help" ] || [ "${1}" == "--help" ] || [ "${1}" == "-?" ]; then
    usage
else
    PHOTO_DIR="${1}"
    if [ ! -d ${PHOTO_DIR} ]; then
        echo "ERROR! ${PHOTO_DIR} was not found."
        usage
    fi
fi

recurse "${PHOTO_DIR}"
if [ ! -d "${PHORT_DIR}/DUPES" ]; then
    mkdir -p "${PHORT_DIR}/DUPES"
fi
fdupes -r -f -1 "${PHORT_DIR}" > "${PHORT_DIR}/DUPES/duplicates.txt"
cat "${PHORT_DIR}/duplicates.txt" | xargs -i cp --parents {} "${PHORT_DIR}/DUPES"
#cat "${PHORT_DIR}/duplicates.txt" | xargs rm
echo "All Done!"
