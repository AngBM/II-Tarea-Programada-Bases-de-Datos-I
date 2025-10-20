from flask import Flask, render_template, request, redirect, url_for, make_response, session
from datetime import datetime
import pyodbc

app = Flask(__name__)
app.secret_key = "a1b2c3d4"

# Conexión a SQL Server
def get_db_connection():
    return pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        "SERVER=tcp:servidorbdcmb19.database.windows.net,1433;"
        "DATABASE=Tarea 2 BD;"
        "UID=AdminCMB19;"
        "PWD=adminbdCMB05;"
        "Encrypt=yes;"
        "TrustServerCertificate=no;"
        "Connection Timeout=30;"
    )

# Pagina principal de login
@app.route('/', methods=['GET'])
def login():
    return render_template('login.html', error=None)
@app.route('/', methods=['POST'])
def login_post():
    # Obtener datos del formulario
    username = request.form.get('username').strip()
    password = request.form.get('password').strip()
    ip_user = request.remote_addr  # IP del usuario

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        
        cursor.execute("""
            DECLARE @outResultCode INT;
            EXEC dbo.sp_login ?, ?, ?, @outResultCode OUTPUT;
            SELECT @outResultCode AS outResultCode;
        """, (username, password, ip_user))

        
        # Obtener el resultado del SP
        result = cursor.fetchone()
        codigo_error = result[0] if result else -1  #  capturamos el OUTPUT


        cursor.close()
        conn.commit()
        conn.close()

        # Validar resultado del login
        if codigo_error == 0:
            # Login exitoso
            session['usuario'] = username  # 
            return redirect(url_for('empleados'))
        elif codigo_error in (50001, 50002):
            # Username o password incorrecto
            error_message = "Usuario o contraseña incorrecta"
        elif codigo_error == 50003:
            # Login deshabilitado por intentos fallidos
            error_message = "Demasiados intentos de login, intente de nuevo dentro de 10 minutos"
        else:
            error_message = "Error desconocido"

        # Renderizar login con mensaje de error
        return render_template('login.html', error=error_message)

    except Exception as e:
        # Error de conexión o ejecución del SP
        return render_template('login.html', error=f"Error de conexión: {str(e)}")
    
#---------------------------------------------------------------------------------------------------------
# Logout
@app.route('/logout', methods=['GET','POST'])
def logout():
    username = session.get('usuario')
    ip_user = request.remote_addr

    if username:
        try:
            conn = get_db_connection()
            cursor = conn.cursor()

            # Llamada al SP de logout
            cursor.execute("""
                DECLARE @outResultCode INT;
                EXEC dbo.sp_logout ?, ?, @outResultCode OUTPUT;
                SELECT @outResultCode AS outResultCode;
            """, (username, ip_user))

            # Obtiene el resultado devuelto por el SP
            result = cursor.fetchone()
            result_code = result[0] if result else -1  # Devuelve el valor del OUTPUT

            cursor.close()
            conn.commit()
            conn.close()

            # Evalua el resultado
            if result_code == 0:
                print(f"Logout exitoso para el usuario: {username}")
            else:
                print(f"Error en logout (Código {result_code}) para el usuario: {username}")

        except Exception as e:
            print(f"Error al cerrar sesión: {str(e)}")

    # Limpiar la sesión y redirigir al login
    session.clear()
    return redirect(url_for('login'))

#------------------------------------------------------------------------

@app.route('/empleados', methods=['GET'])
def empleados():
    # Verifica sesión
    username = session.get('usuario')
    if not username:
        return redirect(url_for('login'))



    filtro = request.args.get('filtro', '').strip()
    ip_user = request.remote_addr

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Ejecuta el SP con el parámetro de salida
        cursor.execute("""
            DECLARE @outResultCode INT;
            EXEC dbo.sp_listar_empleados ?, ?, ?, @outResultCode OUTPUT;
            SELECT @outResultCode AS outResultCode;
        """, (filtro if filtro else None, username, ip_user))

        empleados = []

        #  resultados del SELECT del SP 
        rows = cursor.fetchall()
        for row in rows:
            empleados.append({
                'Nombre': row.Nombre,
                'ValorDocumentoIdentidad': row.ValorDocumentoIdentidad
            })

        # Avanza al siguiente conjunto donde está el SELECT del OUT
        if cursor.nextset():
            result_code_row = cursor.fetchone()
            out_result_code = result_code_row.outResultCode if result_code_row else -1
        else:
            out_result_code = -1

        cursor.close()
        conn.commit()
        conn.close()

        # Valida del código de salida
        error_message = None
        if out_result_code != 0:
            error_message = f"Error en procedimiento. Código: {out_result_code}"

        #  Renderiza HTML c
        return render_template('principal.html',empleados=empleados,filtro=filtro,error=error_message)

    except Exception as e:
        return render_template('principal.html',empleados=[],filtro=filtro,error=f"Error de conexión o ejecución: {str(e)}")
    
#_------------------------------------------------------------------------
@app.route('/insertar_empleado_form')
def insertar_empleado_form():
    return render_template('insertar_empleado.html')

