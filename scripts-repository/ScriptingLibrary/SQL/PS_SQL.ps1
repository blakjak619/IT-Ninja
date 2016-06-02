### This will use windows Authentication only.


function SQLQuery ( [string]$SQLServer, [string]$SQLDB, [string]$SQLCMD )
       {


              $dataSource = "$SQLServer"
              $database = "$SQLDB"    
              $sqlCommand = "$SQLCMD"
              
              
              
              ## Prepare the authentication information. By default, we pick
              ## Windows authentication
              $authentication = "Integrated Security=SSPI;"
              
              
              ## Prepare the connection string out of the information they
              ## provide
              $connectionString = "Provider=sqloledb; " +
                                  "Data Source=$dataSource; " +
                                  "Initial Catalog=$database; " +
                                  "$authentication; "
              
              
              ## Connect to the data source and open it
              $connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
              $command = New-Object System.Data.OleDb.OleDbCommand $sqlCommand,$connection
              $connection.Open()
              
              ## Fetch the results, and close the connection
              $adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
              $dataset = New-Object System.Data.DataSet
              [void] $adapter.Fill($dataSet)
              $connection.Close()
              
              ## Return all of the rows from their query
              $data = $dataSet.Tables
              
              return $data
              
       }
