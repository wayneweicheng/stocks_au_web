from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from datetime import date
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging
import traceback

router = APIRouter(prefix="/api", tags=["breakout-watchlist-us"])
logger = logging.getLogger("app.breakout_watchlist_us")

# LOGIC THRESHOLDS
MIN_TURNOVER = 5000000   # $500,000 Value Traded
MIN_PCT_GAIN = 8.0      # 8% Gain
MAX_PRICE = 5000.00        # Penny stock filter

# Debug symbols for deep logging (left as-is; harmless if symbols differ)
DEBUG_SYMBOLS = {'TSLA.US', 'PLTR.US'}


def get_recent_data_us(observation_date: date, max_price: float = MAX_PRICE) -> List[Dict[str, Any]]:
	"""
	Fetches the last 25 trading records for EVERY stock efficiently from US DB,
	looking back from the specified observation date.
	"""
	query = """
	WITH RankedData AS (
		SELECT
			ASXCode,
			ObservationDate,
			[Open],
			[Close],
			[High],
			[Low],
			[Value],
			PriceChangeVsPrevClose,
			ROW_NUMBER() OVER(PARTITION BY ASXCode ORDER BY ObservationDate DESC) as rn
		FROM StockDB_US.[Transform].[PriceHistory]
		WHERE [Close] <= ? AND ObservationDate <= ?
	)
	SELECT * FROM RankedData
	WHERE rn <= 25
	ORDER BY ASXCode, rn ASC
	"""

	try:
		logger.info(f"[US] Fetching data for date {observation_date}, max_price {max_price}")
		model = get_sql_model()
		data = model.execute_read_query(query, (max_price, observation_date))
		logger.info(f"[US] Retrieved {len(data) if data else 0} rows from database")
		return data or []
	except Exception as e:
		logger.error(f"[US] Database Error: {str(e)}")
		logger.error(traceback.format_exc())
		raise HTTPException(status_code=500, detail=f"Database Error: {str(e)}")


