-- Function: [Common].[GetPriceTick]


CREATE FUNCTION [Common].[GetPriceTick] (@decPrice decimal(20, 4))
returns decimal(20, 4)
--WITH SCHEMABINDING AS
BEGIN
  DECLARE @decTick AS decimal(20, 4) = 0;
  
  select @decTick =
	case when @decPrice > 0 and @decPrice < 0.10 then 0.001
		 when @decPrice >= 0.10 and @decPrice < 2 then 0.005
		 when @decPrice >= 2 then 0.01
		 else 0
	end

  RETURN @decTick;
END;
