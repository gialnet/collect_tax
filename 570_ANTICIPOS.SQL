
--
--insertar en historico_anticipos
--
CREATE OR REPLACE PROCEDURE ADD_HIS_ANTICIPO(
	xIDAnti IN Integer,
	xFecha IN Date,
	xImporte IN Float)
AS
BEGIN

INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,FECHA,IMPORTE)
	VALUES (xIDAnti, Trunc(xFecha,'dd'), xImporte);

END;
/

--
-- Borrar un anticipo en historico_anticipos
--
CREATE OR REPLACE PROCEDURE DEL_HIS_ANTICIPO
		(xIDAnti IN Integer,
		xFecha IN Date,
		xImporte IN Float)
AS
BEGIN

delete from HISTORICO_ANTICIPOS where ANTICIPO=xIDAnti and fecha=trunc(xFecha,'dd') and importe=xImporte
		and movimiento='PR';

END;
/


/********************************************************************/
/* trigger para obtener el numero de secuencia correpondiente */
CREATE OR REPLACE TRIGGER T_INS_ANTICIPOS
BEFORE INSERT ON ANTICIPOS
FOR EACH ROW
BEGIN

   SELECT GENERAANTI.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/

--
-- Si se paga todo el anticipo se dá por liquidado
--
CREATE OR REPLACE TRIGGER TCHK_LIQUIDADO
BEFORE UPDATE ON ANTICIPOS
FOR EACH ROW
BEGIN

  IF :NEW.PENDIENTE <= 0 THEN
     :NEW.ESTADO:='L';
  END IF;

END;
/


--	PROCEDIMIENTOS PARA LA GESTION DE ANTICIPOS Y DESCUENTOS
-- Creación: Febrero - 2.001   AUTOR: Eduardo Muñoz Sala - Lucas Fernandez Perez
-- Modificación: 11-10-2001 Lucas Fernández Pérez
-- Ultima Modificación: 16-10-2001 Lucas Fernández Pérez. Adaptación al Euro

--
-- Crea la cabecera del anticipo
-- Devuelve el ID, que se empleará para relacionarlo con los conceptos correspondiente
--
-- Ultima modificación: 17/01/2003. Agustín León Robles.
--		Adaptación a la nueva forma de trabajar de los anticipos
--
CREATE OR REPLACE PROCEDURE CreaAnticipo(
	xAyuntamiento  	IN ANTICIPOS.AYTO%TYPE,
	xFecha	 		IN ANTICIPOS.FECHA%TYPE,
	xPrioridad		IN ANTICIPOS.PRIORIDAD%TYPE,
	xInteres		IN ANTICIPOS.INTERES%TYPE,
	xDescripcion	IN ANTICIPOS.DESCRIPCION%TYPE,
	xTipo			IN ANTICIPOS.TIPO%TYPE,
	xID				OUT ANTICIPOS.ID%TYPE)

AS
BEGIN

	INSERT INTO ANTICIPOS(AYTO, FECHA, TIPO, DESCRIPCION, PRIORIDAD, INTERES)

	VALUES (xAyuntamiento, Trunc(xFecha,'dd'), xTipo,xDescripcion, xPrioridad,xInteres)

	RETURN ID INTO xID;

END;
/

/***********************************************************************/
/* Asocia un concepto para un ejercicio y periodo con un anticipo */

CREATE OR REPLACE PROCEDURE AsociaConceptoAnticipo
(
	xID_Anti	  	IN CONCEPTOSANTICIPOS.ANTICIPO%TYPE,
	xConcepto	 	IN CONCEPTOSANTICIPOS.CONCEPTO%TYPE,
	xEjercicio		IN CONCEPTOSANTICIPOS.EJERCICIO%TYPE,
	xPeriodo		IN CONCEPTOSANTICIPOS.PERIODO%TYPE,
	xGenerado		OUT INTEGER)
AS
	iden integer;
