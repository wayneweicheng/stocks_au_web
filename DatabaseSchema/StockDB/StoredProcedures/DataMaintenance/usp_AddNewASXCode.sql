-- Stored procedure: [DataMaintenance].[usp_AddNewASXCode]





CREATE PROCEDURE [DataMaintenance].[usp_AddNewASXCode]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddNewASXCode.sql
Stored Procedure Name: usp_AddNewASXCode
Overview
-----------------
usp_AddNewASXCode

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
Date:		2018-02-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddNewASXCode'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempStock') is not null
			drop table #TempStock

		select 
			distinct ASXCode 
		into #TempStock
		from
		(
			select ASXCode
			from StockDAta.PriceHistoryCurrent
			where ObservationDate > Common.DateAddBusinessDay(-5, getdate())
			and len(ASXCode) = 6
			union
			select ASXCode
			from StockDAta.Announcement
			where AnnDateTime > Common.DateAddBusinessDay(-20, getdate())		
			and len(ASXCode) = 6
			union
			select ASXCode
			from StockDAta.CurrentHoldings
			where len(ASXCode) >= 6
		) as x
		where not exists
		(
			select 1
			from StockData.Announcement
			where 1 = 1 
			and AnnDateTime > Common.DateAddBusinessDay(-20, getdate())			
			and 
			(
				AnnDescr like 'mFund%'
				or
				AnnDescr like '%Redemption Report%'
			)
			and ASXCode = x.ASXCode 
		)

		update a
		set a.IsDisabled = 0,
			a.ASXCompanyName = 'Unknown',
			a.[IndustryGroup] = 'Unknown'
		from Stock.ASXCompany as a
		inner join #TempStock as b
		on b.[ASXCode] = a.ASXCode
		and a.IsDisabled = 1

		insert into Stock.ASXCompany
		(
			   [ASXCode]
			  ,[ASXCompanyName]
			  ,[CreateDate]
			  ,[IndustryGroup]
			  ,[IsDisabled]
		)
		select
			   a.[ASXCode] as [ASXCode]
			  ,'Unknown' as [ASXCompanyName]
			  ,getdate() as [CreateDate]
			  ,'Unknown' as [IndustryGroup]
			  ,0 as [IsDisabled]
		from #TempStock as a
		where not exists
		(
			select 1
			from Stock.ASXCompany
			where ASXCode = a.[ASXCode]
		)

		insert into StockData.MonitorStock
		(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			  ,[LastCourseOfSaleDate]
			  ,[StockSource]
		)
		select
			   [ASXCode]
			  ,getdate() as [CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,[MonitorTypeID]
			  ,null as [LastCourseOfSaleDate]
			  ,null as [StockSource]
		from [Stock].[ASXCompany] as a
		cross join 
		(
			select MonitorTypeID 
			from LookupRef.MonitorType as b
			where MonitorTypeID in ('A', 'H', 'I', 'O', 'P')
		) as b
		where a.IsDisabled = 0
		and not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID = b.MonitorTypeID
			and ASXCode = a.ASXCode
		)

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