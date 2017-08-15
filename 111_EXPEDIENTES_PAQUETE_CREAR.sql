-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

-- ******************************************************************************
--
--       Para cualquier duda Carpeta de documentación técnica fichero 1001
--
-- *******************************************************************************

CREATE OR REPLACE PACKAGE PKEXPEDIENTES
AS

-- PARA LAS PRUEBAS
PROCEDURE ACTUALIZATIPOENTIDAD;

-- Formatea año/numero de expediente con ceros por delante.
FUNCTION FormatYearNumExpe(xYEAR  IN  char, xNum   IN  integer) RETURN VARCHAR2;

-- Devuelve un Código de Operación y lo guarda en LAST_NUMERO de la tabla USUARIOS
FUNCTION GetCodigoOperacion RETURN INTEGER;

-- Actualiza el número de recibos (campo RECIBOS) de un expediente
PROCEDURE PonCuantosValoresVivosExpe(xIDExpe IN INTEGER);

-- Inserta en SEGUIMIENTO una Anotación.
PROCEDURE AnotaTextoInformaSegui(xIDEXPE IN INT, xCOMENT IN VARCHAR, xFECHA IN DATE);

-- Rellena la variable varComoCreoExpe.
PROCEDURE ComoCreoExpe;

-- Comprueba si existe un expediente vivo para un deudor y lo devuelve.
FUNCTION ExisteExpeVivoDeudor(
	xNIF IN CONTRIBUYENTES.NIF%Type,
	xAYTO IN MUNICIPIOS.AYTO%Type, 
	xIDExpe OUT INT) RETURN BOOLEAN;

-- Devuelve si un expediente está vivo.
FUNCTION ExisteExpeVivoDeudor(xIDExpe IN INT)
	RETURN BOOLEAN;

-- Comprueba si es invitado de un expediente vivo
FUNCTION CheckGuestExpeLive(
	xNIF IN CONTRIBUYENTES.NIF%Type,
	xAYTO IN MUNICIPIOS.AYTO%Type, 
	xIDExpe OUT INT)
	RETURN BOOLEAN;

-- Crea un Expediente Con Numeración AUTOMATICA.
PROCEDURE MakeExpe(xNIF IN CONTRIBUYENTES.NIF%Type, 
	xAYTO IN MUNICIPIOS.AYTO%Type, 
	xZONA IN MUNICIPIOS.ZONA%Type,
	xFECHA IN DATE);

-- Crea un Expediente Con Numeración MANUAL.
PROCEDURE MakeExpe(xNIF IN CONTRIBUYENTES.NIF%Type,
		xAYTO IN MUNICIPIOS.AYTO%Type,
		xZONA IN MUNICIPIOS.ZONA%Type,
		xNumeroExpediente IN CHAR,
		xFECHA IN DATE);

-- Añade un valor a un expediente.
PROCEDURE AgregarValorExpe(xIDVALOR IN VALORES.ID%Type, 
	xAYTO IN MUNICIPIOS.AYTO%Type, 
	xIDExpe IN INT);

-- Añade los valores de un NIF , de los INVITADOS y de los motes del NIF a un expediente.
PROCEDURE AgregarValoresExpe(xNIF IN CONTRIBUYENTES.NIF%Type, 
	xAYTO IN MUNICIPIOS.AYTO%Type, 
	xIDExpe IN INT);

-- Genera automaticamente el ID de expediente y el número de expediente
PROCEDURE NewNumberExpe( 
	xAYTO IN CHAR,
	xIDExpe OUT INT, 
	xExpediente  OUT char );


-- 0 Creación MANUAL de expedientes. 
-- 1 Creación AUTOMÁTICA de expedientes cuando se acuse la notificacion
varComoCreoExpe INT; 

--Tipo de entidad municipal: 
--Ayuntamientos pequeños (A).
--Ayuntamientos grandes (G): pueden tener mas de un alcalde por distrito, tesorero, etc.
--Entidades SupraMunicipales (S): Mancomunidades y Diputaciones.
--Comunidades Autonomas o Administración Central (C).
--Modo de funcionamiento ASP (X)
-- Los modos A,G,S,C son de Entidades PUBLICAS. El modo X es el único de Entidad PRIVADA.
varPublicoPrivado CHAR(1); 
 

LastExpediente char(10);
LastIDExpediente INT;

END;
/


