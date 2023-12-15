###########################################################################
#
# FILENAME: DATACOLLECTION.ps1
# AUTHOR  : Joshua Wooten
# USAGE   : Originally written to collect data from the workplace database
#           this script now serves as an example of how to gather data
#           from a database and output results to a CSV file.
#
#           Some of the functionality is irrelevant now, but I still
#           thought it was worth saving to repurpose later.
#
###########################################################################

# PARAMETERS
param (
	[string]$user     = "*",
	[string]$pass     = "*",
	[string]$start    = (Get-Date).AddYears(-3)
)

# VARIABLES
$CAPTUREDAYS  = 7
$STARTDATE    = ([DateTime]$start)
$ENDDATE      = $STARTDATE + (New-TimeSpan -Days $CAPTUREDAYS)
$DB__SERVER   = "$env:COMPUTERNAME"
$DB__NAME     = "*"
$DB__USER     = $user
$DB__PASS     = $pass
$DELIM        = ","
$LOGDIR       = ".\logs\csv\"
$FILENAME     = "DATA__" + ('{0:yyyyMMdd}' -f ($STARTDATE)) + "-" + ('{0:yyyyMMdd}' -f ($ENDDATE))

# IF DATE RANGE IS ALREADY CALCULATED,
# STEP FORWARD ONE WEEK AMD CHECK AGAIN
do {
	Write-Output "DATA FROM DATE RANGE [ $STARTDATE -> $ENDDATE ] PREVIOUSLY COLLECTED"
	$STARTDATE    = $ENDDATE
	$ENDDATE      = $ENDDATE + (New-TimeSpan -Days $CAPTUREDAYS)
	$FILENAME     = "DATA__" + ('{0:yyyyMMdd}' -f ($STARTDATE)) + "-" + ('{0:yyyyMMdd}' -f ($ENDDATE))
} while([System.IO.File]::Exists("$LOGDIR\$FILENAME.csv") -or ($STARTDATE > (Get-Date)))

# QUERY VARIABLE
$SQL__QUERY = @"
	[ sql statement goes here ]
"@

# DATA COLLECTION
$SQL__CONNECTION = New-Object System.Data.SqlClient.SqlConnection  
$SQL__CONNECTION.ConnectionString = "Server = $DB__SERVER; Database = $DB__NAME; Integrated Security = True;"
$SQL__CONNECTION.Open()
$SQL__CMD = New-Object System.Data.SqlClient.SqlCommand  
$SQL__CMD.CommandText = $SQL__QUERY
$SQL__CMD.Connection = $SQL__CONNECTION
$SQL__CMD.CommandTimeout = 0
$SQL__ADAPTER = New-Object System.Data.SqlClient.SqlDataAdapter  
$SQL__ADAPTER.SelectCommand = $SQL__CMD

# DATASET CREATION AND EXPORT
$DATASET = New-Object System.Data.DataSet  
$SQL__ADAPTER.Fill($DATASET)
$SQL__CONNECTION.Close()
$DATASET.Tables[0] | export-csv -Delimiter $DELIM -Path "$LOGDIR\$FILENAME.csv" -NoTypeInformation