-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
-- ***************************************************************************************
-- DELPHI, CREAR DILIGENCIA DE EMBARGOS A LOTES INDIVIDUALES 
-- Emite la diligencia de todas las cuentas de un expediente.
-- Anota cada emisión de diligencia en el seguimiento.
-- Modificado: 07-07-2003. Lucas Fernández Pérez.
-- Al generar la diligencia de cuentas, pone HECHO='N', importe_retenido=0 y 
--	fecha_retencion = null en las cuentas afectadas.
-- ***************************************************************************************
CREATE OR REPLACE PROCEDURE DILI_INDI_CUENTAS(
        xIDEXPE 	IN	INT,
        xFDILI 	IN 	DATE,
        xLOTE 	IN	CHAR,
        xZONA 	IN	CHAR)
AS
intereses 		float default 0;
xDeuda_Total 	float default 0;
xYaRETENIDO 	float default 0;
xCuenta 		char(10);
SiHay 		integer;
xTexto 		char(150);

CURSOR Cuentas_Cursor IS 
   select id,entidad,oficina,dc,cuenta 
   from cuentas_lotes where LOTE=xLOTE
				    AND ZONA=xZONA AND IDEXPE=xIDEXPE
			          AND (DILIGENCIA='N' or (diligencia='S' and hecho='S'))
   for update of diligencia,f_diligencia,deuda_a_embargar;

BEGIN

 -- Sumar todo lo retenido y no aplicado para poder emitir una diligencia a otra
 -- entidad por lo aun pendiente 

	SELECT SUM(IMPORTE_RETENIDO) INTO xYaRETENIDO
	FROM CUENTAS_LOTES WHERE LOTE=xLOTE
			 	  AND ZONA=xZONA AND IDEXPE=xIDEXPE
			        AND DILIGENCIA='S' AND HECHO='N';

	if xYaRetenido is null then
   		xYaRetenido:=0;
	end if;

	-- Calcular los intereses de demora de la deuda a la fecha de la diligencia 

	CalcDemora_Expe(xIDEXPE, xFDILI, 'S', 'E', Intereses, xDeuda_Total);

	xDeuda_Total:=xDeuda_Total-xYaRETENIDO;

	UPDATE EMBARGOS_CUENTAS SET DEUDA_TOTAL=ROUND(xDeuda_Total,2)
	WHERE LOTE=xLOTE AND ZONA=xZONA AND IDEXPE=xIDEXPE;
 
	FOR v_CUENTAS IN CUENTAS_CURSOR LOOP

	   UPDATE CUENTAS_LOTES SET DILIGENCIA='S',
	   						HECHO='N',
							importe_retenido=0,
							fecha_retencion=null,
                            F_DILIGENCIA=xFDILI,
                            DEUDA_A_EMBARGAR=ROUND(xDeuda_Total,2)
	   where ID=v_CUENTAS.ID;

	   select count(*) into SiHay from DILIGENCIAS_CUENTAS
	   where lote=xLote and entidad=v_CUENTAS.Entidad and oficina='XXXX'
      	   and FECHA_ENVIO=xFDili
	         and Zona=xZona;

	   if SiHay=0 then

      	-- Asiento del primer apunte de una diligencia

	      INSERT INTO DILIGENCIAS_CUENTAS
	         (LOTE,ENTIDAD,OFICINA,FECHA_ENVIO,CUANTOS,ZONA)
      	VALUES 
	         (xLOTE,v_CUENTAS.ENTIDAD,'XXXX',xFDili, 1 ,xZona);
	   else
	      update Diligencias_Cuentas set Cuantos=Cuantos+1
      	where lote=xLOTE and entidad=v_CUENTAS.ENTIDAD and OFICINA='XXXX'
            	and FECHA_ENVIO=xFDili
	            and ZONA=xZona;
	   end if;

	   xTexto:='Diligencia emb del Lote '||xLote||': ' || 
			v_CUENTAS.Entidad || '-'|| v_CUENTAS.Oficina ||'-'||
			v_CUENTAS.DC ||'-'|| v_CUENTAS.Cuenta || '-Fecha: ' || 
			DAYOFMONTH(xFDILI) ||'-' || MONTH(xFDILI) || '-' || F_YEAR(xFDILI);

	   insert into SEGUIMIENTO 
	     (ID_Expe,F_Actuacion,Descripcion,Importe,ID_Retenido_Cuenta)
	   values 
	     (xIdExpe, SYSDATE, xTexto, 0, v_CUENTAS.ID);

	end LOOP;

	UPDATE EXPEDIENTES SET FECHA_DILI_CUENTAS=xFDILI,
                        INTERES_DILIGENCIA=ROUND(Intereses,2)
	WHERE ID=xIDEXPE;

END;
/

/*****************************************************************************************/
-- Modifica los digitos de control de una cuenta en las tablas que tienen un campo DC.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE MOD_DIGITOS_CONTROL(
        xID 	IN	INTEGER,
        xDC 	IN	CHAR )
AS

xENTIDAD 	CHAR(4);
xOFICINA 	CHAR(4);
xOLD_DC 	CHAR(2);
xCUENTA 	CHAR(10);


BEGIN

	SELECT ENTIDAD,OFICINA,DC,CUENTA
	INTO xENTIDAD,xOFICINA,xOLD_DC,xCUENTA
	FROM CUENTAS_LOTES WHERE ID=xID;

	IF xENTIDAD IS NOT NULL THEN

	   UPDATE CUENTAS_LOTES SET DC=xDC
	   WHERE ID=xID;	

	   UPDATE BORRA_CUENTAS_LOTES SET DC=xDC
	   WHERE ENTIDAD=xENTIDAD AND OFICINA=xOFICINA
      	    AND DC=xOLD_DC AND CUENTA=xCUENTA;

	   UPDATE CUENTAS_CORRIENTES SET DC=xDC
	   WHERE ENTIDAD=xENTIDAD AND OFICINA=xOFICINA
      	    AND DC=xOLD_DC AND CUENTA=xCUENTA;

	   UPDATE CUENTAS_A_LEVANTAR SET DC=xDC
	    WHERE ENTIDAD=xENTIDAD AND OFICINA=xOFICINA
      	    AND DC=xOLD_DC AND CUENTA=xCUENTA;

	END IF;

END;
/


/*****************************************************************************************/
/* delphi, diligencia del levantamiento de una cuenta */
-- Elimina una cuenta de un expediente que esta en un lote de embargo. 
-- Esta cuenta no puede tener la diligencia emitida (DILIGENCIA='S') y sin aplicar (HECHO='N').
-- La cuenta sigue asociada al expediente en la tabla CUENTAS_CORRIENTES, pero se elimina
-- de la tabla CUENTAS_LOTES.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE Borra_cuenta(xID IN integer)
AS
xDili 			char(1);
xEntidad 			char(4);
xF_Diligencia 		DATE;
xLote 			char(10);

BEGIN

SELECT DILIGENCIA,ENTIDAD,F_DILIGENCIA,LOTE INTO xDILI,xENTIDAD,xF_DILIGENCIA,xLOTE
FROM CUENTAS_LOTES WHERE ID=xID;

IF xDILI='S' then
    update DILIGENCIAS_CUENTAS Set Cuantos=Cuantos-1
    where LOTE=xLote and ENTIDAD=xEntidad
          and FECHA_ENVIO=xF_DILIGENCIA;

    delete from DILIGENCIAS_CUENTAS
    where LOTE=xLote and ENTIDAD=xEntidad
          and FECHA_ENVIO=xF_DILIGENCIA
          and Cuantos<=0;
end IF;

Delete from cuentas_lotes where ID=xID;

end;
/

/*****************************************************************************************/
/* APLICAR LAS CUENTAS CON RESULTADOS NEGATIVOS */
-- Elimina un embargo de una cuenta si el retenido es cero.
-- Anota la operación en el seguimiento.
/*****************************************************************************************/

CREATE OR REPLACE PROCEDURE APLICAR_INDI_CUENTAS_NEGATIVAS(
        xID 		IN	INTEGER,
        xIDExpe 		IN	INT,
        xEntidad 		IN	CHAR,
        xOficina 		IN	char,
        xDC 		IN	char,
        xCuenta 		IN	char)
AS
xDescri   	varchar(150);
xIMPO 	FLOAT;
xLote 	char(10);
BEGIN

   SELECT IMPORTE_RETENIDO,LOTE INTO xImpo,xLote 
   FROM CUENTAS_LOTES WHERE ID=xID;

   IF xIMPO = 0 THEN

      xDescri:='Embargo negativo del lote ' ||xLote || ': '||
              xEntidad || '-' || xOficina || '-' || 
              xDC || '-' || xCuenta;

      INSERT INTO SEGUIMIENTO 
         (ID_EXPE, F_ACTUACION, DESCRIPCION, DEBE_O_HABER)
      VALUES
         (xIDEXPE, SYSDATE, xDescri, 'N');

      -- Borrar la cuenta de la tabla de cuentas embargadas
      delete from cuentas_lotes where ID=xID;

	UPDATE EMBARGOS_CUENTAS SET HUBO_CUENTAS='S' WHERE IDEXPE=xIDEXPE;

   END IF;


END;
/




