-- Stored procedure: [DataMaintenance].[usp_RefreshSectorPerformance]


CREATE PROCEDURE [DataMaintenance].[usp_RefreshSectorPerformance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshSectorPerformance.sql
Stored Procedure Name: usp_RefreshSectorPerformance
Overview
-----------------
usp_RefreshSectorPerformance

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
Date:		2017-03-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetSectorPerformance'
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
		--begin transaction
		declare @intWeekDayNum as int 
		select @intWeekDayNum = datepart(dw, getdate())

		if (@intWeekDayNum in (7, 1) and 0 > 1)
		--if (@intWeekDayNum in (0))
		begin
			print 'Weekend'
		end
		else
		begin
			if object_id(N'Tempdb.dbo.#TempStockKeyToken') is not null
				drop table #TempStockKeyToken

			select distinct
				upper(a.Token) as Token,
				a.ASXCode,
				a.AnnWithTokenPerc,
				case when b.ASXCode is not null then 1 else 0 end ListVerified
			into #TempStockKeyToken
			from LookupRef.KeyToken as c
			inner join StockData.StockKeyToken as a 
			on a.Token = c.Token
			left join LookupRef.StockKeyToken as b
			on a.Token = b.Token
			and a.ASXCode = b.ASXCode
			where c.IsDisabled = 0

			if object_id(N'Tempdb.dbo.#TempStockStatsHistoryRaw') is not null
				drop table #TempStockStatsHistoryRaw

			select 
				ASXCode,
				ObservationDate,
				[close],
				Volume
			into #TempStockStatsHistoryRaw
			from
			(
				select
				ASXCode,
				ObservationDate as ObservationDate,
				[close],
				Volume
				from [StockData].[PriceHistory]
			) as a
			where Volume > 0
		
			insert into #TempStockStatsHistoryRaw
			(
				ASXCode,
				ObservationDate,
				[close],
				Volume
			)
			select 
				ASXCode,
				cast(a.DateFrom as date) as ObservationDate,
				[close],
				Volume
			from [StockData].[PriceSummary] as a
			where not exists
			(
				select 1
				from #TempStockStatsHistoryRaw
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)
			and a.LatestForTheDay = 1

			if object_id(N'Tempdb.dbo.#TempSectorLeader') is not null
				drop table #TempSectorLeader

			select distinct
				Token,
				ASXCode
			into #TempSectorLeader
			from
			(
				select 
					a.Token,
					ASXCode,
					b.TokenType,
					row_number() over (partition by a.Token order by 
										case when AnnWithTokenPerc > 0.20 then 1 else 0 end desc,
										ListVerified desc, 
										isnull(AnnWithTokenPerc, 1) desc
									  ) as RowNumber
				from #TempStockKeyToken as a
				inner join LookupRef.KeyToken as b
				on a.Token = b.Token
				where exists
				(
					select 1
					from #TempStockStatsHistoryRaw
					where ASXCode = a.ASXCode
					and datediff(day, ObservationDate, getdate()) < 20
				)
			) as x
			where x.RowNumber <=
				  case when x.TokenType = 'Sector' then 24
					   when x.TokenType = 'MC' then 9999
				  end
		
			if object_id(N'Tempdb.dbo.#TempStockStatsHistory') is not null
				drop table #TempStockStatsHistory

			select distinct
				a.Token, 
				b.ASXCode,
				b.ObservationDate,
				b.[close],
				b.Volume, 
				b.[close] * b.volume as TradeValue,
				cast(null as int) as NumStockInSector,
				cast(null as bit) as IsFirstDay,
				cast(null as int) as HoldQuantity,
				cast(null as decimal(20, 5)) as HoldValue,
				cast(null as date) as ReferenceOBDate,
				cast(null as date) as PeriodStartDate,
				row_number() over (partition by a.Token, a.ASXCode order by ObservationDate asc) as DateSeqNo 
			into #TempStockStatsHistory
			from #TempSectorLeader as a
			inner join #TempStockStatsHistoryRaw as b
			on a.ASXCode = b.ASXCode
			and datediff(day, ObservationDate, getdate()) <= 365
			and b.Volume > 0

			delete a
			from #TempStockStatsHistory as a
			inner join
			(
				select distinct ASXCode, DateSeqNo
				from #TempStockStatsHistory as x
				where exists
				(
					select 1
					from #TempStockStatsHistory
					where ASXCode = x.ASXCode
					and abs(DateSeqNo - x.DateSeqNo) = 1
					and [Close] > 3 * x.[Close]
				)
			) as b
			on a.ASXCode = b.ASXCode

			update a
			set IsFirstDay = 1
			from #TempStockStatsHistory as a
			inner join
			(
				select
					ASXCode,
					min(ObservationDate) as ObservationDate
				from #TempStockStatsHistory
				group by 
					ASXCode
			) as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate

			insert into #TempStockStatsHistory
			(
			   [Token]
			  ,[ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,Volume
			  ,[TradeValue]
			  ,[NumStockInSector]
			  ,[IsFirstDay]
			  ,[HoldQuantity]
			  ,[HoldValue]
			  ,[ReferenceOBDate]
			  ,[PeriodStartDate]
			)
			select distinct
			   [Token]
			  ,[ASXCode]
			  ,[ObservationDate]
			  ,0 as [Close]
			  ,0 as Volume
			  ,0 as [TradeValue]
			  ,0 as [NumStockInSector]
			  ,null as [IsFirstDay]
			  ,null as [HoldQuantity]
			  ,null as [HoldValue]
			  ,null as [ReferenceOBDate]
			  ,null as [PeriodStartDate]
			from 
			(
				select
					distinct a.Token, a.ASXCode, b.ObservationDate
				from #TempStockStatsHistory as a
				cross join 
				(
					select distinct ObservationDate from #TempStockStatsHistory				
				) as b
			) as x
			where not exists
			(
				select 1
				from #TempStockStatsHistory
				where Token = x.Token
				and ASXCode = x.ASXCode
				and ObservationDate = x.ObservationDate
			)

			update a
			set PeriodStartDate = (select min(ObservationDate) from #TempStockStatsHistory)
			from #TempStockStatsHistory as a

			update a
			set a.NumStockInSector = b.NumStock
			from #TempStockStatsHistory as a
			inner join
			(
				select Token, count(distinct ASXCode) as NumStock
				from #TempStockStatsHistory
				group by Token
			) as b
			on a.Token = b.Token

			update a
			set HoldQuantity = floor((100000.0/NumStockInSector)/[Close])
			from #TempStockStatsHistory as a
			where IsFirstDay = 1

			update a
			set HoldQuantity = b.HoldQuantity
			from #TempStockStatsHistory as a
			inner join #TempStockStatsHistory as b
			on a.ASXCode = b.ASXCode
			where b.IsFirstDay = 1
			and a.Token = b.Token
			and a.HoldQuantity is null

			update a
			set a.[Close] = b.[Close],
				a.[Volume] = b.[Volume],
				a.ReferenceOBDate = b.ObservationDate 
			from #TempStockStatsHistory as a
			inner join #TempStockStatsHistory as b
			on a.PeriodStartDate = a.ObservationDate
			and a.ASXCode = b.ASXCode
			and a.Token = b.Token
			and b.IsFirstDay = 1

			update x
			set x.ReferenceOBDate = y.ReferenceObDate
			from #TempStockStatsHistory as x
			inner join
			(
				select a.ASXCode, a.Token, a.ObservationDate, max(b.ObservationDate) as ReferenceObDate
				from #TempStockStatsHistory as a
				inner join #TempStockStatsHistory as b
				on a.ASXCode = b.ASXCode
				and a.Token = b.Token
				and a.ObservationDate > b.ObservationDate
				and a.[Volume] = 0
				and b.[Volume] > 0
				group by a.ASXCode, a.Token, a.ObservationDate
			) as y
			on x.ASXCode = y.ASXCode
			and x.Token = y.Token
			and x.ObservationDate = y.ObservationDate

			update a
			set a.[Close] = b.[Close],
				a.Volume = b.Volume,
				a.TradeValue = b.TradeValue
			from #TempStockStatsHistory as a
			inner join #TempStockStatsHistory as b
			on a.ReferenceOBDate = b.ObservationDate
			and a.ASXCode = b.ASXCode
			and a.Token = b.Token
			where a.[Volume] = 0
			and b.[Volume] > 0

			update a
			set HoldValue = HoldQuantity* [Close]
			from #TempStockStatsHistory as a

			if object_id(N'Report.SectorPerformance') is not null
				drop table Report.SectorPerformance

			select
				Token, 
				ObservationDate, 
				HoldValue, 
				TradeValue, 
				ASXCode, 
				AvgHoldValue,
				MAAvgHoldKey,
				MAAvgHoldValue
			into Report.SectorPerformance
			from
			(		
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'SMA0' as MAAvgHoldKey,
					sum(HoldValue) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
				union
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'SMA3' as MAAvgHoldKey,
					avg(sum(HoldValue)) OVER (partition by Token ORDER BY ObservationDate ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
				union
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'SMA5' as MAAvgHoldKey,
					avg(sum(HoldValue)) OVER (partition by Token ORDER BY ObservationDate ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
				union
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'SMA10' as MAAvgHoldKey,
					avg(sum(HoldValue)) OVER (partition by Token ORDER BY ObservationDate ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
				union
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'SMA20' as MAAvgHoldKey,
					avg(sum(HoldValue)) OVER (partition by Token ORDER BY ObservationDate ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
				union
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'SMA30' as MAAvgHoldKey,
					avg(sum(HoldValue)) OVER (partition by Token ORDER BY ObservationDate ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
				union
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'VSMA5' as MAAvgHoldKey,
					avg(sum(TradeValue)) over (partition by Token order by ObservationDate rows between 5 preceding and current row) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
				union
				select 
					Token, 
					ObservationDate, 
					sum(HoldValue) as HoldValue, 
					sum(TradeValue) as TradeValue, 
					count(distinct ASXCode) as ASXCode, 
					sum(HoldValue)*1.0/count(distinct ASXCode) as AvgHoldValue,
					'VSMA50' as MAAvgHoldKey,
					avg(sum(TradeValue)) over (partition by Token order by ObservationDate rows between 50 preceding and current row) as MAAvgHoldValue
				from #TempStockStatsHistory as a
				group by Token, ObservationDate
			) as x

			if object_id(N'Report.SectorPerformanceDetails') is not null
				drop table Report.SectorPerformanceDetails

			select *
			into Report.SectorPerformanceDetails
			from #TempStockStatsHistory

		end

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
