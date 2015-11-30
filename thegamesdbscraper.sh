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
    echo "Usage: $APP_NAME [-h|--help] [-a|--autoselect [--logfile LOGFILE]] [-o|--output PATH] [-b|--basename IMAGE_BASENAME] [-p|--platform PLATFORM] [-v|--verbose] GAME [GAME...]"
}

parseArgs() {
    while [[ $# > 0 && $1 == "-"* ]]; do
        PARAM=$1
        case $PARAM in
            -h|--help)
                printUsage
                exit 0
                ;;
                
            -a|--autoselect)
                AUTOSELECT="true"
                ;;
            
            --logfile)
                LOGFILE="$2"
                shift
                ;;
            
            -o|--output)
                OUTPUT="$2"
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
            
            -v|--verbose)
                VERBOSE="true"
                ;;
            
            *)
                ;;
            
        esac
        shift
    done
    
    # No game specified?
    if [[ $# == 0 ]]; then
        printUsage
        exit 1
    fi
    
    # Remaining arguments (must be at least one game)
    GAMES=()
    NUM_GAMES=0
    while [[ $# > 0 ]]; do
        GAMES[$NUM_GAMES]="$1"
        ((NUM_GAMES++))
        shift
    done
}

matchPlatform() {
    MATCHED_PLATFORM=""
    if [ "$PLATFORM" == "" ]; then
        PLATFORM="$BASENAME"
    fi
    
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

# Replace roman with arabic numbers for comparison (till 15 should be enough for now...)
romanToLatin() {
    LATIN_STR="`echo $1 | sed -e 's/II/2/g' -e 's/III/3/g' -e 's/IV/4/g' -e 's/V$/5/' -e 's/ V / 5 /g' -e 's/ V:/ 5:/g' -e 's/VI/6/g' -e 's/VII/7/g' -e 's/VIII/8/g' -e 's/IX/9/g' -e 's/ X$/ 10/' -e 's/ X / 10 /g' -e 's/ X:/ 10:/g' -e 's/XI/11/g' -e 's/XII/12/g' -e 's/XIII/13/g' -e 's/XIV/14/g' -e 's/XV/15/g'`"
}

stringLengthDistance() {
    STR1="$1"
    STR2="$2"
    
    STRLENDIST="`echo $((${#STR1} - ${#STR2})) | tr -d '-'`"
    ((STR_LD_RATING = 9 - STRLENDIST/10))
}

stringContained() {
    romanToLatin "$1"
    STR1="$LATIN_STR"
    romanToLatin "$2"
    STR2="$LATIN_STR"
    
    shopt -s nocasematch
    if [[ "$STR1" == "$STR2"* || "$STR2" == "$STR1"* ]]; then
        STRING_CONTAINED="true"
        STRING_CONTAINED_RATING="9"
    else
        STRING_CONTAINED="false"
        STRING_CONTAINED_RATING="0"
    fi
}

# Checks whether all the numbers in $2 are contained in $1
numberContained() {
    romanToLatin "$2"
    NUMBERS="`echo "$LATIN_STR" | grep -o -E '[0-9]+'`"
    romanToLatin "$1"
    STR1="$LATIN_STR"
    
    NUMBER_CONTAINED="true"
    NUM_NUMBERS_NOT_CONTAINED=0
    
    for NUM in $NUMBERS; do
        if [[ "$STR1" != *"$NUM"* ]]; then
            NUMBER_CONTAINED="false"
            ((NUM_NUMBERS_NOT_CONTAINED++))
        fi
    done
    
    NUMBERS_COUNT="`echo $NUMBERS | wc -w`"
    if [[ $NUMBERS_COUNT == 0 ]]; then
        NUMBER_CONTAINED_RATING=9
    else
        ((NUMBER_CONTAINED_RATING = 9 - 9*${NUM_NUMBERS_NOT_CONTAINED}/${NUMBERS_COUNT}))
    fi
}

# Checks whether all words in $2 are contained in $1
wordsContained() {
    romanToLatin "$2"
    WORDS="`echo $LATIN_STR | grep -o -E '[A-Za-z]*'`"
    romanToLatin "$1"
    STR1="$LATIN_STR"
    
    WORDS_CONTAINED="true"
    NUM_WORDS_NOT_CONTAINED=0
    
    for WORD in $WORDS; do
        if [[ "$STR1" != *"$WORD"* ]]; then
            WORDS_CONTAINED="false"
            ((NUM_WORDS_NOT_CONTAINED++))
        fi
    done
    
    WORDS_COUNT="`echo $WORDS | wc -w`"
    ((WORDS_CONTAINED_RATING = 9 - 9*${NUM_WORDS_NOT_CONTAINED}/${WORDS_COUNT}))
}

searchGame() {
    GAME_INPUT="$1"
    NUM_RESULTS="$2"
    if [ "$NUM_RESULTS" == "" ]; then
        NUM_RESULTS=20
    fi
    GAME_PATH="$3"
    if [ "$GAME_PATH" == "" ]; then
        GAME_PATH="$GAME_INPUT"
    fi
    # add the _ so we don't get transferred to the result page immediately
    GAME_URLSEARCH="`echo $GAME_INPUT | sed -e 's/ /+/g' -e 's/(.*)//g' -e 's/\[.*\]//g' -e "s/'//g" -e 's/&/%26/g'`+_"
    GAME_WITHOUT_DR="`echo $GAME_INPUT | sed -e 's/(.*)//g' -e 's/\[.*\]//g'`"
    IMAGE_FILENAMEBASE="${BASENAME}`echo $GAME | sed -e 's/ /-/g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g' -e 's/\.//g'`"

    # Search TheGamesDB
    TEMP_SEARCH="$OUTPUT/temp_search.html"
    TEMP_GAME="$OUTPUT/temp_game.html"
    wget -q "http://thegamesdb.net/search/?searchview=listing&page=1&limit=${NUM_RESULTS}&string=$GAME_URLSEARCH" -O ${TEMP_SEARCH}

    # Check results
    GAMEURLS="`grep "http://thegamesdb.net/game/" ${TEMP_SEARCH} | grep "h3 style" | sed 's/^.*a href="//g' | sed 's/".*//g'`"
    COUNT=1
    PREFERRED_CHOICE=""
    PREFERRED_STRING=""
    BEST_RATING="0"
    BEST_MATCH_NAME=""
    SAME_PLATFORM=""
    MATCHLIST=()
    
    if [[ $GAMEURLS == "" ]]; then
        GAMEURLS="`grep "http://thegamesdb.net/game/" ${TEMP_SEARCH} | grep "canonical" | sed -e 's/^.*href=.//g' -e 's/\".*//g'`"
        echo -n "Found one result: "
        grep "<h1 style" ${TEMP_SEARCH} | perl -pe 's/<.*?>//g'
        CHOICE=1
        return
    fi

    for GAMEURL in $GAMEURLS; do
        # Get name, ID and system/platform of the current match
        NAME="`grep "$GAMEURL" ${TEMP_SEARCH} | grep "h3 style" | perl -pe 's/<.*?>//g'`"
        ID="`echo $GAMEURL | sed 's@http://thegamesdb.net/game/\(.*\)/@\1@'`"
        SYSTEM="`sed -n '/h3 style.*\/'$ID'\//,/common\/consoles/p' ${TEMP_SEARCH} | tail -1 | sed 's/.*href=.*">\(.*\)<\/a>.*/\1/'`"
        
        # Check which images are available and prepare strings for the result
        BOXART_STRING="`sed -n '/h3 style.*\/'$ID'\//,/Boxart:/p' ${TEMP_SEARCH} | tail -1 | awk -F"|" '{print $1}' | grep -E "alt=.Yes."`"
        CLEARLOGO_STRING="`sed -n '/h3 style.*\/'$ID'\//,/Boxart:/p' ${TEMP_SEARCH} | tail -1 | awk -F"|" '{print $3}' | grep -E "alt=.Yes."`"
        
        if [ "$BOXART_STRING" != "" ]; then
            BOXART_STRING="(Box"
        else
            BOXART_STRING="("
        fi
        if [ "$CLEARLOGO_STRING" != "" ]; then
            CLEARLOGO_STRING=", Logo)"
        else
            CLEARLOGO_STRING=")"
        fi
        
        # Now find out whether this is the best match we can find
        numberContained "$NAME" "${GAME_WITHOUT_DR}"
        ((RATING = NUMBER_CONTAINED_RATING * 100000))

        numberContained "${GAME_WITHOUT_DR}" "$NAME"
        ((RATING += NUMBER_CONTAINED_RATING * 10000))
        
        stringContained "$NAME" "$GAME_WITHOUT_DR"
        ((RATING += STRING_CONTAINED_RATING * 1000))
        
        wordsContained "$NAME" "${GAME_WITHOUT_DR}"
        ((RATING += WORDS_CONTAINED_RATING * 100))
        
        wordsContained "${GAME_WITHOUT_DR}" "$NAME"
        ((RATING += WORDS_CONTAINED_RATING * 10))
        
        # Also check how long both strings are (and subtract the results - best if 0)
        stringLengthDistance "$NAME" "${GAME_WITHOUT_DR}"
        ((RATING += STR_LD_RATING * 1))
        
        # We only consider it a good match if the platform is the same
        if [ "$MATCHED_PLATFORM" == "$SYSTEM" ]; then
            SAME_PLATFORM="$COUNT $SAME_PLATFORM"
            # If we don't have any good match yet, this'll be it.
            # Otherwise, it's only better if the full name is contained (see above) AND the string length distance is better
            if [ "$PREFERRED_CHOICE" == "" -o "$RATING" -gt "$BEST_RATING" ]; then
                PREFERRED_CHOICE=$COUNT
                PREFERRED_STRING=" ($COUNT)"
                BEST_RATING="$RATING"
                BEST_MATCH_NAME="$NAME ${BOXART_STRING}${CLEARLOGO_STRING}"
            fi
        fi
        
        if [[ $VERBOSE == "true" ]]; then
            VERBOSE_STRING=" ($RATING)"
        else
            VERBOSE_STRING=""
        fi
        
        # Save result to MATCHLIST array
        MATCHLIST[$((COUNT - 1))]="`printf "(%2d) %s (%s) %s%s%s\n" "$COUNT" "$NAME" "$SYSTEM" "$BOXART_STRING" "$CLEARLOGO_STRING" "$VERBOSE_STRING"`"
        
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
    echo ""

    # Display the list
    if [[ $PREFERRED_CHOICE == "" || $AUTOSELECT != "true" ]]; then
        for MATCH in "${MATCHLIST[@]}"; do
            echo -e $MATCH
        done
        echo ""
    fi
    
    # Autoselect?
    if [[ $AUTOSELECT == "true" ]]; then
        # Select game
        if [[ $PREFERRED_CHOICE != "" ]]; then
            echo -e "Selecting ${BOLDGREEN}`echo "${MATCHLIST[$((PREFERRED_CHOICE - 1))]}" | sed 's/( \([0-9]\)/(\1/'`${TEXTRESET}"
            CHOICE=${PREFERRED_CHOICE}
        else
            echo -e "No match found, skipping.\n"
            CHOICE="-"
            BEST_MATCH_NAME="--no match found--"
        fi
        
        # Log
        echo "# $GAME_PATH" >> "$LOGFILE"
        echo "[ ] $GAME_INPUT" >> "$LOGFILE"
        echo "    $BEST_MATCH_NAME" >> "$LOGFILE"
        echo "" >> "$LOGFILE"
    else
        echo -n "Pick match${PREFERRED_STRING} or enter new search ('-' to skip game, '@<num>' for <num> results): "
        read CHOICE
        echo ""
    fi

}

processGame() {
    # In order to get a default choice...
    GAME_PATH="$1"
    GAME="`echo "$GAME_PATH" | sed 's@.*/@@' | sed 's/\..\{2,5\}$//'`"
    matchPlatform
    
    echo -e "\n${BOLDCYAN}Processing $GAME ($PLATFORM)${TEXTRESET}"

    if [ "${BASENAME}" != "" ]; then
        BASENAME="${BASENAME}-"
    fi

    GAME_SEARCH="$GAME"
    NUM_RESULTS=20
    searchGame "$GAME_SEARCH" "$NUM_RESULTS" "$GAME_PATH"
    
    until [[ $CHOICE =~ ^[0-9]+$ || $CHOICE == "" || $CHOICE == "-" ]]; do
        if [[ $CHOICE =~ ^@[0-9]+$ ]]; then
            NUM_RESULTS="${CHOICE:1}"
        else
            GAME_SEARCH="$CHOICE"
        fi
        searchGame "$GAME_SEARCH" "$NUM_RESULTS" "$GAME_PATH"
    done

    # Pick best match if none given
    if [ "$CHOICE" == "" -a "$PREFERRED_CHOICE" != "" ]; then
        CHOICE="$PREFERRED_CHOICE"
    fi
    
    if [[ $CHOICE == "-" || $CHOICE == "" ]]; then
        return
    fi

    # Get graphics for selected result
    if [ "$CHOICE" -ge 1 -a "$CHOICE" -le "$COUNT" ]; then
        GAMEURL="`echo $GAMEURLS | awk -F" " '{print $'$CHOICE'}'`"
        wget -q $GAMEURL -O ${TEMP_GAME}
        
        CLEARLOGO_URL="`grep "/clearlogo/" ${TEMP_GAME} | sed 's/^.*<img src="//' | sed 's/".*//'`"
        BOXFRONT_URL="`grep "/front/" ${TEMP_GAME} | grep -v gameviewcache | tr -t '"' '\n' | grep -m 1 "/front/"`"
        
        if [ "$CLEARLOGO_URL" != "" ]; then
            echo -n "Saving clear logo..."
            wget -q $CLEARLOGO_URL -O "$OUTPUT/${IMAGE_FILENAMEBASE}_clearlogo.png"
            echo " done."
        fi
        if [ "$BOXFRONT_URL" != "" ]; then
            echo -n "Saving box front..."
            wget -q $BOXFRONT_URL -O "$OUTPUT/${IMAGE_FILENAMEBASE}_boxfront.jpg"
            echo " done."
        fi
    fi
    
    echo ""

    rm -f ${TEMP_SEARCH}
    rm -f ${TEMP_GAME}
}

# Default settings
BASENAME=""
OUTPUT="."
LOGFILE="autoselect.log"

# Parse arguments
parseArgs "$@"

# Process games
for GAME in "${GAMES[@]}"; do
    if [ "$GAME" == "" ]; then
        printUsage
        echo "Error: Game must be specified."
        exit 1
    fi

    processGame "$GAME"
done