/*****************************************************************************************/
-- Elimina el embargo de cuentas de todos los expedientes de un lote y zona 
-- que no tienen cuentas corrientes.
-- Modificacion: 21/11/2002. Lucas Fernández Perez. Permite pasar cada expediente 
-- al embargo que entra como nuevo parámetro, siempre en estado PENDIENTE,o vuelve al embargo 
-- de INMUEBLES en estado ABIERTO si estaba en ese embargo anteriormente (EN_OTROTRAMITE='S').
-- Se anota la operación en el seguimiento del expediente.
-- Modificacion: 19/01/2004. Gloria Maria Calle Hernandez. Si se trata de un deudor jurídico 
-- no pasará al embargo de salarios, pues no tiene sentido, pasará al embargo de inmuebles.
-- Modificado: 12/11/2004. Lucas Fernández Pérez. Corrección al último cambio. Cambiaba a embargo 4 
--   si era deudor juridico sin mirar si xembargo era 3 o no, por lo que si xEmbargo=1,8...
--   lo pasaba a 4 si el deudor era jurídico.
-- *****************************************************************************************

CREATE OR REPLACE PROCEDURE BORRAR_SIN_CUENTA(
	        xZONA	IN	 CHAR,
      	  xLOTE 	IN	 CHAR,
		  xEMBARGO  IN 	 CHAR)
AS
xTEXT 	VARCHAR(150);
xEmbargoNew CHAR(1);

CURSOR EMBARGO_BORRA IS
   SELECT IDEXPE,HUBO_CUENTAS,NIF FROM EMBARGOS_CUENTAS
   WHERE ZONA=xZONA AND LOTE=xLOTE
         AND IDEXPE NOT IN (SELECT IDEXPE FROM CUENTAS_LOTES);

BEGIN

  FOR v_EMB IN EMBARGO_BORRA LOOP
	
    if v_EMB.HUBO_CUENTAS='N' THEN
	    xTEXT:='No se encontraron cuentas corrientes; Lote: '||xLOTE;
	    INSERT INTO SEGUIMIENTO 
      	 (ID_EXPE, F_ACTUACION, DESCRIPCION, DEBE_O_HABER)
	    VALUES
      	 (v_EMB.IDEXPE, SYSDATE, xText, 'N');
	end if;
	
    NEXT_PRELA(v_EMB.IDEXPE,xEmbargo);
    
  END LOOP;

END;
/
/*****************************************************************************************/
-- Elimina un expediente del embargo de cuentas. No puede tener cuentas ese expediente.
-- Modificacion: 21/11/2002. Lucas Fernández Pérez. El expediente pasa al embargo que indique
-- el nuevo parámetro xEMBARGO (no a SALARIOS como estaba antes), siempre en estado PENDIENTE, 
-- o vuelve al embargo de INMUEBLES en estado ABIERTO si estaba en ese embargo anteriormente.
-- Se anota la operación en el seguimiento del expediente.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE BORRAR_UNO_SIN_CUENTA(
		xIDEXPE 	IN INT,
		xEMBARGO 	IN CHAR)
AS

	xText 		varchar(150);
	xLote 		Char(10);
	xHUBO_CUENTAS	char(1);

BEGIN

   SELECT HUBO_CUENTAS,LOTE INTO xHUBO_CUENTAS,xLOTE FROM EMBARGOS_CUENTAS
   WHERE IDEXPE=xIDEXPE;

   if xHUBO_CUENTAS='N' then
	   xTEXT:='No se encontraron cuentas corrientes; Lote: '||xLOTE;

	   INSERT INTO SEGUIMIENTO 
      	(ID_EXPE, F_ACTUACION, DESCRIPCION, DEBE_O_HABER)
	   VALUES
      	(xIDEXPE, SYSDATE, xText, 'N');
   end if;
   
   NEXT_PRELA(xIDEXPE,xEMBARGO);

END;
/


/*****************************************************************************************/
-- Elimina un expediente del embargo de cuentas.
-- Modificacion: 21/11/2002. Lucas Fernández Pérez. El expediente pasa al embargo que indique
-- el nuevo parámetro xEMBARGO (no a SALARIOS como estaba antes), siempre en estado PENDIENTE, 
-- o vuelve al embargo de INMUEBLES en estado ABIERTO si estaba en ese embargo anteriormente.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE NEXT_PRELA(
			xIDEXPE 	IN INT,
			xEMBARGO 	IN CHAR)
AS
BEGIN

	if xEMBARGO='1' then
	  -- Poner el expediente en el PENDIENTE de cuentas
 	  update Expedientes set EMBARGO_1='P'
	  where ID=xIDExpe;
	  
	elsif xEMBARGO='3' then
	  -- Poner el expediente en el PENDIENTE de salarios (si no estaba anteriormente)
 	  update Expedientes set EMBARGO_1='0',	Embargo_3=DECODE(EMBARGO_3,'0','P',EMBARGO_3)
	  where ID=xIDExpe;
	  
	elsif xEMBARGO='4' then
	  -- Poner el expediente en el PENDIENTE de inmuebles  (si no estaba anteriormente)
 	  update Expedientes set EMBARGO_1='0',	Embargo_4=DECODE(EMBARGO_4,'0','P',EMBARGO_4)
	  where ID=xIDExpe;
	  
	elsif xEMBARGO='8' then
	  -- Poner el expediente en el PENDIENTE de vehiculos (si no estaba anteriormente)
 	  update Expedientes set EMBARGO_1='0', Embargo_8=DECODE(EMBARGO_8,'0','P',EMBARGO_8)
	  where ID=xIDExpe;

	elsif xEMBARGO='X' then
	  -- Poner el expediente en el PENDIENTE de otros trámites (si no estaba anteriormente)
 	  update Expedientes set EMBARGO_1='0', Embargo_X=DECODE(EMBARGO_X,'0','P',EMBARGO_X)
	  where ID=xIDExpe;
	  
	end if;

    delete from EMBARGOS_CUENTAS where IdExpe=xIdExpe;

END;
/


/*****************************************************************************************/
-- Elimina los expedientes de un lote y zona del embargo de cuentas, que tienen todas sus 
-- cuentas con estado HECHO='S' y sin ingresar.
-- Modificacion: 21/11/2002. Lucas Fernández Perez. Permite pasar cada expediente 
-- al embargo que entra como nuevo parámetro, siempre en estado PENDIENTE,o vuelve al embargo 
-- de INMUEBLES en estado ABIERTO si estaba en ese embargo anteriormente (EN_OTROTRAMITE='S').
-- Se anota la operación en el seguimiento del expediente.
-- Modificacion: 19/01/2004. Gloria Maria Calle Hernandez. Si se trata de un deudor jurídico 
-- no pasará al embargo de salarios, pues no tiene sentido, pasará al embargo de inmuebles.
-- Modificacion: 26/05/2004. Gloria Maria Calle Hernandez. El cambio anterior sobre si se trata 
-- de un deudor jurídico no pasará al embargo de salarios sino al embargo de inmuebles, sólo se 
-- produce cuando xEMBARGO vale 3, es decir, si se está pasando al embargo de salarios.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE NEXT_PRELA_TODOS(
		xZONA 	IN CHAR, 
		xLOTE 	IN CHAR,
		xEMBARGO	IN CHAR)
AS

xIDEXPE INT;

CURSOR EMBARGO_BORRA IS
   SELECT IDEXPE FROM EMBARGOS_CUENTAS
   WHERE ZONA=xZONA AND LOTE=xLOTE
         AND IDEXPE IN (SELECT IDEXPE FROM CUENTAS_LOTES
                        WHERE ZONA=xZONA AND 
                              LOTE=xLOTE AND HECHO='S')
         AND IDEXPE NOT IN (SELECT IDEXPE FROM CUENTAS_LOTES
                            WHERE ZONA=xZONA AND 
                                  LOTE=xLOTE AND HECHO='N')
         AND IDEXPE IN (SELECT ID FROM EXPEDIENTES
                        WHERE F_INGRESO IS NULL);

BEGIN

   FOR v_EMB IN EMBARGO_BORRA LOOP

     NEXT_PRELA(v_EMB.IDEXPE,xEMBARGO);
     
   END LOOP;

END;
/

--
--Creado: 19/02/2003. Agustín León Robles
--Todos aquellos expedientes que tengan embargos parciales y no tengan más cuentas, 
-- poder hacerles de nuevo una diligencia a la misma cuenta.
--	
CREATE OR REPLACE PROCEDURE Put_Parciales(
		xZONA 	IN CHAR, 
		xLOTE 	IN CHAR)
AS

CURSOR cEmbargo_Borra IS
   SELECT * FROM EMBARGOS_CUENTAS
   WHERE ZONA=xZONA AND LOTE=xLOTE
         AND IDEXPE IN (SELECT IDEXPE FROM CUENTAS_LOTES
                        WHERE ZONA=xZONA AND 
                              LOTE=xLOTE AND HECHO='S')
         AND IDEXPE NOT IN (SELECT IDEXPE FROM CUENTAS_LOTES
                            WHERE ZONA=xZONA AND 
                                  LOTE=xLOTE AND HECHO='N')
         AND IDEXPE IN (SELECT ID FROM EXPEDIENTES
                        WHERE F_INGRESO IS NULL);
