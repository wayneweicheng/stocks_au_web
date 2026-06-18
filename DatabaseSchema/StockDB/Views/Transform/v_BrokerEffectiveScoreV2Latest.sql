-- View: [Transform].[v_BrokerEffectiveScoreV2Latest]


  CREATE   VIEW Transform.v_BrokerEffectiveScoreV2Latest
  AS
  WITH x AS
  (
      SELECT
          ASXCode,
          MAX(ScoreAsOfDate) AS ScoreAsOfDate
      FROM Transform.BrokerEffectiveScoreV2
      GROUP BY ASXCode
  )
  SELECT s.*
  FROM Transform.BrokerEffectiveScoreV2 s
  INNER JOIN x
      ON x.ASXCode = s.ASXCode
     AND x.ScoreAsOfDate = s.ScoreAsOfDate;
