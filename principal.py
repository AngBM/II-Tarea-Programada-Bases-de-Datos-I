from flask import Flask, make_response, render_template, request, redirect, url_for
import pyodbc

app = Flask(__name__)

# Función para conectar a la base
def get_db_connection():
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
    return connection

@app.route('/', methods=['GET'])
def login():
    return render_template('login.html', error=None)

@app.route('/', methods=['POST'])
def login_post():
    username = request.form.get('username').strip()
    password = request.form.get('password').strip()

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Llamada al SP 
        cursor.execute("{CALL sp_login (?, ?)}", (username, password))
        result = cursor.fetchone()

        cursor.close()
        conn.commit()
        conn.close()

        # Verificar resultado del SP
        if result and result.CodigoError == 0:
            # Login exitoso: redirigir a la página principal
            response = make_response(redirect('/dashboard'))
            response.set_cookie('username', username, max_age=60*60*2)  # 2 horas
            return response
        else:
            # Login fallido: mostrar mensaje
            error_message = result.Descripcion if result else "Error desconocido"
            return render_template('login.html', error=error_message)

    except Exception as e:
        # Error de conexión o SP
        return render_template('login.html', error=f"Error de conexión: {str(e)}")

# Logout
@app.route('/logout', methods=['POST'])
def logout():
    username = request.cookies.get('username')
    ip_user = request.remote_addr  # Obtener IP del usuario

    if username:
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            # Llamada al SP de logout
            cursor.execute("{CALL sp_logout (?, ?)}", (username, ip_user))
            cursor.close()
            conn.commit()
            conn.close()
        except Exception as e:
            return f"Error al cerrar sesión: {str(e)}"

    # Redirigir al login y eliminar cookie
    response = redirect(url_for('login'))
    response.delete_cookie('username')
    return response


@app.route('/dashboard')
def dashboard():
    return "<h1>Bienvenido a la pagina principal </h1>"

if __name__ == "__main__":
    app.run(debug=True)
