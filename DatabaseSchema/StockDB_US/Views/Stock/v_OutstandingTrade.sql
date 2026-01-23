-- View: [Stock].[v_OutstandingTrade]


create view Stock.v_OutstandingTrade
as
select UserID, ASXCode from Stock.Trade
group by UserID, ASXCode
having sum(case when TradeType = 1 then Volume else -1*Volume end) > 0