def analyze_breakout_patterns_us(
	observation_date: date,
	min_turnover: float = MIN_TURNOVER,
	min_pct_gain: float = MIN_PCT_GAIN,
	max_price: float = MAX_PRICE
) -> List[Dict[str, Any]]:
	"""
	Analyzes stock data to identify breakout patterns as of the observation date.
	Returns candidates matching FRESH BREAKOUT or CONSOLIDATION patterns.
	Same logic as AU, different data source (US).
	"""
	df_raw = get_recent_data_us(observation_date, max_price)

	if not df_raw:
		return []

	# Group by ASXCode (assumes same schema in US DB)
	grouped_data: Dict[str, List[Dict[str, Any]]] = {}
	for row in df_raw:
		symbol = row['ASXCode']
		if symbol not in grouped_data:
			grouped_data[symbol] = []
		grouped_data[symbol].append(row)

	candidates: List[Dict[str, Any]] = []

	for symbol, group in grouped_data.items():
		group = sorted(group, key=lambda x: x['rn'])

		if len(group) < 2:
			continue

		volumes = [day['Value'] for day in group if day['Value'] is not None]
		if len(volumes) < 10:
			continue

		avg_volume_data = volumes[:min(20, len(volumes))]
		avg_volume_20d = sum(avg_volume_data) / len(avg_volume_data)

		t0 = group[0]
		if t0['Value'] is None or t0['Close'] is None:
			continue

		# Fresh breakout
		t1 = group[1]
		if t1['Close'] is None:
			continue

		if t1['Close'] > 0:
			pct_change_t0 = (t0['Close'] - t1['Close']) / t1['Close'] * 100
		else:
			pct_change_t0 = 0
		volume_ratio_t0 = t0['Value'] / avg_volume_20d if avg_volume_20d > 0 else 0

		if pct_change_t0 >= min_pct_gain and volume_ratio_t0 >= 2.0 and t0['Value'] >= min_turnover:
			candidates.append({
				'Symbol': symbol,
				'Pattern': 'FRESH BREAKOUT',
				'Price': round(t0['Close'], 3),
				'Change%': round(pct_change_t0, 2),
				'VolumeVal': f"${t0['Value']:,.0f}",
				'VolRatio': f"{volume_ratio_t0:.1f}x",
				'Date': t0['ObservationDate'].strftime('%Y-%m-%d') if hasattr(t0['ObservationDate'], 'strftime') else str(t0['ObservationDate']),
				'Note': ''
			})

		# Consolidation
		if len(group) < 4:
			continue
		if t0['Value'] < 10000:
			continue

		for i in range(1, 4):
			if i >= len(group):
				break

			breakout_day = group[i]
			if breakout_day['Value'] is None or breakout_day['Close'] is None:
				continue

			if i + 1 >= len(group):
				continue
			day_before_breakout = group[i + 1]
			if day_before_breakout['Close'] is None or day_before_breakout['Close'] == 0:
				continue

			breakout_gain = (breakout_day['Close'] - day_before_breakout['Close']) / day_before_breakout['Close'] * 100
			breakout_vol_ratio = breakout_day['Value'] / avg_volume_20d if avg_volume_20d > 0 else 0

			if (breakout_gain >= min_pct_gain and
				breakout_vol_ratio >= 2.0 and
				breakout_day['Value'] >= min_turnover):

				is_valid_consolidation = True

				if breakout_day['High'] is not None and breakout_day['Low'] is not None and breakout_day['Close'] > 0:
					breakout_spread = float((breakout_day['High'] - breakout_day['Low']) / breakout_day['Close'] * 100)
				else:
					breakout_spread = 0.0

				if breakout_day['High'] is not None and breakout_day['Low'] is not None:
					breakout_mid_price = float((breakout_day['High'] + breakout_day['Low']) / 2)
				else:
					breakout_mid_price = float(breakout_day['Close'])

				if float(t0['Close']) < breakout_mid_price:
					continue

				if breakout_day['Open'] is not None and breakout_day['Close'] is not None:
					breakout_body_size = float(breakout_day['Close'] - breakout_day['Open'])
					max_consolidation_close = float(breakout_day['Close']) + (breakout_body_size / 2)
				else:
					max_consolidation_close = float(breakout_day['Close']) * 1.05

				prev_volume = breakout_day['Value']
				prev_spread = breakout_spread

				for day_idx in range(i - 1, -1, -1):
					current_day = group[day_idx]
					if current_day['High'] is None or current_day['Low'] is None or current_day['Close'] is None or current_day['Close'] == 0:
						is_valid_consolidation = False
						break
					current_spread = float((current_day['High'] - current_day['Low']) / current_day['Close'] * 100)

					if current_day['Value'] is None:
						is_valid_consolidation = False
						break
					current_volume = float(current_day['Value'])
					prev_volume_float = float(prev_volume)

					if current_volume >= prev_volume_float:
						is_valid_consolidation = False
						break
					if float(current_day['Close']) > max_consolidation_close:
						is_valid_consolidation = False
						break

					prev_spread_float = float(prev_spread)
					if prev_spread_float < 0.5:
						if current_spread > 3.0:
							is_valid_consolidation = False
							break
					else:
						if current_spread > prev_spread_float * 1.50:
							is_valid_consolidation = False
							break

					prev_volume = current_day['Value']
					prev_spread = current_spread

				if is_valid_consolidation:
					days_since_breakout = i
					breakout_date = breakout_day['ObservationDate']
					obs_date = t0['ObservationDate']
					breakout_date_str = breakout_date.strftime('%Y-%m-%d') if hasattr(breakout_date, 'strftime') else str(breakout_date)
					try:
						date_diff_days = (obs_date - breakout_date).days  # type: ignore[operator]
					except Exception:
						date_diff_days = None

					if days_since_breakout == 1:
						continue
					if date_diff_days is not None and date_diff_days > 10:
						continue

					candidates.append({
						'Symbol': symbol,
						'Pattern': 'CONSOLIDATION',
						'Price': round(t0['Close'], 3),
						'Change%': round((t0['Close'] - group[1]['Close']) / group[1]['Close'] * 100, 2) if group[1]['Close'] else 0,
						'VolumeVal': f"${t0['Value']:,.0f}",
						'VolRatio': f"{breakout_vol_ratio:.1f}x",
						'Date': t0['ObservationDate'].strftime('%Y-%m-%d') if hasattr(t0['ObservationDate'], 'strftime') else str(t0['ObservationDate']),
						'Note': f"Ran {round(breakout_gain, 1)}% on {breakout_date_str} ({days_since_breakout}d ago)"
					})
					break

	# Sort by Pattern then Change%
	candidates.sort(key=lambda x: (x['Pattern'], -x['Change%']))
	return candidates


@router.get("/breakout-watchlist-us")
def get_breakout_watchlist_us(
	observation_date: date = Query(..., alias="date", description="Observation date, e.g. 2026-01-08"),
	min_turnover: float = Query(MIN_TURNOVER, description="Minimum turnover in dollars"),
	min_pct_gain: float = Query(MIN_PCT_GAIN, description="Minimum percentage gain"),
	max_price: float = Query(MAX_PRICE, description="Maximum stock price (penny stock filter)"),
	username: str = Depends(verify_credentials)
) -> List[Dict[str, Any]]:
	"""
	Get US breakout watch list candidates based on pattern recognition for a specific date.
	"""
	try:
		logger.info(f"[US] Analyzing breakout patterns for {observation_date} (user: {username})")
		candidates = analyze_breakout_patterns_us(observation_date, min_turnover, min_pct_gain, max_price)
		logger.info(f"[US] Found {len(candidates)} candidates")
		return candidates
	except Exception as e:
		logger.error(f"[US] Error in breakout watchlist: {str(e)}")
		logger.error(traceback.format_exc())
		raise HTTPException(status_code=500, detail=str(e))


