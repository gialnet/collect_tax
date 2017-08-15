CREATE OR REPLACE PACKAGE PKNotificaciones
AS

PROCEDURE AddCostaNotiRelacion(mNumero in char);

procedure AddNotiCartaPago
		(xNumObjetos 	in integer,
		 mNumero		in char);

procedure AddGeneraNotificacion
			(xNumCargo			in char,
			xNotificado			in char,
			xRelacion_Apremio	in char,
			xNIF				in char,
			xValor				in integer,
			mNumero				in char,
			xFNotificacion		in date,
			xExpediente			in integer,
			xFinPeVol			in date);

PROCEDURE AllRecibosNotificacion
				(xNIF 	in	char,
				xAyto		in 	char,
				mNumero	in	char,
				xIncluirPropuBaja in char);



xCuantos			int default 0;
xNotificaciones 	int default 0;
xNumRecibos			int default 0;
xN_Orden			int default 1;
xMaximoPermitido	int;
xCodOpe				int;
xGenerarCartasPago	char(1);
xEntidadPublica		char(1);

--indica si se quiere notificar ademas de los recibos de los cargos elegidos, tambien el 
--resto de deudas que tenga sin notificar. Para Burjasot sera 'S' y para Torrejon sera 'N'
IncluirTodoslosValores	char(1);

END;
/


CREATE OR REPLACE PACKAGE BODY PKNotificaciones
AS


--
-- Añade las costas por adelantado en funcion de la configuracion de la zona
-- Creado: 18/06/2002 Agustin Leon Robles
-- Modificado : 10/09/2002 Antonio Pérez Caballero había un update sobre valores
-- que era redundante.
-- Modificado: 31/08/2004. Lucas Fernández Pérez. Actualiza la costa en reciboscartapagobanco.
--
PROCEDURE AddCostaNotiRelacion(mNumero in char)
AS

xImpoCosta		float default 0;
xIDCostas		integer;
xCostas		char(1);
i			integer default 1;
xCostaValor		float default 0;
xSumCosta		float default 0;
xOrden		integer default 0;

--Para grabar las costas por adelantado
CURSOR cGrabarCostas IS SELECT VALOR,NUMERO_OBJETOS,N_ORDEN 
	FROM NOTIFICACIONES
		WHERE N_RELACION=mNumero order by n_orden
	for update of ID_COSTAS;
BEGIN

	select COSTA_ADELANTADO into xCostas from configuracion where zona=(select zona from
			usuarios where usuario=user);

	--generar las costas de correo por adelantado
	if xCostas='S' then

		SELECT importe INTO xImpoCosta FROM precio_correo WHERE TIPO='L';

		for v_Costas IN cGrabarCostas loop


			--todas las notificaciones del mismo NIF tienen el mismo n_orden, se utiliza
			--este campo y no el NIF porque hay un indice por n_orden y es mas rapido
			if xOrden<>v_Costas.N_ORDEN then
				xOrden:=v_Costas.N_ORDEN;
				i :=1;
			else
				i :=i +1;
			end if;

			--al dividir el importe de la costa entre varios recibos nos descuadra
			--por ejemplo: 2,54 de costa dividido entre 3 recibos salen a 0,85.
			--Si 0,85*3=2,55. Entonces en el ultimo recibo se grabaria 0,84 para que cuadre
			if i = v_Costas.Numero_Objetos then
				xCostaValor := xImpoCosta - xSumCosta;
				xSumCosta := 0;
			else
				xCostaValor := round(xImpoCosta/v_Costas.Numero_Objetos,2);
				xSumCosta  := xSumCosta + xCostaValor;
			end if;

			PUT_COSTAS_RECIBO(v_Costas.Valor,
					'GASTOS AUTOMATICOS DE CORREO',
					xCostaValor,
					sysdate,
					NULL,
					xIDCostas);

		-- Anotamos ID de la costa para que sea fácil mente identificable 

			update notificaciones set ID_COSTAS=xIDCostas 
				WHERE CURRENT OF cGrabarCostas;
		
		-- Aumentamos la costa en reciboscartapagobanco. La costa pendiente (COSTAS) aumenta, así como 
		--  las costas del valor (COSTASVALOR), puesto que acabamos de llamar a PUT_COSTAS_RECIBO.
			UPDATE RECIBOSCARTAPAGOBANCO SET COSTAS=COSTAS+xCostaValor, COSTASVALOR=COSTASVALOR+xCostaValor 
			WHERE N_RELACION=mNumero AND VALOR=v_Costas.Valor;

		end loop;

	end if;

