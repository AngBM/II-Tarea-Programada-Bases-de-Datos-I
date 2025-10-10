from flask import Flask, render_template, request, redirect, url_for, make_response
import pyodbc

app = Flask(__name__)

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

# Página principal de login
@app.route('/', methods=['GET'])
def login():
    return render_template('login.html', error=None)

# Procesar login
@app.route('/', methods=['POST'])
def login_post():
    username = request.form.get('username').strip()
    password = request.form.get('password').strip()

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Llamar SP de login (ya maneja IP y bitácora)
        cursor.execute("{CALL sp_login (?, ?, ?)}", (username, password, request.remote_addr))
        result = cursor.fetchone()

        cursor.close()
        conn.commit()
        conn.close()

        if result and result.CodigoError == 0:
            # Login exitoso
            response = make_response(redirect('/empleados'))
            response.set_cookie('username', username, max_age=60*60*2)
            return response
        else:
            error_message = result.Descripcion if result else "Error desconocido"
            return render_template('login.html', error=error_message)

    except Exception as e:
        return render_template('login.html', error=f"Error de conexión: {str(e)}")

# Logout
@app.route('/logout', methods=['POST'])
def logout():
    username = request.cookies.get('username')
    ip_user = request.remote_addr

    if username:
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("{CALL sp_logout (?, ?)}", (username, ip_user))
            cursor.close()
            conn.commit()
            conn.close()
        except Exception as e:
            return f"Error al cerrar sesión: {str(e)}"

    response = redirect(url_for('login'))
    response.delete_cookie('username')
    return response

# Listado y filtrado de empleados
@app.route('/empleados', methods=['GET'])
def empleados():
    username = request.cookies.get('username')
    if not username:
        return redirect(url_for('login'))

    filtro = request.args.get('filtro', '').strip()
    ip_user = request.remote_addr

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Llamada al SP, envia filtro, username y IP
        cursor.execute("{CALL sp_listar_empleados (?, ?, ?)}", (filtro if filtro else None, username, ip_user))

        empleados = []
        for row in cursor.fetchall():
            empleados.append({
                'Nombre': row.Nombre,
                'ValorDocumentoIdentidad': row.ValorDocumentoIdentidad
            })

        cursor.close()
        conn.commit()
        conn.close()

        return render_template('principal.html', empleados=empleados, filtro=filtro)

    except Exception as e:
        return render_template('principal.html', empleados=[], filtro=filtro, error=f"Error de conexión: {str(e)}")


if __name__ == "__main__":
    app.run(debug=True)
