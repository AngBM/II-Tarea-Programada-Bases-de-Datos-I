ALTER PROCEDURE [dbo].[sp_insertar_movimiento]
    @ValorDocumentoIdentidad NVARCHAR(20),
    @IdTipoMovimiento INT,
    @Monto DECIMAL(5,2),
    @PostByUser NVARCHAR(50),
    @PostInIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdEmpleado INT,
            @SaldoActual DECIMAL(5,2),
            @NuevoSaldo DECIMAL(5,2),
            @IdPostByUser INT,
            @TipoMovimientoNombre NVARCHAR(100),
            @TipoAccion NVARCHAR(20);

    -- Obtener datos base del empleado
    SELECT @IdEmpleado = Id, @SaldoActual = SaldoVacaciones
    FROM Empleado
    WHERE ValorDocumentoIdentidad = @ValorDocumentoIdentidad;

    SELECT @IdPostByUser = Id FROM Usuario WHERE Username = @PostByUser;

    -- Obtener nombre y tipo de acción del movimiento
    SELECT @TipoMovimientoNombre = Nombre, @TipoAccion = TipoAccion
    FROM TipoMovimiento
    WHERE Id = @IdTipoMovimiento;

    -- Calcular nuevo saldo según el tipo de acción
    IF @TipoAccion = 'Debito'
        SET @NuevoSaldo = @SaldoActual - @Monto;
    ELSE IF @TipoAccion = 'Credito'
        SET @NuevoSaldo = @SaldoActual + @Monto;
    ELSE
    BEGIN
        RAISERROR('Tipo de movimiento desconocido.', 16, 1);
        RETURN;
    END

    -- Validación: no permitir saldo negativo
    IF @NuevoSaldo < 0
    BEGIN
        RAISERROR('El saldo no puede ser negativo.', 16, 1);
        RETURN;
    END

    -- nsertar movimiento
    INSERT INTO Movimiento (IdEmpleado, IdTipoMovimiento, Fecha, Monto, NuevoSaldo, IdPostByUser, PostInIP, PostTime)
    VALUES (@IdEmpleado, @IdTipoMovimiento, GETDATE(), @Monto, @NuevoSaldo, @IdPostByUser, @PostInIP, GETDATE());

    -- Actualizar saldo del empleado
    UPDATE Empleado
    SET SaldoVacaciones = @NuevoSaldo
    WHERE Id = @IdEmpleado;
END
