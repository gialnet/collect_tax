-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez
-- No se han realizado cambios.
-- -----------------------------------------------------

--
-- Si era un ingreso por ventanilla banco y se pagó en banco en periodo voluntario
-- pero nosotros lo grabamos en periodo ejecutvo, por causa de que se habia traspapelado
-- o similares. En caso de reponerse el ingreso el recibo tiene que volver a estar en
-- ejecutiva. pues en caso contrario dejaríamos el recibo repuesto en voluntaria.
--
-- Este procedimiento será llamado desde el trigger DEL_INGRESOS
--
CREATE OR REPLACE PROCEDURE COMMEBACK_EJECUTIVA(xValor IN INTEGER)
AS

xFApremio Date;


-- Nosotros al grabar el ingreso lo pasamos a voluntaria
Cursor cValores IS Select Ayto,Padron,Year,Periodo,F_APREMIO From Valores
	where id = xValor
   	and Vol_eje = 'V'
   	and TRUNC(FIN_PE_VOL,'DD') <= TRUNC(sysdate,'DD')
   	for update of Recargo,Vol_Eje,F_APREMIO;

BEGIN


For vCValores IN cValores Loop

	select max(F_APREMIO) Into xFApremio From Valores
		Where Ayto=vCValores.Ayto
		and Padron=vCValores.Padron
		and Year=vCValores.Year
		and Periodo=vCValores.Periodo;

	if xFApremio is not null then
   	   Update Valores Set Recargo=Round((Principal*10/100), 2), Vol_Eje='E',
   			F_APREMIO=xFApremio
   			where current of cValores;
   	end if;

end loop;

END;
/


--
-- Reponer un expediente que estaba en la traba de salarios
-- se podrían dar cuatro situaciones validas y una imposible
-- docuemnto tecnico 1500-Salarios.doc
--
-- Modificado: 21/03/2003. Lucas Fernández Pérez. El expediente puede estar en estado 'O'
-- al reponer el cobro total, si desde la ventana de levantamiento se pulsa el botón de 
-- 'volver al embargo'. En ese caso, no debería crearse ninguna tupla nueva ni cambiar nada.
--
CREATE OR REPLACE PROCEDURE ReponerSalario(xIDExpe IN INTEGER,xTipoIngreso IN CHAR)
AS

xESTA CHAR(1);
xNIF  CHAR(10);
xZONA CHAR(2);
xEXPE CHAR(10);
xID	INTEGER;
xPENDIENTE FLOAT DEFAULT 0;
xSUMA FLOAT DEFAULT 0;
xFDili DATE;

-- Valores pendientes en este momento
cursor ValoresPendientes IS
	SELECT ID FROM VALORES
		WHERE EXPEDIENTE=xIDExpe
 	         and F_ingreso is null
		   and fecha_de_baja is null
		   and F_suspension is null;
BEGIN

   SELECT ESTA_EMBARGO,DEUDOR,ZONA,EXPEDIENTE INTO xESTA,xNIF,xZONA,xEXPE
	FROM EXPEDIENTES
	WHERE ID=xIDExpe;

   -- Si estaba pendiente o con suspensión temporal por documento de ingreso en banco
   -- no hay que hacer nada. Si se metió desde la ventana de levantamiento tampoco.
   IF xESTA IN ('P','S','O') THEN
   	RETURN;
   END IF;

-- Si se había emitido la diligencia a la empresa del deudor
-- no se borro nada para poder emitir el levantamiento.
   IF xESTA='L' THEN

	UPDATE EXPEDIENTES SET Esta_Embargo='O'
		WHERE ID=xIDExpe;

     	update EMBARGOS_SALARIOS set LEVANTADO='N'
		where IDEXPE=xIDExpe;

    	return;

   END IF;

   -- Un ingreso en ventanilla no genera tupla en embargos_salarios
   if xTipoIngreso NOT IN('VE','CM','EE') then
	-- Sin haber emitido la diligencia a la empresa
	FOR vPendi IN ValoresPendientes LOOP

    		GetPendienteNow(vPendi.ID, sysdate,xPENDIENTE);
		xSUMA := xSUMA + xPENDIENTE;
	END LOOP;

	INSERT INTO EMBARGOS_Salarios
       (IDEXPE,DEUDA_TOTAL,NIF,ZONA,EXPEDIENTE)
      values
        (xIDExpe, xSUMA, xNIF, xZONA, xEXPE)
	RETURNING ID INTO xID;

	UPDATE SALARIOS SET IDSALARIO=xID
      	WHERE NIF=xNIF AND IDEXPE=xIDEXPE;
   end if;

END;
/


--
-- Comprobrar si se puede reponer un ingreso o no, porque se rompe el orden en que se
-- realizaron los ingresos, es decir siempre se podrán reponer en sentido de que el
-- último que se realizó es el primero en reponerse y así sucesivamente.
--
CREATE OR REPLACE FUNCTION ReponerSioNo(xCodigoOperacion IN INT)
RETURN BOOLEAN
AS

xIDExpe INT;
xFIngre DATE;
xCuantos INT;

CURSOR cIngresados IS
	SELECT VALOR,PARCIAL_O_COBRO,FECHA FROM INGRESOS
		WHERE CODIGO_OPERACION=xCodigoOperacion;
BEGIN

FOR v_cIngresados IN cIngresados LOOP

   SELECT EXPEDIENTE,F_INGRESO INTO xIDExpe,xFIngre
	FROM VALORES WHERE ID=v_cIngresados.VALOR;

   IF xIDExpe IS NULL THEN
	-- Si era una entrega a cuenta
      IF v_cIngresados.PARCIAL_O_COBRO='P' THEN
		-- y ya está pagado
		IF xFIngre IS NOT NULL THEN
  		   RETURN false;
		END IF;
	END IF;
   ELSE
	-- está dentro de un expediente

	-- comprobar que no se hayan producido ingresos al expediente
	-- posteriores al que se quiere reponer
	-- Dos ingresos con igual Codigooperacion pueden tener fechas distintas (1 segundo p.ej.).
	-- Por eso se pone la última condición, para permitir reponer en ese caso.
	Select count(*) INTO xCuantos From Ingresos I, Valores V
		where I.Valor=V.ID
		and V.EXPEDIENTE=xIDExpe
		and I.FECHA > v_cIngresados.FECHA
		and I.Codigo_Operacion<>xCodigoOperacion;

	IF xCuantos > 0 THEN -- Si es mayor de cero hay ingresos posteriores
	   RETURN False;
	END IF;

   END IF;

