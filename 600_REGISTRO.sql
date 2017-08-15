-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fern�ndez P�rez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/*******************************************************************************************
MODIFICACI�N: 05/10/2001 M. Carmen Junco G�mez. Contador por departamento.
MODIFICACI�N: 22/01/2002 Antonio P�rez Caballero. reforma general
*******************************************************************************************/
--
-- Se utiliza para pasar a un fichero temporal los registros que vamos a imprimir
-- para no tener que imprimir todas las p�ginas del registro de una vez o para poder
-- reimprimir un conjunto de p�ginas.
--
-- xDesde es la p�gina a partir de donde debe comenzar la impresi�n
-- xHasta es la p�gina en la cual finalizar� la impresi�n
-- xTipo ser� E para entrada y S para salida
-- xFormato ser� A4 o A3
--
create or replace procedure libro_registro(
	xTIPO 	IN		CHAR,
	xYEAR 	IN		CHAR,
	xDESDE 	IN		INTEGER,
	xHASTA 	IN		INTEGER,
	xFORMATO	IN		CHAR)
AS

COD_ORIGEN		VARCHAR2(50);
COD_DESTINO		VARCHAR2(50);
I		INTEGER;
D		INTEGER;
H		INTEGER;
P		INTEGER;

-- Filas o registros por p�gina
F		INTEGER;

xNUMERO		CHAR(12);
xPAGINA		INTEGER;


CURSOR cLibroReg IS
 	SELECT NUMERO_DE_REGISTRO,NUM_REGISTRO_DEPAR,FECHA_DE_REGISTRO,FECHA_DOCUMENTO,
	       EXTRACTO,DESTINO,ORIGEN,CODIGO_DESTINO,CODIGO_ORIGEN
	FROM LIBRO_DE_REGISTRO 
	WHERE TIPO_DE_DOCUMENTO=xTIPO 
	AND YEAR=xYEAR
    ORDER BY NUMERO_DE_REGISTRO;

BEGIN

IF (xFORMATO='A4') THEN
   F:=10; -- 10 tuplas en A4
ELSE
   F:=15; -- 15 en A3
END IF;

-- L�neas por p�gina
P:=0;
-- Tuplas leidas
I:=0;

xPAGINA:=xDESDE;

-- primera fila de la p�gina
if xDESDE = 1 then
   D:=0;
else
   D:=(xDESDE-1) * F;
end if;

-- �ltima fila de la p�gina
H:=xHASTA * F;


-- SE BORRA TODO LO QUE TENGA LA TABLA AUXILIAR 
DELETE FROM TABLA_AUX_LIBRO_REGISTRO;

FOR v_cLibroReg IN cLibroReg LOOP 


     xNumero:=SUBSTR(v_cLibroReg.NUMERO_DE_REGISTRO,6,7)||'/'||SUBSTR(v_cLibroReg.NUMERO_DE_REGISTRO,1,4);

     I:=I+1;

	-- Si la fila est� en el intervalo de las p�ginas seleccionadas
     IF (I > D) AND (I <= H) THEN

		 P:=P+1;

		 -- Salto de p�gina, aumentar el contador de p�ginas
		 IF (P=F+1) THEN
               	xPAGINA:=xPAGINA+1;
			P:=1;
		 END IF;

		 select nombre INTO COD_DESTINO from departamento 
			where departamento=v_cLibroReg.CODIGO_DESTINO;

 		 select nombre_EMISOR INTO COD_ORIGEN from CARACTER_DOCUMENTO 
			where EMISOR=v_cLibroReg.CODIGO_ORIGEN;
		
             INSERT INTO TABLA_AUX_LIBRO_REGISTRO 
               (NUMERO,NUMERO_DEPAR,F_DOCUMENTO,F_REGISTRO,COD_ORIGEN,
		    COD_DESTINO,ORIGEN,DESTINO,EXTRACTO,PAGINA)
		 VALUES
               (xNUMERO,v_cLibroReg.NUM_REGISTRO_DEPAR,v_cLibroReg.FECHA_DOCUMENTO,
			v_cLibroReg.FECHA_DE_REGISTRO, COD_ORIGEN, COD_DESTINO,
			v_cLibroReg.ORIGEN,v_cLibroReg.DESTINO,v_cLibroReg.EXTRACTO, xPAGINA);
     END IF;

     -- Si se ha llegado al final de la �ltima p�gina a imprimir salirnos
     IF (I > H) THEN 
	  EXIT;
     END IF;

