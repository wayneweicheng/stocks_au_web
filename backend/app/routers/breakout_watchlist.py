from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from datetime import date, timedelta
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging
import traceback

router = APIRouter(prefix="/api", tags=["breakout-watchlist"])
logger = logging.getLogger("app.breakout_watchlist")

# LOGIC THRESHOLDS
MIN_TURNOVER = 500000   # $500,000 Value Traded
MIN_PCT_GAIN = 8.0      # 8% Gain
MAX_PRICE = 5.00        # Penny stock filter
MAX_DAY2_INCREASE_PCT = 20.0  # Day 2 can be up to 20% higher than Day 1 if both have low volume

# Debug symbols for deep logging
DEBUG_SYMBOLS = {'AQI.AX', 'HWK.AX', 'AR1.AX', 'QPM.AX', 'AEE.AX', 'ELS.AX'}


def get_recent_data(observation_date: date, max_price: float = MAX_PRICE) -> List[Dict[str, Any]]:
    """
    Fetches the last 25 trading records for EVERY stock efficiently,
    looking back from the specified observation date.
    This allows for:
    - 20-day average volume calculation
    - Up to 3-day consolidation window after breakout
    - Additional buffer for pattern detection
    """
    query = """
    WITH TodayCandidates AS (
        SELECT a.ASXCode
        FROM StockDB.[Transform].[PriceHistory] AS a
        WHERE a.ObservationDate = ?
          AND a.[Close] <= ?
          AND a.[Value] >= 10000
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
    WHERE rn <= 25
    ORDER BY ASXCode, rn ASC
    OPTION (RECOMPILE)
    """

    try:
        logger.info(f"Fetching data for date {observation_date}, max_price {max_price}")
        model = get_sql_model()
        data = model.execute_read_query(query, (observation_date, max_price, observation_date))
        logger.info(f"Retrieved {len(data) if data else 0} rows from database")
        return data or []
    except Exception as e:
        logger.error(f"Database Error: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database Error: {str(e)}")