BEGIN

	/* Inserta un anticipo en la tabla conceptosanticipos la asociacion de un concepto
	con un anticipo anteriormente generado*/

	SELECT count(*) INTO iden FROM CONCEPTOSANTICIPOS
		WHERE ANTICIPO=xID_Anti
			AND	CONCEPTO=xConcepto
			AND PERIODO=xPeriodo
			AND EJERCICIO=xEjercicio;

	IF iden=0 THEN
	 	 INSERT INTO CONCEPTOSANTICIPOS(ANTICIPO, CONCEPTO, EJERCICIO,PERIODO)

		  VALUES (xID_Anti, xConcepto, xEjercicio, xPeriodo);

		 xGenerado:=1;
	ELSE
		 xGenerado:=0;
	END IF;

END;
/

/************************************************************/
/* Estado posibles: P: pendiente, L:Liquidado, A:Anulado	*/
/************************************************************/
/*  Establece un anticipo como anulado. La anulación produce
    que dicho anticipo se considere liquidado, sin necesidad
    de ir actualizando los cobros.
*/
CREATE OR REPLACE PROCEDURE AnulaAnticipo
(
	xID_Anticipo  	IN ANTICIPOS.AYTO%TYPE,
	xFecha	 		IN ANTICIPOS.FECHA%TYPE,
	xPendiente		IN ANTICIPOS.PENDIENTE%TYPE,
	xMotivo			IN ANTICIPOS.DESCRIPCION%TYPE)

AS
	mAnulado integer;
BEGIN
	/* Inserta un registro en el historico de anticipos donde se marca la fecha de */
	/* anulacion y el pendiente que quedaba   */
	SELECT count(*) INTO mAnulado FROM ANTICIPOS WHERE ID=xID_Anticipo AND estado='A';

	INSERT INTO HISTORICO_ANTICIPOS(ANTICIPO, FECHA, PENDIENTE)
      VALUES (xID_Anticipo, xFecha, ROUND(xPendiente,2));

	IF mAnulado=0 THEN
		/* Actualizamos el anticipo marcandolo como anulado */
		UPDATE ANTICIPOS SET ESTADO='A' WHERE ID=xID_Anticipo;
	ELSE -- Está anulado, por lo que lo reponemos al estado Pendiente 'P'
		/* Actualizamos el anticipo marcandolo como Pendiente */
		UPDATE ANTICIPOS SET ESTADO='P' WHERE ID=xID_Anticipo;
	END IF;

	IF xMotivo<>' ' THEN
		UPDATE ANTICIPOS SET DESCRIPCION=xMotivo WHERE ID=xID_Anticipo;
	END IF;

END;
/
/****************************************************************************/
/* Permite insertar un nuevo tipo de interes para el prestamo de dinero.
   xFecha: indica la fecha de entrada en vigor del nuevo interes.
   Esto supone que la entrada actualmente en vigor (campo fecha_fin nulo)
   se actualiza estableciendo su Fecha de fin como xFecha-1.
*/
CREATE OR REPLACE PROCEDURE InsertarInteresAnticipo(
	xFecha	 	IN INTERES_ANTICIPOS.FECHA_INICIO%TYPE,
	xInteres	IN INTERES_ANTICIPOS.INTERES%TYPE)

AS
	mExistentes integer;
	mFecha date;
BEGIN

	-- Inserta un registro en la table de tipos de interés donde se marca la fecha de
	-- entrada en vigor y el interes correspondiente
	SELECT count(*) INTO mExistentes FROM INTERES_ANTICIPOS;

	IF mExistentes=0 THEN
	      INSERT INTO INTERES_ANTICIPOS(FECHA_INICIO,INTERES)

	      VALUES (xFecha, xinteres);
	ELSE

	    -- Actualizamos el último tipo de interés insertando su fecha de finalización
		SELECT max(fecha_inicio) INTO mFecha FROM INTERES_ANTICIPOS;

		IF mFecha < xFecha THEN
			UPDATE INTERES_ANTICIPOS SET FECHA_FIN=to_date(xFecha)-1
			WHERE FECHA_INICIO=mFecha;

		    -- Insertamos el nuevo tipo de interes
		    INSERT INTO INTERES_ANTICIPOS(FECHA_INICIO,INTERES)
	      	VALUES (xFecha, xinteres);
		ELSE

			-- Si se esta modificando un interés recien insertado,
			-- actualizamos su porcentaje
			UPDATE INTERES_ANTICIPOS SET INTERES=xInteres
			WHERE FECHA_INICIO=mFecha;
		END IF;

	END IF;

