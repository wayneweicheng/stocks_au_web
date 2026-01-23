-- Stored procedure: [DataMaintenance].[usp_RefreshTransformTickSaleVsBidAsk_intraday]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformTickSaleVsBidAsk_intraday]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformTickSaleVsBidAsk_intraday.sql
Stored Procedure Name: usp_RefreshTransformTickSaleVsBidAsk_intraday
Overview
-----------------
usp_RefreshTransformTickSaleVsBidAsk_intraday

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
Date:		2021-09-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformTickSaleVsBidAsk_intraday'
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
		declare @dtDate as date

		DECLARE @EST_BusinessDay DATE;
		DECLARE @CurrentDate DATE;

		-- Get the initial date in US EST
		WITH US_EST_Date AS (
			SELECT CAST(getdate() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time' AS DATE) AS EST_Date
		)
		SELECT @CurrentDate = EST_Date FROM US_EST_Date;
		
		-- Loop to find the next business day
		WHILE 1 = 1
		BEGIN
			-- Check if the current date is a weekend or holiday
			IF DATENAME(WEEKDAY, @CurrentDate) NOT IN ('Saturday', 'Sunday') AND 
			   NOT EXISTS (SELECT 1 FROM [LookupRef].[PublicHoliday] WHERE HolidayDate = @CurrentDate)
			BEGIN
				SET @EST_BusinessDay = @CurrentDate;
				BREAK;
			END

			-- Move to the next day
			SET @CurrentDate = DATEADD(DAY, -1, @CurrentDate);
		END

		-- Output the next business day
		SELECT @dtDate = @EST_BusinessDay
		--select @dtDate 

		if object_id(N'Tempdb.dbo.#TempBidAsk') is not null
			drop table #TempBidAsk

		select *
		into #TempBidAsk
		from [StockData].[v_StockBidAsk] with(nolock)
		where ObservationDate = @dtDate

		if object_id(N'Tempdb.dbo.#Temp_CourseOfSaleSecondary_By_Min') is not null
			drop table #Temp_CourseOfSaleSecondary_By_Min

		select *
		into #Temp_CourseOfSaleSecondary_By_Min 
		from StockData.v_CourseOfSaleSecondary_By_Min with(nolock)
		where ObservationDate = @dtDate

		if object_id(N'Tempdb.dbo.#Temp_v_StockTickSaleVsBidAsk') is not null
			drop table #Temp_v_StockTickSaleVsBidAsk

		select 
			[CourseOfSaleSecondaryID]
			,[SaleDateTime]
			,[ObservationDate]
			,[Price]
			,[Quantity]
			,[SaleValue]
			,[FormatedSaleValue]
			,[ASXCode]
			,[Exchange]
			,[SpecialCondition]
			,[ActBuySellInd]
			,[DerivedBuySellInd]
			,[DerivedInstitute]
			,[StockBidAskID]
			,[PriceBid]
			,[SizeBid]
			,[PriceAsk]
			,[SizeAsk]
			,[DateFrom]
			,[DateTo]
		into #Temp_v_StockTickSaleVsBidAsk
		from
		(
			select 
				a.CourseOfSaleSecondaryID,
				a.SaleDateTime,
				a.ObservationDate,
				a.Price,
				a.Quantity,
				cast(a.Price*a.Quantity as bigint) as SaleValue,
				format(cast(a.Price*a.Quantity as bigint), 'N0') as FormatedSaleValue,
				a.ASXCode, 
				a.Exchange,
				a.SpecialCondition,
				a.ActBuySellInd,
				case when b.PriceBid < b.PrevPriceBid then 'S'
					 when b.PriceAsk > b.PrevPriceAsk then 'B'
					 else case when a.Price <= b.PriceBid then 'S' 
							   when a.Price >= b.PriceAsk then 'B' 
							   else null
						  end
				end as DerivedBuySellInd,
				a.DerivedInstitute,
				b.StockBidAskID,
				b.PriceBid,
				b.SizeBid,
				b.PriceAsk,
				b.SizeAsk,
				b.DateFrom,
				b.DateTo
			from #Temp_CourseOfSaleSecondary_By_Min as a with(nolock)
			inner join #TempBidAsk as b with(nolock)
			on a.SaleDateTime > b.DateFrom and a.SaleDateTime <= b.DateTo
			and a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			where 1 = 1
			union all
			select 
				null as CourseOfSaleSecondaryID,
				b.ObservationTime as SaleDateTime,
				b.ObservationDate,
				null as Price,
				null as Quantity,
				null as SaleValue,
				null as FormatedSaleValue,
				b.ASXCode as ASXCode, 
				null as Exchange,
				null as SpecialCondition,
				null as ActBuySellInd,
				null as DerivedBuySellInd,
				null as DerivedInstitute,
				b.StockBidAskID,
				b.PriceBid,
				b.SizeBid,
				b.PriceAsk,
				b.SizeAsk,
				b.DateFrom,
				b.DateTo
			from #TempBidAsk as b with(nolock)
			left join #Temp_CourseOfSaleSecondary_By_Min as a with(nolock)
			on a.SaleDateTime > b.DateFrom and a.SaleDateTime <= b.DateTo
			and a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			where a.ASXCode is null
		) as x

		delete a
		from Transform.StockTickSaleVsBidAsk as a
		inner join (
			select ASXCode, ObservationDate
			from #Temp_v_StockTickSaleVsBidAsk
			where DerivedBuySellInd is not null
			group by ASXCode, ObservationDate		
		) as b
		on b.ASXCode = a.ASXCode
		and b.ObservationDate = a.ObservationDate
		
		insert into Transform.StockTickSaleVsBidAsk
		(
			   [CourseOfSaleSecondaryID]
			  ,[SaleDateTime]
			  ,[ObservationDate]
			  ,[Price]
			  ,[Quantity]
			  ,[SaleValue]
			  ,[FormatedSaleValue]
			  ,[ASXCode]
			  ,[Exchange]
			  ,[SpecialCondition]
			  ,[ActBuySellInd]
			  ,[DerivedBuySellInd]
			  ,[DerivedInstitute]
			  ,[StockBidAskID]
			  ,[PriceBid]
			  ,[SizeBid]
			  ,[PriceAsk]
			  ,[SizeAsk]
			  ,[DateFrom]
			  ,[DateTo]
		)
		select
			   [CourseOfSaleSecondaryID]
			  ,[SaleDateTime]
			  ,[ObservationDate]
			  ,[Price]
			  ,[Quantity]
			  ,[SaleValue]
			  ,[FormatedSaleValue]
			  ,[ASXCode]
			  ,[Exchange]
			  ,[SpecialCondition]
			  ,[ActBuySellInd]
			  ,[DerivedBuySellInd]
			  ,[DerivedInstitute]
			  ,[StockBidAskID]
			  ,[PriceBid]
			  ,[SizeBid]
			  ,[PriceAsk]
			  ,[SizeAsk]
			  ,[DateFrom]
			  ,[DateTo]
		from #Temp_v_StockTickSaleVsBidAsk as a
		where not exists
		(
			select 1
			from Transform.StockTickSaleVsBidAsk
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
			and SaleDateTime = a.SaleDateTime
		)

		if object_id(N'Tempdb.dbo.#TempStockBidAskObservationTime') is not null
			drop table #TempStockBidAskObservationTime

		select a.ASXCode, a.ObservationDate, max(ObservationTime) as ObservationTime
		into #TempStockBidAskObservationTime
		from StockData.StockBidAsk as a
		inner join #Temp_v_StockTickSaleVsBidAsk as b
		on a.StockBidAskID = b.StockBidAskID
		group by a.ASXCode, a.ObservationDate

		delete a
		from StockData.StockBidAskObservationTime as a
		inner join #TempStockBidAskObservationTime as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into StockData.StockBidAskObservationTime
		(
			ASXCode, ObservationDate, ObservationTime
		)
		select
			ASXCode, ObservationDate, ObservationTime
		from #TempStockBidAskObservationTime

		--delete a
		--from StockData.StockBidAsk as a
		--inner join 
		--(
		--	select max(StockBidAskID) as StockBidAskID
		--	from #Temp_v_StockTickSaleVsBidAsk 
		--) as b
		--on a.StockBidAskID <= b.StockBidAskID

		--CourseOfSale Secondary
		if object_id(N'Tempdb.dbo.#TempStockcosTime') is not null
			drop table #TempStockcosTime

		select a.ASXCode, a.ObservationDate, max(a.SaleDateTime) as SaleDateTime
		into #TempStockcosTime
		from StockData.CourseOfSaleSecondaryToday as a
		inner join #Temp_v_StockTickSaleVsBidAsk as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.SaleDateTime = b.SaleDateTime
		group by a.ASXCode, a.ObservationDate

		delete a
		from [StockData].[StockCOSSaleTime] as a
		inner join #TempStockcosTime as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into [StockData].[StockCOSSaleTime]
		(
			ASXCode, ObservationDate, SaleDateTime
		)
		select
			ASXCode, ObservationDate, SaleDateTime
		from #TempStockcosTime

		--delete a
		--from StockData.CourseOfSaleSecondaryToday as a
		--inner join #Temp_v_StockTickSaleVsBidAsk as b
		--on a.ASXCode = b.ASXCode
		--and a.ObservationDate = b.ObservationDate
		--and a.SaleDateTime = b.SaleDateTime
		
		update a
		set DerivedBuySellInd =
		case when a.Price <= PriceBid then 'S' 
		 	 when a.Price >= PriceAsk then 'B' 
			 else null
		end
		from Transform.StockTickSaleVsBidAsk as a
		where 1 = 1
		and a.ObservationDate = @dtDate
		and DerivedBuySellInd is null
		and Price is not null

		update a
		set DerivedBuySellInd = 'S'
		from Transform.StockTickSaleVsBidAsk as a
		where PriceBid >= Price
		and PriceAsk > Price
		and isnull(DerivedBuySellInd, 'B') = 'B'
		and a.ObservationDate = @dtDate

		update a
		set DerivedBuySellInd = 'B'
		from Transform.StockTickSaleVsBidAsk as a
		where PriceAsk <= Price
		and PriceBid < Price
		and isnull(DerivedBuySellInd, 'S') = 'S'
		and a.ObservationDate = @dtDate

		update a
		set DerivedInstitute = null
		from Transform.StockTickSaleVsBidAsk as a
		where a.ObservationDate = @dtDate

		update a
		set DerivedInstitute = 1
		from Transform.StockTickSaleVsBidAsk as a
		where SizeBid*1.8 < SizeAsk
		and PriceAsk > PriceBid
		and DerivedBuySellInd = 'B'
		and a.ObservationDate = @dtDate

		update a
		set DerivedInstitute = 0
		from Transform.StockTickSaleVsBidAsk as a
		where SizeBid*1.8 < SizeAsk
		and PriceAsk > PriceBid
		and DerivedBuySellInd = 'S'
		and a.ObservationDate = @dtDate

		update a
		set DerivedInstitute = 1
		from Transform.StockTickSaleVsBidAsk as a
		where SizeBid > SizeAsk*1.8
		and PriceAsk > PriceBid
		and DerivedBuySellInd = 'S'
		and a.ObservationDate = @dtDate

		update a
		set DerivedInstitute = 0
		from Transform.StockTickSaleVsBidAsk as a
		where SizeBid > SizeAsk*1.8
		and PriceAsk > PriceBid
		and DerivedBuySellInd = 'B'
		and a.ObservationDate = @dtDate

		update a
		set DerivedInstitute = 1
		from Transform.StockTickSaleVsBidAsk as a
		where 
		(
			(Price > PriceAsk and PriceBid < PriceAsk)
			or
			(Price < PriceBid and PriceBid < PriceAsk)
		)
		and a.ObservationDate = @dtDate

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_RefreshTransformBrokerReportList failed'
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