-- ================================================================
--  Ficha Seguimiento · Rehabilitación psicosocial de personas con trastornos del comportamiento debido al consumo de alcohol (F10.2 y F17.2)
--  Base: BDHIS_MINSA  |  Destino: dbo.ficha_REHABILITACION_ALCOHOL_csmc25
--  Período: 2025, meses 4-12
-- ================================================================

USE BDHIS_MINSA;
GO

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF OBJECT_ID('dbo.ficha_REHABILITACION_ALCOHOL_csmc25', 'U') IS NOT NULL
    DROP TABLE dbo.ficha_REHABILITACION_ALCOHOL_csmc25;

;WITH

-- 1) Atenciones del período + datos del paciente
Base AS (
    SELECT
        P.Numero_Documento_Paciente                         AS DNI,
        RTRIM(ISNULL(P.Apellido_Paterno_Paciente,'') + ' '
            + ISNULL(P.Apellido_Materno_Paciente,'') + ' '
            + ISNULL(P.Nombres_Paciente,''))                AS Apellidos_Nombres,
        h.Id_Establecimiento,
        h.Codigo_Item,
        h.Fecha_Atencion,
        h.Valor_Lab,
        h.Id_Correlativo_Item,
        h.Tipo_Diagnostico,
        h.Anio
    FROM       NOMINAL_TRAMA_NUEVO h
    INNER JOIN MAESTRO_PACIENTE    P ON h.Id_Paciente = P.Id_Paciente
    WHERE h.Anio = '2025' -- <== CAMBIAR EL AÑO AQUI
      --AND h.MES  BETWEEN 4 AND 12
),

-- 1b) Acogida: código 99205 buscado en 2024 y 2025
Acogida AS (
    SELECT
        P.Numero_Documento_Paciente                         AS DNI,
        MAX(h.Fecha_Atencion)                               AS Acogida
    FROM       NOMINAL_TRAMA_NUEVO h
    INNER JOIN MAESTRO_PACIENTE    P ON h.Id_Paciente = P.Id_Paciente
    WHERE h.Codigo_Item = '99205'
      AND h.Anio IN ('2024','2025','2026')
    GROUP BY P.Numero_Documento_Paciente
),

-- 2) Primer diagnóstico 'F102','F172' por paciente
Dx AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY DNI ORDER BY Fecha_Atencion) AS RankDx
    FROM   Base
    WHERE  Tipo_Diagnostico = 'D'
      AND  (Codigo_Item IN ('F102','F172'))
),

-- ================================================================
-- 2b) Pacientes que tienen al menos una atención con código Z502
-- ================================================================
ConZ502 AS (
    SELECT DISTINCT
        P.Numero_Documento_Paciente                         AS DNI
    FROM       NOMINAL_TRAMA_NUEVO h
    INNER JOIN MAESTRO_PACIENTE    P ON h.Id_Paciente = P.Id_Paciente
    WHERE h.Codigo_Item = 'Z502'
      AND h.Anio = '2025' -- <== CAMBIAR EL AÑO AQUI
),

-- 3) Resumen de actividades por paciente
Act AS (
    SELECT B.DNI,

        -- PAI
        MAX(CASE WHEN B.Codigo_Item = '99366'
                  AND B.Tipo_Diagnostico = 'D'
                  AND B.Id_Correlativo_Item = 3
                  AND B.Valor_Lab BETWEEN '1' AND '6'
                 THEN '1' ELSE '0' END)                     AS PAI,

        -- Psicoterapia grupal PSG (sesión 1-10)
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1'  THEN B.Fecha_Atencion END) AS Fec_PSG1,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '2'  THEN B.Fecha_Atencion END) AS Fec_PSG2,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '3'  THEN B.Fecha_Atencion END) AS Fec_PSG3,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '4'  THEN B.Fecha_Atencion END) AS Fec_PSG4,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '5'  THEN B.Fecha_Atencion END) AS Fec_PSG5,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '6'  THEN B.Fecha_Atencion END) AS Fec_PSG6,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '7'  THEN B.Fecha_Atencion END) AS Fec_PSG7,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '8'  THEN B.Fecha_Atencion END) AS Fec_PSG8,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '9'  THEN B.Fecha_Atencion END) AS Fec_PSG9,
        MAX(CASE WHEN B.Codigo_Item = '90857' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '10' THEN B.Fecha_Atencion END) AS Fec_PSG10,

        -- intervenciones familiares IF (sesión 1-2)
        MAX(CASE WHEN B.Codigo_Item IN ('C2111.01') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1' THEN B.Fecha_Atencion END) AS Fec_IF1,
        MAX(CASE WHEN B.Codigo_Item IN ('C2111.01') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '2' THEN B.Fecha_Atencion END) AS Fec_IF2

    FROM Base B
    INNER JOIN (SELECT DISTINCT DNI FROM Dx) F ON B.DNI = F.DNI
    GROUP BY B.DNI
)

-- ================================================================
SELECT
    D.Id_Establecimiento,
    D.DNI, D.Apellidos_Nombres,
    AC.Acogida,
    D.Codigo_Item AS Codigo_Dx, D.Fecha_Atencion AS Fecha_Dx, '1' AS Dx,
    A.PAI,
    A.Fec_PSG1,  A.Fec_PSG2,  A.Fec_PSG3,  A.Fec_PSG4,  A.Fec_PSG5,
    A.Fec_PSG6,  A.Fec_PSG7,  A.Fec_PSG8,  A.Fec_PSG9,  A.Fec_PSG10,
    A.Fec_IF1,   A.Fec_IF2

INTO  dbo.ficha_REHABILITACION_ALCOHOL_csmc25
FROM  Dx D
LEFT JOIN Act      A  ON D.DNI = A.DNI
LEFT JOIN Acogida  AC ON D.DNI = AC.DNI
-- ================================================================
-- FILTRO: solo pacientes que tienen al menos una atención con Z502
-- ================================================================
INNER JOIN ConZ502 Z  ON D.DNI = Z.DNI
WHERE D.RankDx = 1;

SELECT * FROM dbo.ficha_REHABILITACION_ALCOHOL_csmc25
ORDER BY Apellidos_Nombres ASC;