END LOOP;

RETURN True;

END;
/

-- -------------------------------------------------------------------------------------
-- Mira si el ingreso sobre un fraccionamiento en VOLUNTARIA es el último realizado.
/*INTERNO*/
CREATE OR REPLACE FUNCTION  ReponerSioNoFracVol(
				xCodOpe INTEGER)
RETURN BOOLEAN
AS
xIDFRAC INTEGER;
xIDPlazo INTEGER;
xCodOpeUltimo INTEGER;
xVolEje VARCHAR(1);

CURSOR CINGRE IS SELECT MANEJADOR
	FROM INGRESOS WHERE CODIGO_OPERACION=xCodOpe;

BEGIN

   -- Busco el fraccionamiento donde esta el ingreso.
   SELECT FRAC INTO xIDFRAC FROM INGRESOS_FRAC_VOL WHERE COD_INGRESO=xCodOpe;

   -- Miro cual es el último ingreso del fraccionamiento.
   SELECT MAX(COD_INGRESO) INTO xCodOpeUltimo FROM INGRESOS_FRAC_VOL WHERE FRAC=xIDFRAC;

   IF xCodOpe<>xCodOpeUltimo THEN -- El ingreso es el último,se puede reponer
	RETURN False;
   END IF;

   -- No puedo reponer una entrega sobre un plazo que ahora está en ejecutiva, porque
   -- esa cantidad repuesta no se trataria en ningun sitio.Si la reposicion tiene algun
   -- ingreso sobre un plazo que ahora esta en ejecutiva, no permite que se realice.
   FOR vINGRE IN CINGRE LOOP
      SELECT VOL_EJE INTO xVolEje FROM PLAZOS_FRAC_VOL WHERE ID=vINGRE.MANEJADOR;
   	IF(xVolEje='E') THEN
   	   RETURN False;
   	END IF;
   END LOOP;

   RETURN True;

END;
/
-- -------------------------------------------------------------------------------------
-- Mira si el ingreso sobre un fraccionamiento en EJECUTIVA es el último realizado.
/*INTERNO*/
CREATE OR REPLACE FUNCTION  ReponerSioNoFrac(
				xCodOpe INTEGER)
RETURN BOOLEAN
AS
xIDFRAC INTEGER;
xCodOpeUltimo INTEGER;
BEGIN

   -- Busco el fraccionamiento donde esta el ingreso.
   SELECT FRAC INTO xIDFRAC FROM INGRESOS_FRAC WHERE COD_INGRESO=xCodOpe;

   -- Miro cual es el último ingreso del fraccionamiento.
   SELECT MAX(COD_INGRESO) INTO xCodOpeUltimo FROM INGRESOS_FRAC WHERE FRAC=xIDFRAC;

   IF xCodOpe=xCodOpeUltimo THEN -- El ingreso es el último,se puede reponer
	RETURN True;
   END IF;

   RETURN False;

END;
/
-- ----------------------------------------------------------------------
-- Reposición de un ingreso sobre un plazo de un fraccionamiento en VOLUNTARIA
--
-- Antes era un Trigger para actualizar una reposición de ingreso de un valor
--  con fraccionamiento en voluntaria. Pero necesitaba acceder a los ingresos para saber
--  si era el último de un plazo para poner el plazo a NO cobrado,por lo que se cambia a procedimiento.
--
--	Modificado: 02/09/2003. Lucas Fernández Pérez.
--	Cuando se repone los ingresos actualizar el campo estado a EB si se pago mediante domiciliacion PD	
/*INTERNO*/
CREATE OR REPLACE PROCEDURE ReponerVolFrac(xCodOpe IN INTEGER)
AS
xImporteIngresado FLOAT;
xEntregas Float;
xTipo VARCHAR(1);
xCuantos Integer;

xIDFRAC INTEGER;
xFecha  DATE;
xFCIERRE DATE;
xSuma FLOAT;
xPendiente FLOAT;


   -- Si se repone una entrega recorre todos los ingresos que generó.Uno por plazo máximo.
   -- Si se repone un pago de plazo solo habrá un ingreso con ese codigo de operación
   CURSOR C_INGRE IS SELECT * FROM INGRESOS WHERE CODIGO_OPERACION=xCodOpe;


