#!/bin/bash
#
# TWRP compilation script
#
# Copyright (C) 2016 Nathan Chancellor
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


# Prints a formatted header; used for outlining what the script is doing to the user
function echoText() {
   RED="\033[01;31m"
   RST="\033[0m"

   echo -e ${RED}
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e "==  ${1}  =="
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e ${RST}
}


# Creates a new line
function newLine() {
   echo -e ""
}


# Compiliation function
function compile() {
   # Parameters
   DEVICE=${1}

   # Flags
   SUCCESS=false

   # Directories
   SOURCE_DIR=${HOME}/TWRP
   OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}
   ZIP_MOVE=${HOME}/Web/.hidden/TWRP


   # File names
   COMP_FILE=recovery.img
   UPLD_FILE=twrp-${DEVICE}-$( TZ=MST date +%m%d%Y ).img
   FILE_FORMAT=twrp-${DEVICE}*


   # Export Java 8
   export EXPERIMENTAL_USE_JAVA8=true


   # Clear the terminal
   clear


   # Start tracking time
   echoText "SCRIPT STARTING AT $( TZ=MST date +%D\ %r )"

   START=$( TZ=MST date +%s )


   # Change to the source directory
   echoText "MOVING TO SOURCE DIRECTORY"

   cd ${SOURCE_DIR}


   # Start syncing the latest sources
   echoText "SYNCING LATEST SOURCES"; newLine

   repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)


   # Setup the build environment
   echoText "SETTING UP BUILD ENVIRONMENT"; newLine

   . build/envsetup.sh


   # Prepare device
   newLine; echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"

   lunch omni_${DEVICE}-eng


   # Clean up
   echoText "CLEANING UP OUT DIRECTORY"; newLine

   mka clobber


   # Start building
   newLine; echoText "MAKING TWRP"; newLine
   NOW=$( TZ=MST date +"%Y-%m-%d-%S" )
   time mka recoveryimage 2>&1 | tee ${LOGDIR}/Compilation/twrp_${DEVICE}-${NOW}.log


   # If the compilation was successful, there will be a file in the format above in the out directory
   if [[ $( ls ${OUT_DIR}/${COMP_FILE} 2>/dev/null | wc -l ) != "0" ]]; then
      # Make the build result string show success
      BUILD_RESULT_STRING="BUILD SUCCESSFUL"
      SUCCESS=true



      # If the upload directory doesn't exist, make it; otherwise, remove existing files in ZIP_MOVE
      if [[ ! -d "${ZIP_MOVE}" ]]; then
         newLine; echoText "MAKING UPLOAD DIRECTORY"

         mkdir -p "${ZIP_MOVE}"
      else
         newLine; echoText "CLEANING UPLOAD DIRECTORY"; newLine

         rm -vrf "${ZIP_MOVE}"/*${FILE_FORMAT}*
      fi


      # Copy new files to ZIP_MOVE
      newLine; echoText "MOVING FILE TO UPLOAD DIRECTORY"; newLine

      mv -v ${OUT_DIR}/${COMP_FILE} "${ZIP_MOVE}"/${UPLD_FILE}


      # Upload the files
      # newLine; echoText "UPLOADING FILE"; newLine



      # Clean up out directory to free up space
      newLine; echoText "CLEANING UP OUT DIRECTORY"; newLine

      mka clobber


      # Go back home
      newLine; echoText "GOING HOME"

      cd ${HOME}

   # If the build failed, add a variable
   else
      BUILD_RESULT_STRING="BUILD FAILED"
      SUCCESS=false
   fi



   # Stop tracking time
   END=$( TZ=MST date +%s )
   newLine; echoText "${BUILD_RESULT_STRING}!"

   # Print the image location and its size if the script was successful
   if [[ ${SUCCESS} = true ]]; then
      echo -e ${RED}"IMAGE: $( ls "${ZIP_MOVE}"/${UPLD_FILE} )"
      echo -e "SIZE: $( du -h "${ZIP_MOVE}"/${UPLD_FILE} | awk '{print $1}' )"${RST}
   fi
   # Print the time the script finished and how long the script ran for regardless of success
   echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
   echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RST}; newLine



   # Add line to compilation log
   echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${DEVICE}" >> ${LOG}
   echo -e "${BUILD_RESULT_STRING} IN $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )" >> ${LOG}
   if [[ ${SUCCESS} = true ]]; then
      echo -e "FILE LOCATION: $( ls "${ZIP_MOVE}"/${UPLD_FILE} )" >> ${LOG}
   fi
   echo -e "\a"
}


# If the first parameter to the twrp.sh script is "all", we are running five builds for the devices we support; otherwise, it is just a device specific build
if [[ "${1}" == "all" ]]; then
   DEVICES="angler shamu bullhead hammerhead mako"

   for DEVICE in ${DEVICES}; do
      compile ${DEVICE}
   done

   cd ${HOME}
   cat ${LOG}
else
   compile ${1}
fi