/* ********************** CUERPO DEL PAQUETE ************************* */


CREATE OR REPLACE PACKAGE BODY PKEXPEDIENTES
AS



PROCEDURE ACTUALIZATIPOENTIDAD
AS
BEGIN

  SELECT TIPO_ENTIDAD INTO varPublicoPrivado
   FROM CONFIGURACION WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

END;

/* ****************************************************************************** */
-- Formatea año/numero de expediente con ceros por delante.
/*INTERNO*/
/* ****************************************************************************** */
FUNCTION FormatYearNumExpe(xYEAR  IN  char, xNum   IN  integer)
RETURN VARCHAR2
AS
BEGIN

  RETURN xYear || '/' || LPAD(xNum,5,'0');

END;

/* ****************************************************************************** */
-- Devuelve un Código de Operación y lo guarda en LAST_NUMERO de la tabla USUARIOS
/*INTERNO*/
/* ****************************************************************************** */
FUNCTION GetCodigoOperacion
RETURN INTEGER
AS
  mOperacion INT;

BEGIN

  SELECT GENCodOpeValres.NEXTVAL INTO mOperacion FROM DUAL;

  UPDATE USUARIOS SET LAST_NUMERO=mOperacion
     WHERE USUARIO=USER; 

  RETURN mOperacion;

END;

/* ****************************************************************************** */
-- Actualiza el número de recibos (campo RECIBOS) de un expediente 
--
-- Modificado: 18/06/2003. Lucas Fernández Pérez. Actualizaba sólamente el número de
--	recibos pendientes que había en el expediente (campo RECIBOS). 
-- Ahora también actualiza el número de recibos suspendidos (campo CUANTOS_R_SUSPEN)
--
/*INTERNO*/
/* ****************************************************************************** */
PROCEDURE PonCuantosValoresVivosExpe(xIDExpe IN INTEGER)

AS

   xCuantos 	  INTEGER DEFAULT 0;
   xCuantosSuspen INTEGER DEFAULT 0;

BEGIN

  -- Recibos pendientes dentro de un expediente
  SELECT COUNT(*) INTO xCuantos
  FROM VALORES 
  WHERE EXPEDIENTE=xIDExpe
	AND FECHA_DE_BAJA IS NULL 
	AND F_INGRESO IS NULL
	AND F_SUSPENSION IS NULL;

  -- Recibos suspendidos dentro de un expediente
  SELECT COUNT(*) INTO xCuantosSuspen
  FROM VALORES 
  WHERE EXPEDIENTE=xIDExpe
	AND FECHA_DE_BAJA IS NULL 
	AND F_INGRESO IS NULL
	AND F_SUSPENSION IS NOT NULL;

  -- ACTUALIZAR EL CONTADOR DE RECIBOS PENDIENTES Y SUSPENDIDOS EN EL EXPEDIENTE 
  UPDATE EXPEDIENTES SET RECIBOS=xCuantos, CUANTOS_R_SUSPEN=xCuantosSuspen
  WHERE ID=xIDExpe
	AND F_INGRESO IS NULL 
	AND F_ANULACION IS NULL;

END;

/* ************************************************************ */
-- Inserta en SEGUIMIENTO una Anotación.
/*INTERNO*/
/* ************************************************************ */
PROCEDURE AnotaTextoInformaSegui(xIDEXPE IN INT, xCOMENT IN VARCHAR,xFECHA IN DATE)

AS

BEGIN

  INSERT INTO SEGUIMIENTO 
     (ID_EXPE,F_ACTUACION,DESCRIPCION)
  VALUES
     (xIDEXPE, xFECHA, xCOMENT);

END;

/* ****************************************************************************** */
-- Rellena la variable varComoCreoExpe con el Modo de Creacion de Expedientes:
-- 0 -> MANUAL 1 -> AUTOMATICO
/*BASE*/
/* ****************************************************************************** */
PROCEDURE ComoCreoExpe
AS
BEGIN

  SELECT EXPEDIENTES INTO varComoCreoExpe
   FROM ZONAS
   WHERE zona=(select zona from usuarios where usuario=user);

END;

/* ****************************************************************************** */
-- Comprueba si existe expediente vivo al deudor
/*BASE*/
/* ****************************************************************************** */
FUNCTION ExisteExpeVivoDeudor(
	xNIF IN CONTRIBUYENTES.NIF%Type, 
	xAYTO IN MUNICIPIOS.AYTO%Type, 
	xIDExpe OUT INT)
