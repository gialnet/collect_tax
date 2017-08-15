-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
-- 
-- Se utiliza para agrupar las deudas que van en un determinado documento con el cual
-- el contribuyente irá a pagar en cualquier banco. Despues el banco nos devolverá en
-- soporte magnético el código de identificación del documento por el cúal nosotros
-- cazaremos a que deudas corresponde
--

CREATE OR REPLACE TRIGGER T_CartaPagoBanco
BEFORE INSERT ON CartaPagoBanco
FOR EACH ROW

BEGIN

   SELECT GENCartaPagoBanco.NEXTVAL INTO :NEW.ID FROM DUAL;
   --se graba en usuarios para recojerlo en el procedimiento NewAsistencia, porque se diseño
   --despues y habria que tocar varios procedimientos, esto se hará en una posterior revision
   update usuarios set LAST_NUMERO=:NEW.ID where usuario=user;

END T_CartaPagoBanco;
/

--
-- Crear relaciones de cartas de pago en banco
--
CREATE OR REPLACE TRIGGER T_CartasPagoRelaciones
BEFORE INSERT ON CartasPagoRelaciones
FOR EACH ROW
BEGIN
   SELECT GENRelaCartaPago.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--
-- 		Paquete Gestión de cartas de pago en bancos 
--
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

--
-- Modificado: 10/01/2002 Agustin Leon Robles
--			En el metodo AddAllReciboExpediente se ha añadido la condicion de 
--							f_suspension is null
--
CREATE OR REPLACE PACKAGE PkCartaPagoBanco
AS

-- Añade una nueva carta de pago
PROCEDURE NewCartaPago;

-- Añade una nueva carta de pago
PROCEDURE NewCartaPago(xIDRelacion IN INTEGER);

-- Añade un valor. Sobrecargado.
PROCEDURE CartaPagoAddRecibo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xVALOR   	 RecibosCartaPagoBanco.VALOR%Type,
	xRECARGOVALOR RecibosCartaPagoBanco.RECARGOVALOR%Type,
	xCOSTASVALOR  RecibosCartaPagoBanco.COSTASVALOR%Type);
PROCEDURE CartaPagoAddRecibo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xVALOR   	 RecibosCartaPagoBanco.VALOR%Type,
	xRECARGOVALOR RecibosCartaPagoBanco.RECARGOVALOR%Type,
	xCOSTASVALOR  RecibosCartaPagoBanco.COSTASVALOR%Type,
	xN_RELACION  RecibosCartaPagoBanco.N_RELACION%Type);

-- Elimina un elemento 
PROCEDURE CartaPagoDelRecibo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xVALOR   	 RecibosCartaPagoBanco.VALOR%Type);

-- borra todos los elemtos 
PROCEDURE CartaPagoDelAllRecibos(xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type);

-- Todas las deudas vivas de un expediente
PROCEDURE AddAllReciboExpediente( xIDExpe IN INT);

-- Todas las deudas vivas de un DEUDOR
PROCEDURE AddAllReciboDeudor(xNIF IN CHAR,
	xN_RELACION  RecibosCartaPagoBanco.N_RELACION%Type);

-- Las seleccionadas por el usuario desde el interfaz. Sobrecargado.
PROCEDURE AddReciboSeleccionados( xCodOperacion IN INT);
PROCEDURE AddReciboSeleccionados( xCodOperacion IN INT, xN_RELACION IN CHAR);

-- Sobre Fraccionamientos
-- Inserta un plazo
PROCEDURE CartaPagoAddPlazo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xPlazo	 RecibosCartaPagoBanco.PLAZO%Type);

-- Sobre Fraccionamientos
-- Inserta un plazo de un fraccionamiento en voluntaria
PROCEDURE CartaPagoAddPlazoVol(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xPlazo	 RecibosCartaPagoBanco.PLAZO%Type);

-- Elimina un plazo
PROCEDURE CartaPagoDelPlazo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xPlazo	 RecibosCartaPagoBanco.PLAZO%Type);

VarCartaPagoBanco INT; -- Variable Interna

END PkCartaPagoBanco;
/

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--
-- 		Gestión de cartas de pago en bancos
--
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

CREATE OR REPLACE PACKAGE BODY PkCartaPagoBanco
AS

