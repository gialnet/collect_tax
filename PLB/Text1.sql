
/******************************************************************************* 
Acción: Aplicar los Importes Retenidos en las cuentas tanto a lotes Colectivos
	  como Individuales.
Parámetros: xOfiDili tendrá el valor XXXX cuando se haya generado la 
	  diligencia por solo entidades.
MODIFICACIÓN: 29/01/2002. M. Carmen Junco Gómez. En la aplicación del embargo, 
	  		  cuando se realiza el movimiento en la cuenta de Recaudación, indicar
	  		  el número de lote del que procede.
MODIFICACIÓN: 07/03/2003 Mª del Carmen Junco. En vez de usar el campo R_SUSPENDIDOS de la tabla
			  de expedientes, contamos si hay valores suspendidos o no directamente de la tabla
			  de VALORES. (Este cambio viene por un problema de Paco Bustos con la fiabilidad
			  del contenido de R_SUSPENDIDOS)

*********************************************************************************/

CREATE OR REPLACE PROCEDURE APLICAR_IMPORTE_RETENIDOS
(
	xIDCuenta	IN integer,
    xIDExpe 	IN INT,
    xRETENIDO 	IN FLOAT,
    xFECHA 	IN DATE,
    xFECHABANCO IN DATE,
	xOfiDili	IN char,
	xIDCuentaReca IN INT)
AS
xCiego 		integer;
xMessage 		varchar(150);
xENTIDAD 		CHAR(4);
xOFICINA 		CHAR(4);
xDC 			CHAR(2);
xCUENTA 		CHAR(10);
xSUSPENDIDOS 	CHAR(1);

sPrincipal 		float;
sRecargo 		float;
sCostas 		float;
sDemora 		float;
xPENDIENTE 		float;
xFDiligencia	date;
xLote			char(10);

xIdMovCuenta	integer;
xIDBanco		integer;