BEGIN

   FOR v_EMB IN cEmbargo_Borra LOOP

      update Expedientes set FECHA_DILI_CUENTAS=NULL
      where ID=v_EMB.IDExpe;

	update cuentas_lotes set diligencia='N',
					hecho='N',
					importe_retenido=0,
					fecha_retencion=null,
					f_diligencia=null,
					deuda_a_embargar=0

	where idexpe=v_EMB.IDExpe;

	update embargos_cuentas set DEUDA_TOTAL=0,
					EMBARGO='N',F_EMBARGO=null,QUITAR_EMBARGO='N',
					IMPORTE_EMBARGADO=0,FECHA_RETENCION=null,
					NOTIFICADO='N',NEXT_PRELA='N',ID=null,
					F_DILIGENCIA=null,APLICADO='N',
					ALGUN_EMBARGO='N',HUBO_CUENTAS='N',
					PUEDO_DILIGENCIA='S'
	WHERE IdExpe=v_EMB.IdExpe;

   END LOOP;

END;
/





/************************************************************************************
Acción: procedimiento para mover dinero de una cuenta a otra;
MODIFICACIÓN: 28/01/2002 M. Carmen Junco Gómez. El texto escrito en la tabla 
		  MOV_CUENTAS lo introducirá el usuario desde el programa, no será 
		  un texto fijo.
************************************************************************************/

CREATE OR REPLACE PROCEDURE MOVER_ENTRE_CUENTAS(
			xIDOrigen	IN	INTEGER,
			xIDDestino	IN 	INTEGER,
			xIMPORTE	IN	FLOAT,
			xTexto	IN	VARCHAR2,
			xFechaOperacion IN DATE)
AS
   xSaldoDestino FLOAT default 0;
   xSaldoOrigen float default 0;
