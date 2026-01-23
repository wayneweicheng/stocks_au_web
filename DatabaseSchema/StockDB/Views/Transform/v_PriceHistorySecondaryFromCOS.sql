-- View: [Transform].[v_PriceHistorySecondaryFromCOS]

		CREATE view Transform.v_PriceHistorySecondaryFromCOS
		as
		select 
			a.ASXCode, 
			a.ObservationDate, 
			a.Exchange, 
			b.Price as [Open],
			a.[High] as [High],
			a.[Low] as [Low],
			c.Price as [Close],
			a.Volume as Volume,
			a.[Value] as [Value],
			a.Trades as Trades,
			a.CreateDate as CreateDate,
			a.ModifiedDate as ModifiedDate,
			a.VWAP as VWAP
		from
		(
			select 
				a.ASXCode, 
				cast(a.SaleDateTime as Date) as ObservationDate, 
				Exchange, 
				null as [Open],
				max(Price) as [High],
				min(Price) as [Low],
				null as [Close],
				sum(Quantity) as Volume,
				sum(Price*Quantity) as [Value],
				count(*) as Trades,
				max(CreateDate) as CreateDate,
				max(CreateDate) as ModifiedDate,
				case when sum(Quantity) > 0 then sum(Price*Quantity)/sum(Quantity) else null end as VWAP
			from StockData.CourseOfSaleSecondary as a
			group by a.ASXCode, cast(a.SaleDateTime as Date), Exchange
		) as a
		inner join
		(
			select
				ASXCode,
				cast(SaleDateTime as date) as ObservationDate,
				Price,
				Exchange,
				row_number() over (partition by ASXCode, cast(SaleDateTime as date), Exchange order by SaleDateTime) as RowNumber
			from StockData.CourseOfSaleSecondary
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.ExChange = b.ExChange
		and b.RowNumber = 1
		inner join
		(
			select
				ASXCode,
				cast(SaleDateTime as date) as ObservationDate,
				Price,
				Exchange,
				row_number() over (partition by ASXCode, cast(SaleDateTime as date), Exchange order by SaleDateTime desc) as RowNumber
			from StockData.CourseOfSaleSecondary
		) as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		and a.ExChange = c.ExChange
		and c.RowNumber = 1