END;



--
-- Genera la carta de pago de la notificacion y actualiza en notificaciones el
-- numero de valores que compene para cuando se grabe la costa se divida entre el numero
-- de recibos
--
-- Modificado: 07-04-2004. Agustín León Robles. Se quita el 'if xGenerarCartasPago='S' then'
--		
procedure AddNotiCartaPago
		(xNumObjetos 	in integer,
		 mNumero		in char)
as
begin
	--para poder grabar el acuse de recibo y saber el numero de valores
	--por el que tengo que dividir las costas.
	update notificaciones set NUMERO_OBJETOS=xNumObjetos
			where N_RELACION=mNumero
			and N_ORDEN=xN_ORDEN;

	xN_ORDEN:=xN_ORDEN+1;
	
	-- Creo una nueva carta de pago y le meto los recibos
	-- que componen este codigo de operacion
	PkCartaPagoBanco.NewCartaPago;
	PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero);
	-- Obtengo un nuevo código de operación
	CODIGO_OPERACION(xCodOpe);
	
end;



--
--
-- Genera la notificacion de solo los recibos que estan sin notificar y ademas que no estan
-- ya en otra relacion
--
--
-- Modificado: 16-12-2002. Agustín León Robles.
--		Antes se incluían en las cartas de pago todos los recibos 
--			aunque no estuvieran dentro de los cargos	elegidos, 
--			ahora solo se incluyen en las cartas de pago los recibos de los cargos elegidos
--
-- Modificado: 25-03-2003. Lucas Fernández Pérez.
--	Puesto que todos los recibos que se notifican se imprimen con el 20% de recargo, se
--  pone el recargo de los valores que van a entrar en reciboscartapagobanco al 20% siempre.
--
-- Modificado: 22-04-2003. Lucas Fernández Pérez.
-- Cuando IncluirTodosLosValores='N', si algún recibo del cargo que se notifica 
-- estaba en alguna relación, no se modificaba, pero entraba en la carta de pago,
-- por lo que se producía una incoherencia. Se añade el filtro de que los recibos no
-- tengan relacion de apremio cuando IncluirTodosLosValores='N'.
-- 
-- Modificado: 15-03-2004. Agustín León Robles.
--  Si tiene expediente hay que comprobar si tiene diligencia de embargo, en caso afirmativo
--  no generaremos carta de pago

-- Modificado: 07-04-2004. Agustín León Robles. Ahora se tiene en cuenta si se quiere solo 
--	generar la carta de pago con los recibos que pertenezcan a los cargos elegidos o si se
--	quiere generar la carta de pago con todos los recibos independientemente de si esta en 
--	los cargos elegidos o no 

-- Modificado: 01-06-2004. Agustín León Robles.
--		Si un valor pertenece a un cargo que no está Apremiado no se genera notificacion

-- Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- Modificacion: 22/06/2004 Agustín León Robles. 
--		Por si se ha generado una notificación manual y luego no se le grabó el acuse, borramos el registro para evitar duplicidades
-- Modificacion: 22/12/2004 Lucas Fernández Pérez. 
-- 		en los update de valores hacía RECARGO=ROUND(CUOTA_INICIAL*xTipoRecargo,2), sin tener en cuenta las entregas en
--      voluntaria para calcular el recargo. Se modifica para que el recargo vaya sobre el pendiente en ejecutiva. En el caso de no tener
--		entregas a cuenta en voluntaria se sigue calculando sobre la cuota_inicial para el caso de los ingresos fuera de plazo
-- Modificacion: 29/04/2005. Lucas Fernández Pérez. Había un error cuando IncluirTodoslosValores='S', hacía
--	RECARGO=DECODE(ENTREGAS_A_CUENTA,0,ROUND(CUOTA_INICIAL*xTipoRecargo,2),ROUND(xPrincipal*xTipoRecargo,2))
--  y modificaba el recargo a valores notificados, poniendoles el 10% cuando tenían el 20%. Tras el cambio, 
--  solo se modifica el recargo de los valores a los que se crea notificación.
							

