-- Stored procedure: [DataMaintenance].[usp_MediumFrequencyMaintainStockData]





CREATE PROCEDURE [DataMaintenance].[usp_MediumFrequencyMaintainStockData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_MediumFrequencyMaintainStockData.sql
Stored Procedure Name: usp_MediumFrequencyMaintainStockData
Overview
-----------------
usp_MediumFrequencyMaintainStockData

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
Date:		2017-02-07
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MediumFrequencyMaintainStockData'
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
		exec [DataMaintenance].[usp_MaintainPriceHistory]

		--refresh PriceSummaryLatestFutureMA
		if object_id(N'Transform.PriceSummaryLatestFutureMA') is not null
			drop table Transform.PriceSummaryLatestFutureMA

		select * 
		into Transform.PriceSummaryLatestFutureMA
		from StockData.v_PriceSummary_Latest_Future_MA
		where 1 = 1
		and RowNumber <= 30

		--insert into StockData.PriceHistory
		--(
		--   [ASXCode]
		--  ,[ObservationDate]
		--  ,[Close]
		--  ,[Open]
		--  ,[Low]
		--  ,[High]
		--  ,[Volume]
		--  ,[Value]
		--  ,[Trades]
		--  ,[CreateDate]
		--  ,[ModifyDate]
		--)
		--select
		--   [ASXCode]
		--  ,[ObservationDate]
		--  ,[Close]
		--  ,[Open]
		--  ,[Low]
		--  ,[High]
		--  ,[Volume]
		--  ,VWAP*Volume as [Value]
		--  ,[Trades]
		--  ,[CreateDate]
		--  ,[ModifyDate]
		--from StockData.PriceHistorySecondary as a
		--where Exchange = 'SMART'
		--and Volume > 0
		--and datediff(day, a.ObservationDate, getdate()) <= 3
		--and not exists
		--(
		--	select 1
		--	from StockData.PriceHistory
		--	where ASXCode = a.ASXCode
		--	and ObservationDate = a.ObservationDate
		--)
		
		--refresh
		--if object_id(N'Transform.CHIXVolumeAndVWAP') is not null
		--	drop table Transform.CHIXVolumeAndVWAP

		--select *
		--into Transform.CHIXVolumeAndVWAP
		--from
		--(
		--	select 
		--		a.ASXCode, 
		--		cast(a.ObservationDate as varchar(50)) as ObservationDate, 
		--		a.[Close], 
		--		a.VWAP as TotalVWAP,
		--		null as ChiXvwap,
		--		b.VWAP as ASXVWAP,
		--		format(a.Volume, 'N0') as TotalVolume, 
		--		format(b.Volume, 'N0') as ASXVolume, 
		--		format(a.VWAP*a.Volume, 'N0') as TotalValue,
		--		format(b.VWAP*b.Volume, 'N0') as ASXValue,
		--		d.PriceChangeVsPrevClose, 
		--		d.PriceChangeVsOpen, 
		--		cast((a.Volume - b.Volume)*100.0/a.Volume as decimal(10, 2)) as CHIXPerc,
		--		avg(cast((a.Volume - b.Volume)*100.0/a.Volume as decimal(10, 2))) over (partition by a.ASXCode order by a.ObservationDate asc rows 9 preceding) as AvgCHIXPerc,
		--		c.AnnDescr
		--	from StockData.PriceHistorySecondary as a
		--	inner join StockData.PriceHistorySecondary as b
		--	on a.ASXCode = b.ASXCode
		--	and a.ObservationDate = b.ObservationDate
		--	left join Transform.PriceHistory as d
		--	on a.ASXCode = d.ASXCode
		--	and a.ObservationDate = d.ObservationDate
		--	left join [Transform].[v_Announcement] as c
		--	on a.ASXCode = c.ASXCode
		--	and a.ObservationDate = c.ObservationDate
		--	where 1 = 1
		--	and a.Exchange = 'SMART'
		--	and b.Exchange = 'ASX'
		--	and a.Volume > b.Volume
		--	and a.Volume > 0
		--	and b.Volume > 0
		--	union all
		--	select 
		--		a.ASXCode, 
		--		cast(a.ObservationDate as varchar(50)) as ObservationDate, 
		--		b.[Close], 
		--		null as TotalVWAP,
		--		a.VWAP as ChiXvwap,
		--		b.VWAP as ASXVWAP,
		--		format(a.Volume + b.Volume, 'N0') as TotalVolume, 
		--		format(b.Volume, 'N0') as ASXVolume, 
		--		format(a.[Value] + b.[Value], 'N0') as TotalValue,
		--		format(b.[Value], 'N0') as ASXValue,
		--		null as PriceChangeVsPrevClose, 
		--		null as PriceChangeVsOpen, 
		--		cast(a.Volume*100.0/(a.Volume + b.Volume) as decimal(10, 2)) as CHIXPerc,
		--		null as AvgCHIXPerc,
		--		c.AnnDescr
		--	from Transform.v_PriceHistorySecondaryFromCOS as a
		--	inner join Transform.v_PriceHistorySecondaryFromCOS as b
		--	on a.ASXCode = b.ASXCode
		--	and a.ObservationDate = b.ObservationDate
		--	left join [Transform].[v_Announcement] as c
		--	on a.ASXCode = c.ASXCode
		--	and a.ObservationDate = c.ObservationDate
		--	where 1 = 1
		--	and a.ExChange = 'CHIXAU'
		--	and b.ExChange = 'ASX'
		--	and a.Volume > 0
		--	and b.Volume > 0
		--	and not exists
		--	(
		--		select 1
		--		from StockData.PriceHistorySecondary
		--		where ASXCode = a.ASXCode
		--		and ObservationDate = a.ObservationDate
		--	)
		--) as x
		--order by x.ObservationDate desc

		exec [DataMaintenance].[usp_StoreStockDataReport]

		delete a
		from StockData.PriceSummaryToday as a
		where exists
		(
			select 1
			from StockData.PriceSummaryToday
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
			and DateTo is null
			and DateFrom > a.DateFrom
		)
		and a.DateTo is null

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()

		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_MaintainStockData failed'
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