END;
/


-- ***************** O J O   a partir de quí ya no se utiliza está dentro del paquete
-- de liquidacionesROE



/*------------------------------------------------------------------------------*/
/* Creación: Febrero - 2.001   AUTOR: Eduardo Muñoz Sala - Lucas 				*/
/* Ultima Modificación: 11-10-2001 Lucas Fernández Pérez						*/
/*------------------------------------------------------------------------------*/
/*	ACTUALIZAR UN ANTICIPO EN UNA LIQUIDACIÓN 				 					*/
/*------------------------------------------------------------------------------*/
/* Actualiza la liquidación de un anticipo considerando los ingresos de una		*/
/* liquidación. Comprueba si hay ingresos debidos a los conceptos y periodos 	*/
/* del anticipo, y los descuenta de la liquidación para cobrar el anticipo		*/
/* Sólo es llamado desde el procedimiento ACTUALIZARANTICIPOS. 					*/
/*------------------------------------------------------------------------------*/
CREATE OR REPLACE procedure ActualizarAnticipo(
	xIDLiq			IN ANTICIPOS.LAST_LIQUIDR%TYPE,
	xID_Anti		IN ANTICIPOS.ID%TYPE,
	xFecha	 		IN ANTICIPOS.FECHA%TYPE)

-- xFecha indica hasta que fecha se deben calcular los intereses de los descuentos.

AS

	mUltLiq integer;
	mFechaLiq date;
	mFechaDesde date;
	mFechaHasta date;
	mdias integer;
	mPendiente float default 0;
	mInteres float default 0;
	mIngresado float default 0;
	mDto float default 0;
	mPremio float default 0;
	mDescontado float default 0;
	mDisponible float default 0;

-- Recorre los conceptos asociados con el anticipo

CURSOR cCONCEPTOS IS SELECT CONCEPTO,EJERCICIO,PERIODO
		FROM ConceptosAnticipos
		WHERE ANTICIPO=xID_Anti;

	-- Recorre los tipos de interés posibles a aplicar en el anticipo

	CURSOR cTIPOSINTERES IS SELECT INTERES,FECHA_FIN,FECHA_INICIO
		FROM INTERES_ANTICIPOS
		WHERE (FECHA_INICIO < mFechaHasta AND FECHA_FIN > mFechaDesde)
		OR (FECHA_FIN IS NULL AND FECHA_INICIO < mFechaHasta)
	ORDER BY FECHA_INICIO;


