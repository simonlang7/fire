#!/bin/bash
#
# Author: Simon Lang
# License: GPLv2


TEXTRESET='\e[0m'
BOLDGREEN='\e[1;32m'
BOLDRED='\e[1;31m'
BOLDYELLOW='\e[1;33m'
BOLDBLUE='\e[1;34m'
BOLDPURPLE='\e[1;35m'
BOLDCYAN='\e[1;36m'

APP_NAME="$0"

printUsage() {
    echo "Usage: $APP_NAME [-h|--help] [-r|--rescan FILE] [-a|--autoselect [--no-rescan]] [-o|--output PATH] [-O|--image-output PATH] [-p|--platform PLATFORM] [-f|--force] GAME [GAME...]"
}

parseArgs() {
    while [[ $# > 0 && $1 == "-"* ]]; do
        PARAM=$1
        case $PARAM in
            -h|--help)
                printUsage
                exit 0
                ;;
            
            -r|--rescan)
                RESCAN_FILE="$2"
                shift
                ;;
                
            -a|--autoselect)
                AUTOSELECT_PARAM="--autoselect --logfile "$LOGFILE""
                ;;
            
            --no-rescan)
                NO_RESCAN="true"
                ;;
            
            -o|--output)
                SH_DEST="$2"
                shift
                ;;
            
            -O|--image-output)
                IMG_DEST="$2"
                shift
                ;;
                
            -p|--platform)
                PLATFORM="$2"
                shift
                ;;
                
            -f|--force)
                FORCE="true"
                ;;
            
            *)
                ;;
            
        esac
        shift
    done
    
    # No game AND no rescan file specified?
    if [[ $# == 0 && $RESCAN_FILE == "" ]]; then
        printUsage
        exit 1
    fi
    
    # Remaining arguments (must be at least one game)
    ROMS=()
    NUM_ROMS=0
    while [[ $# > 0 ]]; do
        ROMS[$NUM_ROMS]="$1"
        ((NUM_ROMS++))
        shift
    done
}

getPlatform() {
    EXTENSION="$1"
    case $EXTENSION in
        nes)
            PLATFORM="nes"
            ;;
            
        smc|sfc|fig)
            PLATFORM="snes"
            ;;
        
        n64|z64|v64)
            PLATFORM="n64"
            ;;
            
        iso|cue|m3u)
            PLATFORM="psx"
            ;;
            
        gb)
            PLATFORM="gb"
            ;;
            
        gbc)
            PLATFORM="gbc"
            ;;
            
        gba)
            PLATFORM="gba"
            ;;
            
        nds)
            PLATFORM="nds"
            ;;
            
    esac
}

processRom() {
    # Get game name
    ROMPATH="$1"
    GAMENAME_WITH_DR="`echo "$ROMPATH" | sed 's@.*/@@' | sed 's/\..\{2,5\}$//'`"
    GAME="`echo "$ROMPATH" | sed 's@.*/@@' | sed 's/\..\{2,5\}$//' | sed -e 's/([EGJUSA]*)//' -e 's/\[.*\]//'`"
    
    if [ "$GAME" == "" ]; then
        echo "Error: no game specified."
        echo "       Original path: $ROMPATH"
        echo "       Game: $GAME"
        exit 1
    fi

    EXTENSION="`echo $ROMPATH | sed 's/.*\(.\{2,5\}\)$/\1/'`"
    if [ "$PLATFORM" == "" ]; then
        getPlatform "$EXTENSION"
    fi

    # Strip spaces and parentheses
    OUTPUT_BASE="${PLATFORM}-`echo $ROMPATH | sed 's@.*/@@' | sed -e 's/\..\{2,5\}$//' -e 's/ /-/g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g' -e 's/\.//g' -e "s/'//g" -e 's/\"//g'`"
    OUTPUT_SH="${OUTPUT_BASE}.sh"

    if [[ -e "$SH_DEST/$OUTPUT_SH" && $FORCE != "true" ]]; then
        echo -e "${BOLDPURPLE}Launcher for $GAME exists, skipping.${TEXTRESET}"
        return
    fi
    
    echo -e "#!/bin/bash\n$LAUNCHER $PLATFORM \"$ROMPATH\"" > "$SH_DEST/$OUTPUT_SH"
    chmod +x "$SH_DEST/$OUTPUT_SH"

    # Get images
#    echo "Calling: \"$SCRAPER\" ${AUTOSELECT_PARAM} --output \"${IMG_DEST}\" --basename \"$PLATFORM\" --platform \"$PLATFORM\" \"${ROMPATH}\""
    "$SCRAPER" ${AUTOSELECT_PARAM} --output "${IMG_DEST}" --basename "$PLATFORM" --platform "$PLATFORM" "${ROMPATH}"

    IMAGE_PATH_BASE="${IMG_DEST}/${PLATFORM}-`echo "$GAMENAME_WITH_DR" | sed -e 's/ /-/g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g'`"
    IMAGE_PATH="${IMAGE_PATH_BASE}_clearlogo.png"
    if [ ! -e "$IMAGE_PATH" ]; then
        IMAGE_PATH="${IMAGE_PATH_BASE}_boxfront.jpg"
    fi

    # Prepare .desktop file
    NAME="$GAME"
    ICON="$IMAGE_PATH"
    EXEC="$SH_DEST/$OUTPUT_SH"
    FILEPATH="$SH_DEST"
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
    echo "Path=$FILEPATH" >> $OUTPUT_DESKTOP
    echo "" >> $OUTPUT_DESKTOP
    echo "OnlyShowIn=$ONLY_SHOW_IN" >> $OUTPUT_DESKTOP

}

