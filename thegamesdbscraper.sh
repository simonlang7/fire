#!/bin/bash

TEXTRESET='\e[0m'
BOLDGREEN='\e[1;32m'
BOLDRED='\e[1;31m'
BOLDYELLOW='\e[1;33m'
BOLDBLUE='\e[1;34m'
BOLDPURPLE='\e[1;35m'
BOLDCYAN='\e[1;36m'

APP_NAME="$0"

printUsage() {
    echo "Usage: $APP_NAME [-g|--game \"<Game>\"] [-d|--destination <Path>] [-b|--basename <Image basename>] [-h|--help]"
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

approxMatch() {
    MATCH=100
    ORIGINAL_NAME=$1
    NAME=$2
    # TODO: implement    
}

# Default settings
#PREFERRED_IMAGE="clearlogo"
BASENAME=""
DESTINATION="."

# Parse arguments
parseArgs "$@"
if [ "$GAME" == "" ]; then
    printUsage
    echo "Error: Game must be specified."
    exit 1
fi

echo -e "\n\n${BOLDCYAN}Processing $GAME ($BASENAME)${TEXTRESET}\n"

if [ "${BASENAME}" != "" ]; then
    BASENAME="${BASENAME}-"
fi

# add the _ so we don't get transferred to the result page immediately
GAME_URLSEARCH="`echo $GAME | sed -e 's/ /+/g' -e 's/(.*)//g' -e 's/\[.*\]//g' -e "s/'//g" -e 's/&/%26/g'`+_"
IMAGE_FILENAMEBASE="${BASENAME}`echo $GAME | sed -e 's/ /-/g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g'`"

# Search TheGamesDB
TEMP_SEARCH="$DESTINATION/temp_search.html"
TEMP_GAME="$DESTINATION/temp_game.html"
wget -q http://thegamesdb.net/search/?string=$GAME_URLSEARCH -O ${TEMP_SEARCH}

# Check results
GAMEURLS="`grep "http://thegamesdb.net/game/" ${TEMP_SEARCH} | sed 's/^.*a href="//g' | sed 's/".*//g'`"
COUNT=1
for GAMEURL in $GAMEURLS; do
    NAME="`grep "$GAMEURL" ${TEMP_SEARCH} | perl -pe 's/<.*?>//g'`"
    ID="`echo $GAMEURL | sed 's@http://thegamesdb.net/game/\(.*\)/@\1@'`"
    PLATFORM="`sed -n '/h3 style.*'$ID'/,/consoles/p' ${TEMP_SEARCH} | tail -1 | sed 's/.*href=.*">\(.*\)<\/a>.*/\1/'`"
    printf "(%2d) %s (%s)\n" "$COUNT" "$NAME" "$PLATFORM"
    ((COUNT++))
done

echo ""
echo -n "Pick a match: "
read CHOICE
echo ""


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
