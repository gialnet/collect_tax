
-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez
-- No se han realizado cambios.
-- -----------------------------------------------------
/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_INGRESOS
BEFORE INSERT ON INGRESOS
FOR EACH ROW
BEGIN

   SELECT GENERINGRE.NEXTVAL INTO :NEW.ID FROM DUAL;

   UPDATE USUARIOS SET LAST_INGRESO=:NEW.ID WHERE USUARIO=USER;

END;
/


-- Modificado: 02/09/2003. Lucas Fernández Pérez. 
--	Antes insertaba en TMP_TRANSFERENCIAS si tipo_ingreso in ('VB','EB'), pero si la entrega
--		es sobre un expediente en embargo, podia ser de cualquier otro tipo ('ES','EP'...)
--  Por esto se cambia a que el canal de ingreso sea por banco.
/* ***************************************** */

CREATE OR REPLACE TRIGGER T_INGRESOS_TRANSF
AFTER INSERT ON INGRESOS
FOR EACH ROW
BEGIN
   IF (:NEW.CANAL_INGRESO='PB') THEN
   		IF (:NEW.CONCEPTO LIKE '%transferencia%') THEN
   			INSERT INTO TMP_TRANSFERENCIAS (IDINGRESO)
   			VALUES (:NEW.ID);
   		END IF;
   	END IF;
END;
/

/* ***************************************** */
-- Modificado: 14/03/2003. Lucas Fernández Pérez. Recoge el motivo de la reposición del
-- ingreso de la tabla de usuarios, y lo graba en HISTORIA_VALORES.
--
-- Modificado: 26/08/2003. Lucas Fernández Pérez. 
--	Pone cod_ingreso=null en la tabla de valores cuando el ingreso es parcial.
-- Modificado: 22/01/2004. Lucas Fernández Pérez. 
--	Si el ingreso que se borra es de tipo 'PD', PRINCIPAL:=CUOTA_INICIAL, para que el recibo
--	vuelva a tener el importe original (al ingresarlo por domiciliación el principal puede
--  que se haya aminorado si tenía bonificación por domiciliación el recibo)
-- MODIFICADO: 16/02/2005. Gloria Maria Calle. Eliminada actualización sobre 
--			   desglose_valores, pues se eliminan los campos ingresado e id_ingreso,
--			   no se usa nunca. 
--
CREATE OR REPLACE TRIGGER DEL_INGRESOS
BEFORE DELETE ON INGRESOS
FOR EACH ROW
DECLARE

	xNIF			char(10);
	xNombre		char(40);
	xIMPORTE		FLOAT;
	xRECIBOS		FLOAT;
	xImporteIngresado FLOAT;
	xTEXTO 		VARCHAR2(80);
	--este parametro no sirve para nada en este trigger
	xIDMOV		integer;
	xREPUESTO      	CHAR(1);
	xEstado		char(2);
	xCont			INTEGER;
	xIDFrac		INTEGER;
	xDESCRI 		VARCHAR2(70);
	xFinPeVol		date;