@app.route('/insertar_empleado', methods=['POST'])
def insertar_empleado():
    if 'usuario' not in session:
        return redirect(url_for('login'))


    valor_doc = request.form.get('valor_doc', '').strip()
    nombre = request.form.get('nombre', '').strip()
    nombre_puesto = request.form.get('puesto', '').strip()   # viene del dropdown
    fecha_contratacion = request.form.get('fecha_contratacion', None)
    ip_user = request.remote_addr

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

       
        out_result_code = cursor.execute("""
            DECLARE @outResultCode INT;
            EXEC dbo.sp_insertar_empleado
                @inValorDocumentoIdentidad = ?,
                @inNombre = ?,
                @inNombrePuesto = ?,
                @inPostByUser = ?,
                @inPostInIP = ?,
                @inFechaContratacion = ?,
                @outResultCode = @outResultCode OUTPUT;
            SELECT @outResultCode AS outResultCode;
        """, (valor_doc, nombre, nombre_puesto, username, ip_user, None)).fetchone().outResultCode

        conn.commit()
        cursor.close()
        conn.close()


        #  mensaje según el código de salida
        if out_result_code == 0:
            mensaje = "✅ Empleado insertado correctamente."
        elif out_result_code == 50004:
            mensaje = "⚠️ El número de documento ya existe. No se puede insertar el empleado."
        elif out_result_code == 50005:
            mensaje = "⚠️ Ya existe un empleado con el mismo nombre."
        elif out_result_code == 50009:
            mensaje = "⚠️ El nombre solo puede contener letras y espacios."
        elif out_result_code == 50010:
            mensaje = "⚠️ El documento de identidad debe ser numérico."
        elif out_result_code == 50008:
            mensaje = "❌ Error interno de base de datos. Intente más tarde."
        else:
            mensaje = f"❌ Error desconocido (código {out_result_code})."

        # Renderiza la página principal con el mensaje
        return render_template('insertar_empleado.html', mensaje=mensaje)


    except Exception as e:
       return render_template('insertar_empleado.html', mensaje=f"❌ Error de conexión o ejecución: {str(e)}")
        
#-----------------------------------------------------------------------------------------------------------------
def registrar_evento(tipo_evento, descripcion=""):
    try:
        usuario = session.get("usuario", "desconocido")
        ip = request.remote_addr
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("{CALL sp_insertar_bitacora (?, ?, ?, ?)}", (tipo_evento, descripcion, session.get('usuario', 'Sistema'),  request.remote_addr))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print("Error registrando evento:", e)

#-----------------------------------------------------------------------------------------------------------------
def obtener_error(codigo):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("{CALL sp_obtener_error (?)}", (codigo,))
        row = cur.fetchone()
        conn.close()
        return row[0] if row else "Error desconocido"
    except Exception:
        return "Error desconocido"

#-----------------------------------------------------------------------------------------------------------------
@app.route('/movimientos')
def movimientos():
    if 'usuario' not in session:
        return redirect(url_for('login'))


    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("{CALL sp_listar_movimientos}")
        movimientos = [dict(zip([c[0] for c in cur.description], row)) for row in cur.fetchall()]
        conn.close()
        return render_template('movimientos.html', movimientos=movimientos)
    except Exception as e:
        registrar_evento("Error listar movimientos", str(e))
        return render_template('error.html', codigo=500, mensaje="Error al listar movimientos")

#-----------------------------------------------------------------------------------------------------------------
@app.route('/insertar_movimiento', methods=['GET', 'POST'])
def insertar_movimiento():
    if 'usuario' not in session:
        return redirect(url_for('login'))

    if request.method == 'POST':
        cedula = request.form['cedula']
        id_tipo_movimiento = int(request.form['id_tipo_movimiento'])
        monto = float(request.form['monto'])
        fecha = request.form.get('fecha') or None
        usuario = session.get('usuario')
        ip = request.remote_addr


        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                "{CALL sp_insertar_movimiento (?, ?, ?, ?, ?)}",
                (cedula, id_tipo_movimiento, monto, usuario, ip)
            )
            conn.commit()

            registrar_evento(
                "Insertar movimiento exitoso",
                f"Cédula: {cedula}, Tipo: {id_tipo_movimiento}, Monto: {monto}"
            )
            return render_template('insertar_movimiento.html', mensaje=f"✅ Movimiento registrado para {cedula}")

        except Exception as e:
            desc = obtener_error(501)
            registrar_evento(
                "Intento de insertar movimiento",
                f"{desc}, Cédula: {cedula}, Tipo: {id_tipo_movimiento}, Monto: {monto}"
            )
            mensaje = f"❌ {desc}"
        finally:
            conn.close()

        return render_template('insertar_movimiento.html', mensaje=mensaje)

    return render_template('insertar_movimiento.html')

#-----------------------------------------------------------------------------------------------------------------

@app.errorhandler(404)
def not_found(e):
    return render_template("error.html", codigo=404, mensaje="Página no encontrada"), 404

@app.errorhandler(500)
def server_error(e):
    return render_template("error.html", codigo=500, mensaje="Error interno del servidor"), 500



if __name__ == "__main__":
    app.run(debug=True)
