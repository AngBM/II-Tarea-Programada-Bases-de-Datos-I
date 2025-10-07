CREATE PROCEDURE sp_insertar_movimiento
    @ValorDocumentoIdentidad NVARCHAR(20),
    @IdTipoMovimiento INT,
    @Monto DECIMAL(18,2),
    @PostByUser NVARCHAR(50),
    @PostInIP NVARCHAR(50),
    @Fecha DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdEmpleado INT;
    DECLARE @SaldoActual DECIMAL(18,2);
    DECLARE @NuevoSaldo DECIMAL(18,2);
    DECLARE @IdUser INT;
    DECLARE @IdTipoEvento INT;
    DECLARE @DescripcionBase NVARCHAR(500);
    DECLARE @Descripcion NVARCHAR(500);
    DECLARE @FechaActual DATETIME = ISNULL(@Fecha, GETDATE());
    DECLARE @TipoAccion NVARCHAR(10);
    DECLARE @NombreEmpleado NVARCHAR(100);
    DECLARE @NombreTipoMovimiento NVARCHAR(100);

    BEGIN TRY
        -- Obtener Id del usuario que realiza la acción
        SELECT @IdUser = Id
        FROM Usuario
        WHERE Username = @PostByUser;

        IF @IdUser IS NULL
        BEGIN
            SELECT @DescripcionBase = Descripcion
            FROM dbo.Error
            WHERE Codigo = 50001; -- Usuario inválido

            SET @Descripcion = @DescripcionBase; -- Aquí no se agregan valores de movimiento
            SET @IdTipoEvento = 13; -- Intento de insertar movimiento
            INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES(@IdTipoEvento, @Descripcion, NULL, @PostInIP, @FechaActual);
            RETURN;
        END

        -- Obtener Id, nombre y saldo actual del empleado
        SELECT @IdEmpleado = Id, @SaldoActual = ISNULL(SaldoVacaciones,0), @NombreEmpleado = Nombre
        FROM Empleado
        WHERE ValorDocumentoIdentidad = @ValorDocumentoIdentidad;

        IF @IdEmpleado IS NULL
        BEGIN
            SET @DescripcionBase = 'Empleado no existe';
            SET @Descripcion = @DescripcionBase + ': ' + @ValorDocumentoIdentidad;
            SET @IdTipoEvento = 13; -- Intento de insertar movimiento
            INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES(@IdTipoEvento, @Descripcion, @IdUser, @PostInIP, @FechaActual);
            RETURN;
        END

        -- Obtener TipoAccion y nombre del tipo de movimiento
        SELECT @TipoAccion = TipoAccion, @NombreTipoMovimiento = Nombre
        FROM TipoMovimiento
        WHERE Id = @IdTipoMovimiento;

        -- Calcular nuevo saldo según tipo de acción
        IF @TipoAccion = 'Credito'
            SET @NuevoSaldo = @SaldoActual + @Monto;
        ELSE
            SET @NuevoSaldo = @SaldoActual - @Monto;

        -- Validar saldo negativo
        IF @NuevoSaldo < 0
        BEGIN
            -- Tomar descripción base del catálogo de errores
            SELECT @DescripcionBase = Descripcion
            FROM dbo.Error
            WHERE Codigo = 50011; -- Monto movimiento rechazado

            -- Construir descripción final para BitacoraEvento
            SET @Descripcion = @DescripcionBase + ': ' +
                               @ValorDocumentoIdentidad + ', ' +
                               @NombreEmpleado + ', SaldoActual=' + CAST(@SaldoActual AS NVARCHAR) +
                               ', TipoMovimiento=' + @NombreTipoMovimiento + ', Monto=' + CAST(@Monto AS NVARCHAR);

            SET @IdTipoEvento = 13; -- Intento de insertar movimiento
            INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES(@IdTipoEvento, @Descripcion, @IdUser, @PostInIP, @FechaActual);
            RETURN;
        END

        -- Insertar movimiento
        INSERT INTO Movimiento (IdEmpleado, IdTipoMovimiento, Fecha, Monto, NuevoSaldo, IdPostByUser, PostInIP, PostTime)
        VALUES(@IdEmpleado, @IdTipoMovimiento, @FechaActual, @Monto, @NuevoSaldo, @IdUser, @PostInIP, @FechaActual);

        -- Actualizar saldo vacaciones en empleado
        UPDATE Empleado
        SET SaldoVacaciones = @NuevoSaldo
        WHERE Id = @IdEmpleado;

        -- Registrar inserción exitosa en BitacoraEvento
        SET @IdTipoEvento = 14; -- Insertar movimiento exitoso
        SET @Descripcion = @ValorDocumentoIdentidad + ', ' +
                           @NombreEmpleado + ', NuevoSaldo=' + CAST(@NuevoSaldo AS NVARCHAR) +
                           ', TipoMovimiento=' + @NombreTipoMovimiento + ', Monto=' + CAST(@Monto AS NVARCHAR);

        INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES(@IdTipoEvento, @Descripcion, @IdUser, @PostInIP, @FechaActual);

    END TRY
    BEGIN CATCH
        -- Captura errores de SQL en DBError
        INSERT INTO DBError(UserName, Number, State, Severity, Line, [Procedure], Message, DateTime)
        VALUES(@PostByUser, ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), GETDATE());

        -- Tomar descripción base de catálogo de errores
        SELECT @DescripcionBase = Descripcion
        FROM dbo.Error
        WHERE Codigo = 50008; -- Error de base de datos

        -- Construir descripción final para BitacoraEvento
        SET @Descripcion = @DescripcionBase + ': ' +
                           @ValorDocumentoIdentidad + ', ' +
                           ISNULL(@NombreEmpleado,'') + ', SaldoActual=' + CAST(ISNULL(@SaldoActual,0) AS NVARCHAR) +
                           ', TipoMovimiento=' + ISNULL(@NombreTipoMovimiento,'') + ', Monto=' + CAST(ISNULL(@Monto,0) AS NVARCHAR);

        INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES(13, @Descripcion, @IdUser, @PostInIP, @FechaActual);
    END CATCH
END
GO
