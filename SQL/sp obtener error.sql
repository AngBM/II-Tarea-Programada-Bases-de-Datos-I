CREATE PROCEDURE sp_obtener_error
    @Codigo INT
AS
BEGIN
    SELECT Descripcion FROM Error WHERE Codigo = @Codigo;
END
GO