--
-- Crear una nueva carta de pago
--
PROCEDURE NewCartaPago
AS
BEGIN

  INSERT INTO CartaPagoBanco (F_CREACION) VALUES (SYSDATE)
	RETURNING ID INTO VarCartaPagoBanco;

END;

--
-- Crear una nueva carta de pago añadiendo una relación
--
PROCEDURE NewCartaPago(xIDRelacion IN INTEGER)
AS
BEGIN


  INSERT INTO CartaPagoBanco (F_CREACION,IDCartasPagoRelaciones) 
	VALUES (SYSDATE, xIDRelacion)
	RETURNING ID INTO VarCartaPagoBanco;

END;


--
-- Añadir un elemento 
--
-- Modificado: 27/08/2004 Lucas Fernández Pérez. Graba el recargo y costas del valor en reciboscartapagobanco.
--
PROCEDURE CartaPagoAddRecibo(
	xIDCartaPago  RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xVALOR   	  RecibosCartaPagoBanco.VALOR%Type,
	xRECARGOVALOR RecibosCartaPagoBanco.RECARGOVALOR%Type,
	xCOSTASVALOR  RecibosCartaPagoBanco.COSTASVALOR%Type)

AS

xPRINCIPAL FLOAT  default 0;
xRECARGO FLOAT default 0;
xCOSTAS FLOAT default 0;
xDEMORA FLOAT default 0;
xTOTAL_DEUDA FLOAT default 0;

BEGIN

	PkIngresos.GET_PENDIENTE(xValor,xPRINCIPAL,xRECARGO, xCOSTAS, xDEMORA, xTOTAL_DEUDA);

	INSERT INTO RecibosCartaPagoBanco 
		(CartaPagoBanco, VALOR, PRINCIPAL, RECARGO, COSTAS, DEMORA, RECARGOVALOR, COSTASVALOR) 
	VALUES (xIDCartaPago, xVALOR, xPRINCIPAL, xRECARGO,  xCOSTAS, xDEMORA, xRECARGOVALOR, xCOSTASVALOR);

END;


--
-- Añadir un elemento. Sobrecargado para señalar la relación de notificación 
-- que ha generado la carta de pago 
--
-- Cuando se inserte una carta de pago por relacion de notificaciones siempre saldra con el 20% de recargo
--
--
-- Modificado 23/07/2004: Agustín León Robles. Se elimina el 20% fijo y ahora se recoge de la función Get_Pendiente
--
-- Modificado: 27/08/2004 Lucas Fernández Pérez. Graba el recargo y costas del valor en reciboscartapagobanco.
--
PROCEDURE CartaPagoAddRecibo(
	xIDCartaPago  RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xVALOR   	  RecibosCartaPagoBanco.VALOR%Type,
	xRECARGOVALOR RecibosCartaPagoBanco.RECARGOVALOR%Type,
	xCOSTASVALOR  RecibosCartaPagoBanco.COSTASVALOR%Type,
	xN_RELACION   RecibosCartaPagoBanco.N_RELACION%Type)
AS

xPRINCIPAL FLOAT  default 0;
xRECARGO FLOAT default 0;
xCOSTAS FLOAT default 0;
xDEMORA FLOAT default 0;
xTOTAL_DEUDA FLOAT default 0;

BEGIN

	PkIngresos.GET_PENDIENTE(xValor, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA, xTOTAL_DEUDA);

	INSERT INTO RecibosCartaPagoBanco 
		(CartaPagoBanco, VALOR, N_RELACION, PRINCIPAL, RECARGO, COSTAS, DEMORA, RECARGOVALOR, COSTASVALOR) 

	VALUES (xIDCartaPago, xVALOR, xN_RELACION, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA, xRECARGOVALOR, xCOSTASVALOR);

END;

--
-- Eliminar un elemento del grupo
--
PROCEDURE CartaPagoDelRecibo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xVALOR   	 RecibosCartaPagoBanco.VALOR%Type)
AS
BEGIN

  DELETE FROM RecibosCartaPagoBanco 
	WHERE CartaPagoBanco=xIDCartaPago AND VALOR=xVALOR;

END;

--
-- Borrar todos los elementos 
--
PROCEDURE CartaPagoDelAllRecibos(xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type)
AS
BEGIN

  DELETE FROM RecibosCartaPagoBanco 
	WHERE CartaPagoBanco=xIDCartaPago;

