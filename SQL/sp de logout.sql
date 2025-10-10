CREATE PROCEDURE sp_logout 
	@Username Nvarchar(50),
	@IP Nvarchar (50)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @UserId int;

	-- obtener el id del usuario 
	SELECT @UserId =Id FROM dbo.Usuario WHERE Username= @Username;
	
	INSERT INTO dbo.BitacoraEvento ( [IdTipoEvento], [Descripcion], [IdPostByUser], [PostInIP], [PostTime])
	VALUES (4,'',@UserId,@IP,GETDATE());
END; 
GO 