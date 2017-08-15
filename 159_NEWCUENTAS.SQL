-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.Rounds en insert/update.
-- -----------------------------------------------------
/*****************************************************************************************/
-- PASA LAS CUENTAS DE UN CONTRIBUYENTE AL LOTE
-- Inserta en CUENTAS_LOTES las cuentas de un expediente que hay en CUENTAS_CORRIENTES.
/* BASE*/
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE PASA_CUENTAS_DEL_CONTRI(
	xNIF 		IN	CHAR,
      xLOTE 	IN	CHAR,
      xZONA 	IN	CHAR,
      xEXPE 	IN	CHAR,
      xIDEXPE 	IN	INTEGER)
AS
BEGIN


  INSERT INTO CUENTAS_LOTES
	(LOTE, IDEXPE, NIF, ZONA, EXPEDIENTE,
	ENTIDAD, OFICINA, DC, CUENTA, CLAVE_SEGURIDAD,VECES)

  SELECT xLOTE, xIDEXPE, xNIF, xZONA, xEXPE,ENTIDAD,OFICINA,DC,CUENTA,CLAVE_SEGURIDAD,VECES
    FROM CUENTAS_CORRIENTES
    WHERE NIF=xNIF AND ENTIDAD||OFICINA||DC||CUENTA NOT IN 
		(SELECT ENTIDAD||OFICINA||DC||CUENTA FROM CUENTAS_LOTES WHERE NIF=xNIF);
END;
/

/* ******************************************************* */
-- Añade un expediente a un lote.
/*DELPHI*/
/* ******************************************************* */

CREATE OR REPLACE PROCEDURE PUT_UnExpeEnLote_CC(
        xLote 		IN 		char,
        xIDExpe 		IN 		Integer,
        xExpe 		IN		char,
        xNIF 		IN 		char)
AS
	xZONA CHAR(2);
BEGIN
	-- CAMBIAR EL ESTADO DEL EXPEDIENTE DE PENDIENTE A EN CURSO 
	UPDATE EXPEDIENTES SET F_EMBARGO_CUENTAS=SYSDATE,EMBARGO_1='O'
	WHERE ID=xIDEXPE;

	--zona de quien creo el lote
	select zona into xZona from head_lotes_cuentas where lote=xLote;

	-- AÑADIR EL EXPEDIENTE AL LOTE 
	INSERT INTO EMBARGOS_CUENTAS(IDExpe, EXPEDIENTE, LOTE, NIF, ZONA)
	VALUES(xIDExpe, xEXPE, xLOTE, xNIF, xZONA);

	-- LEER LAS CUENTAS CONOCIDAS DEL DEUDOR Y METERLAS EN EL LOTE 
	PASA_CUENTAS_DEL_CONTRI(xNIF, xLOTE, xZONA, xEXPE, xIDEXPE);
END;
/


--**************************************************************************
-- Acción: Agregar a un lote todos los expedientes de una zona pendientes de embargo, 
--         sin estar ingresados, anulados o suspendidos y entre cantidades.
-- DELPHI
--**************************************************************************
CREATE OR REPLACE PROCEDURE PUT_EN_CUENTAS_between(
		xZonaExp	IN	char,
		xLote 	IN 	char,
      	xDesde 	IN	float,
	      xHasta 	IN	float)
AS

CURSOR EXPE_CUR IS
   SELECT E.ID,E.EXPEDIENTE,E.DEUDOR
   FROM EXPEDIENTES E, PendiValoresExpe V
   WHERE E.ID=V.EXPEDIENTE 
	AND EMBARGO_1='P' 
	AND ZONA=xZonaExp
	AND E.F_INGRESO IS NULL
    AND E.F_ANULACION IS NULL 
	AND E.F_SUSPENSION IS NULL
    AND V.PENDIENTE BETWEEN xDESDE AND xHASTA;
BEGIN

	FOR v_EXPE IN EXPE_CUR LOOP

		PUT_UnExpeEnLote_CC(xLote,v_EXPE.ID,v_EXPE.EXPEDIENTE,v_EXPE.DEUDOR);

	END LOOP;

END;
/


--*****************************************************************************************
-- Acción: Agregar a un lote todos los expedientes de una zona pendientes de embargo, 
--         sin estar ingresados, anulados o suspendidos.
-- MODIFICACIÓN: 02/02/2004 Mª del Carmen Junco Gómez. Quitamos la restricción del maximo
--               importe para C63. Se restringe desde la generación de la diligencia.
-- DELPHI
--*****************************************************************************************
CREATE OR REPLACE PROCEDURE PUT_EN_LOTE_CUENTAS(
	        xLote 	IN	char, 
		  xZonaExp 	IN	char)
AS
xPendiente float;

CURSOR CUR_ZONA IS
   SELECT ID,EXPEDIENTE,DEUDOR
   FROM EXPEDIENTES 
   WHERE EMBARGO_1='P'
		 AND ZONA=xZonaExp AND F_INGRESO IS NULL 
         AND F_ANULACION IS NULL AND F_SUSPENSION IS NULL;
BEGIN  

  FOR v_EXPE IN CUR_ZONA LOOP	
		PUT_UnExpeEnLote_CC(xLote,v_EXPE.ID,v_EXPE.EXPEDIENTE,v_EXPE.DEUDOR);
  END LOOP;

END;
/

/* ************************************************** */
-- Crea un nuevo lote vacio, sin ningun expediente
/*DELPHI*/
/* ************************************************** */
CREATE OR REPLACE PROCEDURE NUEVOLOTE(
        xMODO	IN	 CHAR,
        xFECHA 	IN	 DATE)
AS
xZONA CHAR(2);
BEGIN

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	INSERT INTO HEAD_LOTES_CUENTAS (ZONA, FECHA, MODO)
	VALUES (xZONA, xFECHA, xMODO);

END;
/

/*****************************************************************************************/
-- Generacion de una diligencia a una entidad y oficina de un expediente de un lote.
-- En DILIGENCIAS_CUENTAS se añade la diligencia generada.
-- cambios por Antonio el día 23 Nov 2001
-- MODIFICACIÓN: M. Carmen Junco Gómez. 5/03/2002. Se incluye el número de lote en la
-- 		     nota informativa para el seguimiento.
/*BASE*/
CREATE OR REPLACE PROCEDURE NUEVA_DILIGENCIA(
        xZONA 		IN	CHAR,
        xLOTE 		IN	CHAR,
        xENTIDAD	 	IN	CHAR,
        xOFICINA 		IN	CHAR,
        xDC 		IN	CHAR,
        xCUENTA 		IN	CHAR,
        xFDILIGENCIA 	IN	DATE,
        xIDExpe 		IN	INT,
        xIDCuenta 	IN	INT)

AS

