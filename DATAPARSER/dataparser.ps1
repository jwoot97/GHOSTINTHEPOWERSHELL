##
#
#   DATAPARSER v2.3										[ POWERSHELL ]
#
#   Author:		JOSHUA WOOTEN
#   Purpose:	Given a directory path and a search type,
#            	return the search results.  Output format will
#	            vary by search type.
#				Built from the bones of ConfigScraper v1.2.
#
#   Arguments:
#				1. Full path
#       		2. Search type [ ip, string, findreplace, compare    ]
#
#	Returns:
#				1. Filepath searched
#				2. Search type [ IP, STRING, FINDREPLACE             ]
#				3. Server type [ APP, DB, REPLICATOR                 ]
#				3. Number of matches
#				4. Match location, line number, and full string
#
##

# INITIALIZE VARIABLES
$DIR_PATH = Read-Host -Prompt "Enter the FULL PATH to search [ no relative paths, please ]"
$SEARCH_TYPE = Read-Host -Prompt "Choose a SEARCH TYPE [ ip, string, findreplace, compare ]"
$RX = ""
$OUTPUT_FILENAME = ".\logs\$(hostname)__dataparser-log-$(Get-Date -f yyyyMMdd-hhmmss).txt"

# DETERMINE SERVER TYPE BASED ON HOSTNAME
switch -regex ($(hostname)) {
	'.*APP.*' { $SERVER_TYPE = "APPLICATION" }
	'.*DB.*'  { $SERVER_TYPE = "DATABASE"    }
	'.*REP.*' { $SERVER_TYPE = "REPLICATOR"  }
	Default   { $SERVER_TYPE = "n/a"         }
}

# ENSURE PATH ISN'T RELATIVE / EXISTS
if ( $DIR_PATH.substring(0,2) -match '\.' ) {
	Write-Host "Please provide a full path.  No relative paths ( .\thisdirectory )!" -ForegroundColor Red -BackgroundColor Black
	exit 1
} elseif ( -Not ( Test-Path -Path $DIR_PATH )) {
	Write-Host "$DIR_PATH does not exist." -ForegroundColor Red -BackgroundColor Black
	exit 1
}

# POPULATE CONTENT ARRAYS
$DIRARRAY = @( Get-ChildItem $DIR_PATH -Directory | ForEach-Object { $_ } )
$FILEARRAY = @( Get-ChildItem $DIR_PATH -File -recurse -Include *.config, *.sitemap, *.json, *.xml, *.txt | ForEach-Object { $_.FullName } )

# CREATE LOG DIRECTORY & LOG FILE
if ( -Not ( Test-Path -Path ".\logs" )) {
	mkdir ".\logs"
}
New-Item $OUTPUT_FILENAME | Out-Null