END;


--
-- Añadir todos los recibos vivos de un expediente
--
PROCEDURE AddAllReciboExpediente( xIDExpe IN INT)
AS
CURSOR cVivoExpe IS 
	SELECT ID, RECARGO, COSTAS FROM VALORES 
		WHERE Expediente=xIDExpe
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL;
BEGIN


   FOR v_cVivoExpe IN cVivoExpe LOOP
       CartaPagoAddRecibo(VarCartaPagoBanco, v_cVivoExpe.ID, v_cVivoExpe.RECARGO, v_cVivoExpe.COSTAS);
   END LOOP;

END;

--
-- Todas las deudas vivas de un DEUDOR en EJECUTIVA
--
PROCEDURE AddAllReciboDeudor(xNIF IN CHAR,
	xN_RELACION  RecibosCartaPagoBanco.N_RELACION%Type)
AS
CURSOR cVivoExpe IS 
	SELECT ID, RECARGO, COSTAS FROM VALORES 
		WHERE NIF=xNIF
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND VOL_EJE='E';

BEGIN

   FOR v_cVivoExpe IN cVivoExpe LOOP
       CartaPagoAddRecibo(VarCartaPagoBanco, v_cVivoExpe.ID, v_cVivoExpe.RECARGO, v_cVivoExpe.COSTAS, xN_RELACION);
   END LOOP;

END;

--
-- Añadir los recibos que usuario haya seleccionado
--
PROCEDURE AddReciboSeleccionados( xCodOperacion IN INT)
AS
CURSOR cSeleccionados IS
	SELECT ID, RECARGO, COSTAS FROM VALORES
	  WHERE CODIGO_OPERACION=xCodOperacion
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL;
BEGIN

   FOR v_cSeleccionados IN cSeleccionados LOOP
       CartaPagoAddRecibo(VarCartaPagoBanco, v_cSeleccionados.ID, v_cSeleccionados.RECARGO, v_cSeleccionados.COSTAS);
   END LOOP;

END;

--
-- Añadir los recibos de un contribuyente
-- Sobrecargado para indicar además en la carta de pago que se crea por una notificación,
-- y se indica la relación de notificación en la que se encuadra.
--
PROCEDURE AddReciboSeleccionados( xCodOperacion IN INT, xN_RELACION IN CHAR)
AS
CURSOR cSeleccionados IS
	SELECT ID, RECARGO, COSTAS FROM VALORES 
		WHERE codigo_operacion=xCodOperacion
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL;
BEGIN

   FOR v_cSeleccionados IN cSeleccionados LOOP
       CartaPagoAddRecibo(VarCartaPagoBanco, v_cSeleccionados.ID, v_cSeleccionados.RECARGO, v_cSeleccionados.COSTAS, xN_RELACION);
   END LOOP;

END;
--
-- Añadir un plazo 
--
PROCEDURE CartaPagoAddPlazo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xPlazo   	 RecibosCartaPagoBanco.PLAZO%Type)
AS
BEGIN

	INSERT INTO RecibosCartaPagoBanco (CartaPagoBanco, Plazo) VALUES (xIDCartaPago, xPlazo);

END;

--
-- Añadir un plazo de un fraccionamiento en voluntaria
--
PROCEDURE CartaPagoAddPlazoVol(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xPlazo   	 RecibosCartaPagoBanco.PLAZO%Type)
AS
BEGIN

	INSERT INTO RecibosCartaPagoBanco (CartaPagoBanco, Plazo_Vol) VALUES (xIDCartaPago, xPlazo);

END;

--
-- Eliminar un plazo 
--
PROCEDURE CartaPagoDelPlazo(
	xIDCartaPago RecibosCartaPagoBanco.CartaPagoBanco%Type,
	xPlazo   	 RecibosCartaPagoBanco.PLAZO%Type)
AS
BEGIN

  DELETE FROM RecibosCartaPagoBanco 
	WHERE CartaPagoBanco=xIDCartaPago AND PLAZO=xPlazo;

END;



END PkCartaPagoBanco;
/


-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ 
-- 
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


-- Crear una nueva carta de pago en bancos
/*VACIO*/
CREATE OR REPLACE PROCEDURE NewCartaPago(xIDExpe   IN  INT)
AS
BEGIN

  -- Crear una nueva carta de pago
  PkCartaPagoBanco.NewCartaPago();

  PkCartaPagoBanco.AddAllReciboExpediente(xIDExpe);

