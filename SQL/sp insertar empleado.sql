CREATE PROCEDURE sp_insertar_empleado
    @ValorDocumentoIdentidad NVARCHAR(20),
    @Nombre NVARCHAR(100),
    @IdPuesto INT,
    @PostByUser NVARCHAR(50), -- Usuario que realiza la acción 
    @PostInIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Descripcion NVARCHAR(500);
    DECLARE @IdUser INT;
    DECLARE @IdTipoEvento INT;
    DECLARE @FechaActual DATETIME = GETDATE();

    BEGIN TRY
        -- Obtener Id del usuario que realiza la acción
        SELECT @IdUser = Id
        FROM Usuario
        WHERE Username = @PostByUser;

        IF @IdUser IS NULL
        BEGIN
            -- Usuario no existe
            SELECT @Descripcion = Descripcion
            FROM dbo.Error
            WHERE Codigo = 50001; -- Usuario inválido

            SET @IdTipoEvento = 2; -- Inserción no exitosa

            INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES (@IdTipoEvento, @Descripcion, NULL, @PostInIP, @FechaActual);

            RETURN;
        END

        -- Validar que no exista otro empleado con mismo ValorDocumentoIdentidad
        IF EXISTS(SELECT 1 FROM Empleado WHERE ValorDocumentoIdentidad = @ValorDocumentoIdentidad)
        BEGIN
            SELECT @Descripcion = Descripcion + ': ' + @ValorDocumentoIdentidad + ', ' + @Nombre + ', IdPuesto=' + CAST(@IdPuesto AS NVARCHAR)
            FROM dbo.Error
            WHERE Codigo = 50004; -- ValorDocumentoIdentidad ya existe en inserción

            SET @IdTipoEvento = 2; -- Inserción no exitosa

            INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES (@IdTipoEvento, @Descripcion, @IdUser, @PostInIP, @FechaActual);

            RETURN;
        END

        -- Validar que no exista otro empleado con mismo Nombre
        IF EXISTS(SELECT 1 FROM Empleado WHERE Nombre = @Nombre)
        BEGIN
            SELECT @Descripcion = Descripcion + ': ' + @ValorDocumentoIdentidad + ', ' + @Nombre + ', IdPuesto=' + CAST(@IdPuesto AS NVARCHAR)
            FROM dbo.Error
            WHERE Codigo = 50005; -- Nombre ya existe en inserción

            SET @IdTipoEvento = 2; -- Inserción no exitosa

            INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES (@IdTipoEvento, @Descripcion, @IdUser, @PostInIP, @FechaActual);

            RETURN;
        END

        -- Insertar el empleado
        INSERT INTO Empleado (ValorDocumentoIdentidad, Nombre, IdPuesto, FechaContratacion)
        VALUES (@ValorDocumentoIdentidad, @Nombre, @IdPuesto, @FechaActual);

        -- Registrar inserción exitosa en BitacoraEvento
        SET @IdTipoEvento = 6; -- Inserción exitosa
        SELECT @Descripcion = @ValorDocumentoIdentidad + ', ' + @Nombre + ', IdPuesto=' + CAST(@IdPuesto AS NVARCHAR);

        INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES (@IdTipoEvento, @Descripcion, @IdUser, @PostInIP, @FechaActual);

    END TRY
    BEGIN CATCH
        -- Captura errores de SQL
        INSERT INTO DBError(UserName, Number, State, Severity, Line, [Procedure], Message, DateTime)
        VALUES(@PostByUser, ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), GETDATE());

        -- Registrar en BitacoraEvento usando el código de error de base de datos
        SELECT @Descripcion = Descripcion + ': ' + @ValorDocumentoIdentidad + ', ' + @Nombre + ', IdPuesto=' + CAST(@IdPuesto AS NVARCHAR)
        FROM dbo.Error
        WHERE Codigo = 50008; -- Error de base de datos

        INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES(2, @Descripcion, @IdUser, @PostInIP, @FechaActual);
    END CATCH
END
