-- View: [TT].[v_TweetSymbol]


CREATE view TT.v_TweetSymbol
as
select UserName, FriendlyName, min(Rating) as Rating, Symbol, max(CreateDateTimeUTC) as CreateDateTimeUTC, count(distinct TweetID) as NumObservations, max(Hashtag) as Hashtag
from 
(
	select a.UserName, d.FriendlyName, d.Rating, a.CreateDateTimeUTC, a.TweetID, json_value(a.TweetJson, '$.full_text') as FullText, upper(replace(json_value(b.value, '$.text'), '.AX', '')) as Symbol, upper(json_value(c.value, '$.text')) as Hashtag
	from TT.Tweet as a
	inner join TT.QualityUser as d
	on a.UserName = d.UserName
	cross apply openjson(TweetJson, '$.symbols') as b
	outer apply openjson(TweetJson, '$.hashtags') as c
	where a.CreateDateTimeUTC > dateadd(day, -60, getdate())
) as x
group by UserName, FriendlyName, Symbol;
