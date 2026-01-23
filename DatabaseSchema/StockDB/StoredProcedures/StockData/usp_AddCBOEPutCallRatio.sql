-- Stored procedure: [StockData].[usp_AddCBOEPutCallRatio]



create PROCEDURE [StockData].[usp_AddCBOEPutCallRatio]
 @pbitDebug AS BIT = 0
,@pintErrorNumber AS INT = 0 OUTPUT
,@pvchcboe_date  as varchar(50)
,@pvchtotal_put_call_ratio as varchar(50)
,@pvchindex_put_call_ratio as varchar(50)
,@pvchetp_put_call_ratio as varchar(50)
,@pvchequity_put_call_ratio as varchar(50)
,@pvchcboe_vix_put_call_ratio as varchar(50)
,@pvchspx_put_call_ratio as varchar(50)
,@pvchoex_put_call_ratio as varchar(50)
,@pvchmrut_put_call_ratio as varchar(50)
,@pvchvolume_put_all as varchar(50)
,@pvchvolume_call_all as varchar(50)
,@pvchvolume_total_all as varchar(50)
,@pvchopen_interest_put_all as varchar(50)
,@pvchopen_interest_call_all as varchar(50)
,@pvchopen_interest_total_all as varchar(50)
,@pvchvolume_put_index as varchar(50)
,@pvchvolume_call_index as varchar(50)
,@pvchvolume_total_index as varchar(50)
,@pvchopen_interest_put_index as varchar(50)
,@pvchopen_interest_call_index as varchar(50)
,@pvchopen_interest_total_index as varchar(50)
,@pvchvolume_put_etp as varchar(50)
,@pvchvolume_call_etp as varchar(50)
,@pvchvolume_total_etp as varchar(50)
,@pvchopen_interest_put_etp as varchar(50)
,@pvchopen_interest_call_etp as varchar(50)
,@pvchopen_interest_total_etp as varchar(50)
,@pvchvolume_put_equity as varchar(50)
,@pvchvolume_call_equity as varchar(50)
,@pvchvolume_total_equity as varchar(50)
,@pvchopen_interest_put_equity as varchar(50)
,@pvchopen_interest_call_equity as varchar(50)
,@pvchopen_interest_total_equity as varchar(50)
,@pvchvolume_put_vix as varchar(50)
,@pvchvolume_call_vix as varchar(50)
,@pvchvolume_total_vix as varchar(50)
,@pvchopen_interest_put_vix as varchar(50)
,@pvchopen_interest_call_vix as varchar(50)
,@pvchopen_interest_total_vix as varchar(50)
,@pvchvolume_put_spx as varchar(50)
,@pvchvolume_call_spx as varchar(50)
,@pvchvolume_total_spx as varchar(50)
,@pvchopen_interest_put_spx as varchar(50)
,@pvchopen_interest_call_spx as varchar(50)
,@pvchopen_interest_total_spx as varchar(50)
,@pvchvolume_put_oex as varchar(50)
,@pvchvolume_call_oex as varchar(50)
,@pvchvolume_total_oex as varchar(50)
,@pvchopen_interest_put_oex as varchar(50)
,@pvchopen_interest_call_oex as varchar(50)
,@pvchopen_interest_total_oex as varchar(50)
,@pvchvolume_put_mrut as varchar(50)
,@pvchvolume_call_mrut as varchar(50)
,@pvchvolume_total_mrut as varchar(50)
,@pvchopen_interest_put_mrut as varchar(50)
,@pvchopen_interest_call_mrut as varchar(50)
,@pvchopen_interest_total_mrut varchar(50)
AS
/******************************************************************************
File: usp_AddCBOEPutCallRatio.sql
Stored Procedure Name: usp_AddCBOEPutCallRatio
Overview
-----------------
usp_AddCBOEPutCallRatio

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
Date:		2022-05-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCBOEPutCallRatio'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchASXCode as varchar(100) = 'PLS.AX'
		--declare @pvchCompanyInfo as varchar(100) = '{}'

		--Code goes here 
		set dateformat ymd

		if object_id(N'Tempdb.dbo.#TempCBOEPutCallRatio') is not null
			drop table #TempCBOEPutCallRatio

		create table #TempCBOEPutCallRatio
		(
			 cboe_date date
			,total_put_call_ratio decimal(20, 4)
			,index_put_call_ratio decimal(20, 4)
			,etp_put_call_ratio decimal(20, 4)
			,equity_put_call_ratio decimal(20, 4)
			,cboe_vix_put_call_ratio decimal(20, 4)
			,spx_put_call_ratio decimal(20, 4)
			,oex_put_call_ratio decimal(20, 4)
			,mrut_put_call_ratio decimal(20, 4)
			,volume_put_all decimal(20, 4)
			,volume_call_all decimal(20, 4)
			,volume_total_all decimal(20, 4)
			,open_interest_put_all decimal(20, 4)
			,open_interest_call_all decimal(20, 4)
			,open_interest_total_all decimal(20, 4)
			,volume_put_index decimal(20, 4)
			,volume_call_index decimal(20, 4)
			,volume_total_index decimal(20, 4)
			,open_interest_put_index decimal(20, 4)
			,open_interest_call_index decimal(20, 4)
			,open_interest_total_index decimal(20, 4)
			,volume_put_etp decimal(20, 4)
			,volume_call_etp decimal(20, 4)
			,volume_total_etp decimal(20, 4)
			,open_interest_put_etp decimal(20, 4)
			,open_interest_call_etp decimal(20, 4)
			,open_interest_total_etp decimal(20, 4)
			,volume_put_equity decimal(20, 4)
			,volume_call_equity decimal(20, 4)
			,volume_total_equity decimal(20, 4)
			,open_interest_put_equity decimal(20, 4)
			,open_interest_call_equity decimal(20, 4)
			,open_interest_total_equity decimal(20, 4)
			,volume_put_vix decimal(20, 4)
			,volume_call_vix decimal(20, 4)
			,volume_total_vix decimal(20, 4)
			,open_interest_put_vix decimal(20, 4)
			,open_interest_call_vix decimal(20, 4)
			,open_interest_total_vix decimal(20, 4)
			,volume_put_spx decimal(20, 4)
			,volume_call_spx decimal(20, 4)
			,volume_total_spx decimal(20, 4)
			,open_interest_put_spx decimal(20, 4)
			,open_interest_call_spx decimal(20, 4)
			,open_interest_total_spx decimal(20, 4)
			,volume_put_oex decimal(20, 4)
			,volume_call_oex decimal(20, 4)
			,volume_total_oex decimal(20, 4)
			,open_interest_put_oex decimal(20, 4)
			,open_interest_call_oex decimal(20, 4)
			,open_interest_total_oex decimal(20, 4)
			,volume_put_mrut decimal(20, 4)
			,volume_call_mrut decimal(20, 4)
			,volume_total_mrut decimal(20, 4)
			,open_interest_put_mrut decimal(20, 4)
			,open_interest_call_mrut decimal(20, 4)
			,open_interest_total_mrut decimal(20, 4)
		)

		insert into #TempCBOEPutCallRatio
		(
		   [cboe_date]
		  ,[total_put_call_ratio]
		  ,[index_put_call_ratio]
		  ,[etp_put_call_ratio]
		  ,[equity_put_call_ratio]
		  ,[cboe_vix_put_call_ratio]
		  ,[spx_put_call_ratio]
		  ,[oex_put_call_ratio]
		  ,[mrut_put_call_ratio]
		  ,[volume_put_all]
		  ,[volume_call_all]
		  ,[volume_total_all]
		  ,[open_interest_put_all]
		  ,[open_interest_call_all]
		  ,[open_interest_total_all]
		  ,[volume_put_index]
		  ,[volume_call_index]
		  ,[volume_total_index]
		  ,[open_interest_put_index]
		  ,[open_interest_call_index]
		  ,[open_interest_total_index]
		  ,[volume_put_etp]
		  ,[volume_call_etp]
		  ,[volume_total_etp]
		  ,[open_interest_put_etp]
		  ,[open_interest_call_etp]
		  ,[open_interest_total_etp]
		  ,[volume_put_equity]
		  ,[volume_call_equity]
		  ,[volume_total_equity]
		  ,[open_interest_put_equity]
		  ,[open_interest_call_equity]
		  ,[open_interest_total_equity]
		  ,[volume_put_vix]
		  ,[volume_call_vix]
		  ,[volume_total_vix]
		  ,[open_interest_put_vix]
		  ,[open_interest_call_vix]
		  ,[open_interest_total_vix]
		  ,[volume_put_spx]
		  ,[volume_call_spx]
		  ,[volume_total_spx]
		  ,[open_interest_put_spx]
		  ,[open_interest_call_spx]
		  ,[open_interest_total_spx]
		  ,[volume_put_oex]
		  ,[volume_call_oex]
		  ,[volume_total_oex]
		  ,[open_interest_put_oex]
		  ,[open_interest_call_oex]
		  ,[open_interest_total_oex]
		  ,[volume_put_mrut]
		  ,[volume_call_mrut]
		  ,[volume_total_mrut]
		  ,[open_interest_put_mrut]
		  ,[open_interest_call_mrut]
		  ,[open_interest_total_mrut]
		)
		select
		 @pvchcboe_date as date
		,cast(replace(@pvchtotal_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchindex_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchetp_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchequity_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchcboe_vix_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchspx_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchoex_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchmrut_put_call_ratio, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_all, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_all, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_all, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_all, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_all, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_all, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_index, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_index, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_index, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_index, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_index, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_index, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_etp, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_etp, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_etp, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_etp, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_etp, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_etp, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_equity, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_equity, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_equity, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_equity, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_equity, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_equity, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_vix, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_vix, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_vix, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_vix, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_vix, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_vix, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_spx, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_spx, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_spx, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_spx, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_spx, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_spx, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_oex, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_oex, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_oex, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_oex, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_oex, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_oex, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_put_mrut, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_call_mrut, ',', '') as decimal(20, 4))
		,cast(replace(@pvchvolume_total_mrut, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_put_mrut, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_call_mrut, ',', '') as decimal(20, 4))
		,cast(replace(@pvchopen_interest_total_mrut, ',', '') as decimal(20, 4))

		delete a
		from StockData.CBOEPutCallRatio as a
		inner join #TempCBOEPutCallRatio as b
		on a.cboe_date = b.cboe_date

		insert into StockData.CBOEPutCallRatio
		(
		   [cboe_date]
		  ,[total_put_call_ratio]
		  ,[index_put_call_ratio]
		  ,[etp_put_call_ratio]
		  ,[equity_put_call_ratio]
		  ,[cboe_vix_put_call_ratio]
		  ,[spx_put_call_ratio]
		  ,[oex_put_call_ratio]
		  ,[mrut_put_call_ratio]
		  ,[volume_put_all]
		  ,[volume_call_all]
		  ,[volume_total_all]
		  ,[open_interest_put_all]
		  ,[open_interest_call_all]
		  ,[open_interest_total_all]
		  ,[volume_put_index]
		  ,[volume_call_index]
		  ,[volume_total_index]
		  ,[open_interest_put_index]
		  ,[open_interest_call_index]
		  ,[open_interest_total_index]
		  ,[volume_put_etp]
		  ,[volume_call_etp]
		  ,[volume_total_etp]
		  ,[open_interest_put_etp]
		  ,[open_interest_call_etp]
		  ,[open_interest_total_etp]
		  ,[volume_put_equity]
		  ,[volume_call_equity]
		  ,[volume_total_equity]
		  ,[open_interest_put_equity]
		  ,[open_interest_call_equity]
		  ,[open_interest_total_equity]
		  ,[volume_put_vix]
		  ,[volume_call_vix]
		  ,[volume_total_vix]
		  ,[open_interest_put_vix]
		  ,[open_interest_call_vix]
		  ,[open_interest_total_vix]
		  ,[volume_put_spx]
		  ,[volume_call_spx]
		  ,[volume_total_spx]
		  ,[open_interest_put_spx]
		  ,[open_interest_call_spx]
		  ,[open_interest_total_spx]
		  ,[volume_put_oex]
		  ,[volume_call_oex]
		  ,[volume_total_oex]
		  ,[open_interest_put_oex]
		  ,[open_interest_call_oex]
		  ,[open_interest_total_oex]
		  ,[volume_put_mrut]
		  ,[volume_call_mrut]
		  ,[volume_total_mrut]
		  ,[open_interest_put_mrut]
		  ,[open_interest_call_mrut]
		  ,[open_interest_total_mrut]
		  ,[CreateDate]
		)
		select
		   [cboe_date]
		  ,[total_put_call_ratio]
		  ,[index_put_call_ratio]
		  ,[etp_put_call_ratio]
		  ,[equity_put_call_ratio]
		  ,[cboe_vix_put_call_ratio]
		  ,[spx_put_call_ratio]
		  ,[oex_put_call_ratio]
		  ,[mrut_put_call_ratio]
		  ,[volume_put_all]
		  ,[volume_call_all]
		  ,[volume_total_all]
		  ,[open_interest_put_all]
		  ,[open_interest_call_all]
		  ,[open_interest_total_all]
		  ,[volume_put_index]
		  ,[volume_call_index]
		  ,[volume_total_index]
		  ,[open_interest_put_index]
		  ,[open_interest_call_index]
		  ,[open_interest_total_index]
		  ,[volume_put_etp]
		  ,[volume_call_etp]
		  ,[volume_total_etp]
		  ,[open_interest_put_etp]
		  ,[open_interest_call_etp]
		  ,[open_interest_total_etp]
		  ,[volume_put_equity]
		  ,[volume_call_equity]
		  ,[volume_total_equity]
		  ,[open_interest_put_equity]
		  ,[open_interest_call_equity]
		  ,[open_interest_total_equity]
		  ,[volume_put_vix]
		  ,[volume_call_vix]
		  ,[volume_total_vix]
		  ,[open_interest_put_vix]
		  ,[open_interest_call_vix]
		  ,[open_interest_total_vix]
		  ,[volume_put_spx]
		  ,[volume_call_spx]
		  ,[volume_total_spx]
		  ,[open_interest_put_spx]
		  ,[open_interest_call_spx]
		  ,[open_interest_total_spx]
		  ,[volume_put_oex]
		  ,[volume_call_oex]
		  ,[volume_total_oex]
		  ,[open_interest_put_oex]
		  ,[open_interest_call_oex]
		  ,[open_interest_total_oex]
		  ,[volume_put_mrut]
		  ,[volume_call_mrut]
		  ,[volume_total_mrut]
		  ,[open_interest_put_mrut]
		  ,[open_interest_call_mrut]
		  ,[open_interest_total_mrut]
		  ,getdate() as [CreateDate]
		from #TempCBOEPutCallRatio as a

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
