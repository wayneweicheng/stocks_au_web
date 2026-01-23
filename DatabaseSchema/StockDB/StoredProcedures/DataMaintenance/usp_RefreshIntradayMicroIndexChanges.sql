-- Stored procedure: [DataMaintenance].[usp_RefreshIntradayMicroIndexChanges]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshIntradayMicroIndexChanges]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshIntradayMicroIndexChanges.sql
Stored Procedure Name: usp_RefreshIntradayMicroIndexChanges
Overview
-----------------
usp_RefreshIntradayMicroIndexChanges

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
Date:		2019-09-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshIntradayMicroIndexChanges'
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

		if object_id(N'Tempdb.dbo.#TempHighVolumeSmallCap') is not null
			drop table #TempHighVolumeSmallCap

		select c.MC, a.ASXCode, a.MedianTradeValue, a.MedianTradeValueDaily, a.MedianPriceChangePerc, 
		cast(null as decimal(20, 2)) as CloseVsVWAP,
		cast(null as decimal(20, 2)) as CloseVsOpen, 
		cast(null as decimal(20, 2)) as CloseVsYesterdayClose
		into #TempHighVolumeSmallCap
		from StockData.MedianTradeValue as a
		inner join StockData.PriceHistoryCurrent as b
		on a.ASXCode = b.ASXCode
		inner join StockData.v_CompanyFloatingShare as c
		on a.ASXCode = c.ASXCode
		where MedianPriceChangePerc > 1
		and c.MC < 200
		and [Close] < 10
		and a.MedianTradeValue > 200
		--order by MedianTradeValue desc;
		order by MedianTradeValueDaily desc;

		declare @pdtObservationStartDate as date = cast(getdate() as date)
		declare @pdtObservationDate as date = cast(getdate() as date)
		declare @pdtObservationTime as time = '10:05:00'

		while @pdtObservationDate >= @pdtObservationStartDate
		begin

			select @pdtObservationTime = '10:05:00'
			while @pdtObservationTime < cast('16:20:00' as time) and (cast(getdate() as date) != @pdtObservationDate or @pdtObservationTime <= cast(getdate() as time)) 
			begin
				print @pdtObservationTime

				if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
					drop table #TempPriceSummary

				create table #TempPriceSummary
				(
					UniqueKey int identity(1, 1) not null,
					ASXCode varchar(10) not null,
					[Open] decimal(20, 4),
					[Close] decimal(20, 4),
					[VWAP] decimal(20, 4),
					[PrevClose] decimal(20, 4),
					[Value] decimal(20, 4),
					DateFrom datetime
				)

				insert into #TempPriceSummary
				(
					ASXCode,
					[Open],
					[Close],
					[VWAP],
					[PrevClose],
					[Value],
					DateFrom
				)
				select 
					ASXCode,
					[Open],
					[Close],
					[VWAP],
					[PrevClose],
					[Value],
					DateFrom
				from
				(
					select a.ASXCode, a.[Open], a.[Close], a.[VWAP], a.[PrevClose] as PrevClose, [Value], a.DateFrom, row_number() over (partition by a.ASXCode order by a.DateFrom desc) as RowNumber
					--from StockData.PriceSummaryToday as a with(nolock		
					from StockData.v_PriceSummary as a with(nolock)
					--inner join StockData.PriceHistoryCurrent as b
					--on a.ASXCode = b.ASXCode
					where ObservationDate = @pdtObservationDate
					and cast(DateFrom as time) <= @pdtObservationTime
				) as a
				where RowNumber = 1

				update a
				set
				CloseVsVWAP = b.CloseVsVWAP,
				CloseVsOpen = b.CloseVsOpen, 
				CloseVsYesterdayClose = b.CloseVsYesterdayClose
				from #TempHighVolumeSmallCap as a
				inner join
				(
					select 
						ASXCode, 
						case when h.VWAP > 0 then cast((h.[Close] - h.VWAP)*100.0/h.VWAP as decimal(10, 2)) else null end as CloseVsVWAP,
						case when h.[Open] > 0 then cast((h.[Close] - h.[Open])*100.0/h.[Open] as decimal(10, 2)) else null end as CloseVsOpen,
						case when h.[PrevClose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[PrevClose] as decimal(10, 2)) else null end as CloseVsYesterdayClose
					from #TempPriceSummary as h
				) as b
				on a.ASXCode = b.ASXCode

				delete a
				from StockData.IntradayMicroIndexChanges as a
				where ObservationDate = @pdtObservationDate
				and ObservationTime = @pdtObservationTime

				insert into StockData.IntradayMicroIndexChanges
				(
					ObservationDate,
					ObservationTime,
					VsYesterdayClose_Up,
					VsYesterdayClose_Flat,
					VsYesterdayClose_Down,
					Score,
					VsOpen_Up,
					VsOpen_Flat,
					VsOpenDown,
					VsVWAP_Up,
					VsVWAP_Flat,
					VsVWAPDown,
					NumObs
				)
				select 
					@pdtObservationDate as ObservationDate,
					@pdtObservationTime as ObservationTime,
					cast(x.Up*100.0/x.Total as decimal(10, 2)) as VsYesterdayClose_Up,
					cast(x.Flat*100.0/x.Total as decimal(10, 2)) as VsYesterdayClose_Flat,
					cast(x.Down*100.0/x.Total as decimal(10, 2)) as VsYesterdayClose_Down,
					x.Score as Score,
					cast(y.Up*100.0/y.Total as decimal(10, 2)) as VsOpen_Up,
					cast(y.Flat*100.0/y.Total as decimal(10, 2)) as VsOpen_Flat,
					cast(y.Down*100.0/y.Total as decimal(10, 2)) as VsOpenDown,
					cast(z.Up*100.0/z.Total as decimal(10, 2)) as VsVWAP_Up,
					cast(z.Flat*100.0/z.Total as decimal(10, 2)) as VsVWAP_Flat,
					cast(z.Down*100.0/z.Total as decimal(10, 2)) as VsVWAPDown,
					x.Total as NumObs
				from
				(
					select 
						sum(case when CloseVsYesterdayClose > 0 then 1 else 0 end) as Up,
						sum(case when CloseVsYesterdayClose = 0 then 1 else 0 end) as Flat,
						sum(case when CloseVsYesterdayClose < 0 then 1 else 0 end) as Down,
						sum(
							case 
								 when CloseVsYesterdayClose < 0 and CloseVsYesterdayClose >= -2 then -1
								 when CloseVsYesterdayClose < -2 and CloseVsYesterdayClose >= -4 then -2
								 when CloseVsYesterdayClose < -4 and CloseVsYesterdayClose >= -6 then -3
								 when CloseVsYesterdayClose < -6 and CloseVsYesterdayClose >= -8 then -4
								 when CloseVsYesterdayClose < -8 and CloseVsYesterdayClose >= -10 then -5
								 when CloseVsYesterdayClose < -10 and CloseVsYesterdayClose >= -15 then -6
								 when CloseVsYesterdayClose < -15 and CloseVsYesterdayClose >= -25 then -7
								 when CloseVsYesterdayClose < -25 then -8
								 when CloseVsYesterdayClose = 0 then 0
								 when CloseVsYesterdayClose > 0 and CloseVsYesterdayClose <= 2 then 1
								 when CloseVsYesterdayClose > -2 and CloseVsYesterdayClose <= 4 then 2
								 when CloseVsYesterdayClose > -4 and CloseVsYesterdayClose <= 6 then 3
								 when CloseVsYesterdayClose > -6 and CloseVsYesterdayClose <= 8 then 4
								 when CloseVsYesterdayClose > -8 and CloseVsYesterdayClose <= 10 then 5
								 when CloseVsYesterdayClose > -10 and CloseVsYesterdayClose <= 15 then 6
								 when CloseVsYesterdayClose > -15 and CloseVsYesterdayClose <= 25 then 7
								 when CloseVsYesterdayClose > 25 then 8
							end
						) as Score,
						count(*) as Total
					from #TempHighVolumeSmallCap 
				) as x
				inner join 
				(
					select 
						sum(case when CloseVsOpen > 0 then 1 else 0 end) as Up,
						sum(case when CloseVsOpen = 0 then 1 else 0 end) as Flat,
						sum(case when CloseVsOpen < 0 then 1 else 0 end) as Down,
						count(*) as Total
					from #TempHighVolumeSmallCap 
				) as y
				on 1 = 1
				inner join 
				(
					select 
						sum(case when CloseVsVWAP > 0 then 1 else 0 end) as Up,
						sum(case when CloseVsVWAP = 0 then 1 else 0 end) as Flat,
						sum(case when CloseVsVWAP < 0 then 1 else 0 end) as Down,
						count(*) as Total
					from #TempHighVolumeSmallCap 
				) as z
				on 1 = 1
				where @pdtObservationTime >= '10:10:00'

				if @pdtObservationTime >= '15:30:00' or @pdtObservationTime <= '11:00:00'
				begin
					select @pdtObservationTime = dateadd(minute, 5, @pdtObservationTime) 
				end
				else
				begin
					select @pdtObservationTime = dateadd(minute, 5, @pdtObservationTime) 
				end

			end

			delete a
			from StockData.IntradayMicroIndexChanges as a with(nolock)
			where cast(ObservationTime as time) < '10:10:00'
			and ObservationDate = @pdtObservationDate

			select @pdtObservationDate = Common.DateAddBusinessDay(-1, @pdtObservationDate)
			print @pdtObservationDate 
		end
		
	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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