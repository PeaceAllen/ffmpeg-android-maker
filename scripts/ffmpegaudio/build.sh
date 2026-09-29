#!/usr/bin/env bash

# Building an audio-only FFmpeg.
#
# The default build (scripts/ffmpeg/build.sh) keeps every FFmpeg component
# enabled, which is convenient but produces a *.so where the vast majority of
# the code is video related. This script does the opposite - it passes
# --disable-everything to the configure and then switches the audio
# components back, one by one.
#
# The lists below are the single source of truth about the content of an
# audio-only build. Adding a name to one of them is the only thing that is
# required to make that component available.

case $ANDROID_ABI in
  x86)
    # Disabling assembler optimizations, because they have text relocations
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --disable-asm"
    ;;
  x86_64)
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --x86asmexe=${NASM_EXECUTABLE}"
    ;;
esac

# Audio decoders that are implemented by FFmpeg itself.
# Decoders that need an external library are not listed here,
# see externalEncodersOf below.
# Mind that FFmpeg 8 names the G.7xx codecs adpcm_g7xx, not g7xx
# GPL licensed decoders are not here either, because --enable-gpl is never
# passed and they would be dropped with a warning. Those are ahx_decoder,
# adpcm_n64_decoder and adpcm_psxc_decoder.
AUDIO_DECODERS="
  aac aac_fixed aac_latm ac3 ac3_fixed alac als apac ape aptx aptx_hd
  bmv_audio bonk cook dca dolby_e dss_sp evrc flac g723_1 g728 g729
  gsm gsm_ms hca hcom imc mace3 mace6 mlp
  mp1 mp1float mp2 mp2float mp3 mp3adu mp3adufloat mp3float mp3on4
  mp3on4float mpc7 mpc8 nellymoser osq paf_audio qcelp qdm2 qdmc qoa
  sbc shorten sipr siren smackaud sonic speex tak truehd tta twinvq vorbis
  wavarc wavpack wmalossless wmapro wmav1 wmav2 wmavoice xma1 xma2
  adpcm_dtk adpcm_ea adpcm_ea_r1 adpcm_ea_r2 adpcm_ea_r3
  adpcm_ea_xas adpcm_g722 adpcm_g726 adpcm_g726le
  adpcm_ima_alp adpcm_ima_amv adpcm_ima_apm adpcm_ima_iss adpcm_ima_qt
  adpcm_ima_smjpeg adpcm_ima_ssi adpcm_ima_wav adpcm_ima_xbox
  adpcm_ms adpcm_mtaf adpcm_psx adpcm_sbpro_2
  adpcm_sbpro_3 adpcm_sbpro_4 adpcm_swf adpcm_vima adpcm_xa adpcm_xmd
  adpcm_yamaha adpcm_zork
  pcm_alaw pcm_bluray pcm_dvd pcm_f16le pcm_f24le pcm_f32be pcm_f32le
  pcm_f64be pcm_f64le pcm_lxf pcm_mulaw pcm_s16be pcm_s16be_planar
  pcm_s16le pcm_s16le_planar pcm_s24be pcm_s24daud pcm_s24le
  pcm_s24le_planar pcm_s32be pcm_s32le pcm_s32le_planar pcm_s64be
  pcm_s64le pcm_s8 pcm_s8_planar pcm_sga pcm_u16be pcm_u16le pcm_u24be
  pcm_u24le pcm_u32be pcm_u32le pcm_u8 pcm_vidc
"

# Audio encoders that are implemented by FFmpeg itself
AUDIO_ENCODERS="
  aac ac3 ac3_fixed alac anull aptx aptx_hd dca dfpwm eac3 flac g723_1
  mlp mp2 mp2fixed nellymoser opus s302m sbc sonic truehd tta vorbis
  wavpack wmav1 wmav2
  adpcm_adx adpcm_argo adpcm_g722 adpcm_g726 adpcm_g726le
  adpcm_ima_alp adpcm_ima_amv adpcm_ima_apm adpcm_ima_qt adpcm_ima_ssi
  adpcm_ima_wav adpcm_ima_ws adpcm_ms adpcm_swf adpcm_yamaha
  pcm_alaw pcm_f32be pcm_f32le pcm_f64be pcm_f64le pcm_mulaw
  pcm_s16be pcm_s16be_planar pcm_s16le pcm_s16le_planar pcm_s24be
  pcm_s24daud pcm_s24le pcm_s24le_planar pcm_s32be pcm_s32le
  pcm_s32le_planar pcm_s64be pcm_s64le pcm_s8 pcm_s8_planar
  pcm_u16be pcm_u16le pcm_u24be pcm_u24le pcm_u32be pcm_u32le pcm_u8
  pcm_vidc
"

# Codecs that are provided by the external libraries of this project.
# They cannot be enabled unconditionally, because the configure would fail
# to find the library that was not requested on the command line.
# The codec of a library is named after the library in FFmpeg, and only the
# side that actually exists is listed - FFmpeg has no libmp3lame and no
# libtwolame decoder, they both decode with the native decoders.
function externalEncodersOf() {
  case $1 in
    libmp3lame) echo "libmp3lame" ;;
    libopus)    echo "libopus" ;;
    libspeex)   echo "libspeex" ;;
    libtwolame) echo "libtwolame" ;;
  esac
}