END LOOP;


END;
/


/*******************************************************************************************
MODIFICACI�N: 05/10/2001 M. Carmen Junco G�mez. Contador por departamento.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE TABLA_REGISTRO (xID INTEGER,xMUNI CHAR)
AS
  ID				INTEGER;
  TIPO_DOCUMENTO		CHAR(1);
  N_DE_REGISTRO		CHAR(12);
  NUMERO_DEPAR		CHAR(12);
  YEAR			CHAR(4);
  FECHA_REGIS		DATE;
  FECHA_DOC			DATE;
  POBLACION			CHAR(30);
  DESTINO			CHAR(50);
  ORIGEN			CHAR(50);
  IMPRESO			CHAR(1);
  RESOLUCION		CHAR(20);
  DEPART			CHAR(50);
  CARACTER_DOCU		CHAR(50);
  PERIODO			CHAR(7);

CURSOR C_TABLA_REG IS
     SELECT L.ID, L.TIPO_DE_DOCUMENTO, L.NUMERO_DE_REGISTRO, L.NUM_REGISTRO_DEPAR,
		L.FECHA_DE_REGISTRO, L.FECHA_DOCUMENTO, L.POBLACION, L.DESTINO, L.ORIGEN, 
		L.IMPRESO, L.RESOLUCION, D.NOMBRE, C.NOMBRE_EMISOR
	 FROM LIBRO_DE_REGISTRO L,DEPARTAMENTO D, CARACTER_DOCUMENTO C 
	WHERE D.DEPARTAMENTO=L.CODIGO_ORIGEN AND C.EMISOR=L.CODIGO_DESTINO;

BEGIN
 DELETE FROM TABLA_AUX_TABLA_REGISTRO;
 
 OPEN C_TABLA_REG;
 LOOP
	FETCH C_TABLA_REG INTO ID,TIPO_DOCUMENTO,N_DE_REGISTRO,NUMERO_DEPAR,FECHA_REGIS,
			           FECHA_DOC,POBLACION,DESTINO,ORIGEN,IMPRESO,RESOLUCION,
				     DEPART,CARACTER_DOCU;
	EXIT WHEN C_TABLA_REG%NOTFOUND;
      IF (xID=ID) THEN
	 	YEAR:=SUBSTR(N_DE_REGISTRO,0,4);
		PERIODO:=MONTH(FECHA_REGIS)||'-'||SUBSTR(N_DE_REGISTRO,0,4);
 
	      INSERT INTO TABLA_AUX_TABLA_REGISTRO 
              (ID,TIPO_DOCUMENTO,N_DE_REGISTRO,NUMERO_DEPAR,YEAR,FECHA_REGIS,FECHA_DOC,
		   POBLACION,DESTINO,ORIGEN,IMPRESO,RESOLUCION,DEPARTAMENTO,
		   CARACTER_DOCUMENTO,PERIODO)
		VALUES
              (ID,TIPO_DOCUMENTO,N_DE_REGISTRO,NUMERO_DEPAR,YEAR,FECHA_REGIS,FECHA_DOC,
		   POBLACION,DESTINO,ORIGEN,IMPRESO,RESOLUCION,DEPART,CARACTER_DOCU,PERIODO);
	END IF;
 END LOOP;
 CLOSE C_TABLA_REG;

END;
/

/*******************************************************************************************
Es igual que el proc. anterior pero sin el campo ID.
Se utiliza la misma tabla auxiliar que en el proc. anterior.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE LISTADOS_REGISTRO AS

  TIPO_DOCUMENTO		CHAR(1);
  N_DE_REGISTRO		CHAR(12);
  NUMERO_DEPAR		CHAR(12);
  YEAR			CHAR(4);
  FECHA_REGIS		DATE;
  FECHA_DOC			DATE;
  POBLACION			CHAR(30);
  DESTINO			CHAR(50);
  ORIGEN			CHAR(50);
  IMPRESO			CHAR(1);
  RESOLUCION		CHAR(20);
  DEPART			CHAR(50);
  CARACTER_DOCU		CHAR(50);
  PERIODO			CHAR(7);

  CURSOR C_LISTADOS_REGISTRO IS
	SELECT L.TIPO_DE_DOCUMENTO,L.NUMERO_DE_REGISTRO, L.NUM_REGISTRO_DEPAR,
		 L.FECHA_DE_REGISTRO, L.FECHA_DOCUMENTO,L.POBLACION,L.DESTINO,L.ORIGEN,L.IMPRESO,
		 L.RESOLUCION, D.NOMBRE,C.NOMBRE_EMISOR
	  FROM LIBRO_DE_REGISTRO L,DEPARTAMENTO D,CARACTER_DOCUMENTO C 
 	 WHERE D.DEPARTAMENTO=L.CODIGO_ORIGEN AND C.EMISOR=L.CODIGO_DESTINO; 

BEGIN
	DELETE FROM TABLA_AUX_TABLA_REGISTRO;
	OPEN C_LISTADOS_REGISTRO; 
      LOOP
		FETCH C_LISTADOS_REGISTRO INTO TIPO_DOCUMENTO,N_DE_REGISTRO,NUMERO_DEPAR,
					             FECHA_REGIS,FECHA_DOC,POBLACION,DESTINO,ORIGEN,
							 IMPRESO,RESOLUCION,DEPART,CARACTER_DOCU;
		EXIT WHEN C_LISTADOS_REGISTRO%NOTFOUND;

	 	YEAR:=SUBSTR(N_DE_REGISTRO,0,4);
		PERIODO:=MONTH(FECHA_REGIS)||'-'||SUBSTR(N_DE_REGISTRO,0,4);
 
	      INSERT INTO TABLA_AUX_LISTADOS_REGISTRO 
		  (TIPO_DOCUMENTO,N_DE_REGISTRO,NUMERO_DEPAR,YEAR,FECHA_REGIS,FECHA_DOC,POBLACION,
		   DESTINO,ORIGEN,IMPRESO,RESOLUCION,DEPARTAMENTO,CARACTER_DOCUMENTO,PERIODO)
		VALUES
		  (TIPO_DOCUMENTO,N_DE_REGISTRO,NUMERO_DEPAR,YEAR,FECHA_REGIS,FECHA_DOC,POBLACION,
		   DESTINO,ORIGEN,IMPRESO,RESOLUCION,DEPART,CARACTER_DOCU,PERIODO);	
	END LOOP;
	CLOSE C_LISTADOS_REGISTRO;
END;
/

/*******************************************************************************************/