BEGIN

   /* hacemos el traspaso del dinero: Aumentamos el saldo en la cuenta de Destino
	y lo disminuimos en la cuenta de Origen */
   UPDATE CUENTAS_SERVICIO SET SALDO=ROUND(SALDO+xIMPORTE,2)
   WHERE ID=xIDDestino RETURN Saldo INTO xSaldoDestino;
  
   UPDATE CUENTAS_SERVICIO SET SALDO=ROUND(SALDO-xIMPORTE,2)
   WHERE ID=xIDOrigen RETURN Saldo INTO xSaldoOrigen;
   

   INSERT INTO MOV_CUENTAS 
	(CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
   VALUES
      (xIDDestino,xTEXTO,'MA',ROUND(xIMPORTE,2),
	ROUND(xIMPORTE,2), xIDOrigen,'H',xFechaOperacion,xSaldoDestino);


   INSERT INTO MOV_CUENTAS 
	(CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
   VALUES
      (xIDOrigen,xTEXTO,'MA',ROUND(xIMPORTE,2),
	ROUND(xIMPORTE,2),xIDOrigen,'D',xFechaOperacion,xSaldoOrigen);
   
END;
/


-- Recalcular los saldos de los movimientos bancarios
-- xFecha: seria la fecha desde donde vamos a empezar a realizar el recalculo, o sea tengo
-- que coger el saldo que habia al dia anterior a la fecha que nos den por pantalla
CREATE OR REPLACE PROCEDURE RECALCULAR_SALDOS(
		xIDCuenta		IN	INTEGER,
		xFecha		IN	DATE)
AS
	xSaldoAnterior	FLOAT default 0;
	xID			integer;
	xNuevoCodigo	integer;
	xCuantos		integer default 0;

CURSOR cMovCuentas IS 
	select operacion,id from mov_cuentas where cuenta=xIDCuenta and f_ingreso>=xFecha
	order by f_ingreso,id;
BEGIN

	--se averigua el saldo que habia anterior a esta fecha, para volver a calcular
	--los saldos posteriores
	select max(COD_MOVIMIENTO) into xID from mov_cuentas 
	where cuenta=xIDCuenta and f_ingreso<xFecha;
	if xID is not null then
		select saldo into xSaldoAnterior from mov_cuentas where COD_MOVIMIENTO=xID;
	end if;

	--actualizo todos los movimientos que hay posteriores
	FOR vMovCuentas IN cMovCuentas LOOP

		SELECT GENCUENT_MOV_CUENT.NEXTVAL INTO xNuevoCodigo FROM DUAL;

		if vMovCuentas.Operacion='H' then
			update mov_cuentas set 
				saldo=xSaldoAnterior+importe,
				COD_MOVIMIENTO=xNuevoCodigo
			where ID=vMovCuentas.ID
			RETURN Saldo into xSaldoAnterior;
		else
			update mov_cuentas set 
				saldo=xSaldoAnterior-importe,
				COD_MOVIMIENTO=xNuevoCodigo
			where ID=vMovCuentas.ID
			RETURN Saldo into xSaldoAnterior;
		end if;
	END LOOP;

	UPDATE CUENTAS_SERVICIO SET SALDO=xSaldoAnterior WHERE ID=xIDCuenta;

END;
/



-- Movimientos creados manualmente para una cuenta de ingreso
-- Despues se recalculan todos los movimientos desde un dia en adelante
CREATE OR REPLACE PROCEDURE MOVIMIENTO_DIRECTO(
		xIDCuenta		IN	INTEGER,
		xOperacion		IN    CHAR,
		xTexto		IN	CHAR,
		xFIngreso		IN	DATE,
		xImporte		IN	FLOAT)
AS
BEGIN

	-- Creamos el movimiento para la operación 
	INSERT INTO MOV_CUENTAS 
		(CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,FECHA,F_INGRESO)
	VALUES
		(xIDCuenta,xTexto,'MA',ROUND(xIMPORTE,2),ROUND(xIMPORTE,2),xIDCuenta,
		xOperacion,sysdate,xFIngreso);


	--se recalcula desde una dia antes del movimiento
	RECALCULAR_SALDOS(xIDCuenta,xFIngreso-1);

END;
/


-- Modificar apuntes manuales: a continuacion de esto hay que recalcular los 
-- saldos desde Delphi
CREATE OR REPLACE PROCEDURE MODIFICA_MOV_DIRECTO(
		xID			IN	INTEGER,
		xOperacion		IN    CHAR,
		xTexto		IN	CHAR,
		xImporte		IN	FLOAT)
AS
xFIngreso	date;
xIDCuenta	integer;
BEGIN
	update mov_cuentas set 
			TEXTO=xTexto,
			IMPORTE=ROUND(xImporte,2),RECIBOS=ROUND(xImporte,2),
			OPERACION=xOperacion
	where id=xID return f_ingreso,cuenta into xFIngreso,xIDCuenta;

	--se recalcula desde una dia antes del movimiento
	RECALCULAR_SALDOS(xIDCuenta,xFIngreso-1);

END;
/


-- Eliminar apuntes manuales: a continuacion de esto hay que recalcular los 
-- saldos desde Delphi
CREATE OR REPLACE PROCEDURE DEL_MOV_DIRECTO
		(xID	IN INTEGER)
AS
xFIngreso	date;
xIDCuenta	integer;
BEGIN
	delete from mov_cuentas where Id=xID 
	return f_ingreso,cuenta into xFIngreso,xIDCuenta;

	--se recalcula desde una dia antes del movimiento
	RECALCULAR_SALDOS(xIDCuenta,xFIngreso-1);

END;
/

/**************************************************************************************/
/* tabla temporal para crear una tabla dbase y poder imprimir el documento de diligencia
   de embargo de CC individual mediante combinación 
*/
CREATE OR REPLACE PROCEDURE DILIGENCIA_DBASE(
	xIDEXPE	IN	INTEGER,
	xLOTE		IN	CHAR,	
	xFECHA	IN	DATE)
AS
	xAYUNTAMIENTO	 VARCHAR2(50);
	xCIF_AYTO		 CHAR(10);
	xDIRECCION_AYTO	 VARCHAR2(100);
	xNOMBRE_AYTO	 VARCHAR2(80);
	xPOBLACION_AYTO	 VARCHAR2(50);
	xPROVINCIA_AYTO	 VARCHAR2(50);
	xCARGO_RESPONSABLE CHAR(40);
	xRESPONSABLE	 VARCHAR2(50);
	xENTIDAD		 CHAR(4);
	xNOMBREENTIDAD	 VARCHAR2(50);
	xEXPEDIENTE		 CHAR(10);
	xNIF			 CHAR(10);
	xNOMBRE		 VARCHAR2(40);
	xNIF_CONYUGE	 CHAR(10);
	xNOMBRE_CONYUGE	 VARCHAR2(40);
	xDIRECCION		 VARCHAR2(50);	
	xIMPORTE		 FLOAT;
	xCUENTA1		 CHAR(23);
	xCUENTA2		 CHAR(23);	
	xCUENTA3		 CHAR(23);
	xCUENTA4		 CHAR(23);
	xCUENTASERVICIO	 CHAR(23);				

	CURSOR CEMBARGOS IS SELECT DISTINCT ENTIDAD FROM CUENTAS_LOTES 
				  WHERE LOTE=xLOTE AND IDEXPE=xIDEXPE AND
				  F_DILIGENCIA=xFECHA;

	CURSOR CCUENTAS IS SELECT DISTINCT (ENTIDAD||' '||OFICINA||' '||DC||' '||CUENTA) 
			   		    AS CUENTA,DEUDA_A_EMBARGAR 				
   		             FROM CUENTAS_LOTES WHERE ENTIDAD=xENTIDAD AND
		  	       IDEXPE=xIDEXPE AND LOTE=xLOTE;

BEGIN

   DELETE FROM DILI_DBASE WHERE USUARIO=UID;

   /* datos de cabecera (ayuntamiento,direccion...) */
   SELECT NOMBRE,CIF,DIRECCION,AYUNTAMIENTO,POBLACION,PROVINCIA,CARGO_RESPONSABLE,RESPONSABLE 
   INTO xNOMBRE_AYTO,xCIF_AYTO,xDIRECCION_AYTO,xAYUNTAMIENTO,xPOBLACION_AYTO,xPROVINCIA_AYTO,
	  xCARGO_RESPONSABLE,xRESPONSABLE FROM ZONAS WHERE ZONA IN 
			(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);


   /* datos del expediente y del deudor */
   SELECT EXPEDIENTE,DEUDOR INTO xEXPEDIENTE,xNIF FROM EXPEDIENTES
   WHERE ID=xIDEXPE;

   begin
      SELECT T.NIF,C.NOMBRE INTO xNIF_CONYUGE,xNOMBRE_CONYUGE
      FROM TERCEROS T,CONTRIBUYENTES C
      WHERE T.NIF=C.NIF AND T.EXPEDIENTE=xIDEXPE AND T.RELACION='00';
   exception
	when no_data_found then
		null;
   end;

   SELECT NOMBRE,VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO 
   INTO xNOMBRE,xDIRECCION FROM CONTRIBUYENTES
   WHERE NIF=xNIF;


   OPEN CEMBARGOS;
   LOOP

      FETCH CEMBARGOS INTO xENTIDAD;
	EXIT WHEN CEMBARGOS%NOTFOUND;   

	begin      
   	   SELECT NOMBRE INTO xNOMBREENTIDAD FROM BANCOS WHERE ENTIDAD=xENTIDAD;

         SELECT ENTIDAD||' '||OFICINA||' '||DC||' '||CUENTA INTO xCUENTASERVICIO
	   FROM CUENTAS_SERVICIO WHERE ID IN 
		(SELECT ID_CUENTA_EMBARGO FROM BANCOS WHERE ENTIDAD=xENTIDAD);
	exception
	   when no_data_found then
		null;
	end;

	xCUENTA1:=null;
	xCUENTA2:=null;
	xCUENTA3:=null;
	xCUENTA4:=null;

	FOR v_cuentas IN CCUENTAS 
	LOOP  
         
	   IF (xCUENTA1 is null) THEN
            xCUENTA1:=v_cuentas.CUENTA;
	   ELSIF xCUENTA2 is null THEN
		xCUENTA2:=v_cuentas.CUENTA;
	   ELSIF xCUENTA3 is null THEN
		xCUENTA3:=v_cuentas.CUENTA;
	   ELSIF xCUENTA4 is null THEN
		xCUENTA4:=v_cuentas.CUENTA;
	   END IF;

	   xIMPORTE:=v_cuentas.DEUDA_A_EMBARGAR;
	END LOOP;

	/* insertamos una tupla en la tabla temporal (una por cada entidad diferente) */
	INSERT INTO DILI_DBASE(AYUNTAMIENTO,CIF_AYTO,DIRECCION_AYTO,NOMBRE_AYTO,POBLACION_AYTO,
		PROVINCIA_AYTO,CARGO_RESPONSABLE,RESPONSABLE,ENTIDAD,NOMBREENTIDAD,IDEXPE,
		LOTE,EXPEDIENTE,NIF,NOMBRE,NIF_CONYUGE,NOMBRE_CONYUGE,DIRECCION,IMPORTE,
		CUENTA1,CUENTA2,CUENTA3,CUENTA4,CUENTASERVICIO,FECHA) 
	VALUES (xAYUNTAMIENTO,xCIF_AYTO,xDIRECCION_AYTO,xNOMBRE_AYTO,xPOBLACION_AYTO,
		xPROVINCIA_AYTO,xCARGO_RESPONSABLE,xRESPONSABLE,xENTIDAD,xNOMBREENTIDAD,xIDEXPE,
		xLOTE,xEXPEDIENTE,xNIF,xNOMBRE,xNIF_CONYUGE,xNOMBRE_CONYUGE,xDIRECCION,xIMPORTE,
		xCUENTA1,xCUENTA2,xCUENTA3,xCUENTA4,xCUENTASERVICIO,xFECHA);			      
   END LOOP;
   CLOSE CEMBARGOS;

      
END;
/

/******************************************************************************************
Acción: Rellena una tabla temporal para crear una tabla dbase y poder imprimir el 
        documento de notificación de diligencia de embargo de CC colectivo 
        mediante combinación.
MODIFICACIÓN: 05/08/2003 M. Carmen Junco Gómez. Se selecciona el max(n_relacion) de la 
        tabla de notificaciones poque puede haber más de una tupla.        
******************************************************************************************/

CREATE OR REPLACE PROCEDURE NOTIFICACION_DBASE(
	xLOTE		IN	CHAR,	
	xENTIDAD	IN	CHAR,
	xOFICINA	IN 	CHAR,
	xFECHA	IN	DATE)

AS
	xAYUNTAMIENTO	 VARCHAR2(50);
	xCIF_AYTO		 CHAR(10);
	xDIRECCION_AYTO	 VARCHAR2(100);
	xNOMBRE_AYTO	 VARCHAR2(80);
	xPOBLACION_AYTO	 VARCHAR2(50);
	xPROVINCIA_AYTO	 VARCHAR2(50);
	xCARGO_RESPONSABLE CHAR(40);
	xRESPONSABLE	 VARCHAR2(50);
      xIDEXPE		 INTEGER;
	xEXPEDIENTE		 CHAR(10);
	xNIF			 CHAR(10);
	xNOMBRE		 VARCHAR2(40);
	xNIF_CONYUGE	 CHAR(10);
	xNOMBRE_CONYUGE	 VARCHAR2(40);
	xDIRECCION		 VARCHAR2(50);	
	xCODIGO_POSTAL	 CHAR(5);
	xPOBLACION		 VARCHAR2(35);
	xPROVINCIA		 VARCHAR2(35);
	xIMPORTE		 FLOAT;
	xN_RELACION		 CHAR(10);
	xN_ORDEN		 INTEGER;
	xCUENTA1		 CHAR(74);
	xCUENTA2		 CHAR(74);
	xCUENTA3		 CHAR(74);
	xCUENTA4		 CHAR(74);
	xRETENIDO1		 FLOAT;
      xRETENIDO2		 FLOAT;
	xRETENIDO3		 FLOAT;
	xRETENIDO4		 FLOAT;
	xFRETENCION1	 DATE;
	xFRETENCION2	 DATE;
	xFRETENCION3	 DATE;
	xFRETENCION4	 DATE;
	xTOTALRETENIDO	 FLOAT;
	xOFICINA2		 CHAR(4);
	xContinuar		 BOOLEAN;

	CURSOR CEMBARGOS IS SELECT DISTINCT IDEXPE 
			FROM CUENTAS_LOTES 
				  WHERE LOTE=xLOTE AND ENTIDAD=xENTIDAD AND
				  F_DILIGENCIA=xFECHA AND IMPORTE_RETENIDO>0 AND
				  HECHO='N';

	CURSOR CCUENTAS IS SELECT C.ID,C.DEUDA_A_EMBARGAR,C.ENTIDAD,C.OFICINA,
				  C.DC,C.CUENTA,B.NOMBRE,C.IMPORTE_RETENIDO,C.FECHA_RETENCION
			FROM CUENTAS_LOTES C,BANCOS B 
					WHERE C.ENTIDAD=xENTIDAD 
					AND C.ENTIDAD=B.ENTIDAD 
					AND C.F_DILIGENCIA=xFECHA
					AND C.IDEXPE=xIDEXPE 
					AND C.LOTE=xLOTE 
					AND C.IMPORTE_RETENIDO>0 
					AND C.HECHO='N';



BEGIN
   DELETE FROM NOTI_DBASE WHERE USUARIO=UID;

   -- datos de cabecera (ayuntamiento,direccion...) 
   SELECT NOMBRE,CIF,DIRECCION,AYUNTAMIENTO,POBLACION,PROVINCIA,CARGO_RESPONSABLE,RESPONSABLE 
   INTO xNOMBRE_AYTO,xCIF_AYTO,xDIRECCION_AYTO,xAYUNTAMIENTO,xPOBLACION_AYTO,xPROVINCIA_AYTO,
	  xCARGO_RESPONSABLE,xRESPONSABLE FROM ZONAS WHERE ZONA IN 
			(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   OPEN CEMBARGOS;
   LOOP
      FETCH CEMBARGOS INTO xIDEXPE;
	EXIT WHEN CEMBARGOS%NOTFOUND;

	-- Si la notificación es de una sola oficina, solo va a notificar los expedientes
	-- que tengan importes retenidos de esa oficina. 
	xContinuar:=True;
	IF xOFICINA<>'XXXX' THEN
		-- Si la diligencia de embargo se hizo por oficina, habrá una sola oficina
		-- de la entidad con diligencia emitida por expediente.
		-- No puede haber un expediente en un lote con diligencia de dos oficinas 
		-- distintas de la misma entidad.
		-- Se pone el max porque si puede haber varias cuentas de la misma oficina
		SELECT max(OFICINA) INTO xOFICINA2
			FROM CUENTAS_LOTES
		WHERE IDEXPE=xIDEXPE AND 
			LOTE=xLOTE AND ENTIDAD=xENTIDAD AND
			F_DILIGENCIA=xFECHA AND IMPORTE_RETENIDO>0 AND HECHO='N';
		
		IF xOFICINA<> xOFICINA2 THEN
			xContinuar:=False;
		END IF;

	END IF;

	IF xContinuar=True THEN

         SELECT EXPEDIENTE,DEUDOR INTO xEXPEDIENTE,xNIF FROM EXPEDIENTES
	   WHERE ID=xIDEXPE;

         begin
            SELECT T.NIF,C.NOMBRE INTO xNIF_CONYUGE,xNOMBRE_CONYUGE
         	FROM TERCEROS T,CONTRIBUYENTES C
         	WHERE T.NIF=C.NIF AND T.EXPEDIENTE=xIDEXPE AND T.RELACION='00';
         exception
	   	when no_data_found then
		   begin
			xNIF_CONYUGE:=null;
		 	xNOMBRE_CONYUGE:=null;
		   end;
         end;

         SELECT NOMBRE,VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO,
	    	CODIGO_POSTAL,POBLACION,PROVINCIA
         INTO xNOMBRE,xDIRECCION,xCODIGO_POSTAL,xPOBLACION,xPROVINCIA FROM CONTRIBUYENTES
         WHERE NIF=xNIF;

	   xCUENTA1:=NULL;
	   xCUENTA2:=NULL;
	   xCUENTA3:=NULL;
	   xCUENTA4:=NULL;
	   xFRETENCION1:=NULL;
	   xFRETENCION2:=NULL;
	   xFRETENCION3:=NULL;
	   xFRETENCION4:=NULL;
	   xRETENIDO1:=0;
	   xRETENIDO2:=0;
	   xRETENIDO3:=0;
	   xRETENIDO4:=0;
	   xTOTALRETENIDO:=0;

	   -- cuentas que se declaran embargadas 
	   FOR v_cuentas IN CCUENTAS
	   LOOP
	   	SELECT MAX(N_RELACION),MAX(N_ORDEN) INTO xN_RELACION,xN_ORDEN
	   	FROM NOTIFICACIONES
	   	WHERE EXPEDIENTE=xIDEXPE AND ENTIDAD=xENTIDAD AND ID_EMBARGOS=v_cuentas.ID;

	   	xIMPORTE:=v_cuentas.DEUDA_A_EMBARGAR;

	   	IF xCUENTA1 IS NULL THEN
		   xCUENTA1:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
			    v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
		   xRETENIDO1:=v_cuentas.IMPORTE_RETENIDO;
		   xTOTALRETENIDO:=xRETENIDO1;
		   xFRETENCION1:=v_cuentas.FECHA_RETENCION;
	   	ELSIF xCUENTA2 IS NULL THEN
		   xCUENTA2:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
			    v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
		   xRETENIDO2:=v_cuentas.IMPORTE_RETENIDO;
	         xTOTALRETENIDO:=xTOTALRETENIDO+xRETENIDO2;
		   xFRETENCION2:=v_cuentas.FECHA_RETENCION;
	   	ELSIF xCUENTA3 IS NULL THEN
		   xCUENTA3:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
			    v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
		   xRETENIDO3:=v_cuentas.IMPORTE_RETENIDO;
		   xTOTALRETENIDO:=xTOTALRETENIDO+xRETENIDO3;
		   xFRETENCION3:=v_cuentas.FECHA_RETENCION;
	   	ELSIF xCUENTA4 IS NULL THEN
		   xCUENTA4:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
			    v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
		   xRETENIDO4:=v_cuentas.IMPORTE_RETENIDO;
		   xTOTALRETENIDO:=xTOTALRETENIDO+xRETENIDO4;
		   xFRETENCION4:=v_cuentas.FECHA_RETENCION;
	   	END IF;	   

	   END LOOP;

	   INSERT INTO NOTI_DBASE(AYUNTAMIENTO,CIF_AYTO,DIRECCION_AYTO,NOMBRE_AYTO,POBLACION_AYTO,
		PROVINCIA_AYTO,CARGO_RESPONSABLE,RESPONSABLE,IDEXPE,LOTE,EXPEDIENTE,NIF,
		NOMBRE,NIF_CONYUGE,NOMBRE_CONYUGE,DIRECCION,CODIGO_POSTAL,POBLACION,PROVINCIA,
		IMPORTE,N_RELACION,N_ORDEN,CUENTA1,CUENTA2,CUENTA3,CUENTA4,RETENIDO1,RETENIDO2,
		RETENIDO3,RETENIDO4,FRETENCION1,FRETENCION2,FRETENCION3,FRETENCION4,
		TOTALRETENIDO) 
	   VALUES (xAYUNTAMIENTO,xCIF_AYTO,xDIRECCION_AYTO,xNOMBRE_AYTO,xPOBLACION_AYTO,
		xPROVINCIA_AYTO,xCARGO_RESPONSABLE,xRESPONSABLE,xIDEXPE,xLOTE,xEXPEDIENTE,xNIF,
		xNOMBRE,xNIF_CONYUGE,xNOMBRE_CONYUGE,xDIRECCION,xCODIGO_POSTAL,xPOBLACION,
		xPROVINCIA,xIMPORTE,xN_RELACION,xN_ORDEN,xCUENTA1,xCUENTA2,xCUENTA3,xCUENTA4,
		xRETENIDO1,xRETENIDO2,xRETENIDO3,xRETENIDO4,xFRETENCION1,xFRETENCION2,
		xFRETENCION3,xFRETENCION4,xTOTALRETENIDO);			      

      END IF;

   END LOOP;
   CLOSE CEMBARGOS;

END;
/


/********************************************************************/

/* tabla temporal para crear una tabla dbase y poder imprimir el documento de petición de 
   información en el embargo de CC lote individual mediante combinación
*/
CREATE OR REPLACE PROCEDURE PETICION_INFO_DBASE(
	xLOTE		IN	CHAR,
	xNIF		IN	CHAR)
AS
	xAYUNTAMIENTO	VARCHAR(50);
	xCIF			CHAR(10);
	xDIRECCION		VARCHAR(100);
	xNOMBRE		VARCHAR(80);
	xPOBLACION		VARCHAR(50);
	xPROVINCIA		VARCHAR(50);
	xCARGO_RESPONSABLE CHAR(40);
	xRESPONSABLE	VARCHAR(50);	
	xNOMBRE_DEUDOR	VARCHAR2(40);
	xDOMI_DEUDOR	VARCHAR2(50);
	xNIF_TERCERO	CHAR(10);
	xNOMBRE_TERCERO	VARCHAR2(40);
	xDOMI_TERCERO	VARCHAR2(50);
	xIDEXPE		INTEGER;
	xEXPEDIENTE		CHAR(10);

	CURSOR CENTIDAD IS SELECT NOMBRE FROM BANCOS ORDER BY NOMBRE;
BEGIN

   DELETE FROM INFO_DBASE WHERE USUARIO=UID;

   /* datos de cabecera (ayuntamiento,direccion...) */
   SELECT NOMBRE,CIF,DIRECCION,AYUNTAMIENTO,POBLACION,PROVINCIA,CARGO_RESPONSABLE,RESPONSABLE 
   INTO xNOMBRE,xCIF,xDIRECCION,xAYUNTAMIENTO,xPOBLACION,xPROVINCIA,
	  xCARGO_RESPONSABLE,xRESPONSABLE FROM ZONAS WHERE ZONA IN 
			(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   SELECT A.IDEXPE,A.EXPEDIENTE,B.NOMBRE,
	    VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO
   INTO xIDEXPE,xEXPEDIENTE,xNOMBRE_DEUDOR,xDOMI_DEUDOR
   FROM EMBARGOS_CUENTAS A,CONTRIBUYENTES B
   WHERE A.NIF=B.NIF AND LOTE=xLOTE AND A.NIF=xNIF;

   begin
      SELECT T.NIF,C.NOMBRE,
		VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO
      INTO xNIF_TERCERO,xNOMBRE_TERCERO,xDOMI_TERCERO
      FROM TERCEROS T,CONTRIBUYENTES C
      WHERE T.NIF=C.NIF AND T.EXPEDIENTE=xIDEXPE AND T.RELACION='00';

	Exception
	   When no_data_found then
		null;
   end;

   FOR v_entidad IN CENTIDAD
   LOOP
      INSERT INTO INFO_DBASE(AYUNTAMIENTO,CIF,DIRECCION,NOMBRE,POBLACION,PROVINCIA,
		CARGO_RESPONSABLE,RESPONSABLE,BANCO,NUMLOTE,NIF_DEUDOR,NOMBRE_DEUDOR,
		DOMI_DEUDOR,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,IDEXPE,EXPEDIENTE)
      VALUES (xAYUNTAMIENTO,xCIF,xDIRECCION,xNOMBRE,xPOBLACION,xPROVINCIA,
		xCARGO_RESPONSABLE,xRESPONSABLE,v_entidad.NOMBRE,xLOTE,xNIF,xNOMBRE_DEUDOR,
		xDOMI_DEUDOR,xNIF_TERCERO,xNOMBRE_TERCERO,xDOMI_TERCERO,xIDEXPE,xEXPEDIENTE);
   END LOOP;

END;
/
	

/********************************************************************/

-- tabla temporal para crear una tabla dbase y poder imprimir el documento de notificación de 
--   diligencia de embargo de CC individual mediante combinación 
--
-- Modificado: 11/07/2003. Lucas Fernández Pérez. 
--  Ahora se permite hacer diligencia más de una vez a la misma cuenta, por lo que en la
--  consulta de la tabla de notificaciónes ahora se consulta la notificación más reciente.
--
CREATE OR REPLACE PROCEDURE NOTIFICACION_INDI_DBASE(
	xLOTE		IN	CHAR,	
	xIDEXPE	IN	INTEGER)

AS
	xAYUNTAMIENTO	 VARCHAR2(50);
	xCIF_AYTO		 CHAR(10);
	xDIRECCION_AYTO	 VARCHAR2(100);
	xNOMBRE_AYTO	 VARCHAR2(80);
	xPOBLACION_AYTO	 VARCHAR2(50);
	xPROVINCIA_AYTO	 VARCHAR2(50);
	xCARGO_RESPONSABLE CHAR(40);
	xRESPONSABLE	 VARCHAR2(50);
	xEXPEDIENTE		 CHAR(10);
	xNIF			 CHAR(10);
	xNOMBRE		 VARCHAR2(40);
	xNIF_CONYUGE	 CHAR(10);
	xNOMBRE_CONYUGE	 VARCHAR2(40);
	xDIRECCION		 VARCHAR2(50);	
	xCODIGO_POSTAL	 CHAR(5);
	xPOBLACION		 VARCHAR2(35);
	xPROVINCIA		 VARCHAR2(35);
	xIMPORTE		 FLOAT;
	xN_RELACION		 CHAR(10);
	xN_ORDEN		 INTEGER;
	xCUENTA1		 CHAR(74);
	xCUENTA2		 CHAR(74);
	xCUENTA3		 CHAR(74);
	xCUENTA4		 CHAR(74);
	xRETENIDO1		 FLOAT;
      xRETENIDO2		 FLOAT;
	xRETENIDO3		 FLOAT;
	xRETENIDO4		 FLOAT;
	xFRETENCION1	 DATE;
	xFRETENCION2	 DATE;
	xFRETENCION3	 DATE;
	xFRETENCION4	 DATE;
	xTOTALRETENIDO	 FLOAT;

	CURSOR CCUENTAS IS SELECT C.ID,C.DEUDA_A_EMBARGAR,C.ENTIDAD,C.OFICINA,
					  C.DC,C.CUENTA,B.NOMBRE,C.IMPORTE_RETENIDO,C.FECHA_RETENCION
			       FROM CUENTAS_LOTES C,BANCOS B WHERE C.ENTIDAD=B.ENTIDAD AND 
                            IDEXPE=xIDEXPE AND LOTE=xLOTE AND IMPORTE_RETENIDO>0;



BEGIN

   DELETE FROM NOTI_DBASE WHERE USUARIO=UID;

   /* datos de cabecera (ayuntamiento,direccion...) */
   SELECT NOMBRE,CIF,DIRECCION,AYUNTAMIENTO,POBLACION,PROVINCIA,CARGO_RESPONSABLE,RESPONSABLE 
   INTO xNOMBRE_AYTO,xCIF_AYTO,xDIRECCION_AYTO,xAYUNTAMIENTO,xPOBLACION_AYTO,xPROVINCIA_AYTO,
	  xCARGO_RESPONSABLE,xRESPONSABLE FROM ZONAS WHERE ZONA IN 
			(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   SELECT EXPEDIENTE,DEUDOR INTO xEXPEDIENTE,xNIF FROM EXPEDIENTES
   WHERE ID=xIDEXPE;

   begin
      SELECT T.NIF,C.NOMBRE INTO xNIF_CONYUGE,xNOMBRE_CONYUGE
      FROM TERCEROS T,CONTRIBUYENTES C
      WHERE T.NIF=C.NIF AND T.EXPEDIENTE=xIDEXPE AND T.RELACION='00';
   exception
      when no_data_found then
	   	null;
   end;

   SELECT NOMBRE,VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO,
	    CODIGO_POSTAL,POBLACION,PROVINCIA
   INTO xNOMBRE,xDIRECCION,xCODIGO_POSTAL,xPOBLACION,xPROVINCIA FROM CONTRIBUYENTES
   WHERE NIF=xNIF;

   xCUENTA1:=NULL;
   xCUENTA2:=NULL;
   xCUENTA3:=NULL;
   xCUENTA4:=NULL;
   xTOTALRETENIDO:=0;

   /* cuentas que se declaran embargadas */
   FOR v_cuentas IN CCUENTAS
   LOOP
	SELECT N_RELACION,N_ORDEN INTO xN_RELACION,xN_ORDEN
	FROM NOTIFICACIONES WHERE ID= (SELECT MAX(ID) FROM NOTIFICACIONES
	WHERE EXPEDIENTE=xIDEXPE AND ENTIDAD=v_cuentas.ENTIDAD AND ID_EMBARGOS=v_cuentas.ID);

      xIMPORTE:=v_cuentas.DEUDA_A_EMBARGAR;

      IF xCUENTA1 IS NULL THEN
   	   xCUENTA1:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
		       v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
	   xRETENIDO1:=v_cuentas.IMPORTE_RETENIDO;
	   xTOTALRETENIDO:=xRETENIDO1;
	   xFRETENCION1:=v_cuentas.FECHA_RETENCION;
	ELSIF xCUENTA2 IS NULL THEN
	   xCUENTA2:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
	  	       v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
   	   xRETENIDO2:=v_cuentas.IMPORTE_RETENIDO;
	   xTOTALRETENIDO:=xTOTALRETENIDO+xRETENIDO2;
	   xFRETENCION2:=v_cuentas.FECHA_RETENCION;
	ELSIF xCUENTA3 IS NULL THEN
	   xCUENTA3:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
	  	       v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
	   xRETENIDO3:=v_cuentas.IMPORTE_RETENIDO;
	   xTOTALRETENIDO:=xTOTALRETENIDO+xRETENIDO3;
	   xFRETENCION3:=v_cuentas.FECHA_RETENCION;
	ELSIF xCUENTA4 IS NULL THEN
	   xCUENTA4:=v_cuentas.ENTIDAD||' '||v_cuentas.OFICINA||' '||
	  	       v_cuentas.DC||' '||v_cuentas.CUENTA||' '||v_cuentas.NOMBRE;
	   xRETENIDO4:=v_cuentas.IMPORTE_RETENIDO;
	   xTOTALRETENIDO:=xTOTALRETENIDO+xRETENIDO4;
	   xFRETENCION4:=v_cuentas.FECHA_RETENCION;
	END IF;	   
   END LOOP;

   INSERT INTO NOTI_DBASE(AYUNTAMIENTO,CIF_AYTO,DIRECCION_AYTO,NOMBRE_AYTO,POBLACION_AYTO,
	PROVINCIA_AYTO,CARGO_RESPONSABLE,RESPONSABLE,IDEXPE,LOTE,EXPEDIENTE,NIF,
	NOMBRE,NIF_CONYUGE,NOMBRE_CONYUGE,DIRECCION,CODIGO_POSTAL,POBLACION,PROVINCIA,
	IMPORTE,N_RELACION,N_ORDEN,CUENTA1,CUENTA2,CUENTA3,CUENTA4,RETENIDO1,RETENIDO2,
	RETENIDO3,RETENIDO4,FRETENCION1,FRETENCION2,FRETENCION3,FRETENCION4,
	TOTALRETENIDO) 
   VALUES (xAYUNTAMIENTO,xCIF_AYTO,xDIRECCION_AYTO,xNOMBRE_AYTO,xPOBLACION_AYTO,
	xPROVINCIA_AYTO,xCARGO_RESPONSABLE,xRESPONSABLE,xIDEXPE,xLOTE,xEXPEDIENTE,xNIF,
	xNOMBRE,xNIF_CONYUGE,xNOMBRE_CONYUGE,xDIRECCION,xCODIGO_POSTAL,xPOBLACION,
	xPROVINCIA,xIMPORTE,xN_RELACION,xN_ORDEN,xCUENTA1,xCUENTA2,xCUENTA3,xCUENTA4,
	xRETENIDO1,xRETENIDO2,xRETENIDO3,xRETENIDO4,xFRETENCION1,xFRETENCION2,
	xFRETENCION3,xFRETENCION4,xTOTALRETENIDO);			      

END;
/


/***************************************************************************************
Acción: Control del estado de embargos_cuentas y de diligencias_cuentas
Autor: 28/07/2003 Mª del Carmen Junco Gómez
***************************************************************************************/

CREATE OR REPLACE PROCEDURE CUENTAS_CONTROL_ESTADOS(
				xIDEXPE 		IN	INT,      			
      			xEntidad 		IN	CHAR,
      			xOficina 		IN	CHAR,      			
      			xZONA 			IN 	CHAR,
      			xLOTE 			IN 	CHAR,
      			xF_DILIGENCIA 	IN	DATE) 
AS
	xCUANTOS INTEGER;      			
BEGIN

	-- Control del estado de embargos_cuentas
   	SELECT COUNT(*) INTO xCUANTOS
   	FROM CUENTAS_LOTES 
   	WHERE ZONA=xZONA
		  AND LOTE=xLOTE
		  AND IDEXPE=xIDExpe
		  AND DILIGENCIA='S' 
		  AND HECHO='N'
	      AND IMPORTE_RETENIDO=0;

   	IF xCUANTOS=0 THEN
      	UPDATE EMBARGOS_CUENTAS SET F_DILIGENCIA=NULL, 
      								PUEDO_DILIGENCIA='S', 
      								DEUDA_TOTAL=0
		WHERE IDEXPE=xIDExpe;

      	UPDATE EXPEDIENTES SET FECHA_DILI_CUENTAS=NULL,
      						   INTERES_DILIGENCIA=0
		WHERE ID=xIDExpe;
   	END IF;

    -- control del estado de diligencias_cuentas
   	UPDATE DILIGENCIAS_CUENTAS SET CUANTOS=CUANTOS-1 
   	WHERE ZONA=xZONA
		  AND LOTE=xLOTE
      	  and ENTIDAD=xEntidad 
		  and OFICINA=xOficina
		  AND FECHA_ENVIO=xF_DILIGENCIA
    RETURN CUANTOS INTO xCUANTOS;

   	IF xCUANTOS = 0 THEN
      	DELETE FROM DILIGENCIAS_CUENTAS 
      	WHERE ZONA=xZONA
	   		  AND LOTE=xLOTE
         	  AND ENTIDAD=xEntidad 
	   		  AND OFICINA=xOficina
   	   		  AND FECHA_ENVIO=xF_DILIGENCIA;
   	END IF;
   	
END;
/

/**************************************************************************************
Autor: 23/07/2003 M. Carmen Junco Gómez.
Acción: Rellena una tabla temporal para la generación de la Fase 5 del embargo de 
        cuentas corrientes: Ordenes de levantamiento de retenciones
Parámetros: xFECHA: Hasta que fecha de entrada en el levantamiento
			xENTIDAD: Cuentas de una entidad concreta
			xOFICINA: '0000' todas o una en concreto
Modificado: 18/06/2004. Lucas Fernández Pérez.
	Ahora, si el importe a levantar es cero, pone como código de resultado 00 (Sin actuación)
	Antes siempre ponía como código de resultado 01 (Retencion realizada). 
	Si un expediente se ingresa cuando tiene diligencia pero no tiene leida la fase 4, o cuando
	se ha leido la fase 4 pero no tiene retenciones y no se aplicaron negativos, se levanta,
	pero el importe del levantamiento es cero. Se ponía por tanto en el disco que habia
	una retencion realizada (codigo 01) con 0 euros a levantar, y CajaGranada no lo aceptaba. 
Modificado: 16/07/2004. Lucas Fernández Pérez.
	Si no hay importe que levantar, el tipo de levantamiento se pone a 0 (1 es total y 2 parcial).
DELPHI
**************************************************************************************/
CREATE OR REPLACE PROCEDURE CUENTAS_FASE5
		(xFECHA			DATE,
		 xENTIDAD		CHAR,
		 xOFICINA		CHAR)
AS

	xID		INTEGER;
	xIDEXPE INTEGER;
	xIMP_TOTAL_EMBARGAR FLOAT DEFAULT 0;
	xIMP_TOTAL_RETEN 	FLOAT DEFAULT 0;
	xF_RETENCION 		DATE;
	xCCC1				CHAR(20);		
	xCCC2				CHAR(20);	
	xCCC3				CHAR(20);	
	xC_SEGURIDAD1		CHAR(12);
	xC_SEGURIDAD2		CHAR(12);
	xC_SEGURIDAD3		CHAR(12);
	xIMP_TOTAL_LEVANTAR	FLOAT DEFAULT 0;
	xTIPO_LEVANTA		CHAR(1);
	xIMP_LEVANTAR1		FLOAT DEFAULT 0;
	xTIPO_LEVANTA1		CHAR(1);
	xIMP_LEVANTAR2		FLOAT DEFAULT 0;
	xTIPO_LEVANTA2		CHAR(1);
	xIMP_LEVANTAR3		FLOAT DEFAULT 0;
	xTIPO_LEVANTA3		CHAR(1);
	xRETENIDO1			FLOAT DEFAULT 0;
	xNUEVARETEN1		FLOAT DEFAULT 0;
	xRETENIDO2			FLOAT DEFAULT 0;
	xNUEVARETEN2		FLOAT DEFAULT 0;
	xRETENIDO3			FLOAT DEFAULT 0;
	xNUEVARETEN3		FLOAT DEFAULT 0;
	xCOD_RESULTADO1		CHAR(2);
	xCOD_RESULTADO2		CHAR(2);
	xCOD_RESULTADO3		CHAR(2);
	
	i					INTEGER;
	xIMPORTE			FLOAT DEFAULT 0;
	xPENDIEXPE			FLOAT DEFAULT 0;	
	sPrincipal 			FLOAT DEFAULT 0;
	sRecargo 			FLOAT DEFAULT 0;
	sCostas 			FLOAT DEFAULT 0;
	sDemora 			FLOAT DEFAULT 0;	


	-- expedientes pendientes de levantar no enviados en otro disco.
	CURSOR CEXPEDIENTES IS 
			SELECT N.ID,N.IDEXPE,SUBSTR(N.NIF,1,9) AS NIF,N.F_ENTRADA,C.NOMBRE,
				   SUBSTR(C.VIA||' '||RTRIM(C.CALLE)||' '||C.NUMERO||' '||
				   C.ESCALERA||' '||C.PLANTA ||' '||C.PISO,1,39) AS DOMICILIO,
				   SUBSTR(C.POBLACION,1,12) AS POBLACION,C.CODIGO_POSTAL
			FROM NEXT_LEVANTA_CUENTAS N,CONTRIBUYENTES C
			WHERE N.NIF=C.NIF AND N.ZONA IN (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER)
				  AND TRUNC(N.F_ENTRADA)<=TRUNC(xFECHA) AND F_ENVIO_FASE5 IS NULL;
					
	-- cuentas asociadas a los expedientes pendientes de levantar						   		   
	-- (cuentas a levantar)
    CURSOR CCUENTAS_ENTIDAD IS SELECT ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,
    								  RETENIDO,NUEVARETEN    						        
    						   FROM CUENTAS_A_LEVANTAR
    					 	   WHERE ID=xID AND ENTIDAD=xENTIDAD;							   
    							  
	-- cuentas asociadas a los expedientes pendientes de levantar						   		   
	-- (cuentas a levantar)
    CURSOR CCUENTAS_OFICINA IS SELECT ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,
    								  RETENIDO,NUEVARETEN
    						   FROM CUENTAS_A_LEVANTAR
    						   WHERE ID=xID AND ENTIDAD=xENTIDAD AND OFICINA=xOFICINA;							       							  
	
BEGIN

	DELETE FROM TMP_CUENTAS_FASE5 WHERE USUARIO=UID;
	
	FOR vEXPEDIENTES IN CEXPEDIENTES LOOP
	
		xID:=vEXPEDIENTES.ID;
		
		xIDEXPE:=vEXPEDIENTES.IDEXPE;
		
		i:=0;
		
		IF xOFICINA='0000' THEN -- por entidad						
    			  
    	    -- recogemos el importe total de las retenciones efectuadas; para ello
    	    -- sumamos el campo RETENIDO de la tabla cuentas_a_levantar y el
    	    -- campo IMPORTE_RETENIDO de las posibles cuentas del expediente 
    	    -- para la entidad dada y que no necesiten ser levantadas.
    	    SELECT SUM(RETENIDO),MIN(F_RETENCION) 
    	    INTO xIMP_TOTAL_RETEN,xF_RETENCION
    	    FROM CUENTAS_A_LEVANTAR WHERE ID=xID AND ENTIDAD=xENTIDAD;     	    
    	    
    	    SELECT SUM(IMPORTE_RETENIDO) INTO xIMPORTE FROM CUENTAS_LOTES
    	    	WHERE IDEXPE=xIDEXPE 
    	    			AND DILIGENCIA='S' 
    	    			AND HECHO='N' 
    	    			AND	IMPORTE_RETENIDO > 0 
    	    			AND ENTIDAD=xENTIDAD 
    	    			AND ENTIDAD||OFICINA||DC||CUENTA NOT IN 
    	    			(SELECT ENTIDAD||OFICINA||DC||CUENTA FROM CUENTAS_A_LEVANTAR 
    	    			WHERE ID=xID AND ENTIDAD=xENTIDAD);
    	    
    	    IF (xIMP_TOTAL_RETEN IS NULL) THEN
    	       xIMP_TOTAL_RETEN:=0;
    	    END IF; 	        	    
    	    
    	    IF (xIMPORTE IS NULL) THEN
    	       xIMPORTE:=0;
    	    END IF;
    	    
    	    xIMP_TOTAL_RETEN:=xIMP_TOTAL_RETEN+xIMPORTE;
			
    	    -- retenciones en las distintas cuentas y claves de seguridad
			FOR vCUENTAS IN CCUENTAS_ENTIDAD LOOP
			
				i:=i+1;				
				
				IF i=1 THEN
				
					xCCC1:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||vCUENTAS.DC||vCUENTAS.CUENTA;
						   
				    xRETENIDO1:=vCUENTAS.RETENIDO;
				    
				    xNUEVARETEN1:=vCUENTAS.NUEVARETEN;
				    
				    xIMP_TOTAL_EMBARGAR:=vCUENTAS.DEUDA_A_EMBARGAR;
				    
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD1
				    FROM CUENTAS_CORRIENTES WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC1;
				    
				ELSIF i=2 THEN
				
					xCCC2:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||vCUENTAS.DC||vCUENTAS.CUENTA;
					
					xRETENIDO2:=vCUENTAS.RETENIDO;
					
				    xNUEVARETEN2:=vCUENTAS.NUEVARETEN;
				    
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD2
				    FROM CUENTAS_CORRIENTES WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC2;
				    
				ELSIF i=3 THEN
				
					xCCC3:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||vCUENTAS.DC||vCUENTAS.CUENTA;
					
					xRETENIDO3:=vCUENTAS.RETENIDO;
					
				    xNUEVARETEN3:=vCUENTAS.NUEVARETEN;
				    
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD3
				    FROM CUENTAS_CORRIENTES WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC3;
				    
				END IF;
				
			END LOOP;			   			
		
		ELSE -- por oficina			
    			  
    	    -- recogemos el importe total de las retenciones efectuadas; para ello
    	    -- sumamos el campo RETENIDO de la tabla cuentas_a_levantar y el
    	    -- campo IMPORTE_RETENIDO de las posibles cuentas del expediente 
    	    -- para la entidad dada y que no necesiten ser levantadas.
    	    SELECT SUM(RETENIDO),MIN(F_RETENCION) INTO xIMP_TOTAL_RETEN,xF_RETENCION
    	    FROM CUENTAS_A_LEVANTAR 
    	    WHERE ID=xID AND ENTIDAD=xENTIDAD AND OFICINA=xOFICINA;     	    
    	    
    	    SELECT SUM(IMPORTE_RETENIDO) INTO xIMPORTE FROM CUENTAS_LOTES
    	    WHERE IDEXPE=xIDEXPE 
    	    		AND DILIGENCIA='S' 
    	    		AND HECHO='N' 
    	    		AND IMPORTE_RETENIDO > 0 
    	    		AND ENTIDAD=xENTIDAD 
    	    		AND OFICINA=xOFICINA 
    	    		AND ENTIDAD||OFICINA||DC||CUENTA 
    	    		NOT IN (SELECT ENTIDAD||OFICINA||DC||CUENTA FROM CUENTAS_A_LEVANTAR 
    	    		WHERE ID=xIDEXPE AND ENTIDAD=xENTIDAD AND OFICINA=xOFICINA);
    	    
    	    IF (xIMP_TOTAL_RETEN IS NULL) THEN
    	       xIMP_TOTAL_RETEN:=0;
    	    END IF; 	        	    
    	    
    	    IF (xIMPORTE IS NULL) THEN
    	       xIMPORTE:=0;
    	    END IF;
    	    
    	    xIMP_TOTAL_RETEN:=xIMP_TOTAL_RETEN+xIMPORTE;
		
    	    -- retenciones en las distintas cuentas y claves de seguridad
			FOR vCUENTAS IN CCUENTAS_OFICINA LOOP
			
				i:=i+1;				
				
				IF i=1 THEN
				
					xCCC1:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||vCUENTAS.DC||vCUENTAS.CUENTA;
					
				    xRETENIDO1:=vCUENTAS.RETENIDO;
				    
				    xNUEVARETEN1:=vCUENTAS.NUEVARETEN;
				    
				    xIMP_TOTAL_EMBARGAR:=vCUENTAS.DEUDA_A_EMBARGAR;
				    
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD1
				    FROM CUENTAS_CORRIENTES WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC1;
				    
				ELSIF i=2 THEN
				
					xCCC2:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||vCUENTAS.DC||vCUENTAS.CUENTA;
					
					xRETENIDO2:=vCUENTAS.RETENIDO;
					
				    xNUEVARETEN2:=vCUENTAS.NUEVARETEN;
				    
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD2
				    FROM CUENTAS_CORRIENTES WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC2;
				    
				ELSIF i=3 THEN
				
					xCCC3:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||vCUENTAS.DC||vCUENTAS.CUENTA;
					
					xRETENIDO3:=vCUENTAS.RETENIDO;
					
				    xNUEVARETEN3:=vCUENTAS.NUEVARETEN;
				    
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD3
				    FROM CUENTAS_CORRIENTES WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC3;
				    
				END IF;
				
			END LOOP;		
		
		END IF;		
		
		-- si se han encontrado cuentas para levantar
		IF (i>0) THEN
						
			IF xIMP_TOTAL_EMBARGAR IS NULL THEN
    			xIMP_TOTAL_EMBARGAR:=0;
    		END IF;    	
    	
    		-- Datos orden de levantamiento			
   			PkIngresos.PENDIENTE_EXPE(xIDEXPE,'N',SYSDATE,sPrincipal,sRecargo,sCostas,
        		       		      sDemora,xPENDIEXPE);   		   			
        		       		      
    		IF (i=1) THEN
    	   		xCCC2:=NULL;
    	   		xCCC3:=NULL;
    		ELSIF (i=2) THEN
    	   		xCCC3:=NULL;
    		END IF;
    	
    		xIMP_LEVANTAR1:=0;     -- Importe a levantar 0 por defecto 
    		xIMP_LEVANTAR2:=0;
    		xIMP_LEVANTAR3:=0;
    		
			xCOD_RESULTADO1:='00'; -- Código de resultado "sin actuacion" por defecto
			xCOD_RESULTADO2:='00';
			xCOD_RESULTADO3:='00';

			xTIPO_LEVANTA1:='0';   -- Tipo de levantamiento vacío por defecto
    		xTIPO_LEVANTA2:='0';
    		xTIPO_LEVANTA3:='0';
  		
		
    		IF xCCC1 IS NOT NULL THEN 			
   				
   				xIMP_LEVANTAR1:=xRETENIDO1-xNUEVARETEN1;
   				
   			    
   			    -- Si se levanta algún importe, el código de resultado es 01: Retención Realizada
   			    -- Si no se levanta importe, el código de resultado es 00: Sin Actuación (el valor por defecto).
   			    IF xIMP_LEVANTAR1>0 THEN
    				xCOD_RESULTADO1:='01';
   					if xNUEVARETEN1=0 then
   			   			xTIPO_LEVANTA1:='1'; --levantamiento total de la cuenta
   					else
   			   			xTIPO_LEVANTA1:='2'; --levantamiento parcial de la cuenta
   					end if;
   	            END IF;

   			   				
   			END IF;
   			
   			IF xCCC2 IS NOT NULL THEN  			
   			
   				xIMP_LEVANTAR2:=xRETENIDO2-xNUEVARETEN2;
   			    IF xIMP_LEVANTAR2>0 THEN -- Se levanta importe 
    				xCOD_RESULTADO2:='01';
   					if xNUEVARETEN2=0 then
   		   				xTIPO_LEVANTA2:='1'; --levantamiento total de la cuenta
   					else
   			   			xTIPO_LEVANTA2:='2'; --levantamiento parcial de la cuenta
   			   		end if;
   				END IF;
   				
   			END IF;
   			
   			IF xCCC3 IS NOT NULL THEN   			
   				
   				xIMP_LEVANTAR3:=xRETENIDO3-xNUEVARETEN3;
   			    IF xIMP_LEVANTAR3>0 THEN -- Se levanta importe
    				xCOD_RESULTADO3:='01';
   					if xNUEVARETEN3=0 then
   			   			xTIPO_LEVANTA3:='1'; --levantamiento total de la cuenta
   					else
   			   			xTIPO_LEVANTA3:='2'; --levantamiento parcial de la cuenta
   			   		end if;
   				END IF;
   					
   			END IF;			
   		
   			xIMP_TOTAL_LEVANTAR:=xIMP_LEVANTAR1+xIMP_LEVANTAR2+xIMP_LEVANTAR3;  		
   			
		    IF xIMP_TOTAL_LEVANTAR=0 THEN -- Si no se levanta ninguna cantidad, 
		    	xTIPO_LEVANTA:='0';	      -- el tipo de levantamiento no será parcial ni total, será 0.
		    ELSE
	        	if xPENDIEXPE > 0 then
    	    		xTIPO_LEVANTA:='2'; --levantamiento parcial
        		elsif xPENDIEXPE=0 then
        			xTIPO_LEVANTA:='1'; --levantamiento total
        		end if;
        	END IF;  						
		
   		
			INSERT INTO TMP_CUENTAS_FASE5
				(ID,NIF,NOMBRE,DOMICILIO,MUNICIPIO,CODIGO_POSTAL,IDEXPE,IMP_TOTAL_EMBARGAR,
				IMP_TOTAL_RETEN,F_RETENCION,CCC1,COD_RESULTADO1,IMP_RETENIDO1,CCC2,
				COD_RESULTADO2,IMP_RETENIDO2,CCC3,COD_RESULTADO3,IMP_RETENIDO3,C_SEGURIDAD1,
				C_SEGURIDAD2,C_SEGURIDAD3,IMP_TOTAL_LEVANTAR,TIPO_LEVANTA,IMP_LEVANTAR1,
				TIPO_LEVANTA1,IMP_LEVANTAR2,TIPO_LEVANTA2,IMP_LEVANTAR3,TIPO_LEVANTA3)
			VALUES
				(xID,vEXPEDIENTES.NIF,vEXPEDIENTES.NOMBRE,vEXPEDIENTES.DOMICILIO,
				vEXPEDIENTES.POBLACION,vEXPEDIENTES.CODIGO_POSTAL,xIDEXPE,xIMP_TOTAL_EMBARGAR,
				xIMP_TOTAL_RETEN,xF_RETENCION,xCCC1,xCOD_RESULTADO1,xRETENIDO1,xCCC2,xCOD_RESULTADO2,
				xRETENIDO2,xCCC3,xCOD_RESULTADO3,xRETENIDO3,xC_SEGURIDAD1,xC_SEGURIDAD2,
				xC_SEGURIDAD3,xIMP_TOTAL_LEVANTAR,xTIPO_LEVANTA,xIMP_LEVANTAR1,
				xTIPO_LEVANTA1,xIMP_LEVANTAR2,xTIPO_LEVANTA2,xIMP_LEVANTAR3,xTIPO_LEVANTA3);		
				
		END IF; -- i>0
		
	END LOOP;
	
	
END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
