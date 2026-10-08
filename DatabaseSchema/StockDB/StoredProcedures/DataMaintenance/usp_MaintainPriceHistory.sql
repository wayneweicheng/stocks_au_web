-- Stored procedure: [DataMaintenance].[usp_MaintainPriceHistory]





CREATE OR ALTER PROCEDURE [DataMaintenance].[usp_MaintainPriceHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_MaintainStockData.sql
Stored Procedure Name: usp_MaintainStockData
Overview
-----------------
usp_MaintainStockData

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MaintainPriceHistory'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		-- Serialize this loader with other price-history writers and make the
		-- delete/insert operation atomic. PriceHistory has no Exchange column,
		-- so concurrent ASX and SMART writers can otherwise insert the same
		-- ASXCode/ObservationDate key.
		set xact_abort on;
		begin transaction;

		declare @lockResult int;
		exec @lockResult = sys.sp_getapplock
			@Resource = 'StockDB.PriceHistory.ASXLoader',
			@LockMode = 'Exclusive',
			@LockOwner = 'Transaction',
			@LockTimeout = 60000;
		if @lockResult < 0
		begin
			raiserror ('Unable to acquire the StockDB price-history loader lock.', 16, 1);
		end

		declare @dtYesterdayDate as date = Common.DateAddBusinessDay_Plus(-1, getdate());

		delete a
		from StockData.PriceHistory as a
		where exists
		(
			select 1
			from StockData.PriceHistorySecondary as b
			where a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			and b.Exchange = 'ASX'
			and b.Volume > 0
			and b.ObservationDate >= @dtYesterdayDate
		);

		-- PriceHistory is keyed only by ASXCode/ObservationDate. Select one
		-- source row per target key; SELECT DISTINCT does not protect against
		-- differing values for the same key.
		;with SourceRows as
		(
			select
				a.[ASXCode],
				a.[ObservationDate],
				a.[Close],
				a.[Open],
				a.[Low],
				a.[High],
				a.[Volume],
				a.[Trades],
				a.[CreateDate],
				a.[ModifyDate],
				a.[VWAP],
				row_number() over
				(
					partition by a.[ASXCode], a.[ObservationDate]
					order by a.[ModifyDate] desc, a.[CreateDate] desc, a.[Volume] desc
				) as SourceRank
			from StockData.PriceHistorySecondary as a with (updlock, holdlock)
			where a.Exchange = 'ASX'
			and a.Volume > 0
		)
		insert into StockData.PriceHistory
		(
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
		)
		select
		   a.[ASXCode]
		  ,a.[ObservationDate]
		  ,a.[Close]
		  ,a.[Open]
		  ,a.[Low]
		  ,a.[High]
		  ,a.[Volume]
		  ,a.[VWAP] * a.[Volume] as [Value]
		  ,a.[Trades]
		  ,a.[CreateDate]
		  ,a.[ModifyDate]
		from SourceRows as a
		where a.SourceRank = 1
		and not exists
		(
			select 1
			from StockData.PriceHistory as p with (updlock, holdlock)
			where p.ASXCode = a.ASXCode
			and p.ObservationDate = a.ObservationDate
		);

		commit transaction;

		exec [Transform].[usp_RefreshTransformPriceHistory]
		
	END TRY

	BEGIN CATCH
		-- Preserve failures for SQL Agent/API callers. The old procedure sent
		-- email but could leave downstream jobs falsely green.
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()

		if @@TRANCOUNT > 0
			rollback transaction;

		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_MaintainPriceHistory failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

		raiserror (@vchErrorMessage, 16, 1);
	END CATCH

	IF @pbitDebug = 1
	BEGIN
		PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