RETURN BOOLEAN
AS
  vReturn BOOLEAN default True;

BEGIN

  vReturn:=True;

  IF varPublicoPrivado='X' THEN
    begin
      SELECT ID INTO xIDExpe
      FROM EXPEDIENTES
      WHERE DEUDOR=xNIF 
		AND f_ingreso is null 
		AND f_anulacion is null
		AND AYTO=xAYTO;
      exception
        when no_data_found then
          vReturn:=False;
          xIDExpe:=NULL;
   end;
  ELSE

   begin
     SELECT ID INTO xIDExpe
      FROM EXPEDIENTES
      WHERE DEUDOR=xNIF 
		AND f_ingreso is null 
		AND f_anulacion is null;
     exception
       when no_data_found then
         vReturn:=False;
         xIDExpe:=NULL;
   end;

  END IF;

  RETURN vReturn;

END;

/* ********************************************************************** */
-- Indica si un expediente esta vivo,es decir, sin ingresar ni anular.
/*NO ES LLAMADO POR NADIE*/
/* ********************************************************************** */
FUNCTION ExisteExpeVivoDeudor(xIDExpe IN INT)
RETURN BOOLEAN
AS
vReturn BOOLEAN default True;
xNada INT;

BEGIN

   vReturn:=True;
   begin
     SELECT ID INTO xNada
        FROM EXPEDIENTES
        WHERE ID=xIDExpe
	  AND f_ingreso is null 
	  AND f_anulacion is null;
     exception
     when no_data_found then
        vReturn:=False;
   end;

   RETURN vReturn;

END;

/* ************************************************************ */
-- Comprueba si es un invitado en un expediente activo
--
-- Modificado: 14/03/2005. Lucas Fernández Pérez.
-- Antes miraba si el nif era invitado de un expediente, y luego 
--   en otro select si ese expediente estaba abierto.Esto fallaba 
--   si hay más de 1 expediente ingresado/anulado del mismo NIF con 
--   tupla en guest expe. Por este motivo se funden esos 2 select en uno.
--
/*BASE*/
/* ************************************************************ */
FUNCTION CheckGuestExpeLive(
	xNIF IN CONTRIBUYENTES.NIF%Type,
	xAYTO IN MUNICIPIOS.AYTO%Type, 
	xIDExpe OUT INT)
RETURN BOOLEAN
AS
vReturn BOOLEAN default True;
xNADA INT;

BEGIN

     
-- Nos dice si es un invitado en un expediente abierto

   IF varPublicoPrivado='X' THEN

      Select G.Expediente INTO xIDExpe
         from guest_expe G, expedientes E
         where G.Expediente=E.ID AND G.NIF=xNIF 
	   AND G.AYTO=xAYTO
   	   AND G.TIPO='A'
       AND E.f_ingreso is null
       AND E.f_anulacion is null;

   ELSE

      Select G.Expediente INTO xIDExpe
         from guest_expe G, expedientes E
         where G.Expediente=E.ID AND G.NIF=xNIF 
   	   AND G.TIPO='A'
       AND E.f_ingreso is null
       AND E.f_anulacion is null;

   END IF;

   RETURN vReturn;

   exception
     when no_data_found then
       vReturn:=False;
       xIDExpe:=NULL;

   RETURN vReturn;

END;



/* ************************************************************ */
-- CREA EL NUEVO EXPEDIENTE 
-- Numeración automática
/*BASE*/
/* ************************************************************ */
PROCEDURE MakeExpe(
	xNIF IN CONTRIBUYENTES.NIF%Type,
	xAYTO IN MUNICIPIOS.AYTO%Type,
	xZONA IN MUNICIPIOS.ZONA%Type,
	xFECHA IN DATE)
AS

xIDExpe INT;
xExpediente CHAR(10);

