-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

CREATE OR REPLACE PROCEDURE EXISTE_CONTRI(
	xNIF  IN  CHAR,
      RESP  OUT INTEGER)
AS

xCUANTOS INTEGER DEFAULT 0;

BEGIN

  RESP:=1;

  SELECT COUNT(*) INTO xCUANTOS 
  FROM CONTRIBUYENTES WHERE NIF=xNIF;

  IF xCUANTOS = 0 THEN
     RESP:=0;

  END IF;

END;
/

--
-- Insertar o modificar un contribuyente
--
-- Modificado: 17/12/2004. Gloria Maria Calle Hernandez. Añadido campo motivo al historico de contribuyentes. 
-- Modificado procedimiento INS_UPD_CONTRI y eliminado trigger add_histo_contri. 
--    Ahora desde el procedimiento se ejecuta el insert en el historico.
-- Modificado: 13/01/2005. Lucas Fernández Pérez. El IF antes de modificar los datos sólo comparaba 
--    si xcampo<>xRec.campo, y fallaba cuando campo is null y cuando xReg.campo is null, porque 
--    no lo interpretaba como un cambio en el campo. 
--    Se comprueban esas dos condiciones para cada uno de los campos.
-- Modificado: 27/01/2005. Gloria María Calle Hernández. Eliminado el IF antes de realizar el Update
--    apenas tarda unos milisegundos si actualiza un registro de contribuyentes aunque ningún campo cambie.
--    Daba problemas en Catoure.
CREATE OR REPLACE PROCEDURE INS_UPD_CONTRI(
  	 xMODO   IN CHAR,
	 xNIF    IN CHAR, 
	 xNombre IN CHAR,
	 xVIA    IN CHAR,
	 xCalle  IN CHAR,
	 xNum    IN CHAR,
	 xEsca   IN CHAR, 
	 xPlanta IN CHAR,
	 xPiso   IN CHAR,
     xPobla  IN CHAR, 
	 xProvi  IN CHAR, 
	 xPostal IN CHAR,
     xPais   IN CHAR,
     xTele   IN CHAR,
     xMovil  IN CHAR,
     xEMail  IN CHAR,
	 xMotivo IN CHAR )
AS
     xReg	 CONTRIBUYENTES%ROWTYPE;
BEGIN

  IF (xMODO='A') then
     insert into contribuyentes (NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS,
	 			 				 TELEFONO,MOVIL,EMAIL)
     values (xNIF,xNombre,xVIA,xCalle,xNum,xEsca,xPlanta,xPiso,xPobla,xProvi,xPostal,xPais,xTELE,xMOVIL,xEMAIL);
	 
  ELSE

	BEGIN
	   SELECT * INTO xReg FROM CONTRIBUYENTES WHERE NIF=xNIF;
	EXCEPTION
	   WHEN no_data_found THEN
	        null;
	END;
	
    update contribuyentes set NOMBRE=xNombre,
	  	   				  	  VIA=xVIA,
        					  CALLE=xCalle,
 	  						  NUMERO=xNum,
        					  ESCALERA=xEsca,
        					  PLANTA=xPlanta,
	  						  PISO=xPiso,
        					  POBLACION=xPobla,
        					  PROVINCIA=xProvi,
        					  CODIGO_POSTAL=xPostal,
        					  PAIS=xPais,
	  						  TELEFONO=xTELE,
	  						  MOVIL=xMOVIL,
	  						  EMAIL=xEMAIL
     				    where NIF=xNIF;

	INSERT INTO HDOMICONTRI
	    (USUARIO,FECHA,NIF,NOMBRE,VIA,CODIGO_DE_CALLE,CALLE,NUMERO,ESCALERA,
		 PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS,TELEFONO,MOVIL,EMAIL,MOTIVO)
	VALUES
	    (USER,SYSDATE,xReg.NIF,xReg.NOMBRE,xReg.VIA,xReg.CODIGO_DE_CALLE,xReg.CALLE,xReg.NUMERO,xReg.ESCALERA,xReg.PLANTA,xReg.PISO,
	     xReg.POBLACION,xReg.PROVINCIA,xReg.CODIGO_POSTAL,xReg.PAIS,xReg.TELEFONO,xReg.MOVIL,xReg.EMAIL,xMotivo);
  END IF;	

END;
/


/*****************************************************************************************/

CREATE OR REPLACE PROCEDURE ESTADO_CIVIL(
	  XNIF     IN CHAR,
	  XPESTADO IN CHAR)