CREATE OR REPLACE PROCEDURE REGISTRO_GENERA_ESTADISTICAS
AS
   xYEAR	 CHAR(4);
   xAUX_YEAR CHAR(4);
   xPERIODO	 integer;
   xDEPAR	 CHAR(50);
   xDOC	 CHAR(50);
   xNUM	 INTEGER;

   xMES	 CHAR(10);
 
   CURSOR CYEAR IS SELECT DISTINCT(YEAR) FROM TABLA_AUX_LISTADOS_REGISTRO 
			 WHERE YEAR>=xAUX_YEAR;

   CURSOR CMES IS SELECT DISTINCT(FECHA_REGIS) FROM TABLA_AUX_LISTADOS_REGISTRO 
			 WHERE YEAR=xYEAR;

   CURSOR CDEPAR IS SELECT DISTINCT(DEPARTAMENTO) FROM TABLA_AUX_LISTADOS_REGISTRO 
    		       WHERE YEAR=xYEAR AND TO_NUMBER(TO_CHAR(FECHA_REGIS,'MM'))=xPERIODO; 

   CURSOR CCARAC_DOC IS SELECT DISTINCT(CARACTER_DOCUMENTO) 
    			 FROM TABLA_AUX_LISTADOS_REGISTRO 
                   WHERE YEAR=xYEAR AND TO_NUMBER(TO_DATE(FECHA_REGIS,'MM'))=xPERIODO;	

