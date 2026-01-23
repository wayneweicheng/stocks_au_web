-- Function: [Common].[RoundStockPrice]


CREATE FUNCTION [Common].[RoundStockPrice] (@decPrice decimal(20, 4))
returns decimal(20, 4)
--WITH SCHEMABINDING AS
BEGIN
  DECLARE @decOutput AS decimal(20, 4) = 0;
  
  select @decOutput =
	case when @decPrice > 0 and @decPrice < 0.10 then round(@decPrice, 3)
		 when @decPrice >= 0.10 and @decPrice < 2 then cast(round(@decPrice*200, 0)/200 AS DECIMAL(20, 4))
		 when @decPrice >= 2 then round(@decPrice, 2)
		 else 0
	end

  RETURN @decOutput;
END;
