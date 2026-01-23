-- Stored procedure: [StockData].[usp_GetS708Deal]



CREATE PROCEDURE [StockData].[usp_GetS708Deal]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10) = null,
@pvchDealType varchar(10) = 'All',
@pintLastNumOfDays int = 30,
@pintMinNumOfBids int = 0,
@pvchExportType as varchar(10) = 'Png'
AS
/******************************************************************************
File: usp_GetS708Deal.sql
Stored Procedure Name: usp_GetS708Deal
Overview
-----------------
usp_AddS708Deal

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
Date:		2022-11-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetS708Deal'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchObservationDate as varchar(20) = '20220617'
		
		--Code goes here 
		set dateformat ymd
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * 0, getdate()) as date)
		
		select 
			DealType + ' - ' + a.ASXCode as ASXCode,
			case when b.[Close] is not null then cast(OfferPrice as varchar(20)) + '->' + cast(b.[Close] as varchar(20)) else cast(OfferPrice as varchar(20)) end as 'OfferPrice',
			cast(cast(case when b.[Close] > 0 then (b.[Close] - OfferPrice)*100.0/b.[Close] else null end as decimal(10, 2)) as varchar(50)) + '%' as DiscountPerc,
			cast(a.CreateDate as date) as CreateDate,
			BonusOptionDescr as BonusOption,
			case when @pvchExportType = 'png' then case when len(AdditionalNotes) > 100 then left(AdditionalNotes, 97) + '...' else AdditionalNotes end
				 else AdditionalNotes
			end,
			--CreatedBy,
			--UpdatedBy,
			format(c.NumBid, 'N0') as Bid,
			format(c.TotalBidAmount, 'N0') as BidAmount,
			d.AllocationPercBand as [Allocation %]
			--m2.BrokerCode as Recent10dBuyBroker,
			--n2.BrokerCode as Recent10dSellBroker
		from StockData.S708Deal as a
		--left join [Transform].[BrokerReportList] as m2
		--on a.ASXCode = m2.ASXCode
		--and m2.LookBackNoDays = 10
		--and m2.ObservationDate = cast(@dtObservationDate as date)
		--and m2.NetBuySell = 'B'
		--left join [Transform].[BrokerReportList] as n2
		--on a.ASXCode = n2.ASXCode
		--and n2.LookBackNoDays = 10
		--and n2.ObservationDate = cast(@dtObservationDate as date)
		--and n2.NetBuySell = 'S'
		left join StockData.v_PriceSummary_Latest_Today as b
		on a.ASXCode = b.ASXCode
		left join 
		(
			select S708DealID, count(*) as NumBid, sum(BidAmount) as TotalBidAmount
			from StockData.S708Bid
			group by S708DealID
		) as c
		on a.S708DealID = c.S708DealID
		left join 
		(
			select *, row_number() over (partition by S708DealID order by NumOccr desc) as RowNumber
			from
			(
				select S708DealID, AllocationPercBand, count(*) as NumOccr
				from StockData.S708Allocation
				group by S708DealID,AllocationPercBand
			) as x
		) as d
		on a.S708DealID = d.S708DealID
		and d.RowNumber = 1
		where (@pvchASXCode is null or a.ASXCode = @pvchASXCode + '.AX')
		and (@pvchDealType = 'All' or DealType = @pvchDealType)
		and isnull(c.NumBid, 0) >= @pintMinNumOfBids
		and datediff(day, a.CreateDate, getdate()) < @pintLastNumOfDays
		order by CreateDate desc;


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
