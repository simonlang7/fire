#!/bin/bash
RETROARCH="/usr/bin/retroarch"
CONFIG="/home/simon/.config/retroarch/retroarch.cfg"
CORE_BASE_DIR="/home/simon/.config/retroarch/cores"
LIB_ENDING="_libretro.so"

CORE="#CORE#"
ROM="#ROM#"

$RETROARCH --config "$CONFIG" -L ${CORE_BASE_DIR}/${CORE}${LIB_ENDING} "${ROM}"