BEGIN

  -- Obtiene el ID y numero de expediente automaticamente.
  NewNumberExpe(xAYTO, xIDExpe, xExpediente);

  IF varPublicoPrivado='X' THEN

     INSERT INTO EXPEDIENTES(ID, EXPEDIENTE, F_APERTURA, AYTO, ZONA, DEUDOR)
         VALUES (xIDExpe, xExpediente, xFecha, xAYTO, xZONA, xNIF);
  ELSE

     INSERT INTO EXPEDIENTES(ID, EXPEDIENTE, F_APERTURA, ZONA, DEUDOR)
         VALUES (xIDExpe, xExpediente, xFecha, xZONA, xNIF);

  END IF;

  AnotaTextoInformaSegui(xIDExpe,'SE HA CREADO UN EXPEDIENTE',xFECHA);

  AgregarValoresExpe(xNIF, xAYTO, xIDExpe);

  -- Los trabajos del titular del expediente los hago apuntar al nuevo expediente del titular
  UPDATE SALARIOS SET IDEXPE=xIDEXPE where NIF=xNIF; 									

  LastExpediente:=xExpediente;
  LastIDExpediente:=xIDExpe;

END;

/* ********************************************************************************* */
-- CREA EL NUEVO EXPEDIENTE 
-- Numeración indicada por el usuario
-- esta opción sirve principalmente cuando se arranca con la aplicación por primera
-- vez para poder ponerse al día con todos los expedientes que se tiene abiertos
-- con un programa anterior
/*BASE*/
/* ********************************************************************************* */
PROCEDURE MakeExpe(
	xNIF IN CONTRIBUYENTES.NIF%Type,
	xAYTO IN MUNICIPIOS.AYTO%Type,
	xZONA IN MUNICIPIOS.ZONA%Type, 
	xNumeroExpediente IN CHAR,
	xFECHA IN DATE)
AS

xIDExpe INT;
xExpediente CHAR(10);

BEGIN

  -- AUMENTAR EL ID DE EXPEDIENTES 
  SELECT GENIdExpe.NEXTVAL INTO xIDExpe FROM DUAL;

  IF varPublicoPrivado='X' THEN
     INSERT INTO EXPEDIENTES(ID, EXPEDIENTE, F_APERTURA, AYTO, ZONA, DEUDOR)
        VALUES (xIDExpe, xNumeroExpediente, xFecha, xAYTO, xZONA, xNIF);
  ELSE

     INSERT INTO EXPEDIENTES(ID, EXPEDIENTE, F_APERTURA, ZONA, DEUDOR)
        VALUES (xIDExpe, xNumeroExpediente, xFecha, xZONA, xNIF);

  END IF;

  AnotaTextoInformaSegui(xIDExpe,'SE HA CREADO UN EXPEDIENTE',xFECHA);

  AgregarValoresExpe(xNIF, xAYTO, xIDExpe);

  -- Los trabajos del titular del expediente los hago apuntar al nuevo expediente del titular
  UPDATE SALARIOS SET IDEXPE=xIDEXPE where NIF=xNIF; 									

  LastExpediente:=xNumeroExpediente;
  LastIDExpediente:=xIDExpe;

END;


/* ************************************************************ */
-- Añade un valor a un expediente.
/*BASE*/
/* ************************************************************ */
PROCEDURE AgregarValorExpe(
	xIDVALOR IN VALORES.ID%Type,
	xAYTO IN MUNICIPIOS.AYTO%Type,
	xIDExpe IN INT)
AS
   xCodOperacion INT;
BEGIN

xCodOperacion:=GetCodigoOperacion;

  IF varPublicoPrivado='X' THEN
    UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,
	CODIGO_OPERACION=xCodOperacion
    WHERE ID=xIDValor	
	and ayto=xAyto
	and f_ingreso is null 
	and fecha_de_baja is null
      and expediente is null 
	and notificado='S';
  ELSE
    UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,
	CODIGO_OPERACION=xCodOperacion
    WHERE ID=xIDValor	
	and f_ingreso is null 
	and fecha_de_baja is null
      and expediente is null 
	and notificado='S';
  END IF;

  -- AUMENTAR EL CONTADOR DE RECIBOS EN EL EXPEDIENTE 
  PonCuantosValoresVivosExpe(xIDExpe);

END;

/* ************************************************************************************ */
-- Añade a un expediente los valores de un NIF. 
-- Ademas se mira si el NIF tiene Motes. Si los tiene, agrega los valores de los Motes.
-- Estos valores de los NIF motes es imposible que esten en otro expediente porque
-- al crear un expediente sobre un valor de un Mote se crea con el NIF verdadero.
-- Y además porque si hay un NIF con expediente no te deja que sea mote de otro NIF.
-- Del mismo modo, mira si el expediente tiene INVITADOS, agregando los valores de estos.
-- Modificado: 07/05/2003. Agustín León Robles.
-- 		Estaba siempre incluyendo en el Expediente independientemente de cual fuera la 
--		configuración. En ATECO se crean expedientes por municipios.
/*BASE*/
/* ************************************************************************************ */
PROCEDURE AgregarValoresExpe(
	xNIF IN CONTRIBUYENTES.NIF%Type, 
	xAYTO IN MUNICIPIOS.AYTO%Type,
	xIDExpe IN INT)