function externalDecodersOf() {
  case $1 in
    libopus)    echo "libopus" ;;
    libspeex)   echo "libspeex" ;;
  esac
}

# Containers that can be read. Every raw PCM format is a demuxer on its own,
# that is why the pcm_* entries are present here too.
AUDIO_DEMUXERS="
  aa aac aax ac3 ac4 adf adp adx aea aiff aix alp ape au bmv boa bonk caf
  dts dtshd ea eac3 flac g722 g723_1 g726 g726le gsm hca hcom iamf ilbc
  ipmovie loas lrc matroska mlp mov mp3 mpc mpc8 mpegts ogg oma osq paf
  qcp qoa sbc sga s337m smush sol sox spdif tak tta voc w64 wav wavarc
  wsaud wsvqa wv xa xwma
  pcm_alaw pcm_f32be pcm_f32le pcm_f64be pcm_f64le pcm_mulaw
  pcm_s16be pcm_s16le pcm_s24be pcm_s24le pcm_s32be pcm_s32le pcm_s8
  pcm_u16be pcm_u16le pcm_u24be pcm_u24le pcm_u32be pcm_u32le pcm_u8
  pcm_vidc
"

# Containers that can be written. The mov muxer is intentionally missing,
# ipod and mp4 cover every audio-only QuickTime/MP4 file that is of interest
# and are much cheaper than the generic mov muxer.
AUDIO_MUXERS="
  a64 ac3 ac4 adts aiff au caf dts eac3 flac ipod matroska matroska_audio
  mlp mp2 mp3 mp4 oga ogg opus sbc sox spdif spx truehd tta wav w64 wsaud
  pcm_alaw pcm_f32be pcm_f32le pcm_f64be pcm_f64le pcm_mulaw
  pcm_s16be pcm_s16le pcm_s24be pcm_s24le pcm_s32be pcm_s32le pcm_s8
  pcm_u16be pcm_u16le pcm_u24be pcm_u24le pcm_u32be pcm_u32le pcm_u8
  pcm_vidc
"

# Every audio filter of FFmpeg, plus the audio sources, the audio sinks and
# the audio visualisation filters. showcqt is the only audio filter that
# needs libswscale, so it is the one that is left out on purpose - the whole
# library weighs more than every audio filter together.
AUDIO_FILTERS="
  aap acompressor acontrast acopy acue acrossfade acrossover acrusher
  adeclick adeclip adecorrelate adelay adenorm aderivative adrc
  adynamicequalizer adynamicsmooth aecho aemphasis aeval aexciter afade
  afftdn afftfilt afir afreqshift afwtdn agate aformat aiir aintegral
  ainterleave alatency alimiter allpass aloop amerge ametadata amix
  amultiply anequalizer anlmdn anlmf anlms anull apad aperms aphaser
  aphaseshift apsnr apsyclip apulsator aresample arealtime areverse arls
  arnndn asdr asegment aselect asendcmd asetnsamples asetpts asetrate asettb
  ashowinfo asidedata asisdr asoftclip aspectralstats asplit astats
  astreamselect asubboost asubcut asupercut asuperpass asuperstop atempo
  atilt atrim axcorrelate bandpass bandreject bass biquad channelmap
  channelsplit chorus compand compensationdelay crossfeed crystalizer
  dcshift deesser dialoguenhance drmeter dynaudnorm earwax ebur128 equalizer
  extrastereo firequalizer flanger haas hdcd headphone highpass highshelf
  join loudnorm lowpass lowshelf mcompand pan replaygain sidechaincompress
  sidechaingate silencedetect silenceremove speechnorm stereotools
  stereowiden superequalizer surround tiltshelf treble tremolo vibrato
  virtualbass volume volumedetect
  aevalsrc afdelaysrc afireqsrc afirsrc anoisesrc anullsrc hilbert sinc sine
  anullsink
  a3dscope abitscope ahistogram aphasemeter avectorscope concat showcwt
  showfreqs showspatial showspectrum showspectrumpic showvolume
  showwaves showwavespic
"

# The default set provides local access only. Passing --enable-network to
# ffmpeg-android-maker-only-audio.sh adds the protocols that are able to
# pull audio from the network. https and tls additionally require mbedtls.
AUDIO_PROTOCOLS="cache concat data fd file pipe subfile unix"
AUDIO_NETWORK_PROTOCOLS="crypto http https rtp tcp tls udp udplite"

# Gathering the codecs of the external libraries that were requested
EXTERNAL_ENCODERS=
EXTERNAL_DECODERS=
for LIBRARY_NAME in ${FFMPEG_EXTERNAL_LIBRARIES[@]}
do
  EXTERNAL_ENCODERS+=" $(externalEncodersOf ${LIBRARY_NAME})"
  EXTERNAL_DECODERS+=" $(externalDecodersOf ${LIBRARY_NAME})"
done

