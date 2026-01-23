import pyodbc 
cnxn = pyodbc.connect("Driver={ODBC Driver 17 for SQL Server};Server=111.220.71.137,51020;Database=StockDB;uid=BSV_Supp_User; pwd=!ntegr!ty;")

cursor = cnxn.cursor()

post_type = 'DEFAULT'
poster = 'waynecheng3'
rating = 5
message = ''

sql = 'declare @pvchMessage as varchar(max) exec [HC].[usp_AddPoster_Dev] @pvchPosterType = ?, @pvchPoster = ?, @pintRating = ?, @pvchMessage = @pvchMessage output; select @pvchMessage as pvchMessage'

values = (post_type, poster, rating)

cursor.execute(sql, values)

row = cursor.fetchone()

print(row[0])

cnxn.commit()