AS
  xCodOperacion INT;

  --valores de los DNI incorrectos o motes de un ayuntamiento
  CURSOR C1X IS 
	SELECT ID FROM VALORES 
      WHERE NIF IN (SELECT ALIASNIF FROM ALIASDNI WHERE NIFBUENO=xNIF)
  	  and ayto=xAyto
	  and f_ingreso is null 
	  and fecha_de_baja is null
        and expediente is null 
	  and notificado='S'
	FOR UPDATE OF EXPEDIENTE, F_IN_EXPEDIENTE,CODIGO_OPERACION;

  --valores de los DNI incorrectos o invitados de un ayuntamiento
  CURSOR C2X IS 
	SELECT ID FROM VALORES 
      WHERE NIF IN (SELECT NIF FROM GUEST_EXPE WHERE EXPEDIENTE=xIdExpe AND AYTO=xAYTO)
	  and ayto=xAyto
	  and f_ingreso is null 
	  and fecha_de_baja is null
	  and expediente is null 
	  and notificado='S'
	FOR UPDATE OF EXPEDIENTE, F_IN_EXPEDIENTE,CODIGO_OPERACION;

  --valores de los DNI incorrectos o motes
  CURSOR C1 IS 
	SELECT ID FROM VALORES 
      WHERE NIF IN (SELECT ALIASNIF FROM ALIASDNI WHERE NIFBUENO=xNIF)
	  and f_ingreso is null 
	  and fecha_de_baja is null
        and expediente is null 
	  and notificado='S'
	FOR UPDATE OF EXPEDIENTE, F_IN_EXPEDIENTE,CODIGO_OPERACION;

  --valores de los DNI incorrectos o invitados 
  CURSOR C2 IS 
	SELECT ID FROM VALORES 
      WHERE NIF IN (SELECT NIF FROM GUEST_EXPE WHERE EXPEDIENTE=xIdExpe)
	  and f_ingreso is null 
	  and fecha_de_baja is null
        and expediente is null 
	  and notificado='S'
	FOR UPDATE OF EXPEDIENTE, F_IN_EXPEDIENTE,CODIGO_OPERACION;
BEGIN

	xCodOperacion:=GetCodigoOperacion;

	IF varPublicoPrivado='X' THEN
		--meter dentro del expediente todos los valores que esten notificados del mismo municipio
		UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,CODIGO_OPERACION=xCodOperacion
		WHERE NIF=xNIF and Ayto=xAyto
			and f_ingreso is null 
			and fecha_de_baja is null
			and expediente is null 
			and notificado='S';
	else
		--meter dentro del expediente todos los valores que esten notificados 
		UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,CODIGO_OPERACION=xCodOperacion
		WHERE NIF=xNIF 
			and f_ingreso is null 
			and fecha_de_baja is null
			and expediente is null 
			and notificado='S';

	end if;

	IF varPublicoPrivado='X' THEN

		-- Rastrear por si hubiera alguno sin expediente
		For v_C1 IN C1X LOOP -- Busca valores sobre Alias del NIF
			UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,CODIGO_OPERACION=xCodOperacion
			WHERE ID=v_C1.ID;
		END LOOP;

		For v_C2 IN C2X LOOP -- Y sobre los invitados al expediente
			UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,CODIGO_OPERACION=xCodOperacion
			WHERE ID=v_C2.ID;
		END LOOP;

	ELSE

		-- Rastrear por si hubiera alguno sin expediente
		For v_C1 IN C1 LOOP -- Busca valores sobre Alias del NIF
			UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,CODIGO_OPERACION=xCodOperacion
			WHERE ID=v_C1.ID;
		END LOOP;

		For v_C2 IN C2 LOOP -- Y sobre los invitados al expediente
			UPDATE valores SET expediente=xIdExpe, f_in_expediente=SYSDATE,CODIGO_OPERACION=xCodOperacion
			WHERE ID=v_C2.ID;

		END LOOP;

	END IF;
 
	-- AUMENTAR EL CONTADOR DE RECIBOS EN EL EXPEDIENTE 
	PonCuantosValoresVivosExpe(xIDExpe);

