#!/bin/bash

APP_NAME="$0"

printUsage() {
    echo "Usage: $APP_NAME [-r|--rom \"<Path to ROM>\"] [-s|--shdest <Path>] [-i|--imagedest <Path>] [-h|--help]"
}

parseArgs() {
    while [[ $# > 1 ]]; do
        PARAM=$1
        case $PARAM in
            -h|--help)
                printUsage
                exit 0
                ;;
            
            -r|--rom)
                ROMPATH="$2"
                shift
                ;;
            
            -s|--shdest)
                SH_DEST="$2"
                shift
                ;;
            
            -i|--imagedest)
                IMG_DEST="$2"
                shift
                ;;
            
            *)
                ;;
            
        esac
        shift
    done
    
    # Last parameter
    if [[ $# > 0 ]]; then
        PARAM=$1
        case $PARAM in
            -h|--help)
                printUsage
                exit 0
                ;;
                
            *)
                ;;
        esac
    fi
}

# Default settings
SH_DEST="`pwd`"
SH_TEMPLATE="launchgame.sh"
IMG_DEST="$(pwd)/artwork"
DESKTOP_DEST="$HOME/.local/share/applications"
SCRAPER="./thegamesdbscraper.sh"

# Parse arguments
parseArgs "$@"

# SH template exists?
if [ ! -e "$SH_TEMPLATE" ]; then
    echo "Error: could not find $SH_TEMPLATE."
    exit 1
fi

# Create necessary paths
mkdir -p "$DESKTOP_DEST"
mkdir -p "$IMG_DEST"

# Make sh destination, rom path, and image destination absolute paths
SH_DEST="`realpath "$SH_DEST"`"
ROMPATH="`realpath "$ROMPATH"`"
IMG_DEST="`realpath "$IMG_DEST"`"

# Get game name
GAMENAME_WITH_DR="`echo $ROMPATH | sed 's@.*/@@' | sed 's/....$//'`"
GAME="`echo $ROMPATH | sed 's@.*/@@' | sed 's/....$//'`" # | sed 's/([EGJUSA]*)//'`"

EXTENSION="`echo $ROMPATH | sed 's/.*\(...\)$/\1/'`"
case $EXTENSION in
    smc|sfc|fig)
        CORE="snes9x_next"
        PLATFORM="snes"
        ;;
    
    nes)
        CORE="fceumm"
        PLATFORM="nes"
        ;;
        
    n64|z64|v64)
        CORE="mupen64plus"
        PLATFORM="n64"
        ;;
        
    iso|cue)
        CORE="mednafen_psx"
        PLATFORM="psx"
        ;;
esac

# Strip spaces and parentheses
OUTPUT_BASE="${PLATFORM}-$(echo $ROMPATH | sed 's@.*/@@' | sed -e 's/....$//' -e 's/ /-/g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g')"
OUTPUT_SH="${OUTPUT_BASE}.sh"

# TODO: check if file exists
sed -e "s@#CORE#@$CORE@" -e "s@#ROM#@$ROMPATH@" "$SH_TEMPLATE" > "$SH_DEST/$OUTPUT_SH"

# Get images
"$SCRAPER" --game "${GAMENAME_WITH_DR}" --destination "${IMG_DEST}" --basename "$PLATFORM"

IMAGE_PATH_BASE="${IMG_DEST}/${PLATFORM}-`echo "$GAMENAME_WITH_DR" | sed -e 's/ /-/g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g'`"
IMAGE_PATH="${IMAGE_PATH_BASE}_clearlogo.png"
if [ ! -e "$IMAGE_PATH" ]; then
    IMAGE_PATH="${IMAGE_PATH_BASE}_boxfront.jpg"
fi

# Prepare .desktop file
NAME="$GAME"
ICON="$IMAGE_PATH"
EXEC="$SH_DEST/$OUTPUT_SH"
PATH="$SH_DEST"
OUTPUT_DESKTOP="${DESKTOP_DEST}/${OUTPUT_BASE}.desktop"

ENCODING="UTF-8"
VALUE="1.0"
TYPE="Application"
GENERIC_NAME="$NAME"
COMMENT=""
CATEGORIES="Game;"
ONLY_SHOW_IN="Old"

echo "[Desktop Entry]" > $OUTPUT_DESKTOP
echo "Encoding=$ENCODING" >> $OUTPUT_DESKTOP
echo "Value=$VALUE" >> $OUTPUT_DESKTOP
echo "Type=$TYPE" >> $OUTPUT_DESKTOP
echo "Name=$NAME" >> $OUTPUT_DESKTOP
echo "GenericName=$GENERIC_NAME" >> $OUTPUT_DESKTOP
echo "Comment=$COMMENT" >> $OUTPUT_DESKTOP
echo "Icon=$ICON" >> $OUTPUT_DESKTOP
echo "Exec=$EXEC" >> $OUTPUT_DESKTOP
echo "Categories=$CATEGORIES" >> $OUTPUT_DESKTOP
echo "Path=$PATH" >> $OUTPUT_DESKTOP
echo "" >> $OUTPUT_DESKTOP
echo "OnlyShowIn=$ONLY_SHOW_IN" >> $OUTPUT_DESKTOP

