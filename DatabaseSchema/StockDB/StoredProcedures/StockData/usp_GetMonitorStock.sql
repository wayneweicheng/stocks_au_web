-- Stored procedure: [StockData].[usp_GetMonitorStock]






CREATE PROCEDURE [StockData].[usp_GetMonitorStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchMonitorStockTypeID as varchar(10),
@pintPriorityLevelMin as int = 20,
@pintPriorityLevelMax as int = 999
AS
/******************************************************************************
File: usp_GetMonitorStock.sql
Stored Procedure Name: usp_GetMonitorStock
Overview
-----------------
usp_GetMonitorStock

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
Date:		2016-05-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMonitorStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
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
		
		declare @pvchASXCode varchar(10)
		declare @pvchStockCode varchar(7)

		if @pvchMonitorStockTypeID = 'C'
		begin
			
			select top 1
			   @pvchASXCode = a.[ASXCode],
			   @pvchStockCode = substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1)
			from StockData.MonitorStock as a with(nolock)
			where MonitorTypeID in ('C', 'X')
			and isnull(PriorityLevel, 999) <= 999
			and charindex('.', a.ASXCode, 0) > 0
			--and ASXCode in ('88E.AX')
			--and datediff(second, isnull(LastMonitorDate, '2010-01-01') , getdate()) > 300
			--and datediff(second, isnull(LastUpdateDate, '2010-01-01') , getdate()) > 300
			order by isnull(LastUpdateDate, '2020-01-01') asc, newid()

			update a
			set UpdateStatus = 1,
				LastUpdateDate = getdate()
			from StockData.MonitorStock as a
			where ASXCode = @pvchASXCode
			and a.MonitorTypeID in ('C', 'X')

			select 
				@pvchASXCode as ASXCode,
				@pvchStockCode as StockCode
			where @pvchASXCode is not null
		
		end	

		if @pvchMonitorStockTypeID = 'M'
		begin
			
			--select
			--	'ALK.AX' as ASXCode,
			--	'ALK' as StockCode

			select top 1
			   @pvchASXCode = a.[ASXCode],
			   @pvchStockCode = substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1)
			from StockData.MonitorStock as a with(nolock)
			where MonitorTypeID = 'M'
			and isnull(PriorityLevel, 999) <= 999
			and charindex('.', a.ASXCode, 0) > 0
			--and ASXCode in ('DEG.AX')
			--and datediff(second, isnull(LastMonitorDate, '2010-01-01') , getdate()) > 300
			--and datediff(second, isnull(LastUpdateDate, '2010-01-01') , getdate()) > 300
			order by isnull(LastUpdateDate, '2020-01-01') asc, newid()

			update a
			set UpdateStatus = 1,
				LastUpdateDate = getdate()
			from StockData.MonitorStock as a
			where ASXCode = @pvchASXCode
			and a.MonitorTypeID = 'M'

			select 
				@pvchASXCode as ASXCode,
				@pvchStockCode as StockCode
			where @pvchASXCode is not null
			
			--select top 1
			--   @pvchASXCode = a.[ASXCode],
			--   @pvchStockCode = substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1)
			--from StockData.MonitorStock as a
			----where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
			--where a.MonitorTypeID = 'M'
			--and isnull(PriorityLevel, 999) >= @pintPriorityLevelMin
			--and isnull(PriorityLevel, 999) <= @pintPriorityLevelMax
			--and
			--(
			--	(
			--		1 > 0 and isnull(a.UpdateStatus, 0) = 0
			--	)
			--	or
			--	(
			--		datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 600 and isnull(a.UpdateStatus, 0) = 1 
			--	)
			--)
			--order by 
			--	isnull(a.LastUpdateDate, '2010-01-12'), ASXCode

			--update a
			--set UpdateStatus = 1,
			--	LastUpdateDate = getdate()
			--from StockData.MonitorStock as a
			--where ASXCode = @pvchASXCode
			--and a.MonitorTypeID = 'M'

			--select 
			--	@pvchASXCode as ASXCode,
			--	@pvchStockCode as StockCode
			--where @pvchASXCode is not null
		
		end	

		if @pvchMonitorStockTypeID = 'A'
		begin
			select top 1
			   @pvchASXCode = a.[ASXCode],
			   @pvchStockCode = substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1)
			from StockData.MonitorStock as a
			--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
			where a.MonitorTypeID = 'A'
			--and ASXCode = 'GBR.AX'
			and charindex('.', a.ASXCode, 0) > 0
			and
			(
				datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 30
				or
				isnull(a.UpdateStatus, 0) = 0
			)
			and exists
			(
				select 1
				from StockData.PriceHistory
				where ASXCode = a.ASXCode
				and ObservationDate > dateadd(day, -20, getdate()) 
				and Volume > 0
			)
			order by isnull(a.LastUpdateDate, '2010-01-12') asc

			update a
			set UpdateStatus = 1,
				LastUpdateDate = getdate()
			from StockData.MonitorStock as a
			where ASXCode = @pvchASXCode
			and a.MonitorTypeID = 'A'

			select 
				@pvchASXCode as ASXCode,
				@pvchStockCode as StockCode
			where @pvchASXCode is not null
		
		end
		
		if @pvchMonitorStockTypeID = 'O'
		begin

			select 
			   a.[ASXCode],
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode
			from StockData.MonitorStock as a
			--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
			where a.MonitorTypeID = 'O'
			--and a.ASXCode = 'EYM.AX'
			and len(a.ASXCode) = 6
			and charindex('.', a.ASXCode, 0) > 0
			and exists
			(
				select 1
				from [StockData].[WatchListStock]
				where ASXCode = a.ASXCode
			)
			and
			(
				datediff(day, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 3
				or
				isnull(a.UpdateStatus, 0) = 0
			)
			and not exists
			(
				select 1
				from StockData.CompanyInfo
				where ASXCode = a.ASXCode
				and datediff(day, LastValidateDate, getdate()) <= 3
			)
			and exists
			(
				select 1
				from StockData.Announcement
				where AnnDateTime > dateadd(day, -180, getdate())
				and ASXCode = A.ASXCode
			)
			order by datediff(minute, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) desc, newid()

		end	

		if @pvchMonitorStockTypeID = 'P'
		begin
			select *
			from
			(
				select 
				   a.[ASXCode],
				   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
				   a.LastUpdateDate,
				   max(b.AnnDateTime) as AnnDateTime
				from StockData.MonitorStock as a
				inner join StockData.Announcement as b
				on a.ASXCode = b.ASXCode
				and 
				(
					b.AnnDescr like '%capital%'
					or
					b.AnnDescr like '%rais%'
					or
					b.AnnDescr like '%placement%'
					or
					b.AnnDescr like '%SPP%'
					or
					b.AnnDescr like '%Proposed issue%'
					or
					b.AnnDescr like '%Trading halt%'
				)
				and a.MonitorTypeID = 'P'
				and charindex('.', a.ASXCode, 0) > 0
				--and a.ASXCode = 'SYA.AX'
				and not exists
				(
					select 1
					from StockData.PlaceHistory
					where ASXCode = a.ASXCode
					and PlacementDate > b.AnnDateTime
				)
				--and isnull(a.LastUpdateDate, '2010-01-12') <= b.AnnDateTime
				and
				(
					datediff(day, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 0
					or
					isnull(a.UpdateStatus, 0) = 0
				)
				group by 
				   a.[ASXCode],
				   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1),
				   a.LastUpdateDate
			) as x
			order by AnnDateTime desc, datediff(minute, isnull(LastUpdateDate, '2010-01-12'), getdate()) desc, newid()		
		end	

		if @pvchMonitorStockTypeID = 'E'
		begin
			if object_id(N'Tempdb.dbo.#TempEOD') is not null
				drop table #TempEOD

			select 
			   a.[ASXCode],
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			   a.LastUpdateDate
			into #TempEOD
			from StockData.MonitorStock as a
			--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
			where a.MonitorTypeID = 'E'
			and charindex('.', a.ASXCode, 0) > 0
			and
			(
				datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 30
				or
				isnull(a.UpdateStatus, 0) = 0
			)
			order by isnull(a.LastUpdateDate, '2010-01-12') asc

			delete a 
			from #TempEOD as a
			left join StockData.PriceHistoryCurrent as b
			on a.ASXCode = b.ASXCode
			where 
			(
				b.[Close] > 2.5
				or
				b.[Close] is null
				or
				datediff(day, b.ObservationDate, getdate()) > 15
				or
				b.Volume = 0
			)
			and not exists
			(
				select 1
				from HC.CommonStockPlusHistory
				where datediff(day, CreateDate, getdate()) < 20
				and ASXCode = a.ASXCode
			)
			and not exists
			(
				select 1
				from [LookupRef].[StockKeyToken]
				where 1 = 1
				and ASXCode = a.ASXCode
			)

			select top 1
			   @pvchASXCode = a.[ASXCode],
			   @pvchStockCode = substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1)
			from #TempEOD as a
			order by isnull(a.LastUpdateDate, '2010-01-12') asc

			update a
			set UpdateStatus = 1,
				LastUpdateDate = getdate()
			from StockData.MonitorStock as a
			where ASXCode = @pvchASXCode
			and a.MonitorTypeID = 'E'

			select 
				@pvchASXCode as ASXCode,
				@pvchStockCode as StockCode
			where @pvchASXCode is not null
		
		end

		if @pvchMonitorStockTypeID in ('T')
		begin
			if object_id(N'Tempdb.dbo.#TempHCLastUpdateDate') is not null
				drop table #TempHCLastUpdateDate

			select ASXCode, max(CreateDate) as LastUpdateDate 
			into #TempHCLastUpdateDate
			from HC.PostRaw
			group by ASXCode

			if object_id(N'Tempdb.dbo.#TempReturn') is not null
				drop table #TempReturn

			select 
			   a.[ASXCode] as ASXCode,
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			   cast(null as int) as RunOrder
			into #TempReturn
			from StockData.MonitorStock as a
			left join #TempHCLastUpdateDate as b
			on a.ASXCode = b.ASXCode
			left join StockData.PriceHistoryCurrent as c
			on a.ASXCode = c.ASXCode
			left join StockData.WatchListStock as d
			on a.ASXCode = d.ASXCode
			where a.MonitorTypeID = 'T' --@pvchMonitorStockTypeID
			and charindex('.', a.ASXCode, 0) > 0
			--and a.ASXCode = 'BIT.AX'
			--and not exists
			--(
			--	select 1
			--	from StockData.PriceHistory
			--	where ASXCode = a.ASXCode
			--)
			and isnull(c.[Close], 0) < 10
			--order by isnull(b.LastUpdateDate, '2001-01-12') asc, a.ASXCode asc
		
			declare @vchHCLastSearch as varchar(10)
			select top 1 @vchHCLastSearch = ASXCode
			from HC.PostScan
			order by CreateDate desc

			--select @vchHCLastSearch

			update a
			set a.RunOrder = b.RowNumber
			from #TempReturn as a
			inner join 
			(
				select
					ASXCode,
					row_number() over (order by case when ASXCode >= @vchHCLastSearch then 1 else 0 end desc, ASXCode) as RowNumber
				from #TempReturn
			) as b
			on a.ASXCode = b.ASXCode

			select
				ASXCode,
				StockCode
			from #TempReturn
			where ASXCode in (select ASXCode from StockData.MonitorStock where MonitorTypeID = 'C' and isnull(PriorityLevel, 999) <= 999)
			order by RunOrder

		end	

		if @pvchMonitorStockTypeID in ('H')
		begin
			--if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			--	drop table #TempPriceHistory

			--select ASXCode, max(ModifyDate) as ModifyDate
			--into #TempPriceHistory
			--from StockData.PriceHistory
			--group by ASXCode
			
			select 
			   a.[ASXCode] as ASXCode,
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode
			from StockData.MonitorStock as a
			--left join #TempPriceHistory as b
			--on a.ASXCode = b.ASXCode
			--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
			where a.MonitorTypeID = 'H'
			and charindex('.', a.ASXCode, 0) > 0
			--and a.ASXCode in ('CC9.AX')
			--and not exists
			--(
			--	select 1
			--	from StockData.PriceHistorySecondary
			--	where ASXCode = a.ASXCode
			--	and Exchange = 'ASX'
			--)
			--order by isnull(b.ModifyDate, '2050-01-12') asc
			--and a.ASXCode in ('GOLD:US.US', 'GDX:US.US', 'GDXJ:US.US')
			order by newid()
		end	

		if @pvchMonitorStockTypeID in ('D')
		begin
			select 
			   a.[ASXCode] as ASXCode,
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode
			from StockData.MonitorStock as a
			where a.MonitorTypeID = 'D'
			and charindex('.', a.ASXCode, 0) > 0
			--and a.ASXCode in ('STO.AX', 'NST.AX', 'PRU.AX', 'PLS.AX', 'AKE.AX', 'LTR.AX', 'CBA.AX', 'EVN.AX', 'RMS.AX', 'EVN.AX', 'RRL.AX', 'NCM.AX', 'WGX.AX', 'WDS.AX', 'WHC.AX')
			--and left(ASXCode, 3) in ('AKE', 'LTR', 'PLS', 'SYA', 'CXO', 'NVX', 'RNU', 'PRU', 'DEG', 'FLT', 'CHN', 'BRN', 'SLR', 'BGL', 'GRR', 'STX', 'AGY', 'PNV', 'SYR', 'ZIP', 'LLL', 'PBH', 'NWE', 'ARU', 'TER')
			--and left(ASXCode, 3) in ('AKE')
			and exists
			(
				select 1
				from [StockDB].[Stock].[ASXCompany]
				where ASXCode = a.ASXCode
				and ASX300 = 1
			)
			order by newid()

		end	

		if @pvchMonitorStockTypeID in ('R')
		begin
			
			select top 1
			   a.[ASXCode] as ASXCode,
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode
			from AutoTrade.TradeRequest as a
			where RequestStatus = 'R'
			and charindex('.', a.ASXCode, 0) > 0
			and RequestValidUntil > getdate()
			and isnull(ErrorCount, 0) < 5
			and not exists(
				select 1
				from AutoTrade.RequestProcessHistory
				where AccountNumber = a.AccountNumber
				and TradeRequestID = a.TradeRequestID
			)
			and not exists(
				select 1
				from AutoTrade.RequestProcessHistory
				where TradeRequestID = a.TradeRequestID
				and datediff(second, CreateDate, getdate()) < 20
			)
			order by TradeRank, CreateDate desc

		end	

		if @pvchMonitorStockTypeID in ('B')
		begin
			select 
				APIBrokerName
			from LookupRef.BrokerName as a
			where APIBrokerName is not null
			--and APIBrokerName = 'Macqua'
			--and a.BrokerCode in 
			--(
			--	--'Canacc',
			--	--'ELCBai',
			--	--'FinClrSrv',
			--	--'EurHar',
			--	--'NinMle',
			--	--'VirITG',
			--	--'BarInv',
			--	'BarrJoey'
			--)
			and a.BrokerCode not in 
			(
				'BaiHol',
				'HarLim',
				'ItgAus',
				--'PatSec',
				'PerShn'
			)
			order by newid()
		end	

		if @pvchMonitorStockTypeID in ('S')
		begin
			select 
			   a.[ASXCode] as ASXCode,
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode
			from 
			(
				select distinct ASXCode
				from StockData.v_PriceSummary_Latest
				where Volume > 0
				and ObservationDate > dateadd(day, -30, getdate())
			) as a
		end

		if @pvchMonitorStockTypeID in ('I')
		begin

			select 
			   'DJIA' as ASXCode,
			   'DJIA' as StockCode
			from StockData.MonitorStock as a
			union
			select 
			   'SPX' as ASXCode,
			   'SPX' as StockCode
			from StockData.MonitorStock as a
			union
			select 
			   'GOLD' as ASXCode,
			   'GOLD' as StockCode
			from StockData.MonitorStock as a
			union
			select 
			   'XAO.AX' as ASXCode,
			   'XAO.AX' as StockCode
			from StockData.MonitorStock as a
			union
			select 
			   'XJO.AX' as ASXCode,
			   'XJO.AX' as StockCode
			from StockData.MonitorStock as a
			--union
			--select 
			--   'XSO.AX' as ASXCode,
			--   'XSO.AX' as StockCode
			--from StockData.MonitorStock as a
			--union
			--select 
			--   'XEC.AX' as ASXCode,
			--   'XEC.AX' as StockCode
			--from StockData.MonitorStock as a
			union
			select 
			   'BBUS.AX' as ASXCode,
			   'BBUS.AX' as StockCode
			from StockData.MonitorStock as a
			union
			select 
			   'BBOZ.AX' as ASXCode,
			   'BBOZ.AX' as StockCode
			from StockData.MonitorStock as a
			union
			select
			   a.[ASXCode] as ASXCode,
			   --substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			   a.[ASXCode] as StockCode
			from StockData.MedianTradeValue as a
			where MedianTradeValueDaily > 50

		end	

		--Alert price history 30min
		if @pvchMonitorStockTypeID in ('APH30M')
		begin
			select a.[ASXCode] as ASXCode, 
			   substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			   b.Value as TradeValue,
			   case when b.Prev1Close> 0 then (b.[close] - b.PrevClose)*100.0/b.PrevClose else null end as PriceChange
			from StockData.v_PriceSummary as a
			inner join 
			(
				select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
				from StockData.v_PriceSummary
				where [Value] > 0
				and ObservationDate = cast(getdate() as date)
			) as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			where a.ObservationDate = cast(getdate() as date)
			--and ASXCode = 'DYL.AX'
			and a.DateTo is null
			and b.RowNumber = 1
			and b.[Value] > 100000
			and case when b.Prev1Close> 0 then (b.[close] - b.PrevClose)*100.0/b.PrevClose else null end > 1.5
			and not exists
			(
				select *
				from StockAPI.PushNotification
				where PushType = '30mins SMA alert'
				and ASXCode = a.ASXCode
				and cast(CreateDate as date) = cast(getdate() as date)
			)
		end

		--Alert price history 30min
		if @pvchMonitorStockTypeID in ('SPXWOIRF')
		begin
			select a.* 
			from StockDB_US.Transform.OptionGEXChange as a
			inner join
			(
				select max(ObservationDate) as ObservationDate 
				from StockDB_US.StockData.v_OptionDelayedQuote
				where ASXCode = 'SPXW.US'
			) as b
			on a.ObservationDate = b.ObservationDate
			where ASXCode = 'SPXW.US'
			and GEXDeltaAdjusted != 0
			and not exists
			(
				select *
				from StockAPI.PushNotification
				where PushType = @pvchMonitorStockTypeID
				and cast(CreateDate as date) = cast(getdate() as date)
			)
		end

		if @pvchMonitorStockTypeID in ('QQQOIRF')
		begin
			select a.* 
			from StockDB_US.Transform.OptionGEXChange as a
			inner join
			(
				select max(ObservationDate) as ObservationDate 
				from StockDB_US.StockData.v_OptionDelayedQuote
				where ASXCode = 'QQQ.US'
			) as b
			on a.ObservationDate = b.ObservationDate
			where ASXCode = 'QQQ.US'
			and GEXDeltaAdjusted != 0
			and not exists
			(
				select *
				from StockAPI.PushNotification
				where PushType = @pvchMonitorStockTypeID
				and cast(CreateDate as date) = cast(getdate() as date)
			)
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

	--	IF @@TRANCOUNT > 0
	--	BEGIN
	--		ROLLBACK TRANSACTION
	--	END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
