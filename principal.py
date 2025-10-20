from flask import Flask, render_template, request, redirect, url_for, make_response, session, flash
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
    username = session.get('usuario')

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

    doc = request.args.get('doc')
    nombre = request.args.get('nombre')
    username = session.get('usuario')
    ip = request.remote_addr

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("{CALL sp_listar_movimientos (?, ?, ?, ?, ?)}", (doc, None, None, username, ip))
    movimientos = [dict(zip([c[0] for c in cur.description], row)) for row in cur.fetchall()]
    conn.close()

    return render_template('movimientos.html', nombre=nombre, doc=doc, movimientos=movimientos)


#-----------------------------------------------------------------------------------------------------------------
@app.route('/insertar_movimiento', methods=['GET', 'POST'])
def insertar_movimiento():
    if 'usuario' not in session:
        return redirect(url_for('login'))

    conn = get_db_connection()
    cur = conn.cursor()

    if request.method == 'GET':
        nombre = request.args.get('nombre')
        doc = request.args.get('doc')

        # Obtener saldo actual del empleado
        cur.execute("SELECT SaldoVacaciones FROM Empleado WHERE ValorDocumentoIdentidad = ?", (doc,))
        saldo = cur.fetchone()[0]

        # Cargar tipos de movimiento
        cur.execute("SELECT Id, Nombre FROM TipoMovimiento")
        tipos = [dict(zip([c[0] for c in cur.description], row)) for row in cur.fetchall()]

        conn.close()
        return render_template('insertar_movimiento.html', nombre=nombre, doc=doc, saldo=saldo, tipos=tipos)

    else:
        doc = request.form['doc']
        tipo = int(request.form['tipo'])
        monto = float(request.form['monto'])
        usuario = session.get('usuario')
        ip = request.remote_addr

        # Obtener saldo actual del empleado
        cur.execute("SELECT SaldoVacaciones FROM Empleado WHERE ValorDocumentoIdentidad = ?", (doc,))
        saldo_actual = cur.fetchone()[0]

        # Verificar si el movimiento dejaría saldo negativo
        cur.execute("SELECT Nombre FROM TipoMovimiento WHERE Id = ?", (tipo,))
        tipo_nombre = cur.fetchone()[0]

        if tipo_nombre in ('Vacaciones', 'Ajuste negativo') and saldo_actual - monto < 0:
            conn.close()
            return render_template(
                'insertar_movimiento.html',
                nombre=request.form.get('nombre'),
                doc=doc,
                saldo=saldo_actual,
                tipos=[],
                error="❌ El saldo no puede quedar negativo."
            )

        #  Insertar el movimiento usando el SP y obtener el código de resultado
        cur.execute("""
            DECLARE @result INT;
            EXEC dbo.sp_insertar_movimiento
                @inValorDocumentoIdentidad = ?,
                @inIdTipoMovimiento = ?,
                @inMonto = ?,
                @inPostByUser = ?,
                @inPostInIP = ?,
                @outResultCode = @result OUTPUT;
            SELECT @result;
        """, (doc, tipo, monto, usuario, ip))

        result_code = cur.fetchone()[0]
        conn.commit()
        conn.close()

        #  Validar el código de salida del SP
        if result_code == 50011:
            return render_template(
                'insertar_movimiento.html',
                nombre=request.form.get('nombre'),
                doc=doc,
                saldo=saldo_actual,
                tipos=[],
                error="⚠️ No se puede registrar el movimiento: dejaría el saldo negativo."
            )

        # Si todo sale bien, redirigir
        return redirect(url_for('movimientos', nombre=request.args.get('nombre') or request.form.get('nombre'), doc=doc))


#-----------------------------------------------------------------------------------------------------------------

@app.route('/consultar')
def consultar_empleado():
    doc = request.args.get('doc')
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("{CALL sp_consultar_empleado(?)}", (doc,))
    empleado = cur.fetchone()
    conn.close()
    return render_template('consultar_empleado.html', empleado=empleado)

#--------------------------------------------------------------------------------------------------
@app.route('/actualizar', methods=['GET', 'POST'])
def actualizar():
    if 'usuario' not in session:
        return redirect(url_for('login'))

    conn = get_db_connection()
    cur = conn.cursor()

    try:

        if request.method == 'GET':
            nombre = request.args.get('nombre')
            doc = request.args.get('doc')

            sql = f"EXEC sp_consultar_empleado '{doc}'"
            cur.execute(sql)
            fila = cur.fetchone()

            if not fila:
                return render_template('error.html', codigo=404, mensaje="Empleado no encontrado")

            columnas = [col[0] for col in cur.description]
            empleado = dict(zip(columnas, fila))

            cur.execute("SELECT Id, Nombre FROM Puesto")
            puestos = [dict(zip([c[0] for c in cur.description], row)) for row in cur.fetchall()]

            return render_template('actualizar_empleado.html', empleado=empleado, puestos=puestos)

        else:
            doc_actual = request.form.get('doc_actual')
            nuevo_doc = request.form.get('doc')
            nuevo_nombre = request.form.get('nombre')
            nuevo_puesto = int(request.form.get('puesto'))
            usuario = session.get('usuario')
            ip = request.remote_addr

            sql = (
                "EXEC sp_actualizar_empleado "
                f"'{doc_actual}', '{nuevo_doc}', '{nuevo_nombre}', {nuevo_puesto}, '{usuario}', '{ip}'"
            )

            cur.execute(sql)
            conn.commit()

            flash(" Empleado actualizado correctamente.", "success")
            return redirect(url_for('empleados'))

    except Exception as e:
        if conn and not conn.closed:
            conn.rollback()
        print("Error en actualizar_empleado:", e)
        return render_template('error.html', codigo=500, mensaje=str(e))

    finally:
        conn.close()






#------------------------------------------------------------------------------------------------------------
@app.route('/eliminar')
def eliminar_empleado():
    if 'usuario' not in session:
        return redirect(url_for('login'))

    doc = request.args.get('doc')
    nombre = request.args.get('nombre')
    usuario = session.get('usuario')
    ip = request.remote_addr
    confirmado = int(request.args.get('confirmar', '0'))  # 0 si no se confirma

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Ejecutar SP de eliminación 
        cur.execute("{CALL sp_eliminar_empleado(?, ?, ?, ?)}", (doc, confirmado, usuario, ip))
        conn.commit()

        if confirmado == 1:
            flash(f" Empleado {nombre} ({doc}) eliminado correctamente (borrado lógico).", "success")
        else:
            flash(f" Intento de eliminación registrado para {nombre} ({doc}).", "info")

        return redirect(url_for('empleados'))

    except Exception as e:
        if conn and not conn.closed:
            conn.rollback()
        print("Error al eliminar empleado:", e)
        return render_template('error.html', codigo=500, mensaje=str(e))

    finally:
        conn.close()


#---------------------------------------------------------------------------------------------------------


#---------------------------------------------------------------------------------------------------------
@app.errorhandler(404)
def not_found(e):
    return render_template("error.html", codigo=404, mensaje="Página no encontrada"), 404

@app.errorhandler(500)
def server_error(e):
    return render_template("error.html", codigo=500, mensaje="Error interno del servidor"), 500



if __name__ == "__main__":
    app.run(debug=True)
