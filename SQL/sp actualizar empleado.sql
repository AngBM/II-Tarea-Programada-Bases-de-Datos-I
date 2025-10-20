ALTER PROCEDURE [dbo].[sp_actualizar_empleado]
    @ValorDocumentoIdentidad NVARCHAR(20),
    @NuevoValorDocumentoIdentidad NVARCHAR(20),
    @NuevoNombre NVARCHAR(100),
    @NuevoIdPuesto INT,
    @PostByUser NVARCHAR(50),
    @PostInIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdUser INT,
            @IdEmpleado INT,
            @NombreAnt NVARCHAR(100),
            @PuestoAnt NVARCHAR(100),
            @SaldoAnt DECIMAL(10,2),
            @NuevoPuesto NVARCHAR(100),
            @Descripcion NVARCHAR(800),
            @Msg NVARCHAR(4000);

    BEGIN TRY
        SELECT @IdUser = Id FROM Usuario WHERE Username = @PostByUser;

        -- Validar que el empleado exista
        SELECT 
            @IdEmpleado = E.Id,
            @NombreAnt = E.Nombre,
            @PuestoAnt = P.Nombre,
            @SaldoAnt = E.SaldoVacaciones
        FROM Empleado E
        INNER JOIN Puesto P ON E.IdPuesto = P.Id
        WHERE E.ValorDocumentoIdentidad = @ValorDocumentoIdentidad;

        IF @IdEmpleado IS NULL
        BEGIN
            RAISERROR('Empleado no encontrado.', 16, 1);
            RETURN;
        END

        -- Validar duplicado de documento
        IF EXISTS (SELECT 1 FROM Empleado WHERE ValorDocumentoIdentidad = @NuevoValorDocumentoIdentidad AND Id <> @IdEmpleado)
        BEGIN
            RAISERROR('Ya existe otro empleado con ese valor de documento.', 16, 1);
            RETURN;
        END

        -- Validar duplicado de nombre
        IF EXISTS (SELECT 1 FROM Empleado WHERE Nombre = @NuevoNombre AND Id <> @IdEmpleado)
        BEGIN
            RAISERROR('Ya existe otro empleado con ese nombre.', 16, 1);
            RETURN;
        END

        -- Obtener nombre del nuevo puesto
        SELECT @NuevoPuesto = Nombre FROM Puesto WHERE Id = @NuevoIdPuesto;

        -- Actualizar empleado (sin modificar saldo)
        UPDATE Empleado
        SET ValorDocumentoIdentidad = @NuevoValorDocumentoIdentidad,
            Nombre = @NuevoNombre,
            IdPuesto = @NuevoIdPuesto
        WHERE Id = @IdEmpleado;

        -- Registrar evento exitoso
        SET @Descripcion = CONCAT(
            'Antes: ', @ValorDocumentoIdentidad, ', ', @NombreAnt, ', ', @PuestoAnt,
            ' | Después: ', @NuevoValorDocumentoIdentidad, ', ', @NuevoNombre, ', ', @NuevoPuesto
        );

        INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES(6, @Descripcion, @IdUser, @PostInIP, GETDATE());
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT('Error en actualización: ', ERROR_MESSAGE());
        INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES(7, @Msg, @IdUser, @PostInIP, GETDATE());
        RAISERROR(@Msg, 16, 1);
    END CATCH
END