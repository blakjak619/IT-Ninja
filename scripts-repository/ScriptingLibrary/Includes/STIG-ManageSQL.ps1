## STIG-ManageSQL SQL Management 
# requires sqlps module loaded (SQL Server 2012)

## SQL-AlwaysOn
# ConfigureSQLAlwaysOn -Action $SQLAlwaysOnAction -Path $SQLAlwaysOnPath
Function ConfigureSQLAlwaysOn ([string]$Action, [string]$Path) {
  write-host "SQL AlwaysOn High Availability action ($Action) path ($Path)"
  if ($LoggingCheck) {ToLog -LogFile $LFName -Text "SQL AlwaysOn High Availability action ($Action) path ($Path)" }
   $SQLHACMD = $null
   switch ($Action) {
        enable  { $SQLHACMD = "Enable-SqlAlwaysOn -Path $Path -Force" }
        disable { $SQLHACMD = "Disable-SqlAlwaysOn -Path $Path -Force" }
        default { "$Action NOT supported" }
   }
   
   if ($SQLHACMD) {
     $SQLHAOutput = Invoke-Expression "$SQLHACMD"  -ErrorVariable e
     if ($e) {
        if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting SQL AlwaysOn High Availability ($Action): $e"
				 }

     }
    }

}