SiHay   INT;
xTEXTO  CHAR(150);
xIDDili INT;
BEGIN

    update DILIGENCIAS_CUENTAS set Cuantos=Cuantos+1
	    where ZONA=xZONA 
		AND lote=xLOTE
      	and entidad=xENTIDAD 
		and OFICINA=xOFICINA
	      and FECHA_ENVIO=xFDILIGENCIA
	RETURNING ID INTO xIDDili;



   IF NOT SQL%FOUND THEN

	    INSERT INTO DILIGENCIAS_CUENTAS
      	 (ZONA,LOTE,ENTIDAD,OFICINA,FECHA_ENVIO,CUANTOS)
	    VALUES 
      	 (xZONA,xLOTE,xENTIDAD,xOFICINA,xFDILIGENCIA, 1)
		RETURNING ID INTO xIDDili;

   END IF;

   -- Lo anotamos en el seguimiento del expediente

   xTexto:='Diligencia emb. ZONA: ' || xZona || '-Lote: ' || xLOTE || '-Cuenta: ' ||
      	   xEntidad || '-'|| xOficina ||'-'|| xDC ||'-'||
	         xCuenta || '-Fecha: ' || DAYOFMONTH(xFDILIGENCIA) ||'-' ||
      	   MONTH(xFDILIGENCIA) || '-' || F_YEAR(xFDILIGENCIA);
	
   PkSeguimiento.NotaInformativa(xIDExpe,xTexto,xIDCuenta);

   -- Marcamos los valores que van a entar en esta diligencia
   Update Valores set ID_DILIG_ECC=xIDDili 
	where Expediente=xIDExpe
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL;

END;
/

/*****************************************************************************************/
-- Generacion de diligencias de una entidad, oficina y expediente de un lote.
-- Hasta un máximo de 3 diligencias. Hace diligencia de las 3 cuentas más utilizadas.
/*BASE*/
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE MAXIMO_3_CUENTAS(
        xZONA 		IN	CHAR,
        xLOTE 		IN	CHAR,
        xIDEXPE 		IN	INT,
        xENTIDAD 		IN	CHAR,
        xOFICINA 		IN	CHAR,
        xFDILIGENCIA 	IN	DATE,
        xDeuda_Total 	IN	float)
AS

xContador	integer default 1;

 CURSOR CC_ID IS SELECT ID,DC,CUENTA
    FROM CUENTAS_LOTES 
    WHERE ZONA=xZONA 
	AND LOTE=xLOTE
	AND IDExpe=xIDEXPE 
	AND ENTIDAD=xENTIDAD
	AND OFICINA=xOFICINA 
	AND DILIGENCIA='N'
	ORDER BY VECES DESC
 FOR UPDATE OF diligencia,f_diligencia,DEUDA_A_EMBARGAR;

BEGIN

   FOR v_CC IN CC_ID LOOP

	UPDATE CUENTAS_LOTES SET DILIGENCIA='S',
                            F_DILIGENCIA=xFDILIGENCIA,
                            DEUDA_A_EMBARGAR=ROUND(xDeuda_Total,2)
	WHERE ID=v_CC.ID;

	NUEVA_DILIGENCIA(xZONA, xLOTE, xENTIDAD, xOFICINA,
                    v_CC.DC, v_CC.CUENTA, xFDILIGENCIA, xIDExpe, v_CC.ID);

	if (xContador >= 3) then
		exit;
	end if;

	xContador:=xContador+1;

   END LOOP;

END;
/

-- GENERAR DILIGENCIAS ENTIDADES Y OFICINAS
-- Genera diligencias para los expedientes del lote a los se le puede emitir 
-- una nueva diligencia y que tengan cuentas pendientes en una ENTIDAD Y OFICINA 

-- Modificado: 08/10/2002 Agustin Leon Robles. Los expedientes superiores a 4000 euros
--			no debe de generar diligencia de embargo
--
-- Modificado: 01/04/2003 Agustín León Robles. 
--			xLimiteDiligencia: en todos los ayuntamientos tendran 0 y en ATECO tendran 60 euros que 
--			significa que aquellos expedientes que tengan que tengan una deuda superior a 
--			60 euros las diligencias de embargo saldran como maximo por este importe

/*DELPHI*/
CREATE OR REPLACE PROCEDURE MAKE_CUENTAS_DILIGENCIA(
        xZONA 		IN	ZONAS.ZONA%Type,
        xLOTE 		IN	CUENTAS_LOTES.LOTE%Type,
        xENTIDAD 		IN	CUENTAS_LOTES.ENTIDAD%Type,
        xOFICINA 		IN	CUENTAS_LOTES.OFICINA%Type,
        xFDILI 		IN 	DATE)

AS

Intereses 		float DEFAULT 0;
xDeuda_Total 	float DEFAULT 0;
xRetenido 		float DEFAULT 0;
xPendiente 		float DEFAULT 0;
xMaximo 		float default 0;
xLimiteDiligencia	float DEFAULT 0;

-- Todos los expediente de una zona, de un lote, a los que se le pueda emitir diligencia
-- que su expediente sea de una entidad y oficina
-- que su expediente no esté ni ingresado ni anulado

CURSOR cEmbargos IS
  Select IDExpe,F_DILIGENCIA
  from embargos_cuentas
  where ZONA=xZONA 
	AND Lote=xLote
      and PUEDO_DILIGENCIA='S'
      and IDExpe in (select IDExpe from cuentas_lotes
                       where entidad=xEntidad and oficina=xOficina
                       and diligencia='N')
      and IDExpe in (Select ID from expedientes
                       where f_ingreso is null
                       and f_anulacion is null)
  FOR UPDATE OF DEUDA_TOTAL,F_DILIGENCIA,PUEDO_DILIGENCIA;