BEGIN

	xImporteIngresado:=:OLD.PRINCIPAL+:OLD.RECARGO+:OLD.COSTAS+:OLD.DEMORA;

	IF :OLD.PARTE_DEL_DIA IS NOT NULL THEN

		--si estamos reponiendo ingresos a través de devoluciones de bancos (cuaderno 19)
		--no se ha de hacer en este punto el apunte bancario
		SELECT ESTADO_BANCO INTO xEstado FROM VALORES WHERE ID=:OLD.VALOR;
		IF xEstado is null or xEstado<>'DB' then

		   --se reponen ingresos de embargos de cuentas, parciales o totales
		   if :OLD.TIPO_INGRESO IN ('EP','TC') then
			
			--en este caso se descontaria los importes que estamos reponiendo
			--NOTA: esto tiene un error, si se han producido apuntes bancarios con
			--posterioridad el saldo no seria correcto
			update mov_cuentas set importe=importe-xImporteIngresado,
							recibos=recibos-xImporteIngresado,
							saldo=saldo-xImporteIngresado
			where ID=:OLD.PARTE_DEL_DIA;

			UPDATE CUENTAS_SERVICIO SET SALDO = SALDO - xImporteIngresado
		      WHERE ID=:OLD.CUENTA;

		   else
		      SELECT REPUESTO INTO xREPUESTO FROM MOV_CUENTAS WHERE ID=:OLD.PARTE_DEL_DIA;
		      IF xREPUESTO='N' THEN

			   xTEXTO:='REPONER INGRESO DIA: '||TO_DATE(:OLD.FECHA)||
   			  	  ' COD. OPE: '||TO_CHAR(:OLD.CODIGO_OPERACION) ;
			   --se cojen los importes del movimiento anterior del ingreso
			   SELECT IMPORTE,RECIBOS INTO xIMPORTE,xRECIBOS
			   FROM MOV_CUENTAS WHERE ID=:OLD.PARTE_DEL_DIA;

			   IN_MOV_CUE(:OLD.CUENTA,xTEXTO,'RI',xIMPORTE,xRECIBOS,
		     	   	     :OLD.CUENTA,'D',:OLD.FECHA,xIDMOV);

			   UPDATE MOV_CUENTAS SET REPUESTO='S' WHERE ID=:OLD.PARTE_DEL_DIA;
		      END IF; --fin del IF xREPUESTO='N' THEN
		   end if; --fin del if :OLD.TIPO_INGRESO IN ('EP','TC') then
		END IF; --fin del IF xEstado is null or xEstado<>'DB' then
	END IF; --fin del IF :OLD.PARTE_DEL_DIA IS NOT NULL THEN


	-- COBROS PARCIALES 
	IF :OLD.PARCIAL_O_COBRO='P' THEN
      	UPDATE VALORES SET ENTREGAS_A_CUENTA = ENTREGAS_A_CUENTA - xImporteIngresado,
			DEMORA = DEMORA - :OLD.DEMORA,
			DEMORA_PENDIENTE = DEMORA_PENDIENTE + :OLD.DEMORA, COD_INGRESO=NULL
		WHERE ID=:OLD.VALOR
		RETURN NIF,NOMBRE,FIN_PE_VOL INTO xNIF,xNombre,xFinPeVol;

		--insertamos en historia_valores la reposicion al cobro de cualquier cobro parcial
		--el resto de casos de realiza en el trigger TR_HISTORIA_VALORES
		SELECT RTRIM(SUBSTR(TEXTO,1,70)) INTO xDESCRI FROM USUARIOS WHERE USUARIO=USER;
		INSERT INTO HISTORIA_VALORES
			(ID,VALOR,COD_OPERACION,NIF,NOMBRE,FECHA,
			TIPO_DATA,EXPLICACION,USUARIO,TERMINAL)
		VALUES
			(GEN_H_VALOR.NEXTVAL,:OLD.VALOR,:OLD.CODIGO_OPERACION,xNIF,xNOMBRE,
			SYSDATE, :OLD.TIPO_INGRESO, xDESCRI, USER, UID);
	ELSE
		UPDATE VALORES SET F_INGRESO=NULL,COD_INGRESO=NULL,
			PRINCIPAL=DECODE(:OLD.TIPO_INGRESO,'PD',CUOTA_INICIAL,PRINCIPAL),
			ENTREGAS_A_CUENTA=ENTREGAS_A_CUENTA - xImporteIngresado,
			DEMORA = DEMORA - :OLD.DEMORA,
			DEMORA_PENDIENTE = :OLD.DEMORA
		WHERE ID=:OLD.VALOR
		RETURN FIN_PE_VOL INTO xFinPeVol;

		-- Fraccionamientos Voluntaria: Mira si el ingreso es sobre un valor de un plazo
		-- en ejecutiva abre el fraccionamiento. El valor sobre el que se hace el
		-- fraccionamiento es otro distinto del que estamos reponiendo.
		select count(*), max(fracciona) into xCont,xIDFrac from plazos_frac_vol where valor=:OLD.VALOR;
		if xCont>0 then
		   UPDATE VALORES SET F_INGRESO=NULL,COD_INGRESO=NULL
		   WHERE ID=(SELECT VALOR FROM FRACCIONAMIENTO_VOL WHERE ID=xIDFrac);

		   update FRACCIONAMIENTO_VOL
		   set F_CIERRE=NULL,ISOPEN='S',ESTADO='ABIERTO',F_ESTADO=NULL
		   where ID=xidFrac;

   		end if;

	END IF;

	--
	-- Si estamos reponiendo un ingreso de un recibo en voluntaria
	-- tendremos que comprobar si estaba anteriormente en ejecutiva
	--

	IF :OLD.F_COBRO_BANCO IS NOT NULL THEN
		IF (:OLD.vol_eje='V' and :OLD.F_COBRO_BANCO <= xFinPeVol AND :OLD.TIPO_INGRESO <> 'PD') then
		   COMMEBACK_EJECUTIVA(:OLD.Valor);
		END IF;
	END IF;

END;
/

