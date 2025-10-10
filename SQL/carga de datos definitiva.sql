CREATE PROCEDURE sp_cargar_datos_xml
    @XMLData XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        --------------------------------------
        -- Usuarios
        INSERT INTO Usuario (Id, Username, Password)
        SELECT 
            E.value('@Id','INT'),
            E.value('@Nombre','NVARCHAR(50)'),
            E.value('@Pass','NVARCHAR(50)')
        FROM @XMLData.nodes('/Datos/Usuarios/usuario') AS T(E);

        -- Puestos
        INSERT INTO Puesto (Nombre, SalarioxHora)
        SELECT 
            E.value('@Nombre','NVARCHAR(50)'),
            E.value('@SalarioxHora','DECIMAL(10,2)')
        FROM @XMLData.nodes('/Datos/Puestos/Puesto') AS T(E);

        -- TiposEvento
        INSERT INTO TipoEvento (Id, Nombre)
        SELECT 
            E.value('@Id','INT'),
            E.value('@Nombre','NVARCHAR(50)')
        FROM @XMLData.nodes('/Datos/TiposEvento/TipoEvento') AS T(E);

        -- TiposMovimientos
        INSERT INTO TipoMovimiento (Id, Nombre, TipoAccion)
        SELECT 
            E.value('@Id','INT'),
            E.value('@Nombre','NVARCHAR(50)'),
            E.value('@TipoAccion','NVARCHAR(20)')
        FROM @XMLData.nodes('/Datos/TiposMovimientos/TipoMovimiento') AS T(E);

        -- ErrorCodes
        INSERT INTO Error (Id, Codigo, Descripcion)
        SELECT 
            E.value('@Id','INT'),
            E.value('@Codigo','NVARCHAR(20)'),
            E.value('@Descripcion','NVARCHAR(200)')
        FROM @XMLData.nodes('/Datos/Error/errorCodigo') AS T(E);

        --------------------------------------
        -- Preparar empleados
        --------------------------------------
        DECLARE @Empleados TABLE (
            RowNum INT IDENTITY(1,1) PRIMARY KEY,
            Nombre NVARCHAR(100),
            ValorDocumentoIdentidad NVARCHAR(20),
            Puesto NVARCHAR(50),
            FechaContratacion DATE
        );

        INSERT INTO @Empleados (Nombre, ValorDocumentoIdentidad, Puesto, FechaContratacion)
        SELECT 
            E.value('@Nombre','NVARCHAR(100)'),
            E.value('@ValorDocumentoIdentidad','NVARCHAR(20)'),
            E.value('@Puesto','NVARCHAR(50)'),
            E.value('@FechaContratacion','DATE')
        FROM @XMLData.nodes('/Datos/Empleados/empleado') AS T(E);

        --------------------------------------
        -- Insertar empleados usando SP
        --------------------------------------
        DECLARE @i INT = 1;
        DECLARE @max INT = (SELECT MAX(RowNum) FROM @Empleados);
        DECLARE @Nombre NVARCHAR(100), @ValorDoc NVARCHAR(20), @Puesto NVARCHAR(50), @Fecha DATE, @IdPuesto INT;

        WHILE @i <= @max
        BEGIN
            SELECT 
                @Nombre = Nombre,
                @ValorDoc = ValorDocumentoIdentidad,
                @Puesto = Puesto,
                @Fecha = FechaContratacion
            FROM @Empleados
            WHERE RowNum = @i;

            -- Obtener IdPuesto a partir del nombre del puesto
            SELECT @IdPuesto = Id
            FROM Puesto
            WHERE Nombre = @Puesto;

            EXEC sp_insertar_empleado 
                @ValorDocumentoIdentidad=@ValorDoc,
                @Nombre=@Nombre,
                @IdPuesto=@IdPuesto,
                @PostByUser='scripts',
                @PostInIP='127.0.0.1',
                @FechaContratacion=@Fecha;

            SET @i = @i + 1;
        END

        --------------------------------------
        -- Preparar movimientos
        --------------------------------------
        DECLARE @Movimientos TABLE (
            RowNum INT IDENTITY(1,1) PRIMARY KEY,
            ValorDocId NVARCHAR(20),
            IdTipoMovimiento INT,
            Fecha DATETIME,
            Monto DECIMAL(18,2),
            PostByUser NVARCHAR(50),
            PostInIP NVARCHAR(50),
            PostTime DATETIME
        );

        INSERT INTO @Movimientos (ValorDocId, IdTipoMovimiento, Fecha, Monto, PostByUser, PostInIP, PostTime)
        SELECT
            M.value('@ValorDocId','NVARCHAR(20)'),
            M.value('@IdTipoMovimiento','INT'),
            M.value('@Fecha','DATETIME'),
            M.value('@Monto','DECIMAL(18,2)'),
            M.value('@PostByUser','NVARCHAR(50)'),
            M.value('@PostInIP','NVARCHAR(50)'),
            M.value('@PostTime','DATETIME')
        FROM @XMLData.nodes('/Datos/Movimientos/movimiento') AS T(M);

        --------------------------------------
        -- Insertar movimientos usando SP
        --------------------------------------
        SET @i = 1;
        SET @max = (SELECT MAX(RowNum) FROM @Movimientos);

        DECLARE @ValDocMov NVARCHAR(20), @IdTipoMov INT, @F DATETIME, @Monto DECIMAL(18,2), @PostBy NVARCHAR(50), @PostIP NVARCHAR(50), @PostT DATETIME;

        WHILE @i <= @max
        BEGIN
            SELECT 
                @ValDocMov = ValorDocId,
                @IdTipoMov = IdTipoMovimiento,
                @F = Fecha,
                @Monto = Monto,
                @PostBy = PostByUser,
                @PostIP = PostInIP,
                @PostT = PostTime
            FROM @Movimientos
            WHERE RowNum = @i;

            EXEC sp_insertar_movimiento 
                @ValorDocumentoIdentidad=@ValDocMov, 
                @IdTipoMovimiento=@IdTipoMov, 
                @Fecha=@F, 
                @Monto=@Monto, 
                @PostByUser=@PostBy, 
                @PostInIP=@PostIP, 
                @PostTime=@PostT;

            SET @i = @i + 1;
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error al cargar datos XML: %s',16,1,@ErrorMsg);
    END CATCH
END
