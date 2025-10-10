CREATE PROCEDURE sp_login
    -- parametros de entrada 
    @Username NVARCHAR(50),
    @Password NVARCHAR(255),
    @IP NVARCHAR(50),
    @ResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserId INT;
    DECLARE @intentosfallidos INT;

    BEGIN TRY
        --  Verificar si el usuario existe
        SELECT @UserId = Id FROM Usuario
        WHERE Username = @Username;

        IF @UserId IS NULL
        BEGIN
            -- Usuario no existe
            SET @ResultCode = 50001; -- de prueba 
            INSERT INTO BitacoraEvento (IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES (2, 'Intentos: 0, CodigoError: 50001', NULL, @IP, GETDATE());
            RETURN;
        END

        --  Contar intentos fallidos en los últimos 5 minutos
        SELECT @intentosfallidos = COUNT(*)
        FROM BitacoraEvento
        WHERE IdPostByUser = @UserId
          AND IdTipoEvento = 2 -- Login No exitoso
          AND PostTime >= DATEADD(MINUTE, -5, GETDATE());


        -- si llego al limite de intentos
        IF @intentosfallidos >= 5
        BEGIN
            -- Login deshabilitado
            SET @ResultCode = 50003; -- prueba 
            INSERT INTO BitacoraEvento (IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES (3, 'Login deshabilitado', @UserId, @IP, GETDATE());
            RETURN;
        END

        --  Validar contraseña
        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE Id = @UserId AND Password = @Password) -- si no se encuentra contraseña
        BEGIN
            -- Contraseña incorrecta
            SET @ResultCode = 50002; -- prueba 
            INSERT INTO BitacoraEvento (IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES (2, CONCAT('Intentos: ', @intentosfallidos + 1, ', CodigoError: 50002'), @UserId, @IP, GETDATE());
            RETURN;
        END

        --  Login exitoso
        SET @ResultCode = 0;
        INSERT INTO BitacoraEvento (IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES (1, NULL, @UserId, @IP, GETDATE());

    END TRY
    BEGIN CATCH
        -- Capturar errores de SQL y registrar en DBError
        DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorState INT = ERROR_STATE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorLine INT = ERROR_LINE();
        DECLARE @ErrorProcedure NVARCHAR(128) = ERROR_PROCEDURE();

        INSERT INTO DBError (UserName, Number, State, Severity, Line, [Procedure], Message, DateTime)
        VALUES (@Username, @ErrorNumber, @ErrorState, @ErrorSeverity, @ErrorLine, @ErrorProcedure, @ErrorMessage, GETDATE());

        SET @ResultCode = -1; -- Código de error técnico
    END CATCH
END
