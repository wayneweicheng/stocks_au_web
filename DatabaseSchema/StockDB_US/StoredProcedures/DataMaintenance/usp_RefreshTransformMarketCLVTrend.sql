-- Stored procedure: [DataMaintenance].[usp_RefreshTransformMarketCLVTrend]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformMarketCLVTrend]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformMarketCLVTrend.sql
Stored Procedure Name: usp_RefreshTransformMarketCLVTrend
Overview
-----------------
usp_RefreshTransformMarketCLVTrend

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
Date:		2022-06-18
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformMarketCLVTrend'
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
		if object_id(N'Tempdb.dbo.#TempHistory') is not null
			drop table #TempHistory

		select 
			*, 
			cast(case when [High] - [Low] = 0 then 0 else (([Close] - [Low]) - ([High] - [Close]))/([High] - [Low]) end as decimal(10, 4)) as CLV
		into #TempHistory
		from StockData.PriceHistory
		where ObservationDate > dateadd(day, -365, getdate())
		and Volume > 0
		and [High] > 0
		and [Low] > 0
		and ASXCode not in ('GOOGL.US', 'BABA.US')

		if object_id(N'Transform.MarketCLVTrendDetails') is not null
			drop table Transform.MarketCLVTrendDetails

		select *
		into Transform.MarketCLVTrendDetails
		from
		(
			select
				a.*, 
				case when CleansedMarketCap < 20 then 'a. 0 - 20M'
					when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
					when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
					when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
					when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
					when CleansedMarketCap >= 1000 and CleansedMarketCap < 10000 then 'f. 1B+'
					when CleansedMarketCap >= 10000 and CleansedMarketCap < 300000 then 'g. 10B+'
					when CleansedMarketCap >= 300000 then 'h. 300B+'
				end as MarketCap,				
				row_number() over (partition by a.ASXCode order by a.ObservationDate desc) as RowNumber
			from #TempHistory as a
			inner join StockData.CompanyInfo as b
			on a.ASXCode = b.ASXCode
		) as x
		where x.RowNumber = 1

		if object_id(N'Transform.MarketCLVTrendDetailsETF') is not null
			drop table Transform.MarketCLVTrendDetailsETF

		select *
		into Transform.MarketCLVTrendDetailsETF
		from
		(
			select
				a.*, 
				cast(null as varchar(50)) as MarketCap,				
				row_number() over (partition by a.ASXCode order by a.ObservationDate desc) as RowNumber
			from #TempHistory as a
			inner join Stock.ETF as b
			on a.ASXCode = b.ASXCode
		) as x
		where x.RowNumber > 0

		if object_id(N'Tempdb.dbo.#TempMarketCLVTrend') is not null
			drop table #TempMarketCLVTrend

		select 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 and CleansedMarketCap < 10000 then 'f. 1B+'
			when CleansedMarketCap >= 10000 and CleansedMarketCap < 300000 then 'g. 10B+'
			when CleansedMarketCap >= 300000 then 'h. 300B+'
		end as MarketCap, 
		ObservationDate,
		avg(CLV) as CLV,
		cast(null as decimal(10, 4)) as CLVMA5,
		cast(null as decimal(10, 4)) as CLVMA10,
		cast(null as decimal(10, 4)) as CLVMA20,
		cast(null as decimal(10, 2)) as VarCLVMA5,
		cast(null as decimal(10, 2)) as VarCLVMA10,
		cast(null as decimal(10, 2)) as VarCLVMA20,
		count(a.ASXCode) as NumObservation,
		getdate() as CreateDate,
		cast(null as decimal(20, 4)) as SPX,
		cast(null as decimal(10, 2)) as SPXChange,
		cast(null as decimal(20, 4)) as NASDAQ,
		cast(null as decimal(10, 2)) as NASDAQChange,
		'SPX' as Sector
		into #TempMarketCLVTrend
		from #TempHistory as a
		inner join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		where 1 = 1
		group by 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 and CleansedMarketCap < 10000 then 'f. 1B+'
			when CleansedMarketCap >= 10000 and CleansedMarketCap < 300000 then 'g. 10B+'
			when CleansedMarketCap >= 300000 then 'h. 300B+'
		end,
		ObservationDate
		order by 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 and CleansedMarketCap < 10000 then 'f. 1B+'
			when CleansedMarketCap >= 10000 and CleansedMarketCap < 300000 then 'g. 10B+'
			when CleansedMarketCap >= 300000 then 'h. 300B+'
		end,
		ObservationDate

		update a
		set a.CLVMA5 = b.CLVMA5,
			a.CLVMA10 = b.CLVMA10,
			a.CLVMA20 = b.CLVMA20
		from #TempMarketCLVTrend as a
		inner join
		(
			select
				Sector,
				MarketCap,
				ObservationDate,
				CLVMA5 = avg(CLV) over (partition by Sector, MarketCap order by ObservationDate asc rows 4 preceding),
				CLVMA10 = avg(CLV) over (partition by Sector, MarketCap order by ObservationDate asc rows 9 preceding),
				CLVMA20 = avg(CLV) over (partition by Sector, MarketCap order by ObservationDate asc rows 19 preceding)
			from #TempMarketCLVTrend
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.Sector = b.Sector
		and a.MarketCap = b.MarketCap

		update a
		set a.VARCLVMA5 = case when a.CLVMA5 != 0 then (CLV - a.CLVMA5)*100.0 else null end,
			a.VARCLVMA10 = case when a.CLVMA10 != 0 then (CLV - a.CLVMA10)*100.0 else null end,
			a.VARCLVMA20 = case when a.CLVMA20 != 0 then (CLV - a.CLVMA20)*100.0 else null end
		from #TempMarketCLVTrend as a

		update a
		set a.SPX =  b.[Close]
		from #TempMarketCLVTrend as a
		inner join
		(
			select *
			from StockDB.StockData.PriceHistory
			where ASXCode = 'SPX'
		) as b
		on a.ObservationDate = b.ObservationDate

		update a
		set a.NASDAQ =  b.[Close]
		from #TempMarketCLVTrend as a
		inner join
		(
			select *
			from StockDB.StockData.PriceHistory
			where ASXCode = 'NASDAQ'
		) as b
		on a.ObservationDate = b.ObservationDate

		update a
		set a.SPXChange = case when b.PrevSPX > 0 then cast((a.SPX - b.PrevSPX)*100.0/b.PrevSPX as decimal(10, 2)) else null end
		from #TempMarketCLVTrend as a
		inner join
		(
			select lead(SPX) over (partition by MarketCap, Sector order by ObservationDate desc) as PrevSPX, ObservationDate, Sector, MarketCap
			from #TempMarketCLVTrend
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.Sector = b.Sector
		and a.MarketCap = b.MarketCap

		update a
		set a.NASDAQChange = case when b.PrevNASDAQ > 0 then cast((a.NASDAQ - b.PrevNASDAQ)*100.0/b.PrevNASDAQ as decimal(10, 2)) else null end
		from #TempMarketCLVTrend as a
		inner join
		(
			select lead(NASDAQ) over (partition by MarketCap, Sector order by ObservationDate desc) as PrevNASDAQ, ObservationDate, Sector, MarketCap
			from #TempMarketCLVTrend
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.Sector = b.Sector
		and a.MarketCap = b.MarketCap

		delete a
		from [Transform].[MarketCLVTrend] as a
		inner join #TempMarketCLVTrend as b
		on a.Sector = b.Sector
		and a.ObservationDate = b.ObservationDate

		insert into [Transform].[MarketCLVTrend]
		(
		   [MarketCap]
		  ,[ObservationDate]
		  ,[CLV]
		  ,[CLVMA5]
		  ,[CLVMA10]
		  ,[CLVMA20]
		  ,[VarCLVMA5]
		  ,[VarCLVMA10]
		  ,[VarCLVMA20]
		  ,[NumObservation]
		  ,[CreateDate]
		  ,[SPX]
		  ,[SPXChange]
		  ,NASDAQ
		  ,NASDAQChange
		  ,[Sector]
		)
		select
		   [MarketCap]
		  ,[ObservationDate]
		  ,[CLV]
		  ,[CLVMA5]
		  ,[CLVMA10]
		  ,[CLVMA20]
		  ,[VarCLVMA5]
		  ,[VarCLVMA10]
		  ,[VarCLVMA20]
		  ,[NumObservation]
		  ,[CreateDate]
		  ,[SPX]
		  ,[SPXChange]
		  ,NASDAQ
		  ,NASDAQChange
		  ,[Sector]
		from #TempMarketCLVTrend as a
		where not exists
		(
			select 1
			from [Transform].[MarketCLVTrend]
			where ObservationDate = a.ObservationDate
			and Sector = a.Sector
		)
		
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
