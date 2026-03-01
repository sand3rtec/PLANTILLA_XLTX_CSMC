-- Personal de salud APP 100 - ACOMPAÑAMIENTO CLINICO PSICOSOCIAL
-- ================================================================
USE BDHIS_MINSA;
GO
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- ================================================================
DECLARE @Anio CHAR(4) = '2025';  -- <== CAMBIAR EL AÑO AQUI
-- ================================================================
WITH
-- 1. Base de asistencias técnicas para APP100
base_sesiones AS (
    SELECT
        n.Id_Cita,
        n.Id_Paciente,
        n.Fecha_Atencion,
        n.Id_Personal
    FROM dbo.T_CONSOLIDADO_NUEVA_TRAMA_HISMINSA n
    WHERE n.Id_Paciente         = 'APP100'
      AND n.Codigo_Item         = 'C7004'
      AND n.Id_Correlativo_Item = 1
      AND n.Tipo_Diagnostico    = 'D'
      AND n.Anio                = @Anio
),

-- 2. Renumeración secuencial de sesiones
--    EXCLUIR citas que ya tengan C7002 con Id_Correlativo_Item = 5
sesiones_filtradas AS (
    SELECT
        bs.Id_Cita,
        bs.Id_Paciente,
        bs.Fecha_Atencion,
        bs.Id_Personal,
        ROW_NUMBER() OVER (
            ORDER BY bs.Fecha_Atencion
        )                                    AS Num_Sesion
    FROM base_sesiones bs
    WHERE NOT EXISTS (                       -- <== EXCLUIR SI TIENE CORRELATIVO 5
        SELECT 1
        FROM dbo.NOMINAL_TRAMA_NUEVO x
        WHERE x.Id_Cita         = bs.Id_Cita
          AND x.Codigo_Item     = 'C7002'
          AND x.Id_Correlativo_Item = 5
          AND x.Tipo_Diagnostico = 'D'
          AND x.Anio            = @Anio
    )
),

-- 3. Número de sesión
num_sesion AS (
    SELECT
        Id_Cita,
        CAST(Valor_Lab AS TINYINT)           AS Sesion
    FROM dbo.NOMINAL_TRAMA_NUEVO
    WHERE Codigo_Item         = 'C7004'
      AND Id_Correlativo_Item = 2
      AND Tipo_Diagnostico    = 'D'
      AND Anio                = @Anio
),

-- 4. Número de personal de salud
personal_salud AS (
    SELECT
        Id_Cita,
        CAST(Valor_Lab AS INT)               AS Num_Personal
    FROM dbo.NOMINAL_TRAMA_NUEVO
    WHERE Codigo_Item         = 'C7004'
      AND Id_Correlativo_Item = 3
      AND Tipo_Diagnostico    = 'D'
      AND Anio                = @Anio
),

-- 5. Supervisión C7002
supervision AS (
    SELECT
        Id_Cita,
        CASE CAST(Valor_Lab AS TINYINT)
            WHEN 1 THEN 'Médico psiquiatra'
            WHEN 2 THEN 'Psicólogo(a)'
            WHEN 3 THEN 'Enfermero(a)'
            WHEN 4 THEN 'Trabajador(a) social'
            WHEN 5 THEN 'Médico de familia'
            WHEN 6 THEN 'Otros'
            ELSE        'No registrado'
        END                                  AS Desc_Profesional
    FROM dbo.NOMINAL_TRAMA_NUEVO
    WHERE Codigo_Item         = 'C7002'
      AND Id_Correlativo_Item = 4
      AND Tipo_Diagnostico    = 'D'
      AND Anio                = @Anio
)

-- ================================================================
-- REPORTE VERTICAL
-- ================================================================
SELECT
    s.Id_Paciente,
    s.Fecha_Atencion                                     AS Sesion_Fecha,
    ISNULL(ns.Sesion,           0)                       AS ACP_Num,
    ISNULL(ps.Num_Personal,     0)                       AS Sesion_Personal,
    ISNULL(sv.Desc_Profesional, 'No registrado')         AS Sesion_Profesional,
    RTRIM(
        ISNULL(mp.Apellido_Paterno_Personal, '') + ' ' +
        ISNULL(mp.Apellido_Materno_Personal, '') + ' ' +
        ISNULL(mp.Nombres_Personal,          '')
    )                                                    AS Nombre_Profesional
FROM       sesiones_filtradas  s
LEFT JOIN  dbo.MAESTRO_PERSONAL mp ON mp.Id_Personal = s.Id_Personal
LEFT JOIN  num_sesion           ns ON ns.Id_Cita      = s.Id_Cita
LEFT JOIN  personal_salud       ps ON ps.Id_Cita      = s.Id_Cita
LEFT JOIN  supervision          sv ON sv.Id_Cita      = s.Id_Cita
ORDER BY
    s.Fecha_Atencion           ASC,
    ISNULL(ps.Num_Personal, 0) ASC;