BEGIN


	--xMaximo: tendra grabado 4000 euros que significa que aquellos que tengan una deuda pendiente 
	--		superior a 4000 euros no podran entrar en el embargo de cuentas colectivo
	--xLimiteDiligencia: en todos los ayuntamientos tendran 0 y en ATECO tendran 60 euros que 
	--		significa que aquellos expedientes que tengan que tengan una deuda superior a 
	--		60 euros las diligencias de embargo saldran como maximo por este importe

	select MAXIMO_IMPORTE_C63,IMPORTE_C63 into xMaximo,xLimiteDiligencia from configuracion 
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);


	-- Relación de expedientes del lote a los se le puede emitir una nueva diligencia
	-- y que tengan cuentas pendientes en la ENTIDAD Y OFICINA que estoy buscando

	FOR vEmbargos IN cEmbargos LOOP

		intereses:=0;
		xDeuda_Total:=0;

		--Nos devuelve la diferencia entre el pendiente y lo retenido
		PkIngresos.Get_PendienteRetenido(vEmbargos.IDExpe, xPendiente);

		if (xPendiente > 0) and (xPendiente <= xMaximo) then

			-- Si hay una diligencia previa no volver a calcular los intereses de demora
			if vEmbargos.F_DILIGENCIA is null then
            		CalcDemora_Expe(vEmbargos.IDEXPE, xFDILI, 'S','E', Intereses, xDeuda_Total);
			else
				xDeuda_Total:=xPendiente;         
			End IF;


			--xLimiteDiligencia: en todos los ayuntamientos tendran 0 y en ATECO tendran 60 euros que 
			--significa que aquellos expedientes que tengan una deuda superior a 
			--60 euros las diligencias de embargo saldran como maximo por este importe
			if xLimiteDiligencia > 0 then
				if xDeuda_Total > xLimiteDiligencia then
					xDeuda_Total:= xLimiteDiligencia;
				end if;
			end if;

			UPDATE EMBARGOS_CUENTAS SET 
				DEUDA_TOTAL = ROUND(DECODE(DEUDA_TOTAL,0,xDeuda_Total,DEUDA_TOTAL),2),
				F_DILIGENCIA=xFDILI, PUEDO_DILIGENCIA='N'
			WHERE current of cEmbargos;

			-- generar la nueva diligencia
			MAXIMO_3_CUENTAS(xZONA, xLOTE, vEmbargos.IDEXPE, xENTIDAD,xOFICINA, xFDILI, xDeuda_Total);

			UPDATE EXPEDIENTES SET FECHA_DILI_CUENTAS=xFDILI,
                             INTERES_DILIGENCIA=ROUND(Intereses,2)
			WHERE ID=vEmbargos.IDEXPE;

		End if;

	End LOOP;

END;
/

/*****************************************************************************************/
--
-- Generacion de diligencias por solo entidades 
-- cambios por Antonio el día 23 Nov 2001
-- MODIFICACIÓN: M. Carmen Junco Gómez. Añadir el lote a la nota informativa en el Seguimiento.
/*BASE*/
CREATE OR REPLACE PROCEDURE NUEVA_DILIGENCIA_ENTIDAD(
        xZONA 		IN	CHAR,
        xLOTE 		IN	CHAR,
        xENTIDAD 		IN	CHAR,
        xOFICINA 		IN	CHAR,
        xDC 		IN	CHAR,
        xCUENTA 		IN	CHAR,
        xFDILIGENCIA 	IN	DATE,
        xIDExpe 		IN	INT,
        xIDCuenta 	IN	INT)

AS

SiHay   INT;
xTEXTO  CHAR(150);
xIDDili INT;

BEGIN

   select count(*) INTO SiHay from DILIGENCIAS_CUENTAS
   where ZONA=xZONA 
	AND lote=xLOTE 
 	and entidad=xENTIDAD 
	and oficina='XXXX'
      and FECHA_ENVIO=xFDILIGENCIA;

      update DILIGENCIAS_CUENTAS set Cuantos=Cuantos+1
      where ZONA=xZONA AND lote=xLOTE
          and entidad=xENTIDAD and OFICINA='XXXX'
          and FECHA_ENVIO=xFDILIGENCIA
	RETURNING ID INTO xIDDili;

   IF NOT SQL%FOUND THEN

      INSERT INTO DILIGENCIAS_CUENTAS
         (ZONA,LOTE,ENTIDAD,OFICINA,FECHA_ENVIO,CUANTOS)
      VALUES 
         (xZONA,xLOTE,xENTIDAD,'XXXX',xFDILIGENCIA, 1)
	RETURNING ID INTO xIDDili;

   END IF;

   xTexto:='Diligencia emb. ZONA: ' || xZona || '-Lote: ' || xLOTE || '-Cuenta: ' || 
         xEntidad || '-'|| xOficina ||'-'|| xDC ||'-'||
         xCuenta || '-Fecha: ' || DAYOFMONTH(xFDILIGENCIA) ||'-' ||
         MONTH(xFDILIGENCIA) || '-' || F_YEAR(xFDILIGENCIA);

   PkSeguimiento.NotaInformativa(xIDExpe,xTexto,xIDCuenta);

  -- Marcamos los valores que van a entrar en esta diligencia
   Update Valores set ID_DILIG_ECC=xIDDili 
	where Expediente=xIDExpe
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL;

END;
/

/*****************************************************************************************/
-- Generacion de diligencias por entidad. De un expediente de un lote.
-- Hasta un máximo de 3 diligencias. Hace diligencia de las 3 cuentas más utilizadas.
/*BASE*/
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE MAXIMO_3_ESPECIAL_CUENTAS(
        xZONA 		IN		CHAR,
        xLOTE 		IN		CHAR,
        xIDEXPE 		IN		INT,
        xENTIDAD 		IN		CHAR,
        xFDILIGENCIA 	IN		DATE,
        xDeuda_Total 	IN		float)
AS

  xContador	integer default 1;

  CURSOR CC_ID IS SELECT ID,OFICINA,DC,CUENTA 
			FROM CUENTAS_LOTES 
				WHERE ZONA=xZONA 
				AND LOTE=xLOTE
			      AND IDExpe=xIDEXPE 
				AND ENTIDAD=xENTIDAD 
				AND DILIGENCIA='N'
			ORDER BY VECES DESC
  FOR UPDATE OF diligencia,f_diligencia,DEUDA_A_EMBARGAR;

BEGIN

   FOR v_CC IN CC_ID LOOP

	UPDATE CUENTAS_LOTES SET DILIGENCIA='S',
                            F_DILIGENCIA=xFDILIGENCIA,
                            DEUDA_A_EMBARGAR=ROUND(xDeuda_Total,2)
	WHERE ID=v_CC.ID;

	NUEVA_DILIGENCIA_ENTIDAD(xZONA, xLOTE, xENTIDAD, v_CC.OFICINA,
                    v_CC.DC, v_CC.CUENTA, xFDILIGENCIA, xIDExpe, v_CC.ID);

	if (xContador >= 3) then
		exit;
	end if;

	xContador:=xContador+1;

   END LOOP;

END;
/

-- GENERAR DILIGENCIAS SOLO ENTIDADES
-- Genera diligencias para los expedientes del lote a los se le puede emitir 
-- una nueva diligencia y que tengan cuentas pendientes en una ENTIDAD 
-- Modificado: 08/10/2002 Agustín León Robles. Los expedientes superiores a 4000 euros
--			no debe de generar diligencia de embargo

-- Modificado: 01/04/2003 Agustín León Robles. 
--			xLimiteDiligencia: en todos los ayuntamientos tendran 0 y en ATECO tendran 60 euros que 
--			significa que aquellos expedientes que tengan que tengan una deuda superior a 
--			60 euros las diligencias de embargo saldran como maximo por este importe

