-- View: [Transform].[v_BrokerEffectiveScoreLatest]


  CREATE   VIEW Transform.v_BrokerEffectiveScoreLatest
  AS
  WITH LatestScoreDate AS
  (
      SELECT
          ASXCode,
          MAX(ScoreAsOfDate) AS ScoreAsOfDate
      FROM Transform.BrokerEffectiveScore
      GROUP BY ASXCode
  )
  SELECT s.*
  FROM Transform.BrokerEffectiveScore s
  INNER JOIN LatestScoreDate d
      ON d.ASXCode = s.ASXCode
     AND d.ScoreAsOfDate = s.ScoreAsOfDate;
