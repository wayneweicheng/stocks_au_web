-- Stored procedure: [DataMaintenance].[usp_RefreshBrokerRetailNet]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshBrokerRetailNet]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshAlertStatsHistory.sql
Stored Procedure Name: usp_RefreshAlertStatsHistory
Overview
-----------------
usp_RefreshAlertStatsHistory

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
Date:		2019-09-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshAlertStatsHistory'
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
		if object_id(N'Transform.BrokerRetailNet') is not null
			drop table Transform.BrokerRetailNet

		select
			ASXCode,
			ObservationDate, 
			case when b.BrokerScore >= 1.2 then 'StrongBroker' 
				 when b.BrokerScore >= 0.6 and b.BrokerScore < 1.2 then 'WeakBroker'
				 when b.BrokerScore >= 0 and b.BrokerScore < 0.6 then 'FlipperBroker'
				 when b.BrokerCode not in ('ComSec') and b.BrokerScore < 0 then 'OtherRetail'
				 when b.BrokerCode in ('ComSec') and b.BrokerScore < 0 then 'ComSec'
			end as BrokerRetailNet,
			sum(NetValue) as NetValue
		into Transform.BrokerRetailNet
		from StockData.BrokerReport as a
		inner join LookupRef.BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where a.ObservationDate > dateadd(day, -180, getdate())
		group by 
			ASXCode,
			ObservationDate, 
			case when b.BrokerScore >= 1.2 then 'StrongBroker' 
				 when b.BrokerScore >= 0.6 and b.BrokerScore < 1.2 then 'WeakBroker'
				 when b.BrokerScore >= 0 and b.BrokerScore < 0.6 then 'FlipperBroker'
				 when b.BrokerCode not in ('ComSec') and b.BrokerScore < 0 then 'OtherRetail'
				 when b.BrokerCode in ('ComSec') and b.BrokerScore < 0 then 'ComSec'
			end

		create index idx_transformbrokerretailnet_asxcodeobservationdate on Transform.BrokerRetailNet(ASXCode, ObservationDate)

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
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