/*DELPHI*/
CREATE OR REPLACE PROCEDURE MAKE_ESPECIAL_CUENTAS_DILI(
        xZONA 		IN ZONAS.ZONA%Type,
        xLOTE 		IN CUENTAS_LOTES.LOTE%Type,
        xENTIDAD 		IN CUENTAS_LOTES.ENTIDAD%Type,
        xFDILI 		IN DATE)
AS
Intereses 		float DEFAULT 0;
xDeuda_Total 	float DEFAULT 0;
xRetenido 		float DEFAULT 0;
xPendiente 		float DEFAULT 0;
xMaximo		float DEFAULT 0;
xLimiteDiligencia	float DEFAULT 0;

	CURSOR cEmbargos IS
		Select IDExpe,F_DILIGENCIA
		from embargos_cuentas
		where ZONA=xZONA AND Lote=xLote
			and PUEDO_DILIGENCIA='S' 
			and IDExpe in (select IDExpe from cuentas_lotes
		                        where entidad=xEntidad and diligencia='N')
			and IDExpe in (Select ID from expedientes 
      					where f_ingreso is null
						and f_anulacion is null)
	FOR UPDATE OF DEUDA_TOTAL,F_DILIGENCIA,PUEDO_DILIGENCIA;


BEGIN


	--xMaximo: tendra grabado 4000 euros que significa que aquellos que tengan una deuda pendiente 
	--		superior a 4000 euros no podran entrar en el embargo de cuentas colectivo
	--xLimiteDiligencia: en todos los ayuntamientos tendran 0 y en ATECO tendran 60 euros que 
	--		significa que aquellos expedientes que tengan que tengan una deuda superior a 
	--		60 euros las diligencias de embargo saldran como maximo por este importe

	select MAXIMO_IMPORTE_C63,IMPORTE_C63 into xMaximo,xLimiteDiligencia from configuracion 
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);


	--Relación de expedientes del lote a los se le puede emitir una nueva diligencia
	--y que tengan cuentas pendientes en la ENTIDAD que estoy buscando
	FOR vEmbargos IN cEmbargos LOOP

		intereses:=0;
		xDeuda_Total:=0;

		--Nos devuelve la diferencia entre el pendiente y lo retenido
		PkIngresos.Get_PendienteRetenido(vEmbargos.IDExpe, xPendiente);

		if (xPendiente > 0) and (xPendiente <= xMaximo) then

			--Si hay una diligencia previa no volver a calcular los intereses de demora 
			if vEmbargos.F_DILIGENCIA is null then
				CalcDemora_Expe(vEmbargos.IDEXPE, xFDILI, 'S','E', Intereses, xDeuda_Total);
			else
				xDeuda_Total:=xPendiente;
			End IF;

			--xLimiteDiligencia: en todos los ayuntamientos tendran 0 y en ATECO tendran 60 euros que 
			--significa que aquellos expedientes que tengan que tengan una deuda superior a 
			--60 euros las diligencias de embargo saldran como maximo por este importe
			if xLimiteDiligencia > 0 then
				if xDeuda_Total > xLimiteDiligencia then
					xDeuda_Total:= xLimiteDiligencia;
				end if;
			end if;

			UPDATE EMBARGOS_CUENTAS SET DEUDA_TOTAL = ROUND(DECODE(DEUDA_TOTAL,0,xDeuda_Total,DEUDA_TOTAL),2),
					F_DILIGENCIA=xFDILI, 
					PUEDO_DILIGENCIA='N'
			WHERE current of cEmbargos;

			--generar la nueva diligencia
			MAXIMO_3_ESPECIAL_CUENTAS (xZONA,xLOTE,vEmbargos.IDEXPE,xENTIDAD,xFDILI,xDeuda_Total);

			UPDATE EXPEDIENTES SET FECHA_DILI_CUENTAS=xFDILI,INTERES_DILIGENCIA=ROUND(Intereses,2)
			WHERE ID=vEmbargos.IDEXPE;

		End if;

	End LOOP;

END;
/


/* *********************************************************************** */
--
-- APLICAR IMPORTES NEGATIVOS DE UNA ENTIDAD A UNA FECHA DE DILIGENCIA
--
--	Modificado: 14/10/2003. Agustín León Robles.
--    Se quita la fecha de diligencia en expedientes para que pueda generar intereses de demora, por si se 
--    demora mucho en el tiempo la proxima generacion de una nueva diligencia
/*DELPHI*/
CREATE OR REPLACE PROCEDURE APLICAR_CUENTAS_NEGATIVAS
(
        xZONA 		IN		char,
        xLote 		IN		char,
        xEntidad 	IN		char,
        xOficina 	IN		char,
        xFECHA 		IN		DATE,
		xIDDili		IN		INT)

AS

	xDescri 	varchar(150);
	xPendiente 	float;
	SiHay 		integer;
	xPuedo		char(1);

	CURSOR EMBARGO_BORRA IS
	SELECT IDEXPE,oficina,dc,cuenta,ID
	from cuentas_lotes where ZONA=xZONA
				and Lote=xLote and Entidad=xEntidad
				and F_DILIGENCIA=xFECHA and IMPORTE_RETENIDO = 0;


BEGIN


	FOR v_Borra IN EMBARGO_BORRA LOOP

		-- Si la aplicación de negativos es para una oficina
		-- comprobamos que la oficina del cursor sea la misma que estamos aplicando
		-- Si oficina='XXXX' lo estamos haciendo por entidad, luego participan todas sus oficinas

		IF xOficina='XXXX' OR xOficina=v_Borra.Oficina THEN
	
			xDescri:= 'Embargo negativo lote '|| xLote ||': '|| '-' ||
						xEntidad || '-' || v_Borra.Oficina || '-' ||v_Borra.DC || '-' || v_Borra.Cuenta;
 
			PkSeguimiento.AnotaTramiteNegativo(v_Borra.IDEXPE,xDescri,'1',SYSDATE);

     
			-- Desmarcamos los valores que habiamos marcado en la diligencia
			Update Valores set ID_DILIG_ECC=NULL where Expediente=v_Borra.IDExpe 
					AND ID_DILIG_ECC=xIDDili
					AND F_INGRESO IS NULL 
					AND FECHA_DE_BAJA IS NULL
					AND F_SUSPENSION IS NULL;

			-- Borrar la cuenta de la tabla de cuentas embargadas 
			delete from cuentas_lotes where ID=v_Borra.ID;

			-- comprobar si es un embargo total, en caso contrario 
			-- Comprobar que haya un embargo total previo
			PkIngresos.Get_PendienteRetenido(v_Borra.IDEXPE, xPendiente);

			if xPendiente > 0 then

				-- comprobar que no tenga una diligencia anterior sin la llegada de los importes retenidos 

				select count(*) into SiHay from cuentas_lotes
				where Lote=xLote and IDExpe=v_Borra.IDExpe and DILIGENCIA='S' and importe_retenido=0;

				if (SiHay=0) then

					-- no hay impedimento para realizar una nueva diligencia 
					UPDATE EMBARGOS_CUENTAS SET PUEDO_DILIGENCIA='S',HUBO_CUENTAS='S'
					WHERE IDExpe=v_Borra.IDExpe;

				else
				
					UPDATE EMBARGOS_CUENTAS SET PUEDO_DILIGENCIA='N',HUBO_CUENTAS='S'
					WHERE IDExpe=v_Borra.IDExpe;
					
				END IF;
				
			else
					UPDATE EMBARGOS_CUENTAS SET PUEDO_DILIGENCIA='N',HUBO_CUENTAS='S'
					WHERE IDExpe=v_Borra.IDExpe;

			END IF;

			
			--Se quita la fecha de diligencia en expedientes para que pueda generar intereses de demora, por si se 
			--demora mucho en el tiempo la proxima generacion de una nueva diligencia
			select PUEDO_DILIGENCIA into xPuedo from Embargos_Cuentas where IDExpe=v_Borra.IDExpe;
			
			if xPuedo='S' then
			
				update Expedientes set fecha_dili_cuentas=null where ID=v_Borra.IDExpe;
			
			end if;			
			
		End IF;

	End LOOP; 

