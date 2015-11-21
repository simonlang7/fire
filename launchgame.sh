#!/bin/bash
#
# Author: Simon Lang
# License: GPLv2
RETROARCH="/usr/bin/retroarch"
LIBRETRO_CONFIG="/home/simon/.config/retroarch/retroarch.cfg"
LIBRETRO_COREDIR="/home/simon/.config/retroarch/cores"
LIBRETRO_ENDING="_libretro.so"

M64DIR="/home/simon/mupen64plus/"
M64BIN="mupen64plus"
M64GFX="mupen64plus-video-glide64mk2.so"
M64INPUT="mupen64plus-input-sdl.so"
M64RSP="mupen64plus-rsp-hle.so"
M64AUDIO="mupen64plus-audio-sdl.so"


APP_NAME="$0"

printUsage() {
    echo "Usage: $APP_NAME <Platform> <Path to ROM>"
}

launchGame() {
    PLATFORM="$1"
    ROM="$2"

    case $PLATFORM in
        nes)
            LIBRETRO_CORE="fceumm"
            APPLICATION="retroarch"
            ;;
            
        snes)
            LIBRETRO_CORE="snes9x_next"
            APPLICATION="retroarch"
            ;;
        
        n64)
            LIBRETRO_CORE="mupen64plus"
            APPLICATION="retroarch"
            ;;
            
        psx)
            LIBRETRO_CORE="mednafen_psx"
            APPLICATION="retroarch"
            ;;
            
        md|megadrive|genesis)
            LIBRETRO_CORE="genesis_plus_ex"
            APPLICATION="retroarch"
            ;;
            
        sat|saturn)
            LIBRETRO_CORE="yabause"
            APPLICATION="retroarch"
            ;;
            
        gb|gbc)
            LIBRETRO_CORE="gambatte"
            APPLICATION="retroarch"
            ;;
            
        gba)
            LIBRETRO_CORE="vbam"
            APPLICATION="retroarch"
            ;;
            
        nds)
            LIBRETRO_CORE="desmume"
            APPLICATION="retroarch"
            ;;
            
        psp)
            LIBRETRO_CORE="ppsspp"
            APPLICATION="retroarch"
            ;;
            
    esac

    case $APPLICATION in
        retroarch)
            $RETROARCH --config "$LIBRETRO_CONFIG" -L ${LIBRETRO_COREDIR}/${LIBRETRO_CORE}${LIBRETRO_ENDING} "$ROM"
            ;;

        mupen64plus)
            cd "$M64DIR"
            ./$M64BIN --osd --fullscreen --gfx $M64GFX --audio $M64AUDIO --input $M64INPUT --rsp $M64RSP "$ROM"
            ;;
    esac
}

PLATFORM="$1"
ROM="$2"

launchGame "$PLATFORM" "$ROM"
