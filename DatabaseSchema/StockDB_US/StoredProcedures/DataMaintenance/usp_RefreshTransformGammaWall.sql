-- Stored procedure: [DataMaintenance].[usp_RefreshTransformGammaWall]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformGammaWall]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformGammaWall.sql
Stored Procedure Name: usp_RefreshTransformGammaWall
Overview
-----------------
usp_RefreshTransformGammaWall

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
Date:		2020-08-09
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformGammaWall'
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
		declare @dtStartObservationDate as date
		select @dtStartObservationDate = Common.DateAddBusinessDay(-3, getdate())
		select @dtStartObservationDate

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote_V2') is not null
			drop table #TempOptionDelayedQuote_V2

		select *
		into #TempOptionDelayedQuote_V2
		from StockData.v_OptionDelayedQuote_V2 with(nolock)
		where 1 = 1
		and ObservationDate >= @dtStartObservationDate

		if object_id(N'Tempdb.dbo.#TempGammaWall') is not null
			drop table #TempGammaWall

		select x.Strike, x.ExpiryDate, x.OIGex as CallGamma, y.OIGex as PutGamma, z.ASXCode, z.[Close], x.ObservationDate
		into #TempGammaWall
		from
		(
			select Strike, ExpiryDate, ASXCode, ObservationDate, sum(OpenInterest*100*Gamma) as OIGex
			from #TempOptionDelayedQuote_V2 with(nolock)
			where 1 = 1
			--and ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US')
			and PorC = 'C'
			group by Strike, ExpiryDate, ASXCode, ObservationDate
		) as x
		inner join
		(
			select Strike, ExpiryDate, ASXCode, ObservationDate, sum(OpenInterest*-100*Gamma) as OIGex
			from #TempOptionDelayedQuote_V2 with(nolock)
			where 1 = 1 
			and PorC = 'P'
			--and ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX')
			group by Strike, ExpiryDate, ASXCode, ObservationDate
		) as y
		on x.Strike = y.Strike
		and x.ExpiryDate = y.ExpiryDate
		and x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		inner join 
		(
			select 
				 [ASXCode]
				,[ObservationDate]
				,[Close]
				,[Open]
				,[Low]
				,[High]
				,[Volume]
				,[Value]
				,[Trades]
				,[CreateDate]
				,[ModifyDate]
				,[VWAP]
			from StockData.PriceHistory
			union
			select 
				'SPXW.US' as [ASXCode]
				,[ObservationDate]
				,[Close]
				,[Open]
				,[Low]
				,[High]
				,[Volume]
				,[Value]
				,[Trades]
				,[CreateDate]
				,[ModifyDate]
				,NULL AS [VWAP]
			from StockDB.StockData.PriceHistory
			where ASXCode in ('SPX')
			union all
			select 
				'SPX.US' as [ASXCode]
				,[ObservationDate]
				,[Close]
				,[Open]
				,[Low]
				,[High]
				,[Volume]
				,[Value]
				,[Trades]
				,[CreateDate]
				,[ModifyDate]
				,NULL AS [VWAP]
			from StockDB.StockData.PriceHistory
			where ASXCode in ('SPX')
			union all
			select 
				'_VIX.US' as [ASXCode]
				,[ObservationDate]
				,[Close]
				,[Open]
				,[Low]
				,[High]
				,[Volume]
				,[Value]
				,[Trades]
				,[CreateDate]
				,[ModifyDate]
				,NULL AS [VWAP]
			from StockDB.StockData.PriceHistory
			where ASXCode in ('VIX')
		) as z
		on z.ASXCode = x.ASXCode
		and z.ObservationDate = x.ObservationDate
		and x.Strike <= z.[Close]*case when x.ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 1.1 else 1.3 end
		and x.Strike >= z.[Close]*case when x.ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 0.9 else 0.7 end
		and x.ExpiryDate < dateadd(day, 180, getdate())

		delete a
		from Transform.GammaWall as a
		inner join #TempGammaWall as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into Transform.GammaWall
		select * from #TempGammaWall as a

		if object_id(N'Tempdb.dbo.#TempNetExposure') is not null
			drop table #TempNetExposure;

		with exposure as
		(
			select b.*
			from
			(
				select 
					Strike, ASXCode, [Close], [ObservationDate], sum(CallGamma) as CallGamma, sum(PutGamma) as PutGamma, sum(CallGamma) + sum(PutGamma) as NetGamma,
					case when sum(CallGamma) + sum(PutGamma) > 0 then 'Positive' else 'Negative' end as Exposure
				from #TempGammaWall
				where 1 = 1 
				and Strike <= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 1.1 else 1.3 end
				and Strike >= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 0.9 else 0.7 end
				--and ObservationDate = '2024-08-12'
				--and ASXCode = 'SPXW.US'
				group by Strike, ASXCode, [Close], [ObservationDate]
			) as b
		),

		exposure_agg as
		(
			select 
				ASXCode, [Close], [ObservationDate], sum(CallGamma) as TotalCallGamma, sum(PutGamma) as TotalPutGamma, sum(CallGamma) + sum(PutGamma) as TotalNetGamma,
				case when sum(CallGamma) + sum(PutGamma) > 0 then 'Positive' else 'Negative' end as TotalExposure
			from #TempGammaWall
			where 1 = 1 
			and Strike <= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 1.1 else 1.3 end
			and Strike >= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 0.9 else 0.7 end
			--and ObservationDate = '2024-08-12'
			--and ASXCode = 'SPXW.US'
			group by ASXCode, [Close], [ObservationDate]
		),

		exposure_agg_diff as
		(
		select 
			*,
			[Close] - lead([Close]) over (partition by ASXCode order by ObservationDate desc) as CloseChange,
			[TotalNetGamma] - lead([TotalNetGamma]) over (partition by ASXCode order by ObservationDate desc) as TotalNetGammaChange
		from exposure_agg
		)

		select a.*, b.CloseChange, b.TotalCallGamma, b.TotalPutGamma,  b.TotalNetGamma, b.TotalNetGammaChange
		into #TempNetExposure
		from exposure as a
		inner join exposure_agg_diff as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and b.[Close] is not null
		and b.[TotalNetGammaChange] is not null

		delete a
		from Transform.OptionNetExposureAggregate as a
		inner join #TempNetExposure as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into Transform.OptionNetExposureAggregate
		(
		   [Strike]
		  ,[ASXCode]
		  ,[Close]
		  ,[ObservationDate]
		  ,[CallGamma]
		  ,[PutGamma]
		  ,[NetGamma]
		  ,[Exposure]
		  ,[TotalCallGamma]
		  ,[TotalPutGamma]
		  ,[TotalNetGamma]
		  ,[CloseChange]
		  ,[TotalNetGammaChange]
		)
		select 
		   [Strike]
		  ,[ASXCode]
		  ,[Close]
		  ,[ObservationDate]
		  ,[CallGamma]
		  ,[PutGamma]
		  ,[NetGamma]
		  ,[Exposure]
		  ,[TotalCallGamma]
		  ,[TotalPutGamma]
		  ,[TotalNetGamma]
		  ,[CloseChange]
		  ,[TotalNetGammaChange]		
		from #TempNetExposure


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
