import pyodbc 
cnxn = pyodbc.connect("Driver={ODBC Driver 17 for SQL Server};"
                      "Server=111.220.71.137,51020;"
                      "Database=StockDB;"
                      "uid=BSV_Supp_User; pwd=!ntegr!ty;")


cursor = cnxn.cursor()
cursor.execute('exec [Report].[usp_GetSectorList]')

for row in cursor:
    print('row = %r' % (row,))