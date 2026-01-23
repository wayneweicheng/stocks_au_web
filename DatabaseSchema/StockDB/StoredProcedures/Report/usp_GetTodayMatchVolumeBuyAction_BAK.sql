-- Stored procedure: [Report].[usp_GetTodayMatchVolumeBuyAction_BAK]


CREATE PROCEDURE [Report].[usp_GetTodayMatchVolumeBuyAction]
@pbitDebug AS BIT = 0,
@pvchASXCode varchar(10),
@pdtObservationDate date = null,
@pdecIndicativePrice decimal(20, 4) = null,
@pintMatchVolume int = null,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetTodayMatchVolumeBuyAction.sql
Stored Procedure Name: usp_GetTodayMatchVolumeBuyAction
Overview
-----------------
usp_GetTodayMatchVolumeBuyAction

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
Date:		2021-10-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTodayMatchVolumeBuyAction'
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
		--declare @pvchASXCode as varchar(10) = 'CXO.AX'
		--declare @pdtObservationDate as date = '2022-04-05'

		--select 'Y' as BuyAction, 1000 as BuyValue

		if @pdtObservationDate is null
		begin
			select @pdtObservationDate = cast(getdate() as date)
		end
		

		if object_id(N'Tempdb.dbo.#TempMatchVolume') is not null
			drop table #TempMatchVolume
		
		select 
		   [ASXCode]
		  ,[Bid]
		  ,[Offer]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Close]
		  ,[Volume]
		  ,[Value]
		  ,[Trades]
		  ,[VWAP]
		  ,[DateFrom]
		  ,[DateTo]
		  ,[LastVerifiedDate]
		  ,[bids]
		  ,[bidsTotalVolume]
		  ,[offers]
		  ,[offersTotalVolume]
		  ,[IndicativePrice]
		  ,[SurplusVolume]
		  ,[PrevClose]
		  ,[SysLastSaleDate]
		  ,[SysCreateDate]
		  ,[Prev1PriceSummaryID]
		  ,[Prev1Bid]
		  ,[Prev1Offer]
		  ,[Prev1Volume]
		  ,[Prev1Value]
		  ,[VolumeDelta]
		  ,[ValueDelta]
		  ,[TimeIntervalInSec]
		  ,[BuySellInd]
		  ,[Prev1Close]
		  ,[LatestForTheDay]
		  ,[ObservationDate]
		  ,[MatchVolume]
		  ,[SeqNumber]
		into #TempMatchVolume
		from StockData.PriceSummary with(nolock)
		where 1 != 1
		
		if @pdtObservationDate  = cast(getdate() as date) and cast(getdate() as time) < cast('17:00:00' as time)
		begin
			insert into #TempMatchVolume
			(
			   [ASXCode]
			  ,[Bid]
			  ,[Offer]
			  ,[Open]
			  ,[High]
			  ,[Low]
			  ,[Close]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,[DateTo]
			  ,[LastVerifiedDate]
			  ,[bids]
			  ,[bidsTotalVolume]
			  ,[offers]
			  ,[offersTotalVolume]
			  ,[IndicativePrice]
			  ,[SurplusVolume]
			  ,[PrevClose]
			  ,[SysLastSaleDate]
			  ,[SysCreateDate]
			  ,[Prev1PriceSummaryID]
			  ,[Prev1Bid]
			  ,[Prev1Offer]
			  ,[Prev1Volume]
			  ,[Prev1Value]
			  ,[VolumeDelta]
			  ,[ValueDelta]
			  ,[TimeIntervalInSec]
			  ,[BuySellInd]
			  ,[Prev1Close]
			  ,[LatestForTheDay]
			  ,[ObservationDate]
			  ,[MatchVolume]
			  ,[SeqNumber]
			)
			select 
			   [ASXCode]
			  ,[Bid]
			  ,[Offer]
			  ,[Open]
			  ,[High]
			  ,[Low]
			  ,[Close]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,[DateTo]
			  ,[LastVerifiedDate]
			  ,[bids]
			  ,[bidsTotalVolume]
			  ,[offers]
			  ,[offersTotalVolume]
			  ,[IndicativePrice]
			  ,[SurplusVolume]
			  ,[PrevClose]
			  ,[SysLastSaleDate]
			  ,[SysCreateDate]
			  ,[Prev1PriceSummaryID]
			  ,[Prev1Bid]
			  ,[Prev1Offer]
			  ,[Prev1Volume]
			  ,[Prev1Value]
			  ,[VolumeDelta]
			  ,[ValueDelta]
			  ,[TimeIntervalInSec]
			  ,[BuySellInd]
			  ,[Prev1Close]
			  ,[LatestForTheDay]
			  ,[ObservationDate]
			  ,[MatchVolume]
			  ,[SeqNumber]
			from StockData.PriceSummaryToday with(nolock)
			where ASXCode = @pvchASXCode
			and ObservationDate = @pdtObservationDate
			order by DateFrom asc;
		end
		else
		begin
			insert into #TempMatchVolume
			(
			   [ASXCode]
			  ,[Bid]
			  ,[Offer]
			  ,[Open]
			  ,[High]
			  ,[Low]
			  ,[Close]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,[DateTo]
			  ,[LastVerifiedDate]
			  ,[bids]
			  ,[bidsTotalVolume]
			  ,[offers]
			  ,[offersTotalVolume]
			  ,[IndicativePrice]
			  ,[SurplusVolume]
			  ,[PrevClose]
			  ,[SysLastSaleDate]
			  ,[SysCreateDate]
			  ,[Prev1PriceSummaryID]
			  ,[Prev1Bid]
			  ,[Prev1Offer]
			  ,[Prev1Volume]
			  ,[Prev1Value]
			  ,[VolumeDelta]
			  ,[ValueDelta]
			  ,[TimeIntervalInSec]
			  ,[BuySellInd]
			  ,[Prev1Close]
			  ,[LatestForTheDay]
			  ,[ObservationDate]
			  ,[MatchVolume]
			  ,[SeqNumber]
			)
			select 
			   [ASXCode]
			  ,[Bid]
			  ,[Offer]
			  ,[Open]
			  ,[High]
			  ,[Low]
			  ,[Close]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,[DateTo]
			  ,[LastVerifiedDate]
			  ,[bids]
			  ,[bidsTotalVolume]
			  ,[offers]
			  ,[offersTotalVolume]
			  ,[IndicativePrice]
			  ,[SurplusVolume]
			  ,[PrevClose]
			  ,[SysLastSaleDate]
			  ,[SysCreateDate]
			  ,[Prev1PriceSummaryID]
			  ,[Prev1Bid]
			  ,[Prev1Offer]
			  ,[Prev1Volume]
			  ,[Prev1Value]
			  ,[VolumeDelta]
			  ,[ValueDelta]
			  ,[TimeIntervalInSec]
			  ,[BuySellInd]
			  ,[Prev1Close]
			  ,[LatestForTheDay]
			  ,[ObservationDate]
			  ,[MatchVolume]
			  ,[SeqNumber]
			from StockData.PriceSummary with(nolock)
			where ASXCode = @pvchASXCode
			and ObservationDate = @pdtObservationDate
			order by DateFrom asc;
		end

		--if exists
		--(
		--	select 1
		--	from #TempMatchVolume
		--	where DateTo is null
		--	and Volume > 0
		--) and @pdtObservationDate = cast(getdate() as date)
		--begin
		--	select 'N' as BuyAction, cast(null as decimal(20, 4)) as BuyValue
		--	return
		--end

		delete a
		from #TempMatchVolume as a
		where [Open] > 0
		or IndicativePrice = 0

		if object_id(N'Tempdb.dbo.#TempMatchVolume2') is not null
			drop table #TempMatchVolume2

		select 
			row_number() over (order by DateFrom desc) as VolumeOrder, 
			row_number() over (order by DateFrom asc) as InverseVolumeOrder, 
			cast(null as bit) as BidUp,
			cast(null as bit) as BidDown,
			*
		into #TempMatchVolume2
		from #TempMatchVolume as a
		where datediff(second, datefrom, (select max(SysCreateDate) from #TempMatchVolume)) < 180

		update a
		set a.BidUp = 1
		from #TempMatchVolume2 as a
		inner join #TempMatchVolume2 as b
		on a.VolumeOrder + 1 = b.VolumeOrder
		and a.IndicativePrice > b.IndicativePrice
		where a.BidUp is null	

		update a
		set a.BidUp = 1
		from #TempMatchVolume2 as a
		inner join #TempMatchVolume2 as b
		on a.VolumeOrder + 1 = b.VolumeOrder
		and a.IndicativePrice = b.IndicativePrice 
		and a.SurplusVolume > b.SurplusVolume
		where a.BidUp is null
				
		update a
		set a.BidDown = 1
		from #TempMatchVolume2 as a
		inner join #TempMatchVolume2 as b
		on a.VolumeOrder + 1 = b.VolumeOrder
		and a.IndicativePrice < b.IndicativePrice
		where a.BidDown is null	

		update a
		set a.BidDown = 1
		from #TempMatchVolume2 as a
		inner join #TempMatchVolume2 as b
		on a.VolumeOrder + 1 = b.VolumeOrder
		and a.IndicativePrice = b.IndicativePrice 
		and a.SurplusVolume < b.SurplusVolume
		where a.BidDown is null

		delete a
		from #TempMatchVolume2 as a
		where datediff(second, datefrom, (select max(SysCreateDate) from #TempMatchVolume)) > 120

		--declare @pvchASXCode as varchar(10) = 'CXO.AX'

		if exists
		(
			select 1
			from #TempMatchVolume2 as a
			inner join #TempMatchVolume2 as b
			on a.VolumeOrder = 1
			and b.VolumeOrder = 2
			and a.IndicativePrice > b.IndicativePrice
		 ) and not exists
		 (

			select 1
			from #TempMatchVolume2 as a
			inner join #TempMatchVolume2 as b
			on a.VolumeOrder = 2
			and b.VolumeOrder = 3
			and a.IndicativePrice < b.IndicativePrice
		 )
		begin
			insert into [StockData].[TradeActionCheck]
			(
				[ASXCode],
				[ObservationDate],
				NumDetailRecord,
				[TradeAction],
				[TradeValue],
				[ActionRule],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				(select min(ObservationDate) from #TempMatchVolume2) as [ObservationDate],
				(select count(ASXCode) from #TempMatchVolume2) as NumDetailRecord,
				'B' as [TradeAction],
				'IndicativePrice is up' as [ActionRule],
				cast(10000 as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate

			select 'B' as TradeAction, cast(10000 as decimal(20, 4)) as TradeValue

			return
		end
		
		if exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 3
			and BidUp = 1
		) 
		and exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 2
			and BidUp = 1
		) 
		and exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 1
			and BidUp = 1
		) 
		--and exists
		--(
		--	select 1
		--	from #TempMatchVolume2 as a
		--	inner join #TempMatchVolume2 as b
		--	on a.VolumeOrder = 1
		--	and b.InverseVolumeOrder = 2
		--	and a.IndicativePrice > b.IndicativePrice
		--)
		begin
			insert into [StockData].[TradeActionCheck]
			(
				[ASXCode],
				[ObservationDate],
				NumDetailRecord,
				[TradeAction],
				[TradeValue],
				[ActionRule],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				(select min(ObservationDate) from #TempMatchVolume2) as [ObservationDate],
				(select count(ASXCode) from #TempMatchVolume2) as NumDetailRecord,
				'B' as [TradeAction],
				'IndicativePrice or match volume is up' as [ActionRule],
				cast(10000 as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate

			select 'B' as TradeAction, cast(10000 as decimal(20, 4)) as TradeValue

			return
		end

		if exists
		(
			select 1
			from #TempMatchVolume2 as a
			inner join #TempMatchVolume2 as b
			on a.VolumeOrder = 2
			and b.VolumeOrder in (3, 4)
			and a.IndicativePrice < b.IndicativePrice
		 )
		begin

			insert into [StockData].[TradeActionCheck]
			(
				[ASXCode],
				[ObservationDate],
				NumDetailRecord,
				[TradeAction],
				[TradeValue],
				[ActionRule],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				(select min(ObservationDate) from #TempMatchVolume2) as [ObservationDate],
				(select count(ASXCode) from #TempMatchVolume2) as NumDetailRecord,
				'S' as [TradeAction],
				'2nd latest IndicativePrice is down' as [ActionRule],
				cast(10000 as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate
			
			return

			select 'S' as TradeAction, null as TradeValue
		end

		if exists
		(
			select 1
			from #TempMatchVolume2 as a
			inner join #TempMatchVolume2 as b
			on a.VolumeOrder = 1
			and b.VolumeOrder in (2, 3)
			and a.IndicativePrice < b.IndicativePrice
		 )
		begin
			select 'Y' as SellAction, null as SellValue

			insert into [StockData].[TradeActionCheck]
			(
				[ASXCode],
				[ObservationDate],
				NumDetailRecord,
				[TradeAction],
				[TradeValue],
				[ActionRule],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				(select min(ObservationDate) from #TempMatchVolume2) as [ObservationDate],
				(select count(ASXCode) from #TempMatchVolume2) as NumDetailRecord,
				'S' as [TradeAction],
				'1st latest IndicativePrice is down' as [ActionRule],
				cast(10000 as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate
			
				select 'S' as TradeAction, null as TradeValue			
			return
		end

		if exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 2
			and BidDown = 1
		) 
		and exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 1
			and BidDown = 1
		) 
		begin
			insert into [StockData].[TradeActionCheck]
			(
				[ASXCode],
				[ObservationDate],
				NumDetailRecord,
				[TradeAction],
				[TradeValue],
				[ActionRule],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				(select min(ObservationDate) from #TempMatchVolume2) as [ObservationDate],
				(select count(ASXCode) from #TempMatchVolume2) as NumDetailRecord,
				'S' as [TradeAction],
				'1st and 2nd IndicativePrice and match volume is down' as [ActionRule],
				cast(10000 as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate
			
				select 'S' as TradeAction, null as TradeValue			
			
			return
		end	

		insert into [StockData].[TradeActionCheck]
		(
			[ASXCode],
			[ObservationDate],
			NumDetailRecord,
			[TradeAction],
			[TradeValue],
			[ActionRule],
			[CreateDate]
		)
		select
			@pvchASXCode as ASXCode,
			(select min(ObservationDate) from #TempMatchVolume2) as [ObservationDate],
			(select count(ASXCode) from #TempMatchVolume2) as NumDetailRecord,
			'N' as [TradeAction],
			null as [ActionRule],
			null as [TradeValue],
			getdate() as CreateDate

		select 'N' as BuyAction, cast(0 as decimal(20, 4)) as TradeValue

		
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
