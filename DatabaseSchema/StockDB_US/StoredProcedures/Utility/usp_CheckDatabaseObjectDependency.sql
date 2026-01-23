-- Stored procedure: [Utility].[usp_CheckDatabaseObjectDependency]





CREATE PROCEDURE [Utility].[usp_CheckDatabaseObjectDependency]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchSchemaName as varchar(100),
@pvchObjectName as varchar(100) 
AS
/******************************************************************************
File: usp_CheckDatabaseObjectDependency.sql
Stored Procedure Name: usp_CheckDatabaseObjectDependency
Overview
-----------------
usp_CheckDatabaseObjectDependency

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2020-10-18
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_CheckDatabaseObjectDependency'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Utility'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--begin transaction
		declare @vchSchemaName as varchar(100) = @pvchSchemaName
		declare @vchObjectName as varchar(100) = @pvchObjectName;

		WITH DepTree (referenced_id, referenced_name, referencing_id, referencing_name, referencing_schema_name, create_date, modify_date, object_type, NestLevel)
		 AS 
		(
			SELECT  o.[object_id] AS referenced_id , 
			 o.name AS referenced_name, 
			 o.[object_id] AS referencing_id, 
			 o.name AS referencing_name,  
			 schema_name(o.schema_id) as referencing_schema_name,
			 o.create_date, 
			 o.modify_date,
			 o.type_desc as object_type,
			 0 AS NestLevel
			FROM  sys.objects o 
			WHERE o.name = @vchObjectName
			and schema_id = schema_id(@vchSchemaName)
			UNION ALL    
			SELECT  d1.referenced_id,  
			 OBJECT_NAME( d1.referenced_id) , 
			 d1.referencing_id, 
			 OBJECT_NAME( d1.referencing_id) , 
			 schema_name(b.schema_id) as referencing_schema_name,
			 b.create_date, 
			 b.modify_date,
			 b.type_desc as object_type,
			 NestLevel + 1
			 FROM  sys.sql_expression_dependencies d1
			 inner join sys.objects as b
			 on d1.referencing_id = b.object_id
			 and b.type_desc in 
			 (
				'SQL_STORED_PROCEDURE', 
				'VIEW',
				'USER_TABLE'
			 ) 
		  JOIN DepTree r ON d1.referenced_id =  r.referencing_id
		)
		SELECT DISTINCT referenced_id, referenced_name, referencing_id, referencing_name, referencing_schema_name, create_date, modify_date, object_type, NestLevel
		 FROM DepTree WHERE NestLevel <= 1
		ORDER BY NestLevel, modify_date desc
		option (maxrecursion 0); 

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occured in this procedure

		--COMMIT TRANSACTION 

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
		END
	END

	ELSE
	BEGIN

		--IF @@TRANCOUNT > 0
		--BEGIN
		--	ROLLBACK TRANSACTION
		--END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
