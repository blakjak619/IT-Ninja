Configuration HelloWorldConfig 
{
       Node localhost 
       {
               File TempDir
              {
                 Ensure = "Present" 
                 Type = "Directory" 
                 DestinationPath = "C:\temp" 
                
              }
              File TestFile {
                     Ensure = "Present"
                     DestinationPath = "c:\temp\HelloWorld.txt"
                     Contents = "Hello World!"
                     DependsOn = "[File]TempDir"
              }

       }
}

# Apply configuration (execute via Powershell ISE)
# HelloWorldConfig 
# to enforce:
# Start-DscConfiguration -Wait -Verbose -Path .\HelloWorldConfig