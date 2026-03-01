-- ================================================================
--  Ficha Seguimiento · Tratamiento ambulatorio para las personas con deterioro_cognitivo (F00 al F09)
--  Base: BDHIS_MINSA  |  Destino: dbo.ficha_deterioro_cognitivo_csmc25
--  Período: 2025
-- ================================================================

USE BDHIS_MINSA;
GO

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF OBJECT_ID('dbo.ficha_deterioro_cognitivo_csmc25', 'U') IS NOT NULL
    DROP TABLE dbo.ficha_deterioro_cognitivo_csmc25;

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
    WHERE h.Anio IN ('2025') -- <== CAMBIAR EL AÑO AQUI
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

-- 2) Primer diagnóstico F20 al F29, F31.2, F31.5, F32.3, F33.3, F06.2, F10.5, F11.5, F12.5, F13.5, F14.5, F15.5, F16.5, F17.5, F18.5 Y F19.5 por paciente
Dx AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY DNI ORDER BY Fecha_Atencion) AS RankDx
    FROM   Base
    WHERE  Tipo_Diagnostico = 'D'
      AND  (Codigo_Item BETWEEN 'F00'AND'F09')
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

        -- Consulta Médica CS (sesiones 1-4)
        MAX(CASE WHEN B.Codigo_Item = '99215' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1' THEN B.Fecha_Atencion END) AS Fec_CS1,
        MAX(CASE WHEN B.Codigo_Item = '99215' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '2' THEN B.Fecha_Atencion END) AS Fec_CS2,
        MAX(CASE WHEN B.Codigo_Item = '99215' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '3' THEN B.Fecha_Atencion END) AS Fec_CS3,
		MAX(CASE WHEN B.Codigo_Item = '99215' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '4' THEN B.Fecha_Atencion END) AS Fec_CS4,
		       
        -- terapia de rehabilitación cognitiva RC (sesiones 1-6)
        MAX(CASE WHEN B.Codigo_Item IN ('96100.05') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1' THEN B.Fecha_Atencion END) AS Fec_RC1,
        MAX(CASE WHEN B.Codigo_Item IN ('96100.05') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '2' THEN B.Fecha_Atencion END) AS Fec_RC2,
        MAX(CASE WHEN B.Codigo_Item IN ('96100.05') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '3' THEN B.Fecha_Atencion END) AS Fec_RC3,
        MAX(CASE WHEN B.Codigo_Item IN ('96100.05') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '4' THEN B.Fecha_Atencion END) AS Fec_RC4,
        MAX(CASE WHEN B.Codigo_Item IN ('96100.05') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '5' THEN B.Fecha_Atencion END) AS Fec_RC5,
        MAX(CASE WHEN B.Codigo_Item IN ('96100.05') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '6' THEN B.Fecha_Atencion END) AS Fec_RC6,

		 -- Psicoeducación a la familia y cuidadores IF (sesión 1-2)
        MAX(CASE WHEN B.Codigo_Item = 'C2111.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1' THEN B.Fecha_Atencion END) AS Fec_IF1,
		MAX(CASE WHEN B.Codigo_Item = 'C2111.01' AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '2' THEN B.Fecha_Atencion END) AS Fec_IF2,

		 -- Otras terapias físicas (Z501) o 04 Terapia ocupacional grupal OCU (sesión 1)
        MAX(CASE WHEN B.Codigo_Item IN ('97535.01','Z501') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1' THEN B.Fecha_Atencion END) AS Fec_OCU1,
		MAX(CASE WHEN B.Codigo_Item IN ('97535.01','Z501') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '2' THEN B.Fecha_Atencion END) AS Fec_OCU2,
		MAX(CASE WHEN B.Codigo_Item IN ('97535.01','Z501') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '3' THEN B.Fecha_Atencion END) AS Fec_OCU3,
		MAX(CASE WHEN B.Codigo_Item IN ('97535.01','Z501') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '4' THEN B.Fecha_Atencion END) AS Fec_OCU4

		-- Visita domiciliaria ó 01 movilización de redes de apoyo VI (sesión 1)
       --MAX(CASE WHEN B.Codigo_Item IN ('C0011','C1043') AND B.Tipo_Diagnostico = 'D' AND B.Id_Correlativo_Item IN (2,3,4,5,6) AND B.Valor_Lab = '1' THEN B.Fecha_Atencion END) AS Fec_VI1

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
    A.Fec_CS1, A.Fec_CS2,A.Fec_CS3, A.Fec_CS4,
    A.Fec_RC1, A.Fec_RC2, A.Fec_RC3, A.Fec_RC4, A.Fec_RC5, A.Fec_RC6,
	A.Fec_IF1,A.Fec_IF2,
	A.Fec_OCU1, A.Fec_OCU2,A.Fec_OCU3, A.Fec_OCU4
	

INTO  dbo.ficha_deterioro_cognitivo_csmc25
FROM  Dx D
LEFT JOIN Act     A  ON D.DNI = A.DNI
LEFT JOIN Acogida AC ON D.DNI = AC.DNI
WHERE D.RankDx = 1;

SELECT * FROM dbo.ficha_deterioro_cognitivo_csmc25
ORDER BY Apellidos_Nombres ASC;