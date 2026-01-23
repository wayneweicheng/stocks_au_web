-- Stored procedure: [Working].[usp_CalculateBrokerNetProfit]


CREATE PROCEDURE [Working].[usp_CalculateBrokerNetProfit]
@pbitDebug AS BIT = 0,
@pintLookupNumDay as int = 5,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_SelectPriceReverse.sql
Stored Procedure Name: usp_SelectPriceReverse
Overview
-----------------
usp_SelectPriceReverse

Input Parameters
----------------
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
Date:		2018-08-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_CalculateBrokerNetProfit'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Working'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		declare @pdtEndObservationDate as date = Common.DateAddBusinessDay(-11, getdate()) 
		declare @pdtStartObservationDate as date = Common.DateAddBusinessDay(-90, @pdtEndObservationDate) 

		if object_id(N'Tempdb.dbo.#TempTopNProfitBrokerDetail') is not null
			drop table #TempTopNProfitBrokerDetail

		select 
			a.ASXCode, 
			a.BrokerCode, 
			format(a.NetVolume, 'N0') as NetVolume, 
			format(b.NetValue, 'N0') as NetValue, 
			case when a.NetVolume != 0 then cast(b.NetValue*1.0/a.NetVolume as decimal(20, 4)) else null end as AvgPrice,
			c.[Close] as CurrentPrice,
			format(abs(a.NetVolume)*c.[Close], 'N0') as CurrentValue,
			format(NetVolume*c.[Close] + -1*NetValue, 'N0') as NetProfit,
			NetVolume*c.[Close] + -1*NetValue as NetProfitNumeric
		into #TempTopNProfitBrokerDetail
		from 
		(
			select ASXCode, BrokerCode, sum(NetVolume) as NetVolume 
			from StockData.BrokerReport
			where ObservationDate > @pdtStartObservationDate
			and ObservationDate < @pdtEndObservationDate
			group by ASXCode, BrokerCode
		) as a
		inner join
		(
			select ASXCode, BrokerCode, sum(NetValue) as NetValue
			from StockData.BrokerReport
			where ObservationDate > @pdtStartObservationDate
			and ObservationDate < @pdtEndObservationDate
			group by ASXCode, BrokerCode
		) as b
		on a.BrokerCode = b.BrokerCode
		and a.ASXCode = b.ASXCode
		--and a.ASXCode = '.'
		left join 
		(
			select ASXCode, [Close], row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from Stockdata.PriceHistory
			where ObservationDate <= @pdtEndObservationDate
		) as c
		on a.ASXCode = c.ASXCode
		and c.[Close] > 0
		and c.RowNumber = 1
		where 1 = 1 
		and a.NetVolume != 0
		and a.BrokerCode not in ('J.Pmor')
		order by NetVolume*c.[Close] + -1*NetValue desc;

		if object_id(N'Tempdb.dbo.#TempTopNProfitBroker') is not null
			drop table #TempTopNProfitBroker

		select b.MC, a.*
		into #TempTopNProfitBroker
		from
		(
			select ASXCode, BrokerCode, NetProfit, NetProfitNumeric, row_number() over (partition by ASXCode order by NetProfitNumeric desc) as RowNumber
			from #TempTopNProfitBrokerDetail
			where NetProfitNumeric > 200000
		) as a
		inner join StockData.v_CompanyFloatingShare as b
		on a.ASXCode = b.ASXCode
		where a.BrokerCode not in ('COMSEC', 'CMCMAR')
		and RowNumber <= 3
		order by NetProfitNumeric/b.MC desc;

		declare @pintNumPrevDay as int = 0
		declare @intNumLookBackNoDays as int = 10
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtCurrBRDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 3, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		if object_id(N'Tempdb.dbo.#TempBRAggregateValuePerc') is not null
			drop table #TempBRAggregateValuePerc

		select 
			a.ASXCode, 
			a.BrokerCode, 
			case when b.NetValue != 0 then cast(cast(case when a.NetValue > 0 then a.NetValue else -1*a.NetValue end*100.0/b.NetValue as decimal(10,2)) as varchar(10)) else '' end as ValuePerc,
			cast(a.NetValue*100.0/b.NetValue as decimal(10,2)) as RawValuePerc
		into #TempBRAggregateValuePerc
		from
		(
			select a.BrokerCode, a.ASXCode, sum(a.NetValue) as NetValue
			from StockData.v_BrokerReport as a
			left join LookupRef.v_BrokerName as b
			on a.BrokerCode = b.BrokerCode
			where ObservationDate >= Common.DateAddBusinessDay(0 - @intNumLookBackNoDays, @dtCurrBRDate)
			and ObservationDate <= Common.DateAddBusinessDay(0, @dtCurrBRDate)
			--and a.NetValue > 0
			group by a.BrokerCode, a.ASXCode
		) as a
		inner join
		(
			select a.ASXCode, sum(a.NetValue) as NetValue
			from StockData.v_BrokerReport as a
			left join LookupRef.v_BrokerName as b
			on a.BrokerCode = b.BrokerCode
			where ObservationDate >= Common.DateAddBusinessDay(0 - @intNumLookBackNoDays, @dtCurrBRDate)
			and ObservationDate <= Common.DateAddBusinessDay(0, @dtCurrBRDate)
			and a.NetValue > 0
			group by a.ASXCode
		) as b
		on a.ASXCode = b.ASXCode

		select b.*, x.RawValuePerc 
		from
		(
			select a.*, row_number() over (partition by a.ASXCode order by RawValuePerc desc) as RawValuePercRank
			from #TempBRAggregateValuePerc as a
		) as x
		inner join #TempTopNProfitBroker as b
		on x.ASXCode = b.ASXCode
		and x.BrokerCode = b.BrokerCode
		where x.RawValuePercRank <= 2
		and x.RawValuePerc > 5;

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