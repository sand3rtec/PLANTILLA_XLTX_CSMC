-- ================================================================
--  Ficha Seguimiento · Rehabilitación laboral
--  Base: BDHIS_MINSA  |  Destino: dbo.ficha_REHAB_LABORAL_csmc25
--  Período: 2025
-- ================================================================

USE BDHIS_MINSA;
GO

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF OBJECT_ID('dbo.ficha_REHAB_LABORAL_csmc25', 'U') IS NOT NULL
    DROP TABLE dbo.ficha_REHAB_LABORAL_csmc25;

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
    WHERE h.Anio = '2025' --<== CAMBIAR EL AÑO AQUI
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

-- 2) Primer diagnóstico por paciente
Dx AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY DNI ORDER BY Fecha_Atencion) AS RankDx
    FROM   Base
    WHERE  Tipo_Diagnostico = 'D'
      AND  (Codigo_Item BETWEEN 'F20' AND 'F29' OR Codigo_Item IN ('F312','F315','F323','F333','F062','F105','F115','F125','F135','F145','F155','F165','F175','F185','F195'))
),

-- ================================================================
-- 2b) Pacientes que tienen AL MENOS UNA atención con código 97537.01
-- ================================================================
Con97537 AS (
    SELECT DISTINCT DNI
    FROM   Base
    WHERE  Codigo_Item = '97537.01'
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

        -- Rehabilitación laboral RLA (sesiones 1-10)
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1'          THEN B.Fecha_Atencion END) AS Fec_RLA1,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '2'          THEN B.Fecha_Atencion END) AS Fec_RLA2,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '3'          THEN B.Fecha_Atencion END) AS Fec_RLA3,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '4'          THEN B.Fecha_Atencion END) AS Fec_RLA4,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '5'          THEN B.Fecha_Atencion END) AS Fec_RLA5,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '6'          THEN B.Fecha_Atencion END) AS Fec_RLA6,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '7'          THEN B.Fecha_Atencion END) AS Fec_RLA7,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '8'          THEN B.Fecha_Atencion END) AS Fec_RLA8,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '9'          THEN B.Fecha_Atencion END) AS Fec_RLA9,
        MAX(CASE WHEN B.Codigo_Item = '97537.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab IN ('TA','10') THEN B.Fecha_Atencion END) AS Fec_RLA10

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
    A.Fec_RLA1,  A.Fec_RLA2,  A.Fec_RLA3,  A.Fec_RLA4,  A.Fec_RLA5,
    A.Fec_RLA6,  A.Fec_RLA7,  A.Fec_RLA8,  A.Fec_RLA9,  A.Fec_RLA10

INTO  dbo.ficha_REHAB_LABORAL_csmc25
FROM  Dx D
LEFT JOIN Act      A   ON D.DNI = A.DNI
LEFT JOIN Acogida  AC  ON D.DNI = AC.DNI
-- ================================================================
-- FILTRO: solo pasan pacientes con al menos una atención 97537.01
-- los campos RLA que no tengan fecha quedarán en NULL normalmente
-- ================================================================
INNER JOIN Con97537 C  ON D.DNI = C.DNI
WHERE D.RankDx = 1;

SELECT * FROM dbo.ficha_REHAB_LABORAL_csmc25
ORDER BY Apellidos_Nombres ASC;