xZona			char(2);
xConfig		int;
xOrdenIngreso	char(4);
BEGIN

   SELECT ZONA,ENTIDAD,OFICINA,DC,CUENTA,F_DILIGENCIA,LOTE
	INTO xZona,xEntidad,xOficina,xDC,xCuenta,xFDiligencia,xLote
   FROM CUENTAS_LOTES WHERE ID=xIDCuenta;

   SELECT decode(count(*),0,'N','S') INTO xSUSPENDIDOS FROM VALORES WHERE EXPEDIENTE=xIDEXPE
   AND F_SUSPENSION IS NOT NULL;

   --toda esta parte es para que se haga un apunte único en el banco con la suma del total
   --del importe retenido.
   --Si vamos aplicando expediente a expediente en el campo IdMovCuenta de diligencias_cuentas
   --guarderemos el ID de la tabla Mov_Cuentas
   select IDMOVCUENTA into xIdMovCuenta from diligencias_cuentas 
			where ZONA=xZona
			AND LOTE=xLote
			AND ENTIDAD=xEntidad
			AND OFICINA=xOfiDili
			AND FECHA_ENVIO=xFDiligencia;


   -- Generar un código de operación
   CODIGO_OPERACION(xCiego);

   if xIdMovCuenta is null then
	--hace el apunte en mov_cuentas y actualiza el saldo en la cuenta restringida
	COBROS_BANCOS_EXPE(xIDExpe, xIDCuentaReca, xCIEGO,'TC', 
	  xRetenido, xRetenido, xFECHABANCO, 'EMBARGOS DE CUENTAS CORRIENTES LOTE '||xLote);

	--en el campo last_numero de usuarios esta grabado el ID de Mov_cuentas, lo hace
	--el trigger before insert de mov_cuentas
	update diligencias_cuentas set 
			IDMOVCUENTA=(select last_numero from usuarios where usuario=user)
			where ZONA=xZona
			AND LOTE=xLote
			AND ENTIDAD=xEntidad
			AND OFICINA=xOfiDili
			AND FECHA_ENVIO=xFDiligencia;
   else
	--en el caso de que ya estuviera hecho el apunte en el banco lo grabamos en la tabla
	--usuarios para que luego el procedure write_ingreso lo recoja
	update usuarios set last_numero=xIdMovCuenta,Last_baja=xIDCuentaReca
		where usuario=user;

	--las siguientes veces solo se va acumulando el importe retenido en la cuenta
	update mov_cuentas set importe=ROUND(importe+xRetenido,2),
			recibos=ROUND(recibos+xRetenido,2),
			saldo=ROUND(saldo+xRetenido,2)
	where id=xIdMovCuenta
	return cuenta into xIDBanco;

	UPDATE CUENTAS_SERVICIO SET SALDO=ROUND(SALDO+xRetenido,2) WHERE ID=xIDBanco;
   end if;

   -- se ha logrado el embargo total de la deuda 
   -- CODIGO DE INGRESO TC SE CIERRA EL EMBARGO Y SE
   -- PONE COMO PENDIENTE DE IMPRIMIR SU CARTA DE PAGO 
   PkIngresos.PENDIENTE_EXPE(xIDEXPE ,'N', xFECHABANCO,
                sPrincipal, sRecargo, sCostas, 
                sDemora, xPendiente);


   -- EL CONTROL DE IMPORTE ES MAYOR QUE EL DEBITO EN DELPHI 
   xPENDIENTE:=xPENDIENTE-xRETENIDO;

   -- NO HAY RECIBOS SUSPENDIDOS EN EL EXPEDIENTE 
   IF xPENDIENTE = 0 AND xSUSPENDIDOS='N' THEN

      xMessage:='Aplicación embargo ' ||
              xENTIDAD || '-' || xOFICINA || '-'
              || xDC || '-' || xCUENTA;

      PkIngresos.MAKE_INGRE_RETENIDO(xIDExpe, xCiego,xFECHA,xFECHABANCO,
                        xRetenido, 'TC', xIDCuenta, xMessage);

   ELSE

      xMessage:='Aplicación embargo parcial ' ||
              xENTIDAD || '-' || xOFICINA || '-'
              || xDC || '-' || xCUENTA;

      -- aplicar a ingresos el importe retenido y a su
      -- vez anotarlo en el seguimiento del expediente 

      -- Si el contador esta a 1 sera por reparto proporcional y si esta a 0
      -- por antiguedad en la deuda 

	SELECT ORDENINGRESO,APLICO_EMBARGO INTO xOrdenIngreso,xConfig FROM CONFIGURACION
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

	IF xOrdenIngreso='CPRD' THEN
         EXPE_ENTRE_PRIMEROCOSTAS(xIDExpe,xRetenido,
                               xFECHA, xFECHABANCO, xIDCuenta, xMessage, 'EP', xCiego);
	ELSIF (xConfig=1) THEN
         EXPE_ENTRE_PROPORCIONAL(xIDExpe,xRetenido,
                               xFECHA, xFECHABANCO, xIDCuenta, xMessage, 'EP', xCiego);
      ELSE
         EXPE_ENTRE_ANTIGUEDAD(xIDExpe, xRetenido, xIDCuenta,
                             xFECHA, xFECHABANCO, xMessage, 'EP' ,xCiego);
      END IF;


      UPDATE EMBARGOS_CUENTAS SET EMBARGO='N',
                                F_EMBARGO=NULL,
                                APLICADO='S',
                                IMPORTE_EMBARGADO=0,
                                FECHA_RETENCION=NULL,
                                F_DILIGENCIA=NULL
      WHERE IDEXPE=xIDExpe;

   End IF;


   -- Indicar a la cuenta que ha sido aplicada, pero sólo en casos de embargos parciales

   IF xPENDIENTE > 0 THEN
      UPDATE CUENTAS_LOTES SET HECHO='S'
      where ID=xIDCuenta;
   End if;

   IF xPENDIENTE = 0 THEN

	-- Grabar la situación actual para poder reponer bien los ingresos
	INSERT INTO BORRA_EMBARGOS_CUENTAS(IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,
		EMBARGO,F_EMBARGO,QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,
		NOTIFICADO,NEXT_PRELA,ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,
		HUBO_CUENTAS,PUEDO_DILIGENCIA)

	SELECT IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,
		EMBARGO,F_EMBARGO,QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,
		NOTIFICADO,NEXT_PRELA,ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,
		HUBO_CUENTAS,PUEDO_DILIGENCIA

	FROM EMBARGOS_CUENTAS WHERE IDEXPE=xIDEXPE;


      -- Grabar la situación actual el la lista de borrado
      INSERT INTO BORRA_CUENTAS_LOTES (ID,
	LOTE,IDEXPE, EXPEDIENTE, ZONA, NIF, ENTIDAD, OFICINA, DC,CUENTA,
	CLAVE_SEGURIDAD,IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,
	DILIGENCIA,F_DILIGENCIA,DEUDA_A_EMBARGAR,VECES)

	SELECT ID,LOTE, IDEXPE, EXPEDIENTE, ZONA, NIF, ENTIDAD, OFICINA, DC,CUENTA,
	CLAVE_SEGURIDAD,IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,
	DILIGENCIA,F_DILIGENCIA,DEUDA_A_EMBARGAR,VECES

	FROM CUENTAS_LOTES WHERE IDEXPE=xIDExpe;

   -- Borrar el expediente del lote, con su opción on delete cascade borra las cuentas
   DELETE FROM EMBARGOS_CUENTAS WHERE IDEXPE=xIDExpe;

   END IF;

