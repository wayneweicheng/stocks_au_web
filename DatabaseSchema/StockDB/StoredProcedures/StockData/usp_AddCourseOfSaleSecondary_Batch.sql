-- Stored procedure: [StockData].[usp_AddCourseOfSaleSecondary_Batch]






CREATE PROCEDURE [StockData].[usp_AddCourseOfSaleSecondary_Batch_Dev]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
--@pvchStockCode as varchar(10),
@pvchCourseOfSaleBar as varchar(max)
AS
/******************************************************************************
File: usp_AddCourseOfSaleSecondary_Batch.sql
Stored Procedure Name: usp_AddCourseOfSaleSecondary_Batch
Overview
-----------------
usp_AddCourseOfSaleSecondary_Batch

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
Date:		2021-06-25
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc
	SET LOCK_TIMEOUT 300000;

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCourseOfSaleSecondary_Batch'
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
		if object_id(N'Tempdb.dbo.#TempCOSSecondaryBar') is not null
			drop table #TempCOSSecondaryBar

		select
			@pvchCourseOfSaleBar as CourseOfSaleBar
		into #TempCOSSecondaryBar

		if object_id(N'Tempdb.dbo.#TempCOS') is not null
			drop table #TempCOS

		create table #TempCOS
		(
			COSID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			SaleDateTime datetime not null,
			Price decimal(20, 4),
			Quantity decimal(20,4),
			Exchange varchar(20),
			SpecialCondition varchar(50),
			ObservationDate date
		)

		insert into #TempCOS
		(
			ASXCode,
			SaleDateTime,
			Price,
			Quantity,
			Exchange,
			SpecialCondition,
			ObservationDate 
		)
		select 
			json_value(b.value, '$.ASXCode') as ASXCode,
			cast(json_value(b.value, '$.SaleDateTime') as datetime) as SaleDateTime,
			cast(json_value(b.value, '$.Price') as decimal(20, 4)) as Price,
			floor(cast(json_value(b.value, '$.Quantity') as decimal(20,4))) as Quantity,
			json_value(b.value, '$.Exchange') as Exchange,
			json_value(b.value, '$.SpecialCondition') as SpecialCondition,
			cast(cast(json_value(b.value, '$.SaleDateTime') as datetime) as date) as ObservationDate
		from #TempCOSSecondaryBar as a
		cross apply openjson(CourseOfSaleBar) as b

		if object_id(N'Tempdb.dbo.#TempCourseOfSaleSecondary') is not null
			drop table #TempCourseOfSaleSecondary

		select
			identity(int, 1, 1) as CourseOfSaleSecondaryID,
			[SaleDateTime],
			[Price],
			[Quantity],
			[ASXCode],
			ExChange,
			SpecialCondition,
			getdate() as [CreateDate],
			cast(null as char(1)) as ActBuySellInd,
			cast(null as bit) as DerivedInstitute,
			ObservationDate as ObservationDate
		into #TempCourseOfSaleSecondary
		from 
		(
			select SaleDateTime, Exchange, Price, ASXCode, nullif(Specialcondition, '') as Specialcondition, sum(Quantity) as Quantity, ObservationDate
			from #TempCOS
			group by SaleDateTime, Exchange, Price, ASXCode, nullif(Specialcondition, ''), ObservationDate
		) as a
		where not exists
		(
			select 1
			from [StockData].[CourseOfSaleSecondaryToday] with(nolock)
			where SaleDateTime = a.SaleDateTime
			and ASXCode = a.ASXCode
			and Price = a.Price
			and Quantity = a.Quantity
			and ExChange = a.ExChange
			and ObservationDate = a.ObservationDate
		)

		declare @dtMaxObservationDate as date
		select @dtMaxObservationDate = max(ObservationDate)
		from #TempCourseOfSaleSecondary

		insert into [StockData].[CourseOfSaleSecondaryToday]
		(
			[SaleDateTime],
			[Price],
			[Quantity],
			[ASXCode],
			ExChange,
			SpecialCondition,
			[CreateDate],
			ActBuySellInd,
			DerivedInstitute,
			ObservationDate
		)
		select
			[SaleDateTime],
			[Price],
			[Quantity],
			[ASXCode],
			ExChange,
			SpecialCondition,
			[CreateDate],
			ActBuySellInd,
			DerivedInstitute,
			ObservationDate
		from #TempCourseOfSaleSecondary as a
		where not exists
		(
			select 1
			from [StockData].[CourseOfSaleSecondaryToday] with(nolock)
			where SaleDateTime = a.SaleDateTime
			and ASXCode = a.ASXCode
			and Price = a.Price
			and Quantity = a.Quantity
			and ExChange = a.ExChange
			and ObservationDate = a.ObservationDate
			and ObservationDate = @dtMaxObservationDate
		)

		if object_id(N'Tempdb.dbo.#TempCOS') is not null
			drop table #TempCOS

		if object_id(N'Tempdb.dbo.#TempCourseOfSaleSecondary') is not null
			drop table #TempCourseOfSaleSecondary

		if object_id(N'Tempdb.dbo.#TempDistinctPrice') is not null
			drop table #TempDistinctPrice

		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		if object_id(N'Tempdb.dbo.#TempCourseOfSale2') is not null
			drop table #TempCourseOfSale2

		if object_id(N'Tempdb.dbo.#TempMarketDepth') is not null
			drop table #TempMarketDepth

		if object_id(N'Tempdb.dbo.#TempPriceSummaryToday') is not null
			drop table #TempPriceSummaryToday

		if object_id(N'Tempdb.dbo.#TempDeriveInstitute') is not null
			drop table #TempDeriveInstitute

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