END;

/* ********************************************************************* */
-- Genera automaticamente el ID de expediente y el número de expediente
/*INTERNO*/
/* ********************************************************************* */
PROCEDURE NewNumberExpe( 
	xAYTO IN CHAR,
	xIDExpe OUT INT, 
	xExpediente  OUT char )
AS

xYEAR CHAR(4);
xNUMERO INTEGER;

BEGIN

  IF varPublicoPrivado='X' THEN

	UPDATE MUNICIPIOS SET CONT_EXPE=CONT_EXPE+1
         WHERE AYTO=xAYTO
	RETURNING CONT_EXPE,YEAR_EXPE INTO xNUMERO,xYEAR;

  ELSE

	UPDATE CONTADOREXPE SET CONT_EXPE=CONT_EXPE+1
   	   WHERE CONT_EXPE IS NOT NULL 
	RETURNING CONT_EXPE,YEAR_EXPE INTO xNUMERO,xYEAR;

  END IF;

  -- AUMENTAR EL ID DE EXPEDIENTES 
  SELECT GENIdExpe.NEXTVAL INTO xIDExpe FROM DUAL;
 
  xExpediente:=FormatYearNumExpe(xYEAR, xNUMERO);

END;


/* ************************************************************ */
/* INICIALIZACION DEL PAQUETE. CARGA LA VARIABLE DE COMO HAY QUE GENERAR LOS EXPEDIENTES */
BEGIN

	SELECT EXPEDIENTES INTO varComoCreoExpe
	FROM ZONAS WHERE zona=(select zona from usuarios where usuario=user);

	SELECT TIPO_ENTIDAD INTO varPublicoPrivado FROM CONFIGURACION
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

END;
/


/* ************************************************************************************ */
/*  FIN DEL PAQUETE */
/* ************************************************************************************ */

/* ************************************************************************************ */
-- Pone un nuevo año de trabajo en la aplicación.
-- Va a tener una doble funcionalidad en función del tipo de entidad 
-- 1. para los recaudadores privados lo pondrá en la tabla de MUNICIPIOS y
-- 2. para el resto de entidades será en la tabla CONTADOREXPE
/*DELPHI*/
/* ************************************************************************************* */
CREATE OR REPLACE PROCEDURE PUT_YEAR_WORK_Expe(NuevoYear IN CHAR)
AS
   oldConta		Integer;
   varPublicoPrivado VARCHAR(1);

   CURSOR CMUNI IS SELECT AYTO FROM MUNICIPIOS;

BEGIN

  SELECT TIPO_ENTIDAD into varPublicoPrivado FROM CONFIGURACION 
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

  IF varPublicoPrivado='X' THEN -- Recaudadores Privados, cambia la tabla municipios 

    FOR v_MUNI IN CMUNI LOOP -- Ajusto el contador y año municipio a municipio  

      SELECT MAX(SUBSTR(EXPEDIENTE, 6, 5)) INTO OldConta FROM EXPEDIENTES
         WHERE SUBSTR(EXPEDIENTE,1,4)=NuevoYear AND AYTO=v_MUNI.AYTO;

      IF OldConta IS NOT NULL then
	   UPDATE MUNICIPIOS SET CONT_EXPE=OldConta, YEAR_EXPE=NuevoYear WHERE AYTO=v_MUNI.AYTO;
      ELSE
	   UPDATE MUNICIPIOS SET CONT_EXPE=0, YEAR_EXPE=NuevoYear WHERE AYTO=v_MUNI.AYTO;
      END IF;

    END LOOP;

  ELSE -- Recaudadores Públicos, no va por municipio, cambia la tabla CONTADOREXPE

    SELECT MAX(SUBSTR(EXPEDIENTE, 6, 5)) INTO OldConta FROM EXPEDIENTES
       WHERE SUBSTR(EXPEDIENTE,1,4)=NuevoYear;

    IF OldConta IS NOT NULL then
       UPDATE CONTADOREXPE SET CONT_EXPE=OldConta,YEAR_EXPE=NuevoYear;
    ELSE
       UPDATE CONTADOREXPE SET CONT_EXPE=0,YEAR_EXPE=NuevoYear;
    END IF;

  END IF;

END;
/
