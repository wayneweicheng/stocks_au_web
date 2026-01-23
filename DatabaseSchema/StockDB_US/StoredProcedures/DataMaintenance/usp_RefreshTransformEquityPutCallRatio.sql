-- Stored procedure: [DataMaintenance].[usp_RefreshTransformEquityPutCallRatio]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformEquityPutCallRatio]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformEquityPutCallRatio.sql
Stored Procedure Name: usp_RefreshTransformEquityPutCallRatio
Overview
-----------------
usp_RefreshTransformEquityPutCallRatio

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformEquityPutCallRatio'
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

		if object_id(N'Transform.EquityPutCallRatio') is not null
			drop table Transform.EquityPutCallRatio

		;with op1 as
		(
			select 
				a.ObservationDate, 
				a.ASXCode, 
				PorC, 
				sum(a.Volume) as TradeVolume, 
				sum(OpenInterest-Prev1OpenInterest) as OIChanges,
				case when (a.PorC = 'P' and c.[Close] <= a.Strike) or (a.PorC = 'C' and c.[Close] >= a.Strike) then 'ITM'
					 when (a.PorC = 'P' and c.[Close] > a.Strike) or (a.PorC = 'C' and c.[Close] < a.Strike) then 'OTM'
					 else 'Unknown'
				end as IOrO,
				case when datediff(day, a.ObservationDate, a.ExpiryDate) > 30 then 1
					 else 0
				end as LongExpiry
			from [StockData].[v_OptionDelayedQuote_All] as a with(nolock)
			left join StockData.v_PriceHistory as c with(nolock)
			on c.ASXCode = a.ASXCode
			and a.ObservationDate = c.ObservationDate
			where 1 = 1 
			--and a.ASXCode in ('SPY.US', 'QQQ.US')
			and a.ObservationDate > '2022-01-01'
			group by 
				PorC, 
				a.ObservationDate, 
				a.ASXCode, 
				case when (a.PorC = 'P' and c.[Close] <= a.Strike) or (a.PorC = 'C' and c.[Close] >= a.Strike) then 'ITM'
					 when (a.PorC = 'P' and c.[Close] > a.Strike) or (a.PorC = 'C' and c.[Close] < a.Strike) then 'OTM'
					 else 'Unknown'
				end,
				case when datediff(day, a.ObservationDate, a.ExpiryDate) > 30 then 1
					 else 0
				end
		)

		select 
			a.ObservationDate, 
			a.ASXCode, 
			a.IOrO,
			a.LongExpiry,
			case when b.TradeVolume > 0 then a.TradeVolume*1.0/b.TradeVolume end as PCRVolume,
			case when b.OIChanges > 0 then a.OIChanges*1.0/b.OIChanges end as PCROI,
			c.[Close]
		into Transform.EquityPutCallRatio
		from op1 as a
		inner join op1 as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		and a.PorC = 'P'
		and b.PorC = 'C'
		and a.IOrO = b.IOrO
		and a.LongExpiry = b.LongExpiry
		left join StockDB.StockData.v_PriceHistory as c
		on c.ASXCode = 'SPX'
		and a.ObservationDate = c.ObservationDate
		--and a.ObservationDate = '2022-09-14'
		where 1 = 1 
		--and a.ASXCode = 'SPY.US'
		order by a.ObservationDate desc, a.ASXCode;

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