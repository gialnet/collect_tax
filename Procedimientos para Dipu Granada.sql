
-- ************************************************************ --
-- Comprobaciones previas a las datas para buscar incoherencias --
-- ************************************************************ --
CREATE OR REPLACE PROCEDURE DATAS_CHK_ZONA(
		xFDESDE IN DATE,
		xFHASTA IN DATE)
AS

xZONA CHAR(2);

BEGIN


SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

-- BORRAR TODOS LOS DATOS

DELETE FROM TMP_CHK_DATA WHERE ZONA=xZONA;


--
-- Comprobar que no haya ingresos sin asignar a partes del d�a
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
	SELECT xZONA,V.ID,NIF,NOMBRE,'SIN PARTE DEL D�A','01' 
	FROM INGRESOS I, VALORES V
	WHERE V.ID=I.VALOR
		AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA 
		AND PARTE_DEL_DIA IS NULL 
		AND ZONA=xZONA
		AND F_COBRO_BANCO IS NULL
		AND TIPO_INGRESO IN ('VE','FE','FV','EE','ER','EF','F1','F2');

--
-- Fecha de notificacion anterior a la fecha de providencia de apremio
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT xZONA,V.ID,NIF,NOMBRE,'NOTIFICADO ANTES DE LA PROVIDENCIA DE APREMIO','02' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND ZONA=xZONA
	AND NOTIFICADO='S' 
	AND V.F_NOTIFICACION < V.F_APREMIO;


--
-- Sin notificar con recargo del 20%
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT xZONA,V.ID,NIF,NOMBRE,'SIN NOTIFICAR CON 20% DE RECARGO','03' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND ZONA=xZONA
	AND NOTIFICADO='N' 
	AND V.RECARGO > ROUND((V.PRINCIPAL*10/100), 2);

--
-- Sin notificar con intereses de demora
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT xZONA,V.ID,NIF,NOMBRE,'SIN NOTIFICAR CON INTERESES COBRADOS','04' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND ZONA=xZONA
	AND NOTIFICADO='N' 
	AND I.DEMORA > 0;

--
-- Notificados con el 10% y con intereses de demora
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT xZONA,V.ID,NIF,NOMBRE,'NOTIFICADOS CON EL 10% DE RECARGO Y CON INTERESES COBRADOS','05' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND ZONA=xZONA
	AND NOTIFICADO='S' 
	AND V.RECARGO < ROUND((V.PRINCIPAL*20/100), 2)
	AND I.DEMORA > 0;
--
-- Sin intereses de demora y notificados
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT xZONA,V.ID,NIF,NOMBRE,'COBRADOS SIN INTERESES DE DEMORA','06' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND ZONA=xZONA
	AND NOTIFICADO='S' 
	AND V.F_INGRESO IS NOT NULL
	AND PLAZO_APREMIO(V.F_INGRESO, V.F_NOTIFICACION) > 0
	AND V.DEMORA = 0;


END;
/


-- ************************************************************ --
-- Comprobaciones previas a las datas para buscar incoherencias --
-- ************************************************************ --
CREATE OR REPLACE PROCEDURE DATAS_CHK_TODO(
		xFDESDE IN DATE,
		xFHASTA IN DATE)
AS
BEGIN


-- BORRAR TODOS LOS DATOS

DELETE FROM TMP_CHK_DATA;


--
-- Comprobar que no haya ingresos sin asignar a partes del d�a
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
	SELECT I.ZONA,V.ID,NIF,NOMBRE,'SIN PARTE DEL D�A','01' 
	FROM INGRESOS I, VALORES V
	WHERE V.ID=I.VALOR
		AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA 
		AND PARTE_DEL_DIA IS NULL 
		AND F_COBRO_BANCO IS NULL
		AND TIPO_INGRESO IN ('VE','FE','FV','EE','ER','EF','F1','F2');

--
-- Fecha de notificacion anterior a la fecha de providencia de apremio
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT I.ZONA,V.ID,NIF,NOMBRE,'NOTIFICADO ANTES DE LA PROVIDENCIA DE APREMIO','02' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND NOTIFICADO='S' 
	AND V.F_NOTIFICACION < V.F_APREMIO;

--
-- Sin notificar con recargo del 20%
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT I.ZONA,V.ID,NIF,NOMBRE,'SIN NOTIFICAR CON 20% DE RECARGO','03' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND NOTIFICADO='N' 
	AND V.RECARGO > ROUND((V.PRINCIPAL*10/100), 2);

--
-- Sin notificar con intereses de demora
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT I.ZONA,V.ID,NIF,NOMBRE,'SIN NOTIFICAR CON INTERESES COBRADOS','04' 
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND NOTIFICADO='N' 
	AND I.DEMORA > 0;


--
-- Notificados con el 10% y con intereses de demora
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT I.ZONA,V.ID,NIF,NOMBRE,'NOTIFICADOS CON EL 10% DE RECARGO Y CON INTERESES COBRADOS','05'
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND NOTIFICADO='S' 
	AND V.RECARGO < ROUND((V.PRINCIPAL*20/100), 2)
	AND I.DEMORA > 0;
--
-- Sin intereses de demora y notificados
--
INSERT INTO TMP_CHK_DATA (ZONA,VALOR,NIF,NOMBRE,ERROR,COD_ERROR)
SELECT I.ZONA,V.ID,NIF,NOMBRE,'COBRADOS SIN INTERESES DE DEMORA','06'
	FROM VALORES V, INGRESOS I
	WHERE V.ID=I.VALOR
	AND TRUNC(FECHA,'DD') BETWEEN xFDESDE AND xFHASTA
	AND NOTIFICADO='S' 
	AND V.F_INGRESO IS NOT NULL
	AND PLAZO_APREMIO(V.F_INGRESO, V.F_NOTIFICACION) > 0
	AND V.DEMORA = 0;


END;
/



CREATE TABLE TMP_CHK_DATA(
	USUARIO 	CHAR(30) DEFAULT USER,
	ZONA		CHAR(2),
	VALOR		INTEGER,
	NIF		CHAR(10),
	NOMBRE	VARCHAR2(40),
	COD_ERROR   CHAR(2),
	ERROR		VARCHAR2(150)
);