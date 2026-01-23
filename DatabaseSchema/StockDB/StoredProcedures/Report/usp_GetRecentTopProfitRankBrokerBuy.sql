-- Stored procedure: [Report].[usp_GetRecentTopProfitRankBrokerBuy]



create PROCEDURE [Report].[usp_GetRecentTopProfitRankBrokerBuy]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetBrokerCode.sql
Stored Procedure Name: usp_GetBrokerCode
Overview
-----------------
usp_GetBrokerCode

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
Date:		2018-12-02
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetBrokerCode'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		if object_id(N'Tempdb.dbo.#TempRecentBR') is not null
			drop table #TempRecentBR

		if object_id(N'Tempdb.dbo.#TempRecentBRRank') is not null
			drop table #TempRecentBRRank

		select y.*
		into #TempRecentBR
		from
		(
			select *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber 
			from
			(
				select ASXCode, ObservationDate
				from StockData.BrokerReport
				group by ASXCode, ObservationDate
			) as a
		) as x
		inner join StockData.BrokerReport as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		where RowNumber <= 5;

		select *
		into #TempRecentBRRank
		from
		(
			select *, row_number() over (partition by ASXCode order by NetVolume desc) as NetVolumeRank
			from
			(
				select ASXCode, BrokerCode, sum(NetVolume) as NetVolume, sum(NetValue) as NetValue    
				from #TempRecentBR
				group by ASXCode, BrokerCode
			) as x
		) as y
		where NetVolumeRank <= 3;

		select * 
		from #TempRecentBRRank as a
		inner join Transform.BrokerProfitLossRank as b
		on a.ASXCode = b.ASXCode
		and a.BrokerCode = b.BrokerCode
		and b.BrokerCode not in ('ComSec', 'WeaSec', 'CMCMar')
		and b.ProfitRank <= 3
		and a.NetValue > 30000
		and a.NetVolumeRank <= 3
		--and a.ASXCode = 'TIE.AX'
		order by a.ASXCode;

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