BEGIN

   SELECT MAX(YEAR) INTO xAUX_YEAR FROM REGISTRO_ESTADISTICAS;
   IF (xAUX_YEAR IS NULL) THEN xAUX_YEAR:='1900'; END IF;
  
   DELETE FROM REGISTRO_ESTADISTICAS WHERE YEAR>=xAUX_YEAR;

   /* SE LLAMA AL PROC. QUE RELLENA LA TABLA AUXILIAR */
   LISTADOS_REGISTRO;

   OPEN CYEAR;
   LOOP
      FETCH CYEAR INTO xYEAR;
	EXIT WHEN CYEAR%NOTFOUND;
	OPEN CMES;
	LOOP
	   FETCH CMES INTO xMES;
	   EXIT WHEN CMES%NOTFOUND;
	   xPERIODO:=MONTH(xMES);
	   OPEN CDEPAR;
	   LOOP
	      FETCH CDEPAR INTO xDEPAR;
		EXIT WHEN CDEPAR%NOTFOUND;
		      
	      SELECT COUNT(*) INTO xNUM
   	      FROM TABLA_AUX_LISTADOS_REGISTRO 
	  	WHERE YEAR=xYEAR AND DEPARTAMENTO=xDEPAR AND TIPO_DOCUMENTO='E' AND 
		TO_NUMBER(TO_CHAR(FECHA_REGIS,'MM'))=xPERIODO;

            INSERT INTO REGISTRO_ESTADISTICAS(CODIGO,NOMBRE,CUANTOS,YEAR,TIPO,PERIODO)
            VALUES ('DEP',xDEPAR,xNUM,xYEAR,'E',xPERIODO);

		SELECT COUNT(*) INTO xNUM
            FROM TABLA_AUX_LISTADOS_REGISTRO 
		WHERE YEAR=xYEAR AND DEPARTAMENTO=xDEPAR AND TIPO_DOCUMENTO='S' AND 
		TO_NUMBER(TO_CHAR(FECHA_REGIS,'MM'))=xPERIODO;
		
		INSERT INTO REGISTRO_ESTADISTICAS(CODIGO,NOMBRE,CUANTOS,YEAR,TIPO,PERIODO)
      	VALUES ('DEP',xDEPAR,xNUM,xYEAR,'S',xPERIODO);
			
         END LOOP; /*CDEPAR*/
	   CLOSE CDEPAR; 
 	END LOOP; /*CMES*/
	CLOSE CMES;
   END LOOP;/*CYEAR*/
   CLOSE CYEAR;

   OPEN CYEAR;
   LOOP
	FETCH CYEAR INTO xYEAR;
  	EXIT WHEN CYEAR%NOTFOUND;
	OPEN CMES;
	LOOP
	   FETCH CMES INTO xMES;
	   EXIT WHEN CMES%NOTFOUND;		
	   xPERIODO:=MONTH(xMES);
	   OPEN CCARAC_DOC;
	   LOOP
		FETCH CCARAC_DOC INTO xDOC;
		EXIT WHEN CCARAC_DOC%NOTFOUND;
            
		SELECT COUNT(*) INTO xNUM
		FROM TABLA_AUX_LISTADOS_REGISTRO 
		WHERE YEAR=xYEAR AND 
		      CARACTER_DOCUMENTO=xDOC AND TIPO_DOCUMENTO='E' AND
			TO_NUMBER(TO_CHAR(FECHA_REGIS,'MM'))=xPERIODO;

		INSERT INTO REGISTRO_ESTADISTICAS(CODIGO,NOMBRE,CUANTOS,YEAR,TIPO,PERIODO)
            VALUES('DOC',xDOC,xNUM,xYEAR,'E',xPERIODO);

            SELECT COUNT(*) INTO xNUM 
		FROM TABLA_AUX_LISTADOS_REGISTRO 
		WHERE YEAR=xYEAR AND CARACTER_DOCUMENTO=xDOC AND TIPO_DOCUMENTO='S' AND 
		TO_NUMBER(TO_CHAR(FECHA_REGIS,'MM'))=xPERIODO;

	      INSERT INTO REGISTRO_ESTADISTICAS(CODIGO,NOMBRE,CUANTOS,YEAR,TIPO,PERIODO)
          	VALUES('DOC',xDOC,xNUM,xYEAR,'S',xPERIODO);
         END LOOP; /*CCARAC_DOC*/
	   CLOSE CCARAC_DOC;
      END LOOP; /*CMES*/
	CLOSE CMES;
   END LOOP; /*CYEAR*/
   CLOSE CYEAR;
