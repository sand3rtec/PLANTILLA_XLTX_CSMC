-- ================================================================
--  Ficha Seguimiento · Cuidados de salud domiciliarios a personas
--  con DEMENCIA SEVERA y en precarias condiciones económicas
--  Código de ficha: 0070620
--  Dx: F00-F09, F01-F01.9, F02-F02.8 (Definitivo)
--  Actividad clave: 99374 (Supervisión médica del cuidado en casa)
--                   1° lab = 10
--  Base: BDHIS_MINSA  |  Destino: dbo.ficha_DEMENCIA_SEVERA_csmc25
--  Período: 2025
-- ================================================================

USE BDHIS_MINSA;
GO

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF OBJECT_ID('dbo.ficha_CUIDADOS_DOMICILIARIOS_csmc25','U') IS NOT NULL
    DROP TABLE dbo.ficha_CUIDADOS_DOMICILIARIOS_csmc25;

;WITH

-- ================================================================
-- 1) Base general del período
-- ================================================================
Base AS (
    SELECT
        P.Numero_Documento_Paciente                             AS DNI,
        RTRIM(ISNULL(P.Apellido_Paterno_Paciente,'') + ' '
            + ISNULL(P.Apellido_Materno_Paciente,'') + ' '
            + ISNULL(P.Nombres_Paciente,''))                    AS Apellidos_Nombres,
        h.Id_Establecimiento,
        h.Codigo_Item,
        h.Fecha_Atencion,
        h.Valor_Lab,
        h.Id_Correlativo_Item,
        h.Tipo_Diagnostico
    FROM       NOMINAL_TRAMA_NUEVO h
    INNER JOIN MAESTRO_PACIENTE    P ON h.Id_Paciente = P.Id_Paciente
    WHERE h.Anio = '2025'
),

-- ================================================================
-- 1b) Acogida (99205) en 2024-2026
-- ================================================================
Acogida AS (
    SELECT
        P.Numero_Documento_Paciente  AS DNI,
        MAX(h.Fecha_Atencion)        AS Acogida
    FROM       NOMINAL_TRAMA_NUEVO h
    INNER JOIN MAESTRO_PACIENTE    P ON h.Id_Paciente = P.Id_Paciente
    WHERE h.Codigo_Item = '99205'
      AND h.Anio IN ('2024','2025','2026')
    GROUP BY P.Numero_Documento_Paciente
),

-- ================================================================
-- 2) Primer Dx de DEMENCIA (F00-F09, Definitivo)
-- ================================================================
Dx AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY DNI ORDER BY Fecha_Atencion) AS RankDx
    FROM   Base
    WHERE  Tipo_Diagnostico = 'D'
      AND  Codigo_Item LIKE 'F0[0-9]%'
),

-- ================================================================
-- 3a) PAI por paciente
-- ================================================================
PAI AS (
    SELECT DNI,
           MAX(CASE WHEN Id_Correlativo_Item = 3
                     AND Valor_Lab BETWEEN '1' AND '6'
                    THEN '1' ELSE '0' END)                      AS PAI
    FROM   Base
    WHERE  Codigo_Item      = '99366'
      AND  Tipo_Diagnostico = 'D'
      AND  DNI IN (SELECT DISTINCT DNI FROM Dx)
    GROUP BY DNI
),

-- ================================================================
-- 3b) Supervisión médica 99374 pre-filtrada → 10 sesiones
-- ================================================================
SM AS (
    SELECT DNI,
           MAX(CASE WHEN Valor_Lab = '1'  THEN Fecha_Atencion END) AS Fec_SM1,
           MAX(CASE WHEN Valor_Lab = '2'  THEN Fecha_Atencion END) AS Fec_SM2,
           MAX(CASE WHEN Valor_Lab = '3'  THEN Fecha_Atencion END) AS Fec_SM3,
           MAX(CASE WHEN Valor_Lab = '4'  THEN Fecha_Atencion END) AS Fec_SM4,
           MAX(CASE WHEN Valor_Lab = '5'  THEN Fecha_Atencion END) AS Fec_SM5,
           MAX(CASE WHEN Valor_Lab = '6'  THEN Fecha_Atencion END) AS Fec_SM6,
           MAX(CASE WHEN Valor_Lab = '7'  THEN Fecha_Atencion END) AS Fec_SM7,
           MAX(CASE WHEN Valor_Lab = '8'  THEN Fecha_Atencion END) AS Fec_SM8,
           MAX(CASE WHEN Valor_Lab = '9'  THEN Fecha_Atencion END) AS Fec_SM9,
           MAX(CASE WHEN Valor_Lab = '10' THEN Fecha_Atencion END) AS Fec_SM10
    FROM   Base
    WHERE  Codigo_Item        = '99374'
      AND  Tipo_Diagnostico   = 'D'
      AND  Id_Correlativo_Item IN (2,3,4,5,6)
      AND  Valor_Lab          IN ('1','2','3','4','5','6','7','8','9','10')
      AND  DNI IN (SELECT DISTINCT DNI FROM Dx)
    GROUP BY DNI
)

-- ================================================================
-- 4) Resultado final → SOLO pacientes con al menos Fec_SM1
-- ================================================================
SELECT
    D.Id_Establecimiento,
    D.DNI,
    D.Apellidos_Nombres,
    AC.Acogida,
    D.Codigo_Item       AS Codigo_Dx,
    D.Fecha_Atencion    AS Fecha_Dx,
    '1'                 AS Dx,
    ISNULL(P.PAI,'0')   AS PAI,
    S.Fec_SM1,  S.Fec_SM2,  S.Fec_SM3,  S.Fec_SM4,  S.Fec_SM5,
    S.Fec_SM6,  S.Fec_SM7,  S.Fec_SM8,  S.Fec_SM9,  S.Fec_SM10

INTO dbo.ficha_CUIDADOS_DOMICILIARIOS_csmc25
FROM       Dx      D
INNER JOIN SM      S  ON D.DNI = S.DNI    -- INNER: solo los que tienen sesiones
LEFT JOIN  PAI     P  ON D.DNI = P.DNI
LEFT JOIN  Acogida AC ON D.DNI = AC.DNI
WHERE D.RankDx  = 1
  AND S.Fec_SM1 IS NOT NULL;              -- mínimo: primera sesión registrada

-- Verificación
SELECT * FROM dbo.ficha_CUIDADOS_DOMICILIARIOS_csmc25
ORDER BY Apellidos_Nombres;