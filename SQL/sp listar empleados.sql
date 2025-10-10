
CREATE PROCEDURE sp_listar_empleados
    @inFiltro NVARCHAR(100) = NULL,         
    @inPostByUser NVARCHAR(50),
    @inPostInIP NVARCHAR(50),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FiltroTipo NVARCHAR(10);        -- Nombre o Cedula
    DECLARE @Descripcion NVARCHAR(500);
    DECLARE @IdUser INT;

    BEGIN TRY
        -- Obtiene el  Id del usuario que se envio desde el login
        SELECT @IdUser = U.Id
        FROM dbo.Usuario AS U
        WHERE U.Username = @inPostByUser;

        
        -- Determinar tipo de filtro
        IF (@inFiltro IS NULL OR LTRIM(RTRIM(@inFiltro)) = '') -- revisa si esta vacio
        BEGIN
            SET @FiltroTipo = NULL;           -- Listar todos
        END

        ELSE IF (@inFiltro NOT LIKE '%[^0-9]%') -- revisa si son solo numeros 

        BEGIN
            SET @FiltroTipo = 'Cedula';      
        END

        ELSE IF (@inFiltro NOT LIKE '%[^a-zA-Z ]%') -- revisa que sean solo letras

        BEGIN
            SET @FiltroTipo = 'Nombre';       -- Solo letras y espacios
        END

        IF (@FiltroTipo IS NULL)-- si el filtro viene vacio se muestran todos los empleados
        BEGIN
           
            SELECT E.Nombre,
                   E.ValorDocumentoIdentidad
            FROM dbo.Empleado AS E
            WHERE (E.EsActivo = 1)
            ORDER BY E.Nombre ASC;
        END

        ELSE IF (@FiltroTipo = 'Nombre')
        BEGIN
            -- Registrar la búsqueda por nombre
            INSERT INTO dbo.BitacoraEvento
                (IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES
                (11,@inFiltro, @IdUser, @inPostInIP, GETDATE());

            -- obtener los datos
            SELECT E.Nombre,
                   E.ValorDocumentoIdentidad
            FROM dbo.Empleado AS E
            WHERE (E.EsActivo = 1)
              AND (E.Nombre LIKE '%' + @inFiltro + '%') -- que tengan en el string el filtro
            ORDER BY E.Nombre ASC;
        END

        ELSE IF (@FiltroTipo = 'Cedula')
        BEGIN
            -- Registrar la búsqueda por cédula
            INSERT INTO dbo.BitacoraEvento
                (IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES
                (12,@inFiltro, @IdUser, @inPostInIP, GETDATE());

            -- obtener los datos del empleado
            SELECT E.Nombre,
                   E.ValorDocumentoIdentidad
            FROM dbo.Empleado AS E
            WHERE (E.EsActivo = 1)
              AND (E.ValorDocumentoIdentidad LIKE '%' + @inFiltro + '%')
            ORDER BY E.Nombre ASC;
        END


        SET @outResultCode = 0; -- Éxito

    END TRY
    BEGIN CATCH
        -- Captura errores SQL y registra en DBError
        INSERT INTO dbo.DBError
            (UserName, Number, State, Severity, Line, [Procedure], Message, DateTime)
        VALUES
            (@inPostByUser,
             ERROR_NUMBER(),
             ERROR_STATE(),
             ERROR_SEVERITY(),
             ERROR_LINE(),
             ERROR_PROCEDURE(),
             ERROR_MESSAGE(),
             GETDATE());

        SET @outResultCode = 50008; -- Error de base de datos
    END CATCH
END
GO
