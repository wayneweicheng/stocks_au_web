-- Table: [StockData].[CourseOfSaleSecondaryToday]

CREATE TABLE [StockData].[CourseOfSaleSecondaryToday] (
    [CourseOfSaleSecondaryTodayID] [int] IDENTITY(1,1) NOT NULL,
    [SaleDateTime] [datetime] NOT NULL,
    [Price] [decimal](20,4) NOT NULL,
    [Quantity] [bigint] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ExChange] [varchar](20) NOT NULL,
    [SpecialCondition] [varchar](50) NULL,
    [CreateDate] [datetime] NOT NULL,
    [ActBuySellInd] [char](1) NULL,
    [DerivedInstitute] [bit] NULL,
    [ObservationDate] [date] NOT NULL
,
    CONSTRAINT [pk_stockdatacourseofsalesecondarytoday_saledatetimeasxcodepricequantityexchange] PRIMARY KEY (ObservationDate, SaleDateTime, ASXCode, Price, Quantity, ExChange)
);

CREATE INDEX [idx_CourseOfSaleSecondary_DateFilter] ON [StockData].[CourseOfSaleSecondaryToday] (Quantity, Price, ObservationDate, ASXCode, SaleDateTime);