END;
/

/*****************************************************************************************/
-- Elimina un lote. Antes comprueba que no haya ningun expediente con embargos.
/*DELPHI*/
/*****************************************************************************************/

CREATE OR REPLACE PROCEDURE BORRAR_LOTE
(
	xLOTE 	IN	CHAR,
	xZONA		IN	CHAR,
	xERROR	OUT	INTEGER)

AS

xCONT  INTEGER;

BEGIN


   SELECT COUNT(*) INTO xCONT FROM EMBARGOS_CUENTAS WHERE LOTE=xLOTE AND ZONA=xZONA;

   IF xCONT>0 THEN
      xERROR:=1;
      RETURN;
   END IF;

   xERROR:=0;

   DELETE FROM HEAD_LOTES_CUENTAS WHERE LOTE=xLOTE AND ZONA=xZONA;

END;
/
/*****************************************************************************************/
-- CIERRA UN LOTE. 
-- Pasa a los expedientes que no han sufrido embargo al siguiente trámite de embargo.
/*DELPHI*/
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE CERRARLOTECUENTAS(
	xLote 	IN	CHAR,
      xZONA		IN	CHAR,
	xERROR	OUT	INTEGER)

AS

xCuantos 		integer;
xOtro  		CHAR(1);

CURSOR C_EMBARGOS_CC IS
   SELECT HUBO_CUENTAS,IDEXPE FROM Embargos_Cuentas
   where ZONA=xZONA 
	AND Lote=xLote 
      And Importe_Embargado=0 
	and ALGUN_EMBARGO = 'N';


BEGIN

   xCuantos:=0;

   /* comprobar que todos los embargos están aplicados Hecho='S' */

   select count(*) into xCuantos 
   from cuentas_lotes where ZONA=xZONA AND LOTE=xLote and Hecho='N';

   IF (xCuantos > 0) THEN
      xERROR:=1;
      RETURN;
   END IF;

   xERROR:=0;

/* a los que no se les pudo embargar nada pasarlos directamente al siguiente EMBARGO sin más. */

   FOR v_Embargo IN C_EMBARGOS_CC LOOP

      IF (v_Embargo.HUBO_CUENTAS='N') THEN
	    PkSeguimiento.AnotaTramiteNegativo(v_Embargo.IDEXPE,'No se encontró cuenta corriente','1',sysdate);
	END IF;

    update Expedientes set Embargo_1='0', Embargo_3=DECODE(EMBARGO_3,'0','P',EMBARGO_3),
    where ID = v_Embargo.IDEXPE;
	
   END LOOP;


   /* BORRAR EL LOTE */
   DELETE FROM HEAD_LOTES_CUENTAS WHERE LOTE=xLOTE AND ZONA=xZONA;

   /* borrar los expedientes de embargos cuentas */
   /* Borrar las cuentas */
   /* BORRAR LA COPIA DE LAS CUENTAS */
   /* BORRAR LAS DILIGENCIAS */
   /* TODO ESTO SE PRODUCE CON ON DELETE CASCADE*/

end;
/

/* ************************************************************************************ */
-- Añade cuentas al lote, desde soporte magnetico o bien manualmente
--
-- Modificado: 6-6-2002. Lucas Fernández Pérez. Si una cuenta ya estaba en el lote, no
-- insertaba en cuentas_lotes la cuenta para un nuevo deudor.Ahora si la insertará.
--
-- Modificado: 25/11/2003. Lucas Fernández Pérez. Si se hacía la Fase 2 desde otro lote,
--	grababa las cuenta con el lote equivocado, y no se podia hacer diligencia. Ahora graba
--	la cuenta si el lote corresponde con el lote en el que está el expediente.
--
-- Modificado: 29/06/2004. Agustín León Robles. Se protege el select sobre la tabla de expedientes
--
/*DELPHI*/
/* ************************************************************************************ */
CREATE OR REPLACE PROCEDURE ADD_CUENTAS_LOTES(
      xEntidad 		IN	char,
      xOficina 		IN	char,
      xDC 			IN	char,
      xCuenta 		IN	char,
      xClaveSeguridad 	IN	char,
      xLOTE 		IN	CHAR,
      xIDEXPE 		IN	INTEGER)
AS

   xNIF char(10);
   xZONA CHAR(2);
   xEXPE CHAR(10);
   xCUANTOS INTEGER DEFAULT 0;

