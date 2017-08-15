-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez
-- 	   Modificado: 02-01-2002. Agustin Leon Robles.
--			Se ha anulado la sobrecarga de wtDatosPostalesDeudor
-- 	   Modificado: 29-01-2002. Lucas Fernández Pérez.
--			Se añaden 2 nuevos procedimientos.
--	   Modificado: 29-01-2002. M. Carmen Junco Gómez.
--			El procedimiento wtDatosPostalesRepetir no guardaba los datos
--			del expediente si el nif se encontraba en Asistencia.
-- -----------------------------------------------------

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- PAQUETE DE MANEJO DE TABLAS TEMPORALES DE DOCUMENTOS DE INGRESO
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE OR REPLACE PACKAGE PkwtDocIngreso
AS

--
-- Escribir en una tabla temporal todos las entregas a cuenta que se han producido sobre
-- una determinada deuda.
-- En el caso de que hubiese sido por un embargo de cuentas averiguar la cuenta del
-- contribuyente sobre la que se practicó la traba.
--

PROCEDURE wtEntregasDeUnValor(xIDValor IN INTEGER,xTotalEntregado OUT FLOAT);

-- se sobrecarga para que a la hora de reimprimir las cartas de pago no salgan
-- las entregas a cuentas posteriores al documento que estamos emitiendo
PROCEDURE wtEntregasDeUnValor(xIDValor IN INTEGER, xFechaIngreso IN DATE,xTotalEntregado OUT FLOAT);

-- Escribir los datos postales de un deudor en función de su NIF
PROCEDURE wtDatosPostalesDeudor(xNIF IN Char, xIDExpe IN INT,xBORRA IN CHAR);

-- Para la reimpresión de una carta de pago desde el formulario VerCobrosDiario
PROCEDURE wtDatosPostalesRepetir(xCodOpe IN INT,xID IN INT);

--
-- Escribir en una tabla temporal todas las deudas vivas de un expediente incluyendose
-- también sus deudas suspendidas.
-- de un expediente o las seleccionadas por el usuario, pueden incluir en voluntaria y
-- en ejecutiva.
-- Si el tipo de ingreso es 'DB', genera la carta de pago al banco
--
PROCEDURE wtDeudasVivasySuspendidas(xIDExpe IN INTEGER, xCodOperacion IN INT, xTipo_Ingreso IN CHAR, xSuspendidos IN CHAR,xBORRA IN CHAR);

PROCEDURE wtRepetirCartaParciales
				(xCodOperacion 	IN INT,
				xTipoIngreso 	IN CHAR,
				xVolEje 		IN CHAR,
				xID 			IN INT);

-- Escribir otros datos postales de un deudor por expediente (importe,codigo de barras...)
PROCEDURE wtDatosPostalesDeudorCPago(xIDExpe IN INTEGER);

-- Por cada plazo de un FRACCIONAMIENTO pone los datos necesarios para la carta de pago.
PROCEDURE wtDatosPostalesDeudorCPFrac(xIDFrac IN INTEGER,xVol_Eje IN CHAR);

-- Lo utiliza el procedimiento wtInformeCPBancoPorLotes para el trámite de inmuebles
PROCEDURE wtCPBancoLotesInmuebles(xIDEXPE IN INTEGER,xIDEMBARGO IN INTEGER,
						        xESTA_EMBARGO IN CHAR,xQUIEN IN CHAR,
						        xSIGUE OUT BOOLEAN,xMOSTRAR OUT BOOLEAN);

-- Lo utiliza el procedimiento wtInformeCPBancoPorLotes para el trámite de vehículos
PROCEDURE wtCPBancoLotesVehiculos(xIDEXPE IN INTEGER,xIDEMBARGO IN INTEGER,
						        xESTA_EMBARGO IN CHAR,xQUIEN IN CHAR,
						        xSIGUE OUT BOOLEAN,xMOSTRAR OUT BOOLEAN);

-- Genera el informe de deudas de todos los expedientes de un lote
PROCEDURE wtInformeCPBancoPorLotes(xEMBARGO IN CHAR,xESTA_EMBARGO IN CHAR,
				   	      xLOTE IN CHAR,xGENERA_CARTAPAGO IN CHAR,
					      xGENERA_TODO IN CHAR,xQUIEN IN CHAR);

-- Genera el informe de deudas de todos los expedientes PENDIENTES de un tramite de embargo
PROCEDURE wtInformeCPBancoTodosPend(xEMBARGO IN CHAR,xESTA_EMBARGO IN CHAR,
					xGENERA_CARTAPAGO IN CHAR,xQUIEN IN CHAR);

-- Genera el informe de deudas de todos los expedientes entre fechas
PROCEDURE wtInformeCPBancoEntreFechas(xEMBARGO IN CHAR,xESTA_EMBARGO IN CHAR,
					xDESDE IN DATE, xHASTA IN DATE,xGENERA_CARTAPAGO IN CHAR,xQUIEN IN CHAR);

-- Genera el informe de deudas de todos los expedientes de un lote o entre fechas
-- (dependiendo del embargo) o de un solo expediente que este en tramitacion de embargos
PROCEDURE wtInformeCPBancoEmbargos(xIDEXPE IN INTEGER,xEMBARGO IN CHAR, xESTA_EMBARGO IN CHAR,xLOTE IN CHAR,xDESDE IN DATE, xHASTA IN DATE,xGENERA_CARTAPAGO IN CHAR,xGENERA_TODO IN CHAR,xQUIEN IN CHAR);

State_of_I_Animate Integer default 0;

END;
/

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--
-- 		Gestión de cartas de pago en bancos
--
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE OR REPLACE PACKAGE BODY PkwtDocIngreso
AS

