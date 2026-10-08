/* Latest support/resistance map levels by ASXCode and observation date. */
CREATE OR ALTER VIEW StockData.v_LatestPriceLevelMapLevels
AS
WITH LatestMap AS
(
    SELECT
        p.PriceLevelMapId,
        p.ASXCode,
        p.ObservationDate,
        p.MapGeneratedAtUtc,
        p.MapAsOfAtUtc,
        p.MethodVersion,
        p.SourceSystem,
        ROW_NUMBER() OVER
        (
            PARTITION BY p.ASXCode, p.ObservationDate
            ORDER BY p.MapGeneratedAtUtc DESC, p.PriceLevelMapId DESC
        ) AS SnapshotRank
    FROM StockData.PriceLevelMap AS p WITH (NOLOCK)
)
SELECT
    m.PriceLevelMapId,
    m.ASXCode,
    m.ObservationDate,
    m.MapGeneratedAtUtc,
    m.MapAsOfAtUtc,
    m.MethodVersion,
    m.SourceSystem,
    l.PriceLevelMapLevelId,
    l.LevelOrdinal,
    l.LevelLow,
    l.LevelHigh,
    l.LevelCenter,
    l.LevelType,
    l.Polarity,
    l.SourceJsonPath,
    l.LevelJson
FROM LatestMap AS m
JOIN StockData.PriceLevelMapLevel AS l WITH (NOLOCK)
  ON l.PriceLevelMapId = m.PriceLevelMapId
WHERE m.SnapshotRank = 1;
GO
