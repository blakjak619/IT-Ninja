:: It is recommended to test the script on a local machine for its purpose and effects. 
:: ManageEngine Desktop Central will not be responsible for any 
:: damage/loss to the data/setup based on the behavior of the script.

:: Description - Script to associate an extension to a program
:: Parameters -
:: Remarks - The extension and the program path must be hardcoded
:: Configuration Type - COMPUTER
:: ==============================================================

Assoc .txt=txtfile
:: Specify the path of the exe below
Ftype txtfile="C:\Program Files (x86)\Notepad++\notepad++.exe" %%1