end;
/


/**************************************************************************************/
--el parametro xOFICINA tendrá el valor de XXXX cuando se haya generado la diligencia
--por solo entidades
/*DELPHI*/
/**************************************************************************************/
CREATE OR REPLACE PROCEDURE APLICAR_RETENIDO_TODOS(
			xZONA			IN	CHAR,
			xLOTE			IN	CHAR,
			xENTIDAD		IN	CHAR,
			xOFICINA		IN	CHAR,
			xFECHA          IN	DATE,
			xFECHABANCO     IN  DATE,
			xFDiligencia	IN	DATE,
			xIDCUENTA		IN	INTEGER)

AS
   CURSOR C1 IS SELECT ID,IDExpe,Importe_Retenido
                FROM Cuentas_LOTES WHERE ZONA=xZONA AND Lote=xLote AND IMPORTE_RETENIDO > 0 
                     AND Hecho='N' AND ENTIDAD=xENTIDAD AND OFICINA=xOFICINA 
                     AND F_DILIGENCIA=xFDiligencia;    

   CURSOR C2 IS SELECT ID,IdExpe,Importe_Retenido
		    FROM Cuentas_Lotes WHERE ZONA=xZONA AND LOTE=xLOTE AND IMPORTE_RETENIDO > 0
		         AND Hecho='N' AND ENTIDAD=xENTIDAD AND F_DILIGENCIA=xFDiligencia; 

BEGIN
   IF xOFICINA<>'XXXX' THEN
      FOR v_c1 IN C1 
	LOOP
         APLICAR_IMPORTE_RETENIDOS(v_c1.ID,v_c1.IDEXPE,v_c1.IMPORTE_RETENIDO,
			xFECHA,xFECHABANCO,xOFICINA,xIDCUENTA);
	END LOOP;
   ELSE
      FOR v_c2 IN C2
	LOOP
         APLICAR_IMPORTE_RETENIDOS(v_c2.ID,v_c2.IDEXPE,v_c2.IMPORTE_RETENIDO,
			xFECHA,xFECHABANCO,xOFICINA,xIDCUENTA);

	END LOOP;
   END IF;
END;
/

