#!/usr/bin/env bash

# Building an audio-only FFmpeg for Android.
#
# This script is a sibling of ffmpeg-android-maker.sh, not a replacement for
# it. The default script builds a vanilla FFmpeg with every component that
# FFmpeg has, which is mostly video. This one drops everything video related
# and produces much smaller *.so files that still support every audio codec
# and container FFmpeg natively implements.
#
# Because the video encoders are gone, nothing here needs a GPL licensed
# library, so the result can be linked into a closed source application.
# The only external libraries that make sense are the LGPL ones, and all of
# them are optional:
#
#   -lame      MP3 encoding (FFmpeg has no native MP3 encoder)
#   -twolame   MP2 encoding
#   -speex     Speex encoding
#   -opus      Opus encoding
#   -mbedtls   HTTPS/TLS, only when --enable-network is used as well
#
# Any other library that the default script understands is rejected, because
# it is either a video library or a GPL one.
#
# The build is placed into build-audio and output-audio, so the results of
# the default script are never overwritten.
#
# Usage examples:
#   ./ffmpeg-android-maker-only-audio.sh -abis=arm64-v8a
#   ./ffmpeg-android-maker-only-audio.sh -lame -twolame -abis=arm64-v8a
#   ./ffmpeg-android-maker-only-audio.sh -lame --enable-network -mbedtls

# Defining essential directories

# The root of the project
export BASE_DIR="$( cd "$( dirname "$0" )" && pwd )"
# Directory that contains source code for FFmpeg and its dependencies
export SOURCES_DIR=${BASE_DIR}/sources
# Directory to place some statistics about the build.
# Currently - the info about Text Relocations
export STATS_DIR=${BASE_DIR}/stats-audio
# Directory that contains helper scripts and
# scripts to download and build FFmpeg and each dependency separated by subdirectories
export SCRIPTS_DIR=${BASE_DIR}/scripts
# The directory to use by Android project
# All FFmpeg's libraries and headers are copied there
export OUTPUT_DIR=${BASE_DIR}/output-audio

# Check the host machine for proper setup and fail fast otherwise
${SCRIPTS_DIR}/check-host-machine.sh || exit 1

# Directory to use as a place to build/install FFmpeg and its dependencies
BUILD_DIR=${BASE_DIR}/build-audio
# Separate directory to build FFmpeg to
export BUILD_DIR_FFMPEG=$BUILD_DIR/ffmpeg
# All external libraries are installed to a single root
# to make easier referencing them when FFmpeg is being built.
export BUILD_DIR_EXTERNAL=$BUILD_DIR/external