procedure AddGeneraNotificacion
			(xNumCargo			in char,
			xNotificado			in char,
			xRelacion_Apremio	in char,
			xNIF				in char,
			xValor				in integer,
			mNumero				in char,
			xFNotificacion		in date,
			xExpediente			in integer,
			xFinPeVol			in date)

as
xSiGenera		char(1);
xCuantosCargos	integer default 0;
xFDiligencia	date;
xSiGraba		char(1);
xApremiado		char(1) default 'N';
xTipoRecargo	float;
xPrincipal      float;
begin

	--Nueva Ley General Tributaria 58/2003 de 18 de Diciembre del 2003
	--Según la Disposición transitoria primera dice: 1. Lo dispuesto en el artículo 28 de esta ley se aplicará
	--a las deudas tributarias cuyo período ejecutivo se inicie a partir de la entrada en vigor de la misma.
	if Trunc(xFinPeVol,'dd')<to_date('30/06/2004','dd/mm/yyyy') then
		xTipoRecargo:=0.2;
	else
		xTipoRecargo:=0.1;
	end if;


	--si no se quiere incluir todos los valores pendientes de notificar, tiene que 
	--estar dentro de los cargos elegidos
	if IncluirTodoslosValores='N' then
			
		SELECT count(*) into xCuantosCargos
				FROM TMP_LISTACARGOS 
				WHERE SESIONID=GETSID() and cargo=xNumCargo;

		if ( (xCuantosCargos>0) and (xRelacion_Apremio is null) ) then
			xSiGenera:='S';			
		else
			xSiGenera:='N';
		end if;

	else
		xSiGenera:='S';
	end if;	
	
	
	IF xNOTIFICADO='N' AND xRELACION_APREMIO IS NULL AND xFNotificacion IS NULL THEN

		--si el valor pertenece a un cargo que no está Apremiado no se genera notificacion
		select distinct(Apremiado) into xApremiado from Cargos where Cargo=xNumCargo;
		if xApremiado='N' then
		
			xSiGenera:='N';	
			
		end if;
	
	
		if xSiGenera='S' then

			--para saber el numero de notificaciones totales para grabarlo
			--en la tabla Relaciones_noti
			xCuantos:=xCuantos + 1;

			--para saber el numero de notificaciones que llevo para actualizar en
			-- el campo numero_objetos
			xNotificaciones:=xNotificaciones + 1;
			
			--Por si se ha generado una notificación manual y luego no se le grabó el acuse, borramos el registro para evitar duplicidades
			Delete from Notificaciones where Valor=xValor and Tipo_noti='000' and N_relacion is null and Last_Acuse is null;

			INSERT INTO NOTIFICACIONES
      		(VALOR,N_ENVIOS,TIPO_NOTI,NIF,F_1INTENTO,N_RELACION,N_ORDEN)
			VALUES
			(xValor,1,'000',xNIF,sysdate,mNumero,xN_ORDEN);		
		end if;	
	else
		xSiGenera:='N';
	end if;	
	
	xPrincipal:=DameIngresosVoluntaria(xValor);
	
	--si se quiere generar carta de pago de cualquier recibo del contribuyente
	if xGenerarCartasPago='S' then		
	
		--si tiene expediente hay que comprobar si tiene diligencia de embargo, en caso afirmativo
		--no generaremos carta de pago
		if xExpediente is not null then
	
			select fecha_diligencia into xFDiligencia from Expedientes where ID=xExpediente;
	
			if xFDiligencia is not null then
				xSiGraba:='N';
			else
				xSiGraba:='S';
				xNumRecibos:= xNumRecibos + 1;
			end if;
	
		else
			xSiGraba:='S';
			xNumRecibos:= xNumRecibos + 1;
		end if;	
		
		--En funcion de la variable xSiGenera generaremos o no, notificaciones de apremio	
		UPDATE VALORES SET
			RELACION_APREMIO=DECODE(xSiGenera,'S',mNumero,RELACION_APREMIO),
			ORDEN_APREMIO=DECODE(xSiGenera,'S',xN_ORDEN,ORDEN_APREMIO),
			CODIGO_OPERACION=DECODE(xSiGraba,'S',xCodOpe,CODIGO_OPERACION),
			RECARGO=DECODE(xSiGenera,'S', -- Solo se modifica el recargo de los valores a los que se crea notificación
							DECODE(ENTREGAS_A_CUENTA,0,ROUND(CUOTA_INICIAL*xTipoRecargo,2),ROUND(xPrincipal*xTipoRecargo,2)),
							RECARGO)
		where ID=xValor;	
		
	else --solo se quiere generar la carta de pago con los recibos del cargo que se está notificando	
		 --La unica diferencia con el update de arriba es que se cambia la variable xSiGraba por la de xSiGenera
	
		--En funcion de la variable xSiGenera generaremos o no, notificaciones de apremio		
		UPDATE VALORES SET
			RELACION_APREMIO=DECODE(xSiGenera,'S',mNumero,RELACION_APREMIO),
			ORDEN_APREMIO=DECODE(xSiGenera,'S',xN_ORDEN,ORDEN_APREMIO),
			CODIGO_OPERACION=DECODE(xSiGenera,'S',xCodOpe,CODIGO_OPERACION),
			RECARGO=DECODE(xSiGenera,'S', -- Solo se modifica el recargo de los valores a los que se crea notificación
			                DECODE(ENTREGAS_A_CUENTA,0,ROUND(CUOTA_INICIAL*xTipoRecargo,2),ROUND(xPrincipal*xTipoRecargo,2)),
							RECARGO)
		where ID=xValor;
		
		if xSiGenera='S' then
			xNumRecibos:= xNumRecibos + 1;	
		end if;
	
	end if;
	
	
	IF xNumRecibos=xMaximoPermitido THEN
	
		AddNotiCartaPago(xNotificaciones,mNumero);

		xNotificaciones:=0;
		
		xNumRecibos:=0;
	END IF;
	
