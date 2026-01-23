-- Stored procedure: [DataMaintenance].[usp_RefreshTransformBrokerReportList]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformBrokerReportList]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@intNumLookBackNoDays as int
AS
/******************************************************************************
File: usp_RefreshTransformBrokerReportList.sql
Stored Procedure Name: usp_RefreshTransformBrokerReportList
Overview
-----------------
usp_RefreshTransformBrokerReportList

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformBrokerReportList'
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
		--declare @pintNumPrevDay as int = 0
		--declare @intNumLookBackNoDays as int = 10
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

		select a.ASXCode, b.DisplayBrokerCode + '(' + coalesce(c.ValuePerc, d.ValuePerc, '') + ')' as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.v_BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		left join #TempBRAggregateValuePerc as c
		on a.ASXCode = c.ASXCode
		and a.BrokerCode = c.BrokerCode
		and c.RawValuePerc > 0
		left join #TempBRAggregateValuePerc as d
		on a.ASXCode = d.ASXCode
		and a.BrokerCode = d.BrokerCode
		and d.RawValuePerc < 0
		where a.ObservationDate >= Common.DateAddBusinessDay(0 - @intNumLookBackNoDays, @dtCurrBRDate)
		and a.ObservationDate <= Common.DateAddBusinessDay(0, @dtCurrBRDate)
		group by a.ASXCode, b.DisplayBrokerCode + '(' + coalesce(c.ValuePerc, d.ValuePerc, '') + ')' 

		if object_id(N'Tempdb.dbo.#TempBrokerReportList') is not null
			drop table #TempBrokerReportList

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregate as a
			where x.ASXCode = a.ASXCode
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportList
		from #TempBRAggregate as x

		if object_id(N'Tempdb.dbo.#TempBrokerReportListNeg') is not null
			drop table #TempBrokerReportListNeg

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregate as a
			where x.ASXCode = a.ASXCode
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNeg
		from #TempBRAggregate as x

		delete a
		from Transform.BrokerReportList as a
		where ObservationDate = @dtObservationDate
		and LookBackNoDays = @intNumLookBackNoDays

		insert into Transform.BrokerReportList
		(
			ObservationDate,
			[CurrBRDate],
			ASXCode,
			BrokerCode,
			NetBuySell,
			LookBackNoDays,
			CreateDate,
			StartBRDate
		)
		select
			@dtObservationDate as ObservationDate,
			@dtCurrBRDate as [CurrBRDate],
			ASXCode,
			BrokerCode,
			'B' as NetBuySell,
			@intNumLookBackNoDays as LookBackNoDays,
			getdate() as CreateDate,
			Common.DateAddBusinessDay(0 - @intNumLookBackNoDays, @dtCurrBRDate) as StartBRDate
		from #TempBrokerReportList
		union
		select
			@dtObservationDate as ObservationDate,
			@dtCurrBRDate as [CurrBRDate],
			ASXCode,
			BrokerCode,
			'S' as NetBuySell,
			@intNumLookBackNoDays as LookBackNoDays,
			getdate() as CreateDate,
			Common.DateAddBusinessDay(0 - @intNumLookBackNoDays, @dtCurrBRDate) as StartBRDate
		from #TempBrokerReportListNeg
		
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