BEGIN

   -- Voy a borrar varias entregas sobre un fraccionamiento o un pago de plazo sobre el mismo

   -- Puede haber muchos ingresos, pero cada uno a un plazo distino del mismo fraccionamiento.
   FOR v_INGRE IN C_INGRE LOOP

	-- Importe que voy a borrar del fraccionamiento.
   	xImporteIngresado:=v_INGRE.PRINCIPAL+v_INGRE.RECARGO+v_INGRE.COSTAS+v_INGRE.DEMORA;

   	-- Hay que saber si se esta reponiendo una entrega o un pago del plazo
   	SELECT TIPO INTO xTIPO FROM INGRESOS_FRAC_VOL WHERE COD_INGRESO=v_INGRE.CODIGO_OPERACION;

   	-- obtengo lo que se ha entregado del plazo.
   	SELECT ENTREGAS INTO xEntregas FROM VWPLAZOS_FRAC_VOL WHERE ID=v_INGRE.MANEJADOR;

   	-- Si es una entrega, disminuyo el valor de las entregas en plazos_frac_vol
   	IF xTIPO='E' THEN

	   -- Miro si hay otra entrega sobre el mismo plazo.Si hay otra,INGRESADO
	   -- deberá tomar valor 'P'. Si era la última, deberá tomar valor 'N'.
	   SELECT COUNT(*) INTO xCuantos FROM INGRESOS WHERE
		VALOR=v_INGRE.VALOR AND MANEJADOR=v_INGRE.MANEJADOR;

	   -- Si lo que elimino es menos de lo que hay entregado,actualizo lo entregado
 	   IF xImporteIngresado < xENTREGAS THEN
    		   UPDATE PLAZOS_FRAC_VOL SET F_INGRESO=NULL,INGRESADO='P',
					 ENTREGAS=ENTREGAS-xImporteIngresado,
					 ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
    		   WHERE ID=v_INGRE.MANEJADOR;
	   ELSE -- Era una entrega, en la cual ingresaba lo que hay entregado en el plazo
		IF xCUANTOS > 1 THEN -- Hay otra entrega sobre el plazo,quedará ingresado Parcialmente
   	   	   UPDATE PLAZOS_FRAC_VOL SET F_INGRESO=NULL,INGRESADO='P',ENTREGAS=0,
					 ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
               WHERE ID=v_INGRE.MANEJADOR;
		ELSE -- Es el único ingreso sobre el plazo,quedará sin Ingresar
   	   	   UPDATE PLAZOS_FRAC_VOL SET F_INGRESO=NULL,INGRESADO='N',ENTREGAS=0,
					 ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
               WHERE ID=v_INGRE.MANEJADOR;
		END IF;

	   END IF;

  	ELSE -- If TIPO='P'. Estoy reponiendo un pago de plazo
	   if xEntregas>0 then -- Hay entregas al plazo, esta PARCIALMENTE INGRESADO.
	   	UPDATE PLAZOS_FRAC_VOL SET F_INGRESO=NULL,INGRESADO='P',
					 ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
      	WHERE ID=v_INGRE.MANEJADOR;
	   else -- No hay entregas al plazo, no hay NADA INGRESADO.
	   	UPDATE PLAZOS_FRAC_VOL SET F_INGRESO=NULL,INGRESADO='N',
					 ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
      	WHERE ID=v_INGRE.MANEJADOR;
	   end if;
   	END IF;

   END LOOP;

   --  --------------------
   -- Hemos actualizado los plazos. Ahora actualizamos el fraccionamiento.

   /* Leemos el ID del fraccionamiento */
   SELECT F_PLAZO,IMPORTE,FRAC,TIPO INTO xFECHA,xSUMA,xIDFRAC,xTIPO
	FROM INGRESOS_FRAC_VOL
      WHERE COD_INGRESO=xCodOpe;

   -- Leemos el fraccionamiento
   SELECT F_CIERRE INTO xFCIERRE
      FROM FRACCIONAMIENTO_VOL
	WHERE ID=xIDFRAC;

   IF xTIPO='P' THEN -- estoy reponiendo los pagos de un plazo

	-- Con las cartas de pago puede no ser el ultimo plazo el que cierra el fraccionamiento.
	-- Por eso, al reponer hay que buscar la minima fecha y su importe para ponerlos en el
	-- fraccionamiento.

  	-- Busco sobre que plazo es. Si repone sobre un plazo en voluntaria habiendo pendiente
	-- algun plazo en ejecutiva anterior,pongo como next_fecha la del plazo voluntario mas proxima.
	SELECT MIN(FECHA) INTO xFECHA FROM PLAZOS_FRAC_VOL
		WHERE FRACCIONA=xIDFRAC AND INGRESADO<>'S' AND VOL_EJE='V';
	-- Y obtengo su pendiente.
	SELECT (PRINCIPAL+RECARGO+COSTAS+DEMORA-ENTREGAS) INTO xPendiente FROM PLAZOS_FRAC_VOL
		WHERE FRACCIONA=xIDFRAC AND INGRESADO<>'S' AND FECHA=xFECHA;

	--si estaba cerrado quiere decir que estoy reponiendo el ultimo plazo del fraccionamiento
	IF xFCIERRE IS NOT NULL THEN
    		UPDATE FRACCIONAMIENTO_VOL SET F_NEXT_PLAZO=xFECHA,
			IMPO_NEXT_PLAZO=xPendiente,
			PAGADO=PAGADO-xSUMA,
			F_CIERRE=NULL,ISOPEN='O',ESTADO='ABIERTO',F_ESTADO=SYSDATE
    		WHERE ID=xIDFRAC;
	ELSE -- Repongo un pago de plazo del fraccionamiento que no es el último.
    		UPDATE FRACCIONAMIENTO_VOL SET F_NEXT_PLAZO=xFECHA,
			IMPO_NEXT_PLAZO=xPendiente,
			PAGADO=PAGADO-xSUMA
    		WHERE ID=xIDFRAC;
	END IF;
   ELSE -- Estoy reponiendo una entrega a cuenta sobre un plazo del fraccionamiento

  	-- Busco sobre que plazo es. Si repone sobre un plazo en voluntaria habiendo pendiente
	-- algun plazo en ejecutiva anterior,pongo como next_fecha la del plazo voluntario mas proxima.
	SELECT MIN(FECHA) INTO xFECHA FROM PLAZOS_FRAC_VOL
		WHERE FRACCIONA=xIDFRAC AND INGRESADO<>'S' AND VOL_EJE='V';
	-- Y obtengo su pendiente.
	SELECT (PRINCIPAL+RECARGO+COSTAS+DEMORA-ENTREGAS) INTO xPendiente FROM PLAZOS_FRAC_VOL
		WHERE FRACCIONA=xIDFRAC AND INGRESADO<>'S' AND FECHA=xFECHA;

	-- Si el fraccionamiento estaba cerrado, lo vuelvo a abrir
	IF xFCIERRE IS NOT NULL THEN
    		UPDATE FRACCIONAMIENTO_VOL SET ENTREGAS=ENTREGAS-xSUMA,
			IMPO_NEXT_PLAZO=xPendiente,
			F_NEXT_PLAZO=xFECHA,
			F_CIERRE=NULL,
			ISOPEN='O',
			ESTADO='ABIERTO',
			F_ESTADO=SYSDATE
        	WHERE ID=xIDFRAC;

	ELSE
    		UPDATE FRACCIONAMIENTO_VOL SET
			ENTREGAS=ENTREGAS-xSUMA,
			F_NEXT_PLAZO=xFECHA,
			IMPO_NEXT_PLAZO=xPendiente
        	WHERE ID=xIDFRAC;
	END IF;
   END IF;

   /* BORRAR DEL INDICE DE INGRESOS DEL FRACCIONAMIENTO */
   DELETE FROM INGRESOS_FRAC_VOL WHERE COD_INGRESO=xCodOpe;

END;
/

