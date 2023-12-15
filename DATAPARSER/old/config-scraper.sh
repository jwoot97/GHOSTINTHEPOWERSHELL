##
#
#   Configuration Scraper v1.0                    [ SHELL ]
#
#   Author:  JOSHUA WOOTEN
#   Purpose: Given a directory path and a search type,
#	     return the search results.  Output format
#	     will vary by search type.
#
#   Arguments:
#	1. PATH
#	2. Search Type ( ip )
#
##

# INIT VARIABLES
DIR_PATH="${1}"
SEARCH_TYPE="${2}"
declare -a FILEARRAY
R_PATTERN=""
OUTPUT_FILENAME="./logs/${HOSTNAME}__configscraper-log-$(date +%m%d%Y)-$(date +%H%M%S).txt"

if [[ $( echo ${FILENAME} | grep "APP") != '' ]]; then
	SERVERTYPE="APPLICATION"
elif [[ $( echo ${FILENAME} | grep "REP") != '' ]]; then
	SERVERTYPE="REPLICATOR"
else
	SERVERTYPE="DEFAULT"
fi


# INIT COLOR CODES
RED="\\e[31m"
YELLOW="\\e[33m"
GREEN="\\e[32m"
CYAN="\\e[36m"
NC="\\e[0m"

# CHECK FOR MISSING ARGUMENTS
if [[ "${DIR_PATH}" == "" || "${SEARCH_TYPE}" == "" ]]; then
	echo -e "${RED}[ ERROR ]: Script requires a directory path and a search type.${NC}"
	echo -e "\t| USAGE: sh config-scraper.sh <path> <search-type>"
	echo -e "\t| Search Types include: ip"
	exit 1
fi

# PARSE PATH ( FIX SLASHES IF OPERATING SYS RULES VARY, AND ESCAPE SPACES )
DIR_PATH=$(echo ${DIR_PATH} | sed 's|\\|\/|g;s|\ |\\ |g')

# ENSURE PATH EXISTS
if ! [[ -e ${DIR_PATH} ]]; then
	echo -e "${RED}[ ERROR ]: ${DIR_PATH} is not a valid path.${NC}"
	exit 1
fi

# POPULATE FILE ARRAY
FILEARRAY=($(ls -1 ${DIR_PATH}))

# SEARCH TYPE SWITCH ( ALLOWS FOR DIFFERENT PATTERNS TO BE USED )
case SEARCH_TYPE in
	ip)
		R_PATTERN="\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}"
	;;
esac

# CREATE LOG & DIRECTORY
if [[ ! -d $(dirname ${OUTPUT_FILENAME}) ]]; then
	mkdir $(dirname ${OUTPUT_FILENAME})
fi

touch ${OUTPUT_FILENAME}

# POPULATE LOG
echo -e "HOSTNAME:\t${HOSTNAME}\nSERVER TYPE:\t${SERVERTYPE}\nSEARCH PATH:\t$(readlink -f ${DIR_PATH})\nSEARCH TYPE:\t${SEARCH_TYPE}\n\nRESULTS:" >> ${OUTPUT_FILENAME}
for element in ${FILEARRAY[@]}; do
	FULLPATH="$(readlink -f ${DIR_PATH})/${element}"
	if [[ -f ${FULLPATH} ]]; then
		echo -e "${CYAN}[ INFO ]: ${element} is a file - searching ...${NC}"
		echo -e "\n\tFILE PATH: [ ${FULLPATH} ]" >> ${OUTPUT_FILENAME}
		cat ${FULLPATH} | grep -ne "${R_PATTERN}" | sed -e 's|:|\ -\ |g' -e 's|^|\t\t\|\ LINE\ |g' >> ${OUTPUT_FILENAME}
	elif [[ -d ${FULLPATH} ]]; then
		echo -e "${YELLOW}[ WARN ]: ${element} is a directory - skipping.${NC}"
		continue
	else
		echo -e "${RED}[ ERROR ]: ${element} is neither a file or a directory - skipping.${NC}"
		continue
	fi
done

echo -e "\n${GREEN}DONE.${NC}\nLog file can be found at [ ${GREEN}${OUTPUT_FILENAME}${NC} ]"