AS
BEGIN
   UPDATE CONTRIBUYENTES SET ESTADO_CIVIL=xpESTADO
   WHERE NIF=xNIF;
END;
/

/* *****************************************************
	Cambiar en todos los tributos un dni malo por el bueno
	Antonio Pérez 25 Julio 2.001
   ***************************************************** */
--
-- MODIFICACIÓN: 19/03/2002 Antonio Pérez Caballero
-- se mejora el cambio de titularidad en IBI, dejando un rastro más pronunciado
--

CREATE OR REPLACE PROCEDURE CHGNIF_MALO_A_BUENO(
	xMALO IN ALIASDNI.NIFBUENO%Type,
	xBUENO IN ALIASDNI.NIFBUENO%Type)
AS
CURSOR cIBI IS
	SELECT ID FROM IBI WHERE NIF=xMALO;

xGT Char(1);
BEGIN


-- Este valor de configuración nos indica si tiene instalado nuestro software de GT
SELECT GT INTO xGT FROM CONFIGURACION 
WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

IF xGT='N' THEN
   return;
END IF;

   FOR v_cIBI IN cIBI LOOP
       IBICambioTitularidad(xBUENO, v_cIBI.ID, 'M',sysdate );
   END LOOP;


	-- Actualizamos en NIF en la tabla de referencia para IBI urbano y rustico e IAE
	UPDATE REFERENCIAS_BANCOS SET NIF=xBUENO WHERE NIF=xMALO;

	UPDATE RUS80 SET NIF=xBUENO WHERE NIF=xMALO;
	UPDATE IAE SET NIF=xBUENO WHERE NIF=xMALO;
	UPDATE VEHICULOS SET NIF=xBUENO WHERE NIF=xMALO;
	UPDATE AGUA SET NIF=xBUENO WHERE NIF=xMALO;
	UPDATE EXACCIONES SET NIF=xBUENO WHERE NIF=xMALO;	
	UPDATE VEHICULOSR SET NIF=xBUENO WHERE NIF=xMALO;

END;
/


/* *****************************************************
	Relación de todos los motes de un NIF Y CAMBIARLOS
	EN LAS TABLAS DE TRIBUTOS, PARA NO TENER QUE IR CAMBIANDO
	EL NIF NUEVO EN CADA UNO DE LOS TRIBUTOS
	Antonio Pérez 25 Julio 2.001
   ***************************************************** */

CREATE OR REPLACE PROCEDURE CHGNIF_TODOS_MOTES(
	xNIF IN ALIASDNI.NIFBUENO%Type)
AS
CURSOR cMotes IS Select ALIASNIF From ALIASDNI where NIFBUENO=xNIF;
BEGIN

FOR v_cMotes IN cMotes LOOP

    CHGNIF_MALO_A_BUENO(v_cMotes.ALIASNIF, xNIF);

END LOOP;

END;
/


/* ************************************
	AÑADIR UNA LISTA DE MOTES A UN DNI EN CONCRETO
	ANTONIO PEREZ CABALLERO 24 JUNIO 2.001

1) Uno que se halla considerado como bueno, que tenga malos asociados a el, nunca podrá ser malo
2) Si hay un expediente abierto a un malo no puede ser mote
3) No se puede ser mote de más de un NIF bueno, ESTO LO CONTROLA LA INTEGRIDAD REFERENCIAL

En el interfaz de usuario cuando un nif sea mote de otro la rejilla la marcaremos en color amarillo
y el boton motes lo desactivaremos.

   ************************************ */
CREATE OR REPLACE PROCEDURE ADDMOTESWRITE(xLISTA IN VARCHAR2, 
	xNIFBUENO IN ALIASDNI.NIFBUENO%Type )
AS
xNIF ALIASDNI.ALIASNIF%Type;
xMALO ALIASDNI.ALIASNIF%Type;
xLISTALOCAL VARCHAR2(512);
xCUANTOS INT;
BEGIN

xLISTALOCAL:=xLISTA;

--DBMS_OUTPUT.PUT_LINE(xLISTALOCAL);

IF INSTR(xLISTALOCAL,'/') > 0 THEN

