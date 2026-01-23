-- Stored procedure: [StockData].[usp_AddInverseEquityETF]



CREATE PROCEDURE [StockData].[usp_AddInverseEquityETF]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchEquityCode as varchar(20),
@pvchSharesOutstanding as varchar(50),
@pvchTotalNetAssets as varchar(50),
@pvchTotalNav as varchar(50),
@pvchNavDate as varchar(50),
@pvchAverageVolume as varchar(50)
AS
/******************************************************************************
File: usp_AddInverseEquityETF.sql
Stored Procedure Name: usp_AddInverseEquityETF
Overview
-----------------
usp_AddInverseEquityETF

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
Date:		2022-05-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddInverseEquityETF'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchASXCode as varchar(100) = 'PLS.AX'
		--declare @pvchCompanyInfo as varchar(100) = '{}'

		--Code goes here 
		set dateformat mdy
		--declare @pvchEquityCode as varchar(20) = 'SH'
		--declare @pvchSharesOutstanding as varchar(50) = '69100.55'
		--declare @pvchTotalNetAssets as varchar(50) = '3317800573.7127'
		--declare @pvchTotalNav as varchar(50) = '48.0141'
		--declare @pvchNavDate as varchar(50) = '06/03/2022'
		--declare @pvchAverageVolume as varchar(50) = '-1'

		if object_id(N'Tempdb.dbo.#TempInverseEquityETF') is not null
			drop table #TempInverseEquityETF

		select
	       upper(@pvchEquityCode) as EquityCode
		  ,try_cast(replace(replace(@pvchSharesOutstanding, ',', ''), 'M', '') as decimal(20, 4))/1000.0 as [SharesOutstandingInM]
		  ,try_cast(@pvchTotalNetAssets as decimal(20, 2))/1000000.0 as [TotalNetAssetsInM]
		  ,try_cast(replace(replace(@pvchTotalNav, '$', ''), ' ', '') as decimal(20, 4)) as [TotalNAV]
		  ,try_cast(@pvchNavDate as date) as [NAVDate]
		  ,try_cast(replace(replace(@pvchAverageVolume, 'M', ''), ' ', '') as decimal(20, 4)) as [AverageVolumeInM]
		into #TempInverseEquityETF

		delete a
		from StockData.InverseEquityETF as a
		inner join #TempInverseEquityETF as b
		on a.EquityCode = b.EquityCode
		and a.NAVDate = b.NAVDate
		and a.NAVDate > dateadd(day, -5, getdate())
		
		insert into StockData.InverseEquityETF
		(
			EquityCode,
			SharesOutstandingInM,
			TotalNetAssetsInM,
			TotalNAV,
			NAVDate,
			AverageVolumeInM,
			CreateDate
		)
		select
			EquityCode,
			SharesOutstandingInM,
			TotalNetAssetsInM,
			TotalNAV,
			NAVDate,
			AverageVolumeInM,
			getdate() as CreateDate
		from #TempInverseEquityETF as a
		where not exists
		(
			select 1
			from StockData.InverseEquityETF
			where NAVDate = a.NAVDate
			and EquityCode = a.EquityCode
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