--
-- Reponer el ingreso de un fraccionamiento en EJECUTIVA
--
--	Modificado: 24/07/2003. Agustín León Robles.
--	Cuando se repone los ingresos actualizar el campo estado a EB si se pago mediante domiciliacion PD	
--
-- Modificado: 25/08/2003. Lucas Fernández Pérez. 
--	Al reponer el ingreso, se rellena la fecha de suspension de los valores
--		del fraccionamiento que no la tuviesen.
-- Modificado: 04/11/2003. Lucas Fernández Pérez. 
--	Al reponer el ingreso, se inserta en suspensiones_valores cuando se rellena
--		la fecha de suspension de los valores que no la tuviesen.
--
CREATE OR REPLACE PROCEDURE ReponerFrac(xCodOpe IN INTEGER, xIDExpe OUT INT)
AS

xImporteIngresado FLOAT;
xEntregas Float;

xIDFRAC INTEGER;
xFecha  DATE;
xTipo VARCHAR(1);
xFAPERTURA DATE;
xFCIERRE DATE;
xSuma FLOAT;
xPendiente FLOAT;

   -- Si se repone una entrega recorre todos los ingresos que generó.
   -- Si se repone un pago de plazo solo habrá un ingreso por valor con ese codigo de operación
   CURSOR C_INGRE IS SELECT * FROM INGRESOS WHERE CODIGO_OPERACION=xCodOpe;

BEGIN

   -- Leemos el ID del fraccionamiento 
   SELECT F_PLAZO,IMPORTE,FRAC,TIPO INTO xFECHA,xSUMA,xIDFRAC,xTipo
	FROM INGRESOS_FRAC
      WHERE COD_INGRESO=xCodOpe;

    SELECT F_APERTURA,F_CIERRE,EXPEDIENTE INTO xFAPERTURA,xFCIERRE,xIDExpe
      FROM FRACCIONAMIENTO
	WHERE ID=xIDFRAC;

	
   -- Recorre los ingresos para actualizar los plazos.
   FOR v_INGRE IN C_INGRE LOOP

	-- Importe que voy a borrar del fraccionamiento.
   	xImporteIngresado:=v_INGRE.PRINCIPAL+v_INGRE.RECARGO+v_INGRE.COSTAS+v_INGRE.DEMORA;

   	-- obtengo lo que se ha entregado del plazo.
   	SELECT ENTREGAS INTO xEntregas FROM VWPLAZOS_FRAC WHERE ID=v_INGRE.MANEJADOR;

   	-- Hay que saber si se esta reponiendo una entrega o un pago del plazo
   	SELECT TIPO INTO xTIPO FROM INGRESOS_FRAC WHERE COD_INGRESO=v_INGRE.CODIGO_OPERACION;

   	IF xTIPO='E' THEN -- Se repone el pago de una entrega
		-- Si lo que elimino es menos de lo que hay entregado,actualizo lo entregado
 	   if xImporteIngresado < xENTREGAS then
		UPDATE PLAZOS_FRAC SET F_INGRESO=NULL,INGRESADO='P',
						ENTREGAS=ENTREGAS-xImporteIngresado,
						ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
    	   	WHERE ID=v_INGRE.MANEJADOR;
	   else -- Era una entrega, en la cual ingresaba lo que hay entregado en el plazo
	   	UPDATE PLAZOS_FRAC SET F_INGRESO=NULL,INGRESADO='N',
						ENTREGAS=0,
						ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
            WHERE ID=v_INGRE.MANEJADOR;
	   end if;

   	ELSE -- If TIPO='P'. Estoy reponiendo un pago de plazo
	   if xEntregas>0 then -- Hay entregas al plazo, esta PARCIALMENTE INGRESADO.
	   	UPDATE PLAZOS_FRAC SET F_INGRESO=NULL,INGRESADO='P',
						ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
      	WHERE ID=v_INGRE.MANEJADOR;
	   else -- No hay entregas al plazo, no hay NADA INGRESADO.
	   	UPDATE PLAZOS_FRAC SET F_INGRESO=NULL,INGRESADO='N',
						ESTADO=DECODE(ESTADO,'PD','EB',ESTADO)
      	WHERE ID=v_INGRE.MANEJADOR;
	   end if;

   	END IF;

    INSERT INTO SUSPENSIONES_VALORES
      (VALOR,ID_EXPE,F_ACUERDO,DESCRIPCION)
	  SELECT ID,EXPEDIENTE,xFAPERTURA,'FRACCIONAMIENTO' FROM VALORES
	  	WHERE ID=v_INGRE.VALOR AND F_SUSPENSION IS NULL;
	  	
	-- Actualizo los valores del fraccionamiento poniendolos a estado suspendido.
   	UPDATE VALORES SET F_SUSPENSION=xFAPERTURA, IS_LIVE='N' 
    WHERE ID=v_INGRE.VALOR AND F_SUSPENSION IS NULL;
	    
   END LOOP;

   --  --------------------
   -- Hemos actualizado los plazos. Ahora actualizamos el fraccionamiento.

   -- BORRAR EL APUNTE EN EL SEGUIMIENTO DEL EXPEDIENTE 
   DELETE FROM SEGUIMIENTO WHERE ID_INGRESOS=xCodOpe;

   IF xTIPO='P' THEN -- estoy reponiendo los pagos de un plazo
	--si estaba cerrado quiere decir que estoy reponiendo el ultimo plazo del fraccionamiento
	IF xFCIERRE IS NOT NULL THEN
    		UPDATE FRACCIONAMIENTO SET F_NEXT_PLAZO=xFECHA,
			IMPO_NEXT_PLAZO=xSUMA,
			PAGADO=PAGADO-xSUMA,
			F_CIERRE=NULL,ISOPEN='O',ESTADO='ABIERTO',F_ESTADO=SYSDATE
    		WHERE ID=xIDFRAC;
	ELSE
    		UPDATE FRACCIONAMIENTO SET F_NEXT_PLAZO=xFECHA,
			IMPO_NEXT_PLAZO=xSUMA,
			PAGADO=PAGADO-xSUMA
    		WHERE ID=xIDFRAC;
	END IF;
   ELSE
	SELECT MIN(FECHA) INTO xFECHA FROM PLAZOS_FRAC
		WHERE FRACCIONA=xIDFRAC AND INGRESADO<>'S';
	-- Y obtengo su pendiente.
	SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA-ENTREGAS) INTO xPendiente FROM PLAZOS_FRAC
		WHERE FRACCIONA=xIDFRAC AND INGRESADO<>'S' AND FECHA=xFECHA;

	-- El fraccionamiento estaba cerrado ahora lo vuelvo a abrir
	IF xFCIERRE IS NOT NULL THEN
    		UPDATE FRACCIONAMIENTO SET ENTREGAS=ENTREGAS-xSUMA,
			IMPO_NEXT_PLAZO=xPendiente,
			F_NEXT_PLAZO=xFECHA,
			F_CIERRE=NULL,
			ISOPEN='O',
			ESTADO='ABIERTO',
			F_ESTADO=SYSDATE
        	WHERE ID=xIDFRAC;

	ELSE
    		UPDATE FRACCIONAMIENTO SET
			ENTREGAS=ENTREGAS-xSUMA,
			F_NEXT_PLAZO=xFECHA,
			IMPO_NEXT_PLAZO=xPendiente
        	WHERE ID=xIDFRAC;
	END IF;
   END IF;

   -- BORRAR DEL INDICE DE INGRESOS DEL FRACCIONAMIENTO 
   DELETE FROM INGRESOS_FRAC WHERE COD_INGRESO=xCodOpe;

   IF xFCIERRE IS NOT NULL THEN
	-- Si estuviera pagado, puede ser que el fraccionamiento esta cerrado pero que el exp.
	--no lo estuviera, porque pueden aparecer mas recibos al exp. mientras este el fracciona.
	--entonces a la hora de reponer si habra que poner el estado "FRACCIO" ya que el trigger
	--"PAGA_EXPEDIENTE" no haria nada
	-- el TRIGGER "PAGA_EXPEDIENTE" hace el resto
	UPDATE EXPEDIENTES SET F_INGRESO=NULL,
				ESTADO='FRACCIO',
				F_SUSPENSION=SYSDATE
	WHERE ID=xIDEXPE;

   END IF;


