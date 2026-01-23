-- Stored procedure: [Report].[usp_GetSectorPerformanceAlert]



CREATE PROCEDURE [Report].[usp_GetSectorPerformanceAlert]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetSectorPerformanceAlert.sql
Stored Procedure Name: usp_GetSectorPerformanceAlert
Overview
-----------------
usp_GetSectorPerformanceAlert

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
Date:		2019-08-29
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetSectorPerformanceAlert'
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
		if object_id(N'Tempdb.dbo.#TempReport') is not null
			drop table #TempReport
		
		select
		   SMA0.[Token]
		  ,cast(SMA0.[ObservationDate] as varchar(50)) as ObservationDate
		  ,SMA0.[TradeValue]
		  ,SMA0.[ASXCode]
		  ,SMA0.SMA0
		  ,SMA3.SMA3
		  ,SMA5.SMA5
		  ,SMA10.SMA10
		  ,SMA20.SMA20
		  ,SMA30.SMA30
		  ,VSMA5.VSMA5
		  ,VSMA50.VSMA50
		into #TempReport
		from
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA0
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'SMA0'
		) as SMA0
		left join
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA3
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'SMA3'
		) as SMA3
		on SMA0.Token = SMA3.Token
		and SMA0.ObservationDate = SMA3.ObservationDate
		left join
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA5
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'SMA5'
		) as SMA5
		on SMA0.Token = SMA5.Token
		and SMA0.ObservationDate = SMA5.ObservationDate
		left join
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA10
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'SMA10'
		) as SMA10
		on SMA0.Token = SMA10.Token
		and SMA0.ObservationDate = SMA10.ObservationDate
		left join
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA20
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'SMA20'
		) as SMA20
		on SMA0.Token = SMA20.Token
		and SMA0.ObservationDate = SMA20.ObservationDate
		left join
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA30
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'SMA30'
		) as SMA30
		on SMA0.Token = SMA30.Token
		and SMA0.ObservationDate = SMA30.ObservationDate
		left join
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as VSMA5
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'VSMA5'
		) as VSMA5
		on SMA0.Token = VSMA5.Token
		and SMA0.ObservationDate = VSMA5.ObservationDate
		left join
		(
			select distinct
			   a.[Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as VSMA50
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			where b.TokenType in ('Sector')
			and [MAAvgHoldKey] = 'VSMA50'
		) as VSMA50
		on SMA0.Token = VSMA50.Token
		and SMA0.ObservationDate = VSMA50.ObservationDate

		if object_id(N'Tempdb.dbo.#TempCandidate') is not null
			drop table #TempCandidate

		select 
			x.Token,
			x.ObservationDate,
			x.VSMA5,
			x.VSMA50
		into #TempCandidate
		from
		(
			select 
				a.Token, 
				a.ObservationDate, 
				a.SMA0, 
				a.SMA5, 
				a.SMA10, 
				a.SMA30, 
				a.VSMA5, 
				a.VSMA50, 
				lag(a.ObservationDate, 5, null) over (partition by a.Token order by a.ObservationDate) as Prev5ObservationDate,
				lag(a.ObservationDate, 4, null) over (partition by a.Token order by a.ObservationDate) as Prev4ObservationDate,
				lag(a.ObservationDate, 3, null) over (partition by a.Token order by a.ObservationDate) as Prev3ObservationDate,
				lag(a.ObservationDate, 2, null) over (partition by a.Token order by a.ObservationDate) as Prev2ObservationDate,
				lag(a.ObservationDate, 1, null) over (partition by a.Token order by a.ObservationDate) as Prev1ObservationDate
			from #TempReport as a
		) as x
		inner join #TempReport as p5
		on x.Prev5ObservationDate = p5.ObservationDate
		and x.Token = p5.Token
		inner join #TempReport as p4
		on x.Prev5ObservationDate = p4.ObservationDate
		and x.Token = p4.Token
		inner join #TempReport as p3
		on x.Prev5ObservationDate = p3.ObservationDate
		and x.Token = p3.Token
		inner join #TempReport as p2
		on x.Prev5ObservationDate = p2.ObservationDate
		and x.Token = p2.Token
		inner join #TempReport as p1
		on x.Prev1ObservationDate = p1.ObservationDate
		and x.Token = p1.Token
		where 1 = 1
		and
		(
			(x.SMA5 > x.SMA10
			and x.SMA10 > x.SMA30
			and not 
			(
				p1.SMA5 > p1.SMA10
				and p1.SMA10 > p1.SMA30		
			))
			or
			(p1.SMA5 > p1.SMA10
			and p1.SMA10 > p1.SMA30
			and not 
			(
				p2.SMA5 > p2.SMA10
				and p2.SMA10 > p2.SMA30		
			))
			or
			(p2.SMA5 > p2.SMA10
			and p2.SMA10 > p2.SMA30
			and not 
			(
				p3.SMA5 > p3.SMA10
				and p3.SMA10 > p3.SMA30		
			))
			or
			(p3.SMA5 > p3.SMA10
			and p3.SMA10 > p3.SMA30
			and not 
			(
				p4.SMA5 > p4.SMA10
				and p4.SMA10 > p4.SMA30		
			))
			or
			(p4.SMA5 > p4.SMA10
			and p4.SMA10 > p4.SMA30
			and not 
			(
				p5.SMA5 > p5.SMA10
				and p5.SMA10 > p5.SMA30		
			))
		)
		and x.SMA10 > p1.SMA10
		and x.SMA30 > p1.SMA30
		and p1.SMA10 > p2.SMA10
		and p1.SMA30 > p2.SMA30
		and x.VSMA5 > p1.VSMA50 *1.0
		--and x.ObservationDate = '2019-07-18'
		order by x.ObservationDate desc

		if object_id(N'Tempdb.dbo.#TempSectorPerformanceAlert') is not null
			drop table #TempSectorPerformanceAlert

		select x.*, y.NumStock
		into #TempSectorPerformanceAlert
		from
		(
			select 
				*, 
				lag(ObservationDate, 1, null) over (partition by Token order by ObservationDate) as Prev1ObservationDate,
				lag(ObservationDate, 2, null) over (partition by Token order by ObservationDate) as Prev2ObservationDate,
				lag(ObservationDate, 3, null) over (partition by Token order by ObservationDate) as Prev3ObservationDate					 
			from #TempCandidate		
		) as x
		inner join 
		(
			select Token, ObservationDate, count(*) as NumStock  
			from Report.SectorPerformanceDetails
			group by Token, ObservationDate
		) as y
		on x.Token = y.Token
		and x.ObservationDate = y.ObservationDate
		where datediff(day, isnull(Prev1ObservationDate, '1990-01-01'), x.ObservationDate) > 10
		and x.ObservationDate > dateadd(day, -3, cast(getdate() as date))
		order by x.ObservationDate desc

		insert into [Alert].[SectorPerformanceAlert]
		(
			[Token],
			[ObservationDate],
			[VSMA5],
			[VSMA50],
			[Prev1ObservationDate],
			[Prev2ObservationDate],
			[Prev3ObservationDate],
			[NumStock],
			AlertSentDate
		)
		select
			[Token],
			[ObservationDate],
			[VSMA5],
			[VSMA50],
			[Prev1ObservationDate],
			[Prev2ObservationDate],
			[Prev3ObservationDate],
			[NumStock],
			null as AlertSentDate
		from #TempSectorPerformanceAlert as a
		where not exists
		(
			select 1
			from [Alert].[SectorPerformanceAlert]
			where Token = a.Token
			and ObservationDate = a.ObservationDate
		)

		while exists (
			select 1
			from [Alert].[SectorPerformanceAlert]
			where AlertSentDate is null
		)
		begin
			declare @intSectorPerformanceAlertID as int
			declare @pvchEmailRecipient as varchar(200)
			declare @pvchEmailSubject as varchar(200)
			declare @pvchEmailBody as varchar(500)

			select top 1
				@intSectorPerformanceAlertID = a.SectorPerformanceAlertID,
				@pvchEmailSubject = 'Sector Alert on: ' + a.Token,
				@pvchEmailBody = 'Sector Alert: ' + cast(a.Token as varchar(50)) + '
	' + 'ObservationDate: ' + cast(a.ObservationDate as varchar(50)) + '
	' + 'NumStock: ' + cast(a.NumStock as varchar(50)) + '
	' + 'VSMA5: ' + isnull(cast(a.VSMA5 as varchar(50)), '') + '
	' + 'VSMA50: ' + isnull(cast(a.VSMA50 as varchar(50)), '')
			from [Alert].[SectorPerformanceAlert] as a
			where AlertSentDate is null
			order by a.ObservationDate asc, a.Token

			select @pvchEmailRecipient = 'wayneweicheng@gmail.com'

			if @pvchEmailSubject is not null
			begin
				EXECUTE [Utility].[usp_AddEmail] 
					 @pvchEmailRecipient = @pvchEmailRecipient
					,@pvchEmailSubject = @pvchEmailSubject
					,@pvchEmailBody = @pvchEmailBody
					,@pintEventTypeID = 3
			end

			update a
			set a.AlertSentDate = getdate()
			from [Alert].[SectorPerformanceAlert] as a
			where SectorPerformanceAlertID = @intSectorPerformanceAlertID

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
