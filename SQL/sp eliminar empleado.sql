ALTER PROCEDURE [dbo].[sp_eliminar_empleado]
    @ValorDocumentoIdentidad NVARCHAR(20),
    @Confirmado BIT,
    @PostByUser NVARCHAR(50),
    @PostInIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdUser INT, @Nombre NVARCHAR(100), @Puesto NVARCHAR(100), @Saldo DECIMAL(10,2);
    SELECT @IdUser = Id FROM Usuario WHERE Username = @PostByUser;
    SELECT @Nombre = E.Nombre, @Puesto = P.Nombre, @Saldo = E.SaldoVacaciones
    FROM Empleado E JOIN Puesto P ON E.IdPuesto = P.Id
    WHERE E.ValorDocumentoIdentidad = @ValorDocumentoIdentidad;

    IF @Confirmado = 0
    BEGIN
        INSERT INTO BitacoraEvento VALUES(10, CONCAT(@ValorDocumentoIdentidad, ', ', @Nombre, ', ', @Puesto, ', ', @Saldo),
                                          @IdUser, @PostInIP, GETDATE());
        RETURN;
    END

    UPDATE Empleado
    SET EsActivo = 0
    WHERE ValorDocumentoIdentidad = @ValorDocumentoIdentidad;

    INSERT INTO BitacoraEvento VALUES(8, CONCAT(@ValorDocumentoIdentidad, ', ', @Nombre, ', ', @Puesto, ', ', @Saldo),
                                      @IdUser, @PostInIP, GETDATE());
END

