-- Stored procedure: [StockData].[usp_AddCompanyPlacementHistory]



CREATE PROCEDURE [StockData].[usp_AddCompanyPlacementHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchCompanyInfo as varchar(max)
AS
/******************************************************************************
File: usp_AddCompanyPlacementHistory.sql
Stored Procedure Name: usp_AddCompanyPlacementHistory
Overview
-----------------
usp_AddCompanyPlacementHistory

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
Date:		2020-10-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCompanyPlacementHistory'
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
		if object_id(N'Tempdb.dbo.#TempCompanyInfoRaw') is not null
			drop table #TempCompanyInfoRaw

		select
			@pvchASXCode as ASXCode,
			@pvchCompanyInfo as CompanyInfo
		into #TempCompanyInfoRaw
		
		insert into StockData.RawData
		(
			DataTypeID,
			RawData,
			CreateDate,
			SourceSystemDate
		)
		select
			62 as DataTypeID,
			@pvchCompanyInfo as RawData,
			getdate() as CreateDate,
			null as SourceSystemDate

		--if object_id(N'MAWork.dbo.TempCompanyInfoRaw') is not null
		--	drop table MAWork.dbo.TempCompanyInfoRaw

		--select *
		--into MAWork.dbo.TempCompanyInfoRaw
		--from #TempCompanyInfoRaw

		if object_id(N'Tempdb.dbo.#TempCompanyPlacementHistory') is not null
			drop table #TempCompanyPlacementHistory

		select 
			a.ASXCode,
			json_value(c.value, '$.PlaceDate') as PlacementDate,
			json_value(c.value, '$.RaisedAmount') as RaisedAmount,
			json_value(c.value, '$.OfferPrice') as OfferPrice,
			json_value(c.value, '$.Discount') as Discount,
			json_value(c.value, '$.MarketCapAtRaise') as MarketCapAtRaise
		into #TempCompanyPlacementHistory
		from #TempCompanyInfoRaw as a
		cross apply openjson(CompanyInfo) as b
		cross apply openjson(b.value) as c
		where b.[key] = 'PlacementHistory'

		--delete a
		--from StockData.PlaceHistory as a
		--inner join #TempCompanyPlacementHistory as b
		--on a.ASXCode = b.ASXCode

		insert into StockData.PlaceHistory
		(
			ASXCode,
			PlacementDate,
			OfferPrice,
			Discount,
			MarketCapAtRaiseRaw,
			MarketCapAtRaise,
			CreateDate
		)
		select
			ASXCode,
			try_cast(PlacementDate as date),
			try_cast(replace(OfferPrice, '$', '') as decimal(20, 4)) as OfferPrice,
			try_cast(replace(Discount, '%', '') as decimal(10, 2)) as Discount,
			replace(MarketCapAtRaise, '$', '') as MarketCapAtRaiseRaw,
			null as MarketCapAtRaise,
			getdate() as CreateDate
		from #TempCompanyPlacementHistory as a
		where not exists
		(
			select 1
			from StockData.PlaceHistory
			where ASXCode = a.ASXCode
			and PlacementDate = a.PlacementDate
		)

		update a
		set a.ClosePriorToPlacement = b.[Close]
		from StockData.PlaceHistory as a
		inner join
		(
			select b.ASXCode, a.PlacementDate, b.ObservationDate, b.[Open], b.[Close], row_number() over (partition by a.ASXCode, a.PlacementDate order by b.ObservationDate desc) as RowNumber
			from StockData.PlaceHistory as a
			inner join StockData.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and a.PlacementDate >= b.ObservationDate
			and b.Volume > 0
		) as b
		on a.ASXCode = b.ASXcode
		and a.PlacementDate = b.PlacementDate
		and b.RowNumber = 1
		and a.ASXCode = @pvchASXCode
		and a.ClosePriorToPlacement is null

		update a
		set a.CloseAfterPlacementAnn = b.[Close],
			a.OpenAfterPlacementAnn = b.[Open]
		from StockData.PlaceHistory as a
		inner join
		(
			select b.ASXCode, a.PlacementDate, b.ObservationDate, b.[Open], b.[Close], row_number() over (partition by a.ASXCode, a.PlacementDate order by b.ObservationDate asc) as RowNumber
			from StockData.PlaceHistory as a
			inner join StockData.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and a.PlacementDate < b.ObservationDate
			and b.Volume > 0
		) as b
		on a.ASXCode = b.ASXcode
		and a.PlacementDate = b.PlacementDate
		and b.RowNumber = 1
		and a.ASXCode = @pvchASXCode
		and a.CloseAfterPlacementAnn is null

		update a
		set a.Close5dAfterPlacementAnn = b.[Close]
		from StockData.PlaceHistory as a
		inner join
		(
			select b.ASXCode, a.PlacementDate, b.ObservationDate, b.[Open], b.[Close], row_number() over (partition by a.ASXCode, a.PlacementDate order by b.ObservationDate asc) as RowNumber
			from StockData.PlaceHistory as a
			inner join StockData.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and Common.DateAddBusinessDay(5, a.PlacementDate) < b.ObservationDate
			and b.Volume > 0
		) as b
		on a.ASXCode = b.ASXcode
		and a.PlacementDate = b.PlacementDate
		and b.RowNumber = 1
		and a.ASXCode = @pvchASXCode
		where a.Close5dAfterPlacementAnn is null

		update a
		set a.Close30dAfterPlacementAnn = b.[Close]
		from StockData.PlaceHistory as a
		inner join
		(
			select b.ASXCode, a.PlacementDate, b.ObservationDate, b.[Open], b.[Close], row_number() over (partition by a.ASXCode, a.PlacementDate order by b.ObservationDate asc) as RowNumber
			from StockData.PlaceHistory as a
			inner join StockData.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and Common.DateAddBusinessDay(30, a.PlacementDate) < b.ObservationDate
			and b.Volume > 0
		) as b
		on a.ASXCode = b.ASXcode
		and a.PlacementDate = b.PlacementDate
		and b.RowNumber = 1
		and a.ASXCode = @pvchASXCode
		and a.Close30dAfterPlacementAnn is null

		update a
		set a.Close60dAfterPlacementAnn = b.[Close]
		from StockData.PlaceHistory as a
		inner join
		(
			select b.ASXCode, a.PlacementDate, b.ObservationDate, b.[Open], b.[Close], row_number() over (partition by a.ASXCode, a.PlacementDate order by b.ObservationDate asc) as RowNumber
			from StockData.PlaceHistory as a
			inner join StockData.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and Common.DateAddBusinessDay(60, a.PlacementDate) < b.ObservationDate
			and b.Volume > 0
		) as b
		on a.ASXCode = b.ASXcode
		and a.PlacementDate = b.PlacementDate
		and b.RowNumber = 1
		and a.ASXCode = @pvchASXCode
		and a.Close60dAfterPlacementAnn is null

		update a
		set MarketCapAtRaise = try_cast(replace(MarketCapAtRaiseRaw, 'b', '') as decimal(10, 2))*1000.0
		--select *, cast(replace(MarketCapAtRaiseRaw, 'b', '') as decimal(10, 2))*1000.0
		from StockData.PlaceHistory as a
		where right(MarketCapAtRaiseRaw, 1) = 'b'
		and a.ASXCode = @pvchASXCode
		and MarketCapAtRaise  is null

		update a
		set MarketCapAtRaise = try_cast(replace(MarketCapAtRaiseRaw, 'm', '') as decimal(10, 2))
		--select *, cast(replace(MarketCapAtRaiseRaw, 'b', '') as decimal(10, 2))*1000.0
		from StockData.PlaceHistory as a
		where right(MarketCapAtRaiseRaw, 1) = 'm'
		and a.ASXCode = @pvchASXCode
		and MarketCapAtRaise is null

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