def analyze_breakout_patterns(
    observation_date: date,
    min_turnover: float = MIN_TURNOVER,
    min_pct_gain: float = MIN_PCT_GAIN,
    max_price: float = MAX_PRICE,
    max_day2_increase_pct: float = MAX_DAY2_INCREASE_PCT
) -> List[Dict[str, Any]]:
    """
    Analyzes stock data to identify breakout patterns as of the observation date.
    Returns candidates matching FRESH BREAKOUT or CONSOLIDATION patterns.
    """
    df_raw = get_recent_data(observation_date, max_price)

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
        # Sort by rn (1=Latest, 2=Yesterday, 3=Day Before, etc.)
        group = sorted(group, key=lambda x: x['rn'])

        # Debug logging for specific stocks at entry
        if symbol in DEBUG_SYMBOLS:
            logger.info(f"{symbol}: Found {len(group)} days of data")
            for idx, day in enumerate(group[:5]):
                logger.info(f"{symbol} day {idx}: date={day['ObservationDate']}, open={day.get('Open')}, close={day['Close']}, high={day.get('High')}, low={day.get('Low')}, value={day['Value']}")

        if len(group) < 2:
            if symbol in DEBUG_SYMBOLS:
                logger.info(f"{symbol}: Skipped - insufficient data days ({len(group)})")
            continue  # Need at least 2 days for comparison

        # Calculate 20-day average volume (use as many days as available, minimum 10)
        volumes = [day['Value'] for day in group if day['Value'] is not None]
        if len(volumes) < 10:  # Need enough data for reliable average
            if symbol in DEBUG_SYMBOLS:
                logger.info(f"{symbol}: Skipped - insufficient volume data ({len(volumes)} days)")
            continue

        # Use last 20 days for average (or all available if less than 20)
        avg_volume_data = volumes[:min(20, len(volumes))]
        avg_volume_20d = sum(avg_volume_data) / len(avg_volume_data)

        if symbol in DEBUG_SYMBOLS:
            logger.info(f"{symbol}: 20-day avg volume = ${avg_volume_20d:,.0f}")

        t0 = group[0]  # Latest (today)

        # Skip if critical data is missing
        if t0['Value'] is None or t0['Close'] is None:
            if symbol in DEBUG_SYMBOLS:
                logger.info(f"{symbol}: Skipped - missing critical data (Value={t0['Value']}, Close={t0['Close']})")
            continue

        # ========== Pattern 1: FRESH BREAKOUT ==========
        # Today is the breakout day with volume surge
        if len(group) < 2:
            continue

        t1 = group[1]  # Yesterday
        if t1['Close'] is None:
            continue

        if t1['Close'] > 0:
            pct_change_t0 = (t0['Close'] - t1['Close']) / t1['Close'] * 100
        else:
            pct_change_t0 = 0

        volume_ratio_t0 = t0['Value'] / avg_volume_20d if avg_volume_20d > 0 else 0

        # Fresh breakout: Today has 8%+ gain AND 2x volume surge AND meets liquidity requirement
        if pct_change_t0 >= min_pct_gain and volume_ratio_t0 >= 2.0 and t0['Value'] >= min_turnover:
            candidates.append({
                'Symbol': symbol,
                'Pattern': 'FRESH BREAKOUT',
                'Price': round(t0['Close'], 3),
                'Change%': round(pct_change_t0, 2),
                'VolumeVal': f"${t0['Value']:,.0f}",
                'VolRatio': f"{volume_ratio_t0:.1f}x",
                'Date': t0['ObservationDate'].strftime('%Y-%m-%d') if hasattr(t0['ObservationDate'], 'strftime') else str(t0['ObservationDate']),
                'Note': '',
                '1dChange': t0.get('TomorrowChange'),
                '2dChange': t0.get('Next2DaysChange'),
                '5dChange': t0.get('Next5DaysChange'),
                '10dChange': t0.get('Next10DaysChange'),
            })
            if symbol in DEBUG_SYMBOLS:
                logger.info(f"{symbol}: Selected FRESH BREAKOUT candidate (change={pct_change_t0:.2f}%, vol_ratio={volume_ratio_t0:.2f}x, turnover=${t0['Value']:,.0f})")
        else:
            if symbol in DEBUG_SYMBOLS:
                logger.info(f"{symbol}: Not FRESH BREAKOUT: change={pct_change_t0:.2f}% (min {min_pct_gain}%), vol_ratio={volume_ratio_t0:.2f}x (min 2.0x), turnover=${t0['Value']:,.0f} (min ${min_turnover:,.0f})")

        # ========== Pattern 2: CONSOLIDATION ==========
        # Look back 1-3 days to find a breakout day, then check if today is consolidating
        # We need at least 4 days: today + 3 potential breakout days
        if len(group) < 4:
            if symbol in DEBUG_SYMBOLS:
                logger.info(f"{symbol}: Skipped consolidation - insufficient days ({len(group)}), need >= 4")
            continue

        # NO liquidity requirement on consolidation days - volume should naturally be lower
        # The $500K requirement applies ONLY to the breakout day itself (checked below)

        # However, filter out days with negligible volume (< $10K)
        if t0['Value'] < 10000:
            if symbol in DEBUG_SYMBOLS:
                logger.info(f"{symbol}: Skipped - negligible volume on observation day (${t0['Value']:,.0f})")
            continue

        if symbol in DEBUG_SYMBOLS:
            logger.info(f"{symbol}: Checking for consolidation patterns")

        # Check last 3 days (t1, t2, t3) for a breakout day
        for i in range(1, 4):  # Check positions 1, 2, 3 (yesterday, 2 days ago, 3 days ago)
            if i >= len(group):
                break

            breakout_day = group[i]
            if breakout_day['Value'] is None or breakout_day['Close'] is None:
                if symbol in DEBUG_SYMBOLS:
                    logger.info(f"{symbol}: day-{i} skipped as breakout - missing data (value={breakout_day['Value']}, close={breakout_day['Close']})")
                continue

            # Need the day before breakout to calculate gain
            if i + 1 >= len(group):
                if symbol in DEBUG_SYMBOLS:
                    logger.info(f"{symbol}: day-{i} skipped as breakout - missing prior day for gain calculation")
                continue

            day_before_breakout = group[i + 1]
            if day_before_breakout['Close'] is None or day_before_breakout['Close'] == 0:
                if symbol in DEBUG_SYMBOLS:
                    logger.info(f"{symbol}: day-{i} skipped as breakout - invalid prior close ({day_before_breakout['Close']})")
                continue

            # Calculate breakout day gain
            breakout_gain = (breakout_day['Close'] - day_before_breakout['Close']) / day_before_breakout['Close'] * 100

            # Calculate breakout day volume ratio
            breakout_vol_ratio = breakout_day['Value'] / avg_volume_20d if avg_volume_20d > 0 else 0

            # Check if breakout day meets criteria (8%+ gain, 2x volume, $500K+ turnover)
            if (breakout_gain >= min_pct_gain and
                breakout_vol_ratio >= 2.0 and
                breakout_day['Value'] >= min_turnover):

                # Now verify consolidation pattern:
                # - Volume MUST be strictly decreasing each day
                # - Spread (High-Low range) should ideally decrease
                is_valid_consolidation = True

                # Calculate breakout day spread (High - Low as % of Close)
                if breakout_day['High'] is not None and breakout_day['Low'] is not None and breakout_day['Close'] > 0:
                    breakout_spread = float((breakout_day['High'] - breakout_day['Low']) / breakout_day['Close'] * 100)
                else:
                    breakout_spread = 0.0

                # Calculate breakout day mid-price (average of High and Low)
                # Exclude if current price is below breakout mid-price
                if breakout_day['High'] is not None and breakout_day['Low'] is not None:
                    breakout_mid_price = float((breakout_day['High'] + breakout_day['Low']) / 2)
                else:
                    breakout_mid_price = float(breakout_day['Close'])

                if float(t0['Close']) < breakout_mid_price:
                    if symbol in DEBUG_SYMBOLS:
                        logger.info(f"{symbol}: Skipped - current price ${t0['Close']:.4f} below breakout mid-price ${breakout_mid_price:.4f}")
                    continue

                # Calculate maximum allowed close for consolidation days
                # Max close = breakout close + (close - open)/2
                # This ensures consolidation days don't close too high
                if breakout_day['Open'] is not None and breakout_day['Close'] is not None:
                    breakout_body_size = float(breakout_day['Close'] - breakout_day['Open'])
                    max_consolidation_close = float(breakout_day['Close']) + (breakout_body_size / 2)
                else:
                    # If Open is missing, use a more lenient threshold
                    max_consolidation_close = float(breakout_day['Close']) * 1.05  # 5% above breakout close

                # Track previous day's metrics for comparison
                prev_volume = breakout_day['Value']
                prev_spread = breakout_spread

                # Check each day from day 1 after breakout up to today
                for day_idx in range(i - 1, -1, -1):  # Walk from day after breakout to today
                    current_day = group[day_idx]
                    previous_day = group[day_idx + 1]

                    # Calculate current day's spread (High - Low as % of Close)
                    if current_day['High'] is None or current_day['Low'] is None or current_day['Close'] is None or current_day['Close'] == 0:
                        is_valid_consolidation = False
                        break

                    current_spread = float((current_day['High'] - current_day['Low']) / current_day['Close'] * 100)

                    # Consolidation requirement: volume must be strictly lower
                    if current_day['Value'] is None:
                        is_valid_consolidation = False
                        break

                    # Convert volumes to float for comparison
                    current_volume = float(current_day['Value'])
                    prev_volume_float = float(prev_volume)
                    breakout_volume = float(breakout_day['Value'])

                    # Calculate how many days after breakout we are
                    days_after_breakout = i - day_idx

                    # Special case: Day 2 after breakout can be higher than Day 1
                    # IF both Day 1 and Day 2 have significantly lower volume than breakout
                    if days_after_breakout == 2:
                        # Day 2 can be up to max_day2_increase_pct% higher than Day 1
                        # IF both have significantly lower volume than breakout (e.g., < 50% of breakout volume)
                        day1_volume = prev_volume_float
                        day2_volume = current_volume

                        # Check if both days have significantly lower volume than breakout
                        if day1_volume < (breakout_volume * 0.5) and day2_volume < (breakout_volume * 0.5):
                            # Allow Day 2 to be up to max_day2_increase_pct% higher than Day 1
                            max_allowed_day2_volume = day1_volume * (1 + max_day2_increase_pct / 100)
                            if day2_volume > max_allowed_day2_volume:
                                is_valid_consolidation = False
                                if symbol in DEBUG_SYMBOLS:
                                    logger.info(f"{symbol}: Failed consolidation at day_idx={day_idx} (Day 2): volume={day2_volume:,.0f} > {max_day2_increase_pct}% above Day 1 ({max_allowed_day2_volume:,.0f})")
                                break
                            else:
                                if symbol in DEBUG_SYMBOLS:
                                    logger.info(f"{symbol}: Day 2 volume check passed: {day2_volume:,.0f} <= {max_allowed_day2_volume:,.0f} (Day 1: {day1_volume:,.0f}, breakout: {breakout_volume:,.0f})")
                        else:
                            # If volumes aren't significantly lower than breakout, use strict decreasing rule
                            if current_volume >= prev_volume_float:
                                is_valid_consolidation = False
                                if symbol in DEBUG_SYMBOLS:
                                    logger.info(f"{symbol}: Failed consolidation at day_idx={day_idx} (Day 2): volume={current_volume:,.0f} >= prev={prev_volume_float:,.0f} (not both < 50% of breakout)")
                                break
                    else:
                        # For all other days, volume MUST be strictly decreasing
                        if current_volume >= prev_volume_float:
                            is_valid_consolidation = False
                            if symbol in DEBUG_SYMBOLS:
                                logger.info(f"{symbol}: Failed consolidation at day_idx={day_idx}: volume={current_volume:,.0f} >= prev={prev_volume_float:,.0f}")
                            break

                    # Consolidation day close must not exceed breakout close + half body size
                    # This ensures consolidation days don't close too high
                    if float(current_day['Close']) > max_consolidation_close:
                        is_valid_consolidation = False
                        if symbol in DEBUG_SYMBOLS:
                            logger.info(f"{symbol}: Failed consolidation at day_idx={day_idx}: close=${current_day['Close']:.4f} > max_allowed=${max_consolidation_close:.4f}")
                        break

                    # Spread should be ideally lower, but allow up to 10% higher than previous day
                    # Special case: if prev_spread is very small (< 0.5%), allow current spread up to 3%
                    # This handles cases where the stock consolidates flat then has small movement
                    prev_spread_float = float(prev_spread)

                    if prev_spread_float < 0.5:
                        # If previous day had minimal movement, allow up to 3% spread on current day
                        if current_spread > 3.0:
                            is_valid_consolidation = False
                            if symbol in DEBUG_SYMBOLS:
                                logger.info(f"{symbol}: Failed consolidation at day_idx={day_idx}: spread={current_spread:.2f}% > 3.0% (prev was minimal: {prev_spread_float:.2f}%)")
                            break
                    else:
                        # Normal case: current spread should be <= prev_spread * 1.50
                        if current_spread > prev_spread_float * 1.50:
                            is_valid_consolidation = False
                            if symbol in DEBUG_SYMBOLS:
                                logger.info(f"{symbol}: Failed consolidation at day_idx={day_idx}: spread={current_spread:.2f}% > prev={prev_spread_float:.2f}% * 1.10")
                            break

                    # Update for next iteration
                    prev_volume = current_day['Value']
                    prev_spread = current_spread

                if symbol in DEBUG_SYMBOLS:
                    logger.info(f"{symbol} day-{i}: gain={breakout_gain:.2f}%, vol_ratio={breakout_vol_ratio:.2f}x, turnover=${breakout_day['Value']:,.0f}, valid_consolidation={is_valid_consolidation}, today_change={pct_change_t0:.2f}%, today_turnover=${t0['Value']:,.0f}, breakout_mid_price=${breakout_mid_price:.4f}, max_consol_close=${max_consolidation_close:.4f}")

                if is_valid_consolidation:
                    days_since_breakout = i
                    breakout_date = breakout_day['ObservationDate']
                    obs_date = t0['ObservationDate']
                    breakout_date_str = breakout_date.strftime('%Y-%m-%d') if hasattr(breakout_date, 'strftime') else str(breakout_date)
                    # Calculate calendar day diff if possible
                    try:
                        date_diff_days = (obs_date - breakout_date).days  # type: ignore[operator]
                    except Exception:
                        date_diff_days = None

                    # Exclusions:
                    # - Skip consolidation when breakout was 1 trading day ago
                    if days_since_breakout == 1:
                        if symbol in DEBUG_SYMBOLS:
                            logger.info(f"{symbol}: Skipped consolidation add - breakout only 1 trading day ago")
                        continue
                    # - Skip when breakout was more than 10 calendar days ago (defensive, despite 3d scan)
                    if date_diff_days is not None and date_diff_days > 10:
                        if symbol in DEBUG_SYMBOLS:
                            logger.info(f"{symbol}: Skipped consolidation add - breakout {date_diff_days} calendar days ago (>10)")
                        continue

                    candidates.append({
                        'Symbol': symbol,
                        'Pattern': 'CONSOLIDATION',
                        'Price': round(t0['Close'], 3),
                        'Change%': round(pct_change_t0, 2),
                        'VolumeVal': f"${t0['Value']:,.0f}",
                        'VolRatio': f"{breakout_vol_ratio:.1f}x",
                        'Date': t0['ObservationDate'].strftime('%Y-%m-%d') if hasattr(t0['ObservationDate'], 'strftime') else str(t0['ObservationDate']),
                        'Note': f"Ran {round(breakout_gain, 1)}% on {breakout_date_str} ({days_since_breakout}d ago)",
                        '1dChange': t0.get('TomorrowChange'),
                        '2dChange': t0.get('Next2DaysChange'),
                        '5dChange': t0.get('Next5DaysChange'),
                        '10dChange': t0.get('Next10DaysChange'),
                    })
                    break  # Found consolidation pattern, move to next stock
            else:
                if symbol in DEBUG_SYMBOLS:
                    logger.info(f"{symbol}: day-{i} not breakout: gain={breakout_gain:.2f}% (min {min_pct_gain}%), vol_ratio={breakout_vol_ratio:.2f}x (min 2.0x), turnover=${breakout_day['Value']:,.0f} (min ${min_turnover:,.0f})")

    # Sort by Pattern then Change%
    candidates.sort(key=lambda x: (x['Pattern'], -x['Change%']))

    return candidates


