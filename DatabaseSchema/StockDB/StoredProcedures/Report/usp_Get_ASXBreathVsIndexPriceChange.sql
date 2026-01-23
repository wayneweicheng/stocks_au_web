-- Stored procedure: [Report].[usp_Get_ASXBreathVsIndexPriceChange]



CREATE PROCEDURE [Report].[usp_Get_ASXBreathVsIndexPriceChange]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchMarketCapType as varchar(20),
@pvchIndex as varchar(10),
@pintNumObservations as int = 30
AS
/******************************************************************************
File: usp_Get_ASXBreathVsIndexPriceChange.sql
Stored Procedure Name: usp_Get_ASXBreathVsIndexPriceChange
Overview
-----------------
usp_Get_ASXBreathVsIndexPriceChange

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
Date:		2021-12-20
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
******************************B*************************************************/

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_ASXBreathVsIndexPriceChange'
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
		--declare @pintNumObservations as int = 90
		--declare @pvchMarketCapType as varchar(20) = 'SmallCap'
		--declare @pvchIndex as varchar(10) = 'DJIA'

		if object_id(N'Tempdb.dbo.#Temp') is not null
			drop table #Temp

		select *, lag([Close], 1, null) over (order by ObservationDate asc) as PrevClose, cast(null as decimal(20, 2)) as ChangePerc
		into #Temp
		from StockData.PriceHistory
		where ASXCode = @pvchIndex

		--update a
		--set ChangePerc = ([Close] - [PrevClose])*100.0/[PrevClose]
		--from #Temp as a
		--where [PrevClose] > 0

		update a
		set ChangePerc = ([Close] - [Open])*100.0/[Open]
		from #Temp as a
		where [Open] > 0

		if object_id(N'Tempdb.dbo.#Temp2') is not null
			drop table #Temp2

		select 
			x.ObservationDate, 
			x.MarketCapType, 
			y.Score - x.Score as ScoreChange, 
			case when y.Score - x.Score >= 0 and y.Score - x.Score < 40 then 0
				 when y.Score - x.Score >= 40 and y.Score - x.Score < 120 then 1
				 when y.Score - x.Score >= 120 and y.Score - x.Score < 240 then 2
				 when y.Score - x.Score >= 240 and y.Score - x.Score < 360 then 3
				 when y.Score - x.Score >= 360 and y.Score - x.Score < 550 then 4
				 when y.Score - x.Score >= 550 then 5
				 when y.Score - x.Score < 0 and y.Score - x.Score > -40 then 0
				 when y.Score - x.Score <= -40 and y.Score - x.Score > -120 then -1
				 when y.Score - x.Score <= -120 and y.Score - x.Score > -240 then -2
				 when y.Score - x.Score <= -240 and y.Score - x.Score > -360 then -3
				 when y.Score - x.Score <= -360 and y.Score - x.Score > -550 then -4
				 when y.Score - x.Score <= -550 then -5
			end as ScoreChangeBand,
			y.VsOpen_Up - x.VsOpen_Up as VsOpen_UpChange, 
			y.VsVWAP_Up - x.VsVWAP_Up as VsVWAP_UpChange
		into #Temp2
		from
		(
			select *, row_number() over (partition by ObservationDate order by ObservationTime asc) as RowNumber
			from [StockData].[v_IntradayIndexChanges]
			where 1 =1 
			and ObservationTime >= '10:20:00.0000000'
			and MarketCapType = @pvchMarketCapType
		) as x
		inner join
		(
			select *, row_number() over (partition by ObservationDate order by ObservationTime desc) as RowNumber
			from [StockData].[v_IntradayIndexChanges]
			where 1 = 1
			and MarketCapType = @pvchMarketCapType
		) as y
		on x.ObservationDate = y.ObservationDate
		where x.RowNumber = 1
		and y.RowNumber = 1
		order by x.ObservationDate;

		select top (@pintNumObservations)
			a.ASXCode as IndexCode, 
			b.MarketCapType,
			b.ObservationDate,
			a.ChangePerc as IndexChangePerc, 
			b.ScoreChange,
			b.ScoreChangeBand,
			case when b.ScoreChangeBand >= 1 and a.ChangePerc >= 0 then 1
				 when b.ScoreChangeBand <= -1 and a.ChangePerc <= 0 then 1
				 when b.ScoreChangeBand = 0 or abs(ChangePerc) < 0.25 then null
				 else 0
			end as ScoreChangeCorrect,
			b.VsOpen_UpChange,
			b.VsVWAP_UpChange
		from #Temp2 as b
		left join #Temp as a
		on a.ObservationDate = b.ObservationDate
		where 1 = 1
		--and a.ObservationDate between '2022-02-26' and '2022-04-30'
		and b.ScoreChange is not null
		order by b.ObservationDate desc

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