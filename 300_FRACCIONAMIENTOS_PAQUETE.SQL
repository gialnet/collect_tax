-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.(ROUND)
-- -----------------------------------------------------
CREATE OR REPLACE PACKAGE PKFraccionamientos
AS

TYPE Registro_valores IS RECORD(ID VALORES.ID%TYPE, FIN_PE_VOL VALORES.FIN_PE_VOL%TYPE,
					TIPO_DE_TRIBUTO VALORES.TIPO_DE_TRIBUTO%TYPE,
					PADRON VALORES.PADRON%TYPE,YEAR VALORES.YEAR%TYPE,
					PERIODO VALORES.PERIODO%TYPE,RECIBO VALORES.RECIBO%TYPE);

/******************************************************************************/
/* 	CURSOR: Cursor para recorrer los valores de un expediente, 			*/
/*		  buscando por ID y que este sin ingresar, sin dar de baja  	*/
/*		  ni suspendido.									*/
/*	Parametros Entrada:									*/
/*					xIDExpediente: INTEGER					*/
/*	Valor Devuelto:		Registros de la tabla VALORES				*/
/*					Registro_cursor						*/
/******************************************************************************/
/*BASE*/
CURSOR Valores_expediente(xIDExpediente IN INTEGER) RETURN Registro_valores;

/******************************************************************************/
/*	PROCEDIMIENTO: Añade un nuevo plazo Temporal					*/
/*	Parametros Entreda:									*/
/*					xVALOR: INTEGER						*/
/*					xF_PLAZO: DATE						*/
/*					xPRINCIPAL: FLOAT						*/
/*				      xRECARGO: FLOAT						*/
/*					xCOSTAS: FLOAT						*/
/*					xINTERESES: FLOAT						*/
/*					xPADRON: CHAR						*/
/*					xYEAR: CHAR							*/
/*					xPERIODO: CHAR						*/
/*					xRECIBO: INTEGER						*/
/******************************************************************************/
/*BASE*/
PROCEDURE Insertar_Plazo_Temp(xVALOR IN INTEGER,xF_PLAZO IN DATE,xPRINCIPAL IN FLOAT,
				      xRECARGO IN FLOAT,xCOSTAS IN FLOAT,xINTERESES IN FLOAT,
					xPADRON IN CHAR,xYEAR IN CHAR,xPERIODO IN CHAR,
					xRECIBO IN INTEGER);

/******************************************************************************/
/*	PROCEDIMIENTO: Actualiza los datos del fraccionamiento en el expediente */
/*			   segun el tipo de embargo						*/
/*	Parametros Entreda:									*/
/*					xIDExpediente: INTEGER					*/
/******************************************************************************/
/*BASE*/
PROCEDURE Actualiza_fraccionamiento(xIDExpediente IN INTEGER);

/******************************************************************************/
/* 	FUNTION: Calcula la fecha para el siguiente Plazo.				*/
/*	Parametros Entrada:									*/
/*					xFECHA: DATE						*/
/*					xPASOS: INTEGER						*/
/*	Valor Retorno:		El siguiente plazo, tipo DATE				*/
/******************************************************************************/
/*BASE*/
FUNCTION Next_plazo(xFECHA IN DATE,xPASOS IN INTEGER) RETURN DATE;

/******************************************************************************/
/* 	FUNCION	: Calcula el importe de un plazo para un Concepto		*/
/*			  dividido en xPlazos							*/
/*	Parametros Entrada:									*/
/*					xImporteTotal: FLOAT					*/
/*					xPlazos: INTEGER						*/
/*	Valor  Retorno:		El importe de un plazo, tipo FLOAT			*/
/******************************************************************************/
/*BASE*/
FUNCTION Calcula_importe_Plazo(xImporteTotal IN FLOAT,xPlazos IN INTEGER) RETURN FLOAT;

/******************************************************************************/
/* 	FUNCION	: Calcula el importe de un fraccionamiento			*/
/*	SOBRECARGA  : Si se le indica fecha calcula el importe del primer plazo	*/
/*	Parametros Entrada:									*/
/*					xIDFraccionamiento: INTEGER				*/
/*				      xFecha: DATE
/*	Valor  Retorno:		El importe de un fraccionamiento, tipo FLOAT	*/
/******************************************************************************/
/*BASE*/
FUNCTION Calcula_importe_fracc(xIDFracc IN INTEGER) RETURN FLOAT;
FUNCTION Calcula_importe_fracc(xIDFracc IN INTEGER,xFecha IN DATE) RETURN FLOAT;


END PKFraccionamientos;
/

CREATE OR REPLACE PACKAGE BODY PKFraccionamientos 
AS

CURSOR Valores_expediente(xIDExpediente INTEGER) RETURN Registro_valores
IS
SELECT ID,FIN_PE_VOL,TIPO_DE_TRIBUTO,PADRON,YEAR,PERIODO,RECIBO
FROM VALORESEXPE 
WHERE EXPEDIENTE=xIDExpediente 
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NULL
	AND PENDIENTE>0;