END;
/

/**************************************************************************************
Acci�n: A�adir o modificar un registro de Entrada/Salida.
MODIFICACI�N: 05/10/2001 M. Carmen Junco G�mez. Contador por departamento.
MODIFICACI�N: 28/01/2002 M. Carmen Junco G�mez. Insertar anotaci�n en el seguimiento tanto
		  si es una inserci�n como si es una modificaci�n.
MODIFICACI�N: 03/06/2002 M. Carmen Junco G�mez. Para relacionar multas con el registro
		  modificamos la tabla de multas con el ID del registro.
Modificado: 21/11/2003. Lucas Fern�ndez P�rez. Par�metro nuevo: xExpediente
***************************************************************************************/
CREATE OR REPLACE PROCEDURE REGISTRO_ADD_MOD_ENTRADA(
		xTIPO 			CHAR,
		xNUMERO 		CHAR,		
		xFREGISTRO 		DATE,
		xFDOCUMENTO		DATE,
		xPOBLACION 		VARCHAR2,
		xEXTRACTO  		VARCHAR2,
		xNIF_DESTINO	CHAR,
		xDESTINO    	VARCHAR2,
		xNIF_ORIGEN		CHAR,
		xORIGEN     	VARCHAR2,
		xCOD_DESTINO   	INTEGER,
		xCOD_ORIGEN     INTEGER,
		xRESOLUCION		VARCHAR2,
		xOBSERVACIONES 	VARCHAR2,
		xVinculo		Integer,
		xTipoVinculo	CHAR,
		xDescribeVinculo	VARCHAR2,
		xExpediente			CHAR,
		xNUMERO_REGIS 		OUT	CHAR,
		xNUM_REGIS_DEPAR	OUT CHAR,
		xIDRegistro			OUT INTEGER)
AS

   xFECHADOCUMENTO	DATE;
   mYEAR			CHAR(4);
   mYEARENTRADA		CHAR(4);
   mYEARSALIDA		CHAR(4);   
   xCONTADOR		CHAR(7);
   xCUANTOS			INTEGER;
   mOLDCODIGO		INTEGER;