<<INICIO>>

   WHILE (INSTR(xLISTALOCAL,'/') > 1) LOOP


      xNIF:=SUBSTR(xLISTALOCAL, 1, (INSTR(xLISTALOCAL,'/')-1));

      xLISTALOCAL:=SUBSTR(xLISTALOCAL, INSTR(xLISTALOCAL,'/')+1, LENGTH(xLISTALOCAL));

	IF xNIFBUENO=xNIF THEN
	   GOTO INICIO;
	END IF;

	--
	-- comprobar que un nif malo no este asignado a un nif bueno como alias
	-- Si un nif existe como nif bueno, nunca podrá estar en la colunmna de nif malo
	--


	  xCUANTOS:=0;
	  SELECT COUNT(*) INTO xCUANTOS FROM ALIASDNI WHERE NIFBUENO=xNIF;
	  IF xCUANTOS > 0 THEN
	     GOTO INICIO;
	  END IF;

	-- 
	-- Comprobar que no hay expediente vivo a nombre del mote
	--

	begin

	  SELECT ID INTO xCUANTOS
        FROM EXPEDIENTES
        WHERE DEUDOR=xNIF 
		AND f_ingreso is null 
		AND f_anulacion is null;

	  GOTO INICIO;
	exception
	   when no_data_found then
		Null;
	end;


	BEGIN
	  SELECT NIFBUENO INTO xMALO FROM ALIASDNI WHERE NIFBUENO=xNIFBUENO AND ALIASNIF=xNIF;
	Exception
		When no_data_found then
		INSERT INTO ALIASDNI (ALIASNIF, NIFBUENO) VALUES (xNIF, xNIFBUENO);
		UPDATE CONTRIBUYENTES SET VALIDADO='M' WHERE NIF=xNIF;
	END;	

   END LOOP;

END IF;

END;
/

/* *****************************************************************************************
Acción: Añade una lista de motes a un DNI en concreto
Autor:  24/06/2001 ANTONIO PEREZ CABALLERO
MODIFICACIÓN: 19/06/2002 Antonio Pérez Caballero.Para marcar todos los nif buenos que 
	        tengan motes asociados, esto es a petición de de Andrés Rodríguez 
		  Tejerina Tesorero de Salobreña.
DELPHI
****************************************************************************************** */

CREATE OR REPLACE PROCEDURE ADDMOTES(xLISTA IN VARCHAR2, 
	xNIFBUENO IN ALIASDNI.NIFBUENO%Type )
AS
xCuantos Integer;
BEGIN

ADDMOTESWRITE(xLISTA, xNIFBUENO);

CHGNIF_TODOS_MOTES(xNIFBUENO);

Select count(*) INTO xCuantos from ALIASDNI 
	where NIFBUENO=xNIFBUENO;

-- Si hay motes asociados lo indicamos
IF xCuantos > 0 THEN
   UPDATE CONTRIBUYENTES SET BUENODEMOTE='S' 
	WHERE NIF=xNIFBUENO
		AND BUENODEMOTE='N';
END IF;

END;
/

/* ************************************
	AÑADIR UN DOMICILIO ALTERNATIVO A UN CONTRIBUYENTE
	ANTONIO PEREZ CABALLERO 24 JUNIO 2.001
   ************************************ */

CREATE OR REPLACE PROCEDURE ADDDOMIALTERNATIVO(
	xNIF IN DOMICILIOS_ALTERNATIVOS.NIF%Type,
      xVIA IN DOMICILIOS_ALTERNATIVOS.VIA%Type,
	xCODIGO_DE_CALLE IN DOMICILIOS_ALTERNATIVOS.CODIGO_DE_CALLE%Type,
	xCALLE IN DOMICILIOS_ALTERNATIVOS.CALLE%Type,
	xNUMERO IN DOMICILIOS_ALTERNATIVOS.NUMERO%Type,
	xESCALERA IN DOMICILIOS_ALTERNATIVOS.ESCALERA%Type,
	xPLANTA IN DOMICILIOS_ALTERNATIVOS.PLANTA%Type,
	xPISO IN DOMICILIOS_ALTERNATIVOS.PISO%Type,
      xPOBLACION IN DOMICILIOS_ALTERNATIVOS.POBLACION%Type,
	xPROVINCIA IN DOMICILIOS_ALTERNATIVOS.PROVINCIA%Type,
	xCODIGO_POSTAL IN DOMICILIOS_ALTERNATIVOS.CODIGO_POSTAL%Type,
	xPAIS IN DOMICILIOS_ALTERNATIVOS.PAIS%Type,
	xParaQue IN DOMICILIOS_ALTERNATIVOS.PARAQUE%Type,
	xTELE IN DOMICILIOS_ALTERNATIVOS.TELEFONO%Type,
	xMOVIL IN DOMICILIOS_ALTERNATIVOS.MOVIL%Type,
	xEMAIL IN DOMICILIOS_ALTERNATIVOS.EMAIL%Type)
