-- Stored procedure: [Report].[usp_GetGEXDeltaCapitalType_Analysis]


CREATE PROCEDURE [Report].[usp_GetGEXDeltaCapitalType_Analysis]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10)
AS
/******************************************************************************
File: usp_GetGEXDeltaCapitalType_Analysis.sql
Stored Procedure Name: usp_GetGEXDeltaCapitalType_Analysis
Overview
-----------------
usp_GetGEXDeltaCapitalType_Analysis

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
Date:		2018-02-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetGEXDeltaCapitalType_Analysis'
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
		--declare @pintNumPrevDay as int = 0
		if object_id(N'Tempdb.dbo.#Temp_v_OptionGexChangeCapitalType') is not null
			drop table #Temp_v_OptionGexChangeCapitalType

		select *
		into #Temp_v_OptionGexChangeCapitalType
		from StockDB_US.Transform.v_OptionGexChangeCapitalType
		where ASXCode = @pvchStockCode
		and ObservationDate > '2022-01-01'

		if object_id(N'Tempdb.dbo.#Temp_v_OptionGexChangeCapitalType_Pre') is not null
			drop table #Temp_v_OptionGexChangeCapitalType_Pre

		select *
		into #Temp_v_OptionGexChangeCapitalType_Pre
		from StockDB_US.Transform.v_OptionGexChangeCapitalType_Pre
		where ASXCode = @pvchStockCode
		and ObservationDate > '2022-01-01'

		select 
			x.ObservationDate,
			a.GEXDeltaPerc as BC_GEXDeltaPerc,
			c.GEXDeltaPerc as BC_GEXDeltaPerc_Pre,
			b.GEXDeltaPerc as BP_GEXDeltaPerc,
			d.GEXDeltaPerc as BP_GEXDeltaPerc_Pre,
			a2.GEXDeltaPerc as SC_GEXDeltaPerc,
			b2.GEXDeltaPerc as SP_GEXDeltaPerc,
			a.[Close],
			a.ASXCode
		from 
		(
			select ObservationDate, ASXCode
			from #Temp_v_OptionGexChangeCapitalType as a
			where CapitalType = 'BC'
			union
			select ObservationDate, ASXCode 
			from #Temp_v_OptionGexChangeCapitalType_Pre as a
			where CapitalType = 'BC'
		) as x
		left join StockDB_US.Transform.v_OptionGexChangeCapitalType as a
		on x.ASXCode = a.ASXCode
		and x.ObservationDate = a.ObservationDate
		and a.CapitalType = 'BC'
		left join StockDB_US.Transform.v_OptionGexChangeCapitalType as b
		on x.ASXCode = b.ASXCode
		and x.ObservationDate = b.ObservationDate
		and b.CapitalType = 'BP'
		left join StockDB_US.Transform.v_OptionGexChangeCapitalType as a2
		on x.ASXCode = a2.ASXCode
		and x.ObservationDate = a2.ObservationDate
		and a2.CapitalType = 'SC'
		left join StockDB_US.Transform.v_OptionGexChangeCapitalType as b2
		on x.ASXCode = b2.ASXCode
		and x.ObservationDate = b2.ObservationDate
		and b2.CapitalType = 'SP'
		left join StockDB_US.Transform.v_OptionGexChangeCapitalType_Pre as c
		on x.ASXCode = c.ASXCode
		and x.ObservationDate = c.ObservationDate
		and c.CapitalType = 'BC'
		left join StockDB_US.Transform.v_OptionGexChangeCapitalType_Pre as d
		on x.ASXCode = d.ASXCode
		and x.ObservationDate = d.ObservationDate
		and d.CapitalType = 'BP'
		where 1 = 1
		order by case when x.ASXCode = 'SPXW.US' then 1 else 0 end desc, x.ASXCode, x.ObservationDate desc, a.CapitalType

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
