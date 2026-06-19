"""Export raw data from SQL Server for stock analysis."""

from datetime import date, timedelta
from typing import Dict, List, Any, Optional
import pyodbc
from app.core.db import get_db_connection


def get_latest_trading_date(observation_date: date, conn: pyodbc.Connection) -> date:
    """Get the latest trading date strictly before the as-at input date."""
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT TOP 1 ObservationDate
        FROM StockData.PriceHistory
        WHERE ObservationDate < convert(date, ?)
        ORDER BY ObservationDate DESC
        """,
        (observation_date,)
    )
    row = cursor.fetchone()
    return row[0] if row else observation_date


def get_latest_broker_observation_date(
    stock_code: str,
    cutoff_date: date,
    conn: pyodbc.Connection,
) -> Optional[date]:
    """Get latest broker observation date on or before the cutoff date."""
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT TOP 1 ObservationDate
        FROM BrokerData.BrokerDayReport
        WHERE ASXCode = convert(varchar(10), ?)
          AND ObservationDate <= convert(date, ?)
        ORDER BY ObservationDate DESC
        """,
        (stock_code, cutoff_date),
    )
    row = cursor.fetchone()
    return row[0] if row else None


def get_latest_snapshot_date(
    table_name: str,
    effective_date: date,
    conn: pyodbc.Connection,
    asx_code: Optional[str] = None,
) -> Optional[date]:
    """Get latest snapshot date on or before the provided date."""
    cursor = conn.cursor()
    if asx_code:
        cursor.execute(
            f"""
            SELECT TOP 1 SnapshotDate
            FROM {table_name}
            WHERE ASXCode = convert(varchar(10), ?)
              AND SnapshotDate <= ?
            ORDER BY SnapshotDate DESC
            """,
            (asx_code, effective_date),
        )
    else:
        cursor.execute(
            f"""
            SELECT TOP 1 SnapshotDate
            FROM {table_name}
            WHERE SnapshotDate <= ?
            ORDER BY SnapshotDate DESC
            """,
            (effective_date,),
        )
    row = cursor.fetchone()
    return row[0] if row else None


def get_latest_stock_snapshot_date(
    table_name: str,
    asx_code: str,
    conn: pyodbc.Connection,
) -> Optional[date]:
    """Get the latest snapshot date available for a specific stock."""
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT TOP 1 SnapshotDate
        FROM {table_name}
        WHERE ASXCode = convert(varchar(10), ?)
        ORDER BY SnapshotDate DESC
        """,
        (asx_code,),
    )
    row = cursor.fetchone()
    return row[0] if row else None


def export_announcements(
    stock_code: str,
    observation_date: date,
    conn: pyodbc.Connection
) -> List[Dict[str, Any]]:
    """Export announcements for the last 90 days before observation date."""
    start_date = observation_date - timedelta(days=90)
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT
            AnnouncementID,
            ASXCode,
            AnnDateTime,
            AnnRetriveDateTime,
            MarketSensitiveIndicator,
            AnnDescr,
            AnnURL,
            AnnContent,
            AnnNumPage,
            ObservationDate
        FROM StockData.Announcement
        WHERE ASXCode = convert(varchar(10), ?)
          AND ObservationDate >= convert(date, ?)
          AND ObservationDate <= convert(date, ?)
        ORDER BY ObservationDate DESC, AnnDateTime DESC
        """,
        (stock_code, start_date, observation_date)
    )

    columns = [column[0] for column in cursor.description]
    results = []
    for row in cursor.fetchall():
        results.append(dict(zip(columns, row)))

    return results


