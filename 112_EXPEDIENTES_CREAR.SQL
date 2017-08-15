-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

--
-- ******************************************************************************
--
--       Para cualquier duda Carpeta de documentación técnica fichero 1001
--
-- *******************************************************************************


-- PEGAR UN VALOR A UN EXPEDIENTE 
-- El expediente debe existir.
-- Con el parametro xCuantos indicamos si queremos que pege un sólo valor
-- o todos los valores que aún estén pendientes
--  xCuantos 1:un solo valor; 0:todos los notificados
/*DELPHI*/
CREATE OR REPLACE PROCEDURE PEGA_EXPE(
		xIDExpe		IN   INT,
		xValor		IN   INT,
		xCuantos	IN   INT, 
		xPosible	OUT   INT)
AS

xIDAcumula INT;
xNIF CHAR(10);
xAYTO Char(3);

BEGIN

	xPosible:=1;

	-- Comprueba si hay un expediente vivo. Si lo hay, obtiene su AYTO.
	SELECT AYTO INTO xAYTO FROM EXPEDIENTES WHERE ID=xIDExpe 
			AND F_INGRESO IS NULL 
			AND F_ANULACION IS NULL;

	-- Para un solo valor
	IF (xCuantos=1) THEN
		PkEXPEDIENTES.AgregarValorExpe(xValor, xAyto, xIDExpe);
	ELSE 

		-- Averiguar el NIF del deudor
		SELECT NIF INTO xNIF FROM VALORES
		WHERE ID=xVALOR
				AND EXPEDIENTE IS NULL
				AND F_INGRESO IS NULL
				AND FECHA_DE_BAJA IS NULL;

		-- Agregar los valores pendientes
		PkEXPEDIENTES.AgregarValoresExpe(xNIF, xAyto, xIDExpe);
	END IF;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		xPosible:=0;

END;
/

-- PASA LOS RECIBOS APREMIADOS A EXPEDIENTES. EN CASO DE QUE EXISTA EXPEDIENTE ABIERTO
-- QUE ESTE VIVO ACUMULA
-- Pasar los valores que cumplen la condicón del art. 108 RGR a un expediente
-- en caso de que haya un expediente vivo abierto sumarselo a este
--
-- IMPORTANTE: El NIF de entrada puede ser un MOTE de otro NIF VERDADERO. En ese caso
-- el Expediente se crea o añade al del Nombre del NIF VERDADERO, no del NIF de entrada.
-- Revisa MOTES e INVITADOS.
/*BASE*/

CREATE OR REPLACE PROCEDURE APREMIADOS_A_EXPEDIENTE(
        xNIF         IN CHAR,
        xAYTO        IN CHAR,
	  xZONA 	   IN CHAR)
AS
xIDExpe   INT;
xNIFBueno VARCHAR(10);
xVALIDADO CHAR(1);
BEGIN
 
   -- Si es un NIF declarado como falso no se le puede crear un expediente
   SELECT VALIDADO INTO xVALIDADO FROM CONTRIBUYENTES WHERE NIF=xNIF;
   IF xVALIDADO='F' THEN
      RETURN;
   END IF;

   --si no se puede crear expedientes ni pegar recibos no hace falta comprobar nada mas
   --En concreto, si el modo de creacion de expedientes es MANUAL, termino.
   PkEXPEDIENTES.ComoCreoExpe;
   IF PkEXPEDIENTES.varComoCreoExpe=0 THEN
      return;
   END IF;

   -- Pero puede que el NIF sea un MOTE de otro NIF, en cuyo caso genero el expediente
   -- con el NIF VERDADERO, o lo agrego en el del NIF VERDADERO, no el del mote. 
   -- Por eso busco si el NIF es de Mote o no.
   xNIFBueno:=GetAliasNIF(xNIF);
   IF xNIFBueno is Null THEN
	xNIFBueno:=xNIF;
   END IF;

   /*comprobar si existe expediente vivo al deudor*/
   IF PkEXPEDIENTES.ExisteExpeVivoDeudor(xNIFBueno,xAYTO,xIDExpe) THEN

	PkEXPEDIENTES.AgregarValoresExpe(xNIFBueno,xAYTO,xIDExpe);
	/* si hay creado un apunte sin notificar lo añadimos a la acumulacion
	existente en caso contrario creamos una acumulacion nueva*/

   ELSE

	/*comprobar si es un invitado en un expediente activo*/
	IF PkEXPEDIENTES.CheckGuestExpeLive(xNIFBueno, xAYTO, xIDExpe) THEN

         PkEXPEDIENTES.AgregarValoresExpe(xNIFBueno, xAYTO, xIDExpe);

	ELSE -- Genero un expediente nuevo.

	   PkEXPEDIENTES.MakeExpe(xNIFBueno, xAYTO, xZONA,SYSDATE);

	END IF;

   END IF;