# SEARCH TYPE SWITCH [ ip, string, findreplace ]
switch -Exact ($SEARCH_TYPE) {
	ip {
		# POPULATE LOG HEADER
		"HOSTNAME:`t`t$(hostname)`nSERVER TYPE:`t$SERVER_TYPE`nSEARCH PATH:`t$(Resolve-Path -Path $DIR_PATH)`nSEARCH TYPE:`t$SEARCH_TYPE`n`nRESULTS:" | Out-File -Append $OUTPUT_FILENAME
		Write-Host "`n"
		
		# INITIATE SEARCH
		$RX = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
		$FILEARRAY | ForEach-Object {
			$element = $_
			if ( $element -like "*log*") {
				return
			} else {
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
	}
	string {
		$STRINGSEARCH = Read-Host -Prompt "Enter the string to search for"
		
		# POPULATE LOG HEADER
		"HOSTNAME:`t`t$(hostname)`nSERVER TYPE:`t$SERVER_TYPE`nSEARCH PATH:`t$(Resolve-Path -Path $DIR_PATH)`nSEARCH TYPE:`t$SEARCH_TYPE`nSTRING SEARCH:`t$STRINGSEARCH`n`nRESULTS:" | Out-File -Append $OUTPUT_FILENAME
		Write-Host "`n"
		
		# INITIATE SEARCH
		$RX = "$STRINGSEARCH"
		Write-Host "Looking for string [ $STRINGSEARCH ].`n" -ForegroundColor Green -BackgroundColor Black
		$FILEARRAY | ForEach-Object {
			$element = $_
			if ( $element -like "*log*") {
				return
			} else {
				Write-Host "Searching filepath: $element ..." -ForegroundColor Cyan -BackgroundColor Black
				$RX_MATCHES = @(Select-String -Path $element -Pattern $RX)
				
				# ENSURE FILE HAS MATCHES
				if ( $RX_MATCHES.length -gt 0 ) {
					"`n`tFILE PATH:`t[ $element ]`n`tMATCH COUNT:`t[ $($RX_MATCHES.length) ]" | Out-File -Append $OUTPUT_FILENAME
					$RX_MATCHES | ForEach-Object {
						$fullmatch = $_ | Out-String
						$linenumber = $fullmatch.split(':')[2]
						$matchingstring = $fullmatch.split(':', 3)[-1]
						
						# REMOVE EXTRA NEWLINES/RETURNS WITHIN MATCHES AND WRITE TO LOG
						$stringtrim = $matchingstring -replace "\r\n","" -replace ":",":`t"
						"`t`t| LINE $stringtrim" | Out-File -Append $OUTPUT_FILENAME
					}
				}
			}
		}
	}
	findreplace {
		$FINDSTRING = Read-Host -Prompt "Enter the string to search for"
		$REPLACESTRING = Read-Host -Prompt "Enter the string to replace string [ $FINDSTRING ] with"
		
		# POPULATE LOG HEADER
		"HOSTNAME:`t`t$(hostname)`nSERVER TYPE:`t$SERVER_TYPE`nSEARCH PATH:`t$(Resolve-Path -Path $DIR_PATH)`nSEARCH TYPE:`t$SEARCH_TYPE`nSTRING FOUND:`t$FINDSTRING`nSTRING REPLACEMENT:`t$REPLACESTRING`n`nRESULTS:" | Out-File -Append $OUTPUT_FILENAME

		# INITIATE FIND/REPLACE
		Write-Host "Replacing string [ $FINDSTRING ] with [ $REPLACESTRING ].`n" -ForegroundColor Green -BackgroundColor Black
		$num_replacements = 0
		$FILEARRAY | ForEach-Object {
			$element = $_
			if ( $element -like "*log*") {
				return
			} else {
				Write-Host "Searching filepath: $element ..." -ForegroundColor Cyan -BackgroundColor Black
				( ( Get-Content -path $element -Raw ) -replace $FINDSTRING, $REPLACESTRING ) | Set-Content -Path $element
				
				# ENSURE STRING TO BE REPLACED HAS BEEN REMOVED FROM FILE
				if ( @(Select-String -Path $element -Pattern $REPLACESTRING).length -gt 0 ) {
					"`tFILE PATH: [ $element ]`n`t`tReplaced all occurrences of [ $FINDSTRING ] with [ $REPLACESTRING ]." | Out-File -Append $OUTPUT_FILENAME
					$num_replacements++
				}
			}
		}		
		Write-Host "`nTotal replacements made: [ $num_replacements ]." -ForegroundColor Green -BackgroundColor Black
		if ( $num_replacements -lt 1 ) { "`n`tNo replacements made.  [ $FINDSTRING ] not found in any files in [ $DIR_PATH ]." | Out-File -Append $OUTPUT_FILENAME }
	}
	compare {
		Write-Host ""
		
		# POPULATE LOG HEADER
		"HOSTNAME:`t`t$(hostname)`nSERVER TYPE:`t$SERVER_TYPE`nSEARCH PATH:`t$(Resolve-Path -Path $DIR_PATH)`nSEARCH TYPE:`t$SEARCH_TYPE`n`nRESULTS:" | Out-File -Append $OUTPUT_FILENAME
		
		# POPULATE COMPARISON ARRAYS
		$DIR_OLD  = @()
		$DIR_NEW = @()
		$DIRARRAY | ForEach-Object {
			if ( $_ -like "*_OLD" ) {
				$DIR_OLD += $_.FullName
				$DIR_NEW += $_.FullName -replace "_OLD",""
			}
		}
		
		# DEBUG
		#Write-Host "`nOLD DIRECTORIES:`n`t$( $DIR_OLD -join "`n`t" )" -ForegroundColor Green -BackgroundColor Black
		#Write-Host "`nNEW DIRECTORIES:`n`t$( $DIR_NEW -join "`n`t" )" -ForegroundColor Green -BackgroundColor Black
		
		# POPULATE COMPARISON FILEARRAYS
		$FILES_OLD = @(	Get-ChildItem $DIR_OLD -File -recurse -Include *.config, *.sitemap, *.json, *.xml, *.txt | ForEach-Object { $_.FullName } )
		$FILES_NEW = @( Get-ChildItem $DIR_NEW -File -recurse -Include *.config, *.sitemap, *.json, *.xml, *.txt | ForEach-Object { $_.FullName } )
		
		# DEBUG
		#Write-Host "`nOLD FILES:`n`t$( $FILES_OLD -join "`n`t" )" -ForegroundColor Green -BackgroundColor Black
		#Write-Host "`nNEW FILES:`n`t$( $FILES_NEW -join "`n`t" )`n`n" -ForegroundColor Green -BackgroundColor Black
			
		# OUTPUT FILES WITH CHANGES
		0..($FILES_OLD.length - 1) | ForEach-Object {
			Write-Host "`tCOMPARING FILES: [ $($FILES_OLD[$_]) ] [ $($FILES_NEW[$_]) ]"
			if ( $( Compare-Object ( Get-Content $FILES_OLD[$_] ) ( Get-Content $FILES_NEW[$_] ) ) -ne $null ) {
						"`t`tChanges found between files:`n`t`t`t[ $($FILES_OLD[$_]) ] and [ $($FILES_NEW[$_]) ]." | Out-File -Append $OUTPUT_FILENAME					
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