BEGIN


	begin
   	SELECT EXPEDIENTE,DEUDOR INTO xEXPE,xNIF FROM EXPEDIENTES WHERE ID=xIDEXPE;
   exception
   	when no_data_found then
   		return;
   end;

   --se coge la zona del usuario no la del expediente, por si el lote lo hubiera creado
   --los servicios centrales
   SELECT ZONA INTO xZona FROM usuarios where usuario=user;

   -- COMPROBAR SI ES UNA OFICINA DE NUESTRO AMBITO DE ACTUACION
   SELECT COUNT(*) INTO xCUANTOS FROM SUCURSALES WHERE ENTIDAD=xENTIDAD AND OFICINA=xOFICINA;

   --Cuenta de fuera de nuestro ambito de actuación
   IF xCUANTOS=0 THEN   
      RETURN;
   END IF;

   update cuentas_corrientes set clave_seguridad=xClaveSeguridad
   where NIF=xNIF 
	AND ENTIDAD=xENTIDAD 
	AND OFICINA=xOFICINA
      AND DC=xDC 
	AND CUENTA=xCUENTA;

   IF SQL%NOTFOUND THEN

     /* no lo encuentra, lo damos de alta */

     Insert Into cuentas_corrientes
       (Nif,Entidad,Oficina,dc,Cuenta,CLAVE_SEGURIDAD)
     values
       (xNIF,xEntidad,xOficina,xDC,xCuenta,xClaveSeguridad);
   END IF;

     -- Puede haber varios deudores con el mismo numero de cuenta. Por eso se añade al update
     -- la condicion por nif, porque si no la tiene el update da como SQL%FOUND y no inserta
     -- en cuentas_lotes la cuenta del deudor (porque hay otros deudores con esa cuenta)
     -- Actualizar la clave de seguridad
     UPDATE CUENTAS_LOTES SET clave_seguridad=xClaveSeguridad
 	 WHERE ENTIDAD=xENTIDAD 
		and OFICINA=xOFICINA
            and DC=xDC 
		and CUENTA=xCUENTA
		and NIF=xNIF
		and LOTE=xLOTE; 

     if SQL%NOTFOUND then
	 --hay que comprobar que este en el embargo, puede ocurrir que lo hayamos cambiado
	 --de prelacion, entonces solo lo introduciriamos en cuentas_corrientes. Además,
	 --el expediente debe estar en el mismo lote que el parámetro de entrada.
	 select count(*) into xCuantos from embargos_cuentas 
	 	where IDEXPE=xIDEXPE and LOTE=xLOTE;
	 if xCuantos>0 then
          INSERT INTO CUENTAS_LOTES
             (LOTE, IDEXPE, NIF, EXPEDIENTE, ZONA,
             ENTIDAD, OFICINA, DC, CUENTA, CLAVE_SEGURIDAD)
          VALUES
             (xLOTE, xIDEXPE, xNIF, xEXPE, xZONA,
             xENTIDAD, xOFICINA, xDC, xCUENTA, xClaveSEGURIDAD);
	 end if;
     end if;


END;
/
/* ********************************************************************************* */
-- Devuelve el estado de una cuenta de CUENTAS_LOTES
-- 1 -> Peticion de información
-- 2 -> Diligencia de embargo emitida al banco
-- 3 -> Retencion de importes
-- 4 -> Aplicada la retención bancaria
/*BASE*/
/* ********************************************************************************* */
CREATE OR REPLACE FUNCTION FASE_TRAMITECUENTAS
(xIDCuentaLote IN INTEGER)
RETURN INT

AS

xIMPORTE_RETENIDO float;
xFECHA_RETENCION date;
xHECHO char(1);
xDILIGENCIA char(1);
xF_DILIGENCIA date;

BEGIN

    begin
	SELECT IMPORTE_RETENIDO, FECHA_RETENCION, HECHO, DILIGENCIA, F_DILIGENCIA
	INTO xIMPORTE_RETENIDO, xFECHA_RETENCION, xHECHO, xDILIGENCIA, xF_DILIGENCIA
	FROM CUENTAS_LOTES
	WHERE ID=xIDCuentaLote;
	
	exception
   	  when no_data_found then
           RETURN 0; --NO HAY CUENTA
    end;

    --Aplicada la retención bancaria
    IF xHECHO='S' THEN
       RETURN 4;
    END IF;


    IF xIMPORTE_RETENIDO > 0 THEN
       IF (TO_CHAR(SYSDATE,'DDD') - TO_CHAR(xFECHA_RETENCION,'DDD')) < 20 THEN
          RETURN 3; --Retencion de importes
       ELSE
          RETURN 4;
       END IF;
    END IF;

    --Diligencia de embargo emitida al banco
    IF xF_DILIGENCIA IS NOT NULL THEN
       RETURN 2;
    END IF;

    --Peticion de información
    RETURN 1;

END;
/

/* ********************************************************************************* */
-- QUITAR UN EXPEDIENTE DEL LOTE 
-- Borra el expediente de la tabla EMBARGOS_CUENTAS
/*BASE*/
/* ********************************************************************************* */
CREATE OR REPLACE PROCEDURE QUITO_EXPE_LOTE(xIDEXPE IN INTEGER)
AS
BEGIN
	--a traves de la constraint CULOTEEMBCU de la tabla cuentas_lotes, cuando se borra en
	--embargos_cuentas borra automaticamente en la tabla de cuentas_lotes
	DELETE FROM EMBARGOS_CUENTAS WHERE IDEXPE=xIDEXPE;
END;
/

/*****************************************************************************************/
-- Pone al expediente en estado PENDIENTE y lo borra de la tabla EMBARGOS_CUENTAS
/*DELPHI*/
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE ELIMINA_EXPE_CUENTAS
(xIdExpe IN integer)
AS

BEGIN

   -- Lo pone en estado pendiente
   update Expedientes set EMBARGO_1='P',F_EMBARGO_CUENTAS=SYSDATE,FECHA_DILI_CUENTAS=NULL	 
	 where id=xIDExpe;
	
   QUITO_EXPE_LOTE(xIdExpe);

END;
/
/*****************************************************************************************
Acción: Borra un levantamiento sobre un expediente de la tabla NEXT_LEVANTA_CUENTAS
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Antes se borraba todo el levantamiento 
			  del expediente; ahora puede haber más de un levantamiento por exp, y se
			  borran de forma individual.
DELPHI
*****************************************************************************************/

CREATE OR REPLACE PROCEDURE DEL_LEVANTA_CUENTAS(
	xID IN INT)
AS 
BEGIN 
   delete from next_levanta_cuentas where ID=xID; 
END;
/

/* ******************************************************************************** */

/* EL BLOQUE DE LOS DOS PROXIMOS PROCEDIMIENTOS SON PARA LA GESTIÓN DE LA FICHA DE
   CONTRIBUYENTES*/

/* ******************************************************************************** */
/*PERTENECE AL BLOQUE GEST_CUENTAS*/
-- Inserta en CUENTAS_LOTES los embargos que hay sobre una cuenta para un deudor 
/* ******************************************************************************** */
CREATE OR REPLACE PROCEDURE INSERT_CUENTAS_LOTES(	
          xNIF            IN CHAR,
          xEntidad        IN CHAR,
          xOficina        IN CHAR,
          xDC             IN CHAR,
          xCuenta         IN CHAR,
          xCLAVESEGURIDAD IN CHAR )
 
AS
 
CURSOR cEMBARGOSCu IS
SELECT IDEXPE,LOTE,EXPEDIENTE,ZONA
   FROM EMBARGOS_CUENTAS
   WHERE NIF=xNIF;

BEGIN
 