# Turning the whitespace separated lists into --enable-* arguments
# libswscale is disabled explicitly because the configure enables every
# library of LIBRARY_LIST unconditionally, and no audio component needs it
AUDIO_CONFIGURATION_FLAGS="--disable-everything --disable-doc --disable-swscale"
for COMPONENT_NAME in ${AUDIO_DECODERS} ${EXTERNAL_DECODERS}
do
  AUDIO_CONFIGURATION_FLAGS+=" --enable-decoder=${COMPONENT_NAME}"
done
for COMPONENT_NAME in ${AUDIO_ENCODERS} ${EXTERNAL_ENCODERS}
do
  AUDIO_CONFIGURATION_FLAGS+=" --enable-encoder=${COMPONENT_NAME}"
done
for COMPONENT_NAME in ${AUDIO_DEMUXERS}
do
  AUDIO_CONFIGURATION_FLAGS+=" --enable-demuxer=${COMPONENT_NAME}"
done
for COMPONENT_NAME in ${AUDIO_MUXERS}
do
  AUDIO_CONFIGURATION_FLAGS+=" --enable-muxer=${COMPONENT_NAME}"
done
for COMPONENT_NAME in ${AUDIO_FILTERS}
do
  AUDIO_CONFIGURATION_FLAGS+=" --enable-filter=${COMPONENT_NAME}"
done

if [ "${FFMPEG_AUDIO_ENABLE_NETWORK}" = true ] ; then
  AUDIO_PROTOCOLS+=" ${AUDIO_NETWORK_PROTOCOLS}"
fi
for COMPONENT_NAME in ${AUDIO_PROTOCOLS}
do
  AUDIO_CONFIGURATION_FLAGS+=" --enable-protocol=${COMPONENT_NAME}"
done

# FFmpeg enables its examples unconditionally and there is no single option
# that turns them off, but two of them need libswscale. libswscale is bigger
# than every audio filter of FFmpeg together, so each example is disabled
# separately, the same way the configure itself lists them.
# The first and the last line of EXAMPLE_LIST are its quotes, they are dropped
# with sed, otherwise they would end up inside a --disable- argument.
for EXAMPLE_NAME in $(sed -n '/^EXAMPLE_LIST="/,/^"$/p' configure | sed '1d;$d')
do
  AUDIO_CONFIGURATION_FLAGS+=" --disable-${EXAMPLE_NAME}"
done

if [ "$FFMPEG_GPL_ENABLED" = true ] ; then
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-gpl"
fi

# Preparing flags for enabling requested libraries
ADDITIONAL_COMPONENTS=
for LIBRARY_NAME in ${FFMPEG_EXTERNAL_LIBRARIES[@]}
do
  ADDITIONAL_COMPONENTS+=" --enable-$LIBRARY_NAME"
done

# Referencing dependencies without pkgconfig
DEP_CFLAGS="-I${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/include"
DEP_LD_FLAGS="-L${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/lib $FFMPEG_EXTRA_LD_FLAGS"

# Android 15 with 16 kb page size support
# https://developer.android.com/guide/practices/page-sizes#compile-r27
EXTRA_LDFLAGS="-Wl,-z,max-page-size=16384 $DEP_LD_FLAGS"

./configure \
  --prefix=${BUILD_DIR_FFMPEG}/${ANDROID_ABI} \
  --enable-cross-compile \
  --target-os=android \
  --arch=${TARGET_TRIPLE_MACHINE_ARCH} \
  --sysroot=${SYSROOT_PATH} \
  --cc=${FAM_CC} \
  --cxx=${FAM_CXX} \
  --ld=${FAM_LD} \
  --ar=${FAM_AR} \
  --as=${FAM_CC} \
  --nm=${FAM_NM} \
  --ranlib=${FAM_RANLIB} \
  --strip=${FAM_STRIP} \
  --extra-cflags="-O3 -fPIC $DEP_CFLAGS" \
  --extra-ldflags="$EXTRA_LDFLAGS" \
  --enable-shared \
  --disable-static \
  --disable-vulkan \
  --pkg-config=${PKG_CONFIG_EXECUTABLE} \
  ${AUDIO_CONFIGURATION_FLAGS} \
  ${EXTRA_BUILD_CONFIGURATION_FLAGS} \
  $ADDITIONAL_COMPONENTS || exit 1

# FFmpeg drops a component without any visible error when its dependencies
# are not met, so a requested encoder can be missing from the result while
# the configure still reports success. Checking the requested external
# codecs turns that silent failure into a build failure.
for CODEC_NAME in ${EXTERNAL_ENCODERS} ${EXTERNAL_DECODERS}
do
  if grep -q "^!CONFIG_$(echo ${CODEC_NAME} | tr 'a-z-' 'A-Z_')_\(ENCODER\|DECODER\)=yes" ffbuild/config.mak
  then
    echo "The ${CODEC_NAME} codec was requested, but FFmpeg did not enable it."
    echo "The library it comes from is probably missing from ${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}"
    exit 1
  fi
done

${MAKE_EXECUTABLE} clean
${MAKE_EXECUTABLE} -j${HOST_NPROC}
${MAKE_EXECUTABLE} install