AS
BEGIN

INSERT INTO DOMICILIOS_ALTERNATIVOS (NIF,
      VIA,CODIGO_DE_CALLE,CALLE,NUMERO,ESCALERA,PLANTA,PISO,
      POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS,PARAQUE,TELEFONO,MOVIL,EMAIL)
	VALUES (xNIF,
      xVIA,xCODIGO_DE_CALLE,xCALLE,xNUMERO,xESCALERA,xPLANTA,xPISO,
      xPOBLACION,xPROVINCIA,xCODIGO_POSTAL,xPAIS,xPARAQUE,xTELE,xMOVIL,xEMAIL);

END;
/


/* ************************************
	MODIFICAR UN DOMICILIO ALTERNATIVO A UN CONTRIBUYENTE
	ANTONIO PEREZ CABALLERO 24 JUNIO 2.001
   ************************************ */



CREATE OR REPLACE PROCEDURE ModiDOMIALTERNATIVO(
	xID IN DOMICILIOS_ALTERNATIVOS.ID%Type,
      xVIA IN DOMICILIOS_ALTERNATIVOS.VIA%Type,
	xCODIGO_DE_CALLE IN DOMICILIOS_ALTERNATIVOS.CODIGO_DE_CALLE%Type,
	xCALLE IN DOMICILIOS_ALTERNATIVOS.CALLE%Type,
	xNUMERO IN DOMICILIOS_ALTERNATIVOS.NUMERO%Type,
	xESCALERA IN DOMICILIOS_ALTERNATIVOS.ESCALERA%Type,
	xPLANTA IN DOMICILIOS_ALTERNATIVOS.PLANTA%Type,
	xPISO IN DOMICILIOS_ALTERNATIVOS.PISO%Type,
      xPOBLACION IN DOMICILIOS_ALTERNATIVOS.POBLACION%Type,
	xPROVINCIA IN DOMICILIOS_ALTERNATIVOS.PROVINCIA%Type,
	xCODIGO_POSTAL IN DOMICILIOS_ALTERNATIVOS.CODIGO_POSTAL%Type,
	xPAIS IN DOMICILIOS_ALTERNATIVOS.PAIS%Type,
	xPARAQUE IN DOMICILIOS_ALTERNATIVOS.PARAQUE%Type,
	xTELE IN DOMICILIOS_ALTERNATIVOS.TELEFONO%Type,
	xMOVIL IN DOMICILIOS_ALTERNATIVOS.MOVIL%Type,
	xEMAIL IN DOMICILIOS_ALTERNATIVOS.EMAIL%Type)
AS
BEGIN

update DOMICILIOS_ALTERNATIVOS SET VIA=xVIA,CODIGO_DE_CALLE=xCODIGO_DE_CALLE,
	CALLE=xCALLE,NUMERO=xNUMERO,
	ESCALERA=xESCALERA,PLANTA=xPLANTA,
	PISO=xPISO,POBLACION=xPOBLACION,
	PROVINCIA=xPROVINCIA,CODIGO_POSTAL=xCODIGO_POSTAL,
	PAIS=xPAIS,PARAQUE=xPARAQUE,
	TELEFONO=xTELE,
	MOVIL=xMOVIL,
	EMAIL=xEMAIL
	WHERE ID=xID;

END;
/


--
-- Añadir un cotitular
--

CREATE OR REPLACE PROCEDURE AddCOTITULARES(
	xPrograma COTITULARES.PROGRAMA%Type,
	xNIF COTITULARES.NIF%Type,
	xID_CONCEPTO COTITULARES.ID_CONCEPTO%Type)
AS
BEGIN

INSERT INTO COTITULARES (PROGRAMA,NIF,ID_CONCEPTO) 
	VALUES (xPROGRAMA,xNIF,xID_CONCEPTO);

END;
/

--
-- Antonio Pérez Caballero
-- 07/11/2001
-- Dando un NIF nos devuelve o su NIF bueno o nulo
-- Esto nos sirve para identificar si un dni es un mote de alguien o no
--
CREATE OR REPLACE FUNCTION GetAliasNIF(xNIF IN ALIASDNI.NIFBUENO%Type)
RETURN Char
AS
v_NIF Char(10);
BEGIN 

  Select NIFBUENO into v_NIF From ALIASDNI
	Where ALIASNIF=xNIF;

