##
#
#   DURATIONCHECK v1.0											[ POWERSHELL ]
#
#   Author:		JOSHUA WOOTEN
#   Purpose:	Run on customer database server.  Change the log directory
#	            and filename as necessary.  When running, use Powershell in
#	            administrator mode.  Example of command run:
#	            .\DURATIONCHECK.ps1 -user "*" -pass "*" -path "x"
#
#   Arguments:
#				1. User
#       		2. Password
#               3. Path
#
#	Returns:
#				1. File output
#
##

param (
	[string]$user     = "*",
	[string]$pass     = "*",
	[string]$path     = "x",
	[string]$instance = "$env:COMPUTERNAME"
)

# VARIABLES + DEFAULTS
$DB__SERVER   = $instance
$DB__USER     = $user
$DB__PASS     = ConvertTo-SecureString $pass -AsPlaintext -Force
$CRED         = New-Object System.Management.Automation.PSCredential ($DB__USER, $DB__PASS)
$SQL__QUERY   = ""
$NOTES        = ""
$LOGDIR       = ".\logs\" # default
$FILENAME     = "DURATIONCHECK__" + $path.ToUpper() + "_" + ('{0:yyyyMMdd}' -f (Get-Date)) + "-" + $prepost.ToUpper() + ".txt"
$PATHS  = @('x', 'y')

# EXECUTE SQL COMMANDS
##########################################################################################
function EXE-SQL-CMD {
	# DATA COLLECTION
	$SQL__CONNECTION = New-Object System.Data.SqlClient.SqlConnection  
	$SQL__CONNECTION.ConnectionString = "Server = $DB__SERVER; Database = $DB__NAME; User ID=$DB__USER; Password=$DB__PASS; Integrated Security = True; MultipleActiveResultSets = False"
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
	
	return ($DATASET.Tables[0] | Select-Object).Item(0)
}

# RETURNS DURATION OF SQL QUERY RUN
##########################################################################################
function Get-SQL-Duration{
	param(
		$instancename = $DB__SERVER,
		$databasename = $DB__NAME,
		$sqlquery = $SQL__QUERY,
		$addtlnotes = $NOTES
	)

	$OUTPUT = New-Object System.Object
	
	$OUTPUT | Add-Member -Type NoteProperty -Name path -Value $path
	$OUTPUT | Add-Member -Type NoteProperty -Name InstanceName -Value $DB__SERVER
	$OUTPUT | Add-Member -Type NoteProperty -Name DatabaseName -Value $DB__NAME
	$OUTPUT | Add-Member -Type NoteProperty -Name StartTime -Value (Get-Date)
	
	$SQLOUT = EXE-SQL-CMD
 
	$OUTPUT | Add-Member -Type NoteProperty -Name EndTime -Value (Get-Date)
	$OUTPUT | Add-Member -Type NoteProperty -Name RunDuration -Value (New-TimeSpan -Start $OUTPUT.StartTime -End $OUTPUT.EndTime)
	$OUTPUT | Add-Member -Type NoteProperty -Name AddtlNotes -Value $NOTES
 
	return $OUTPUT
}

# RETURNS OUTPUT OF SQL QUERY RUN
##########################################################################################
function Get-SQL-Output {
	param(
		$instancename = $DB__SERVER,
		$databasename = $DB__NAME,
		$sqlquery = $SQL__QUERY,
		$addtlnotes = $NOTES
	)
		
	$OUTPUT = New-Object System.Object
	$OUTPUT | Add-Member -Type NoteProperty -Name path -Value $path
	$OUTPUT | Add-Member -Type NoteProperty -Name InstanceName -Value $DB__SERVER
	$OUTPUT | Add-Member -Type NoteProperty -Name DatabaseName -Value $DB__NAME
	
	$SQLOUT = EXE-SQL-CMD
	#$SQLOUT = Invoke-Sqlcmd -ServerInstance $DB__SERVER -Database $DB__NAME -Query $SQL__QUERY
 
	if ( $GETVEE -eq 1 ) { $OUTPUT | Add-Member -Type NoteProperty -Name RunDuration -Value $SQLOUT }
	else { $OUTPUT | Add-Member -Type NoteProperty -Name RunDuration -Value $SQLOUT[1] }
	$OUTPUT | Add-Member -Type NoteProperty -Name AddtlNotes -Value $NOTES
	
	return $OUTPUT
}

# FUNCTION TO ORCHESTRATE DATA GATHERING
##########################################################################################
function Output-Duration-Log {
	param(
		$selectedpath = $path
	)
	# QUERY VARIABLE SWITCH [ PER path ]
	######################################################################################
	switch ($path.ToUpper())
	{
		"x" {
			$DB__NAME = "DB_x"
			$SQL__QUERY = @"
				[ SQL HERE ]
"@
			$NOTES = "---"
			Get-SQL-Duration -instancename $DB__SERVER -databasename $DB__NAME -sqlquery $SQL__QUERY `
			| Select-Object instancename,databasename,starttime,endtime,runduration,addtlnotes `
			| Add-Content -Path $LOGDIR\$FILENAME -PassThru
		}
		
		"y" {
			$DB__NAME = "DB_y"
			$SQL__QUERY = @"
				[ SQL HERE ]
"@
			$NOTES = "AVG IMPORT JOB RUNTIME (SECONDS)"
			Get-SQL-Output -instancename $DB__SERVER -databasename $DB__NAME -sqlquery $SQL__QUERY `
			| Select-Object instancename,databasename,runduration,addtlnotes `
			| Add-Content -Path $LOGDIR\$FILENAME -PassThru

		}
	}
}

# EXECUTE SCRIPT FUNCTIONALITY
if ( !($PATHS.Contains($path.ToLower())) ) {
	Write-Host "Invalid path.  Try one of the following: ( x, y )."
} else {
	# CREATE LOG FILE IF NOT CREATED ALREADY
	if ( !(Test-Path $LOGDIR\$FILENAME) ) { New-Item -path $LOGDIR -name $FILENAME -type "file" -value "" -force }
	
	# GATHER DATA
		Output-Duration-Log -selectedpath $path
}