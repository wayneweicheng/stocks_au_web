-- Function: [Common].[CalculateMinVolume]


create FUNCTION Common.CalculateMinVolume(@decPrice decimal(20, 4), @intRating tinyint)
returns int
--WITH SCHEMABINDING AS
BEGIN
	declare @intOutVolume as int = 0
	declare @decOutPrice AS decimal(20, 4) = 0;
	select @decOutPrice = Common.CalculateBuyPrice(@decPrice, @intRating)
	
	if @intRating <= 5 and @intOutVolume = 0
	begin 
		select @intOutVolume = floor(3000.0/@decOutPrice)
	end

	if @intRating <= 10 and @intOutVolume = 0
	begin 
		select @intOutVolume = floor(3000.0/@decOutPrice)
	end

	
	return @intOutVolume
END;