end;




-- Modificado: 12-05-2004. Agustín León Robles.
--		Los propuestos de baja tampoco se genera notificación. 
-- Modificado: 06/09/2004. Lucas Fernandez Pérez.Nuevo parámetro xIncluirPropuBaja que indica si se quieren 
--  							notificar los propuestos de baja o no.
PROCEDURE AllRecibosNotificacion
				(xNIF 	in	char,
				xAyto	in 	char,
				mNumero	in	char,
				xIncluirPropuBaja in char)
AS

--Relacion de deudas de un determinado NIF y ayto, pendientes de cobro
CURSOR cAytoNotificacion IS
	SELECT ID,NOTIFICADO,RELACION_APREMIO,N_CARGO,F_NOTIFICACION,EXPEDIENTE,FIN_PE_VOL FROM VALORES
	WHERE NIF=xNIF
		AND AYTO=xAyto
		AND VOL_EJE='E'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		);


--Relacion de deudas de un determinado NIF, pendientes de cobro
CURSOR cNotificacion IS
	SELECT ID,NOTIFICADO,RELACION_APREMIO,N_CARGO,F_NOTIFICACION,EXPEDIENTE,FIN_PE_VOL FROM VALORES
	WHERE NIF=xNIF
		AND VOL_EJE='E'
      	AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		);

BEGIN

if xEntidadPublica='X' then

	for v_Noti IN cAytoNotificacion loop
		AddGeneraNotificacion(v_Noti.N_CARGO,v_Noti.Notificado,
					v_Noti.Relacion_Apremio,xNIF,v_Noti.ID,mNumero,v_Noti.F_Notificacion,v_Noti.Expediente,v_Noti.FIN_PE_VOL);
	end loop;

else
	for v_Noti IN cNotificacion loop
		AddGeneraNotificacion(v_Noti.N_CARGO,v_Noti.Notificado,
					v_Noti.Relacion_Apremio,xNIF,v_Noti.ID,mNumero,v_Noti.F_Notificacion,v_Noti.Expediente,v_Noti.FIN_PE_VOL);
	end loop;
end if;


END;


END;
/