Return v_NIF;

Exception
  When no_data_found then
    Return Null;
END;
/

--
-- Antonio Pérez Caballero
-- 09/04/2002
-- Dando un NIF nos devuelve o su NIF bueno o nulo
-- Esto nos sirve para identificar si un dni es un mote de alguien o no
-- y para saber si el nif existe como contribuyente
--
CREATE OR REPLACE FUNCTION GetExisteNIF(xNIF IN ALIASDNI.NIFBUENO%Type)
RETURN Char
AS
   v_NIF Char(10);

BEGIN 

   begin
      Select NIFBUENO into v_NIF From ALIASDNI
	Where ALIASNIF=xNIF;
      Exception
         When no_data_found then
            Select NIF into v_NIF From Contribuyentes
	      Where NIF=xNIF;
   end;

   Return v_NIF;

   Exception
      When no_data_found then
         Return Null;

END;
/


/*******************************************************************************************/


/*RECOGER LOS DATOS POSTALES DE UN CONTRIBUYENTE*/
create or replace procedure Get_Datos_Postales (
	xNIF 		in	char,
	xEXPE 	in	CHAR,
	xTIPO 	in	CHAR,
	xID 		in	Integer,
	xNOMBRE 	out	CHAR,
	xDOMICILIO 	out	CHAR,
	xCODPOSTAL 	out	CHAR,
	xPOBLACION 	out	CHAR,
	xPROVINCIA 	out	CHAR,
	xRela 	out	char,
	xOrden 	out	char
)
as
	xCalle	char(30);
	xNumero	char(3);
	xEscalera   char(2);
	xPlanta	char(3);
	xPiso		char(2);
begin

   select nombre,calle,numero,escalera,planta,piso,codigo_postal,poblacion,provincia 
     into xNOMBRE,xCalle,xNumero,xEscalera,xPlanta,xPiso,xCODPOSTAL,xPOBLACION,xPROVINCIA
   from CONTRIBUYENTES
   where NIF=xNIF;

   xDomicilio:=xCalle||' '||xNumero||' '||xEscalera||' '||xPlanta||' '||xPiso;
   SELECT N_RELACION,N_ORDEN into xRela,xOrden FROM NOTIFICACIONES 
   WHERE EXPEDIENTE=xEXPE AND NIF=xNIF AND TIPO_NOTI=xTIPO AND ID_EMBARGOS=xID;
end;
/

/********************************************************************/

CREATE or REPLACE FUNCTION GetNombre (xNIF IN Contribuyentes.NIF%TYPE)
RETURN char
AS
   v_Nombre char(40);
BEGIN

   SELECT NOMBRE 
   INTO v_Nombre
   FROM contribuyentes
   WHERE nif=xNIF;

   RETURN v_Nombre;

END;
/

/********************************************************************/

CREATE or REPLACE FUNCTION GetDomicilio (xNIF IN Contribuyentes.NIF%TYPE)
RETURN varchar2
AS
   v_Domicilio varchar2(50);
BEGIN 

   SELECT ltrim(rtrim( VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||
	    PLANTA||' '||PISO))	  
   INTO v_Domicilio
   FROM contribuyentes
   WHERE nif=xNIF;

   RETURN v_Domicilio;

END;
/

--
-- Borrar un mote y controlar que cuando ya no le queden motes colgados al nif bueno
-- anotarlo en la tabla de contribuyentes
-- 19/06/2002 Antonio Pérez Caballero
--
CREATE OR REPLACE PROCEDURE MOTESDEL(xNIFMALO IN ALIASDNI.NIFBUENO%Type, 
	xNIFBUENO IN ALIASDNI.NIFBUENO%Type )
AS
xCuantos Integer;
BEGIN

DELETE FROM ALIASDNI WHERE ALIASNIF=xNIFMALO;

UPDATE contribuyentes set VALIDADO='N' WHERE NIF=xNIFMALO;

Select count(*) INTO xCuantos from ALIASDNI 
	where NIFBUENO=xNIFBUENO;

-- Si hay motes asociados lo indicamos
IF xCuantos = 0 THEN
   UPDATE CONTRIBUYENTES SET BUENODEMOTE='N' 
	WHERE NIF=xNIFBUENO
		AND BUENODEMOTE='S';
END IF;

END;
/
