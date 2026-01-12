from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from datetime import date, timedelta
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging
import traceback

router = APIRouter(prefix="/api", tags=["gap-up-watchlist"])
logger = logging.getLogger("app.gap_up_watchlist")

# DEFAULT THRESHOLDS
DEFAULT_GAP_PCT = 6.0          # 6% gap between today's low and yesterday's high
DEFAULT_VOLUME_MULTIPLIER = 5.0  # 5x the 20-day average
DEFAULT_MIN_VOLUME_VALUE = 600000  # $600K minimum volume value
DEFAULT_MIN_PRICE = 0.02       # Minimum price threshold
DEFAULT_CLOSE_LOCATION = 0.5   # (close-low)/(high-low) must be > 0.5


def get_gap_up_data(observation_date: date) -> List[Dict[str, Any]]:
    """
    Fetches the last 65 trading records for stocks to enable:
    - 20-day average volume calculation
    - 60-day high close comparison
    - Yesterday's high for gap calculation
    """
    query = """
    WITH TodayCandidates AS (
        SELECT a.ASXCode
        FROM StockDB.[Transform].[PriceHistory] AS a
        WHERE a.ObservationDate = ?
          AND a.[Value] >= 10000
          AND a.[Close] IS NOT NULL
    ),
    RankedData AS (
        SELECT
            a.ASXCode,
            a.ObservationDate,
            a.[Open],
            a.[Close],
            a.[High],
            a.[Low],
            a.[Value],
            a.PriceChangeVsPrevClose,
            b.TomorrowChange,
            b.Next2DaysChange,
            b.Next5DaysChange,
            b.Next10DaysChange,
            ROW_NUMBER() OVER(PARTITION BY a.ASXCode ORDER BY a.ObservationDate DESC) as rn
        FROM StockDB.[Transform].[PriceHistory] as a
        LEFT JOIN StockDB.[Transform].[PriceHistory24Month] as b
            ON a.ASXCode = b.ASXCode
            AND a.ObservationDate = b.ObservationDate
        INNER JOIN TodayCandidates tc
            ON tc.ASXCode = a.ASXCode
        WHERE a.ObservationDate <= ?
    )
    SELECT * FROM RankedData
    WHERE rn <= 65
    ORDER BY ASXCode, rn ASC
    OPTION (RECOMPILE)
    """

    try:
        logger.info(f"Fetching gap up data for date {observation_date}")
        model = get_sql_model()
        data = model.execute_read_query(query, (observation_date, observation_date))
        logger.info(f"Retrieved {len(data) if data else 0} rows from database")
        return data or []
    except Exception as e:
        logger.error(f"Database Error: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database Error: {str(e)}")


