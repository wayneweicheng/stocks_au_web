-- Stored procedure: [Notification].[usp_Notify_GEXInsightAlert]


CREATE   PROCEDURE [Notification].[usp_Notify_GEXInsightAlert]
    @pvchASXCode VARCHAR(20) = 'SPXW.US',
    @pbitDebug BIT = 0
AS
SET NOCOUNT ON;

BEGIN
    DECLARE @pintErrorNumber INT = 0;

    BEGIN TRY
        DECLARE @dtTargetDate DATE;
        DECLARE @dtTopDate DATE;
        DECLARE @nvchTopInsight NVARCHAR(255);
        
        -- 1. Calculate Previous Business Day
        SET @dtTargetDate = CAST([Common].[DateAddBusinessDay_Plus](-1, GETDATE()) AS DATE);

        -- 2. Create a "Safe" Temp Table
        -- We make everything NVARCHAR(MAX) so the INSERT never fails on conversion.
        -- We will cast the data types back when we select from it.
        CREATE TABLE #CapturedResults_Safe (
            ObservationDate NVARCHAR(MAX),
            GEXInsight NVARCHAR(MAX),
            BC_GEXDeltaPerc NVARCHAR(MAX),
            BC_GEXDeltaPerc_Pre NVARCHAR(MAX),
            BP_GEXDeltaPerc NVARCHAR(MAX),
            BP_GEXDeltaPerc_Pre NVARCHAR(MAX),
            [Close] NVARCHAR(MAX),
            PreviousClose NVARCHAR(MAX),
            VWAP NVARCHAR(MAX),
            AvgGEXDelta NVARCHAR(MAX),
            NumObs NVARCHAR(MAX),
            ASXCode NVARCHAR(MAX)
        );

        -- 3. Execute the Report SP
        -- If the column order is slightly off, this will still load the data 
        -- instead of crashing, allowing us to debug or run the logic.
        INSERT INTO #CapturedResults_Safe
        EXEC [Report].[usp_Dashboard_OptionGexDeltaCapitalType_table]
            @pbitDebug = 0,
            @pvchASXCode = @pvchASXCode;

        -- 4. Retrieve the Top Row with Safe Conversion
        SELECT TOP 1 
            @dtTopDate = CAST(ObservationDate AS DATE), 
            @nvchTopInsight = GEXInsight
        FROM #CapturedResults_Safe
        ORDER BY CAST(ObservationDate AS DATETIME) DESC;

        -- Debugging: If requested, show what we captured to help verify column alignment
        IF @pbitDebug = 1
        BEGIN
            PRINT 'Target Date: ' + CAST(@dtTargetDate AS VARCHAR(50));
            PRINT 'Top Date Found: ' + CAST(@dtTopDate AS VARCHAR(50));
            PRINT 'Insight Found: ' + ISNULL(@nvchTopInsight, 'NULL');
            SELECT TOP 1 * FROM #CapturedResults_Safe ORDER BY ObservationDate DESC;
        END

        -- 5. Logic Check
        IF @dtTopDate = @dtTargetDate AND @nvchTopInsight IS NOT NULL
        BEGIN
            PRINT @nvchTopInsight;

			--declare @nvchTopInsight as varchar(200) = 'Down'
			--declare @pvchASXCode as varchar(20) = 'SPXW.US'
			--DECLARE @dtTopDate DATE = '2026-01-22';

			-- Queue notifications for subscribers based on insight direction
			DECLARE @vchSubCode VARCHAR(100);
			DECLARE @vchEventType VARCHAR(50);
			DECLARE @vchTitle NVARCHAR(255);
			DECLARE @vchBody NVARCHAR(MAX);
			DECLARE @vchContext NVARCHAR(MAX);
			declare @vchInsightMessage varchar(200);

			IF @nvchTopInsight = 'Up'
			begin
				SET @vchSubCode = 'GEX_SPXW_BULLISH';
				set @vchInsightMessage = 'Strongly Bullish';
			end
			ELSE IF @nvchTopInsight = 'Down'
			begin
				SET @vchSubCode = 'GEX_SPXW_BEARISH';
				set @vchInsightMessage = 'Strongly Bearish'
			end

			IF @vchSubCode IS NOT NULL
			BEGIN
				-- Resolve event type from subscription type (fallback to code if not found)
				SELECT TOP 1 @vchEventType = EventType
				FROM [Notification].[SubscriptionTypes]
				WHERE SubscriptionTypeCode = @vchSubCode
				  AND IsActive = 1;

				SET @vchTitle = CONCAT(N'GEX Insight: ', @pvchASXCode, N' ', @vchInsightMessage);
				SET @vchBody  = CONCAT(N'GEX Insight for ', @pvchASXCode, N' on ', CONVERT(NVARCHAR(50), @dtTopDate, 120), N': ', @vchInsightMessage);
				SET @vchContext = CONCAT(N'{"ASXCode":"', @pvchASXCode, N'","Insight":"', @nvchTopInsight, N'","Date":"', CONVERT(NVARCHAR(10), @dtTopDate, 23), N'"}');

				 --Insert one queued message per active subscriber for this subscription type and entity
				INSERT INTO [Notification].[MessageQueue] (
					EventType,
					EventSourceID,
					EventSourceTable,
					EventData,
					MessageTitle,
					MessageBody,
					TargetUserID,
					SubscriptionContext,
					QueuedBy,
					[Priority]
				)
				SELECT
					ISNULL(@vchEventType, @vchSubCode) AS EventType,
					@pvchASXCode AS EventSourceID,
					N'[Report].[usp_Dashboard_OptionGexDeltaCapitalType_table]' AS EventSourceTable,
					NULL AS EventData,
					@vchTitle,
					@vchBody,
					us.UserID,
					@vchContext,
					N'[Notification].[usp_Notify_GEXInsightAlert]',
					[Priority]
				FROM [Notification].[UserSubscriptions] us
				INNER JOIN [Notification].[SubscriptionTypes] st
					ON st.SubscriptionTypeID = us.SubscriptionTypeID
				INNER JOIN [Notification].[Users] u
					ON u.UserID = us.UserID
				WHERE st.SubscriptionTypeCode = @vchSubCode
				  AND st.IsActive = 1
				  AND us.IsActive = 1
				  AND u.IsActive = 1
				  AND us.EntityCode = @pvchASXCode
				  AND NOT EXISTS (
					SELECT 1
					FROM [Notification].[MessageQueue] mq
					WHERE mq.TargetUserID = us.UserID
						AND mq.EventType = ISNULL(@vchEventType, @vchSubCode)
						AND mq.EventSourceID = @pvchASXCode
						AND CAST(mq.QueuedDate AS DATE) = CAST(GETDATE() AS DATE)
						AND mq.Status IN ('pending','processing','sent')
				  );
			END
        END
		else
		begin
			print('No events')
		end

        DROP TABLE #CapturedResults_Safe;

    END TRY

    BEGIN CATCH
        -- If it still fails, it means the Report SP is returning a different NUMBER of columns
        DECLARE @vchErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR ('Error in Notification SP: %s', 16, 1, @vchErrorMessage);
    END CATCH

    RETURN 0;
END