END;
/


-- **************************************************************************************
-- Acción: Reponer la aplicación de un embargo total por causa de cualquier error, 
--         pues no era la fecha correcta de aplicación u otras causas extrañas.
-- MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Al poder tener mas de una tupla en 
-- 		next_levanta_cuentas para un mismo expediente, tendremos que registrar cual
-- 		es la que hay que borrar en caso de reposición y eliminar sólo ésta. Para ello
-- 		se utiliza la tabla BORRA_LEVANTAMIENTOS.
-- Modificado: 03/12/2003. Lucas Fernández Pérez. Si el expediente se vuelve a un embargo
--	con diligencia sin retener (indicado por puedo_diligencia='N'), se rellena el campo
--  fecha_diligencia para que no se puedan recalcular intereses en el expediente.
-- ***************************************************************************************

CREATE OR REPLACE PROCEDURE ReponerEmbargoCuentas(xIDExpe IN INT)

AS
	xOTRO CHAR(1);
 	xESTA CHAR(1);
 	xPuedoDili CHAR(1);
 	xFDili 	DATE;
BEGIN


	-- Se consulta si el expediente debe tener algo en su campo fecha_diligencia.
	begin
		select puedo_diligencia,f_diligencia into xPuedoDili,xFDili 
		from borra_embargos_cuentas where idexpe=xIDExpe;
	exception
		when no_data_found then
			xPuedoDili:='S';
	end;

   	INSERT INTO EMBARGOS_CUENTAS(IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,
		EMBARGO,F_EMBARGO,QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,
		NOTIFICADO,NEXT_PRELA,ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,
		HUBO_CUENTAS,PUEDO_DILIGENCIA)

   	SELECT IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,
		EMBARGO,F_EMBARGO,QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,
		NOTIFICADO,NEXT_PRELA,ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,
		HUBO_CUENTAS,PUEDO_DILIGENCIA

   	FROM BORRA_EMBARGOS_CUENTAS WHERE IDEXPE=xIDEXPE;


	-- Reponer las cuentas del lote

	INSERT INTO CUENTAS_LOTES (ID,
		LOTE,IDEXPE,EXPEDIENTE,ZONA,NIF,ENTIDAD,OFICINA,DC,CUENTA,
		CLAVE_SEGURIDAD,IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,
		DILIGENCIA,F_DILIGENCIA,DEUDA_A_EMBARGAR,VECES)

	SELECT ID,LOTE, IDEXPE, EXPEDIENTE, ZONA, NIF, ENTIDAD, OFICINA, DC,CUENTA,
		CLAVE_SEGURIDAD,IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,
		DILIGENCIA,F_DILIGENCIA,DEUDA_A_EMBARGAR,VECES

	FROM BORRA_CUENTAS_LOTES WHERE IDEXPE=xIDExpe;

	-- Borrar de la lista circular de borrado
	DELETE FROM BORRA_EMBARGOS_CUENTAS WHERE IDEXPE=xIDExpe;
	DELETE FROM BORRA_CUENTAS_LOTES WHERE IDEXPE=xIDExpe;

	-- Borrar del levantamiento de cuentas
	DELETE FROM NEXT_LEVANTA_CUENTAS WHERE ID IN (SELECT ID FROM 
	BORRA_LEVANTAMIENTOS WHERE IDEXPE=xIDExpe);
	DELETE FROM BORRA_LEVANTAMIENTOS WHERE IDEXPE=xIDEXPE;


	-- Comprobar si hay un embargo de cuentas simultaneo
	SELECT EN_OTROTRAMITE,ESTA_EMBARGO INTO xOTRO,xESTA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	-- en caso afirmativo reponerlo
	IF xOTRO='S' THEN
   		IF xESTA='L' THEN -- Estaba levantado, lo vuelvo a abrir
			UPDATE EMBARGOS_INMUEBLES SET QUITAR_EMBARGO='N' WHERE IDEXPE=xIDExpe;
   		END IF;
	END IF;

	UPDATE EXPEDIENTES SET ESTA_EMBARGO='O',
		FECHA_DILIGENCIA=DECODE(xPuedoDili,'N',xFDili,Null)
		WHERE ID=xIDExpe;

END;
/

