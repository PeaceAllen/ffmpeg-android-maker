#!/usr/bin/env bash

# Script that provides the source code for the audio-only build of FFmpeg.
#
# The very same FFmpeg sources are used by the default build, so the whole
# download procedure is delegated to scripts/ffmpeg/download.sh and the
# already extracted directory is reused instead of being downloaded twice.
#
# Exports SOURCES_DIR_ffmpegaudio - path where actual sources are stored

# download.sh is executed from the directory that belongs to the component,
# switching to the directory of the default 'ffmpeg' component by hand
cd ${SOURCES_DIR}/ffmpeg || exit 1

source ${SCRIPTS_DIR}/ffmpeg/download.sh || exit 1

# The generic download script exports SOURCES_DIR_ffmpeg for every source
# origin, so the audio-only component just points to the same location
export SOURCES_DIR_ffmpegaudio=${SOURCES_DIR_ffmpeg}
