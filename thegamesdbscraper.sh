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
    echo "Usage: $APP_NAME [-g|--game \"<Game>\"] [-d|--destination <Path>] [-b|--basename <Image basename>] [-p|--platform <Platform>] [-h|--help]"
}

parseArgs() {
    while [[ $# > 1 ]]; do
        PARAM=$1
        case $PARAM in
            -h|--help)
                printUsage
                exit 0
                ;;
            
            -g|--game)
                GAME="$2"
                shift
                ;;
            
            -d|--destination)
                DESTINATION="$2"
                shift
                ;;
                
            -b|--basename)
                BASENAME="$2"
                shift
                ;;
                
            -p|--platform)
                PLATFORM="$2"
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

matchPlatform() {
    MATCHED_PLATFORM=""
    if [ "$PLATFORM" == "" ]; then
        PLATFORM="$BASENAME"
    fi
    
    echo -e "Match platform: $PLATFORM\n\n"
    
    case $PLATFORM in
        nes|NES)
            MATCHED_PLATFORM="Nintendo Entertainment System (NES)"
            ;;
        
        snes|SNES)
            MATCHED_PLATFORM="Super Nintendo (SNES)"
            ;;
        
        n64|N64)
            MATCHED_PLATFORM="Nintendo 64"
            ;;
        
        psx|PSX)
            MATCHED_PLATFORM="Sony Playstation"
            ;;
        
        gb|GB)
            MATCHED_PLATFORM="Nintendo Game Boy"
            ;;
        
        gbc|GBC)
            MATCHED_PLATFORM="Nintendo Game Boy Color"
            ;;
        
        gba|GBA)
            MATCHED_PLATFORM="Nintendo Game Boy Advance"
            ;;
            
        md|MD|megadrive|genesis)
            MATCHED_PLATFORM="Sega Mega Drive"
            ;;
            
        sat|SAT|saturn)
            MATCHED_PLATFORM="Sega Saturn"
            ;;
        
        nds|NDS)
            MATCHED_PLATFORM="Nintendo DS"
            ;;
        
        ps2|PS2)
            MATCHED_PLATFORM="Sony Playstation 2"
            ;;
        
        psp|PSP)
            MATCHED_PLATFORM="Sony PSP"
            ;;
            
        *)
            ;;
        
    esac
}

stringLengthDistance() {
    STR1="$1"
    STR2="$2"
    
    STRLENDIST="`echo $((${#STR1} - ${#STR2})) | tr -d '-'`"
}