--
-- Reponer los cobros totales
--
-- Modificado: 21/03/2003. Lucas Fernández Pérez. Al borrar ingresos de salarios, reajusta 
-- las retenciones de los salarios (SALARIOS_RETENCIONES).
--

CREATE OR REPLACE PROCEDURE ReponerCobrosTotales(
	xIDExpe IN INT,
	xCodOpe IN INT,
	xTRAMITE IN CHAR,
	xTipoIngreso IN CHAR)

AS
xIDEmbargo INT;
xESTA CHAR(1);

-- Recorre todos los ingresos que se van a borrar, para aminorar en la tabla de retenciones
CURSOR CINGRESALA IS 
	SELECT IDRETENCIONES,IMPORTE FROM INGRESOS_SALA WHERE COD_INGRESO=xCodOpe;

BEGIN

-- Siempre y cuando haya embargo de cuentas
IF xTRAMITE='1' THEN
   ReponerEmbargoCuentas(xIDExpe);
END IF;

-- Salarios.
IF xTRAMITE = '3' THEN

   -- Se reajustan los importes ingresados en las retenciones de salarios.
   FOR v_INGRE IN CINGRESALA LOOP
	  UPDATE SALARIOS_RETENCIONES SET INGRESADO=INGRESADO - v_INGRE.IMPORTE 
	  WHERE ID=v_INGRE.IDRETENCIONES;
   END LOOP;

   DELETE FROM INGRESOS_SALA WHERE COD_INGRESO=xCodOpe; -- Se borra el ingreso
   
   ReponerSalario(xIDExpe,xTipoIngreso); -- Se repone el salario

   SELECT max(ID) INTO xIDEmbargo FROM EMBARGOS_SALARIOS WHERE IDEXPE=xIDExpe;

   -- Busca la fecha ultima de ingreso en banco y ponerla en el embargo de salarios.
   -- Necesita saber el codigo de operacion del ingreso, para lo cual accede a ingresos_sala
   -- Esta tabla no tiene id, se sabe el código accediendo al último ingreso del embargo.

   UPDATE EMBARGOS_SALARIOS SET LAST_RETENCION =
     (SELECT Max(F_COBRO_BANCO) FROM INGRESOS WHERE CODIGO_OPERACION=
	   (SELECT COD_INGRESO FROM INGRESOS_SALA
		WHERE IDSALARIO=xIDEmbargo
			AND FECHA = (SELECT MAX(FECHA) FROM INGRESOS_SALA
					WHERE IDSALARIO=xIDEmbargo)
	   )
	)
   WHERE ID=xIDEmbargo;
/* En el caso de querer poner la fecha de ingreso (no de ingreso en banco
   UPDATE EMBARGOS_SALARIOS SET LAST_RETENCION =
	(SELECT MAX(FECHA) FROM INGRESOS_SALA
		WHERE IDSALARIO=(SELECT ID FROM EMBARGOS_SALARIOS WHERE IDEXPE=xIDExpe)
	)WHERE IDSALARIO=xIDEmbargo;
*/
END IF;


-- El resto de trámites no tiene tabla de referencia de ingresos, pues cuando
-- se practica la traba se suele cobrar todo, es decir despues de un embargo de inmuebles
-- la subasta cobramos o lo que sea pero no hay más posibles ingresos.

IF xTRAMITE='4' THEN
   SELECT ESTA_EMBARGO INTO xESTA
	FROM EXPEDIENTES WHERE ID=xIDExpe;
   IF xESTA='L' THEN -- Estaba levantado, lo vuelvo a abrir
	UPDATE EXPEDIENTES SET ESTA_EMBARGO='O' WHERE ID=xIDExpe;
	UPDATE EMBARGOS_INMUEBLES SET QUITAR_EMBARGO='N' WHERE IDEXPE=xIDExpe;
   END IF;
END IF;

IF xTRAMITE='8' THEN
   SELECT ESTA_EMBARGO INTO xESTA
	FROM EXPEDIENTES WHERE ID=xIDExpe;
   IF xESTA='L' THEN -- Estaba levantado, lo vuelvo a abrir
	UPDATE EXPEDIENTES SET ESTA_EMBARGO='O' WHERE ID=xIDExpe;
	UPDATE EMBARGOS_AUTOS SET QUITAR_EMBARGO='N' WHERE IDEXPE=xIDExpe;
   END IF;
END IF;


DELETE FROM SEGUIMIENTO WHERE ID_INGRESOS=xCodOpe;


-- TRIGGER PAGA_EXPEDIENTE
-- se encarga de poner las cosas

UPDATE EXPEDIENTES SET F_INGRESO=NULL
     	WHERE ID=xIDEXPE;


END;
/



/*******************************************************************************/

--
-- Reponer un ingreso o entrega a cuenta
-- Es el punto de entrada del interfaz de usuario
--
-- Modificado: 14/03/2003. Lucas Fernández Pérez. Escribe el motivo de la 
-- reposición en la tabla USUARIOS para que lo lean los triggers 
-- TR_HISTORIA_VALORES y DEL_INGRESOS de la tabla, y lo graben en HISTORIA_VALORES.

-- Modificado: 21/03/2003. Lucas Fernández Pérez. Al borrar ingresos de salarios, reajusta 
-- las retenciones de los salarios (SALARIOS_RETENCIONES).

-- Modificado: 24/04/2003. Lucas Fernández Pérez. En reposición de ingresos de embargos 
-- 	de cuentas no se anota un apunte en mov_cuentas, sino que se descuenta el importe del
--  movimiento. Si el movimiento de cuentas tenía en parte ingreso indebido, no se 
--  descontaba el importe del ingreso indebido del movimiento de cuentas.
-- Modificado: 28/10/2003. Lucas Fernández Pérez. Si el ingreso generó un ingreso indebido 
--   y venía del cuaderno 60, la incidencia del cuaderno 60 se desliga del ingreso indebido
--	 (que se borra), pero no se borra de incidencias_c60.
-- Modificado: 25/02/2004. Agustín León Robles. Perdía el indice cuando tenía en el cursor la 
--		declaracion "and expediente is not null". Se quita esta condición y se comprueba mediante
--		un if dentro del cursor

