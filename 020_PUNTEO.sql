-- Creado: 27 de Febrero del 2002. Agustin Leon Robles
-- Solo para el Organismo de Motril, son datos necesarios en los discos que hay que darle
-- al Ayuntamiento de Motril con los ingresos y bajas que se han producido
--
-- Modificado: 07/11/2002. Se rellena tambien el campo RECARGO_JUNTA de la tabla AS_400
--
create or replace procedure PasaRestoDatos(
			xID 			IN integer,
			xCENTRO_GESTOR 	in char,
			xOFICINA_LIQUI 	in char,
			xN_ORDEN_VALOR 	in char,
			xCERT_DESCUBIERTO in char,
			xRECARGO		in float
			)
as
begin

	insert into VALORES_AS400
	(VALOR,CENTRO_GESTOR,OFICINA_LIQUI,N_CERTIFICACION,N_ORDEN_VALOR,RECARGO_JUNTA)
	values (xID,xCENTRO_GESTOR,xOFICINA_LIQUI,xCERT_DESCUBIERTO,xN_ORDEN_VALOR,xRECARGO);

end;
/


-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez
-- Se han realizado cambios.(Round en Insert)
-- -----------------------------------------------------
-- Modificado: 16/02/2005. Gloria Maria Calle. Cambia el procedimiento pues cambia la 
-- 			estructura de la tabla desglose_valores a una linea. Se supone que se llama
--			con todos los importes sobre el valor en una llamada, por eso sólo se da de alta 
--			con el primer importe si no existe.
--
--
--

CREATE OR REPLACE PROCEDURE PASAR_DESGLOSE(
	xValor 	IN	INTEGER,
	xImpo1 	IN	float,
	xImpo2 	IN	float,
    xImpo3 	IN	float,
	xImpo4 	IN	float,
    xImpo5 	IN	float,
	xImpo6 	IN	float,
    xImpo7 	IN	float,
    xTitulo1 	IN	varchar,
	xTitulo2 	IN	varchar,
    xTitulo3 	IN	varchar,
	xTitulo4 	IN	varchar,
    xTitulo5 	IN	varchar,
	xTitulo6 	IN	varchar,
    xTitulo7 	IN	varchar)
AS
BEGIN

   if xImpo1 > 0 then
      update DESGLOSE_VALORES set DESCRIPCION1=xTitulo1,
      							  IMPORTE1=ROUND(xImpo1,2)
       where VALOR=xValor;
       
      if (sql%notfound) then
          insert into DESGLOSE_VALORES (VALOR,DESCRIPCION1,IMPORTE1)
          values (xValor,xTitulo1,ROUND(xImpo1,2));
      end if;
   end if;

   if xImpo2 > 0 then
      update DESGLOSE_VALORES set DESCRIPCION2=xTitulo2,
      							  IMPORTE2=ROUND(xImpo2,2)
       where VALOR=xValor;
   end if;

   if xImpo3 > 0 then
      update DESGLOSE_VALORES set DESCRIPCION3=xTitulo3,
      							  IMPORTE3=ROUND(xImpo3,2)
       where VALOR=xValor;
   end if;

   if xImpo4 > 0 then
      update DESGLOSE_VALORES set DESCRIPCION4=xTitulo4,
      							  IMPORTE4=ROUND(xImpo4,2)
       where VALOR=xValor;
   end if;

   if xImpo5 > 0 then
      update DESGLOSE_VALORES set DESCRIPCION5=xTitulo5,
      							  IMPORTE5=ROUND(xImpo5,2)
       where VALOR=xValor;
   end if;

   if xImpo6 > 0 then
      update DESGLOSE_VALORES set DESCRIPCION6=xTitulo6,
      							  IMPORTE6=ROUND(xImpo6,2)
       where VALOR=xValor;
   end if;

   if xImpo7 > 0 then
      update DESGLOSE_VALORES set DESCRIPCION7=xTitulo7,
      							  IMPORTE7=ROUND(xImpo7,2)
       where VALOR=xValor;
   end if;

END;
/

--
-- Controla que no haya datos mezclados de recibos y liquidaciones
-- ademas de crear el cargo y el detalle
--
CREATE OR REPLACE PROCEDURE AnalizaCargo(
	xCARGO IN CHAR,
	xTipo  OUT CHAR,
	xError OUT INTEGER)
