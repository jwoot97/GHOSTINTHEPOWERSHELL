##
#
#   Configuration Scraper v1.2                   [ POWERSHELL ]
#
#   Author:		JOSHUA WOOTEN
#   Purpose:	Given a directory path and a search type,
#            	return the search results.  Output format will
#	            vary by search type.
#
#   Arguments:
#				1. Full path
#       		2. Search type ( ip )
#
#	Returns:
#				1. Filepath searched
#				2. Search type
#				3. Server type ( APP, DB, REPLICATOR )
#				3. Number of matches
#				4. Match location ( line number ) and string
#				5. Number of matches not directly related
#
##

# INITIALIZE VARIABLES
$DIR_PATH = $args[0]
$SEARCH_TYPE = $args[1]
$RX = ""
$OUTPUT_FILENAME = ".\logs\$(hostname)__configscraper-log-$(Get-Date -f yyyyMMdd-hhmmss).txt"

# DETERMINE SERVER TYPE BASED ON HOSTNAME
if ( $(hostname) -like "*APP*" ) {
	$SERVER_TYPE = "APPLICATION"
} elseif ( $(hostname) -like "*DB*" ) {
	$SERVER_TYPE = "DATABASE"
} elseif ( $(hostname) -like "*REP*" ) {
	$SERVER_TYPE = "REPLICATOR"
} else {
	$SERVER_TYPE = "DEFAULT"
}

# CHECK FOR MISSING ARGUMENTS
if ( $args.length -lt 2 ) {
	Write-Host "Script requires a directory path to search and a search type." -ForegroundColor Red -BackgroundColor Black
	Write-Host "| USAGE: config-scraper.ps1 <directory path> <search type>"
	Write-Host "Search Types: ip"
	exit 1
}

# ENSURE PATH ISN'T RELATIVE / EXISTS
if ( $DIR_PATH.substring(0,2) -match '\.' ) {
	Write-Host "Please provide a full path.  No relative paths ( .\thisdirectory )!" -ForegroundColor Red -BackgroundColor Black
	exit 1
} elseif ( -Not ( Test-Path -Path $DIR_PATH )) {
	Write-Host "$DIR_PATH does not exist." -ForegroundColor Red -BackgroundColor Black
	exit 1
}

# POPULATE FILE ARRAY
$FILEARRAY = @(Get-ChildItem $DIR_PATH -File -recurse -Include *.config, *.sitemap, *.json, *.xml | ForEach-Object { $_.FullName })

# CREATE LOG DIRECTORY & LOG FILE
if ( -Not ( Test-Path -Path ".\logs" )) {
	mkdir ".\logs"
}
New-Item $OUTPUT_FILENAME | Out-Null

# POPULATE LOG
"HOSTNAME:`t`t$(hostname)`nSERVER TYPE:`t$SERVER_TYPE`nSEARCH PATH:`t$( Resolve-Path -Path $DIR_PATH )`nSEARCH TYPE:`t$SEARCH_TYPE`n`nRESULTS:" | Out-File -Append $OUTPUT_FILENAME
Write-Host "`n"

# SEARCH TYPE SWITCH
switch -Exact ($SEARCH_TYPE) {
	ip {
		$RX = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
		$FILEARRAY | ForEach-Object {
			$element = $_
			Write-Host "Searching filepath: $element ..." -ForegroundColor Cyan -BackgroundColor Black
			$RX_MATCHES = @(Select-String -Path $element -Pattern $RX)
			
			# ENSURE FILE HAS MATCHES
			if ( $RX_MATCHES.length -gt 0 ) {
				"`n`tFILE PATH:`t[ $element ]`n`tMATCH COUNT:`t[ $($RX_MATCHES.length) ]" | Out-File -Append $OUTPUT_FILENAME
				$non_ip_count = 0
				$RX_MATCHES | ForEach-Object {
					$fullmatch = $_ | Out-String
					$linenumber = $fullmatch.split(':')[2]
					$matchingstring = $fullmatch.split(':', 3)[-1]
					
					# SKIP MATCHES THAT REFERENCE VERSION/READING TYPE ( NOT IP )
					if ($fullmatch -like "*ersion*" -OR $fullmatch -like "*ReadingType*") {
						$non_ip_count++
					} else {
						# REMOVE EXTRA NEWLINES/RETURNS WITHIN MATCHES AND WRITE TO LOG
						$stringtrim = $matchingstring -replace "\r\n",""
						"`t`t| LINE $stringtrim" | Out-File -Append $OUTPUT_FILENAME
					}
				}
				# DISPLAY COUNT OF REGEX MATCHES THAT DON'T REFER TO IP
				if ( $non_ip_count -gt 0 ) {
					"`t`t| Matches referencing version number or readingtype: $non_ip_count" | Out-File -Append $OUTPUT_FILENAME
				}
			}
		}
	}
	Default {
		Write-Host "Invalid search type: $_" -ForegroundColor Red -BackgroundColor Black
		exit 1
	}
}

# REMOVE ALL EMPTY LINES IN LOG FILE
(gc $OUTPUT_FILENAME) | ? {$_.trim() -ne "" } | set-content $OUTPUT_FILENAME

# DISPLAY LOG FILE PATH
Write-Host "`nDONE.`nLog file can be found at [ $( Resolve-Path -Path $OUTPUT_FILENAME) ]`n" -ForegroundColor Green -BackgroundColor Black