/*DELPHI*/
CREATE OR REPLACE PROCEDURE REPON_INGRE(
	xCodOpe	IN	INTEGER,
      xTIPO 	IN 	CHAR,
      xMENSAJE 	IN 	VARCHAR2)

AS

xError int;
xIDExpe int;
xIDCuenta int;
xTRAMITE char(1);
xFechaIngreso DATE;
xIDEmbargo int;
xEstado Char(1);
xIndebido Float;
xParte Integer;

-- Cursor con los expedientes que han sido tocados
-- Se accede a ingresos porque el codigo_operacion de valores solo apunta al último ingreso
-- que se hizo sobre el valor, y no guarda el apuntador a ingresos anteriores.
CURSOR cExpedientes IS
    Select Expediente
    from valores
	where id in (select valor from ingresos where codigo_operacion = xCodOpe)	
	group by expediente;

-- Recorre todos los ingresos que se van a borrar, para aminorar en la tabla de retenciones
CURSOR CINGRESALA IS 
	SELECT IDRETENCIONES,IMPORTE FROM INGRESOS_SALA WHERE COD_INGRESO=xCodOpe;

BEGIN

   -- comprobar que no haya ingresos datados
   -- si los ingresos están datados no se puede reponer

   SELECT COUNT(*) INTO xERROR FROM INGRESOS
   WHERE CODIGO_OPERACION=xCodOpe
	AND NUMERO_DE_DATA IS NOT NULL;


   IF xERROR > 0 THEN
   	  raise_application_error(-20006,'No se puede reponer un Ingreso Datado');
   END IF;


-- **************************** nuevo control **********************************

   SELECT COUNT(*) INTO xERROR FROM INGRESOS
   WHERE CODIGO_OPERACION=xCodOpe
	AND ORGANISMO_EXT='A';

   IF xERROR > 0 THEN
   	  raise_application_error(-20013,'No se puede reponer un Ingreso de fuera de plazo en O.E.');
   END IF;

-- **************************************************************


   -- Controlar que se está respetando el orden en que se hicieron los ingresos
   IF NOT ReponerSioNo(xCodOpe) THEN

	raise_application_error(-20010,'Se rompe el orden en que se realizaron los ingresos ');

   END IF;


    IF (xTIPO IN ('FV','F1','F2')) THEN -- Fraccionamientos en voluntaria
   	-- Controlar que se está respetando el orden en que se hicieron los ingresos
   	IF NOT ReponerSioNoFracVol(xCodOpe) THEN
	   raise_application_error(-20010,'Se rompe el orden en que se realizaron los ingresos ');
   	END IF;

   	ReponerVolFrac(xCodOpe);
   END IF;

   IF (xTIPO IN ('FE','EF')) THEN -- Fraccionamientos en ejecutiva
   	-- Controlar que se está respetando el orden en que se hicieron los ingresos
   	IF NOT ReponerSioNoFrac(xCodOpe) THEN
	   raise_application_error(-20010,'Se rompe el orden en que se realizaron los ingresos ');
   	END IF;
	ReponerFrac(xCodOpe, xIDExpe);
   END IF;


   --Si los ingresos son a traves de cartas de pago en banco, no se podra borrar de asistencia
   --al reponer los ingresos, ya que no se le va a volver a imprimir el documento
   if (xTIPO IN ('VE','CM','PD','FE','FV','EE','ER','EC','EF','F1','F2')) THEN
      DELETE FROM ASISTENCIA WHERE IDINGRESO=xCodOpe;
   end if;

   -- Reponer ingresos de valores que pertenecen a un expediente
   FOR vcExpedientes IN cExpedientes LOOP

		if vcExpedientes.Expediente is not null then
		
			-- Pertenecian a un expediente
			Select F_INGRESO,EMBARGO,ESTA_EMBARGO INTO xFechaIngreso,xTRAMITE,xEstado
			from expedientes where ID=vcExpedientes.Expediente;

			DELETE FROM SEGUIMIENTO
			WHERE ID_INGRESOS=xCodOpe AND ID_EXPE=vcExpedientes.Expediente
			RETURN ID_RETENIDO_CUENTA INTO xIDCuenta;

			IF xFechaIngreso IS NOT NULL THEN

				ReponerCobrosTotales(vcExpedientes.Expediente, xCodOpe, xTRAMITE,xTIPO);
			ELSE
				-- Embargos parciales de cuentas corrientes
				IF xTRAMITE = '1' THEN

					IF xIDCuenta IS NOT NULL THEN
	   		   			-- Embargos parciales
         		   		UPDATE CUENTAS_LOTES SET HECHO='N' WHERE ID=xIDCuenta;
      				END IF;

   				END IF;

   				-- Salarios.
   				IF xTRAMITE = '3' THEN

   		   			-- Se reajustan los importes ingresados en las retenciones.
   		   			FOR v_INGRE IN CINGRESALA LOOP
	  		  			UPDATE SALARIOS_RETENCIONES SET INGRESADO=INGRESADO - v_INGRE.IMPORTE 
	  		  			WHERE ID=v_INGRE.IDRETENCIONES;
		   			END LOOP;

   		   			-- Primero borro el ingreso
      	   			DELETE FROM INGRESOS_SALA WHERE COD_INGRESO=xCodOpe;

		   			-- Para luego buscar la fecha ultima de ingreso y ponerla en el
		   			-- embargo de salarios.
		   			SELECT max(ID) INTO xIDEmbargo FROM EMBARGOS_SALARIOS
					WHERE IDEXPE=vcExpedientes.Expediente;

	   	   			-- Busca la fecha ultima de ingreso en banco y ponerla en el embargo de salarios
	   	   			-- Necesita saber el codigo de operacion del ingreso, para lo cual
		   			-- accede a ingresos_sala. Esta tabla no tiene id, se sabe el código
		   			-- accediendo al último ingreso del embargo.
		   			UPDATE EMBARGOS_SALARIOS SET LEVANTADO='N', LAST_RETENCION =
		     			(SELECT Max(F_COBRO_BANCO) FROM INGRESOS WHERE CODIGO_OPERACION=
			   			(SELECT COD_INGRESO FROM INGRESOS_SALA
					WHERE IDSALARIO=xIDEmbargo
						AND FECHA = (SELECT MAX(FECHA) FROM INGRESOS_SALA
							WHERE IDSALARIO=xIDEmbargo)
			   		)
					)
		   			WHERE ID=xIDEmbargo;

  		   			IF xEstado='L' THEN -- Si el expediente estaba levantado, lo vuelvo a abrir
						UPDATE EXPEDIENTES SET ESTA_EMBARGO='O' where ID=vcExpedientes.Expediente;
		   			END IF;

				END IF;

   				-- Resto de tipos
   				/*IF (xTRAMITE IN ('4','8','X')) THEN
      	   			;
   				END IF;*/

   			END IF;

			PkSeguimiento.NotaInformativa(vcExpedientes.Expediente, xMENSAJE);
		end if; --final del if vcExpedientes.Expediente is not null then
		
   END LOOP;

   -- Este campo se recoge en el trigger DEL_INGRESOS BEFORE DELETE ON INGRESOS si el 
   -- ingreso es parcial y en TR_HISTORIA_VALORES before update on valores si es total.
   UPDATE USUARIOS SET TEXTO=xMENSAJE WHERE USUARIO=USER;

   if xTipo IN ('EP','TC') then
			
	  -- Los ingresos que se borran puede tener algún ingreso indebido asociado, por lo
	  -- que habrá que descontar ese importe también del mov_cuentas. 
	  -- El importe ingresado se descuenta en el trigger DEL_INGRESOS
   	begin
		SELECT sum(IMPORTE) INTO xIndebido FROM INGRESOS_INDEBIDOS 
		WHERE CODIGO_OPERACION=xCodOpe;
	exception
		when no_data_found then
			xIndebido:=0;
	end;
	if xIndebido>0 then
		SELECT MAX(PARTE_DEL_DIA) INTO xParte FROM INGRESOS WHERE CODIGO_OPERACION=xCodOpe;
		update mov_cuentas set importe=importe-xIndebido where ID=xParte;
	end if;

   end if;

   -- Borrar los ingresos
   DELETE FROM INGRESOS WHERE CODIGO_OPERACION=xCodOpe;
   -- Hay numerosos triggers asociados a este borrado
   -- De ellos se ha eliminado uno para la reposición de fraccionamientos en voluntaria.
   -- y se ha eliminado otro para la reposición de fraccionamientos en ejecutiva.

   -- Si el ingreso genero un ingreso_indebido, este tambien se borra al reponer el ingreso.
   DELETE FROM INCIDENCIASR WHERE ID_ING_INDE IN
		(SELECT ID FROM INGRESOS_INDEBIDOS WHERE CODIGO_OPERACION=xCodOpe);

   -- Si el ingreso generó un ingreso indebido y venía del cuaderno 60, la incidencia del
   --  cuaderno 60 se desliga del ingreso indebido (que se borra), pero no se borra.
   UPDATE INCIDENCIAS_C60 SET ID_ING_INDE=NULL WHERE ID_ING_INDE IN
		(SELECT ID FROM INGRESOS_INDEBIDOS WHERE CODIGO_OPERACION=xCodOpe);
		
   DELETE FROM INGRESOS_INDEBIDOS WHERE CODIGO_OPERACION=xCodOpe;


