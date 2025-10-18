import pyodbc
import os

# Obtener la ruta del archivo 
base_path = os.path.dirname(os.path.abspath(__file__))
xml_path = os.path.join(base_path, 'archivoDatos.xml')  # 

# Verificar que el archivo existe
if not os.path.exists(xml_path):
    raise FileNotFoundError(f"No se encontró el archivo XML en: {xml_path}")


# Leer contenido del XML
# -----------------------------
# Abri con utf-8-sig para quitar BOM si existe
with open(xml_path, 'r', encoding='utf-8-sig') as f:
    xml_data = f.read()


conn = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=tcp:servidorbdcmb19.database.windows.net,1433;"
    "DATABASE=Tarea 2 BD;"
    "UID=AdminCMB19;"
    "PWD=adminbdCMB05;"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Connection Timeout=30;"
)
cursor = conn.cursor()


#  Ejecutar el SP
# -----------------------------
try:
    sql = """
    DECLARE @outResultCode INT;
    EXEC dbo.sp_cargar_datos_xml 
        @XMLData = ?, 
        @outResultCode = @outResultCode OUTPUT;
    SELECT @outResultCode AS ResultCode;
    """

    cursor.execute(sql, (xml_data,))
    result = cursor.fetchone()

    if result and result.ResultCode == 0:
        print("✅ Carga de datos exitosa.")
    else:
        print(f"⚠️ Carga completada con errores. Código devuelto: {result.ResultCode}")

    conn.commit()

except Exception as e:
    print(f"❌ Error al cargar datos: {e}")

finally:
    cursor.close()
    conn.close()