def export_price_history(
    stock_code: str,
    observation_date: date,
    conn: pyodbc.Connection
) -> List[Dict[str, Any]]:
    """Export daily price history for the last 90 days."""
    start_date = observation_date - timedelta(days=90)
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT
            ASXCode,
            ObservationDate AS TradeDate,
            [Open],
            [High],
            [Low],
            [Close],
            Volume,
            [Value] AS MarketCap,
            NULL AS ChangePercent
        FROM StockData.PriceHistory
        WHERE ASXCode = convert(varchar(10), ?)
          AND ObservationDate >= convert(date, ?)
          AND ObservationDate <= convert(date, ?)
        ORDER BY ObservationDate DESC
        """,
        (stock_code, start_date, observation_date)
    )

    columns = [column[0] for column in cursor.description]
    results = []
    for row in cursor.fetchall():
        results.append(dict(zip(columns, row)))

    return results


def export_retail_participation(
    stock_code_base: str,
    observation_date: date,
    conn: pyodbc.Connection,
    lookback_days: int = 60,
) -> Dict[str, Any]:
    """Calculate recent retail participation from BrokerData.BrokerDayReport."""
    window_start = observation_date - timedelta(days=lookback_days)
    retail_brokers = ("CMC Markets", "Commonwealth Securities", "Wealthhub")
    cursor = conn.cursor()

    cursor.execute(
        """
        WITH DailyParticipation AS (
            SELECT
                ObservationDate,
                SUM(CASE WHEN BrokerName IN (?, ?, ?)
                    THEN COALESCE(TotalValue, 0)
                    ELSE 0
                END) AS RetailTotalValue,
                SUM(COALESCE(TotalValue, 0)) AS MarketTotalValue
            FROM BrokerData.BrokerDayReport
            WHERE ASXCode = convert(varchar(10), ?)
              AND ObservationDate > convert(date, ?)
              AND ObservationDate <= convert(date, ?)
            GROUP BY ObservationDate
            HAVING SUM(COALESCE(TotalValue, 0)) > 0
        )
        SELECT
            COUNT(*) AS TradingDays,
            MIN(ObservationDate) AS WindowFirstObservationDate,
            MAX(ObservationDate) AS WindowLastObservationDate,
            CAST(AVG(RetailTotalValue * 100.0 / NULLIF(MarketTotalValue, 0)) AS decimal(10, 2))
                AS AverageDailyRetailParticipationPct,
            CAST(SUM(RetailTotalValue) * 100.0 / NULLIF(SUM(MarketTotalValue), 0) AS decimal(10, 2))
                AS PeriodRetailParticipationPct,
            CAST(SUM(RetailTotalValue) AS decimal(20, 2)) AS RetailTotalValue,
            CAST(SUM(MarketTotalValue) AS decimal(20, 2)) AS MarketTotalValue
        FROM DailyParticipation
        """,
        (*retail_brokers, stock_code_base, window_start, observation_date),
    )

    columns = [column[0] for column in cursor.description]
    row = cursor.fetchone()
    result = dict(zip(columns, row)) if row else {}
    return {
        "lookback_days": lookback_days,
        "window_start_date": window_start,
        "observation_date": observation_date,
        "retail_brokers": list(retail_brokers),
        "trading_days": result.get("TradingDays", 0) or 0,
        "window_first_observation_date": result.get("WindowFirstObservationDate"),
        "window_last_observation_date": result.get("WindowLastObservationDate"),
        "average_daily_retail_participation_pct": result.get("AverageDailyRetailParticipationPct"),
        "period_retail_participation_pct": result.get("PeriodRetailParticipationPct"),
        "retail_total_value": result.get("RetailTotalValue"),
        "market_total_value": result.get("MarketTotalValue"),
    }


def export_broker_data(
    stock_code_base: str,
    observation_date: date,
    conn: pyodbc.Connection
) -> Dict[str, Any]:
    """Export broker setup and microstructure data from Transform schema."""
    # For broker data, use T+3 cutoff
    broker_cutoff = observation_date - timedelta(days=3)
    broker_effective_date = get_latest_broker_observation_date(stock_code_base, broker_cutoff, conn) or broker_cutoff
    setup_snapshot_date = get_latest_snapshot_date(
        "Transform.StockDayBrokerSetup",
        broker_effective_date,
        conn,
        asx_code=stock_code_base,
    )
    historical_snapshot_date = get_latest_snapshot_date(
        "Transform.BrokerHistoricalPerformance",
        broker_effective_date,
        conn,
    )
    # Use the latest archived microstructure snapshot for this stock, then cap
    # the actual evidence rows by broker_effective_date to improve coverage.
    micro_snapshot_date = get_latest_stock_snapshot_date(
        "Transform.BrokerTxMicrostructureDay",
        stock_code_base,
        conn,
    )

    cursor = conn.cursor()

    # Get broker setup data
    cursor.execute(
        """
        SELECT TOP 20
            SnapshotDate,
            ASXCode,
            PriceASXCode,
            TradeDate,
            BullishSetupScore,
            BearishSetupScore,
            LeadBullBroker AS TopBuyBroker,
            LeadBearBroker AS TopSellBroker
        FROM Transform.StockDayBrokerSetup
        WHERE ASXCode = convert(varchar(10), ?)
          AND SnapshotDate = ?
        ORDER BY TradeDate DESC
        """,
        (stock_code_base, setup_snapshot_date if setup_snapshot_date else date(1900, 1, 1))
    )

    columns = [column[0] for column in cursor.description]
    setup_data = []
    for row in cursor.fetchall():
        setup_data.append(dict(zip(columns, row)))

    cursor.execute(
        """
        SELECT
            SnapshotDate,
            BrokerName,
            BrokerCode,
            EventType,
            EventDirection,
            EventCount,
            StockCount,
            ReliabilityScore,
            HistoricalEdgeScore,
            BrokerArchetype
        FROM Transform.BrokerHistoricalPerformance
        WHERE SnapshotDate = ?
        ORDER BY HistoricalEdgeScore DESC, EventCount DESC
        """,
        (historical_snapshot_date if historical_snapshot_date else date(1900, 1, 1),)
    )

    columns = [column[0] for column in cursor.description]
    historical_data = []
    for row in cursor.fetchall():
        historical_data.append(dict(zip(columns, row)))

    # Get microstructure data
    cursor.execute(
        """
        SELECT TOP 10
            SnapshotDate,
            ASXCode,
            PriceASXCode,
            ObservationDate,
            CaptureSource,
            BullishSetupScore,
            BearishSetupScore,
            TransactionCount,
            TotalValue,
            BuyerAggressionScore,
            SellerAggressionScore,
            LiveDistributionScore,
            LiveExecutionQualityScore,
            LeadAggressorBroker,
            LeadDistributorBroker
        FROM Transform.BrokerTxMicrostructureDay
        WHERE ASXCode = convert(varchar(10), ?)
          AND SnapshotDate = ?
          AND ObservationDate <= convert(date, ?)
        ORDER BY ObservationDate DESC
        """,
        (
            stock_code_base,
            micro_snapshot_date if micro_snapshot_date else date(1900, 1, 1),
            broker_effective_date,
        )
    )

    columns = [column[0] for column in cursor.description]
    micro_data = []
    for row in cursor.fetchall():
        micro_data.append(dict(zip(columns, row)))

    retail_participation = export_retail_participation(stock_code_base, observation_date, conn)

    return {
        "setup": setup_data,
        "historical": historical_data,
        "microstructure": micro_data,
        "retail_participation": retail_participation,
        "setup_snapshot_date": setup_snapshot_date,
        "historical_snapshot_date": historical_snapshot_date,
        "micro_snapshot_date": micro_snapshot_date,
        "broker_effective_date": broker_effective_date
    }


def export_all_data(
    stock_code: str,
    observation_date: date
) -> Dict[str, Any]:
    """Export all data needed for stock analysis."""
    conn = get_db_connection()

    try:
        # Normalize stock code
        stock_code_market = stock_code if stock_code.endswith(".AX") else f"{stock_code}.AX"
        stock_code_base = stock_code.replace(".AX", "")

        effective_trade_date = get_latest_trading_date(observation_date, conn)

        announcements = export_announcements(stock_code_market, effective_trade_date, conn)
        price_history = export_price_history(stock_code_market, effective_trade_date, conn)
        broker_data = export_broker_data(stock_code_base, effective_trade_date, conn)

        return {
            "stock_code": stock_code_market,
            "stock_code_base": stock_code_base,
            "observation_date": observation_date.isoformat(),
            "effective_trade_date": effective_trade_date.isoformat(),
            "broker_effective_date": broker_data["broker_effective_date"].isoformat(),
            "broker_setup_snapshot_date": (
                broker_data["setup_snapshot_date"].isoformat()
                if broker_data.get("setup_snapshot_date")
                else None
            ),
            "broker_historical_snapshot_date": (
                broker_data["historical_snapshot_date"].isoformat()
                if broker_data.get("historical_snapshot_date")
                else None
            ),
            "broker_micro_snapshot_date": (
                broker_data["micro_snapshot_date"].isoformat()
                if broker_data.get("micro_snapshot_date")
                else None
            ),
            "announcements": announcements,
            "price_history": price_history,
            "broker_setup": broker_data["setup"],
            "broker_historical": broker_data["historical"],
            "broker_microstructure": broker_data["microstructure"],
            "broker_retail_participation": broker_data["retail_participation"]
        }
    finally:
        conn.close()