END;
/


-- Elimina un ingreso indebido generado por error. Borra de Ingresos_indebidos e incidenciasr,
-- y anula el movimiento de cuentas.
-- xOK -> 1  -> El ingreso se ha borrado correctamente.
--	    0  -> El ingreso indebido tiene ingresos asociados. No se borra.
--	   -1  -> El ingreso indebido no coincide en importe con el movimiento de cuentas.No se borra.
-- Modificado: 28/10/2003. Lucas Fernández Pérez. Si el ingreso generó un ingreso indebido 
--   y venía del cuaderno 60, la incidencia del cuaderno 60 se desliga del ingreso indebido
--	 (que se borra), pero no se borra de incidencias_c60.
-- DELPHI
CREATE OR REPLACE PROCEDURE BORRA_INGRESO_INDEBIDO(
		xID_ING_INDE	IN 	INTEGER,
		xOK			OUT 	INTEGER)

AS
xCuantos 	INTEGER;
xCodOpe	INTEGER;
xIDMOVCUENTAS	INTEGER;
xImporte	FLOAT;
xIDCuentas	INTEGER;
xImporteCuenta FLOAT;

BEGIN

	xOK:=1;

	SELECT CODIGO_OPERACION,IDMOVCUENTAS,IMPORTE INTO xCodOpe,xIDMOVCuentas,xImporte
	FROM INGRESOS_INDEBIDOS WHERE ID=xID_ING_INDE;

	SELECT COUNT(*) into xCuantos FROM INGRESOS WHERE CODIGO_OPERACION=xCodOpe;

	if xCuantos>0 then -- Hay ingresos asociados al ingreso indebido.No se borra el I.Indebido
	   xOK:=0;
	   RETURN;
	end if;

	if xIDMOVCuentas IS NOT NULL then -- Hay un movimiento de cuentas asociado al Ing.Indebido
		SELECT IMPORTE,CUENTA INTO xImporteCuenta,xIDCuentas
		FROM MOV_CUENTAS WHERE ID=xIDMOVCuentas;

		if xImporteCuenta<>xImporte then --Los importes no coinciden.No se borra el I.Indeb.
		   xOK:=-1;
		   RETURN;
		end if;
	end if;

	-- Borro el ingreso indebido
	DELETE FROM INCIDENCIASR WHERE ID_ING_INDE=xID_ING_INDE;
    -- Si el ingreso generó un ingreso indebido y venía del cuaderno 60, la incidencia del
    --  cuaderno 60 se desliga del ingreso indebido (que se borra), pero no se borra.
    UPDATE INCIDENCIAS_C60 SET ID_ING_INDE=NULL WHERE ID_ING_INDE=xID_ING_INDE;
	DELETE FROM INGRESOS_INDEBIDOS WHERE ID=xID_ING_INDE;

	-- Se borra el movimiento de cuentas y actualizo el saldo de la cuenta.
	if xIDMOVCuentas IS NOT NULL then
		delete from mov_cuentas where ID=xIDMOVCuentas and IMPORTE=xImporte;

		UPDATE CUENTAS_SERVICIO SET SALDO = SALDO - xImporte
	    		WHERE ID=xIDCuentas;
	end if;

END;
/
