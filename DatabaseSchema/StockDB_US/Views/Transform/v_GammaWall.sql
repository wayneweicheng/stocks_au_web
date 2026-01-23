-- View: [Transform].[v_GammaWall]



CREATE view [Transform].[v_GammaWall]
as
select 
    [Strike],
    [ExpiryDate],
    [CallGamma],
    -1*[PutGamma] AS PutGamma,
    [ASXCode],
    [Close],
    [ObservationDate]
from Transform.GammaWall
