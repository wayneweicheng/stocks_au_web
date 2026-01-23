-- Stored procedure: [DataMaintenance].[usp_CacheTokenPriceVolumeHistory]


CREATE PROCEDURE [DataMaintenance].[usp_CacheTokenPriceVolumeHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_CacheTokenPriceVolumeHistory.sql
Stored Procedure Name: usp_CacheTokenPriceVolumeHistory
Overview
-----------------
usp_CacheTokenPriceVolumeHistory

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
Date:		2018-10-30
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_CacheTokenPriceVolumeHistory'
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
		--begin transaction
		if object_id(N'Working.TokenPriceVolumeHistory') is not null
			drop table Working.TokenPriceVolumeHistory

		CREATE TABLE Working.TokenPriceVolumeHistory(
			[Token] [varchar](200) NULL,
			[ObservationDate] [varchar](50) NULL,
			[TradeValue] [decimal](38, 4) NULL,
			[ASXCode] [int] NULL,
			[SMA0] [decimal](38, 5) NULL,
			[SMA3] [decimal](38, 5) NULL,
			[SMA5] [decimal](38, 5) NULL,
			[SMA10] [decimal](38, 5) NULL,
			[SMA20] [decimal](38, 5) NULL,
			[SMA30] [decimal](38, 5) NULL
		) ON [PRIMARY]

		declare curToken cursor for
		select Token
		from LookupRef.KeyToken
		where IsDisabled = 0
		order by TokenType, Token

		declare @vchToken as varchar(200)

		open curToken
		fetch curToken into @vchToken

		while @@FETCH_STATUS = 0
		begin
			--select @vchToken

			insert into Working.TokenPriceVolumeHistory
			exec [Report].[usp_GetSectorPerformance]
			@pvchToken = @vchToken

			fetch curToken into @vchToken
			
		end

		close curToken
		deallocate curToken

		truncate table Transform.TokenPriceVolumeHistory

		insert into Transform.TokenPriceVolumeHistory
		(
		   [Token]
		  ,[ObservationDate]
		  ,[TradeValue]
		  ,[ASXCode]
		  ,[SMA0]
		  ,[SMA3]
		  ,[SMA5]
		  ,[SMA10]
		  ,[SMA20]
		  ,[SMA30]
		  ,[TokenType]
		  ,[CreateDate]
		)
		select
		   a.[Token]
		  ,a.[ObservationDate]
		  ,a.[TradeValue]
		  ,a.[ASXCode]
		  ,a.[SMA0]
		  ,a.[SMA3]
		  ,a.[SMA5]
		  ,a.[SMA10]
		  ,a.[SMA20]
		  ,a.[SMA30]
		  ,b.TokenType as [TokenType]
		  ,getdate() as [CreateDate]
		from Working.TokenPriceVolumeHistory as a
		inner join LookupRef.KeyToken as b
		on a.Token = b.Token

		update a
		set a.DateSeq = b.RowNumber
		from Transform.TokenPriceVolumeHistory as a
		inner join
		(
			select
				ObservationDate,
				Token,
				row_number() over (partition by Token order by ObservationDate) as RowNumber
			from Transform.TokenPriceVolumeHistory
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.Token = b.Token

		update a
		set AvgTradeValue = case when ASXCode > 0 then TradeValue/ASXCode end
		from Transform.TokenPriceVolumeHistory as a

		update a
		set a.AvgTradeValueSMA5 = b.AvgTradeValueSMA5,
			a.AvgTradeValueSMA120 = b.AvgTradeValueSMA120
		from Transform.TokenPriceVolumeHistory as a
		inner join
		(
			select
				Token,
				ObservationDate,
				AvgTradeValueSMA5 = avg(AvgTradeValue) over (partition by Token order by DateSeq asc rows 4 preceding),
				AvgTradeValueSMA120 = avg(AvgTradeValue) over (partition by Token order by DateSeq asc rows 119 preceding)
			from Transform.TokenPriceVolumeHistory
		) as b
		on a.Token = b.Token
		and a.ObservationDate = b.ObservationDate

		update a
		set ATVvsATVSMA5 = case when a.AvgTradeValueSMA5 > 0 then AvgTradeValue/a.AvgTradeValueSMA5 end,
			ATVvsATVSMA120 = case when a.AvgTradeValueSMA120 > 0 then AvgTradeValue/a.AvgTradeValueSMA120 end
		from Transform.TokenPriceVolumeHistory as a

		update a
		set TradeValueProfit = a.SMA0 - b.SMA0,
			TradeValueProfitPercentage = case when b.SMA0 > 0 then (a.SMA0 - b.SMA0)*100.0/b.SMA0 else null end
		from Transform.TokenPriceVolumeHistory as a
		inner join Transform.TokenPriceVolumeHistory as b
		on a.Token = b.Token
		and a.DateSeq = b.DateSeq + 1

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