/*CON UN CURSOR PUES EN EL CASO DE LOS ORGANISMOS UN DEUDOR PUEDE ESTAR EN MAS DE
  UN PROCESO DE EMBARGO DE CUENTAS. PODRIA ESTAR SIENDO EMBARGADO POR UNO O VARIOS 
  MUNICIPIOS DIFERENTES Y POR OTROS ENTES COMO LA JUNTA DE ANDALUCIA, ETC.*/

   FOR vEMBARGOSCu IN cEMBARGOSCu LOOP 

     INSERT INTO CUENTAS_LOTES
      (LOTE,IDEXPE,EXPEDIENTE,ZONA,NIF,ENTIDAD,OFICINA,DC,CUENTA,CLAVE_SEGURIDAD)
     VALUES
      (vEMBARGOSCu.LOTE,vEMBARGOSCu.IDEXPE,vEMBARGOSCu.EXPEDIENTE,
      vEMBARGOSCu.ZONA,xNIF,xENTIDAD,xOFICINA,xDC,xCUENTA,xClaveSEGURIDAD);

   END LOOP;


END;
/
/* ************************************************************ */
/*DELPHI*/
/* FORMULARIO DEL MANTENIMIENTO DE CONTRIBUYENTES */
-- Inserta en CUENTAS_LOTES los embargos que hay sobre una cuenta para un deudor.
-- Si la cuenta no existe, la crea. 

CREATE OR REPLACE PROCEDURE GEST_CUENTAS(
            xID             IN INTEGER,
            xNIF            IN CHAR,
            xentidad        IN CHAR,
            xoficina        IN CHAR,
            xdc             IN CHAR,
            xcuenta         IN CHAR,
            xClaveSeguridad IN CHAR)
      
AS    
BEGIN
     

   IF (xID=0) THEN       

      INSERT INTO cuentas_corrientes
        (Nif,Entidad,Oficina,dc,Cuenta,CLAVE_SEGURIDAD)
      VALUES
        (xNIF,xEntidad,xOficina,xDC,xCuenta,xClaveSeguridad);

      INSERT_CUENTAS_LOTES(xNIF,xENTIDAD,xOFICINA,xDC,xCUENTA,xClaveSEGURIDAD);

   ELSE
     
      /* EL TRIGGER DE BEFORE UPDATE SE ENCARGA DE ACTUALIZAR EN CUENTAS_LOTES */    
   
      UPDATE cuentas_corrientes SET ENTIDAD=xEntidad,
				            OFICINA=xOficina,
     				            DC=xDC,
     				            CUENTA=xCuenta,
     				            CLAVE_SEGURIDAD=xClaveSeguridad
      WHERE ID=xID;
   
   END IF;
     
END;
/
/*****************************************************************************************/
-- GRABAR LAS RETENCIONES BANCARIAS
--   xIDCuenta : el id de cuentas lotes
--   xImpoRete : el importe retenido
--   xFecha    : fecha de retencion
--   xIdExpe   : el Id de expedientes 
-- Se anota la operación en el seguimiento.
-- Modificado : 07/11/2002 Lucas Fernández Pérez. Consultaba if Resto>1, no if Resto>0
/*BASE*/
/*****************************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_RETENCIONES_BANCARIAS(
	xIDCuenta	IN	Integer,
      xImpoRete 	IN	Float,
      xFecha 	IN	DATE,
      xIdExpe 	IN	Integer)

AS

xDeuda 	float default 0;
xResto 	float default 0;
SiHay 	integer default 0;
xTEXTO 	VARCHAR(150);
xENTIDAD 	CHAR(4);
xOFICINA 	CHAR(4);
xDC 		CHAR(2);
xCUENTA 	CHAR(10);
xNIF 		CHAR(10);


BEGIN

   /* procedimiento que nos devuelve la diferencia
      entre el pendiente y lo anteriormente retenido */

   PkIngresos.Get_PendienteRetenido(xIdExpe, xDeuda);

   /*Averiguar el pendiente despues de esta última retención*/

   xResto:= xDeuda - xImpoRete;

   update CUENTAS_LOTES set IMPORTE_RETENIDO=ROUND(xImpoRete,2),
                          FECHA_RETENCION=xFecha
   WHERE ID=xIDCuenta
   RETURN ENTIDAD,OFICINA,DC,CUENTA,NIF
   INTO xENTIDAD,xOFICINA,xDC,xCUENTA,xNIF;

   /* comprobar si es un embargo total */

   if xResto > 0 then --Embargo parcial

      /* comprobar que no tenga una diligencia anterior
         sin la llegada de los importes retenidos */

      select count(*) into SiHay from cuentas_lotes
      where IdExpe=xIdExpe 
	  and DILIGENCIA='S' 
	  and importe_retenido=0;

      if (SiHay=0) then

         /* no hay impedimento para realizar una nueva diligencia */

         UPDATE EMBARGOS_CUENTAS SET PUEDO_DILIGENCIA='S'
         WHERE IdExpe=xIdExpe;

      else
         UPDATE EMBARGOS_CUENTAS SET PUEDO_DILIGENCIA='N'
         WHERE IdExpe=xIdExpe;
      end if;

   else

      /* Embargo Total */

      UPDATE EMBARGOS_CUENTAS SET PUEDO_DILIGENCIA='N'
      WHERE IdExpe=xIdExpe;

   end if;

   /* ANOTARLO EN EL SEGUIMIENTO */

   xTexto:='Se retiene ccc: ' || xEntidad || '-'||
           xOficina || '-' || xDC || '-' ||
           xCuenta || '-IMPORTE: ' || ROUND(xIMPORete, 2);

   PkSeguimiento.NotaInformativa(xIDExpe,xTexto,xIDCuenta);

END;
/

/*****************************************************************************************/
-- GRABAR LAS RETENCIONES BANCARIAS
--   xIdCuenta : el id de cuentas lotes
--   xImpo: el importe retenido
--   xFecha: fecha de retencion
--   xIdExpe: el id de expedientes 
-- Se utiliza tanto para crear una nueva retención, como para modificación o anulación 
-- de la misma.

--
-- Modificación: 29-01-2003. Agustín León Robles. Cuando el importe retenido es superior
--					al pendiente del expediente se inserta en la tabla retenciones_indebidas
--
-- Modificado: 05-05-2003. Lucas Fernández Pérez. Ajuste para el correcto tratamiento de
--	la información en la tabla de retenciones_indebidas. Se borran casos antiguos.
--
-- Modificación: 22-07-2003. Agustín León Robles. Ya no se borra en el seguimiento, se hacen anotaciones nuevas.
--
/*DELPHI*/
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE LEER_RETENCIONES_BANCARIAS(
				xIDCuenta 	IN	Integer,
				xImpo 	IN	Float,
				xFecha 	IN	DATE,
				xIdExpe 	IN	Integer)
AS