searchGame() {
    GAME_INPUT="$1"
    # add the _ so we don't get transferred to the result page immediately
    GAME_URLSEARCH="`echo $GAME_INPUT | sed -e 's/ /+/g' -e 's/(.*)//g' -e 's/\[.*\]//g' -e "s/'//g" -e 's/&/%26/g'`+_"
    GAME_WITHOUT_DR="`echo $GAME | sed -e 's/(.*)//g' -e 's/\[.*\]//g'`"
    IMAGE_FILENAMEBASE="${BASENAME}`echo $GAME | sed -e 's/ /-/g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g'`"

    # Search TheGamesDB
    TEMP_SEARCH="$DESTINATION/temp_search.html"
    TEMP_GAME="$DESTINATION/temp_game.html"
    wget -q http://thegamesdb.net/search/?string=$GAME_URLSEARCH -O ${TEMP_SEARCH}

    # Check results
    GAMEURLS="`grep "http://thegamesdb.net/game/" ${TEMP_SEARCH} | grep "h3 style" | sed 's/^.*a href="//g' | sed 's/".*//g'`"
    COUNT=1
    PREFERRED_CHOICE=""
    PREFERRED_STRING=""
    BEST_STRLENDIST="100"
    SAME_PLATFORM=""

    for GAMEURL in $GAMEURLS; do
        # Get name, ID and system/platform of the current match
        NAME="`grep "$GAMEURL" ${TEMP_SEARCH} | grep "h3 style" | perl -pe 's/<.*?>//g'`"
        ID="`echo $GAMEURL | sed 's@http://thegamesdb.net/game/\(.*\)/@\1@'`"
        SYSTEM="`sed -n '/h3 style.*'$ID'/,/common\/consoles/p' ${TEMP_SEARCH} | tail -1 | sed 's/.*href=.*">\(.*\)<\/a>.*/\1/'`"
        
        
        # Now find out whether this is the best match we can find
        
        # Is the full name of the rom contained in the match, or vice versa?
        shopt -s nocasematch
        if [[ "$NAME" == "${GAME_WITHOUT_DR}"* || "${GAME_WITHOUT_DR}" == "$NAME"* ]]; then
            NAME_CONTAINED="true"
        else
            NAME_CONTAINED="false"
        fi
        
        # Also check how long both strings are (and subtract the results - best if 0)
        stringLengthDistance "$NAME" "${GAME_WITHOUT_DR}"
        
        # We only consider it a good match if the platform is the same
        if [ "$MATCHED_PLATFORM" == "$SYSTEM" ]; then
            SAME_PLATFORM="$COUNT $SAME_PLATFORM"
            # If we don't have any good match yet, this'll be it.
            # Otherwise, it's only better if the full name is contained (see above) AND the string length distance is better
            if [ "$PREFERRED_CHOICE" == "" -o "$NAME_CONTAINED" == "true" -a "$STRLENDIST" -lt "$BEST_STRLENDIST" ]; then
                PREFERRED_CHOICE=$COUNT
                PREFERRED_STRING=" ($COUNT)"
                BEST_STRLENDIST="$STRLENDIST"
            fi
        fi
        
        # Save result to MATCHLIST array
        MATCHLIST[$((COUNT - 1))]="`printf "${COLORTAG}(%2d) %s (%s)\n" "$COUNT" "$NAME" "$SYSTEM"`"
        
        ((COUNT++))
    done

    # If we have a best match, color it
    if [ "$PREFERRED_CHOICE" != "" ]; then
        MATCHLIST[$((PREFERRED_CHOICE - 1))]="${BOLDGREEN}${MATCHLIST[$((PREFERRED_CHOICE - 1))]}${TEXTRESET}"
    fi
    # Also color other results with the same platform
    for MATCH in $SAME_PLATFORM; do
        MATCHLIST[$((MATCH - 1))]="${BOLDBLUE}${MATCHLIST[$((MATCH - 1))]}${TEXTRESET}"
    done

    # Display the list
    for MATCH in "${MATCHLIST[@]}"; do
        echo -e $MATCH
    done

    echo ""
    echo -n "Pick match${PREFERRED_STRING} or enter new search ('-' to skip game): "
    read CHOICE
    echo ""
}

processGame() {
    echo -e "\n\n${BOLDCYAN}Processing $GAME ($BASENAME)${TEXTRESET}\n"

    # In order to get a default choice...
    matchPlatform

    if [ "${BASENAME}" != "" ]; then
        BASENAME="${BASENAME}-"
    fi

    GAME_SEARCH="$GAME"
    searchGame "$GAME_SEARCH"
    
    until [[ $CHOICE =~ ^[0-9]+$ || $CHOICE == "" || $CHOICE == "-" ]]; do
        searchGame "$CHOICE"
    done

    # Pick best match if none given
    if [ "$CHOICE" == "" -a "$PREFERRED_CHOICE" != "" ]; then
        CHOICE="$PREFERRED_CHOICE"
    fi
    
    if [[ $CHOICE == "-" || $CHOICE == "" ]]; then
        return
    fi

    # Get graphics for selected result
    if [ "$CHOICE" -ge 1 -a "$CHOICE" -lt "$COUNT" ]; then
        GAMEURL="`echo $GAMEURLS | awk -F" " '{print $'$CHOICE'}'`"
        wget -q $GAMEURL -O ${TEMP_GAME}
        
        CLEARLOGO_URL="`grep "/clearlogo/" ${TEMP_GAME} | sed 's/^.*<img src="//' | sed 's/".*//'`"
        BOXFRONT_URL="`grep "/front/" ${TEMP_GAME} | grep -v gameviewcache | tr -t '"' '\n' | grep -m 1 "/front/"`"
        
        if [ "$CLEARLOGO_URL" != "" ]; then
            echo -n "Saving clear logo..."
            wget -q $CLEARLOGO_URL -O "$DESTINATION/${IMAGE_FILENAMEBASE}_clearlogo.png"
            echo " done."
        fi
        if [ "$BOXFRONT_URL" != "" ]; then
            echo -n "Saving box front..."
            wget -q $BOXFRONT_URL -O "$DESTINATION/${IMAGE_FILENAMEBASE}_boxfront.jpg"
            echo " done."
        fi
        

    fi



    rm -f ${TEMP_SEARCH}
    rm -f ${TEMP_GAME}
}

# Default settings
BASENAME=""
DESTINATION="."

# Parse arguments
parseArgs "$@"
if [ "$GAME" == "" ]; then
    printUsage
    echo "Error: Game must be specified."
    exit 1
fi

processGame