-- Modificado: 24/07/2003. Lucas Fernández Pérez. Antes llamaba a los procedimientos de 
--	levantamiento sin mirar ningún estado. Se restringe la llamada a que el estado sea
--	de abierto ('O').
-- 
PROCEDURE Actualiza_fraccionamiento(xIDExpediente IN INTEGER)
AS
 xEmbargo CHAR(1);
 xEsta_Embargo CHAR(1);
BEGIN

   SELECT Embargo, Esta_Embargo
   INTO   xEmbargo, xEsta_Embargo 
   FROM   Expedientes
   WHERE  ID=xIDExpediente;

   -- 1 => cuentas corrientes 
   IF xEmbargo='1' and xEsta_Embargo='O' THEN
     ADD_CUENTAS_A_LEVANTAR(xIDExpediente);
     QUITO_EXPE_LOTE(xIDExpediente);
   END IF;
 
   -- 3 => Salarios 
   IF xEmbargo='3' and xEsta_Embargo='O' THEN
     LEVANTA_SALARIOS(xIDExpediente);
   END IF;
 
   -- 4 =>Inmuebles 
   IF xEmbargo='4' and xEsta_Embargo='O' THEN
     LEVANTA_INMUEBLES(xIDExpediente);
   END IF;

   -- 8 =>Vehiculos 
   IF xEmbargo='8' and xEsta_Embargo='O' THEN
     LEVANTA_VEHICULOS(xIDExpediente);
   END IF;

END Actualiza_fraccionamiento;


PROCEDURE Insertar_Plazo_Temp(xVALOR IN INTEGER,xF_PLAZO IN DATE,xPRINCIPAL IN FLOAT,
				      xRECARGO IN FLOAT,xCOSTAS IN FLOAT,xINTERESES IN FLOAT,
					xPADRON IN CHAR,xYEAR IN CHAR,xPERIODO IN CHAR,
					xRECIBO IN INTEGER)
AS
xUID Integer;
BEGIN

   SELECT UID INTO xUID FROM DUAL;

   INSERT INTO TEMP_PLAZOS
	(USUARIO,VALOR,FECHA, PRINCIPAL, 
      RECARGO, COSTAS,DEMORA,
      PADRON,YEAR,PERIODO,RECIBO)
   VALUES 
      (xUID,xVALOR,xF_PLAZO, ROUND(xPRINCIPAL,2),
      ROUND(xRECARGO,2), ROUND(xCOSTAS,2),ROUND(xINTERESES,2),
      xPADRON,xYEAR,xPERIODO,xRECIBO);

END Insertar_Plazo_Temp;

FUNCTION Next_plazo(xFECHA IN DATE,xPASOS IN INTEGER) RETURN DATE
IS

	xMES   INTEGER;
	xYEAR  INTEGER;
	xFECHA_CADENA  CHAR(20);
	xNEXT_PLAZO DATE;

BEGIN

  xMES:=MONTH(xFECHA);
  xYEAR:=F_YEAR(xFECHA);
  xMES:=xMES+xPASOS;

  IF xMES > 12 THEN
     xYEAR:=xYEAR+1;
     xMES:=xMES-12;
  END IF;

  xFECHA_CADENA:=DAYOFMONTH(xFECHA) || '/' || xMES || '/' || xYEAR || ' 00:00:00';
  xNEXT_PLAZO:=TO_DATE(xFECHA_CADENA, 'DD/MM/YYYY HH24:MI:SS');

  RETURN xNEXT_PLAZO;

END Next_plazo;


FUNCTION Calcula_importe_plazo(xImporteTotal IN FLOAT,xPlazos IN INTEGER) RETURN FLOAT
AS
BEGIN
   IF xImporteTotal > 0 
   THEN Return xImporteTotal/xPlazos;
   ELSE Return xImporteTotal;
   END IF;
END Calcula_importe_plazo;

FUNCTION Calcula_importe_fracc(xIDFracc IN INTEGER) RETURN FLOAT
AS
 xTotal_fracc FLOAT DEFAULT 0;
BEGIN

   SELECT sum(PRINCIPAL+RECARGO+COSTAS+DEMORA) 
   INTO   xTotal_fracc
   FROM   PLAZOS_FRAC 
   WHERE  FRACCIONA=xIDFracc;

   RETURN xTotal_fracc;

END Calcula_importe_fracc;


FUNCTION Calcula_importe_fracc(xIDFracc IN INTEGER,xFecha IN DATE) RETURN FLOAT
AS
 xTotal_plazo FLOAT DEFAULT 0;
BEGIN

   SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA)
   INTO   xTotal_plazo
   FROM   PLAZOS_FRAC 
   WHERE  FRACCIONA=xIDFracc AND FECHA=xFecha;

   RETURN xTotal_plazo;

END Calcula_importe_fracc;

END;
/