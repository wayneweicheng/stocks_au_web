-- Stored procedure: [AutoTrade].[usp_AddTradeRequestFromHCQualityPoster]

CREATE PROCEDURE [AutoTrade].[usp_AddTradeRequestFromHCQualityPoster]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchPostUrl as varchar(500),
@pvchPostDateTime as varchar(100),
@pvchPoster as varchar(200),
@pintPosterIsHeart bit,
@pvchPostContent varchar(max),
@pvchPostFooter varchar(max)
AS
/******************************************************************************
File: usp_AddTradeRequestFromHCQualityPoster.sql
Stored Procedure Name: usp_AddTradeRequestFromHCQualityPoster
Overview
-----------------
usp_AddTradeRequestFromHCQualityPoster

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
Date:		2017-12-31
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddTradeRequestFromHCQualityPoster'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'AutoTrade'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if len(@pvchPostUrl) > 0 and len(@pvchPostDateTime) > 0 and len(@pvchPoster) > 0 and len(@pvchPostFooter) > 0
		begin
			print 'OK'
		end
		else
		begin
			raiserror('Values not populated', 16, 0)
		end

		set dateformat dmy

		--insert into HC.PostScan
		--(
		--	ASXCode,
		--	CreateDate
		--)
		--select
		--	@pvchASXCode as ASXCode,
		--	getdate() as CreateDate

		if object_id(N'Tempdb.dbo.#TempPost') is not null
			drop table #TempPost

		CREATE TABLE #TempPost(
			[ASXCode] [varchar](10) NOT NULL,
			[PostUrl] [varchar](500) NOT NULL,
			[PostDateTime] [smalldatetime] NOT NULL,
			[Poster] [varchar](200) NOT NULL,
			[PosterIsHeart] [bit] NOT NULL,
			[PostContent] [varchar](max) NULL,
			[PostFooter] [varchar](max) NOT NULL,
			[CreateDate] [smalldatetime] NOT NULL,
			[PriceAtPosting] [varchar](100) NULL,
			[Sentiment] [varchar](100) NULL,
			[Disclosure] [varchar](100) NULL,
			[QualityPosterRating] [tinyint] NULL
		) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

		insert into #TempPost
		(
			ASXCode,
			PostUrl,
			PostDateTime,
			Poster,
			PosterIsHeart,
			PostContent,
			PostFooter,
			CreateDate,
			PriceAtPosting,
			Sentiment,
			Disclosure
		)
		select
			@pvchASXCode as ASXCode,
			@pvchPostUrl as PostUrl,
			cast(@pvchPostDateTime as smalldatetime) as PostDateTime,
			@pvchPoster as Poster,
			cast(@pintPosterIsHeart as bit) as PosterIsHeart,
			case when @pintPosterIsHeart = 1 then @pvchPostContent else null end as PostContent,
			@pvchPostFooter as PostFooter,
			getdate() as CreateDate,
			replace(DA_Utility.dbo.RegexMatch(replace(replace(replace(@pvchPostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Priceatposting:).{0,30}(?=</span>)'), '&cent;', 'c') as PriceAtPosting,
			DA_Utility.dbo.RegexMatch(replace(replace(replace(@pvchPostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Sentiment:).{0,30}(?=</span>)') as Sentiment,
			DA_Utility.dbo.RegexMatch(replace(replace(replace(@pvchPostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Disclosure:).{0,30}(?=</span>)') as Disclosure
		--where not exists
		--(
		--	select 1
		--	from HC.PostRaw
		--	where PostUrl = @pvchPostUrl
		--)
		
		--if object_id(N'Working.TempPost') is not null
		--	drop table Working.TempPost

		--select *
		--into Working.TempPost
		--from #TempPost

		declare @intRating as tinyint
		select @intRating = Rating
		from HC.QualityPoster
		where Poster = @pvchPoster

		declare @decPrice as decimal(20, 4)
		select @decPrice = max(
			case when PriceAtPosting like '%c' then 0.01*cast(replace(PriceAtPosting, 'c', '') as decimal(20, 4))
				 when PriceAtPosting like '$%' then 1*cast(replace(PriceAtPosting, '$', '') as decimal(20, 4))
			end	 	
		)
		from #TempPost

		declare @bitAddRequest as bit = 1

		if datediff(hour, cast(@pvchPostDateTime as smalldatetime), getdate()) > 24
		begin
			select @bitAddRequest = 0
		end

		if exists
		(
			select 1
			from #TempPost
			where Sentiment not in ('Buy', 'Hold', 'None')
			or Disclosure != 'Held'
		)
		begin
			select @bitAddRequest = 0
		end

		--if not exists
		--(
		--	select 1
		--	from StockData.MonitorStock
		--	where MonitorTypeID = 'T'
		--	and ASXCode = @pvchASXCode
		--)
		--begin
		--	select @bitAddRequest = 0
		--end

		declare @dtMinPostDate as date
		select @dtMinPostDate = min(PostDateTime)
		from HC.PostRaw 

		if exists
		(
			select 1
			from HC.PostRaw
			where ASXCode = @pvchASXCode
			and Poster = @pvchPoster
			and Disclosure = 'Held'
			and datediff(day, CreateDate, getdate()) < 90
		) and datediff(day, @dtMinPostDate, getdate()) > 30
		begin
			select @bitAddRequest = 0
		end

		if exists
		(
			select 1
			from [AutoTrade].[TradeRequest]
			where ASXCode = @pvchASXCode
			and TradeStrategyID = 1
			and TradeStrategyMessage = @pvchPoster
			and BuySellFlag = 'B'
			and datediff(day, CreateDate, getdate()) < 60
		)
		begin
			select @bitAddRequest = 0
		end

		if @bitAddRequest = 1 and @decPrice < 5.0
		begin
			insert into [AutoTrade].[TradeRequest]
			(
			   [ASXCode]
			  ,[BuySellFlag]
			  ,[Price]
			  ,[StopLossPrice]
			  ,[StopProfitPrice]
			  ,[MinVolume]
			  ,[MaxVolume]
			  ,[RequestValidTimeFrameInMin]
			  ,[RequestValidUntil]
			  ,[CreateDate]
			  ,[LastTryDate]
			  ,[OrderPlaceDate]
			  ,[OrderPlaceVolume]
			  ,[OrderReceiptID]
			  ,[OrderFillDate]
			  ,[OrderFillVolume]
			  ,[RequestStatus]
			  ,[RequestStatusMessage]
			  ,[PreReqTradeRequestID]
			  ,[AccountNumber]
			  ,[TradeStrategyID]
			  ,[ErrorCount]
			  ,TradeStrategyMessage
			  ,TradeRank
			)
			select
			   ASXCode as [ASXCode]
			  ,'B' as [BuySellFlag]
			  ,Common.CalculateBuyPrice(@decPrice, @intRating) as [Price]
			  ,null as [StopLossPrice]
			  ,@decPrice*2 as [StopProfitPrice]
			  ,Common.CalculateMinVolume(@decPrice, @intRating) as [MinVolume]
			  ,Common.CalculateMaxVolume(@decPrice, @intRating) as [MaxVolume]
			  ,60 as [RequestValidTimeFrameInMin]
			  ,dateadd(minute, 60, getdate()) as [RequestValidUntil]
			  ,getdate() as [CreateDate]
			  ,null as [LastTryDate]
			  ,null as [OrderPlaceDate]
			  ,null as [OrderPlaceVolume]
			  ,null as [OrderReceiptID]
			  ,null as [OrderFillDate]
			  ,null as [OrderFillVolume]
			  ,'R' as [RequestStatus]
			  ,null as [RequestStatusMessage]
			  ,null as [PreReqTradeRequestID]
			  ,null as [AccountNumber]
			  ,1 as [TradeStrategyID]
			  ,0 as [ErrorCount]
			  ,Poster as TradeStrategyMessage
			  ,@intRating as TradeRank
			from #TempPost
		end

		insert into HC.PostRaw
		(
			ASXCode,
			PostUrl,
			PostDateTime,
			Poster,
			PosterIsHeart,
			PostContent,
			PostFooter,
			CreateDate,
			PriceAtPosting,
			Sentiment,
			Disclosure
		)
		select
			@pvchASXCode as ASXCode,
			@pvchPostUrl as PostUrl,
			cast(@pvchPostDateTime as smalldatetime) as PostDateTime,
			@pvchPoster as Poster,
			cast(@pintPosterIsHeart as bit) as PosterIsHeart,
			case when @pintPosterIsHeart = 1 then @pvchPostContent else null end as PostContent,
			@pvchPostFooter as PostFooter,
			getdate() as CreateDate,
			PriceAtPosting,
			Sentiment,
			Disclosure
		from #TempPost
		where not exists
		(
			select 1
			from HC.PostRaw
			where PostUrl = @pvchPostUrl
		)

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