xCuanto 		Float default 0;
xNIF 			CHAR(10);
xPendiente 		float DEFAULT 0;
xResto		float default 0;
xEntidad		char(4);
xOficina		char(4);
xDC			char(2);
xCuenta		char(10);
xLote 		char(10);
xF_Dili		date;
xTEXTO 		VARCHAR2(150);
BEGIN

	-- DE xCuanto y xImpo deducimos si es una nueva retención, modificación o anulación 
	select IMPORTE_RETENIDO,NIF,ENTIDAD,OFICINA,DC,CUENTA,LOTE,F_DILIGENCIA 
   			into xCuanto,xNIF,xEntidad,xOficina,xDC,xCuenta,xLote,xF_Dili
	from cuentas_lotes where ID=xIDCuenta;


	-- procedimiento que nos devuelve la diferencia entre el pendiente y lo retenido 
	PkIngresos.Get_PendienteRetenido(xIDExpe, xPendiente);


	--en caso de modificación como xPendiente es el importe del pendiente menos lo ya
	--retenido habra que restar lo anteriormente retenido
	xPendiente:=xPendiente+xCuanto;

	xResto:=xPendiente-xImpo;
   
	-- Elimino alguna posible retención indebida que tuviese el expediente
	DELETE FROM RETENCIONES_INDEBIDAS WHERE IDEXPE=xIDExpe AND LOTE=xLote AND
			ENTIDAD||OFICINA||DC||CUENTA=xEntidad||xOficina||xDC||xCuenta AND	F_DILIGENCIA=xF_Dili;

	if xResto < 0 then
		--RETENCION INDEBIDA
		INSERT INTO RETENCIONES_INDEBIDAS(ID,IDEXPE,F_DILIGENCIA,F_RETENCION,
   					IMPORTE_DISCO,PENDIENTE_EXPE,NIF,LOTE,ENTIDAD,OFICINA,DC,CUENTA)
		VALUES (G_RETEN_INDEBIDAS.NextVal,xIdExpe,xF_Dili,xFecha,
					xImpo,xPendiente,xNIF,xLote,xEntidad,xOficina,xDC,xCuenta);
		
		return;
	
	end if;

	-- INTRODUCIR UNA RETENCION 
	IF xImpo > 0 And xCuanto = 0 then

		PUT_RETENCIONES_BANCARIAS(xIDCuenta, xImpo, xFecha, xIDExpe);

		-- ENVIAR UNA NOTIFICACION 
		Add_Notificaciones_expe(xIDExpe, '101', xIDCuenta, xNIF, 'QQ');

		--no queda mas remedio que hacer aqui un update en notificaciones, 
		--ya que add_notificaciones_expe se utiliza mas veces, estos datos sirven para las 
		--publicaciones en el BOP de expedientes
		UPDATE NOTIFICACIONES SET LOTE=xLote,ENTIDAD=xEntidad	WHERE EXPEDIENTE=xIDExpe AND ID_EMBARGOS=xIDCuenta;

	END IF;

	-- MODIFICAR UNA RETENCION 
	IF xImpo > 0 And xCuanto > 0 then

		-- Por que es una modificacion solo se borra el apunte del importe retenido, el de la
		-- notificacion no se borra

		xTexto:='Se anula por modificación del importe retenido ccc: ' || xEntidad || '-'|| xOficina || '-' || xDC || '-' ||
				xCuenta || '-IMPORTE retenido anterior: ' || xCuanto;

		PkSeguimiento.NotaInformativa(xIDExpe,xTexto,xIDCuenta);

		--poner las retenciones a cero en una modificación
		UPDATE CUENTAS_LOTES SET IMPORTE_RETENIDO=0 WHERE ID=xIDCuenta;

		PUT_RETENCIONES_BANCARIAS(xIDCuenta, xImpo, xFecha, xIDExpe);

	END IF;


	-- BORRAR UNA RETENCION 
	IF xImpo = 0 And xCuanto > 0 then

		update CUENTAS_LOTES set IMPORTE_RETENIDO=0,FECHA_RETENCION=NULL where ID=xIDCuenta;
 
		UPDATE EMBARGOS_CUENTAS SET PUEDO_DILIGENCIA='N' WHERE IdExpe=xIdExpe;

		-- BORRAR LA NOTIFICACION 
		DELETE FROM NOTIFICACIONES WHERE EXPEDIENTE=xIDExpe AND ID_EMBARGOS=xIDCuenta;


		xTexto:='Se anula importe retenido ccc: ' || xEntidad || '-'|| xOficina || '-' || xDC || '-' ||
				xCuenta || '-IMPORTE anulado: ' || xCuanto;

		PkSeguimiento.NotaInformativa(xIDExpe,xTexto,xIDCuenta);		

	END IF;

END;
/


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
-- Modificacion: 14/04/2005. Lucas Fernández Pérez. 
-- Nuevo parámetro xFECHA con la fecha de ingreso en la aplicación de la retención. Se pone esa fecha sólo en
--  la tabla INGRESOS, dejando en mov_cuentas ( y en el seguimiento y al ingresar el expediente) como fecha Sysdate.
--  Antes solo estaba xFecha, con la fecha de ingreso en banco. Ahora xFecha es la fecha de ingreso en la aplicación
--   y xFechaBanco es la fecha que se pasaba antes, la de ingreso en banco.
--
CREATE OR REPLACE PROCEDURE APLICAR_IMPORTE_RETENIDOS
(
	xIDCuenta	IN integer,
    xIDExpe 	IN INT,
    xRETENIDO 	IN FLOAT,
    xFECHA	 	IN DATE,
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

/* ********************************************************************************** */
-- creamos una tabla temporal para pasar la información que se ha de imprimir al 
-- hacer petición de información de lote colectivo 
/*DELPHI*/
/* ********************************************************************************** */

CREATE OR REPLACE PROCEDURE PASAR_INFO_DBASE( 
			xNUMLOTE	IN	CHAR)
AS
   xAYUNTAMIENTO	VARCHAR(50);
   xCIF		CHAR(10);
   xDIRE		VARCHAR(100);
   xNOMBRE  	VARCHAR(80);
   xPOBLA   	VARCHAR(50);
   xPROVI   	VARCHAR(50);
   xRESPONSABLE   VARCHAR(50);
   
   CURSOR c_bancos IS SELECT NOMBRE FROM BANCOS;

BEGIN

   DELETE FROM INFO_DBASE WHERE USUARIO=UID;

   SELECT AYUNTAMIENTO,CIF,DIRECCION,NOMBRE,POBLACION,PROVINCIA,RESPONSABLE
   INTO xAYUNTAMIENTO,xCIF,xDIRE,xNOMBRE,xPOBLA,xPROVI,xRESPONSABLE
   FROM ZONAS
   WHERE ZONA IN (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   FOR v_bancos IN c_bancos 
   LOOP
      INSERT INTO INFO_DBASE(AYUNTAMIENTO,CIF,DIRECCION,NOMBRE,POBLACION,PROVINCIA,
		RESPONSABLE,BANCO,NUMLOTE)
	VALUES (xAYUNTAMIENTO,xCIF,xDIRE,xNOMBRE,xPOBLA,xPROVI,xRESPONSABLE,
		v_bancos.NOMBRE,xNUMLOTE);	
   END LOOP;

END;
/
			