@router.get("/breakout-watchlist")
def get_breakout_watchlist(
    observation_date: date = Query(..., alias="date", description="Observation date, e.g. 2026-01-08"),
    min_turnover: float = Query(MIN_TURNOVER, description="Minimum turnover in dollars"),
    min_pct_gain: float = Query(MIN_PCT_GAIN, description="Minimum percentage gain"),
    max_price: float = Query(MAX_PRICE, description="Maximum stock price (penny stock filter)"),
    max_day2_increase_pct: float = Query(MAX_DAY2_INCREASE_PCT, description="Max % Day 2 can be higher than Day 1 when both have low volume"),
    username: str = Depends(verify_credentials)
) -> List[Dict[str, Any]]:
    """
    Get breakout watch list candidates based on pattern recognition for a specific date.

    Patterns identified:
    - FRESH BREAKOUT: Stock's gain > min_pct_gain% on observation date
    - CONSOLIDATION: Yesterday had big gain, observation date is consolidating

    Special rule: Day 2 after breakout can be up to max_day2_increase_pct% higher than Day 1,
    as long as both days have significantly lower volume (< 50%) than the breakout day.
    """
    try:
        logger.info(f"Analyzing breakout patterns for {observation_date} (user: {username})")
        candidates = analyze_breakout_patterns(observation_date, min_turnover, min_pct_gain, max_price, max_day2_increase_pct)
        logger.info(f"Found {len(candidates)} candidates")
        return candidates
    except Exception as e:
        logger.error(f"Error in breakout watchlist: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