END;
/



/***************************************************************************************/
--Autor: 17/02/2004 Mª del Carmen Junco Gómez.
--Crea una nueva carta de pago para un expediente
--Inicialmente se utilizará para la suspensión en el 
--pendiente de los trámites (asusta viejas)

CREATE OR REPLACE PROCEDURE NEWCARTAPAGOEXPEDIENTE 
	(xIDEXPE	IN	INTEGER)
AS
	xTramite		char(1);
	xContador		integer;
BEGIN

	REFRESHEXPE(xIDEXPE); -- REFRESCO LOS INTERESES DEL EXPEDIENTE
	
	SELECT COUNT(*) INTO xCONTADOR 
	FROM VALORES 
	WHERE Expediente=xIDExpe
		  AND F_INGRESO IS NULL 
		  AND FECHA_DE_BAJA IS NULL
		  AND F_SUSPENSION IS NULL;
		  
	IF (xCONTADOR>0) THEN
	
		NewCartaPago(xIDExpe);
	
		select embargo into xTramite from expedientes where id=xIDExpe;
		PkSeguimiento.AnotaCartaPago
			(xIDExpe,
			'Suspensión temporal, Emisión de carta de pago número: '||
			PkCartaPagoBanco.VarCartaPagoBanco,
			xTramite,
			PkCartaPagoBanco.VarCartaPagoBanco);	
			
	END IF;
	
END;
/


/***************************************************************************************/
--Autor: 17/02/2004 Mª del Carmen Junco Gómez.
--procedimiento que rellena las tablas temporales para imprimir la carta de pago que se pasa como 
-- parámetro

-- Modificado: 27/08/2004 - 02/09/2004. Lucas Fernández Pérez. Este procedimiento sólo se llama desde
--	la impresión de suspensiones temporales de expedientes, por lo que antes comprobaba si
--  xIDExpe venía vacío o no, cuando siempre viene con datos, y además la fecha de vencimiento
--	la tomaba de la tabla CONFIGURACION, cuando ahora la toma del campo F_EMBARGO del expediente, 
--  que tiene guardada la fecha de vencimiento de la suspensión temporal. Esto es así porque
--  todos los expedientes que llegan a este procedimiento están SUSPENDIDOS TEMPORALMENTE.
-- Este procedimiento sólo es llamado desde el procedimiento SuspenImprimeCartasPago.
--
-- El proceso de suspension temporal es el siguiente:
--   1º se crean las cartas de pago cuando se suspende el expediente.
--   2º se llama a este procedimiento para rellenar las tablas temporales e imprimir las cartas de pago.

-- Entre el paso 1 y el paso 2 puede pasar tiempo. Y los importes pueden cambiar. Cuando se ingrese la carta de pago,
--	se reajusta el recargo,costas y demora a la que había en el momento de crear la carta de pago (paso 1). 
-- Pero ese momento no es el momento de la impresión (paso 2), por lo que tenemos que asegurarnos de que el recargo,
--  las costas y la demora no varían entre los pasos 1 y 2. La demora se reajusta a la fecha del paso 1, mientras 
--  que se hace necesario comprobar que el recargo y las costas no han variado. También hay que comprobar que ningún
--	recibo de la carta de pago se haya ingresado, anulado o suspendido.

-- Por esto se comprueba que el recargo/costas no hayan aumentado o disminuido, que el importe pendiente
--  de recargo/costas no haya variado entre el paso 1 y el paso 2, y que ningún recibo se haya ingresado o anulado
--	o suspendido. Si hay algun cambio, no se imprime la carta de pago y se guarda en la tabla TMP_INFORME_EXPE el error.