AS

BEGIN

xError:=0;

BEGIN
	SELECT TIPO_DE_OBJETO INTO xTIPO FROM PUNTEO
		WHERE N_CARGO=xCARGO
		GROUP BY TIPO_DE_OBJETO;
EXCEPTION
	When TOO_MANY_ROWS then
	xError:=1;
	RETURN;
	WHEN OTHERS THEN
	xError:=2;
	RETURN;

END;


-- Insertamos el nuevo cargo
--
INSERT INTO CARGOS (CARGO, AYTO, F_CARGO, VOL_EJE, RECIBOS, TOTAL_CARGO )

SELECT xCARGO, AYTO, F_CARGO, VOL_EJE, COUNT(*), ROUND( SUM(PRINCIPAL), 2)
FROM PUNTEO
WHERE N_CARGO=xCARGO
GROUP BY AYTO, F_CARGO, VOL_EJE;

IF xTIPO='R' THEN

	-- Insertamos el desglose de los cargos

	INSERT INTO DESGLOSE_CARGOS
	(CARGO,AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO,
	INI_PER_VOLUN, FIN_PER_VOLUN, RECIBOS, TOTAL_CARGO)

	SELECT xCARGO,AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO,
	INI_PE_VOL, FIN_PE_VOL, COUNT(*), ROUND( SUM(PRINCIPAL), 2)

	FROM PUNTEO
	WHERE N_CARGO=xCARGO
	GROUP BY AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO,INI_PE_VOL,FIN_PE_VOL;

ELSE
	-- Liquidaciones

	-- Insertamos el desglose de los cargos

	INSERT INTO DESGLOSE_CARGOS
	(CARGO,AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO,
	RECIBOS, TOTAL_CARGO)

	SELECT xCARGO,AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO,
	COUNT(*), ROUND( SUM(PRINCIPAL), 2)

	FROM PUNTEO
	WHERE N_CARGO=xCARGO
	GROUP BY AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO;

END IF;


END;
/

--
-- Se trata de incorporar las deudas tributarias que tenemos en la tabla temporal llamada
-- punteo. La tabla punteo sirve para que se puedan hacer comprobaciones previas a un cargo.
-- Coinciden los importes, el número de recibos, etc.
-- Una vez se comprueba su validez, el recaudador, incorporará el cargo que se encuentra en el
-- punto a la tabla de valores.
--
-- Los datos que se incorporan a valores pueden ser de datos que gestionamos con
-- nuestra aplicación de gestión tributaria o externo a nuestra gestión.
--
-- xExterno: significa que si el cargo viene a traves de programas externos, entonces
-- hay que insertar un contribuyentes en caso de no existir en nuestra base de datos. También
-- comprobamos si es mote de NIF bueno, en caso afirmativo insertamos en NIF bueno.
--

--Modificado: 10/10/2002 Agustín León Robles
--si el cargo es de ejecutiva se comprueba si el contribuyente esta declarado
--como insolvente, entonces el valor pasa directamente a estar propuesto de baja
--por referencia
--
-- Modificado: 17/10/2002 Antonio Pérez Caballero
-- Se a añadido un campo nuevo a la tabla de valores, pues en los cargos de la Junta
-- de Andalucía el ingresado fuera de plazo podía ser superior al principal hemos
-- añadido en valores ENTREGAS_ANTESDEL_CARGO y se le pasa desde punteo en entregas_a_cuenta
-- para poder controlar esta nueva situación
--

--
--Modificado: 27/11/2002 Agustín León Robles
--En el fichero de contribuyentes no se grababa el código de la via del domicilio fiscal
--
--
--Modificado: 17/01/2003 Agustín León Robles
--Cuando se hacen los ingresos de la Junta la fecha de ingreso se cambia a "sysdate" en vez de "fin_pe_vol+1"
--

--Modificado: 26/05/2003 M. Carmen Junco Gómez.
--Si se ha de proponer de baja por insolvencia, tendremos que insertar una tupla
--en PROPUESTAS_BAJA

--Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
--
CREATE OR REPLACE PROCEDURE PUNTEO_A_VALORES(
	xCARGO 		IN	CHAR,
	xExterno	IN	CHAR,
	xFApremio	IN	DATE)
AS

