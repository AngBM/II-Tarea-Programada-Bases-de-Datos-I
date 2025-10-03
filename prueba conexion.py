import pyodbc


connection = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=tcp:servidorbdcmb19.database.windows.net,1433;"
    "DATABASE=Tarea 2 BD;"
    "UID=AdminCMB19;"
    "PWD=adminbdCMB05;"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Connection Timeout=30;"
)

print(" Conexión exitosa a la base de datos ")
cursor = connection.cursor()
cursor.execute("")