-- Ejemplo:
-- Paso 1: Se genera la carta de pago de un valor con los datos: 
--    Principal: 100  Recargo: 20  Costas: 15  Demora: 5  RecargoValor:20  CostasValor:15 -> Pendiente: 140
-- Tras esto se incrementan las costas 5 euros, quedando el valor con costas=20. 
-- Paso 2: Se imprime la carta de pago. El impreso muestra los datos pendientes del valor, por lo que en la carta
-- 			de pago se muestra un pendiente de 145 euros.
-- Paso 3: Ingreso de la carta de pago. Al ingresar la carta de pago actualiza el valor con el recargo, costas y demora
--			que tenía el valor en el paso 1, es decir, las costas del valor las pone a 15. 
--         Ya se han perdido esos 5 euros. Por eso no se permite imprimir si las costas del valor han cambiado.
-- Otro Ejemplo:
-- Paso 1: Se genera la carta de pago con los mismos importes.
-- Tras esto, mediante una entrega a cuenta, se ingresan 10 euros de costas (50 de principal y 10 de recargo).
-- Paso 2: Se imprime la carta de pago. El impreso muestra los datos pendientes del valor, por lo que en la carta
-- 			de pago se muestra un pendiente de 70 euros. 
-- Si consultásemos la carta de pago en la tabla, nos diría que hay 15 euros de costas pendientes,(100 de principal y 
--  20 de recargo) cuando realmente en el impreso han ido 5 euros de costas, 50 de principal y 10 de recargo.
-- El ingreso se hace correctamente, pero los datos son inconsistentes. Por eso no se permite imprimir si las 
--	costas pendientes del valor han cambiado.
--
-- Modificacion: 08/09/2004. Agustín León Robles. En funcion de la configuracion del tipo de empresa
-- que lleva la gestión de la recaudacion se mirará los datos de la emisora o bien a traves de la zona del usuario
-- o si es una empresa privada la que lleva la gestión se mirará en base a la zona del municipio del expediente

CREATE OR REPLACE PROCEDURE ImprimeCartaPago
		(xIDCARTAPAGO	IN 	INT,
		 xIDEXPE		IN	INT)
AS
	xEmisora		char(6);
	xSufijo			char(3);
	xRemesa			char(2);
	xImpor			float;
	xDC				char(2);
	xDIG_C60_M2		char(2);
	xFVencimiento	date;
	xCodBarraModa1  char(38);
	xCodBarraModa2	char(42);
	xInteres 		FLOAT default 0;
	xRecargo		float default 0;
	xCostas			float default 0;	
	xRecargoIngre	float default 0;
	xCostasIngre	float default 0;	
	xNIF			char(10);
	xFecha			date default null;
	xDiaSemana 		varchar2(15);
	xFDili			date;
	xExpediente		char(10);
	xDeudor			char(10);
	xNombre			varchar(40);
	xCuantos		integer;
	xContinuar      boolean;
	xCodigoSalida	char(1);
	xFIngreso		date;
	xFBaja			date;
	xFSuspension 	date;
	varPublicoPrivado 	VARCHAR(1);
	xAyto			char(3);


		
CURSOR cRECIBOS IS		
	SELECT * FROM RECIBOSCARTAPAGOBANCO WHERE CARTAPAGOBANCO=xIdCartaPago
	FOR UPDATE OF DEMORA,COSTAS;		