xID					INTEGER DEFAULT 0;
mFApremio			DATE;
xTEMP               INTEGER DEFAULT 0;
xPorRecargo			INTEGER DEFAULT 0;
xRECARGO			FLOAT DEFAULT 0;
xCuantos			INTEGER DEFAULT 0;
xPrimerPaso			CHAR(1) DEFAULT 'S';
xNIFBueno			CHAR(10);
xError				INTEGER;
xTipo				CHAR(1);
xCONCEPTO			CHAR(6);
xPROGRAMA			CHAR(10) DEFAULT NULL;
xPropuBaja			char(1) default 'N';
xIDCUENTA			INTEGER;
xZONA				CHAR(2);

-- Leer los valores de un cargo de un ayuntamiento

CURSOR cPunteo IS SELECT * FROM PUNTEO WHERE N_CARGO=xCARGO;

BEGIN

-- Rellena el cargo y el detalle del cargo
AnalizaCargo(xCARGO, xTipo, xError);

-- Si hay recibos y liquidaciones mezclados no seguimos
IF xERROR > 0 THEN
   RETURN;
END IF;

-- Si son recibos, comprobar si son padrones
-- externos IBI, RUSTICA, IAE
IF xTIPO='R' THEN

	BEGIN
	 SELECT PADRON INTO xCONCEPTO FROM PUNTEO
		WHERE N_CARGO=xCARGO
		GROUP BY PADRON;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			ROLLBACK;
			RETURN;
	END;
	-- Saber si es IBI, IAE, etc. Hay que tener en cuenta que los padrones de exacciones
	-- no estan grabados en la tabla de programas.
	BEGIN
	SELECT PROGRAMA INTO xPROGRAMA
		FROM PROGRAMAS WHERE CONCEPTO=xCONCEPTO;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			xPrograma:=NULL;
	END;
END IF;