BEGIN

   IF (TO_CHAR(xFDOCUMENTO,'YYYY')='1899') THEN 
      xFECHADOCUMENTO:=NULL; 
   ELSE
      xFECHADOCUMENTO:=xFDOCUMENTO;
   END IF;

   IF (xNUMERO='I') THEN
  
	INSERT INTO Libro_de_registro (FECHA_DE_REGISTRO,FECHA_DOCUMENTO,
		POBLACION,EXTRACTO,NIF_DESTINO,DESTINO,NIF_ORIGEN,ORIGEN,CODIGO_DESTINO,
		CODIGO_ORIGEN,RESOLUCION,OBSERVACIONES,TIPO_DE_DOCUMENTO,
		IDCONECTA,TIPOCONECTA,EXPEDIENTE)

	VALUES (xFREGISTRO,xFECHADOCUMENTO,xPOBLACION,xEXTRACTO,
	     	  xNIF_DESTINO,xDESTINO,xNIF_ORIGEN,xORIGEN,xCOD_DESTINO,xCOD_ORIGEN,
		  xRESOLUCION,xOBSERVACIONES,xTIPO,
		  xVinculo, xTipoVinculo,xExpediente)

	RETURNING NUMERO_DE_REGISTRO,NUM_REGISTRO_DEPAR,ID 
	INTO xNUMERO_REGIS,xNUM_REGIS_DEPAR,xIDRegistro;
	
   ELSE

	SELECT CODIGO_DESTINO INTO mOLDCODIGO FROM LIBRO_DE_REGISTRO
	WHERE TIPO_DE_DOCUMENTO=xTIPO AND NUMERO_DE_REGISTRO=xNUMERO;
  
      UPDATE Libro_de_registro 
	SET FECHA_DE_REGISTRO=xFREGISTRO,
	    FECHA_DOCUMENTO=xFECHADOCUMENTO,POBLACION=xPOBLACION,
	    EXTRACTO=xEXTRACTO,NIF_DESTINO=xNIF_DESTINO,DESTINO=xDESTINO,
	    NIF_ORIGEN=xNIF_ORIGEN,ORIGEN=xORIGEN,
	    CODIGO_DESTINO=xCOD_DESTINO,
	    CODIGO_ORIGEN=xCOD_ORIGEN,RESOLUCION=xRESOLUCION,
	    OBSERVACIONES=xOBSERVACIONES,
	    IDCONECTA=xVinculo, TIPOCONECTA=xTipoVinculo, EXPEDIENTE=xExpediente
	WHERE TIPO_DE_DOCUMENTO=xTIPO AND NUMERO_DE_REGISTRO=xNUMERO

	RETURNING ID,NUMERO_DE_REGISTRO,NUM_REGISTRO_DEPAR,YEAR
      INTO xIDRegistro,xNUMERO_REGIS,xNUM_REGIS_DEPAR,mYEAR;   

	-- Si se ha modificado el Departamento, tendremos que actualizar el contador
	-- NUM_REGISTRO_DEPAR. Su nuevo valor se podr� tomar de la tabla 
	-- DATOS_REGISTRO_DEPAR si el a�o del documento es igual al a�o de 
	-- entrada, o buscando el �ltimo valor de este contador para el 
	-- nuevo departamento en la tabla LIBRO_DE_REGISTRO si los a�os son distintos.

	SELECT YEAR_REG_ENTRADA,YEAR_REG_SALIDA INTO mYEARENTRADA,mYEARSALIDA
	FROM DATOS_REGISTRO;	

	IF (xCOD_DESTINO<>mOLDCODIGO) THEN	   
	
	   IF xTIPO='E' THEN
		IF (mYEAR=mYEARENTRADA) THEN
		   UPDATE DATOS_REGISTRO_DEPAR SET ENTRADA=ENTRADA+1 
		   WHERE DEPARTAMENTO=xCOD_DESTINO
		   RETURNING ENTRADA INTO xCUANTOS;

		   xNUM_REGIS_DEPAR:=mYEAR ||'/'||LPAD(xCUANTOS,7,'0');		   
		ELSE	   	   
		   SELECT MAX(SUBSTR(NUM_REGISTRO_DEPAR,6,7)) INTO xCONTADOR
		   FROM LIBRO_DE_REGISTRO WHERE TIPO_DE_DOCUMENTO='E' AND YEAR=mYEAR
	         AND CODIGO_DESTINO=xCOD_DESTINO AND NUMERO_DE_REGISTRO<>xNUMERO_REGIS;

		   IF (xCONTADOR IS NULL) THEN						
		      xNUM_REGIS_DEPAR:=mYEAR||'/'||'0000001';
		   ELSE			
		      xNUM_REGIS_DEPAR:=mYEAR||'/'||LPAD(TO_NUMBER(xCONTADOR)+1,7,'0');
		   END IF;		   
		END IF;
		
	   ELSE
		IF (mYEAR=mYEARSALIDA) THEN
               UPDATE DATOS_REGISTRO_DEPAR SET SALIDA=SALIDA+1 
		   WHERE DEPARTAMENTO=xCOD_DESTINO
		   RETURNING SALIDA INTO xCUANTOS;

	         xNUM_REGIS_DEPAR:=mYEAR ||'/'|| LPAD(xCUANTOS,7,'0');		   
		ELSE	   
		   SELECT MAX(SUBSTR(NUM_REGISTRO_DEPAR,6,7)) INTO xCONTADOR
		   FROM LIBRO_DE_REGISTRO WHERE TIPO_DE_DOCUMENTO='S' AND YEAR=mYEAR
	         AND CODIGO_DESTINO=xCOD_DESTINO AND NUMERO_DE_REGISTRO<>xNUMERO_REGIS;

		   IF (xCONTADOR IS NULL) THEN
		      xNUM_REGIS_DEPAR:=mYEAR|| '/' ||'0000001';
		   ELSE
		      xNUM_REGIS_DEPAR:=mYEAR|| '/' ||LPAD(TO_NUMBER(xCONTADOR)+1,7,'0');
		   END IF;		   
		END IF;		
	   END IF;	   

	   UPDATE LIBRO_DE_REGISTRO SET NUM_REGISTRO_DEPAR=SUBSTR(xNUM_REGIS_DEPAR,1,12)
	   WHERE ID=xIDRegistro;			   

	END IF;
	
   END IF;

   -- tenemos que insertar en el seguimiento del expediente la anotaci�n
   IF xTipoVinculo='E' THEN
      PkSeguimiento.AnotaRegistroES(xVinculo, xIDRegistro, xDescribeVinculo);
   --Multas: Lo vinculamos tambi�n en la tabla de multas
   ELSIF xTipoVinculo='M' THEN 
      UPDATE MULTAS SET IDREGISTRO=xIDRegistro
	WHERE ID=xVinculo;
   END IF;