BEGIN	
			
	--para el calculo de intereses a la fecha de emision de la cartas de pago
	SELECT F_CREACION INTO xFECHA FROM CARTAPAGOBANCO WHERE ID=xIDCARTAPAGO;

	-- El expediente está suspendido temporalmente, y en f_embargo está la fecha límite de suspensión.		
	SELECT E.AYTO,E.EXPEDIENTE, E.F_EMBARGO, E.DEUDOR, C.NOMBRE 
		INTO xAyto, xEXPEDIENTE, xFVencimiento, xDeudor, xNombre FROM EXPEDIENTES E, CONTRIBUYENTES C 
	WHERE E.DEUDOR=C.NIF AND E.ID=xIDEXPE;
			
	FOR vRECIBOS IN cRECIBOS
	LOOP

		-- Calculamos los intereses de demora a la fecha de emision de la carta de pago, grabandolos en VALORES. 
		-- Devuelve también el recargo y costas que tiene el valor, y si está ingresado, anulado o suspendido
		InteresProvidencia(vRECIBOS.Valor,xFecha,xInteres,xRecargo,xCostas,xFIngreso,xFBaja,xFSuspension);
		
		xContinuar:=True;

		IF xFIngreso IS NOT NULL THEN -- Comprobacion "1": El valor está ingresado
			xCodigoSalida:='1'; 
			xContinuar:=False;
		
		ELSIF xFBaja IS NOT NULL THEN -- Comprobacion "2": El valor está anulado
			xCodigoSalida:='2'; 
			xContinuar:=False;
		
		ELSIF xFSuspension IS NOT NULL THEN -- Comprobacion "3": El valor está suspendido
			xCodigoSalida:='3'; 
			xContinuar:=False;
			
		ELSE -- El recibo no está ingresado ni anulado ni suspendido. Se comprueba que los importes no hayan cambiado.
		
			-- xRecargo/xCostas tiene el recargo/costas del valor. xRecargoIngre/xCostasIngre las ingresadas. 
			-- De ahí saco el importe pendiente de recargo/costas. Si no coincide con los campos recargo/costas 
			-- de reciboscartapagobanco, anota la incidencia y termina el procedimiento.
			-- Del mismo modo, si el campo xRecargo/xCostas del valor no coincide con los campos recargovalor/costasvalor
			-- de reciboscartapagobanco, anota la incidencia y termina el procedimiento.
			SELECT SUM(RECARGO),SUM(COSTAS),COUNT(*) into xRecargoIngre, xCostasIngre, xCuantos 
			FROM INGRESOS WHERE VALOR=vRECIBOS.Valor;
		
			IF xCuantos=0 THEN
				xRecargoIngre:=0;
				xCostasIngre:=0;
			END IF;

			-- Comprobacion "4": El recargo del valor debe ser el mismo ahora que cuando se creo la carta de pago
			IF xRecargo<>vRECIBOS.RECARGOVALOR THEN 
				xCodigoSalida:='4'; 
				xContinuar:=False;
			-- Comprobacion "5": El recargo pendiente del valor debe ser el mismo ahora que cuando se creo la c.pago
			ELSIF (xRecargo-xRecargoIngre)<>vRECIBOS.RECARGO THEN 
				xCodigoSalida:='5'; 
				xContinuar:=False;
			-- Comprobacion "6": Las costas del valor deben ser las mismas ahora que cuando se creo la carta de pago
			ELSIF xCostas<>vRECIBOS.COSTASVALOR THEN 
				xCodigoSalida:='6'; 
				xContinuar:=False;
			-- Comprobacion "7": Las costas pendientes deben ser las mismas ahora que cuando se creo la carta de pago
			ELSIF (xCostas-xCostasIngre)<>vRECIBOS.COSTAS THEN 
				xCodigoSalida:='7'; 
				xContinuar:=False;
			END IF;
			
		END IF;

		IF xContinuar=False THEN 
		
			insert into TMP_INFORME_EXPE(USUARIO,ID,RECIBOS,EXPEDIENTE,DEUDOR,NOMBRE,F_APERTURA,EMBARGO,PENDIENTE) 
			VALUES (UID,vRECIBOS.Valor,xIDExpe,xExpediente,xDeudor,xNombre,sysdate,xCodigoSalida,xIDCartaPago);
		
			-- Si una carta de pago tiene varios recibos, al fallar uno hay que borrar el resto de las tablas temporales.	
			DELETE FROM TMPENTREGASVALOR WHERE USUARIO=UID AND XID IN 
				(SELECT XID FROM TMPDEUDASVIVAS WHERE USUARIO=UID AND IDCARTAPAGOBANCO=xIdCartaPago
				);
			
			DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID AND IDCARTAPAGOBANCO=xIdCartaPago;
				
			RETURN;
			
		END IF;
		
		--insertamos en TMPDEUDASVIVAS y en TmpEntregasValor
		NotifiRellenaCartasPago(xIdCartaPago,vRECIBOS.Valor, xNIF);						
			
		UPDATE TMPDEUDASVIVAS SET IDEXPE=xIDEXPE,EXPEDIENTE=xEXPEDIENTE
		WHERE USUARIO=UID AND xID=vRECIBOS.Valor;

		--se graba el importe de la demora en este momento, porque cuando se generan las cartas de pago 
		-- se graba el principal/recargo/costas pendientes, pero no se calcula la demora pendiente.
		update RECIBOSCARTAPAGOBANCO set demora=round(xInteres,2) 
		where current of cRECIBOS;
			
	END LOOP;		

	--insertamos los datos postales de la carta de pago
	PkwtDocIngreso.wtDatosPostalesDeudor(xNIF, 0, 'N');


	--se accede a la tabla de configuracion para recoger los datos de la emisora y sufijo
	--Tambien se recoge el tipo de empresa que tiene la gestion de la recaudacion:
	--Ayuntamientos pequeños (A).
	--Ayuntamientos grandes (G): pueden tener mas de un alcalde por distrito, tesorero, etc.
	--Entidades SupraMunicipales (S): Mancomunidades y Diputaciones.
	--Comunidades Autonomas o Administración Central (C).
	--Modo de funcionamiento ASP X
	select EMISORA,SUFIJO,REMESA_MOD1,TIPO_ENTIDAD  into xEmisora,xSufijo,xRemesa,varPublicoPrivado
	from configuracion WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);
	
	
	--Si es una empresa privada se los datos se toman en funcion del municipio del expediente	
	if varPublicoPrivado='X' then
					
		select EMISORA,SUFIJO into xEmisora,xSufijo
		from configuracion WHERE ZONA=(SELECT ZONA FROM MUNICIPIOS WHERE AYTO=xAyto);
			
	end if;

	--averiguamos el importe de la carta de pago porque interviene en el
	--calculo del digito de control		

	select sum(PRINCIPAL+RECARGO+COSTAS+DEMORA-ENTREGAS_A_CUENTA+DEMORA_PENDIENTE)
	into xImpor from TmpDeudasVivas
	where IDCARTAPAGOBANCO=xIdCartaPago and Usuario=UID;

	-- la fecha de vencimiento del pago en el banco sera la indicada como límite de la suspension temporal,
	-- en el caso de que el resultado de la suma fuera sabado o domingo se pasaría a lunes
	select to_char(xFVencimiento,'Day') into xDiaSemana from Dual;

	--SABADO
	if Upper(RTRIM(xDiaSemana)) in ('SÁBADO','SABADO','SATURDAY') then
		xFVencimiento:=xFVencimiento+2;
	--DOMINGO
	elsif Upper(RTRIM(xDiaSemana)) IN ('DOMINGO','SUNDAY') then
		xFVencimiento:=xFVencimiento+1;
	end if;

		
	--calcular los dígitos de control del cuaderno 60 modalidad 1
	--esto se incluye para Ateco, para que no tengan que generarlos ellos al
	--crear la base de datos access. 
		
	CALCULA_DC_60 (xImpor, xIdCartaPago, xSufijo,
				   to_char(sysdate,'yy'),xRemesa,xEmisora,xDC);
					   
	xCodBarraModa1:='90502'||xEmisora||LPAD(xIdCartaPago,10,'0')||xDC||
       				xSufijo||to_char(sysdate,'yy')||xRemesa||
       				LPAD(xImpor*100,8,'0');

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(xImpor, xIdCartaPago, xSufijo,
			to_char(sysdate,'yy'), '1',
			to_char(xFVencimiento,'y'), to_char(xFVencimiento,'ddd'),
			xEmisora, xDIG_C60_M2);

	xCodBarraModa2:='90521'||xEmisora||LPAD(xIdCartaPago,10,'0')||
			xDIG_C60_M2||'1'||
			xSufijo||to_char(sysdate,'yy')||
			to_char(xFVencimiento,'y')||to_char(xFVencimiento,'ddd')||
			--expresado en centimos de euros
		    LPAD(xImpor*100,8,'0')||'0';

	--se lo pasamos a los datos de cabecera
	Update TmpDeudorDPostales set
			EMISOR=xEmisora,
			REFERENCIA=LPAD(xIdCartaPago,10,'0'),
			TRIBUTO=xSufijo,
			EJERCICIO=to_char(sysdate,'yy'),
			REMESA=xRemesa,
			IMPO=LPAD(xImpor,12,'0'),
			IMPORTE=xImpor,
			DISCRI_PERIODO='1',
			DIGITO_YEAR=to_char(xFVencimiento,'y'),
			F_JULIANA=to_char(xFVencimiento,'ddd'),
			FECHA_VENCIMIENTO=xFVencimiento,
			DC=xDC,
			COD_BARRAS_MOD1=xCodBarraModa1,
			DIGITO_C60_MODALIDAD2=xDIG_C60_M2,
			COD_BARRAS_MOD2=xCodBarraModa2,
			IDCARTAPAGOBANCO=xIdCartaPago,
			IDEXPE=xIDEXPE,
			EXPEDIENTE=xEXPEDIENTE
	where usuario=UID and referencia is null;	

END;
/