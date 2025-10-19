CREATE PROCEDURE sp_listar_movimientos
    @ValorDocumentoIdentidad NVARCHAR(20) = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @PostByUser NVARCHAR(50),
    @PostInIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdUser INT;
    SELECT @IdUser = Id FROM Usuario WHERE Username = @PostByUser;

    INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
    VALUES(15, 'Consulta de movimientos', @IdUser, @PostInIP, GETDATE());

    SELECT E.Nombre, E.ValorDocumentoIdentidad, TM.Nombre AS TipoMovimiento, 
           M.Monto, M.Fecha, M.NuevoSaldo
    FROM Movimiento M
         JOIN Empleado E ON M.IdEmpleado = E.Id
         JOIN TipoMovimiento TM ON M.IdTipoMovimiento = TM.Id
    WHERE (@ValorDocumentoIdentidad IS NULL OR E.ValorDocumentoIdentidad = @ValorDocumentoIdentidad)
      AND (@FechaInicio IS NULL OR M.Fecha >= @FechaInicio)
      AND (@FechaFin IS NULL OR M.Fecha <= @FechaFin)
    ORDER BY M.Fecha DESC;
END
GO