END;
/

/******************************************************************************************
MODIFICACI�N: 05/10/2001 M. Carmen Junco G�mez. Contador por departamento.
*******************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_LIBRO_DE_REGISTRO
BEFORE INSERT ON LIBRO_DE_REGISTRO
FOR EACH ROW 
DECLARE  xTEMP INTEGER;
         mNum Integer;
	   mNumDepar Integer;
         mYear char(4);
BEGIN

      SELECT GENREGI.NEXTVAL INTO :NEW.ID FROM DUAL;

	:NEW.YEAR:=TO_CHAR(:NEW.FECHA_DE_REGISTRO,'YYYY');
	:NEW.MES:=TO_CHAR(:NEW.FECHA_DE_REGISTRO,'MM');

      IF (:new.tipo_de_documento='E') THEN
		UPDATE DATOS_REGISTRO SET ENTRADA=ENTRADA+1
			RETURNING ENTRADA,YEAR_REG_ENTRADA INTO mNum,mYear;

		UPDATE DATOS_REGISTRO_DEPAR SET ENTRADA=ENTRADA+1
		WHERE DEPARTAMENTO=:NEW.CODIGO_DESTINO
			RETURNING ENTRADA INTO mNumDepar;

      ELSE
		UPDATE DATOS_REGISTRO SET SALIDA=SALIDA+1
			RETURNING SALIDA,YEAR_REG_SALIDA INTO mNum,mYear;

		UPDATE DATOS_REGISTRO_DEPAR SET SALIDA=SALIDA+1
		WHERE DEPARTAMENTO=:NEW.CODIGO_DESTINO
			RETURNING SALIDA INTO mNumDepar;

      END IF;


      :NEW.NUMERO_DE_REGISTRO:=mYEAR || '/' || LPAD(mNum,7,'0');

	:NEW.NUM_REGISTRO_DEPAR:=mYEAR || '/' || LPAD(mNumDepar,7,'0');

END;
/

/**************************************************************************************
A�adir o modificar un registro de la tabla de caracter del documento.
**************************************************************************************/

CREATE OR REPLACE PROCEDURE REGISTRO_ADD_MOD_CARA(
	 xEMI INTEGER, 
	 xNOMBRE CHAR)
AS

BEGIN

   IF (xEMI =0) THEN
      INSERT INTO Caracter_Documento (NOMBRE_EMISOR) VALUES (xNOMBRE);
   ELSE
      UPDATE Caracter_Documento SET NOMBRE_EMISOR=xNOMBRE WHERE EMISOR=xEMI;
   END IF;

END;
/

/**************************************************************************************
A�adir o modificar un registro de la tabla de departamentos.
***************************************************************************************/

CREATE OR REPLACE PROCEDURE REGISTRO_ADD_MOD_DEPA(
	xDEPA INTEGER, 
	xNOMBRE CHAR, 
	xMAIL CHAR)
AS
xID integer;
BEGIN

   IF (xDEPA=0) THEN
		INSERT INTO Departamento (NOMBRE,CORREO_ELECTRONICO) VALUES (xNOMBRE,xMAIL)
		returning DEPARTAMENTO into xID;

		INSERT INTO DATOS_REGISTRO_DEPAR(DEPARTAMENTO,ENTRADA,SALIDA)
			VALUES (xID,0,0);

   ELSE
		UPDATE Departamento SET NOMBRE=xNOMBRE,CORREO_ELECTRONICO=xMAIL WHERE DEPARTAMENTO=xDEPA;
   END IF;