-- Si le pasamos en fecha de apremio el valor 1899 es que no están apremiados

   IF TO_CHAR(xFApremio,'yyyy')='1899' THEN
	mFApremio:=NULL;
   ELSE
	mFApremio:=xFApremio;
   END IF;
   
   
   -- recogemos la zona del usuario que acepta el cargo
   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;


   FOR v_Punteo IN cPunteo LOOP

	-- solamente se realiza la primera vez

	IF xPrimerPaso='S' THEN

		-- cargo en ejecutiva o en voluntaria

		IF v_Punteo.VOL_EJE ='E' THEN


			-- Leer de configuración
			SELECT RECARGO INTO xTEMP FROM CONFIGURACION
			WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

			IF xTEMP = 0 THEN
				xPorRecargo:=5;
			ELSE
				xPorRecargo:=10;
			END IF;

		ELSE

			xPorRecargo:=0;

		END IF;


		xPrimerPaso:='N';

	END IF;

	--
	-- Si no hay entregas a cuenta el procentaje de recargo indicado en la configuración
	--
	xRECARGO:=0;
	xIDCUENTA:=null;

	IF v_Punteo.VOL_EJE='E' THEN

		IF v_Punteo.ENTREGAS_A_CUENTA = 0 THEN
			xRECARGO:=v_Punteo.CUOTA_INICIAL * xPorRecargo / 100;
		ELSE
			-- Este caso sólo se daría teoricamente en un cargo en ejecutiva
			-- con un valor que se ha ingresado fuera de plazo voluntario, con lo cual se
			-- ha ingresado todo el principal y sólo vamos a cobrar el recargo de apremio
			xRECARGO:=v_Punteo.CUOTA_INICIAL * 10 / 100;

			--
			-- Averiguar el código de cuenta de organismo externo
			--
			begin
				SELECT min(ID) INTO xIDCUENTA FROM CUENTAS_SERVICIO
				WHERE ZONA IN (SELECT ZONA FROM MUNICIPIOS WHERE AYTO=v_Punteo.AYTO)
				AND ORGANISMO_EXT='S' AND ENTIDAD='9999';
			exception
				when no_data_found then
					xIDCUENTA:=NULL;
			end;

		END IF;

	END IF;


	IF xExterno='S' THEN

		-- En el caso del IBI
		IF xPROGRAMA='IBI' THEN

			BEGIN
				SELECT NIF INTO xNIFBueno FROM REFERENCIAS_BANCOS
					WHERE REF_CATASTRAL=v_Punteo.CLAVE_CONCEPTO;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
			   		INSERTA_REFERENCIA_BANCO(v_Punteo.AYTO,v_Punteo.YEAR,NULL,
					v_Punteo.NIF, NULL, RTRIM(v_Punteo.CLAVE_CONCEPTO),NULL);
			END;
		END IF;

		IF xPROGRAMA='RUSTICA' THEN

			BEGIN
				SELECT NIF INTO xNIFBueno FROM REFERENCIAS_BANCOS
					WHERE REF_RUSTICA=v_Punteo.CLAVE_CONCEPTO;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
			   		INSERTA_REFERENCIA_BANCO(v_Punteo.AYTO,v_Punteo.YEAR,
					NULL,v_Punteo.NIF,RTRIM(v_Punteo.CLAVE_CONCEPTO),NULL,NULL);
			END;
		END IF;


		-- En el caso del IAE
		IF xPROGRAMA='IAE' THEN

			BEGIN
				SELECT NIF INTO xNIFBueno FROM REFERENCIAS_BANCOS
					WHERE REFERENCIA_IAE=v_Punteo.CLAVE_CONCEPTO;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
			   		INSERTA_REFERENCIA_BANCO(v_Punteo.AYTO,v_Punteo.YEAR,v_Punteo.PERIODO,
					v_Punteo.NIF, RTRIM(v_Punteo.CLAVE_CONCEPTO), NULL, NULL);
			END;
		END IF;

		-- Si no existe como contribuyente, lo insertamos

		SELECT COUNT(*) INTO xCuantos FROM CONTRIBUYENTES
			WHERE nif=v_Punteo.NIF;

		IF xCuantos=0 THEN

			INSERT INTO CONTRIBUYENTES
				(nif,nombre,via,calle,numero,escalera,planta,piso,poblacion,
				provincia,pais,codigo_postal)
			VALUES
				(v_Punteo.nif,v_Punteo.nombre,v_Punteo.via,v_Punteo.calle,
				v_Punteo.numero,
				v_Punteo.escalera,v_Punteo.planta,v_Punteo.piso,v_Punteo.poblacion,
				v_Punteo.provincia,v_Punteo.pais,v_Punteo.codigo_postal);

			xNIFBueno:=v_Punteo.NIF;

		ELSE

			-- Comprobar si es un mote, en caso afirmativo, nos devuelve el NIF correcto
			-- en caso negativo nos devuelve un nulo

			xNIFBueno:=GetAliasNIF(v_Punteo.NIF);

			IF xNIFBueno IS NULL THEN
	   	   	   xNIFBueno:=v_Punteo.NIF;
			END IF;

		END IF;

	ELSE
		xNIFBueno:=v_Punteo.NIF;

	END IF; -- EXTERNO


	--si el cargo es de ejecutiva se comprueba si el contribuyente esta declarado
	--como insolvente, entonces el valor pasa directamente a estar propuesto de baja
	--por referencia
	if v_Punteo.VOL_EJE='E' then

		select count(*) into xCuantos from insolventes where nif=xNIFBueno;
		if xCuantos>0 then
			xPropuBaja:='S';
		else
			xPropuBaja:='N';
		end if;
	else
		xPropuBaja:='N';
	end if;

	INSERT INTO VALORES
		(PADRON, YEAR, PERIODO, RECIBO, TIPO_DE_OBJETO, CLAVE_CONCEPTO, COTITULARES,
		CERT_DESCUBIERTO, YEAR_CONTRAIDO, NIF, NOMBRE, CLAVE_RECIBO,
		CUOTA_INICIAL, PRINCIPAL, RECARGO_O_E, VOL_EJE, COSTAS, ENTREGAS_ANTESDEL_CARGO,
		N_CARGO,F_CARGO, FIN_PE_VOL, ESTADO_BANCO, CLAVE_EXTERNA,
		DOM_TRIBUTARIO,OBJETO_TRIBUTARIO,TIPO_DE_TRIBUTO,AYTO,Recargo,F_APREMIO,
		F_NOTIFICACION,NOTIFICADO,PROPU_INSOLVENTE,FECHA_PROPUESTA_BAJA)
	VALUES
		(v_Punteo.PADRON, v_Punteo.YEAR, v_Punteo.PERIODO, v_Punteo.RECIBO,
		v_Punteo.TIPO_DE_OBJETO, v_Punteo.CLAVE_CONCEPTO, v_Punteo.COTITULARES,
		v_Punteo.CERT_DESCUBIERTO, v_Punteo.YEAR_CONTRAIDO,

		xNIFBueno, v_Punteo.NOMBRE,

		v_Punteo.CLAVE_RECIBO, v_Punteo.CUOTA_INICIAL, v_Punteo.PRINCIPAL,
		v_Punteo.RECARGO_O_E, v_Punteo.VOL_EJE,v_Punteo.COSTAS,v_Punteo.ENTREGAS_A_CUENTA,
		xCARGO,v_Punteo.F_CARGO,
		v_Punteo.FIN_PE_VOL,v_Punteo.ESTADO_BANCO,v_Punteo.CLAVE_EXTERNA,
		v_Punteo.DOM_TRIBUTARIO, v_Punteo.OBJETO_TRIBUTARIO,
		v_Punteo.TIPO_DE_TRIBUTO, v_Punteo.AYTO, ROUND(xRECARGO,2), mFApremio,
		v_Punteo.F_NOTIFICACION,v_Punteo.NOTIFICADO,
		xPropuBaja,DECODE(xPropuBaja,'S',Trunc(sysdate,'dd'),NULL))
	RETURN ID INTO xID;
	
	-- insertar en propuestas_baja si es un valor de un nif insolvente
	IF (xPropuBaja='S') THEN
	   INSERT INTO PROPUESTAS_BAJA(IDVALOR,ZONA) VALUES(xID,xZONA);
	END IF;


	-- pasar el desglose del recibo
	PASAR_DESGLOSE(xID,v_Punteo.Importe1,v_Punteo.Importe2,v_Punteo.Importe3,
                    v_Punteo.Importe4,v_Punteo.Importe5,v_Punteo.Importe6,v_Punteo.Importe7,
                    v_Punteo.Titulo1,v_Punteo.Titulo2,v_Punteo.Titulo3,
                    v_Punteo.Titulo4,v_Punteo.Titulo5,v_Punteo.Titulo6,v_Punteo.Titulo7);


	--Solo para el Organismo de Motril, son datos necesarios en los discos que hay que darle
	--al Ayuntamiento de Motril con los ingresos y bajas que se han producido
	--Tambien sirve para la Diputación de Granada en donde grabamos el código de la Delegación
	--remitente
	IF v_Punteo.CENTRO_GESTOR IS NOT NULL THEN
		PasaRestoDatos(xID,v_Punteo.CENTRO_GESTOR,v_Punteo.OFICINA_LIQUI,
					v_Punteo.N_ORDEN_VALOR,v_Punteo.CERT_DESCUBIERTO,
					v_Punteo.RECARGO);
	END IF;

	--
	-- Si hay entregas previas al cargo, añadir en ingresos la entrega
	--
	if v_Punteo.ENTREGAS_A_CUENTA > 0 AND v_Punteo.VOL_EJE='E' then

	   ENTREGA_ORGANISMO_EXT(xID,	xIDCUENTA,
			v_Punteo.ENTREGAS_A_CUENTA, v_Punteo.FIN_PE_VOL+1,sysdate, 'A');
	end if;

   END LOOP;

   -- Eliminar el cargo una vez se ha pasado a valores

   DELETE FROM PUNTEO WHERE N_CARGO=xCARGO;