BEGIN


	-- obtenemos la cantidad pendiente y el tipo de interés que se le debe aplicar
	SELECT PENDIENTE,INTERES,LAST_LIQUIDR,FECHA INTO mPendiente,mInteres,
	mUltLiq,mFechaLiq
		FROM ANTICIPOS
		WHERE ID=xID_Anti;

	IF mUltLiq is not null THEN -- El descuento se trato en otra liquidación
		-- Obtengo la fecha de fin de esa otra liquidación, que es la de inicio
		-- del cálculo de intereses.
		SELECT FECHA_FIN INTO mFechaLiq FROM LIQUIDACIONESR WHERE ID=mUltLiq;
	END IF;

	-- Si el descuento no se trató en otra liquidación, la fecha de inicio del cálculo de
	-- intereses es la fecha de creación del descuento.

	-- Las fechas de inicio y fin del descuento pueden no estar con formato
	-- de hora 0:00:00 y por ese motivo se truncan para que el calculo de dias sea correcto.
	mFechaHasta:=TRUNC(xFecha,'dd');
	mFechaDesde:=TRUNC(mFechaLiq,'dd');

	IF mInteres<>-1 THEN	-- si el interés es fijo
		mdias:=mFechaHasta-mFechaDesde;	-- días trascurridos
		mInteres:=(((mdias*mInteres)/365)*(mPendiente/100)); -- interés calculado
	ELSE

	-- si el interés es variable, recorremos los tipos de interés y calculamos los
	-- intereses para los días comprendidos en cada tipo de interés

  	  mInteres:=0;

	  FOR v_TipoI IN cTIPOSINTERES LOOP

		IF v_TipoI.FECHA_FIN IS NULL THEN
			mdias:=mFechaHasta-mFechaDesde;
		ELSE
			-- Si la fecha de fin del interés es menor que la de fin del anticipo
			IF (v_TipoI.FECHA_FIN < mFechaHasta) THEN
			  mdias:=v_TipoI.FECHA_FIN-mFechaDesde;
			  mFechaDesde:=v_TipoI.FECHA_FIN;
			ELSE -- La fecha de fin del interés es mayor que la del anticipo
			  mdias:=mFechaHasta-mFechaDesde;
			END IF;
		END IF;

		mInteres:=mInteres+(((mdias*v_TipoI.INTERES)/365)*(mPendiente/100));

	  END LOOP;

	END IF;

	mInteres:=ROUND(mInteres, 2);

	-- actualizamos el histórico de anticipos
	INSERT INTO HISTORICO_ANTICIPOS
		(ANTICIPO, FECHA, PENDIENTE, N_LIQUIDR, INTERESES)
	VALUES
		(xID_Anti, mFechaHasta, mPendiente, xIDLiq, mInteres);

	-- añadimos los intereses a la deuda
	mPendiente:=mPendiente+mInteres;

	-- Para cada concepto del anticipo, vamos descontado para el pago del anticipo
	FOR v_Con IN cCONCEPTOS LOOP


		SELECT Sum(Ingresos-Premio),Sum(Dto) INTO mIngresado,mDescontado
		FROM LIQUIDR_CTO_RESUMEN
		WHERE IDLIQ=xIDLiq
			AND CONCEPTO=v_Con.CONCEPTO
			AND YEAR=v_Con.EJERCICIO
			AND PERIODO=v_Con.PERIODO;

		-- Liquido pendiente
		mIngresado:=mIngresado-mDescontado;

		if mIngresado >= mPendiente then
		   mDto:=mPendiente;
		   mPendiente:=0;
		else
		   mPendiente:=mPendiente-mIngresado;
		   mDto:=mIngresado;
		end if;

		UPDATE LIQUIDR_CTO_RESUMEN SET DTO=DTO+mDto
			WHERE IDLIQ=xIDLiq
				AND CONCEPTO=v_Con.CONCEPTO
				AND YEAR=v_Con.EJERCICIO
				AND PERIODO=v_Con.PERIODO;

		IF mPendiente=0 THEN
		   EXIT;
		END IF;


	END LOOP;

	IF mPendiente > 0 THEN -- Si ha quedado algo pendiente
		UPDATE ANTICIPOS SET PENDIENTE=mPendiente,LAST_LIQUIDR=xIDLiq
			WHERE ID=xID_Anti;
	ELSE
		UPDATE ANTICIPOS SET PENDIENTE=0,LAST_LIQUIDR=xIDLiq,ESTADO='L'
			WHERE ID=xID_Anti;
	END IF;


END;
/

