ALTER PROCEDURE [dbo].[sp_listar_movimientos]
    @ValorDocumentoIdentidad NVARCHAR(20) = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @PostByUser NVARCHAR(50),
    @PostInIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        E.Nombre AS NombreEmpleado,
        E.ValorDocumentoIdentidad AS Documento,
        M.Fecha AS FechaMovimiento,
        TM.Nombre AS TipoMovimiento,
        M.Monto,
        M.NuevoSaldo,
        U.Username AS UsuarioRegistro, 
        M.PostInIP,
        M.PostTime
    FROM Movimiento M
    INNER JOIN Empleado E ON M.IdEmpleado = E.Id
    INNER JOIN TipoMovimiento TM ON M.IdTipoMovimiento = TM.Id
    INNER JOIN Usuario U ON M.IdPostByUser = U.Id
    WHERE (@ValorDocumentoIdentidad IS NULL OR E.ValorDocumentoIdentidad = @ValorDocumentoIdentidad)
      AND (@FechaInicio IS NULL OR M.Fecha >= @FechaInicio)
      AND (@FechaFin IS NULL OR M.Fecha <= @FechaFin)
    ORDER BY M.Fecha DESC;
END
