CREATE PROCEDURE sp_insertar_bitacora
    @TipoEvento NVARCHAR(50),
    @Descripcion NVARCHAR(500),
    @IdPostByUser NVARCHAR(50),
    @IP NVARCHAR(50)
AS
BEGIN
    INSERT INTO BitacoraEvento(IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
    VALUES ((SELECT Id FROM TipoEvento WHERE Nombre = @TipoEvento),
            @Descripcion, 
            (SELECT Id FROM Usuario WHERE Username = @IdPostByUser),
            @IP,
            GETDATE());
END
GO