END;
/


-- Montar los expedientes posibles a partir de todos los deudores de un cargo
-- Realiza la prelacion de embargo de cuentas.
-- Busca todos los valores de un cargo y municipio posibles de expedientar y los
-- expedienta.
-- Revisa MOTES e INVITADOS.
/*DELPHI*/

CREATE OR REPLACE PROCEDURE COMIENZA_PRELACION(
        xCargo 	IN	char,
        xAYTO 	IN	CHAR,
	  xUSUARIO	IN	CHAR)
AS

xIDExpe 		int;
xZona 		char(2);
xNIFBueno		char(10);
xVALIDADO CHAR(1);
-- Conjunto de deudores de un cargo de valores.
CURSOR VALOR_ID IS
    SELECT NIF FROM VALORES
    where N_CARGO=xCargo 
	AND AYTO=xAYTO 
	and Expediente is null
      and F_ingreso is null 
	and FECHA_DE_BAJA is null
      and F_SUSPENSION is null 
	and Notificado='S' 
	and vol_eje='E'
	GROUP BY NIF;


BEGIN


  SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=xUSUARIO;

/* leer todos los deudores del cargo que cumplan
     la condicion y crear los expedientes */

  FOR v_VALOR IN VALOR_ID LOOP

    -- Si es un NIF declarado como falso no se le puede crear un expediente
    SELECT VALIDADO INTO xVALIDADO FROM CONTRIBUYENTES WHERE NIF=v_VALOR.NIF;
    IF xVALIDADO<>'F' THEN
       
       -- Pero puede que el NIF sea un MOTE de otro NIF, en cuyo caso genero el expediente
       -- con el NIF VERDADERO, o lo agrego en el del NIF VERDADERO, no el del mote. 
       -- Por eso busco si el NIF es de Mote o no. 
       xNIFBueno:=GetAliasNIF(v_VALOR.NIF);
       IF xNIFBueno is Null THEN
	    xNIFBueno:=v_VALOR.NIF;
       END IF;
    
       -- Primero mira si el expediente esta ya creado. Si es así, añade el valor. 
       IF PkEXPEDIENTES.ExisteExpeVivoDeudor(xNIFBueno,xAYTO, xIDExpe) THEN
	    PkEXPEDIENTES.AgregarValoresExpe(xNIFBueno, xAYTO, xIDExpe);
       ELSE

	    -- comprobar si es un invitado en un expediente activo
	    IF PkEXPEDIENTES.CheckGuestExpeLive(xNIFBueno, xAYTO, xIDExpe) THEN

             PkEXPEDIENTES.AgregarValoresExpe(xNIFBueno, xAYTO, xIDExpe);

	     ELSE -- Genero un expediente nuevo.

	       PkEXPEDIENTES.MakeExpe(xNIFBueno, xAYTO, xZONA,SYSDATE);

	     END IF;

       END IF;

    END IF; -- xVALIDADO

  END LOOP;

  /* con este update creamos el lote */

  UPDATE EXPEDIENTES SET EMBARGO_1='P',
                         RETENIDO=0,
                         FECHA_RETENCION=NULL,
                         INTERES_DILIGENCIA=0
  WHERE ZONA=xZONA 
	AND EMBARGO_1='0' 
	AND F_INGRESO is null
    AND F_SUSPENSION is null 
	AND F_ANULACION is null
    AND RECIBOS > 0;

END;
/


-- Realizar todas las conprobaciones de filtrado de las circustancias posibles
-- para poder crear un expediente o agrupar recibos al expediente.
-- He añadido el tema de los motes de los contribuyentes.
-- Revisa MOTES e INVITADOS.
/*BASE*/

CREATE OR REPLACE PROCEDURE FiltroCreaExpe(
	xNIF IN CHAR,
	xAYTO IN CHAR,
	xTIPO	IN	INT,
	xExpManual 	IN CHAR,
	xIDExpe OUT INT,
	xFECHA IN DATE,
	xERROR OUT INT)

AS
xNIFBueno Char(10);
xZONA 	CHAR(2);

