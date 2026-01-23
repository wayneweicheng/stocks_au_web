-- View: [Transform].[v_GammaWallByExpiryDate]


CREATE view [Transform].[v_GammaWallByExpiryDate]
as
select *
from Transform.GammaWallByExpiryDate
where ExpiryDate < dateadd(day, 120, getdate())
