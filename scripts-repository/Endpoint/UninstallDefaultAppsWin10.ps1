#It is recommended to test the script on a local machine for its purpose and effects. 
#ManageEngine Desktop Central will not be responsible for any 
#damage/loss to the data/setup based on the behavior of the script.

#Description - Script to uninstall default apps from windows 10
#Configuration Type - USER

#Uninstall Calendar and Mail:
Get-AppxPackage *windowscommunicationsapps* | Remove-AppxPackage
#Uninstall News:
Get-AppxPackage *bingnews* | Remove-AppxPackage
#Uninstall Movies & TV:
Get-AppxPackage *zunevideo* | Remove-AppxPackage
#Uninstall Weather:
Get-AppxPackage *bingweather* | Remove-AppxPackage
#Uninstall Money:
Get-AppxPackage *bingfinance* | Remove-AppxPackage
#Uninstall OneNote:
Get-AppxPackage *onenote* | Remove-AppxPackage
#Uninstall Xbox:
Get-AppxPackage *xboxapp* | Remove-AppxPackage
#Uninstall Groove Music:
Get-AppxPackage *zunemusic* | Remove-AppxPackage
#Uninstall Get Office:
Get-AppxPackage *officehub* | Remove-AppxPackage