processGamesFromFile() {
    INPUT_FILE="$1"
    if [[ $VISUAL == "" ]]; then
        echo -n "Editor to view file: "
        read VISUAL
    fi
    "$VISUAL" "$INPUT_FILE"
    AUTOSELECT_PARAM=""
    
    # Read games from file
    GAMES=()
    COUNT=0
    while read -r GAME; do
        GAMES[$COUNT]="$GAME"
        ((COUNT++))
    done < <(grep -B1 -i -E "^\[x\]" "$INPUT_FILE" | grep "#" | sed 's/# //g')

    # Process read games    
    for GAME in "${GAMES[@]}"; do
        # There are two possibilities:
        # 1. The file's comments contain full paths to the roms, i.e. "# /path/to/rom.ext",
        #    then we can just process it directly from there
        if [[ -e "$GAME" ]]; then
            processRom "$GAME"
        else
            # or 2. They just contain the game's name, i.e. "# Some Game", then we have to check
            # our original rom list for the full path
            for ROM in "${ROMS[@]}"; do
                if [[ "$ROM" == *"$GAME"* ]]; then
                    processRom "$ROM"
                fi
            done
        fi
    done
}


# Default settings
SH_DEST="`pwd`"
LAUNCHER="$HOME/bin/launchgame.sh"
DESKTOP_DEST="$HOME/.local/share/applications"
SCRAPER="./thegamesdbscraper.sh"
LOGFILE="autoselect.log"

# Parse arguments
parseArgs "$@"
IMG_DEST="${SH_DEST}/artwork"

# SH template exists?
if [ ! -e "$LAUNCHER" ]; then
    echo "Error: could not find ${LAUNCHER}."
    exit 1
fi

if [[ $AUTOSELECT_PARAM != "" ]]; then
    if [[ "$RESCAN_FILE" == "$LOGFILE" ]]; then
        echo "Rescan file will be saved under rescan.tmp"
        cp -- "$RESCAN_FILE" "rescan.tmp"
        RESCAN_FILE="rescan.tmp"
    fi
    if [[ -e "$LOGFILE" ]]; then
        mv -- "$LOGFILE" "${LOGFILE}.old"
    fi
    touch "$LOGFILE"
    echo "# Games processed on `date`" >> "$LOGFILE"
    echo "# Syntax:" >> "$LOGFILE"
    echo "# # /path/to/rom (or the game's name)" >> "$LOGFILE"
    echo "# [ ] Your ROM (input for the scraper)" >> "$LOGFILE"
    echo "#     Match picked by the scraper" >> "$LOGFILE"
    echo "# " >> "$LOGFILE"
    echo "# Titles with a checked box [x] or [X] will be rescanned after exiting the" >> "$LOGFILE"
    echo "# editor. All other titles will not be rescanned. You can also manually" >> "$LOGFILE"
    echo "# rescan games from a file using the --rescan parameter." >> "$LOGFILE"
    echo "" >> "$LOGFILE"
fi

# Create necessary paths
mkdir -p "$SH_DEST"
mkdir -p "$DESKTOP_DEST"
mkdir -p "$IMG_DEST"

# Make sh destination, rom path, and image destination absolute paths
SH_DEST="`realpath "$SH_DEST"`"
IMG_DEST="`realpath "$IMG_DEST"`"

# Process all ROMs
for ROM in "${ROMS[@]}"; do
    ROM="`realpath "$ROM"`"
    if [ ! -e "$ROM" ]; then
        echo "Error: $ROM does not exist. Skipping..."
    else
        processRom "$ROM"
    fi
done

# Do we need to check the log and rescan titles?
if [[ $AUTOSELECT_PARAM != "" && $NO_RESCAN != "true" ]]; then
    echo ""
    echo -e "${BOLDPURPLE}Processing games from logfile...${TEXTRESET}"
    sleep 2
    processGamesFromFile "$LOGFILE"
fi

# or rescan titles from a given rescan file?
if [[ -e "$RESCAN_FILE" ]]; then
    echo ""
    echo -e "${BOLDPURPLE}Processing games from rescan file...${TEXTRESET}"
    sleep 2
    processGamesFromFile "$RESCAN_FILE"
fi