def analyze_gap_up_patterns(
    observation_date: date,
    gap_pct: float = DEFAULT_GAP_PCT,
    volume_multiplier: float = DEFAULT_VOLUME_MULTIPLIER,
    min_volume_value: float = DEFAULT_MIN_VOLUME_VALUE,
    min_price: float = DEFAULT_MIN_PRICE,
    close_location_threshold: float = DEFAULT_CLOSE_LOCATION
) -> List[Dict[str, Any]]:
    """
    Analyzes stock data to identify significant gap up patterns.

    Conditions:
    1. Today's low > yesterday's high by at least gap_pct%
    2. Volume today >= volume_multiplier * 20-day average AND >= min_volume_value
    3. Close price location (close-low)/(high-low) > close_location_threshold
    4. Close > Open (bullish candle)
    5. Close > highest close in last 60 days
    6. Today's price > min_price
    """
    df_raw = get_gap_up_data(observation_date)

    if not df_raw:
        return []

    # Group by ASXCode
    grouped_data = {}
    for row in df_raw:
        symbol = row['ASXCode']
        if symbol not in grouped_data:
            grouped_data[symbol] = []
        grouped_data[symbol].append(row)

    candidates = []

    for symbol, group in grouped_data.items():
        # Sort by rn (1=Latest/Today, 2=Yesterday, etc.)
        group = sorted(group, key=lambda x: x['rn'])

        if len(group) < 2:
            continue  # Need at least 2 days (today + yesterday)

        t0 = group[0]  # Today
        t1 = group[1]  # Yesterday

        # Skip if critical data is missing
        if (t0['Close'] is None or t0['Low'] is None or t0['High'] is None or
            t0['Open'] is None or t0['Value'] is None or
            t1['High'] is None):
            continue

        # Convert to float for calculations
        today_close = float(t0['Close'])
        today_low = float(t0['Low'])
        today_high = float(t0['High'])
        today_open = float(t0['Open'])
        today_volume = float(t0['Value'])
        yesterday_high = float(t1['High'])

        # Condition 6: Today's price must be > min_price
        if today_close <= min_price:
            continue

        # Condition 1: Gap up - today's low > yesterday's high by at least gap_pct%
        if yesterday_high == 0:
            continue
        gap_percentage = ((today_low - yesterday_high) / yesterday_high) * 100
        if gap_percentage < gap_pct:
            continue

        # Calculate 20-day average volume
        volumes = [float(day['Value']) for day in group[:min(21, len(group))] if day['Value'] is not None]
        if len(volumes) < 10:  # Need at least 10 days
            continue

        avg_volume_20d = sum(volumes) / len(volumes)

        # Condition 2: Volume today >= volume_multiplier * 20-day average AND >= min_volume_value
        if today_volume < (volume_multiplier * avg_volume_20d) or today_volume < min_volume_value:
            continue

        # Condition 3: Close price location (close-low)/(high-low) > close_location_threshold
        if today_high == today_low:
            continue  # Avoid division by zero
        close_location = (today_close - today_low) / (today_high - today_low)
        if close_location <= close_location_threshold:
            continue

        # Condition 4: Close must be higher than open
        if today_close <= today_open:
            continue

        # Condition 5: Close must be higher than last 60 days close
        last_60_closes = [float(day['Close']) for day in group[:min(61, len(group))] if day['Close'] is not None]
        if len(last_60_closes) < 2:  # Need at least current day + 1 historical
            continue

        max_60d_close = max(last_60_closes[1:])  # Exclude today (index 0)
        if today_close <= max_60d_close:
            continue

        # Calculate metrics for display
        volume_ratio = today_volume / avg_volume_20d if avg_volume_20d > 0 else 0
        price_change_pct = ((today_close - today_open) / today_open * 100) if today_open > 0 else 0

        candidates.append({
            'Symbol': symbol,
            'Price': round(today_close, 3),
            'Change%': round(price_change_pct, 2),
            'GapUp%': round(gap_percentage, 2),
            'VolumeVal': f"${today_volume:,.0f}",
            'VolRatio': f"{volume_ratio:.1f}x",
            'CloseLocation': f"{close_location * 100:.1f}%",
            '60dHigh': round(max_60d_close, 3),
            'Date': t0['ObservationDate'].strftime('%Y-%m-%d') if hasattr(t0['ObservationDate'], 'strftime') else str(t0['ObservationDate']),
            '1dChange': t0.get('TomorrowChange'),
            '2dChange': t0.get('Next2DaysChange'),
            '5dChange': t0.get('Next5DaysChange'),
            '10dChange': t0.get('Next10DaysChange'),
        })

    # Sort by Gap% descending
    candidates.sort(key=lambda x: -x['GapUp%'])

    return candidates


@router.get("/gap-up-watchlist")
def get_gap_up_watchlist(
    observation_date: date = Query(..., alias="date", description="Observation date, e.g. 2026-01-08"),
    gap_pct: float = Query(DEFAULT_GAP_PCT, description="Minimum gap percentage (today's low vs yesterday's high)"),
    volume_multiplier: float = Query(DEFAULT_VOLUME_MULTIPLIER, description="Volume multiplier vs 20-day average"),
    min_volume_value: float = Query(DEFAULT_MIN_VOLUME_VALUE, description="Minimum volume value in dollars"),
    min_price: float = Query(DEFAULT_MIN_PRICE, description="Minimum stock price"),
    close_location: float = Query(DEFAULT_CLOSE_LOCATION, description="Minimum close location ratio"),
    username: str = Depends(verify_credentials)
) -> List[Dict[str, Any]]:
    """
    Get gap up watchlist candidates based on significant gap up patterns.

    Identifies stocks that:
    - Gap up significantly (low > yesterday's high by gap_pct%)
    - Have volume surge (volume_multiplier times 20-day average AND >= min_volume_value)
    - Close in upper portion of range (close location > close_location)
    - Close higher than open (bullish)
    - Close above 60-day high
    - Price above min_price threshold
    """
    try:
        logger.info(f"Analyzing gap up patterns for {observation_date} (user: {username})")
        candidates = analyze_gap_up_patterns(
            observation_date,
            gap_pct,
            volume_multiplier,
            min_volume_value,
            min_price,
            close_location
        )
        logger.info(f"Found {len(candidates)} gap up candidates")
        return candidates
    except Exception as e:
        logger.error(f"Error in gap up watchlist: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
