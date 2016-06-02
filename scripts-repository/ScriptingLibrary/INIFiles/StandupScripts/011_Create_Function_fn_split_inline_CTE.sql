
USE master
GO

IF OBJECT_ID( 'fn_split_inline_cte' ) IS NOT NULL 
    DROP FUNCTION [fn_split_inline_cte]
GO

CREATE FUNCTION [dbo].[fn_split_inline_cte]  
 (@list  NVARCHAR(MAX),  
  @delimiter NCHAR(1) = ',')   
    RETURNS TABLE   
AS  
  
RETURN  
    WITH cte_list([BeginChar], [EndChar]) AS (  
        SELECT [BeginChar] = CONVERT(BIGINT, 1), [EndChar] = CHARINDEX(@delimiter, @list + @delimiter)  
    UNION ALL  
        SELECT [BeginChar] = [EndChar] + 1, [EndChar] = CHARINDEX(@delimiter, @list + @delimiter, [EndChar] + 1)  
    FROM cte_list  
        WHERE  [EndChar] > 0  
    )  
    SELECT LTRIM(RTRIM(SUBSTRING(@list, [BeginChar],  
        CASE WHEN [EndChar] > 0 THEN [EndChar] - [BeginChar] ELSE 0 END))) AS [ParsedValue]  
    FROM cte_list  
        WHERE [EndChar] > 0 ;  

GO