END;
/

/*****************************************************************************/

--
-- MODIFICAR LOS DATOS DE UN RECIBO EN EL PUNTEO
-- Y LOS DATOS DEL CONTRIBUYENTE SIMULTANEAMENTE
--
-- Modificado: 01-07-2002. Lucas Fernández Pérez. Añade un nuevo parámetro de entrada
-- que indica si las modificaciones del recibo afectarán a la tabla CONTRIBUYENTES.
-- Modificado: 28-04-2004. Gloria Maria Calle Hernandez. Se añade un nuevo parámetro 
-- de entrada: la Via del domicilio.


CREATE OR REPLACE PROCEDURE ACTUALIZARPUNTEO(
  	    xID			   IN 	    integer,
        xNombre 	   IN 	    char,
        xObjeto 	   IN		varchar,
        xVia 		   IN 	    char,
        xCalle 		   IN 	    char,
        xNumero 	   IN		char,
        xEscalera 	   IN		char,
        xPlanta 	   IN		char,
        xPiso 		   IN		char,
        xPobla 		   IN		char,
        xProvi 		   IN		char,
        xPais 		   IN		char,
        xPostal 	   IN		char,
        xNIF 		   IN		char,
        xDomi 		   IN		char,
        xClave_Concepto IN		varchar,

        xIMPORTE1 	   IN		FLOAT,
        xIMPORTE2 	   IN		FLOAT,
        xIMPORTE3 	   IN		FLOAT,
        xIMPORTE4 	   IN		FLOAT,
        xIMPORTE5 	   IN		FLOAT,
        xIMPORTE6 	   IN		FLOAT,
        xIMPORTE7 	   IN		FLOAT,

        xTITULO1       IN		CHAR,
        xTITULO2       IN		CHAR,
        xTITULO3       IN		CHAR,
        xTITULO4       IN		CHAR,
        xTITULO5       IN		CHAR,
        xTITULO6       IN		CHAR,
        xTITULO7       IN		CHAR,
 	    xUpdateContri  IN 	    CHAR)
