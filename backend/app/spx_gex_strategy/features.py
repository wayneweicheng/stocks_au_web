from __future__ import annotations

from datetime import date
from statistics import median
from typing import Mapping, Sequence

from .calendar import USCashCalendar
from .models import DailyGexObservation, SignalClassification, SignalEvaluation


def percentile(values: Sequence[float], quantile: float) -> float:
    """Linear percentile matching the usual pandas/numpy interpolation rule."""
    if not values:
        raise ValueError("percentile requires at least one value")
    ordered = sorted(float(value) for value in values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * quantile
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    fraction = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def percentile_rank(value: float, history: Sequence[float]) -> float:
    if not history:
        return 0.0
    return 100.0 * sum(item <= value for item in history) / len(history)


def _prior_nq_return(
    observation_date: date,
    calendar: USCashCalendar,
    nq_daily_closes: Mapping[date, float],
) -> float | None:
    prior_date = calendar.session_offset(observation_date, -5)
    current = nq_daily_closes.get(observation_date)
    prior = nq_daily_closes.get(prior_date)
    if current is None or prior in (None, 0):
        return None
    return current / prior - 1.0


def classify_observations(
    observations: Sequence[DailyGexObservation],
    calendar: USCashCalendar,
    nq_daily_closes: Mapping[date, float] | None = None,
    lookback_days: int = 60,
    actionable_hour: int = 3,
    actionable_minute: int = 30,
) -> list[SignalEvaluation]:
    """Classify observations using only rows strictly before each date."""
    ordered = sorted(observations, key=lambda item: item.observation_date)
    nq_daily_closes = nq_daily_closes or {}
    if len({item.observation_date for item in ordered}) != len(ordered):
        raise ValueError("Duplicate GEX observation dates are not allowed")

    evaluations: list[SignalEvaluation] = []
    prior_valid: list[DailyGexObservation] = []
    for observation in ordered:
        d1 = calendar.next_session(observation.observation_date)
        actionable_at = calendar.actionable_at(d1, actionable_hour, actionable_minute)
        classification = SignalClassification.NO_SIGNAL
        trade_allowed = False
        skip_reason: str | None = None
        sc_median: float | None = None
        sc_rank: float | None = None
        sp_p75: float | None = None
        sp_rank: float | None = None
        prior_return: float | None = None

        raw_signal = (observation.signal_raw or "").upper()
        if raw_signal not in {"BEARISH", "BULLISH"}:
            skip_reason = "NO_SIGNAL"
        elif raw_signal == "BEARISH":
            if len(prior_valid) < lookback_days:
                classification = SignalClassification.INSUFFICIENT_HISTORY
                skip_reason = f"INSUFFICIENT_HISTORY_{len(prior_valid)}_OF_{lookback_days}"
            else:
                history = prior_valid[-lookback_days:]
                missing_history = sum(item.sc_gex is None for item in history)
                if observation.sc_gex is None:
                    classification = SignalClassification.INSUFFICIENT_HISTORY
                    skip_reason = "MISSING_CURRENT_SC_GEX_LEVEL"
                elif missing_history:
                    classification = SignalClassification.INSUFFICIENT_HISTORY
                    skip_reason = f"MISSING_SC_GEX_LEVEL_IN_PRIOR_60_{missing_history}"
                else:
                    sc_values = [float(item.sc_gex) for item in history if item.sc_gex is not None]
                    sp_values = [item.sp_delta_share or 0.0 for item in history]
                    sc_current = float(observation.sc_gex)
                    sp_current = observation.sp_delta_share or 0.0
                    sc_median = median(sc_values)
                    sp_p75 = percentile(sp_values, 0.75)
                    sc_rank = percentile_rank(sc_current, sc_values)
                    sp_rank = percentile_rank(sp_current, sp_values)
                    sc_low = sc_current <= sc_median
                    sp_high = sp_current > sp_p75
                    if sc_low and sp_high:
                        classification = SignalClassification.STRONG_YELLOW
                    elif sc_low and not sp_high:
                        classification = SignalClassification.RELIABLE_YELLOW
                    elif not sc_low and sp_high:
                        classification = SignalClassification.MIXED_YELLOW
                    else:
                        classification = SignalClassification.WEAK_YELLOW
                    trade_allowed = classification in {
                        SignalClassification.STRONG_YELLOW,
                        SignalClassification.RELIABLE_YELLOW,
                    }
                    if not trade_allowed:
                        skip_reason = "NON_TRADABLE_YELLOW_CLASSIFICATION"
        else:
            prior_return = _prior_nq_return(observation.observation_date, calendar, nq_daily_closes)
            if prior_return is None:
                skip_reason = "MISSING_NQ_PRIOR_5D_DATA"
            elif prior_return <= 0:
                classification = SignalClassification.REVERSAL_GREEN
                trade_allowed = True
            else:
                classification = SignalClassification.NORMAL_GREEN
                trade_allowed = True

        if classification == SignalClassification.NO_SIGNAL and raw_signal in {"BEARISH", "BULLISH"}:
            classification = SignalClassification.INSUFFICIENT_HISTORY
            trade_allowed = False

        observation.derived.update(
            {
                "SC_GEX_current": observation.sc_gex,
                "SC_GEXDelta_current": observation.sc_gex_delta,
                "SP_GEX_current": observation.sp_gex,
                "SP_GEXDelta_current": observation.sp_gex_delta,
                "SP_delta_share_current": observation.sp_delta_share,
                "SC_GEX_threshold": sc_median,
                "SC_GEX_percentile": sc_rank,
                "SP_delta_share_threshold": sp_p75,
                "SP_delta_share_percentile": sp_rank,
                "prior_5d_nq_return": prior_return,
            }
        )
        evaluations.append(
            SignalEvaluation(
                observation=observation,
                classification=classification,
                actionable_at=actionable_at,
                action_date=d1,
                trade_allowed=trade_allowed,
                skip_reason=skip_reason,
                sc_rolling_median_60=sc_median,
                sc_percentile_60=sc_rank,
                sp_share_p75_60=sp_p75,
                sp_share_percentile_60=sp_rank,
                prior_5d_nq_return=prior_return,
            )
        )
        # A row is eligible for future thresholds only after its own signal
        # has been evaluated. This is the key no-look-ahead boundary.
        prior_valid.append(observation)
    return evaluations


def nq_daily_closes(bars: Sequence, calendar: USCashCalendar) -> dict[date, float]:
    """Use the last NQ bar ending at each US cash-session close.

    NQ 30-minute timestamps identify interval starts.  The bar stamped
    16:00 therefore runs beyond the NYSE close and must not be used for the
    cash-session close; on an early-close day the same rule applies to the
    session's actual close time.
    """
    grouped: dict[date, list] = {}
    for bar in bars:
        session_date = bar.timestamp.astimezone(calendar.timezone).date()
        if calendar.is_session(session_date) and bar.timestamp < calendar.cash_close(session_date):
            grouped.setdefault(session_date, []).append(bar)
    return {
        session_date: sorted(session_bars, key=lambda item: item.timestamp)[-1].close
        for session_date, session_bars in grouped.items()
    }
