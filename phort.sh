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

echo "phort v${VER} - Automatic photo and video file sorter."
echo "Copyright (c) 2013 Flexion.Org, http://flexion.org. MIT License"
echo

exifsorter() {
    echo "Processing files in `pwd` : "
    for TYPE in 3gp jpg JPG m4v mp4
    do
        for PHOTO in *.${TYPE}
        do
            if [ -f "${PHOTO}" ]; then
                local CREATE_DATE=`exiftool -DateTimeOriginal -fast2 "${PHOTO}" | cut -d':' -f2- | sed 's/ //g'`

                #If DateTimeOriginal was not available fall back to CreateDate
                if [ -z "${CREATE_DATE}" ]; then
                    local CREATE_DATE=`exiftool -CreateDate -fast2 "${PHOTO}" | cut -d':' -f2- | sed 's/ //g'`
                fi

                # Only query the other tags if CreateDate was found.
                local MODEL=`exiftool -Model -fast2 "${PHOTO}" | cut -d':' -f2- | sed 's/ //g'`
                if [ -z "${MODEL}" ]; then
                    local MODEL="Unknown"
		fi

                local FILE_TYPE=`exiftool -FileType -fast2 "${PHOTO}" | cut -d':' -f2- | sed 's/ //g' | tr '[:upper:]' '[:lower:]'`
                if [ -z "${FILE_TYPE}" ]; then
                    local FILE_TYPE="${PHOTO##*.}"
                fi

                local YEAR=`echo "${CREATE_DATE}" | cut -c1-4`
                # Correct bogus year
                #  - http://redmine.yorba.org/issues/3314
                # The problem in AOSP is they're all reporting videos dated 1945
                # in 2011. That's off by 66 years, which is the difference
                # between 1970 (unix) and 1904 (quicktime).
                if [ ${YEAR} -le 1970 ]; then
                    local YEAR=$((${YEAR} + 66))
                fi

                local MONTH=`echo "${CREATE_DATE}" | cut -c6-7`
                local DAY=`echo "${CREATE_DATE}" | cut -c9-10`
                local HH=`echo "${CREATE_DATE}" | cut -c11-12`
                local MM=`echo "${CREATE_DATE}" | cut -c14-15`
                local SS=`echo "${CREATE_DATE}" | cut -c17-18`

                if [ -n "${YEAR}${MONTH}${DAY}${HH}${MM}${SS}" ]; then
                    local NEW_DIRECTORY="${HOME}/Phort/${YEAR}/${MONTH}"
                    local NEW_FILENAME="${YEAR}-${MONTH}-${DAY}-${HH}-${MM}-${SS}-${MODEL}.${FILE_TYPE}"
                else
                    local NEW_DIRECTORY="${HOME}/Phort/NOEXIF/"
                    local NEW_FILENAME="${MODEL}.${FILE_TYPE}"
                fi

                if [ ! -d "${NEW_DIRECTORY}" ]; then
                    mkdir -p "${NEW_DIRECTORY}"
                fi

                # Handle file name conflicts.
                local INCREMENT=0
                while [ -f "${NEW_DIRECTORY}/${NEW_FILENAME}" ]
                do
                    local INCREMENT=$(( ${INCREMENT} + 1 ))
                    if [ -n "${YEAR}${MONTH}${DAY}${HH}${MM}${SS}" ]; then
                        local NEW_FILENAME="${YEAR}-${MONTH}-${DAY}-${HH}-${MM}-${SS}-${MODEL}-${INCREMENT}.${FILE_TYPE}"
                    else
                        local NEW_FILENAME="${MODEL}-${INCREMENT}.${FILE_TYPE}"
                    fi
                done
                cp -v "${PHOTO}" "${NEW_DIRECTORY}/${NEW_FILENAME}"
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
echo
ls
exiftool
pwd
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
echo "All Done!"
