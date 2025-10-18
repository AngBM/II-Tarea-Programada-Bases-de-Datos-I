CREATE PROCEDURE sp_actualizar_empleado
    @ValorDocumentoIdentidad NVARCHAR(20),
    @NuevoNombre NVARCHAR(100),
    @NuevoIdPuesto INT,
    @PostByUser NVARCHAR(50),
    @PostInIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdUser INT, @NombreAnt NVARCHAR(100), @PuestoAnt NVARCHAR(100), @Saldo DECIMAL(10,2);
    DECLARE @Desc NVARCHAR(500);
    SELECT @IdUser = Id FROM Usuario WHERE Username = @PostByUser;

    SELECT @NombreAnt = E.Nombre, @PuestoAnt = P.Nombre, @Saldo = E.SaldoVacaciones
    FROM Empleado E JOIN Puesto P ON E.IdPuesto = P.Id
    WHERE E.ValorDocumentoIdentidad = @ValorDocumentoIdentidad;

    UPDATE Empleado
    SET Nombre = @NuevoNombre, IdPuesto = @NuevoIdPuesto
    WHERE ValorDocumentoIdentidad = @ValorDocumentoIdentidad;

    SET @Desc = CONCAT('Antes: ', @ValorDocumentoIdentidad, ', ', @NombreAnt, ', ', @PuestoAnt,
                       ' -> Después: ', @NuevoNombre, ', NuevoPuestoId=', @NuevoIdPuesto,
                       ', SaldoVacaciones=', @Saldo);

    INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
    VALUES(9, @Desc, @IdUser, @PostInIP, GETDATE());
END
GO