# Function that copies *.so files and headers of the current ANDROID_ABI
# to the proper place inside OUTPUT_DIR
function prepareOutput() {
  OUTPUT_LIB=${OUTPUT_DIR}/lib/${ANDROID_ABI}
  mkdir -p ${OUTPUT_LIB}
  cp ${BUILD_DIR_FFMPEG}/${ANDROID_ABI}/lib/*.so ${OUTPUT_LIB}

  OUTPUT_HEADERS=${OUTPUT_DIR}/include/${ANDROID_ABI}
  mkdir -p ${OUTPUT_HEADERS}
  cp -r ${BUILD_DIR_FFMPEG}/${ANDROID_ABI}/include/* ${OUTPUT_HEADERS}
}

# Saving stats about text relocation presence.
# If the result file doesn't have 'TEXTREL' at all, then we are good.
# Otherwise the whole script is interrupted
function checkTextRelocations() {
  TEXT_REL_STATS_FILE=${STATS_DIR}/text-relocations.txt
  ${FAM_READELF} --dynamic ${BUILD_DIR_FFMPEG}/${ANDROID_ABI}/lib/*.so | grep 'TEXTREL\|File' >> ${TEXT_REL_STATS_FILE}

  if grep -q TEXTREL ${TEXT_REL_STATS_FILE}; then
    echo "There are text relocations in output files:"
    cat ${TEXT_REL_STATS_FILE}
    exit 1
  fi
}

# The external libraries that are able to encode or decode audio.
# Everything else that the default script supports is dropped, because
# either it is a video library or it is GPL licensed.
AUDIO_ONLY_LIBRARIES=("libmp3lame" "libopus" "libspeex" "libtwolame" "mbedtls")

# Arguments that are specific to this script and are not understood by
# the shared scripts/parse-arguments.sh
export FFMPEG_AUDIO_ENABLE_NETWORK=false
SCRIPT_SPECIFIC_ARGUMENTS=()
SCRIPT_ARGUMENTS=()

for ARGUMENT in "$@"
do
  case ${ARGUMENT} in
    --enable-network | -network)
      FFMPEG_AUDIO_ENABLE_NETWORK=true
      SCRIPT_SPECIFIC_ARGUMENTS+=(${ARGUMENT})
      ;;
    *)
      SCRIPT_ARGUMENTS+=(${ARGUMENT})
      ;;
  esac
done

# Actual work of the script

# Clearing previously created binaries
rm -rf ${BUILD_DIR}
rm -rf ${STATS_DIR}
rm -rf ${OUTPUT_DIR}
mkdir -p ${STATS_DIR}
mkdir -p ${OUTPUT_DIR}

# Exporting more necessary variabls
source ${SCRIPTS_DIR}/export-host-variables.sh
source ${SCRIPTS_DIR}/parse-arguments.sh "${SCRIPT_ARGUMENTS[@]}"

# Dropping the libraries that do not belong to an audio-only build.
# FFMPEG_GPL_ENABLED is cleared as well, because no GPL library survives
# the check below and an unnecessary --enable-gpl would only restrict
# the license of the result.
if [ ${#EXTERNAL_LIBRARIES[@]} -gt 0 ]
then
  AUDIO_EXTERNAL_LIBRARIES=()
  for LIBRARY_NAME in "${EXTERNAL_LIBRARIES[@]}"
  do
    IS_AUDIO_LIBRARY=false
    for AUDIO_LIBRARY_NAME in "${AUDIO_ONLY_LIBRARIES[@]}"
    do
      [ "${LIBRARY_NAME}" = "${AUDIO_LIBRARY_NAME}" ] && IS_AUDIO_LIBRARY=true
    done
    if [ "${IS_AUDIO_LIBRARY}" = true ]
    then
      AUDIO_EXTERNAL_LIBRARIES+=("${LIBRARY_NAME}")
    else
      echo "Ignoring ${LIBRARY_NAME}, it is not used by an audio-only build"
    fi
  done
  EXTERNAL_LIBRARIES=("${AUDIO_EXTERNAL_LIBRARIES[@]}")
  FFMPEG_EXTERNAL_LIBRARIES=${EXTERNAL_LIBRARIES[@]}
  FFMPEG_GPL_ENABLED=false
fi

# Treating FFmpeg as just a module to build after its dependencies.
# The ffmpegaudio component is the audio-only version of the ffmpeg one,
# it uses the same sources but a different build.sh
COMPONENTS_TO_BUILD=${EXTERNAL_LIBRARIES[@]}
COMPONENTS_TO_BUILD+=( "ffmpegaudio" )

# Get the source code of component to build
for COMPONENT in ${COMPONENTS_TO_BUILD[@]}
do
  echo "Getting source code of the component: ${COMPONENT}"
  SOURCE_DIR_FOR_COMPONENT=${SOURCES_DIR}/${COMPONENT}

  mkdir -p ${SOURCE_DIR_FOR_COMPONENT}
  cd ${SOURCE_DIR_FOR_COMPONENT}

  # Executing the component-specific script for downloading the source code
  source ${SCRIPTS_DIR}/${COMPONENT}/download.sh

  # The download.sh script has to export SOURCES_DIR_$COMPONENT variable
  # with actual path of the source code. This is done for possiblity to switch
  # between different verions of a component.
  # If it isn't set, consider SOURCE_DIR_FOR_COMPONENT as the proper value
  COMPONENT_SOURCES_DIR_VARIABLE=SOURCES_DIR_${COMPONENT}
  if [[ -z "${!COMPONENT_SOURCES_DIR_VARIABLE}" ]]; then
     export SOURCES_DIR_${COMPONENT}=${SOURCE_DIR_FOR_COMPONENT}
  fi

  # Returning to the rood directory. Just in case.
  cd ${BASE_DIR}
done

# Main build loop
for ABI in ${FFMPEG_ABIS_TO_BUILD[@]}
do
  # Exporting variables for the current ABI
  source ${SCRIPTS_DIR}/export-build-variables.sh ${ABI}

  for COMPONENT in ${COMPONENTS_TO_BUILD[@]}
  do
    echo "Building the component: ${COMPONENT}"
    COMPONENT_SOURCES_DIR_VARIABLE=SOURCES_DIR_${COMPONENT}

    # Going to the actual source code directory of the current component
    cd ${!COMPONENT_SOURCES_DIR_VARIABLE}

    # and executing the component-specific build script
    source ${SCRIPTS_DIR}/${COMPONENT}/build.sh || exit 1

    # Returning to the root directory. Just in case.
    cd ${BASE_DIR}
  done

  checkTextRelocations || exit 1

  prepareOutput
done

echo "The audio-only build is ready in ${OUTPUT_DIR}"