/*--------------------------------------------------------------------------*/
/* Creación: Febrero - 2.001   AUTOR: Eduardo Muñoz Sala - Lucas 			*/
/* Ultima Modificación: 11-10-2001 Lucas Fernández Pérez					*/
/*--------------------------------------------------------------------------*/
/*	ACTUALIZAR UN DESCUENTO EN UNA LIQUIDACIóN								*/
/*--------------------------------------------------------------------------*/
/* Actualiza un descuento en base a los ingresos de una liquidación.		*/
/* Liquida el descuento en función de la cantidad disponible 				*/
/* en la liquidación, repartiendo equitativamente el cobro entre todos los 	*/
/* conceptos asociados.														*/
/* Sólo es llamado desde el procedimiento ACTUALIZARANTICIPOS. 				*/
/*--------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE ActualizarDescuento(
	xIDLiq		IN ANTICIPOS.LAST_LIQUIDR%TYPE,
	xID_Desc	IN ANTICIPOS.ID%TYPE,
	xFecha	 	IN ANTICIPOS.FECHA%TYPE)

-- xFecha indica hasta que fecha se deben calcular los intereses de los descuentos.

AS

	mUltLiq integer;
	mFechaLiq date;
	mFechaHasta date;
	mFechaDesde date;
	mdias integer;
	mPendiente float;
	mInteres  float;
	mPorcentaje float;

	mIngresado float default 0;
	mDescontado float default 0;
	mDisponible float;


	CURSOR cTIPOSINTERES IS SELECT INTERES,FECHA_FIN,FECHA_INICIO
		FROM INTERES_ANTICIPOS
		WHERE (FECHA_INICIO < mFechaHasta AND FECHA_FIN > mFechaDesde)
		OR (FECHA_FIN IS NULL AND FECHA_INICIO < mFechaHasta)
		ORDER BY FECHA_INICIO;

BEGIN


	-- obtenemos la cantidad pendiente y el tipo de interes que se le debe aplicar
	SELECT PENDIENTE,INTERES,LAST_LIQUIDR,FECHA INTO mPendiente,mInteres,mUltLiq,mFechaLiq
	FROM ANTICIPOS WHERE ID=xID_Desc;

	IF mUltLiq is not null THEN -- El descuento se trato en otra liquidación
		-- Obtengo la fecha de fin de esa otra liquidación, que es la de inicio
		-- del cálculo de intereses.
		SELECT FECHA_FIN INTO mFechaLiq FROM LIQUIDACIONESR WHERE ID=mUltLiq;
	END IF;
	-- Si el descuento no se trató en otra liquidación, la fecha de inicio del cálculo de
	-- intereses es la fecha de creación del descuento.

	-- Las fechas de inicio y fin del descuento pueden no estar con formato
	-- de hora 0:00:00 y por ese motivo se truncan para que el calculo de dias sea correcto.
	mFechaHasta:=TRUNC(xFecha,'dd');
	mFechaDesde:=TRUNC(mFechaLiq,'dd');

	IF mInteres<>-1 THEN -- si el interes es fijo
		mdias:=mFechaHasta-mFechaDesde; -- dias trascurridos
		mInteres:=(((mdias*mInteres)/365)*(mPendiente/100)); -- calculo del interés
	ELSE
	-- si el interes es variable,recorremos los tipos de interes y calculamos los
	-- intereses para los dias comprendidos en cada tipo de interes
	  mInteres:=0;

	  FOR v_TipoI IN cTIPOSINTERES LOOP

		IF v_TipoI.FECHA_FIN IS NULL THEN
			mdias:=mFechaHasta-mFechaDesde;
		ELSE
			-- Si la fecha de fin del interes sea menor que la fecha de fin del anticipo
			IF(v_TipoI.FECHA_FIN<mFechaHasta) THEN
			  mdias:=v_TipoI.FECHA_FIN-mFechaDesde;
			  mFechaDesde:=v_TipoI.FECHA_FIN;
			ELSE -- La fecha de fin del interes es mayor que la del anticipo
			  mdias:=mFechaHasta-mFechaDesde;
			END IF;
		END IF;
		mInteres:=mInteres+(((mdias*v_TipoI.INTERES)/365)*(mPendiente/100));

	  END LOOP;
	END IF;

	mInteres:=ROUND(mInteres,2);
	-- actualizamos el historico de anticipos
	INSERT INTO HISTORICO_ANTICIPOS(ANTICIPO,FECHA,PENDIENTE,N_LIQUIDR,INTERESES)
	VALUES (xID_Desc,mFechaHasta,mPendiente,xIDLiq,mInteres);

	-- actualizamos el pendiente
	mPendiente:=mPendiente+mInteres;

	-- Sumamos las cantidades obtenidas en la liquidación
	SELECT SUM(INGRESOS-Premio),SUM(Dto) INTO mIngresado,mDescontado
		FROM LIQUIDR_CTO_RESUMEN
		WHERE IDLIQ=xIDLiq;

	mDisponible:=mIngresado-mDescontado;

	IF mDisponible > 0 THEN -- hay dinero, se puede descontar

		IF mPendiente > mDisponible THEN -- no se puede descontar todo
			mPendiente:=mPendiente-mDisponible;

			UPDATE ANTICIPOS SET PENDIENTE=mPendiente,LAST_LIQUIDR=xIDLiq
			WHERE ID=xID_Desc;
			mDisponible:=0;

		    -- marcamos todos los conceptos como totalmente descontados
			UPDATE LIQUIDR_CTO_RESUMEN SET Dto=INGRESOS-Premio
				WHERE IDLIQ=xIDLiq;

		ELSE -- hay dinero suficiente para descontar todo.

			UPDATE ANTICIPOS SET PENDIENTE=0,LAST_LIQUIDR=xIDLiq,ESTADO='L'
			WHERE ID=xID_Desc;

			-- repartimos el cobro del descuento entre los conceptos
			mPorcentaje:=(mPendiente*100)/mDisponible;

			UPDATE LIQUIDR_CTO_RESUMEN
			SET DTO=ROUND(Dto+((((INGRESOS-Premio)-Dto)*mPorcentaje)/100),2)
			WHERE IDLIQ=xIDLiq;

		END IF;

	ELSE -- No hay ningún dinero, sólo acumulo intereses en el PENDIENTE del anticipo

		UPDATE ANTICIPOS SET PENDIENTE=mPendiente,LAST_LIQUIDR=xIDLiq
			WHERE ID=xID_Desc;

	END IF;

END;
/

/*------------------------------------------------------------------------------*/
/* Creación: Febrero - 2.001   AUTOR: Eduardo Muñoz Sala - Lucas 				*/
/* Ultima Modificación: 11-10-2001 Lucas Fernández Pérez						*/
/*------------------------------------------------------------------------------*/
/*	ACTUALIZAR ANTICIPOS/DESCUENTOS EN UNA LIQUIDACIóN							*/
/*------------------------------------------------------------------------------*/
/* Actualiza los anticipos/descuentos con una liquidación recién generada 		*/
/* que es la que llama al procedimiento. 										*/
/* Sólo es llamado desde el procedimiento LIQUIDAUNAYTO. 						*/
/*------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE ActualizarAnticipos(
	xIDLiq		IN ANTICIPOS.LAST_LIQUIDR%TYPE,
	xFecha	 	IN ANTICIPOS.FECHA%TYPE)

-- xFecha indica hasta que fecha se deben calcular los intereses de los anticipos/descuentos.

AS

mDescontado float default 0;
mIngresado 	float default 0;
xAyto		ANTICIPOS.AYTO%TYPE;

--	Recorre los anticipos pendientes del ayuntamiento en cuestión.
-- 	Si el anticipo es posterior a la liquidación, no se tiene en cuenta

	CURSOR cANTICIPOS IS SELECT ID,TIPO FROM ANTICIPOS
		WHERE AYTO = xAyto
		AND ESTADO = 'P'
		AND FECHA < xFecha
		ORDER BY PRIORIDAD;


BEGIN

	-- Obtengo el código de municipio
	SELECT AYTO INTO xAyto FROM LIQUIDACIONESR WHERE ID=xIDLiq;

	-- Para cada anticipo y en orden de prioridad actualizamos su pendiente,
	--   comprobando si se puede liquidar

	FOR v_Anti IN cANTICIPOS LOOP

		-- Sumamos las cantidades obtenidas en la liquidación
		SELECT SUM(INGRESOS-PREMIO),SUM(DTO) INTO mIngresado,mDescontado
		FROM LIQUIDR_CTO_RESUMEN
			WHERE IDLIQ=xIDLiq;

		IF mIngresado=mDescontado THEN -- Todo lo ingresado se ha descontado, no queda más.
			EXIT;
		END IF;

		IF v_Anti.TIPO='A' THEN -- es un anticipo
			ActualizarAnticipo(xIDLiq,v_Anti.ID,xFecha);
		ELSE -- es un descuento
  			ActualizarDescuento(xIDLiq,v_Anti.ID,xFecha);
		END IF;

	END LOOP;

END;
/
