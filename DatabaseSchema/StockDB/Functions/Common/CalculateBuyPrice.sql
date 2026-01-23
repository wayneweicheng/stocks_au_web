-- Function: [Common].[CalculateBuyPrice]


CREATE FUNCTION Common.CalculateBuyPrice (@decPrice decimal(20, 4), @intRating tinyint)
returns decimal(20, 4)
--WITH SCHEMABINDING AS
BEGIN
  DECLARE @decOutPrice AS decimal(20, 4) = 0;

  if @intRating <= 3 and @decOutPrice = 0
  begin
	
	select @decOutPrice = @decPrice + 2*
	case when @decPrice > 0 and @decPrice < 0.10 then 0.001
		 when @decPrice >= 0.10 and @decPrice < 2 then 0.005
		 when @decPrice >= 2 then 0.01
		 else 0
	end

	if @decOutPrice > @decPrice * 1.2
	begin
		select @decOutPrice = @decPrice + 1*
		case when @decPrice > 0 and @decPrice < 0.10 then 0.001
			 when @decPrice >= 0.10 and @decPrice < 2 then 0.005
			 when @decPrice >= 2 then 0.01
			 else 0
		end

		if @decOutPrice > @decPrice * 1.2
		begin
			select @decOutPrice = @decPrice
		end 
	end

  end

  if @intRating <= 5 and @decOutPrice = 0
  begin
	select @decOutPrice = @decPrice + 1*
	case when @decPrice > 0 and @decPrice < 0.10 then 0.001
			when @decPrice >= 0.10 and @decPrice < 2 then 0.005
			when @decPrice >= 2 then 0.01
			else 0
	end

	if @decOutPrice > @decPrice * 1.2
	begin
		select @decOutPrice = @decPrice
	end 

  end

  if @intRating <= 10 and @decOutPrice = 0
  begin
	select @decOutPrice = @decPrice + 0*
	case when @decPrice > 0 and @decPrice < 0.10 then 0.001
			when @decPrice >= 0.10 and @decPrice < 2 then 0.005
			when @decPrice >= 2 then 0.01
			else 0
	end

	if @decOutPrice > @decPrice * 1.2
	begin
		select @decOutPrice = @decPrice
	end 

  end


  RETURN @decOutPrice ;
END;