END;
/

/****************************************************************************************
Acci�n: Ver o poner el a�o de trabajo.
MODIFICACI�N: 05/10/2001 M. Carmen Junco G�mez. Contador por departamento.
****************************************************************************************/

CREATE OR REPLACE PROCEDURE SET_YEAR (
	YearEntrada 		integer, 
      ContadorEntrada         integer,
	YearSalida 			integer,
      ContadorSalida          integer,
	sYearEntrada 	out	integer, 
      sContadorEntrada  out   integer,
	sYearSalida 	out	integer,
      sContadorSalida   out   integer)
AS
   xCONTADOR CHAR(7);
   xCONT_E INTEGER;
   xCONT_S INTEGER;
   CURSOR CDEPAR IS SELECT DEPARTAMENTO FROM DEPARTAMENTO;  
BEGIN

   IF (YearEntrada=0) THEN  /*Si no pasamos parametros */

      SELECT YEAR_REG_ENTRADA,ENTRADA,YEAR_REG_SALIDA,SALIDA 
	INTO sYearEntrada,sContadorEntrada,sYearSalida,
           sContadorSalida     
      FROM DATOS_REGISTRO;
   ELSE
      /*Establece el a�o de Entrada en el generador*/
	
      UPDATE DATOS_REGISTRO SET YEAR_REG_ENTRADA=YearEntrada,
    					  ENTRADA=ContadorEntrada,
					  YEAR_REG_SALIDA=YearSalida,
					  SALIDA=ContadorSalida;

      FOR vDEPAR IN CDEPAR
      LOOP
	   SELECT MAX(SUBSTR(NUM_REGISTRO_DEPAR,6,7)) INTO xCONTADOR FROM LIBRO_DE_REGISTRO 
	   WHERE TIPO_DE_DOCUMENTO='E' AND CODIGO_DESTINO=vDEPAR.DEPARTAMENTO AND
	         YEAR=YearEntrada;

	   IF xCONTADOR IS NULL THEN
		xCONT_E:=0;
	   ELSE
		xCONT_E:=TO_NUMBER(xCONTADOR);
	   END IF;
	
	   SELECT MAX(SUBSTR(NUM_REGISTRO_DEPAR,6,7)) INTO xCONTADOR FROM LIBRO_DE_REGISTRO
	   WHERE TIPO_DE_DOCUMENTO='S' AND CODIGO_DESTINO=vDEPAR.DEPARTAMENTO AND
               YEAR=YearSalida;

	   IF xCONTADOR IS NULL THEN
		xCONT_S:=0;
	   ELSE
		xCONT_S:=TO_NUMBER(xCONTADOR);
	   END IF;

	   UPDATE DATOS_REGISTRO_DEPAR SET ENTRADA=xCONT_E,
	  					     SALIDA=xCONT_S
	   WHERE DEPARTAMENTO=vDEPAR.DEPARTAMENTO;
      END LOOP;

   END IF;
END;
/

/****************************************************************************************/

CREATE OR REPLACE TRIGGER T_DOCREGISTRO
BEFORE INSERT ON DOCREGISTRO
FOR EACH ROW

BEGIN
   SELECT GENDOCREGISTRO.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

--CREATE DIRECTORY REGISTRO AS 'C:\REGISTROES'


CREATE OR REPLACE PROCEDURE RegistroDocAdd( 
	xIDLibro IN DOCREGISTRO.IDLIBRO%Type,
	xFichero IN DOCREGISTRO.FicherOriginal%Type,
	xRefe IN DOCREGISTRO.REFERENCIA%Type,
	xID OUT DOCREGISTRO.ID%Type)
AS
BEGIN

   INSERT INTO DOCREGISTRO (IDLIBRO,REFERENCIA,IMAGEN) 
   VALUES (xIDLibro, xRefe, empty_blob() )
   	RETURNING ID INTO xID;

END;
/


/********************************************************************/
COMMIT;
/********************************************************************/