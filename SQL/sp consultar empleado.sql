ALTER PROCEDURE [dbo].[sp_consultar_empleado]
    @ValorDocumentoIdentidad NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        E.Id,
        E.ValorDocumentoIdentidad,
        E.Nombre,
        E.IdPuesto,
        P.Nombre AS Puesto,
        E.SaldoVacaciones,
        E.EsActivo
    FROM Empleado E
    INNER JOIN Puesto P ON E.IdPuesto = P.Id
    WHERE E.ValorDocumentoIdentidad = @ValorDocumentoIdentidad;
END