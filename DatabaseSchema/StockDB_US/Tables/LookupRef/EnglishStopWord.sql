-- Table: [LookupRef].[EnglishStopWord]

CREATE TABLE [LookupRef].[EnglishStopWord] (
    [EnglishStopWordID] [int] IDENTITY(1,1) NOT NULL,
    [EnglishStopWord] [varchar](200) NULL
,
    CONSTRAINT [pk_lookuprefenglishword_englishstopwordid] PRIMARY KEY (EnglishStopWordID)
);