AS

BEGIN

	UPDATE Punteo set nombre=xNombre,
                    objeto_tributario=xObjeto,
                    dom_tributario=xDomi,
                    clave_concepto=xClave_Concepto,
                    IMPORTE1=ROUND(xImporte1,2),
                    IMPORTE2=ROUND(xImporte2,2),
                    IMPORTE3=ROUND(xImporte3,2),
                    IMPORTE4=ROUND(xImporte4,2),
                    IMPORTE5=ROUND(xImporte5,2),
                    IMPORTE6=ROUND(xImporte6,2),
                    IMPORTE7=ROUND(xImporte7,2),
                    TITULO1=xTitulo1,
                    TITULO2=xTitulo2,
                    TITULO3=xTitulo3,
                    TITULO4=xTitulo4,
                    TITULO5=xTitulo5,
                    TITULO6=xTitulo6,
                    TITULO7=xTitulo7,
					VIA=xVia,
                    CALLE=xCalle,
                    NUMERO=xNumero,
                    ESCALERA=xEscalera,
                    PLANTA=xPlanta,
                    PISO=xPiso,
                    POBLACION=xPobla,
                    PROVINCIA=xProvi,
                    CODIGO_POSTAL=xPostal,
                    PAIS=xPais

	WHERE ID=xID;

	if xUpdateContri='S' then -- Si se quieren aplicar los cambios en la tabla CONTRIBUYENTES.

	   update contribuyentes set nombre=xNombre,
	   		  				 	 via=xVia,                             
							     calle=xCalle,
                                 numero=xNumero,
                                 escalera=xEscalera,
                                 planta=xPlanta,
                                 piso=xPiso,
                                 poblacion=xPobla,
                                 provincia=xProvi,
                                 pais=xPais,
                                 codigo_postal=xPostal
	   where nif=xNIF;


	   -- Si no existe el contribuyente lo damos de alta
	   IF SQL%NOTFOUND THEN
		insert into contribuyentes
			(nif,nombre,via,calle,numero,escalera,planta,piso,poblacion,
			provincia,pais,codigo_postal)
		values
			(xNif,xNombre,xVia,xCalle,xNumero,xEscalera,xPlanta,xPiso,
			xPobla,xProvi,xPais,xPostal);
	   END IF;

	end if;

END;
/


/*****************************************************************************/


/*****************************************************************************/


-- PASAR UN CARGO A VOLUNTARIA
-- Modificacion: 21/10/2004 Gloria María Calle Hernández. Se añade parámetro PADRON, para el pase
--				de ejecutiva a voluntaria del barrido de liquidaciones por concepto y fechas. Desde Delphi 
--				si se trata de un pase de liquidaciones envía el código de PADRON correspondiente
--				si se trata de un pase de un cargo envía este código nulo.

CREATE OR REPLACE PROCEDURE PASE_A_VOLUNTARIA(
        xCARGO	IN	CHAR,
        xPADRON IN  CHAR,
        xAyto  	IN	CHAR)
AS