BEGIN

   xERROR:=0;

   -- Comprobar si es un mote de un nif bueno y si es el caso tomar el nif bueno
   xNIFBueno:=GetAliasNIF(xNIF);

   IF xNIFBueno is Null THEN
	xNIFBueno:=xNIF;
   END IF;
	
   IF PkEXPEDIENTES.ExisteExpeVivoDeudor(xNIFBueno, xAyto, xIDExpe) THEN

	PkEXPEDIENTES.AgregarValoresExpe(xNIFBueno, xAyto, xIDExpe);	
   	xERROR:=-1;

   ELSE
          -- Comprobar si es un invitado en un expediente activo
	IF PkEXPEDIENTES.CheckGuestExpeLive(xNIFBueno, xAyto, xIDExpe) THEN

	   PkEXPEDIENTES.AgregarValoresExpe(xNIFBueno, xAyto, xIDExpe);	   
         xERROR:=-3;

	ELSE

	   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	   IF xTIPO=0 THEN
		PkEXPEDIENTES.MakeExpe(xNIFBueno, xAyto, xZONA, xFecha);
		xIDExpe:=PkEXPEDIENTES.LastIDExpediente;
	   ELSE
			-- procedimiento sobrecargado 
		PkEXPEDIENTES.MakeExpe(xNIFBueno, xAyto, xZONA, xExpManual, xFecha);
		xIDExpe:=PkEXPEDIENTES.LastIDExpediente;
	   END IF;

	END IF;

   END IF;

END;
/

--
-- crear expedientes de forma manual, es decir por indicación del usuario, es la opción
-- de ventanilla de recaudación en el interfaz.
--
-- Si el programa funciona en modo ASP monta todos los expedientes posibles por municipio
-- para un deudor, es decir si un deudor tiene deudas en dos municipios distintos montará
-- dos expedietes uno para cada municipio. Mejora la versión anterior que el usuario tenia
-- que indicar municipio a municipio, pues solo lo hacia del seleccionado en pantalla.
--
/*DELPHI*/

CREATE OR REPLACE PROCEDURE ADD_MANUAL_EXPE(
	xTIPO			IN	INT,
      xNIF 			IN	CHAR,
      xExpManual 		IN	CHAR,
	xFecha		IN 	DATE)

AS

xCUENTA 	INT DEFAULT 0;
xRECIBOS 	INT;
xRESP INT;
xIDExpe INT;

CURSOR cVALORES IS SELECT AYTO FROM VALORES
	WHERE NIF=xNIF 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL
    AND EXPEDIENTE IS NULL 
	AND NOTIFICADO='S' 
	AND VOL_EJE='E'
	GROUP BY AYTO;

BEGIN

  xResp:=0;

  -- Comprobar el tipo de entidad para montar los expedientes
  -- por NIF o por Ayto+NIF

  IF PkEXPEDIENTES.varPublicoPrivado='X' THEN

    -- Filtro Ayto + NIF
    FOR v_Valores IN cValores Loop

       FiltroCreaExpe(xNIF, v_Valores.Ayto, xTipo, xExpManual, xIDExpe, xFecha, xResp);

    END LOOP;

  ELSE

    -- Sólo NIF
    SELECT COUNT(*) INTO xRecibos
	FROM VALORES
	WHERE NIF=xNIF 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL
    AND EXPEDIENTE IS NULL 
	AND NOTIFICADO='S' 
	AND VOL_EJE='E';

    IF xRECIBOS = 0 THEN
      -- No hay recibos para el expediente 
      update usuarios set LAST_TAREA=-2,LAST_NUMERO=0
	   where usuario=user;
      RETURN;
    END IF;

    FiltroCreaExpe(xNIF, Null, xTipo, xExpManual, xIDExpe, xFecha, xResp);

  END IF;


  -- Escribir el código de error y el número de expediete pues el driver de Oracle
  -- da un error si se devuelve por parametro de procedimiento
  update usuarios set LAST_TAREA=xResp, LAST_NUMERO=xIDExpe
	where usuario=user;

END;
/


--
-- Este forma de crear un expediente es para aquellos casos en que conozcamos el NIF
-- correcto del deudor pero no tengamos ningún recibo a este NIF, entonces creamos
-- este expediente en blanco y luego le pegamos los recibos que queremos que contenga
--
-- Actualmente existe otra forma de actuar que es tal vez más comoda para el usuario
-- que es crear el expediete a nombre del titular erroneo y en el interfaz de usuario
-- tenemos una opción que es cambiar titular, habilitada para el menester que su propio 
-- nombre indica, se guarda por compatibilidad con versiones anteriores y porque hay
-- usuarios de versiones anteriores que la conocen y quieren seguir así
--
-- Tipo=0 numeración del expediente automática
-- otro valor numeración manual, introducida por el usuario
/*DELPHI*/

CREATE OR REPLACE PROCEDURE EXPEDIENTE_BLANCO(
	xTIPO		IN	INTEGER,
	xAYTO		IN	CHAR,
      xNIF 		IN 	CHAR,
      xMANUAL 	IN 	CHAR,
	xFECHA	IN	DATE)
AS

