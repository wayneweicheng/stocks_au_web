-- Function: [Common].[DateAddBusinessDay]


CREATE FUNCTION [Common].[DateAddBusinessDay]
(
@n INT, 
@Date date
)
RETURNS date 
AS 
BEGIN
  -- This ensures that however the server is configured for dates
  -- the function will know the DATEPART(DW values for Saturday
  -- and Sunday
  declare @SaturdayDW int
  declare @SundayDW int
  set @SaturdayDW = DATEPART(DW,CONVERT(datetime,'2019 January 5')) -- A Saturday
  set @SundayDW = DATEPART(DW,CONVERT(datetime,'2019 January 6')) -- A Sunday
  -----------------------------------------------------------------
  -- If @N is zero then reduce the date by 1
  -- and try adding one day
  if @N=0
    begin
      set @N=1
      set @Date=DATEADD(DAY,-1,@Date)
    end
  ----------------------------------------------------------------
  -- If @N GTE 0 then increment dates while counting
  -- If @N LT 0 then decrement dates while counting
  declare @increment int
  if @n>=0 set @increment = 1 else set @increment = -1
  ----------------------------------------------------------------
  declare @CountDays int
  set @CountDays=0
  declare @LoopDate datetime
  set @LoopDate = @Date

  while @CountDays<ABS(@N)
    begin
      set @LoopDate=DATEADD(DAY,@increment,@LoopDate)
      while exists(select PublicHolidayID from LookupRef.PublicHoliday where HolidayDate=@LoopDate) 
               or DATEPART(DW,@LoopDate)= @SaturdayDW 
               or DATEPART(DW,@LoopDate)= @SundayDW
        begin  
            set @LoopDate=DATEADD(DAY,@increment,@LoopDate)
        end
      set @CountDays=@CountDays+1
    end

  return cast(@LoopDate as date)

END