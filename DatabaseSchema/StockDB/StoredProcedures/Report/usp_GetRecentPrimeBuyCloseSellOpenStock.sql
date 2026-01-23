-- Stored procedure: [Report].[usp_GetRecentPrimeBuyCloseSellOpenStock]


CREATE PROCEDURE [Report].[usp_GetRecentPrimeBuyCloseSellOpenStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintLastNDays as int = 20
AS
/******************************************************************************
File: usp_GetWatchList.sql
Stored Procedure Name: usp_GetWatchList
Overview
-----------------
usp_GetWatchList

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
Date:		2018-06-09
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetWatchList'
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
		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory

		select lag([ObservationDate], 1, null) over (partition by x.ASXCode order by ObservationDate asc) as PrevObservationDate, * 
		into #TempPriceHistory
		from StockData.PriceHistory as x
		where ObservationDate > dateadd(day, -120, getdate())

		--select top 100 * from #TempPriceHistory
		--where ASXCode = 'MGT.AX'
		--order by ObservationDate desc;

		--select a.ASXCode, x.IntraDayChange, x.[Close], x.[Open], x.ObservationDate, x.PrevObservationDate, (x.[Open]-a.[Close])*100.0/x.[Open] as OpenVsPrevClose
		--from #TempPriceHistory as a
		--left join
		--(
		--	select ASXCode, ObservationDate, PrevObservationDate, ([Close] - [Open])*100.0/[Open] as IntraDayChange, [Close], [Open]
		--	from #TempPriceHistory
		--	where [Open] > 0
		--) as x
		--on a.ASXCode = x.ASXCode
		--and a.ObservationDate = x.PrevObservationDate
		--where 1 = 1
		--and a.[Close] > 0.02
		--and a.ASXCode = 'NOV.AX'
		--and a.ObservationDate >= '2021-12-01'
		--order by a.ObservationDate desc;

		select 
			y.ASXCode,
			count(*), 
			avg(OpenVsPrevClose) as AvgProfitPerc, 
			case when sum(case when OpenVsPrevClose != 0 then 1 else 0 end) > 0 then sum(case when OpenVsPrevClose > 0 then 1 else 0 end)*100.0/sum(case when OpenVsPrevClose != 0 then 1 else 0 end) end as PositivePerc,
			format(avg([Value]), 'N0') as AvgTradeValue
		from
		(
			select a.ASXCode, x.IntraDayChange, x.[Close], x.[Open], x.ObservationDate, x.PrevObservationDate, (x.[Open]-a.[Close])*100.0/x.[Open] as OpenVsPrevClose, a.[Value]
			from #TempPriceHistory as a
			left join
			(
				select ASXCode, ObservationDate, PrevObservationDate, ([Close] - [Open])*100.0/[Open] as IntraDayChange, [Close], [Open]
				from #TempPriceHistory
				where [Open] > 0
			) as x
			on a.ASXCode = x.ASXCode
			and a.ObservationDate = x.PrevObservationDate
			where 1 = 1
			and a.[Close] > 0.02
			and a.ObservationDate >= dateadd(day, -1*@pintLastNDays, getdate())
		) as y
		group by y.ASXCode
		having count(*) >= @pintLastNDays*0.6
		and avg([Value]) > 500000
		and avg(OpenVsPrevClose) > 1.0
		order by PositivePerc desc;

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