xZONA 	CHAR(2);
xIDExpe INT;
xERROR   INT;

BEGIN

  xERROR:=0;

  IF PkEXPEDIENTES.varPublicoPrivado='X' THEN
	FiltroCreaExpe(xNIF, xAyto, xTipo, xManual, xIDExpe, xFecha, xERROR);
  ELSE
	FiltroCreaExpe(xNIF, NULL, xTipo, xManual, xIDExpe, xFecha, xERROR);
  END IF;
  

-- Escribir el código de error y el número de expediete pues el driver de Oracle
-- da un error si se devuelve por parametro de procedimiento

  update usuarios set LAST_TAREA=xERROR, LAST_NUMERO=xIDExpe
	where usuario=user;


END;
/

--
-- Añadir un invitado al expediente, es decir un mote, alias del NIF del expediente
-- para que todos los recibos notificados de apremio, pasen a este expediente sin
-- tener que estar atento a esta circustancia de forma manual. Cada vez que procesemos
-- una notificación de apremio de un recibo con este NIF de invitado, se agregará de
-- forma automática a este expediente. Es lo mismo que los motes sobre un contribuyente
-- pero, desde aqui sólo tendrá validez mientras el expediente este abierto, mieentras
-- que sobre el contribuyente esta circustancia será valida siempre.
--
-- Una restricción importante es que para poder ser invitado de un expediente no se puede 
-- tener un expediente abierto a este invitado, ni tampoco ser invitado de otro expediente.
-- Una vez que se añade como invitado se buscan todos los recibos pendientes que pudiera 
-- tener el invitado y se pegan al expediente.
--
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ADD_INVITADO(
        xNIF      IN CHAR,
	  xAyto	IN Char,
	  xIDEXPE   IN INTEGER,
        xOtroEXPE OUT INTEGER, 
	  xERROR    OUT INTEGER)

AS

xNOMBRE CONTRIBUYENTES.NOMBRE%Type;

BEGIN

   xError:=0;

   -- Para ser invitado no se puede tener un expediente abierto vivo 
   IF PKExpedientes.ExisteExpeVivoDeudor(xNIF, xAyto, xOtroEXPE) THEN
      xERROR:=2;
      return;
   END IF;

   IF PkEXPEDIENTES.CheckGuestExpeLive(xNIF, xAYTO, xOtroEXPE) THEN

      -- SOLO PUEDE SER INVITADO DE UN UNICO EXPEDIENTE 
	xERROR:=1;

   ELSE
  
	IF PkEXPEDIENTES.varPublicoPrivado='X' THEN
         INSERT INTO GUEST_EXPE (NIF,EXPEDIENTE,TIPO, AYTO)
      	VALUES (xNIF, xIDEXPE, 'A', xAYTO);
	ELSE
         INSERT INTO GUEST_EXPE (NIF,EXPEDIENTE,TIPO)
      	VALUES (xNIF, xIDEXPE, 'A');
	END IF;

	SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES
		WHERE NIF=xNIF;

	PkSeguimiento.NotaInformativa(xIDEXPE, 
	'SE AÑADE EL INVITADO NIF: '|| RTRIM(xNIF) || ' ' || RTRIM(xNOMBRE));

      -- BUSCAR TODOS SUS VALORES PARA PASARLOS AL EXPEDIENTE
	IF PkEXPEDIENTES.varPublicoPrivado='X' THEN
         UPDATE VALORES SET EXPEDIENTE=xIDEXPE,
   	                   F_IN_EXPEDIENTE=SYSDATE
         WHERE NIF=xNIF 
		AND AYTO=xAYTO
		AND EXPEDIENTE IS NULL 
		AND NOTIFICADO='S' 
		AND VOL_EJE='E' 
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL;
	ELSE
         UPDATE VALORES SET EXPEDIENTE=xIDEXPE,
   	                   F_IN_EXPEDIENTE=SYSDATE
         WHERE NIF=xNIF 
		AND EXPEDIENTE IS NULL 
		AND NOTIFICADO='S' 
		AND VOL_EJE='E' 
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL;
	END IF;

   END IF;

END;
/

--
-- Borrar un invitado de un expediente
--
/* DELPHI */
CREATE OR REPLACE PROCEDURE DEL_INVITADO(
	xID IN INTEGER, 
	xIDEXPE IN INT,
	xNIF CHAR,
	xNOMBRE CHAR)
AS
BEGIN

   DELETE FROM GUEST_EXPE WHERE ID=xID;

   PkSeguimiento.NotaInformativa(xIDEXPE, 
	'SE BORRA EL INVITADO NIF: '|| RTRIM(xNIF) || ' ' || RTRIM(xNOMBRE));

END;
/