BEGIN

  UPDATE VALORES
  SET VOL_EJE='V',
      RECARGO=0,
      F_APREMIO=NULL
  WHERE N_CARGO=xCARGO AND
	      PADRON=decode(xPadron,NULL,PADRON,xPadron) AND
        AYTO=xAYTO AND
        VOL_EJE='E' AND
        F_INGRESO IS NULL AND
        FECHA_DE_BAJA IS NULL AND
        CUOTA_INICIAL > 0;

   UPDATE CARGOS SET VOL_EJE='V',APREMIADO='N'
   WHERE CARGO=xCARGO;

END;
/



--
-- Anular un cargo de liquidaciones directas a Recaudación
-- Autor: Antonio Pérez Caballero
-- Fecha: 23/08/2001
-- Modificado por Agustin Leon Robles 27/08/2001, se ha incluido la anulacion de multas
-- modificado: 3 Enero 2.002 Antonio Pérez Caballero
-- Modificado: 01/03/2005. Lucas Fernández Pérez. Nuevo parámetro xAYTO para borrar el cargo
--  de un ayto, porque hay clientes que tienen para distintos aytos el mismo cargo (Catoure).
--
CREATE OR REPLACE PROCEDURE ANULAR_PASE(xNCARGO IN CHAR, xAYTO IN CHAR, xTipo IN CHAR)
AS
BEGIN


   Delete from punteo where N_Cargo=xNCARGO AND AYTO=xAYTO;

   -- Pueden ser liquidaciones directas o multas de trafico
   -- Si son liquidaciones directas poner el cargo como no pasado a recaudación
   -- Si son multas poner el cargo como no pasado a recaudación y tambien volver a poner el
   --    estado='PC' pendiente de certificacion

   IF xTipo='L' THEN

   	INSERT INTO HISTORIA_LIQUI (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
		SELECT ID,'H','SE ANULA EL CARGO: '||xNCARGO,SYSDATE,USER FROM LIQUIDACIONES
		WHERE NUMERO_DE_CARGO=xNCARGO AND MUNICIPIO=xAYTO;

	UPDATE LIQUIDACIONES SET PASADO='N',
		NUMERO_DE_CARGO=NULL,
		F_CARGO=NULL
	WHERE NUMERO_DE_CARGO=xNCARGO  AND MUNICIPIO=xAYTO;


	UPDATE MULTAS SET PASADO='N',
		NUMERO_DE_CARGO=NULL,
		F_CARGO=NULL,
		ESTADO_ACTUAL='PC',FECHA_ESTADO_ACTUAL=sysdate
	WHERE NUMERO_DE_CARGO=xNCARGO AND MUNICIPIO=xAYTO;

END IF;

END;
/





--
-- Impresion Masiva de Recibos para cada contribuyente desde la tabla de Punteo
-- Autor: Gloria Maria Calle Hernandez
-- Fecha: 25/05/2004
-- Modificado: 01/07/2004 Gloria Maria Calle Hernandez. Cuando se trata de una exaccion,
-- se comprueba consultando la tabla de exacciones no sobre Programas como los restantes.
-- Modificado: 24/09/2004 Gloria Maria Calle Hernandez. Creado WriteTempAgua especificamente
-- para ser llamado desde este procedimiento y rellenar la tabla de impresion temporal uno a 
-- uno sin borrarla
-- Modificado: 02/03/2005 Gloria Maria Calle Hernandez. Cambiado select para tomar todos 
-- los padrones de los conceptos IAE,IBI,RUSTICA,EXACCIONES,AGUA,VEHICULOS. Que como coincide 
-- que son todos tipo_objeto='R', sería suficiente y mejor hacer esta ultima comparacion.
--
CREATE OR REPLACE PROCEDURE ImprimeRecibosJuntos (
	xAyto		  IN CHAR,
	xNombre		  IN CHAR)
AS
  	-- Variables para crear la sentencia
    TYPE tCURSOR IS   REF CURSOR;  -- define REF CURSOR type
    vCURSOR    	 	  tCURSOR;     -- declare cursor variable
	vPUNTEO			  PUNTEO%ROWTYPE;
	vSENTENCIA		  VARCHAR2(2000);

	v_RegistroVehi    Recibos_Vehi%ROWTYPE;
	v_RegistroIBI  	  Recibos_IBI%ROWTYPE;
	v_RegistroRus	  Recibos_Rustica%ROWTYPE;
	v_RegistroIAE	  Recibos_IAE%ROWTYPE;
	v_RegistroExac	  Recibos_Exac%ROWTYPE;
	v_RegistroAgua	  Recibos_Agua%ROWTYPE;

	vDomiAgua  		  CHAR(1);
	vPrograma		  CHAR(10);
	
BEGIN

	DELETE FROM IMP_RECIBOS_VEHI WHERE USUARIO=UID;
	DELETE FROM IMP_RECIBOS_IBI  WHERE USUARIO=UID;
	DELETE FROM IMP_RECIBOS_RUS  WHERE USUARIO=UID;
	DELETE FROM IMP_RECIBOS_IAE  WHERE USUARIO=UID;
	DELETE FROM IMP_RECIBOS_EXAC WHERE USUARIO=UID;
	DELETE FROM IMP_RECIBOS_AGUA WHERE USUARIO=UID;

	
	--Especificamos los padrones de los cuales imprimiremos los recibos... de otros conceptos no se imprimiran 
    vSENTENCIA:= 'SELECT * FROM PUNTEO where Tipo_de_Objeto=''R'' '||
		   '   and Estado_Banco is null and Ayto='''||xAyto||'''';
	vSENTENCIA:= vSENTENCIA||'and trim(Nombre)='''||trim(xNombre)||'''';


	--Asignar consulta a cursor, abrirlo y recorrerlo
	OPEN vCURSOR FOR vSENTENCIA;
	LOOP
		FETCH vCURSOR INTO vPUNTEO;
		EXIT WHEN vCURSOR%NOTFOUND;
	

		BEGIN
			SELECT PROGRAMA INTO vPrograma FROM PROGRAMAS WHERE CONCEPTO=vPunteo.Padron;
        EXCEPTION
		    WHEN OTHERS THEN
                 
		         BEGIN 
				     SELECT 'EXACCIONES' INTO vPrograma FROM DUAL WHERE vPunteo.Padron IN 
					(SELECT DISTINCT COD_ORDENANZA FROM EXACCIONES);				 
				 EXCEPTION
				     WHEN OTHERS THEN
      				      vPrograma:=NULL;
      			 END;
		END;
	
		IF vPrograma='VEHICULOS' THEN
		
			SELECT * INTO v_RegistroVehi FROM RECIBOS_VEHI WHERE ID=vPunteo.Clave_Recibo;
		
			WriteTempVehi(v_RegistroVehi,vPunteo.Year,vPunteo.Periodo);
		
		ELSIF vPrograma='IBI' THEN
		
			SELECT * INTO v_RegistroIBI FROM RECIBOS_IBI WHERE ID=vPunteo.Clave_Recibo;

			WriteTempIBI(v_RegistroIBI,vPunteo.Ayto,vPunteo.Year,vPunteo.Periodo);
		
		ELSIF vPrograma='RUSTICA' THEN
		
			SELECT * INTO v_RegistroRus FROM RECIBOS_RUSTICA WHERE ID=vPunteo.Clave_Recibo;
		
			WriteTempRustica(v_RegistroRus,vPunteo.Ayto,vPunteo.Year,vPunteo.Periodo);
		
		ELSIF vPrograma='IAE' THEN
		
			SELECT * INTO v_RegistroIAE FROM RECIBOS_IAE WHERE ID=vPunteo.Clave_Recibo;
		
			WriteTempIAE(v_RegistroIAE,vPunteo.Ayto,vPunteo.Year,vPunteo.Periodo);
		
		ELSIF vPrograma='EXACCIONES' THEN
		
			SELECT * INTO v_RegistroExac FROM RECIBOS_EXAC WHERE ID=vPunteo.Clave_Recibo;
		
			WriteTempEXAC(v_RegistroExac,vPunteo.Ayto,vPunteo.Year,vPunteo.Periodo,vPunteo.Padron);
		
		ELSIF vPrograma='AGUA' THEN
		
			SELECT * INTO v_RegistroAgua FROM RECIBOS_AGUA WHERE ID=vPunteo.Clave_Recibo;
		
			WriteTempAgua(v_RegistroAgua,vPunteo.Ayto,vPunteo.Year,vPunteo.Periodo);
		
		END IF;

	END LOOP;

	CLOSE vCURSOR;
END;
/



/*****************************************************************************/
COMMIT;
/********************************************************************/