-- Modificado: 14/04/2005. Lucas Fernández Pérez. Se modifica el mensaje de tipo de ingreso
-- si el tipo de entrega es entrega por embargo, puesto que llevaba a confusión en los informes de deudas
PROCEDURE wtEntregasDeUnValor(xIDValor IN INTEGER,xTotalEntregado OUT FLOAT)
AS
-- Relación de las entregas a cuenta
-- Cursor con los ingresos de un grupo de tipos determinado
-- de un valor en concreto
-- INTERNO
xMensaje Varchar(60);
CURSOR cEntregas IS
SELECT CODIGO_OPERACION, TIPO_INGRESO, FECHA, PRINCIPAL, RECARGO, COSTAS, DEMORA,
			(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS IMPORTE, CONCEPTO, ORGANISMO_EXT
	FROM INGRESOS
	WHERE VALOR=xIDValor
	AND PARCIAL_O_COBRO='P';

BEGIN

   xTotalEntregado:=0;

   -- Leer las entregas a cuenta
   FOR v_cEntregas IN cEntregas LOOP

	xMensaje:='';

	if v_cEntregas.ORGANISMO_EXT = 'S' then xMensaje:=  'Entrega en Organismo Externo';
	elsif v_cEntregas.ORGANISMO_EXT='R' then xMensaje:= 'Entrega por Regularizacion';
	elsif v_cEntregas.ORGANISMO_EXT='A' then xMensaje:= 'Entrega Fuera de Plazo en O.E.';

	elsif v_cEntregas.TIPO_INGRESO='EE' then xMensaje:= 'Entrega sobre un expediente';
	elsif v_cEntregas.TIPO_INGRESO='EP' then xMensaje:= SUBSTR(v_cEntregas.CONCEPTO,27,60);
	elsif v_cEntregas.TIPO_INGRESO='ER' then xMensaje:= 'Entrega sobre un valor';
	elsif v_cEntregas.TIPO_INGRESO='EC' then xMensaje:= 'Entrega por Compensación';
	elsif v_cEntregas.TIPO_INGRESO='EB' then xMensaje:= 'Entrega por Ventanilla Banco';
	elsif v_cEntregas.TIPO_INGRESO='EF' then xMensaje:= 'Entrega por Frac. en Ejecutiva';
	elsif v_cEntregas.TIPO_INGRESO='F1' then xMensaje:= 'Entrega por Frac. en Voluntaria';
	elsif v_cEntregas.TIPO_INGRESO='F2' then xMensaje:= 'Entrega Frac.V. Pagado en Ejecutiva';
	elsif v_cEntregas.TIPO_INGRESO='ES' then xMensaje:= 'Entrega sobre un valor'; -- por Embargo de Salarios';
	elsif v_cEntregas.TIPO_INGRESO='EI' then xMensaje:= 'Entrega sobre un valor'; -- por Embargo de Inmuebles';
	elsif v_cEntregas.TIPO_INGRESO='EV' then xMensaje:= 'Entrega sobre un valor'; -- por Embargo de Vehículos';
	elsif v_cEntregas.TIPO_INGRESO='EO' then xMensaje:= 'Entrega sobre un valor'; -- por Otros Tramites';
	end if;

	-- Insertar en el temporal de entregas a cuenta

      INSERT INTO TmpEntregasValor
	   (xID, xFECHA, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA, xIMPORTE, MENSAJE)
   	VALUES
	   (xIDValor, v_cEntregas.FECHA, v_cEntregas.PRINCIPAL,
		v_cEntregas.RECARGO, v_cEntregas.COSTAS,
		v_cEntregas.DEMORA, v_cEntregas.IMPORTE,
		xMensaje);

	xTotalEntregado:=xTotalEntregado+v_cEntregas.IMPORTE;

   END LOOP;

END;


---
---
--- se sobrecarga para que a la hora de reimprimir las cartas de pago no salgan
--- las entregas a cuentas posteriores al documento que estamos emitiendo
-- Modificado: 17/03/2003. Lucas Fernández Pérez. Se rellena el mensaje de tipo de ingreso
-- si el tipo de entrega es un cobro total.
-- Modificado: 14/04/2005. Lucas Fernández Pérez. Se modifica el mensaje de tipo de ingreso
-- si el tipo de entrega es entrega por embargo, puesto que llevaba a confusión en los informes de deudas
PROCEDURE wtEntregasDeUnValor(xIDValor IN INTEGER, xFechaIngreso IN DATE,xTotalEntregado OUT FLOAT)
AS
-- Relación de las entregas a cuenta
-- Cursor con los ingresos de un grupo de tipos determinado
-- de un valor en concreto
-- INTERNO
xMensaje	VARCHAR(60);
CURSOR cEntregas IS
SELECT CODIGO_OPERACION, TIPO_INGRESO, FECHA, PRINCIPAL, RECARGO, COSTAS, DEMORA,
			(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS IMPORTE, CONCEPTO, ORGANISMO_EXT
	FROM INGRESOS
	WHERE VALOR=xIDValor and Fecha<=xFechaIngreso;

BEGIN

   xTotalEntregado:=0;

   -- Leer las entregas a cuenta
   FOR v_cEntregas IN cEntregas LOOP


	xMensaje:='';

	if v_cEntregas.ORGANISMO_EXT = 'S' then xMensaje:=  'Entrega en Organismo Externo';
	elsif v_cEntregas.ORGANISMO_EXT='R' then xMensaje:= 'Entrega por Regularizacion';
	elsif v_cEntregas.ORGANISMO_EXT='A' then xMensaje:= 'Entrega Fuera de Plazo en O.E.';

	-- Entregas parciales
	elsif v_cEntregas.TIPO_INGRESO='EE' then xMensaje:= 'Entrega sobre un expediente';
	elsif v_cEntregas.TIPO_INGRESO='EP' then xMensaje:= SUBSTR(v_cEntregas.CONCEPTO,27,60);
	elsif v_cEntregas.TIPO_INGRESO='ER' then xMensaje:= 'Entrega sobre un valor';
	elsif v_cEntregas.TIPO_INGRESO='EC' then xMensaje:= 'Entrega por Compensación';
	elsif v_cEntregas.TIPO_INGRESO='EB' then xMensaje:= 'Entrega por Ventanilla Banco';
	elsif v_cEntregas.TIPO_INGRESO='EF' then xMensaje:= 'Entrega por Fraccionamiento en Ejecutiva';
	elsif v_cEntregas.TIPO_INGRESO='F1' then xMensaje:= 'Entrega por Fraccionamiento en Voluntaria';
	elsif v_cEntregas.TIPO_INGRESO='F2' then xMensaje:= 'Entrega Fracc.Voluntaria Pagado en Ejecutiva';
	elsif v_cEntregas.TIPO_INGRESO='ES' then xMensaje:= 'Entrega sobre un valor'; -- por Embargo de Salarios';
	elsif v_cEntregas.TIPO_INGRESO='EI' then xMensaje:= 'Entrega sobre un valor'; -- por Embargo de Inmuebles';
	elsif v_cEntregas.TIPO_INGRESO='EV' then xMensaje:= 'Entrega sobre un valor'; -- por Embargo de Vehículos';
	elsif v_cEntregas.TIPO_INGRESO='EO' then xMensaje:= 'Entrega sobre un valor'; -- por Otros Tramites';

	-- Cobros totales
	elsif v_cEntregas.TIPO_INGRESO='VE' then xMensaje:= 'Ingreso por Ventanilla';
	elsif v_cEntregas.TIPO_INGRESO='VB' then xMensaje:= 'Ingreso por Ventanilla Banco';
	elsif v_cEntregas.TIPO_INGRESO='CM' then xMensaje:= 'Ingreso por Compensación';
	elsif v_cEntregas.TIPO_INGRESO='PD' then xMensaje:= 'Ingreso por Domiciliación';
	elsif v_cEntregas.TIPO_INGRESO='TC' then xMensaje:= SUBSTR(v_cEntregas.CONCEPTO,19,60);
	elsif v_cEntregas.TIPO_INGRESO='TS' then xMensaje:= 'Ingreso por Embargo de Salarios';
	elsif v_cEntregas.TIPO_INGRESO='TI' then xMensaje:= 'Ingreso por Embargo de Inmuebles';
	elsif v_cEntregas.TIPO_INGRESO='TV' then xMensaje:= 'Ingreso por Embargo de Vehículos';
	elsif v_cEntregas.TIPO_INGRESO='TO' then xMensaje:= 'Ingreso por Otros Tramites';
	elsif v_cEntregas.TIPO_INGRESO='FE' then xMensaje:= 'Ingreso por Fraccionamiento en Ejecutiva';
	elsif v_cEntregas.TIPO_INGRESO='FV' then xMensaje:= 'Ingreso por Fraccionamiento en Voluntaria';
	end if;


	-- Insertar en el temporal de entregas a cuenta

      INSERT INTO TmpEntregasValor
	   (xID, xFECHA, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA, xIMPORTE, MENSAJE)
   	VALUES
	   (xIDValor, v_cEntregas.FECHA, v_cEntregas.PRINCIPAL,
		v_cEntregas.RECARGO, v_cEntregas.COSTAS,
		v_cEntregas.DEMORA, v_cEntregas.IMPORTE,
		xMensaje);
	xTotalEntregado:=xTotalEntregado+v_cEntregas.IMPORTE;

   END LOOP;

END;




--
-- En función del NIF
--
-- Modificado: 26/11/2004 Agustín Léon Robles. Se protege la consulta sobre contribuyentes
--
--
-- DELPHI
PROCEDURE wtDatosPostalesDeudor(xNIF IN Char, xIDExpe IN INT, xBORRA IN CHAR)
AS
xZONA 			CHAR(2) DEFAULT '00';
xNOMBRE 			CHAR(40);
xDOMI 			VARCHAR(50);
xCODPOSTAL 			CHAR(5);
xPOBLACION 			VARCHAR(35);
xPROVINCIA 			VARCHAR(35);
xAYUNTA 			VARCHAR(50);
xEMPRESA 			VARCHAR(80);
xDIRECCION			VARCHAR(100);
xCIF 				CHAR(10);
xPOBLADATOSPER 		VARCHAR(50);
xEXPEDIENTE			CHAR(10);
BEGIN


   IF xBORRA='S' THEN
	-- borrar el temporal de los datos postales
   	delete from TmpDeudorDPostales where usuario=uid;
   END IF;

   -- Averiguar la zona del usuario
   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;


   -- DATOS POSTALES DEL AYUNTAMIENTO PARA LA CABECERA
   SELECT AYUNTAMIENTO,NOMBRE,DIRECCION,CIF,POBLACION
     INTO xAYUNTA,xEMPRESA,xDIRECCION,xCIF,xPOBLADATOSPER
   FROM ZONAS WHERE ZONA=xZONA;

	-- Leer los datos postales del deudor del expediente
	begin
		SELECT NOMBRE,VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO,CODIGO_POSTAL,POBLACION,PROVINCIA
		INTO  xNOMBRE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA
		FROM CONTRIBUYENTES WHERE NIF=xNIF;
	exception
		when no_data_found then
			begin
				xNombre:=NULL;
				xDOMI:=NULL;
				xCODPOSTAL:=NULL;
				xPOBLACION:=NULL;
				xPROVINCIA:=NULL;
			end;
	end;

   -- Leer el número de expediente, solo cuando se trate de informe de debitos o cartas de pago
   -- al expediente completo.
   if xIDExpe > 0 then
      SELECT EXPEDIENTE INTO xEXPEDIENTE FROM EXPEDIENTES WHERE ID=xIDExpe;
   end if;

   -- Insertar los datos postales en la tabla temporal.
   Insert into TmpDeudorDPostales (IDEXPE,EXPEDIENTE,NIFEXPE,NOMBREEXPE,xDOMI,xCODPOSTAL,
	xPOBLACION,xPROVINCIA,xAYUNTA,xEMPRESA,xDIRECCION,xCIF,xPOBLADATOSPER)
   Values (xIDExpe, xEXPEDIENTE, xNIF, xNOMBRE,xDOMI,xCODPOSTAL,
	xPOBLACION,xPROVINCIA,xAYUNTA,xEMPRESA,xDIRECCION,xCIF,xPOBLADATOSPER);

END;

--
-- Para la reimpresión de una carta de pago desde el formulario VerCobrosDiario
--
PROCEDURE wtDatosPostalesRepetir(xCodOpe IN INT,xID IN INT)
AS
xZONA 			CHAR(2) DEFAULT '00';
xNOMBRE 			CHAR(40);
xNOMBREEXPE 		CHAR(40);
xIDEXPE			INTEGER;
xDOMI 			VARCHAR(50);
xCODPOSTAL 			CHAR(5);
xPOBLACION 			VARCHAR(35);
xPROVINCIA 			VARCHAR(35);
xAYUNTA 			VARCHAR(50);
xEMPRESA 			VARCHAR(80);
xDIRECCION			VARCHAR(100);
xCIF 				CHAR(10);
xNIF				CHAR(10);
xPOBLADATOSPER 		VARCHAR(50);
xEXPEDIENTE			char(10);

BEGIN


   -- borrar el temporal de los datos postales
   delete from TmpDeudorDPostales where usuario=uid;

   -- Averiguar la zona del usuario
   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;


   -- DATOS POSTALES DEL AYUNTAMIENTO PARA LA CABECERA
   SELECT AYUNTAMIENTO,NOMBRE,DIRECCION,CIF,POBLACION
     INTO xAYUNTA,xEMPRESA,xDIRECCION,xCIF,xPOBLADATOSPER
   FROM ZONAS WHERE ZONA=xZONA;

   -- recogemos el id del expediente (si existiera)
   begin
      select max(expediente) into xIDExpe
      from valores where expediente is not null and
	     id in (select valor from ingresos where ID=xID);
      Exception
         When no_data_found then
	   begin
            xIDExpe:=Null;
		xExpediente:=Null;
	   end;
   end;

   if xIDExpe is not null then
      select expediente into xExpediente from expedientes where id=xIDExpe;
   end if;

   -- Es de una reimpresión de carta de pago
   -- en el formulario VerCobrosDiario, el dato lo sacaremos de la tabla asistencia
   begin
      Select NIF INTO xNIF from Asistencia Where IDINGRESO=xCodOpe;

   Exception
	   -- Cuando sea ingresos de transferencias bancarios o embargos, no estara grabado
	   -- en la tabla asistencia
	   when no_data_found then
	      if xIdExpe is not null then
		   select deudor into xNIF from expedientes where id=xIDExpe;
		else
		   select NIF into xNIF from valores where ID in
			  	  (select max(valor) from ingresos where ID=xID);
		end if;
   end;

   -- Leer los datos postales del deudor del expediente
   SELECT NOMBRE,VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO,
          CODIGO_POSTAL,POBLACION,PROVINCIA
   INTO  xNOMBREEXPE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA
   FROM CONTRIBUYENTES WHERE NIF=xNIF;

   -- Insertar los datos postales en la tabla temporal.
   Insert into TmpDeudorDPostales (IDEXPE,EXPEDIENTE,NIFEXPE,NOMBREEXPE,xDOMI,xCODPOSTAL,
	xPOBLACION,xPROVINCIA,xAYUNTA,xEMPRESA,xDIRECCION,xCIF,xPOBLADATOSPER)
   Values (xIDEXPE,xEXPEDIENTE, xNIF, xNOMBREEXPE,xDOMI,xCODPOSTAL,
	xPOBLACION,xPROVINCIA,xAYUNTA,xEMPRESA,xDIRECCION,xCIF,xPOBLADATOSPER);

END;

-- Escribir en una tabla temporal todas las deudas vivas de un expediente incluyendose
-- también sus deudas suspendidas.
-- de un expediente o las seleccionadas por el usuario, pueden incluir en voluntaria y
-- en ejecutiva.
-- xBORRA='S' -> Elimina los datos de las tablas temporales
-- xBORRA<>'S' -> Acumula los datos en las tablas temporales
-- Modificacion: 24-6-2002 Lucas Fernández Pérez.
-- Se da la posibilidad de incluir en el listado los recibos suspendidos de un
-- expediente añadiendo un nuevo parámetro de entrada : xSuspendidos ('S','N').
-- Esto solo sirve para listados, si xTipo_Ingreso='DB' no genera carta de pago.
-- Modificación: 03/06/2003 M. Carmen Junco Gómez. Se incluyen también el dígito de 
--               control modalidad1 y el código de barras modalidad 1.
-- Modificacion: 30/06/2003. Agustín León Robles. En el caso de que las cartas de pago
--			tuvieran como fecha tope el sabado o el domingo se pasarían a lunes
-- Modificacion: 21/07/2003. Agustín León Robles. Se ha cambiado la sentencia:
--				to_char(sysdate+xDias,'D') por la siguiente: to_char(sysdate+xDias,'Day') 
-- Modificacion: 22/07/2003 Lucas Fernández Pérez. Se añaden los campos NOTIFICADO 
--			 y F_NOTIFICACION a la tabla TMPDEUDASVIVAS.
--
-- Modificacion: 06/05/2004. Agustín León Robles. En funcion de la configuracion del tipo de empresa
-- que lleva la gestión de la recaudacion se mirará los datos de la emisora o bien a traves de la zona del usuario
-- o si es una empresa privada la que lleva la gestión se mirará en base a la zona del municipio de los recibos
-- elegidos. En este caso solo se podrá marcar recibos de un único municipio. Este control se hace desde Delphi.
--
-- Modificado: 22/07/2004. Lucas Fernández Pérez. 
-- Antes Deuda = principal+recargo+costas+demora y ahora se añade +demora_pendiente
--
--
-- Modificado: 08/09/2004. Agustín León Robles.
-- Puede ocurrir que cuando se emita la carta de pago en banco algunos conceptos vayan con 
-- la misma emisora que la de voluntaria.
-- Por ejemplo en Catoure tienen varios municipios que para el concepto de Basura quieren que
-- vaya a la emisora de la Mancomunidad, pero para el resto de conceptos vaya a la del ayuntamiento
-- Modificado: 15/04/2005. Agustín León Robles.
-- Se quita el trozo de codigo buscar en la tabla de rela_apli_bancos, ya que en catoure se han pasado los conceptos de la 
-- mancomunidad a otro codigo de municipio
-- BASE Y DELPHI
PROCEDURE wtDeudasVivasySuspendidas(
	xIDExpe 		IN INTEGER,
	xCodOperacion 	IN INT,
	xTipo_Ingreso 	IN CHAR,
	xSuspendidos 	IN CHAR,
	xBorra 			IN CHAR )
AS
xTramite			char(1);
xEmisora			char(6);
xSufijo				char(3);
xDias				integer;
xDESCRIPCION 		VARCHAR(50);
xImpor				float;
xDC					char(2);
xDIG_C60_M2			char(2);
xFVencimiento		date;
xCodBarraModa1  	char(38);
xCodBarraModa2		char(42);
xExpediente			char(10);
xEntregasACuenta  	float;
xTotalPrincipal		float default 0;
xTotalRecargo		float default 0;
xTotalCostas		float default 0;
xTotalDemora		float default 0;
xDiaSemana 			varchar2(15);
varPublicoPrivado 	VARCHAR(1);
xAyto				char(3);
xConcepto			char(6);

-- Cursor con las deudas vivas del expediente más las suspendidas
CURSOR cDeudasVS IS
SELECT ID,NIF,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,CUOTA_INICIAL,
   PRINCIPAL,RECARGO,COSTAS,DEMORA,ENTREGAS_ANTESDEL_CARGO,
   (PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) AS DEUDA,DEMORA_PENDIENTE,
   (PRINCIPAL + RECARGO + COSTAS + DEMORA - ENTREGAS_A_CUENTA + DEMORA_PENDIENTE) AS PENDIENTE,
   OBJETO_TRIBUTARIO,FIN_PE_VOL,F_APREMIO,F_SUSPENSION,NOTIFICADO,F_NOTIFICACION,
   DECODE(TIPO_DE_OBJETO,'R','RECIBO','LIQUIDACION') AS TIPO,DOM_TRIBUTARIO, EXPEDIENTE
	FROM VALORES
	WHERE EXPEDIENTE=xIDExpe
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL; -- Se elimina AND F_SUSPENSION IS NULL;

--el cursor se pone ordenado por número de operacion para que salga la carta de pago
--a nombre del titular del grupo.
CURSOR cValores IS
SELECT ID,NIF,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,CUOTA_INICIAL,
    PRINCIPAL,RECARGO,COSTAS,DEMORA,ENTREGAS_ANTESDEL_CARGO,
   (PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) AS DEUDA,DEMORA_PENDIENTE,
   (PRINCIPAL + RECARGO + COSTAS + DEMORA - ENTREGAS_A_CUENTA + DEMORA_PENDIENTE) AS PENDIENTE,
   OBJETO_TRIBUTARIO,FIN_PE_VOL,F_APREMIO,NOTIFICADO,F_NOTIFICACION,
   DECODE(TIPO_DE_OBJETO,'R','RECIBO','LIQUIDACION') AS TIPO,DOM_TRIBUTARIO, EXPEDIENTE
	FROM VALORES
	WHERE CODIGO_OPERACION=xCodOperacion
	ORDER BY NUMERO_OPERACION;

--
-- para insertar en el seguimiento la referencia de la carta de pago
--
CURSOR cSeguimiento IS
SELECT EXPEDIENTE
	FROM VALORES
	WHERE CODIGO_OPERACION=xCodOperacion
	GROUP BY EXPEDIENTE;

BEGIN

if State_of_I_Animate > 0 then
   select usuario into xDESCRIPCION from usuarios;
end if;

   IF xBORRA='S' THEN
   	-- borrar el temporal de la deudas
   	DELETE FROM TmpDeudasVivas WHERE USUARIO=UID;

   	-- borrar el temporal de las entregas a cuenta de las deudas
   	DELETE FROM TmpEntregasValor WHERE USUARIO=UID;
   END IF;

   begin
	-- recogemos el expediente asociado al IDExpe introducido como parametro
   	SELECT EXPEDIENTE INTO xEXPEDIENTE FROM EXPEDIENTES
   	WHERE ID=xIDExpe;
	exception
		when no_data_found then
			xEXPEDIENTE:=null;
   end;


   IF xCodOperacion<>0 THEN

	-- Duedas seleccionadas por el usuario
	FOR v_cDeudasVS IN cValores LOOP

		--se recoge el código de municipio para luego coger los datos de la emisora en funcion del municipio
		--esto solo servirá para la gestion de empresas privadas, ya que solo podran seleccionar recibos 
		--de un unico municipio, este control se hace desde Delphi
		xAyto:=v_cDeudasVS.Ayto;
		xConcepto:=v_cDeudasVS.PADRON;
		
		-- Leer la descripción del concepto en función de su código

		SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS	WHERE CONCEPTO=v_cDeudasVS.PADRON;


  	   -- Relación de entregas a cuenta
         wtEntregasDeUnValor(v_cDeudasVS.ID,xEntregasACuenta);

	   -- Insertar una deuda en el temporal
  	   INSERT INTO TmpDeudasVivas
        	(xID,DNI_DEUDOR,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
		IDEXPE,EXPEDIENTE,CUOTA_INICIAL,PRINCIPAL,FUERA_PLAZO_JUNTA,
	   	RECARGO,COSTAS,DEMORA,DEUDA,DEMORA_PENDIENTE,PENDIENTE,ENTREGAS_A_CUENTA,
		OBJETO_TRIBUTARIO,xRECILIQUI,DESCRIPCION,DOM_TRIBUTARIO,FIN_PE_VOL,F_APREMIO,
		NOTIFICADO,F_NOTIFICACION)
	   VALUES
	  	(v_cDeudasVS.ID, v_cDeudasVS.NIF, v_cDeudasVS.NOMBRE, v_cDeudasVS.AYTO,
		v_cDeudasVS.PADRON, v_cDeudasVS.YEAR, v_cDeudasVS.PERIODO,
		v_cDeudasVS.RECIBO, v_cDeudasVS.CLAVE_CONCEPTO, v_cDeudasVS.EXPEDIENTE,
		xEXPEDIENTE, v_cDeudasVS.CUOTA_INICIAL, v_cDeudasVS.PRINCIPAL, 
		v_cDeudasVS.ENTREGAS_ANTESDEL_CARGO,
		v_cDeudasVS.RECARGO, v_cDeudasVS.COSTAS,
		v_cDeudasVS.DEMORA,v_cDeudasVS.DEUDA, v_cDeudasVS.DEMORA_PENDIENTE,
		v_cDeudasVS.PENDIENTE, xEntregasACuenta,v_cDeudasVS.OBJETO_TRIBUTARIO,
		v_cDeudasVS.TIPO, xDESCRIPCION, v_cDeudasVS.DOM_TRIBUTARIO,v_cDeudasVS.FIN_PE_VOL,
		v_cDeudasVS.F_APREMIO,v_cDeudasVS.NOTIFICADO,v_cDeudasVS.F_NOTIFICACION);

	END LOOP;

   ELSE

	-- Deudas del expediente

	FOR v_cDeudasVS IN cDeudasVS LOOP

		-- Si el valor no esta suspendido o estándolo se quiere meter, se inserta en la tabla
		IF v_cDeudasVS.F_SUSPENSION IS NULL OR xSuspendidos='S' THEN

	   
	   		--se recoge el código de municipio para luego coger los datos de la emisora en funcion del municipio
			--esto solo servirá para la gestion de empresas privadas, ya que solo podran seleccionar recibos 
			--de un unico municipio, este control se hace desde Delphi
			xAyto:=v_cDeudasVS.Ayto;
			xConcepto:=v_cDeudasVS.PADRON;
	   
	   		-- Leer la descripción del concepto en función de su código

   	   		SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS WHERE CONCEPTO=v_cDeudasVS.PADRON;

			-- Relación de entregas a cuenta
         	wtEntregasDeUnValor(v_cDeudasVS.ID,xEntregasACuenta);

			-- Insertar una deuda en el temporal
			INSERT INTO TmpDeudasVivas
				(xID,DNI_DEUDOR,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
				IDEXPE,EXPEDIENTE,CUOTA_INICIAL,PRINCIPAL,RECARGO,COSTAS,DEMORA,DEUDA,
				FUERA_PLAZO_JUNTA,DEMORA_PENDIENTE,PENDIENTE,ENTREGAS_A_CUENTA,
				OBJETO_TRIBUTARIO,xRECILIQUI,DESCRIPCION,DOM_TRIBUTARIO,FIN_PE_VOL,F_APREMIO,
				NOTIFICADO,F_NOTIFICACION)
			VALUES
				(v_cDeudasVS.ID, v_cDeudasVS.NIF, v_cDeudasVS.NOMBRE, v_cDeudasVS.AYTO,
				v_cDeudasVS.PADRON, v_cDeudasVS.YEAR, v_cDeudasVS.PERIODO,
				v_cDeudasVS.RECIBO, v_cDeudasVS.CLAVE_CONCEPTO,
				v_cDeudasVS.EXPEDIENTE, xEXPEDIENTE, v_cDeudasVS.CUOTA_INICIAL,
				v_cDeudasVS.PRINCIPAL, v_cDeudasVS.RECARGO, v_cDeudasVS.COSTAS,
				v_cDeudasVS.DEMORA, v_cDeudasVS.DEUDA, v_cDeudasVS.ENTREGAS_ANTESDEL_CARGO,
				v_cDeudasVS.DEMORA_PENDIENTE,
				v_cDeudasVS.PENDIENTE, xEntregasACuenta,v_cDeudasVS.OBJETO_TRIBUTARIO,
				v_cDeudasVS.TIPO, xDESCRIPCION, v_cDeudasVS.DOM_TRIBUTARIO,v_cDeudasVS.FIN_PE_VOL,
				v_cDeudasVS.F_APREMIO,v_cDeudasVS.NOTIFICADO,v_cDeudasVS.F_NOTIFICACION);

		END IF;

	END LOOP;

   END IF;

   -- Si es documento bancario
   -- Además no permite generar carta de pago si el informe incluye recibos suspendidos.
   IF xTipo_Ingreso='DB' and xSuspendidos='N' THEN

	--creamos una nueva carta de pago en banco
	 PkCartaPagoBanco.NewCartaPago;

	--se accede a la tabla de configuracion para recoger los datos de la emisora, sufijo
	--y dias de vencimiento para pagar en el banco
	
	--Tambien se recoge el tipo de empresa que tiene la gestion de la recaudacion:
	--Ayuntamientos pequeños (A).
	--Ayuntamientos grandes (G): pueden tener mas de un alcalde por distrito, tesorero, etc.
	--Entidades SupraMunicipales (S): Mancomunidades y Diputaciones.
	--Comunidades Autonomas o Administración Central (C).
	--Modo de funcionamiento ASP X
	select EMISORA,SUFIJO,DIAS_VENCIMIENTO,TIPO_ENTIDAD into xEmisora,xSufijo,xDias,varPublicoPrivado
	from configuracion WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);
	
	
	--Si es una empresa privada se los datos se toman en funcion del municipio de los recibos
	--Solo podran seleccionar recibos de un unico municipio, este control se hace desde Delphi	
	if varPublicoPrivado='X' then
					
		select EMISORA,SUFIJO,DIAS_VENCIMIENTO into xEmisora,xSufijo,xDias
		from configuracion WHERE ZONA=(SELECT ZONA FROM MUNICIPIOS WHERE AYTO=xAyto);
		
	end if;

	--averiguamos el importe de la carta de pago porque interviene en el calculo del digito
	--de control
	select sum(PENDIENTE) into xImpor from TmpDeudasVivas where usuario=UID;
	
	--calcular los dígitos de control del cuaderno 60 modalidad 1	
	CALCULA_DC_60 (xImpor, PkCartaPagoBanco.VarCartaPagoBanco, xSufijo,
				to_char(sysdate,'yy'),'01',xEmisora,xDC);
					   
	xCodBarraModa1:='90502'||xEmisora||LPAD(PkCartaPagoBanco.VarCartaPagoBanco,10,'0')||
				xDC||xSufijo||to_char(sysdate,'yy')||'01'||
				LPAD(xImpor*100,8,'0');


	--la fecha de vencimiento del pago en el banco sera hoy mas los dias que se le de por
	--configuracion, en el caso de que el resultado de la suma fuera sabado o domingo se pasaría a
	--lunes
	select to_char(sysdate+xDias,'Day') into xDiaSemana from Dual;

	--SABADO
	if Upper(RTRIM(xDiaSemana)) in ('SÁBADO','SABADO','SATURDAY') then
		xFVencimiento:=sysdate+xDias+2;
	--DOMINGO
	elsif Upper(RTRIM(xDiaSemana)) IN ('DOMINGO','SUNDAY') then
		xFVencimiento:=sysdate+xDias+1;
	else
		xFVencimiento:=sysdate+xDias;
	end if;



	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(xImpor, PkCartaPagoBanco.VarCartaPagoBanco, xSufijo,
			to_char(sysdate,'yy'), '1',
			to_char(xFVencimiento,'y'),
			to_char(xFVencimiento,'ddd'),
			xEmisora, xDIG_C60_M2);

	xCodBarraModa2:='90521'||xEmisora||LPAD(PkCartaPagoBanco.VarCartaPagoBanco,10,'0')||
				xDIG_C60_M2||'1'||
				xSufijo||
				to_char(sysdate,'yy')||
				to_char(xFVencimiento,'y')||
				to_char(xFVencimiento,'ddd')||
				--expresado en centimos de euros
			      LPAD(xImpor*100,8,'0')||'0';

	--se lo pasamos a los datos de cabecera
	Update TmpDeudorDPostales set
			EMISOR=xEmisora,
			REFERENCIA=LPAD(PkCartaPagoBanco.VarCartaPagoBanco,10,'0'),
			TRIBUTO=xSufijo,
			EJERCICIO=to_char(sysdate,'yy'),
			REMESA='01',
			IMPO=LPAD(xImpor,12,'0'),
			IMPORTE=xImpor,
			DISCRI_PERIODO='1',
			DIGITO_YEAR=to_char(xFVencimiento,'y'),
			F_JULIANA=to_char(xFVencimiento,'ddd'),
			FECHA_VENCIMIENTO=xFVencimiento,
			DC=xDC,
			COD_BARRAS_MOD1=xCodBarraModa1,
			DIGITO_C60_MODALIDAD2=xDIG_C60_M2,
			COD_BARRAS_MOD2=xCodBarraModa2
		where usuario=UID;

	--ponemos los valores seleccionados en la carta de pago

	--Valores de xCodOperacion:
	--		0: es un informe de debitos desde expedientes
	--		Cualquier otro valor: puede ser:
	--				informe de debitos de ventanilla
	--				carta de pago en ventanilla
	--				carta de pago desde expediente

	if (xCodOperacion<>0) then
	   PkCartaPagoBanco.AddReciboSeleccionados(xCodOperacion);

	   for v_Seguimiento IN cSeguimiento loop

		   if v_Seguimiento.Expediente is not null then
			   select embargo into xTramite from expedientes
				where id=v_Seguimiento.Expediente;

			   PkSeguimiento.AnotaCartaPago
				(v_Seguimiento.Expediente,
				'Ventanilla, Emisión de carta de pago número: '||
							PkCartaPagoBanco.VarCartaPagoBanco,
				xTramite,
				PkCartaPagoBanco.VarCartaPagoBanco);
		   end if;

	   end loop;
	else
	   PkCartaPagoBanco.AddAllReciboExpediente(xIDExpe);
	   select embargo into xTramite from expedientes where id=xIDExpe;
	   PkSeguimiento.AnotaCartaPago
			(xIDExpe,
			'Expedientes, Emisión de carta de pago número: '||
						PkCartaPagoBanco.VarCartaPagoBanco,
			xTramite,
			PkCartaPagoBanco.VarCartaPagoBanco);
	end if;

   END IF; --IF xTipo_Ingreso='DB' and xSuspendidos='N' THEN

END;


--Realizado: 2-1-2002. Agustín León Robles
-- 		Reimprimir una carta de pago de cualquier ingresos parciales
--Modificado: 23-10-2002. Agustín León Robles
--		Se añade 3 parametros más que es el tipo de ingreso porque si son ingresos
--		PD o VB no se puede imprimir por codigo de operacion ya que todos los recibos
--		ingresados por domiciliaciones o C60 tienen el mismo codigo de operacion. En estos
--		casos hay que imprimirlos uno a uno.
--		Tambien se añade si el ingreso es de Voluntaria o Ejecutiva. El ultimo parametro
--			xID es el Id de la tabla de Ingresos
-- Modificado: 24-01-2003. Lucas Fernández Pérez.
--	Se cambia el cursor para que no agrupe por valor y fecha, puesto que puede haber
-- un recibo con dos entregas y el mismo codigo de operación, y en ese caso se duplicarían
-- los datos en las tablas.Con el MAX(FECHA) sólo rellena en las tablas la información
-- una vez.
-- Modificado: 22/07/2003 Lucas Fernández Pérez. Se añaden los campos NOTIFICADO 
--			 y F_NOTIFICACION a la tabla TMPDEUDASVIVAS.
-- Modificado: 21/07/2004. Lucas Fernández Pérez. 
-- Antes xDeuda = principal+recargo+costas+demora y ahora se añade +demora_pendiente
-- DELPHI
PROCEDURE wtRepetirCartaParciales
				(xCodOperacion 	IN INT,
				xTipoIngreso 	IN CHAR,
				xVolEje 		IN CHAR,
				xID 			IN INT)
AS

xDESCRIPCION 		VARCHAR(50);
xNIF				CHAR(10);
xNOMBRE				VARCHAR(40);
xAYTO				CHAR(3);
xPADRON				CHAR(6);
xYEAR				CHAR(4);
xPERIODO			CHAR(2);
xRECIBO				INTEGER;
xCUOTA_INICIAL		FLOAT;
xPRINCIPAL			FLOAT;
xRECARGO			FLOAT;
xCOSTAS				FLOAT;
xDEMORA				FLOAT;
xDEUDA				FLOAT;
xDEMORA_PENDIENTE	FLOAT;
xPENDIENTE			FLOAT;
xOBJETO_TRIBUTARIO	VARCHAR(1024);
xEXPEDIENTE			INTEGER;
xTIPO				VARCHAR(11);
xDOM_TRIBUTARIO		VARCHAR(60);
xEntregasACuenta	FLOAT;
xFinPeVol			DATE;
xFApremio			DATE;
xCLAVE_CONCEPTO		VARCHAR(30);
xFUERAPLAZO			FLOAT DEFAULT 0;
xNotificado			CHAR(1);
xF_Notificacion		DATE;

CURSOR cIngresos IS
		SELECT VALOR, max(FECHA) as fecha FROM INGRESOS
		WHERE CODIGO_OPERACION=xCodOperacion
		group by valor;

CURSOR cUnSoloIngreso IS SELECT VALOR,FECHA FROM INGRESOS WHERE ID=xID;

BEGIN

	-- borrar el temporal de la deudas
	DELETE FROM TmpDeudasVivas WHERE USUARIO=UID;

	-- borrar el temporal de las entregas a cuenta de las deudas
	DELETE FROM TmpEntregasValor WHERE USUARIO=UID;

--
--Si el ingreso es PD: pago domiciliado hay que imprimir recibo a recibo
--Si el ingreso es VB: pago por ventanilla hay que tener en cuenta que este en voluntaria
--				para saber que es del C60 porque tambien puede haber ingresos del
--				C60 en ejecutiva y esos si se imprimen por codigo de operacion
--
if (xTipoIngreso='PD') or (xTipoIngreso='VB' and xVolEje='V') or (xTipoIngreso='CM') then

	-- Deudas seleccionadas por el usuario
	FOR v_UnSoloIngreso IN cUnSoloIngreso LOOP

		SELECT NIF,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
			CUOTA_INICIAL,PRINCIPAL,RECARGO,COSTAS,DEMORA,ENTREGAS_ANTESDEL_CARGO,
			(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) AS DEUDA,DEMORA_PENDIENTE,
			(PRINCIPAL + RECARGO + COSTAS + DEMORA - ENTREGAS_A_CUENTA +
						DEMORA_PENDIENTE) AS PENDIENTE,

			OBJETO_TRIBUTARIO,EXPEDIENTE,FIN_PE_VOL,F_APREMIO,NOTIFICADO,F_NOTIFICACION,
			DECODE(TIPO_DE_OBJETO,'R','RECIBO','LIQUIDACION') AS TIPO,DOM_TRIBUTARIO

		INTO 	xNIF,xNOMBRE,xAYTO,xPADRON,xYEAR,xPERIODO,xRECIBO,xCLAVE_CONCEPTO,
			xCUOTA_INICIAL,xPRINCIPAL,xRECARGO,xCOSTAS,xDEMORA,xFUERAPLAZO,
			xDEUDA,xDEMORA_PENDIENTE,xPENDIENTE,
			xOBJETO_TRIBUTARIO,xEXPEDIENTE,xFinPeVol,xFApremio,xNotificado,xF_Notificacion,
			xTIPO,xDOM_TRIBUTARIO

		FROM VALORES WHERE ID=v_UnSoloIngreso.VALOR;


	   -- Leer la descripción del concepto en función de su código
  	   SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS
      	WHERE CONCEPTO=xPADRON;

  	   -- Relación de entregas a cuenta
         wtEntregasDeUnValor(v_UnSoloIngreso.VALOR, v_UnSoloIngreso.Fecha,xEntregasACuenta);

	   -- Insertar una deuda en el temporal
  	   INSERT INTO TmpDeudasVivas
        	(xID,DNI_DEUDOR,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
		IDEXPE,CUOTA_INICIAL,PRINCIPAL,RECARGO,COSTAS,DEMORA,DEUDA,FUERA_PLAZO_JUNTA,
		DEMORA_PENDIENTE,PENDIENTE,ENTREGAS_A_CUENTA, NOTIFICADO, F_NOTIFICACION,
		OBJETO_TRIBUTARIO,xRECILIQUI, DESCRIPCION,DOM_TRIBUTARIO,FIN_PE_VOL,F_APREMIO)
	   VALUES
	  	(v_UnSoloIngreso.VALOR, xNIF, xNOMBRE, xAYTO,
		xPADRON, xYEAR, xPERIODO, xRECIBO, xCLAVE_CONCEPTO,
		xEXPEDIENTE, xCUOTA_INICIAL, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA,
		xDEUDA, xFUERAPLAZO, xDEMORA_PENDIENTE, xPENDIENTE, xEntregasACuenta,
		xNotificado, xF_Notificacion,	xOBJETO_TRIBUTARIO, xTIPO, 
		xDESCRIPCION, xDOM_TRIBUTARIO,xFinPeVol,xFApremio);

	END LOOP;
else

	-- Deudas seleccionadas por el usuario
	FOR v_Ingresos IN cIngresos LOOP

		SELECT NIF,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
			CUOTA_INICIAL,PRINCIPAL,RECARGO,COSTAS,DEMORA,ENTREGAS_ANTESDEL_CARGO,
			(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) AS DEUDA,DEMORA_PENDIENTE,
			(PRINCIPAL + RECARGO + COSTAS + DEMORA - ENTREGAS_A_CUENTA +
						DEMORA_PENDIENTE) AS PENDIENTE,

			OBJETO_TRIBUTARIO,EXPEDIENTE,FIN_PE_VOL,F_APREMIO,NOTIFICADO,F_NOTIFICACION,
			DECODE(TIPO_DE_OBJETO,'R','RECIBO','LIQUIDACION') AS TIPO,DOM_TRIBUTARIO

		INTO 	xNIF,xNOMBRE,xAYTO,xPADRON,xYEAR,xPERIODO,xRECIBO,xCLAVE_CONCEPTO,
			xCUOTA_INICIAL,xPRINCIPAL,xRECARGO,xCOSTAS,xDEMORA,xFUERAPLAZO,
			xDEUDA,xDEMORA_PENDIENTE,xPENDIENTE,
			xOBJETO_TRIBUTARIO,xEXPEDIENTE,xFinPeVol,xFApremio,xNotificado,xF_Notificacion,
			xTIPO,xDOM_TRIBUTARIO

		FROM VALORES WHERE ID=v_Ingresos.VALOR;


	   -- Leer la descripción del concepto en función de su código
  	   SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS
      	WHERE CONCEPTO=xPADRON;

  	   -- Relación de entregas a cuenta
         wtEntregasDeUnValor(v_Ingresos.VALOR, v_Ingresos.Fecha,xEntregasACuenta);

	   -- Insertar una deuda en el temporal
  	   INSERT INTO TmpDeudasVivas
        	(xID,DNI_DEUDOR,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
		IDEXPE,CUOTA_INICIAL,PRINCIPAL,RECARGO,COSTAS,DEMORA,DEUDA,FUERA_PLAZO_JUNTA,
		DEMORA_PENDIENTE,PENDIENTE,ENTREGAS_A_CUENTA,NOTIFICADO,F_NOTIFICACION,
		OBJETO_TRIBUTARIO,xRECILIQUI,DESCRIPCION,DOM_TRIBUTARIO,FIN_PE_VOL,F_APREMIO)
	   VALUES
	  	(v_Ingresos.VALOR, xNIF, xNOMBRE, xAYTO,
		xPADRON, xYEAR, xPERIODO, xRECIBO, xCLAVE_CONCEPTO,
		xEXPEDIENTE, xCUOTA_INICIAL, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA, xDEUDA, 
		xFUERAPLAZO, xDEMORA_PENDIENTE, xPENDIENTE, xEntregasACuenta,xNotificado,xF_Notificacion,
		xOBJETO_TRIBUTARIO, xTIPO, xDESCRIPCION, xDOM_TRIBUTARIO,xFinPeVol,xFApremio);

	END LOOP;

end if;

END;

-- 28-01-2002. Lucas Fernández Pérez. Para la impresión de carta de pago de embargos suspendidos
-- se necesita saber la información expediente a expediente. Cuando se llama a este procedure
-- se debe haber generado la cartapagobanco del expediente y rellenado el tmpdeudasvivas del
-- expediente.
-- Modificacion: 30/06/2003. Agustín León Robles. En el caso de que las cartas de pago
--			tuvieran como fecha tope el sabado o el domingo se pasarían a lunes

PROCEDURE wtDatosPostalesDeudorCPago(xIDExpe INTEGER)
AS

xTramite		char(1);
xEmisora		char(6);
xSufijo		char(3);
xDias			integer;
xDESCRIPCION 	VARCHAR(50);
xImpor		float;
xDIG_C60_M2		char(2);
xFVencimiento	date;
xCodBarraModa2	char(42);
xExpediente		char(10);
xReferencia 	INTEGER;
xDiaSemana		integer;
BEGIN
 	--buscamos la ultima carta de pago en banco generada para el expediente
	select max(cartapagobanco) into xReferencia from reciboscartapagobanco
		where valor in (select id from valores where expediente=xIDExpe);

	--se accede a la tabla de configuracion para recoger los datos de la emisora, sufijo
	--y dias de vencimiento para pagar en el banco
	select EMISORA,SUFIJO,DIAS_VENCIMIENTO into xEmisora,xSufijo,xDias
	from configuracion WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

	--averiguamos el importe de la carta de pago porque interviene en el calculo del digito
	--de control
	select sum(PENDIENTE) into xImpor from TmpDeudasVivas where usuario=UID and IDEXPE=xIDExpe;

	--la fecha de vencimiento del pago en el banco sera hoy mas los dias que se le de por
	--configuracion, en el caso de que el resultado de la suma fuera sabado o domingo se pasaría a
	--lunes
	select to_char(sysdate+xDias,'d') into xDiaSemana from Dual;

	--El 1: domingo.   
	if xDiaSemana=1 then
		xFVencimiento:=sysdate+xDias+1;
	--El 7: sabado
	elsif xDiaSemana=7 then
		xFVencimiento:=sysdate+xDias+2;
	else
		xFVencimiento:=sysdate+xDias;
	end if;

	--recogemos el número de expediente (formato de diez caracteres)
   	begin
	   -- recogemos el expediente asociado al IDExpe introducido como parametro
    	   SELECT EXPEDIENTE INTO xEXPEDIENTE FROM EXPEDIENTES
   	   WHERE ID=xIDExpe;
	   exception
		when no_data_found then
			xEXPEDIENTE:=null;
	end;

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(xImpor, xReferencia, xSufijo,
			to_char(sysdate,'yy'), '1',
			to_char(xFVencimiento,'y'),
			to_char(xFVencimiento,'ddd'),
			xEmisora, xDIG_C60_M2);

	xCodBarraModa2:='90521'||xEmisora||LPAD(PkCartaPagoBanco.VarCartaPagoBanco,10,'0')||
				xDIG_C60_M2||'1'||
				xSufijo||to_char(sysdate,'yy')||
				to_char(xFVencimiento,'y')||
				to_char(xFVencimiento,'ddd')||
				--expresado en centimos de euros
			      LPAD(xImpor*100,8,'0')||'0';

	--se lo pasamos a los datos de cabecera
	Update TmpDeudorDPostales set
			EXPEDIENTE=xExpediente,
			EMISOR=xEmisora,
			REFERENCIA=LPAD(xReferencia,10,'0'),
			TRIBUTO=xSufijo,
			EJERCICIO=to_char(sysdate,'yy'),
			REMESA='00',
			IMPO=LPAD(xImpor,12,'0'),
			IMPORTE=xImpor,
			DISCRI_PERIODO='1',
			DIGITO_YEAR=to_char(xFVencimiento,'y'),
			F_JULIANA=to_char(xFVencimiento,'ddd'),
			FECHA_VENCIMIENTO=xFVencimiento,
			DIGITO_C60_MODALIDAD2=xDIG_C60_M2,
			COD_BARRAS_MOD2=xCodBarraModa2
		where usuario=UID and idexpe=xIDEXPE;
END;

/*********************************************************************************************
Acción: Para la impresión de cartas de pago de fraccionamientos. Por cada plazo se rellenan
		los datos necesarios para la carta de pago.
Autor: Lucas Fernández Pérez. 15/04/2002
Modificación: Mª del Carmen Junco Gómez. 14/01/2003. Se añaden los datos del expediente a
			  la tabla TmpDeudorDPostales, si el fraccionamiento es de un expediente.
*********************************************************************************************/

PROCEDURE wtDatosPostalesDeudorCPFrac(
			xIDFrac IN INTEGER,
			xVol_Eje  IN CHAR)
AS

xIDExpe 		integer;
xExpediente		char(10);
xNIFEXPE		char(10);
xNOMBREEXPE 	CHAR(40);
xDOMI 			VARCHAR(50);
xCODPOSTAL 		CHAR(5);
xPOBLACION 		VARCHAR(35);
xPROVINCIA 		VARCHAR(35);
xEmisora		char(6);
xSufijo			char(3);
xDias			integer;
xDIG_C60_M2		char(2);
xFVencimiento	date;
xCodBarraModa2	char(42);
xReferencia 	integer;
xIDPlazo 		integer;

   CURSOR CPLAZOS IS
		SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS PENDIENTE, FECHA
		FROM PLAZOS_FRAC
		WHERE FRACCIONA=xIDFrac
		GROUP BY FECHA;

   CURSOR CPLAZOS_VOL IS
		SELECT ID,PRINCIPAL+RECARGO+COSTAS+DEMORA AS PENDIENTE, FECHA
		FROM PLAZOS_FRAC_VOL
		WHERE FRACCIONA=xIDFrac;

BEGIN

   DELETE FROM TMPDEUDORDPOSTALES WHERE USUARIO=UID;

   --se accede a la tabla de configuracion para recoger los datos de la emisora, sufijo
   --y dias de vencimiento para pagar en el banco
   select EMISORA,SUFIJO,DIAS_VENCIMIENTO into xEmisora,xSufijo,xDias
   from configuracion WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   -- Generamos los datos del deudor para cada plazo del fraccionamiento
   IF xVol_Eje='E' THEN

   	  SELECT EXPEDIENTEVALOR INTO xIDEXPE FROM FRACCIONAMIENTOS_VOLEJE
   	  WHERE ID=xIDFRAC;

      -- Leer los datos postales del deudor del expediente
      SELECT NIF,NOMBRE,VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO,
             CODIGO_POSTAL,POBLACION,PROVINCIA
      INTO   xNIFEXPE,xNOMBREEXPE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA
      FROM   CONTRIBUYENTES WHERE NIF=(SELECT DEUDOR FROM EXPEDIENTES WHERE ID=xIDEXPE);

      -- Leer el número de expediente
      SELECT EXPEDIENTE INTO xEXPEDIENTE FROM EXPEDIENTES WHERE ID=xIDExpe;

	  FOR v_PLAZO IN CPLAZOS LOOP

	     SELECT MIN(ID) into xIDPlazo FROM PLAZOS_FRAC WHERE
		 FRACCIONA=xIDFrac AND FECHA=v_PLAZO.FECHA;

	     -- Obtengo el ID de cartapagobanco.
	     -- En plazos_frac hay varias tuplas de la misma carta de pago, y en esta se escribia
	     -- el ID menor de ese conjunto de tuplas de plazos_frac, por lo que consultamos
	     -- el menor ID del conjunto de tuplas del plazo en plazos_frac.
	     select max(cartapagobanco) into xReferencia from reciboscartapagobanco
		 where plazo=xIDPlazo;

	     --la fecha de vencimiento del pago en el banco es la que indica el plazo
     	     xFVencimiento:=v_PLAZO.FECHA;

   	     --calcular los digitos de control del cuaderno 60 modalidad 2
   	     CALCULA_DC_MODALIDAD2_60(v_PLAZO.PENDIENTE, xReferencia, xSufijo,
			to_char(sysdate,'yy'), '1',
			to_char(xFVencimiento,'y'),
			to_char(xFVencimiento,'ddd'), xEmisora, xDIG_C60_M2);

   	     xCodBarraModa2:='90521'||xEmisora||LPAD(xReferencia,10,'0')||xDIG_C60_M2||'1'||
			xSufijo||to_char(sysdate,'yy')||to_char(xFVencimiento,'y')||
			to_char(xFVencimiento,'ddd')||
		    LPAD(v_PLAZO.PENDIENTE*100,8,'0')||'0';
			--expresado en centimos de euros

	     --se lo pasamos a los datos de cabecera.
	     insert into TmpDeudorDPostales (IDPLAZO,EMISOR,REFERENCIA,TRIBUTO,EJERCICIO,
	     		REMESA,IMPO,IMPORTE,DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,FECHA_VENCIMIENTO,
				DIGITO_C60_MODALIDAD2,COD_BARRAS_MOD2,IDEXPE,EXPEDIENTE,NIFEXPE,NOMBREEXPE,
				xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA)
	     VALUES (xIDPlazo,xEmisora,LPAD(xReferencia,10,'0'),xSufijo,
	     		to_char(sysdate,'yy'),'00',LPAD(v_PLAZO.PENDIENTE,12,'0'),
				v_PLAZO.PENDIENTE,'1',to_char(xFVencimiento,'y'),to_char(xFVencimiento,'ddd'),
				xFVencimiento,xDIG_C60_M2,xCodBarraModa2,xIDExpe,xExpediente,xNIFEXPE,
				xNOMBREEXPE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA);

	  END LOOP;

   ELSE

      FOR v_PLAZO IN CPLAZOS_VOL LOOP

	     -- Obtengo el ID de cartapagobanco
	     select max(cartapagobanco) into xReferencia from reciboscartapagobanco
	     where plazo_Vol = v_PLAZO.ID;

	     --la fecha de vencimiento del pago en el banco es la que indica el plazo
         xFVencimiento:=v_PLAZO.FECHA;

   	     --calcular los digitos de control del cuaderno 60 modalidad 2
   	     CALCULA_DC_MODALIDAD2_60(v_PLAZO.PENDIENTE, xReferencia, xSufijo,
			to_char(sysdate,'yy'), '1',
			to_char(xFVencimiento,'y'),
			to_char(xFVencimiento,'ddd'),
			xEmisora, xDIG_C60_M2);

   	     xCodBarraModa2:='90521'||xEmisora||LPAD(xReferencia,10,'0')||xDIG_C60_M2||'1'||
			xSufijo||to_char(sysdate,'yy')||to_char(xFVencimiento,'y')||
			to_char(xFVencimiento,'ddd')||
	        LPAD(v_PLAZO.PENDIENTE*100,8,'0')||'0';
			--expresado en centimos de euros

	     --se lo pasamos a los datos de cabecera. EN IDEXPE PASAMOS EL ID DE LA CARTA DE PAGO.
	     insert into TmpDeudorDPostales (IDPLAZO,EMISOR,REFERENCIA,TRIBUTO,EJERCICIO,
	  		REMESA,IMPO,IMPORTE,DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,FECHA_VENCIMIENTO,
		    DIGITO_C60_MODALIDAD2,COD_BARRAS_MOD2)
	     VALUES (v_PLAZO.ID,xEmisora,LPAD(xReferencia,10,'0'),
		    xSufijo,to_char(sysdate,'yy'),'00',LPAD(v_PLAZO.PENDIENTE,12,'0'),
		    v_PLAZO.PENDIENTE,'1',to_char(xFVencimiento,'y'),to_char(xFVencimiento,'ddd'),
		    xFVencimiento,xDIG_C60_M2,xCodBarraModa2);

	  END LOOP;

   END IF;

END;
-- **************************************************************************************
-- Autor:  M. Carmen Junco Gómez.
-- Fecha: 22/02/2002
-- Acción: Se utiliza en el procedimiento wtInformeCPBancoPorLotes para saber si dado un
-- 	  expediente concreto se ha de generar la carta de pago o recuperarla y si se
-- 	  ha de tener en cuenta o no este expediente.
-- Parámetros:
-- 	xIDEXPE: ID del Expediente;
-- 	xIDEMBARGO: ID del embargo de inmuebles.
-- 	xESTA_EMBARGO: Estado del embargo ('P': Pendiente,'O': Abierto,'L':Levantado).
-- 	xQUIEN: Desde que punto del programa se está llamando al proceso.
--       xSIGUE: 'true': Debe generar la información.
-- 	        'false': No debe generar la información.
-- 	xMOSTRAR: 'true': El embargo tratado cumple las condiciones para imprimir C.Pago.
-- 		    'false': El embargo tratado no cumple las condiciones para imprimir C. Pago.
-- ****************************************************************************************

PROCEDURE wtCPBancoLotesInmuebles(
						xIDEXPE	      IN INTEGER,
						xIDEMBARGO	      IN INTEGER,
						xESTA_EMBARGO     IN CHAR,
						xQUIEN	      IN CHAR,
						xSIGUE 		OUT BOOLEAN,
						xMOSTRAR		OUT BOOLEAN)
AS
   xF_Dili  DATE;
   xEmitida CHAR(1);
   xCuantos INTEGER;
BEGIN

      xSIGUE:=true;
      xMOSTRAR:=true;

	-- ----------------------------------------------------------------------------------
	-- Inmuebles cuando se pulsa el boton de NOTIFICACIONES AL DEUDOR Y A TERCEROS
	IF xESTA_EMBARGO='O' AND xQUIEN='D' THEN

	   -- Comprueba si tiene fecha de diligencia y fincas embargadas,y si se ha emitido la
	   -- la notificacion

         SELECT COUNT(*),MIN(E.EMITIDA_NOTI) INTO xCuantos,xEMITIDA
  	   FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F
	   WHERE E.ID=xIDEMBARGO AND E.IDEXPE=xIDEXPE AND E.ID=F.IDEMBINMU AND
	   E.F_DILIGENCIA IS NOT NULL;

	   if xCuantos=0 then
		-- El embargo no tienen fecha de diligencia, no muestra la Carta de Pago
	      xMostrar:=false;
		xEMITIDA:='N';
	   end if;

	   if xEMITIDA='S' then  -- Si ya esta emitida la notificacion no vuelve a crearla
		xSigue:=False;
	   end if;

	-- ----------------------------------------------------------------------------------
	-- Inmuebles cuando se pulsa el boton de VALORACION MUNICIPAL
	ELSIF xESTA_EMBARGO='O' AND xQUIEN='V' THEN

	   -- Comprueba si tiene fecha de mandamiento, y mira si se ha emitido ya la valoracion.
         SELECT COUNT(*),MIN(E.VALORACION) INTO xCuantos, xEMITIDA
	   FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F
	   WHERE E.ID=xIDEMBARGO AND E.IDEXPE=xIDEXPE AND E.ID=F.IDEMBINMU AND
	   E.F_MANDAMIENTO IS NOT NULL
	   AND E.ID NOT IN
	   (SELECT IDEMBINMU FROM VWFINCASEMBARGADAS
	    WHERE IDEMBINMU=E.ID AND FECHA_EMBARGO IS NULL);

	   if xCuantos=0 then
		-- El embargo no tiene emitido el mandamiento, no muestra la C.P.
	      xMostrar:=false;
		xEMITIDA:='N';
	   end if;

	   if xEMITIDA='S' then  -- Si ya esta emitida la valoracion no vuelve a crearla
		xSigue:=False;
	   end if;

	-- ----------------------------------------------------------------------------------
	-- Inmuebles cuando se pulsa el boton de SUBASTA
	ELSIF xESTA_EMBARGO='O' AND xQUIEN='S' THEN

	   -- Comprueba si tiene fecha de mandamiento, y mira si se ha emitido ya la valoracion.
         SELECT COUNT(*),MIN(E.EMI_NOTI_SUBA) INTO xCuantos,xEMITIDA
	   FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F
	   WHERE E.ID=xIDEMBARGO AND E.IDEXPE=xIDEXPE AND E.ID=F.IDEMBINMU AND
	   E.F_SUBASTA IS NOT NULL AND
	   E.F_MANDAMIENTO IS NOT NULL AND E.VALORACION='S';

	   if xCuantos=0 then
	      -- El embargo no tiene fecha de mandamiento o valoración, no muestra la C.P.
	      xMostrar:=false;
		xEMITIDA:='N';
	   end if;

	   if xEMITIDA='S' then  -- Si ya esta emitida la subasta no vuelve a crearla
		xSigue:=False;
	   end if;
	END IF;

END;

-- **************************************************************************************
-- Autor:  M. Carmen Junco Gómez.
-- Fecha: 22/02/2002
-- Acción: Se utiliza en el procedimiento wtInformeCPBancoPorLotes para saber si dado un
-- 	  expediente concreto se ha de generar la carta de pago o recuperarla y si se
-- 	  ha de tener en cuenta o no este expediente.
-- Parámetros:
-- 	xIDEXPE: ID del Expediente;
-- 	xIDEMBARGO: ID del embargo de inmuebles.
-- 	xESTA_EMBARGO: Estado del embargo ('P': Pendiente,'O': Abierto,'L':Levantado).
-- 	xQUIEN: Desde que punto del programa se está llamando al proceso.
--    xSIGUE: 'true': Debe generar la información.
-- 	        'false': No debe generar la información.
-- 	xMOSTRAR: 'true': El embargo tratado cumple las condiciones para imprimir C.Pago.
-- 		    'false': El embargo tratado no cumple las condiciones para imprimir C. Pago.
-- ****************************************************************************************

PROCEDURE wtCPBancoLotesVehiculos(
						xIDEXPE	      IN INTEGER,
						xIDEMBARGO	      IN INTEGER,
						xESTA_EMBARGO     IN CHAR,
						xQUIEN	      IN CHAR,
						xSIGUE		OUT BOOLEAN,
						xMOSTRAR		OUT BOOLEAN)
AS
   xF_Dili  DATE;
   xCuantos INTEGER;
   xEmitida CHAR(1);
BEGIN
   xSIGUE:=true;
   xMOSTRAR:=true;
END;

-- **************************************************************************************
-- Autor: Lucas Fernández Pérez
-- Fecha: 08/02/2002
-- Acción: Rellena tablas temporales con información para mostrar la carta de pago en bancos
--         Se utiliza en salarios,inmuebles y vehículos, por número de lote, por lo que lo
--      hace para cada uno de los expedientes dentro del lote.
-- Parámetros:
-- 	xIDEXPE: ID del Expediente;
-- 	xEMBARGO: Tipo de Embargo: '3','4' u '8' para Salarios, Inmuebles y Vehículos.
-- 	xESTA_EMBARGO: Estado del embargo ('P':Pendiente,'O':Abierto,'L':Levantado).
-- 	xLOTE: Número de Lote.
-- 	xGENERA_CARTAPAGO: 'S': genera cartas de pago.
-- 				 'N': accede a cartas de pago que deben existir previamente.
-- 	xGENERA_TODO: 'S': trata todos los expedientes del lote.
-- 			  'N': solo trata cartas de pago de expedientes sin emitir al deudor.
-- 	xQUIEN: Desde que punto del programa se está llamando al proceso.
--
-- ****************************************************************************************

PROCEDURE wtInformeCPBancoPorLotes(
					xEMBARGO 		IN CHAR,
					xESTA_EMBARGO 	IN CHAR,
					xLOTE 		IN CHAR,
					xGENERA_CARTAPAGO IN CHAR,
					xGENERA_TODO 	IN CHAR,
					xQUIEN 		IN CHAR)
AS
xDeudor CHAR(10);
xSigue BOOLEAN;
xMostrar BOOLEAN;
xEmitida CHAR(1);
xF_Dili  DATE;
xCuantos INTEGER;

CURSOR CEXPEDIENTES IS SELECT DEUDOR,ID AS IDEXPE FROM EXPEDIENTES
	 		  WHERE LOTE=xLOTE AND EMBARGO=xEMBARGO AND ESTA_EMBARGO=xESTA_EMBARGO;
CURSOR CINMUEBLES IS SELECT DEUDOR,E.ID AS IDEXPE,M.ID AS IDEMBARGO
			  FROM EXPEDIENTES E,EMBARGOS_INMUEBLES M
			  WHERE E.ID=M.IDEXPE AND E.LOTE=xLOTE
		        AND E.EMBARGO=xEMBARGO AND E.ESTA_EMBARGO=xESTA_EMBARGO;
CURSOR CVEHICULOS IS SELECT DEUDOR,E.ID AS IDEXPE,M.ID AS IDEMBARGO
			  FROM EXPEDIENTES E,EMBARGOS_AUTOS M
			  WHERE E.ID=M.IDEXPE AND E.LOTE=xLOTE
		        AND E.EMBARGO=xEMBARGO AND E.ESTA_EMBARGO=xESTA_EMBARGO;

BEGIN

   -- -----------------------------------------------------------------------------------
   -- PRIMER RECORRIDO
   -- -----------------------------------------------------------------------------------

   IF xEMBARGO='3' AND xESTA_EMBARGO='O' THEN
      FOR v_SALARIOS IN CEXPEDIENTES
      LOOP
	   	xSigue:=True;
	   	xMostrar:=True;

	      begin
		   SELECT EMITIDA_DEUDOR INTO xEMITIDA FROM EMBARGOS_SALARIOS
               WHERE IDEXPE=v_SALARIOS.IDEXPE;
	      exception
		   when no_data_found then
		      xEMITIDA:='N';
	      end;

	      if xEMITIDA='S' then -- No debe generar informacion
		   xSigue:=false;
	      end if;

            -- Se pide generar las cartas de pago no generadas.
            IF (xGENERA_CARTAPAGO='S') AND (xMostrar) THEN
               IF xSigue=True THEN -- Si puede generarla, la crea.
	            PkwtDocIngreso.wtDeudasVivasySuspendidas(v_SALARIOS.IDEXPE,0,'DB','N','N');
               ELSIF xGENERA_TODO='S' THEN
                  -- No puede generarla pero se pide que se imprima
	            -- Poniendo un valor distinto de 'DB' el procedimiento
                  -- no crea la Carta de Pago.
	            PkwtDocIngreso.wtDeudasVivasySuspendidas(v_SALARIOS.IDEXPE,0, 'VE','N','N');
               END IF;

            ELSIF xGENERA_CARTAPAGO='N' THEN
               -- No generar ninguna CP. Esto se da en reimpresiones de expedientes suspendidos
	         -- ¿Por qué? xSigue indica que la genere porque el exped.no está abierto.
               -- Pero la Carta de pago ya existe, por lo que solo hay que reimprimirla.
               -- Por eso se pone esta opción.

               PkwtDocIngreso.wtDeudasVivasySuspendidas(v_SALARIOS.IDEXPE,0,'VE','N','N');

            END IF;

	END LOOP;

   ELSIF xEMBARGO='4' AND xESTA_EMBARGO='O' THEN
	  FOR v_INMUEBLES IN CINMUEBLES
	  LOOP

	   wtCPBancoLotesInmuebles(v_INMUEBLES.IDEXPE,
			  	         v_INMUEBLES.IDEMBARGO,
			  		   xESTA_EMBARGO,
					   xQUIEN,
					   xSIGUE,
					   xMOSTRAR);

         -- Se pide generar las cartas de pago no generadas.
         IF (xGENERA_CARTAPAGO='S') AND (xMostrar) THEN
            IF xSigue=True THEN -- Si puede generarla, la crea.
	         PkwtDocIngreso.wtDeudasVivasySuspendidas(v_INMUEBLES.IDEXPE,0,'DB','N','N');
            ELSIF xGENERA_TODO='S' THEN
               -- No puede generarla pero se pide que se imprima
	         -- Poniendo un valor distinto de 'DB' el procedimiento
               -- no crea la Carta de Pago.
	         PkwtDocIngreso.wtDeudasVivasySuspendidas(v_INMUEBLES.IDEXPE,0, 'VE','N','N');
            END IF;

         ELSIF xGENERA_CARTAPAGO='N' THEN
            -- No generar ninguna CP. Esto se da en reimpresiones de expedientes suspendidos
	      -- ¿Por qué? xSigue indica que la genere porque el exped.no está abierto.
            -- Pero la Carta de pago ya existe, por lo que solo hay que reimprimirla.
            -- Por eso se pone esta opción.

            PkwtDocIngreso.wtDeudasVivasySuspendidas(v_INMUEBLES.IDEXPE,0,'VE','N','N');

         END IF;

	  END LOOP;

   ELSIF xEMBARGO='8' AND xESTA_EMBARGO='O' THEN
      FOR v_VEHICULOS IN CVEHICULOS
	LOOP

	   wtCPBancoLotesVehiculos(v_VEHICULOS.IDEXPE,
			  		   v_VEHICULOS.IDEMBARGO,
			  		   xESTA_EMBARGO,
					   xQUIEN,
					   xSIGUE,
					   xMOSTRAR);

         -- Se pide generar las cartas de pago no generadas.
         IF (xGENERA_CARTAPAGO='S') AND (xMostrar) THEN
            IF xSigue=True THEN -- Si puede generarla, la crea.
	         PkwtDocIngreso.wtDeudasVivasySuspendidas(v_VEHICULOS.IDEXPE,0,'DB','N','N');
            ELSIF xGENERA_TODO='S' THEN
               -- No puede generarla pero se pide que se imprima
	         -- Poniendo un valor distinto de 'DB' el procedimiento
               -- no crea la Carta de Pago.
	         PkwtDocIngreso.wtDeudasVivasySuspendidas(v_VEHICULOS.IDEXPE,0, 'VE','N','N');
            END IF;

         ELSIF xGENERA_CARTAPAGO='N' THEN
            -- No generar ninguna CP. Esto se da en reimpresiones de expedientes suspendidos
	      -- ¿Por qué? xSigue indica que la genere porque el exped.no está abierto.
            -- Pero la Carta de pago ya existe, por lo que solo hay que reimprimirla.
            -- Por eso se pone esta opción.

            PkwtDocIngreso.wtDeudasVivasySuspendidas(v_VEHICULOS.IDEXPE,0,'VE','N','N');

         END IF;

      END LOOP;

   ELSIF xESTA_EMBARGO='P' OR xESTA_EMBARGO='S' THEN  --Independientemente del embargo.

      FOR v_EXPE IN CEXPEDIENTES
      LOOP
	   xSigue:=True;
	   xMostrar:=True;
	   REFRESHEXPE(v_EXPE.IDEXPE); -- REFRESCO LOS INTERESES DEL EXPEDIENTE
         -- Se pide generar las cartas de pago no generadas.
	   IF (xGENERA_CARTAPAGO='S') AND (xMostrar) THEN
          	IF xSigue=True THEN -- Si puede generarla, la crea.
	       	PkwtDocIngreso.wtDeudasVivasySuspendidas(v_EXPE.IDEXPE,0,'DB','N','N');
          	ELSIF xGENERA_TODO='S' THEN
             	-- No puede generarla pero se pide que se imprima
	       	-- Poniendo un valor distinto de 'DB' el procedimiento
             	-- no crea la Carta de Pago.
	       	PkwtDocIngreso.wtDeudasVivasySuspendidas(v_EXPE.IDEXPE,0, 'VE','N','N');
          	END IF;

	   ELSIF xGENERA_CARTAPAGO='N' THEN
          	-- No generar ninguna CP. Esto se da en reimpresiones de expedientes suspendidos
	    	-- ¿Por qué? xSigue indica que la genere porque el exped.no está abierto.
          	-- Pero la Carta de pago ya existe, por lo que solo hay que reimprimirla.
          	-- Por eso se pone esta opción.

          	PkwtDocIngreso.wtDeudasVivasySuspendidas(v_EXPE.IDEXPE,0,'VE','N','N');
         END IF;

	END LOOP;

   END IF;

   -- ---------------------------------------------------------------------------------------
   -- SEGUNDO RECORRIDO: Doy una segunda vuelta para actualizar los datos de los deudores
   -- ---------------------------------------------------------------------------------------

   IF xEMBARGO='3' AND xESTA_EMBARGO='O' THEN
      FOR v_SALARIOS IN CEXPEDIENTES
      LOOP

	   xSigue:=True;
	   xMostrar:=True;

	      begin
		   SELECT EMITIDA_DEUDOR INTO xEMITIDA FROM EMBARGOS_SALARIOS
               WHERE IDEXPE=v_SALARIOS.IDEXPE;
	      exception
		   when no_data_found then
		      xEMITIDA:='N';
	      end;

	      if xEMITIDA='S' then -- No debe generar informacion
	         xSigue:=false;
	      end if;

	      -- Si se pide generar todo, hay en la tabla una tupla por cada expediente
	      -- Si se pide generar solo las cartas nuevas, habra tuplas de expedientes
		-- con xSigue=true.
 	      IF (xGENERA_TODO='S' or (xGENERA_TODO='N' AND xSigue=true)) and (xMostrar) THEN
	         PkwtDocIngreso.wtDatosPostalesDeudor(v_SALARIOS.DEUDOR, v_SALARIOS.IDEXPE,'N');
	         PkwtDocIngreso.wtDatosPostalesDeudorCPago(v_SALARIOS.IDEXPE);
	      END IF;

	END LOOP;

   ELSIF xEMBARGO='4' AND xESTA_EMBARGO='O'  THEN
      FOR v_INMUEBLES IN CINMUEBLES
	LOOP

	   wtCPBancoLotesInmuebles(v_INMUEBLES.IDEXPE,
			  	         v_INMUEBLES.IDEMBARGO,
			  		   xESTA_EMBARGO,
					   xQUIEN,
					   xSIGUE,
					   xMOSTRAR);
	   -- Si se pide generar todo, hay en la tabla una tupla por cada expediente
	   -- Si se pide generar solo las cartas nuevas, habra tuplas de expedientes
         -- con xSigue=true.
 	   IF (xGENERA_TODO='S' or (xGENERA_TODO='N' AND xSigue=true)) and (xMostrar) THEN
	      PkwtDocIngreso.wtDatosPostalesDeudor(v_INMUEBLES.DEUDOR, v_INMUEBLES.IDEXPE,'N');
	      PkwtDocIngreso.wtDatosPostalesDeudorCPago(v_INMUEBLES.IDEXPE);
	   END IF;

	END LOOP;

   ELSIF xEMBARGO='8' AND xESTA_EMBARGO='O' THEN
      FOR v_VEHICULOS IN CVEHICULOS
	LOOP

	   wtCPBancoLotesVehiculos(v_VEHICULOS.IDEXPE,
			  		   v_VEHICULOS.IDEMBARGO,
			  		   xESTA_EMBARGO,
					   xQUIEN,
					   xSIGUE,
					   xMOSTRAR);

	   -- Si se pide generar todo, hay en la tabla una tupla por cada expediente
	   -- Si se pide generar solo las cartas nuevas, habra tuplas de expedientes
         -- con xSigue=true.
 	   IF (xGENERA_TODO='S' or (xGENERA_TODO='N' AND xSigue=true)) and (xMostrar) THEN
	      PkwtDocIngreso.wtDatosPostalesDeudor(v_VEHICULOS.DEUDOR, v_VEHICULOS.IDEXPE,'N');
	      PkwtDocIngreso.wtDatosPostalesDeudorCPago(v_VEHICULOS.IDEXPE);
	   END IF;

      END LOOP;


   ELSIF xESTA_EMBARGO='P' OR xESTA_EMBARGO='S'  THEN --Independientemente del embargo.

      FOR v_EXPE IN CEXPEDIENTES
      LOOP
	   	xSigue:=True;
	   	xMostrar:=True;
	      -- Si se pide generar todo, hay en la tabla una tupla por cada expediente
	      -- Si se pide generar solo las cartas nuevas, habra tuplas de expedientes
		-- con xSigue=true.
 	      IF (xGENERA_TODO='S' or (xGENERA_TODO='N' AND xSigue=true)) and (xMostrar) THEN

	         PkwtDocIngreso.wtDatosPostalesDeudor(v_EXPE.DEUDOR, v_EXPE.IDEXPE,'N');

		   if xQUIEN='S' then -- Se piden los datos de carta de pago. Hay que generarlos.
	            PkwtDocIngreso.wtDatosPostalesDeudorCPago(v_EXPE.IDEXPE);
		   end if;

	      END IF;

	END LOOP;

   END IF;

END;

-- ***************************************************************************************
--Autor: Lucas Fernández Pérez
--Fecha: 12/07/2002
--Acción: Rellena tablas temporales con información para mostrar la carta de pago en bancos
--        Se utiliza en salarios,inmuebles y vehículos, de todos los pendientes.

-- Parámetros:
--	xEMBARGO: Tipo de Embargo: '3','4' u '8' para Salarios, Inmuebles y Vehículos.
--	xESTA_EMBARGO: Estado del embargo ('P':Pendiente,'O':Abierto,'L':Levantado).
--	xGENERA_CARTAPAGO: 'S': genera cartas de pago.
--				 'N': accede a cartas de pago que deben existir previamente.
--	xGENERA_TODO: 'S': trata todos los expedientes del lote.
--			  'N': solo trata cartas de pago de expedientes sin emitir al deudor.
--  	xQUIEN:	'S': Genera informacion para el impreso de carta de pago
--			'N': No muestra informacion para la carta de pago.
-- ***************************************************************************************
PROCEDURE wtInformeCPBancoTodosPend(
					xEMBARGO 		IN CHAR,
					xESTA_EMBARGO 	IN CHAR,
					xGENERA_CARTAPAGO IN CHAR,
					xQUIEN IN CHAR)
AS

CURSOR CEXPEDIENTES IS SELECT DEUDOR,ID AS IDEXPE FROM EXPEDIENTES
	 		  WHERE EMBARGO=xEMBARGO AND ESTA_EMBARGO=xESTA_EMBARGO;

BEGIN

   IF xESTA_EMBARGO='P' OR xESTA_EMBARGO='S'  THEN --Independientemente del embargo.

      FOR v_EXPE IN CEXPEDIENTES
      LOOP
	   REFRESHEXPE(v_EXPE.IDEXPE); -- REFRESCO LOS INTERESES DEL EXPEDIENTE
         -- Se pide generar las cartas de pago no generadas.
	   IF xGENERA_CARTAPAGO='S'  THEN
       	PkwtDocIngreso.wtDeudasVivasySuspendidas(v_EXPE.IDEXPE,0,'DB','N','N');

	   ELSIF xGENERA_CARTAPAGO='N' THEN
          	-- No generar ninguna CP. Esto se da en reimpresiones de expedientes suspendidos
	    	-- ¿Por qué? xSigue indica que la genere porque el exped.no está abierto.
          	-- Pero la Carta de pago ya existe, por lo que solo hay que reimprimirla.
          	-- Por eso se pone esta opción.
          	PkwtDocIngreso.wtDeudasVivasySuspendidas(v_EXPE.IDEXPE,0,'VE','N','N');
         END IF;

	END LOOP;

   	-- ------------------------------------------------------------------------------------
   	-- SEGUNDO RECORRIDO: Doy una segunda vuelta para actualizar los datos de los deudores
   	-- ------------------------------------------------------------------------------------
      FOR v_EXPE IN CEXPEDIENTES
      LOOP

         PkwtDocIngreso.wtDatosPostalesDeudor(v_EXPE.DEUDOR, v_EXPE.IDEXPE,'N');

	   if xQUIEN='S' then -- Se piden los datos de carta de pago. Hay que generarlos.
         	PkwtDocIngreso.wtDatosPostalesDeudorCPago(v_EXPE.IDEXPE);
	   end if;

	END LOOP;

   END IF;

END;


-- 8-02-2002.Lucas Fernández Pérez
-- Rellena tablas temporales con información para mostrar la carta de pago en bancos
-- Es para todos los expedientes en un determinado embargo y en un intervalo.
-- Valores de los parámetros de entrada:
-- xGENERA_CARTAPAGO = 'S' -> genera cartas de pago
-- xGENERA_CARTAPAGO = 'N' -> accede a cartas de pago que deben existir previamente
--
-- Modificado : 30/12/2002. Lucas Fernández Pérez.
--	Se utiliza para expedientes pendientes o suspendidos de cualquier embargo entre fechas.
--
PROCEDURE wtInformeCPBancoEntreFechas(
					xEMBARGO 		IN CHAR,
					xESTA_EMBARGO 	IN CHAR,
					xDESDE 		IN DATE,
					xHASTA 		IN DATE,
					xGENERA_CARTAPAGO IN CHAR,
					xQUIEN 	IN CHAR)
AS

CURSOR CEXPE IS SELECT DEUDOR,ID AS IDEXPE FROM EXPEDIENTES WHERE
		F_EMBARGO BETWEEN xDESDE AND xHASTA
		AND EMBARGO=xEMBARGO AND ESTA_EMBARGO=xESTA_EMBARGO;

BEGIN

   IF xESTA_EMBARGO='P' OR xESTA_EMBARGO='S'  THEN --Independientemente del embargo.

      FOR v_EXPE IN CEXPE
      LOOP
	   REFRESHEXPE(v_EXPE.IDEXPE); -- REFRESCO LOS INTERESES DEL EXPEDIENTE
         -- Se pide generar las cartas de pago no generadas.
	   IF xGENERA_CARTAPAGO='S'  THEN
       	PkwtDocIngreso.wtDeudasVivasySuspendidas(v_EXPE.IDEXPE,0,'DB','N','N');

	   ELSIF xGENERA_CARTAPAGO='N' THEN
          	-- No generar ninguna CP. Esto se da en reimpresiones de expedientes suspendidos
	    	-- ¿Por qué? xSigue indica que la genere porque el exped.no está abierto.
          	-- Pero la Carta de pago ya existe, por lo que solo hay que reimprimirla.
          	-- Por eso se pone esta opción.
          	PkwtDocIngreso.wtDeudasVivasySuspendidas(v_EXPE.IDEXPE,0,'VE','N','N');
         END IF;

	END LOOP;

   	-- ------------------------------------------------------------------------------------
   	-- SEGUNDO RECORRIDO: Doy una segunda vuelta para actualizar los datos de los deudores
   	-- ------------------------------------------------------------------------------------
      FOR v_EXPE IN CEXPE
      LOOP

         PkwtDocIngreso.wtDatosPostalesDeudor(v_EXPE.DEUDOR, v_EXPE.IDEXPE,'N');

	   if xQUIEN='S' then -- Se piden los datos de carta de pago. Hay que generarlos.
         	PkwtDocIngreso.wtDatosPostalesDeudorCPago(v_EXPE.IDEXPE);
	   end if;

	END LOOP;

   END IF;

END;

-- 28-01-2002.Lucas Fernández Pérez
-- Rellena tablas temporales con información para mostrar la carta de pago en bancos
-- Si es para salarios,inmuebles o vehiculos, lo hace por número de lote.
-- Si tiene numero de lote (o entre fechas), lo hace para todos los expedientes del mismo,
-- si no tiene numero de lote (o entre fechas), lo hace para un solo expediente.
-- Valores de los parámetros de entrada:
-- xIDEXPE = -1 -> es por numero de lote o entre fechas
-- 	xGENERA_TODO = 'S' -> trata todos los expedientes del lote (o entre fechas)
-- 	xGENERA_TODO = 'N' -> solo trata cartas de pago de expedientes sin emitir al deudor
-- xIDEXPE <> -1 -> es para un solo expediente

-- xGENERA_CARTAPAGO = 'S' -> genera cartas de pago
-- xGENERA_CARTAPAGO = 'N' -> accede a cartas de pago que deben existir previamente

-- xQUIEN -> Indica donde se ha pedido el informe, para que así se generen unas cartas de pago
--		determinadas.
-- 		Cuando se llama al procedimiento desde la suspension de expedientes, indica
--		si se quiere generar informacion para el impreso de carta de pago del expediente
--  		('S') o si no es necesario (sólo se imprime un informe de deudas del mismo ('N'))
--
-- Modificado: 30/12/2002. Lucas Fernández Pérez. Se habilita poder hacerlo tambien para
--				expedientes en embargo de cuentas.
--
PROCEDURE wtInformeCPBancoEmbargos(
					xIDEXPE IN INTEGER,
					xEMBARGO IN CHAR,
					xESTA_EMBARGO IN CHAR,
					xLOTE IN CHAR,
					xDESDE IN DATE,
					xHASTA IN DATE,
					xGENERA_CARTAPAGO IN CHAR,
					xGENERA_TODO IN CHAR,
					xQUIEN	IN CHAR)
AS
xDeudor CHAR(10);

BEGIN

   -- Primero borra todos los datos de las tablas temporales que va a rellenar.
   DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID;
   DELETE FROM TmpEntregasValor WHERE USUARIO=UID;
   DELETE FROM TMPDEUDORDPOSTALES WHERE USUARIO=UID;

   IF xIDEXPE=-1 THEN -- Para todo un lote si es salarios o inmuebles o vehiculos

   	IF xEMBARGO='3' OR xEMBARGO='4' OR xEMBARGO='8' THEN
	   -- Embargo de salarios,inmuebles o vehiculos : Por número de Lote
	   wtInformeCPBancoPorLotes(xEMBARGO,xESTA_EMBARGO,
							xLOTE,xGENERA_CARTAPAGO,xGENERA_TODO,xQUIEN);
	ELSIF xEMBARGO='1' THEN
	   -- Embargo de cuentas: Entre fechas
	   wtInformeCPBancoEntreFechas(xEMBARGO,xESTA_EMBARGO,xDESDE,xHASTA,
							xGENERA_CARTAPAGO,xQUIEN);

	END IF;

   ELSIF xIDEXPE=-2 THEN -- Para todos los expedientes pendientes de un trámite de embargo

   	IF xEMBARGO='1' OR xEMBARGO='3' OR xEMBARGO='4' OR xEMBARGO='8' THEN
	   -- Embargo de cuentas,salarios,inmuebles o vehiculos : Todos los pendientes
	   wtInformeCPBancoTodosPend(xEMBARGO,xESTA_EMBARGO,xGENERA_CARTAPAGO,xQUIEN);
	END IF;

   ELSE -- Para un solo expediente

   	REFRESHEXPE(xIDEXPE); -- REFRESCO LOS INTERESES DEL EXPEDIENTE

   	IF xGENERA_CARTAPAGO='S' THEN -- Genera la carga de pago.
  		PkwtDocIngreso.wtDeudasVivasySuspendidas( xIDEXPE, 0, 'DB','N','N');
   	ELSE -- Con sólo tener un valor distinto a 'DB' ya no genera la carta de pago
	  	PkwtDocIngreso.wtDeudasVivasySuspendidas( xIDEXPE, 0, 'VE','N','N');
	END IF;

	SELECT DEUDOR INTO xDeudor FROM EXPEDIENTES WHERE ID=xIDEXPE;
	PkwtDocIngreso.wtDatosPostalesDeudor(xDeudor,xIDExpe,'N');

	if xQUIEN='S' then -- Se piden los datos de carta de pago. Hay que generarlos.
	   PkwtDocIngreso.wtDatosPostalesDeudorCPago(xIDExpe);
	end if;

   END IF;

END;

-- Inicializar el paquete

BEGIN

SELECT EstadoIani INTO State_of_I_Animate FROM DATOSPERR;


END;
/

