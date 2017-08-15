-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/***************************************************************************************/
-- Añade un salario a una persona. Asocia a la persona (NIF) con una empresa (CIF).
-- Indica el Expediente en el que se encuentra esa persona.
-- Si una persona no tiene salario, no se le podrá realizar un EMBARGO de SALARIOS
-- Además, si el expediente está en un lote de salarios, indica en el estado que tiene trabajo.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ADD_SALARIOS_LOTES(
      xIDEXPE       IN INTEGER,
      xNIF          IN CHAR,
      xSITUACION    IN CHAR,
      xCIF_EMPRESA  IN CHAR)

AS
xNADA         INTEGER;
xEsta_Embargo CHAR(1);
BEGIN

   INSERT INTO SALARIOS (IDEXPE,NIF,SITUACION,CIF_EMPRESA)
   VALUES (xIDEXPE,xNIF,xSITUACION,xCIF_EMPRESA);

   -- Indico en el expediente que tiene trabajo. (estado = 'R')
   UPDATE EXPEDIENTES SET E_LOTE3='R' WHERE ID=xIDEXPE
	returning EMBARGO_3 INTO xEsta_Embargo;  

   -- Al ponerle un trabajo, si esta pendiente en embargo de salarios lo paso a estado abierto.
   IF xEsta_Embargo='P' THEN
   	 PUT_UnExpeEnLoteSalarios(xIDExpe,xNADA) ;
   END IF;

   -- Al ponerle un trabajo, si esta abierto en embargo de salarios pongo Notificado='N',
   -- porque ahora no todos los trabajos del embargo estan notificados.
   IF xEsta_Embargo='O' THEN
   	 UPDATE EMBARGOS_SALARIOS SET NOTIFICADO='N' WHERE IDEXPE=xIDExpe;
   END IF;

END;
/

/***************************************************************************************/
-- Elimina un salario de una persona. 
-- Además, si la persona se queda sin ningun salario y el expediente tiene un lote,
-- se actualiza el estado del lote para indicar que dicha persona no tiene trabajo.
/***************************************************************************************/
/*DELPHI*/ 
CREATE OR REPLACE PROCEDURE DEL_SALARIOS_LOTES
	(xIDSalario       IN 	INTEGER,
	 xNIF			IN	CHAR)

AS
xIDExpe		     INTEGER;
xCont			 INTEGER;
xEmitida_Empresa CHAR(1);
xCIF             CHAR(10);
BEGIN

	--comprobar si el expediente está en trámite de salarios
    begin
		select ID into xIDExpe
		from expedientes where deudor=xNIF
      	and f_ingreso is null and f_anulacion is null and EMBARGO_3 <> '0';
	exception
		when no_data_found then
			DELETE FROM SALARIOS WHERE ID=xIDSalario; -- No está en salarios, se borra el salario sin más
			return;
	end;

    -- Aquí llegados, el expediente estará en estados 'P', 'O' , ó 'L'
    
	--comprobamos el numero de trabajos, si tiene mas de 1 trabajo puedo borrarlo, 
	--tenga o no diligencia
	SELECT COUNT(*) INTO xCont FROM SALARIOS WHERE IDEXPE=xIDExpe;
   
	
	IF xCont>1 THEN 
		DELETE FROM SALARIOS WHERE ID=xIDSalario;
	ELSE
		
		begin
			select emitida_empresa into xEmitida_Empresa -- Busca si está emitida la notificación a la empresa
				from embargos_salarios where idexpe=xIdExpe;
		exception
			when no_data_found then
				xEmitida_Empresa:='P'; -- el expediente está en estado 3P
		end;
		
		if xEmitida_Empresa='N' then -- Si no está emitida la notificación a la empresa: el expediente está en '3''0' 
			DELETE FROM SALARIOS WHERE ID=xIDSalario; -- y pasa a '3P'
            UPDATE VALORES SET ID_SALARIOS=NULL WHERE EXPEDIENTE=xIDExpe;
			delete from embargos_salarios where idexpe=xIdExpe;			
			update expedientes set EMBARGO_3='P' where id=xIdExpe;
			PkSeguimiento.NotaInformativa(xIDExpe,'Pasa al Pendiente de Salarios, porque no tiene trabajo');
			
		elsif xEmitida_Empresa='P' then -- El expediente esta en '3P'
			DELETE FROM SALARIOS WHERE ID=xIDSalario;
			update expedientes set E_LOTE3=DECODE(LOTE_3,NULL,'N','S') where id=xIdExpe;
			
		else -- El expediente esta en '3''O' con notificación emitida, o bien en '3L': No puede borrarse el salario
		    SELECT CIF_EMPRESA INTO xCIF FROM SALARIOS WHERE ID=xIDSalario;
			PkSeguimiento.NotaInformativa(xIDExpe,'No se puede eliminar el salario de la empresa '||xCIF
													||' porque tiene notificación emitida');
		end if;	

	end if;

END;
/

/***************************************************************************************/
-- Parte de un expediente en trámite de embargo de salarios y estado PENDIENTE.
-- Genera un embargo de salarios si existe un salario para ese expediente, y 
-- pasa al expediente al estado de ABIERTO en ese trámite. 
-- Anota la operacion en el seguimiento del expediente.
--  xSINSALA 1: sin salario; 0: con salario  2: No está pendiente
/***************************************************************************************/
/*DELPHI e INTERNO*/
CREATE OR REPLACE PROCEDURE PUT_UnExpeEnLoteSalarios(
		xIDExpe IN INTEGER,
		xSINSALA OUT INTEGER) 

AS
xID        INTEGER;
xPENDIENTE FLOAT DEFAULT 0;
xNIF       CHAR(10);
xZONA      CHAR(2);
xEXPE      CHAR(10);
xCONTADOR  INTEGER;
xNLote     CHAR(8);
xCadena    CHAR(150);

BEGIN

   xSinSala:=0;

   /* comprobamos si el expediente tiene un trabajo asociado. Si no es así no podemos
     añadirlo al embargo. Se quedará en el pendiente de salarios.
   */

   SELECT COUNT(NIF) INTO xCONTADOR FROM SALARIOS
   WHERE IDEXPE=xIDEXPE;

   IF xCONTADOR=0 THEN
	xSinSala:=1;  -- se saldrá del procedimiento al no poseer un salario 
	Return;
   END IF;

   -- está sobre una vista que tiene las condiciones de filtro de pendiente */
   begin
     SELECT PENDIENTE INTO xPENDIENTE
     FROM PendiValoresExpe
   	 WHERE EXPEDIENTE=xIDExpe;
   exception 
 	 when no_data_found then
	   xSinSala:=2;
	   return;
   end;

   if (xPendiente > 0) then
      
	SELECT DEUDOR,ZONA,EXPEDIENTE,LOTE_3 Into xNIF,xZONA,xEXPE,xNLote
   	FROM EXPEDIENTES
   	WHERE ID=xIDExpe;

    INSERT INTO EMBARGOS_Salarios
      (IDEXPE,DEUDA_TOTAL,NIF,ZONA,EXPEDIENTE)
    values
      (xIDExpe,xPendiente, xNIF,xZONA,xEXPE)
	RETURNING ID INTO xID;

    UPDATE SALARIOS SET IDSALARIO=xID 
    WHERE NIF=xNIF AND IDEXPE=xIDEXPE;

	IF xNLote IS NULL THEN
	   xCadena:='Comienza proceso embargo de Salarios. No esta en ningun lote';
	ELSE
	   xCadena:='Comienza proceso embargo de Salarios. Lote Número: '||xNLote;
	END IF;

	pkSeguimiento.NotaInformativa(xIDEXPE,xCadena);

	-- Actualizo el estado del expediente 
    UPDATE EXPEDIENTES SET EMBARGO_3='O'
    WHERE ID=xIDexpe AND EMBARGO_3='P';
    
   end IF;  
   
END;
/

/***************************************************************************************/
-- Los afectados son todos los expedientes en trámite de embargo de salarios y estado PENDIENTE.
-- Expedientes además no ingresados, anulados o suspensos. DE UN LOTE y CON TRABAJO.
-- Genera un embargo de salarios si existe un salario para cada uno de esos expedientes, y 
-- pasa a los expedientes al estado de ABIERTO en ese trámite.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE PORZONASSALARIOS(
		xZONA IN CHAR,
		xNLOTE IN CHAR)

AS

   xSinSala Integer;
   CURSOR EXPE_CUR IS
        SELECT ID
        FROM EXPEDIENTES
        WHERE ZONA=xZONA
              AND EMBARGO_3='P'
              AND F_INGRESO IS NULL
              AND F_ANULACION IS NULL
              AND F_SUSPENSION IS NULL
		  AND LOTE_3=xNLOTE
		  AND E_LOTE3='R';

BEGIN

   FOR v_EXPE IN EXPE_CUR LOOP

      PUT_UnExpeEnLoteSalarios(v_EXPE.ID, xSinSala);
       
   END LOOP;

END;
/

/***************************************************************************************/
-- Elimina un embargo de salarios, dejando el expediente sin tramites.
-- Es similar al procedimiento LEVANTA_SALARIOS, con la diferencia de que no comprueba 
-- si se había emitido la diligencia a la empresa. Borra el embargo sin comprobaciones.
-- ¿Por que puede ocurrir esto? Porque se paga el expediente, cuando la diligencia a la 
-- empresa se había emitido ya. Una vez que se responde a la empresa, ya se puede eliminar
-- el embargo, y es cuando se llama a este procedimiento.También se utiliza para borrar
-- un expediente en estado PENDIENTE.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE BORRA_DILI_LEVANTA(xIDEXPE IN INTEGER)
AS
BEGIN

   UPDATE SALARIOS SET IDSALARIO=NULL WHERE IDEXPE=xIDEXPE;

   UPDATE VALORES SET ID_SALARIOS=NULL WHERE EXPEDIENTE=xIDExpe;

   DELETE FROM EMBARGOS_SALARIOS WHERE IDEXPE=xIDEXPE;

   PKSeguimiento.NotaInformativa(xIDEXPE,'El expediente no tiene trámite de salarios');	

   UPDATE EXPEDIENTES SET EMBARGO_3='0'
   WHERE ID=xIDEXPE;

END;
/

/***************************************************************************************/
-- Elimina el embargo de salarios de un expediente, dejando al expediente en
-- el trámite de embargo de salarios pero en estado PENDIENTE.
-- Este expediente Pendiente podrá pasar a Activo con los procedimientos PORZONASSALARIOS
-- y PUT_UnExpeEnLoteSalarios, o bien a Pendiente de otro trámite (proc.BORRAR_SIN_SALARIO,
-- CAMBIAR_PRELACION_UNO, CAMBIAR_PRELACION_TODOS y CAMBIAR_PRELACION_IMPORTE)
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE Quito_ExpeLoteSalarios(
        xIDExpe IN INTEGER)

AS
xIDSala INTEGER;
BEGIN

   UPDATE SALARIOS SET IDSALARIO=NULL where IDExpe=xIDExpe;

   UPDATE VALORES SET ID_SALARIOS=NULL WHERE EXPEDIENTE=xIDExpe;

   delete from EMBARGOS_SALARIOS where IDExpe=xIDExpe returning ID INTO xIDSala;

   -- Las notificaciones no las elimino, solamente anulo su apunte al embargo.
   UPDATE NOTIFICACIONES SET ID_EMBARGOS=NULL 
   WHERE EXPEDIENTE=xIDEXPE 
	AND ID_EMBARGOS=xIDSala 
	AND TIPO_NOTI LIKE '3%';

   PKSeguimiento.NotaInformativa(xIDEXPE,'Pasa a estado Pendiente de Salarios');	

   update Expedientes set EMBARGO_3='P'
   where ID=xIDExpe;

END;
/

/***************************************************************************************/
-- ----------   SALARIOS PENDIENTES -> INMUEBLES PENDIENTES   --------------------------
/***************************************************************************************/
-- Pasa expedientes con embargo de salarios en estado PENDIENTE al embargo
-- de INMUEBLES en estado PENDIENTE. ¿Cuantos expedientes? Depende de xTodos:
-- xTodos='Z' -> Todos los expedientes de una zona (xZONA) de un lote,(pasa los expedientes 
--                  sobre deudores que no tengan trabajo)
-- xTodos='A' -> Todos los expedientes que no tengan trabajo de un lote.
--
-- xTodos='E' -> Un solo expediente (xIDEXPE).No comprueba si tiene trabajo ni la f_embargo.
-- Anota la operación en el seguimiento del expediente.
/***************************************************************************************/
/*DELPHI e INTERNO*/
CREATE OR REPLACE PROCEDURE BORRAR_SIN_SALARIO(
         xIDEXPE IN INTEGER,
         xZONA   IN CHAR,
         xTODOS  IN CHAR,
	   xNLOTE  IN CHAR)

AS
	
   xTEXT CHAR(150);
   xCONTADOR INTEGER;
   CURSOR CC_ZONA IS
	      SELECT ID FROM EXPEDIENTES
	      WHERE ZONA=xZONA
	            AND EMBARGO_3='P'
			AND LOTE_3=xNLOTE 
			AND E_LOTE3='S';

   CURSOR CC_AYTO IS
	      SELECT ID FROM EXPEDIENTES
	      WHERE EMBARGO_3='P'
			AND LOTE_3=xNLOTE 
			AND E_LOTE3='S';
BEGIN


   IF xNLote is NULL THEN
	xTEXT:='No se encontró sueldo, salario o pensión. No tiene número de lote';
   ELSE
	xTEXT:='No se encontró sueldo, salario o pensión. Número de lote:'||xNLote;
   END IF;


   IF xTODOS='Z' THEN   
	FOR v_ZONA IN CC_ZONA LOOP

	   SELECT COUNT(NIF) INTO xCONTADOR FROM SALARIOS
	   WHERE IDEXPE=v_ZONA.ID;

	   IF xCONTADOR=0 THEN -- No tiene salario, lo paso a embargo de inmuebles
	
	   	PkSeguimiento.AnotaTramiteNegativo(v_ZONA.ID, xText,'3',SYSDATE);

	      UPDATE EXPEDIENTES SET EMBARGO_3='0', 
	      		  EMBARGO_4=DECODE(EMBARGO_4,'0','P',EMBARGO_4),
				  F_EMBARGO_INMUEBLES=DECODE(EMBARGO_4,'0',SYSDATE,F_EMBARGO_INMUEBLES)
	      WHERE ID=v_ZONA.ID;

	   END IF;

      END LOOP;

    ELSIF xTODOS='A' THEN

	FOR v_AYTO IN CC_AYTO LOOP
	
	   SELECT COUNT(NIF) INTO xCONTADOR FROM SALARIOS
	   WHERE IDEXPE=v_AYTO.ID;

	   IF xCONTADOR=0 THEN -- No tiene salario, lo paso a embargo de inmuebles

	   	PkSeguimiento.AnotaTramiteNegativo(v_AYTO.ID, xText,'3',SYSDATE);

	      UPDATE EXPEDIENTES SET EMBARGO_3='0', 
	      		  EMBARGO_4=DECODE(EMBARGO_4,'0','P',EMBARGO_4),
				  F_EMBARGO_INMUEBLES=DECODE(EMBARGO_4,'0',SYSDATE,F_EMBARGO_INMUEBLES)
	      WHERE ID=v_AYTO.ID;

	   END IF;

      END LOOP;

     ELSIF xTODOS='E' THEN   

  	    PkSeguimiento.AnotaTramiteNegativo(xIDEXPE, xText,'3',SYSDATE);

	      UPDATE EXPEDIENTES SET EMBARGO_3='0', 
	      		  EMBARGO_4=DECODE(EMBARGO_4,'0','P',EMBARGO_4),
				  F_EMBARGO_INMUEBLES=DECODE(EMBARGO_4,'0',SYSDATE,F_EMBARGO_INMUEBLES)
          WHERE ID=xIDEXPE
	        AND EMBARGO_3='P';

      END IF;

END;
/

/***************************************************************************************/
-- Realiza la diligencia del embargo de salarios de un expediente ,
-- calculando la deuda total del embargo y anotando la operación en el seguimiento del exped.
/***************************************************************************************/
/*DELPHI e INTERNO*/
CREATE OR REPLACE PROCEDURE DILIGENCIA_SALARIOS
			(xIDEXPE IN INTEGER,
			 xIDSALA IN INTEGER,
			 xFECHA  IN DATE)
AS
   xTEXTO CHAR(150);
   xFECHA_AUX CHAR(10);
   xFDILI DATE;
   xIntereses 	float DEFAULT 0;
   xDeuda_Total 	float DEFAULT 0;
BEGIN

	xFECHA_AUX:=TO_CHAR(xFECHA,'DD/MM/YYYY');

	SELECT F_DILIGENCIA INTO xFDILI FROM EMBARGOS_SALARIOS WHERE ID=xIDSALA;

	IF (xFDILI IS NULL) THEN
		xTexto:='Diligencia embargo salarios con fecha: ' || xFECHA_AUX;        
       
		pkSeguimiento.NotaInformativa(xIDExpe,xTexto);

		CalcDemora_Expe(xIDExpe, xFECHA, 'S','E', xIntereses, xDeuda_Total);

		UPDATE EMBARGOS_SALARIOS SET F_DILIGENCIA=xFECHA,DEUDA_TOTAL=ROUND(xDeuda_Total,2)
		WHERE ID=xIDSALA;

       	UPDATE EXPEDIENTES SET FECHA_DILI_SALARIOS=SYSDATE,
		                    INTERES_DILIGENCIA=ROUND(xIntereses,2)
  	    WHERE ID=xIDEXPE;

	    -- Actualizo los valores que entran en el embargo, apuntando al id del embargo de salarios
        UPDATE VALORES SET ID_SALARIOS=xIDSALA
        WHERE Expediente=xIDExpe
          and F_ingreso is null
          and Fecha_de_baja is null
          and F_suspension is null
          and ID_SALARIOS IS NULL;
          
	END IF;
END;
/

/***************************************************************************************/
-- Realiza las diligencias de todos los expedientes con embargo de salarios de una zona
-- Los embargos a autónomos no se tienen en cuenta, así como los que ya tenian la diligencia.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE DILIGENCIAS_MASIVAS(
     xZONA   IN CHAR,
     xFECHA  IN DATE,
     xLOTE	 IN CHAR)

AS
   CURSOR CSALARIOS IS SELECT DISTINCT E.ID,E.IDEXPE		
			     FROM EMBARGOS_SALARIOS E,SALARIOS S, EXPEDIENTES P 
			     WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=P.ID AND
			     S.NIF<>S.CIF_EMPRESA AND /* no autónomos */
			     F_DILIGENCIA IS NULL AND 
			     E.ZONA=xZONA AND P.LOTE_3=xLOTE;
BEGIN

   FOR v_Sal IN CSALARIOS 
   LOOP
      DILIGENCIA_SALARIOS(v_Sal.IDEXPE,v_Sal.ID,xFECHA);
   END LOOP;   
   
END;
/

/***************************************************************************************/
-- Genera una notificación de embargo de salarios de un expediente. Esta notificación
-- puede ser de tres tipos, segun a quien vaya dirigida. Puede ir dirigida a:
-- 1. Las empresas donde trabaja el asalariado, en condición de notificación.(xQUIEN='E') 
--	En este caso, calcula la deuda del embargo y el interes de demora que se suma al
-- 	expediente.
-- 2. A esas empresas, en condición de REITERACION advertencia de sanción.(xQUIEN='R') 
-- 3. Al propio deudor. (xQUIEN='D') 
-- Solo permite crear una notificación de cada tipo.
/***************************************************************************************/
/*DELPHI e INTERNO*/
CREATE OR REPLACE PROCEDURE NOTIFICA_SALARIOS(
     xIDEXPE IN INTEGER,
     xIDSala IN INTEGER,
     xQUIEN  IN CHAR)

AS
xEMITI CHAR(1);
xNIF   CHAR(10);
   
CURSOR TRABAJOS IS SELECT CIF_EMPRESA FROM SALARIOS WHERE NIF=xNIF;

BEGIN


  IF (xQUIEN='E') THEN

    /* COMPROBAR QUE NO SE HAYA EMITIDO YA LA DILIGENCIA A LA EMPRESA */

    SELECT EMITIDA_EMPRESA,NIF INTO xEMITI,xNIF
    FROM EMBARGOS_SALARIOS
    WHERE ID=xIDSALA;

    IF (xEMITI='N') THEN

      FOR v_trabajo IN TRABAJOS  -- BUSCAR EL CIF DE LA EMPRESA 
	  LOOP

        -- Comprobar que no exista otra notificación
		update NOTIFICACIONES set ID_EMBARGOS=xIDSALA
			where EXPEDIENTE=xIDEXPE
			AND ID_EMBARGOS=xIDSALA
			AND TIPO_NOTI='302'
			AND NIF=v_trabajo.CIF_EMPRESA;

		IF SQL%NOTFOUND THEN -- NOTIFICARLE A LA EMPRESA 
               Add_Notificaciones_expe(xIDExpe, '302', xIDSALA, v_trabajo.CIF_EMPRESA, 'QQ');
		END IF;
	  END LOOP; 

      UPDATE EMBARGOS_SALARIOS SET EMITIDA_EMPRESA='S'
      WHERE ID=xIDSALA AND EMITIDA_EMPRESA='N';
      
    END IF;
    
  END IF;

  /* REITERACION ADVERTENCIA DE SANCION */
  IF (xQUIEN='R') THEN

    SELECT EMITIDA_REITERA,NIF INTO xEMITI,xNIF
    FROM EMBARGOS_SALARIOS
    WHERE ID=xIDSALA;

    IF (xEMITI='N') THEN
        
	  FOR v_trabajo IN TRABAJOS -- BUSCAR EL CIF DE LA EMPRESA 
	  LOOP
		-- Comprobar que no exista otra notificación
		update NOTIFICACIONES set ID_EMBARGOS=xIDSALA
			where EXPEDIENTE=xIDEXPE
			AND ID_EMBARGOS=xIDSALA
			AND TIPO_NOTI='303'
			AND NIF=v_trabajo.CIF_EMPRESA;

		IF SQL%NOTFOUND THEN
               Add_Notificaciones_expe(xIDExpe, '303', xIDSALA, v_trabajo.CIF_EMPRESA, 'QQ');
		END IF;

	  END LOOP;

      UPDATE EMBARGOS_SALARIOS SET EMITIDA_REITERA='S'
      WHERE ID=xIDSALA AND EMITIDA_REITERA='N';

    END IF;
  END IF;

  /* AL DEUDOR */
  IF (xQUIEN='D') THEN

    SELECT EMITIDA_DEUDOR,NIF INTO xEMITI,xNIF
    FROM EMBARGOS_SALARIOS
    WHERE ID=xIDSALA;

    IF (xEMITI='N') THEN

      -- Comprobar que no exista otra notificación
	  update NOTIFICACIONES set ID_EMBARGOS=xIDSALA
		where EXPEDIENTE=xIDEXPE
		AND ID_EMBARGOS=xIDSALA
		AND TIPO_NOTI='304'
		AND NIF=xNIF;

	  IF SQL%NOTFOUND THEN
        Add_Notificaciones_expe (xIDExpe, '304', xIDSALA, xNIF, 'QQ');
	  END IF;

      UPDATE EMBARGOS_SALARIOS SET EMITIDA_DEUDOR='S'
      WHERE ID=xIDSALA AND EMITIDA_DEUDOR='N';
      
    END IF;
    
  END IF;

END;
/


/***************************************************************************************/
-- Introduce un nuevo trabajo de una persona en una empresa. 
-- Si la empresa no existe, la inserta en CONTRIBUYENTES.
-- El nuevo trabajo de esta persona se inserta en SALARIOS.
-- xTIPOREGISTRO indica si la persona tiene o no trabajo (1-> tiene trabajo, 0,2-> no tiene
-- Si la persona tiene un expediente en estado pendiente de embargo de salarios:
-- 1 -> Pasa a abierto de salarios cuando tiene trabajo.
-- 2 -> Pasa a pendiente de inmuebles cuando no tiene trabajo.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE GRABAR_DISCO_SS(
			xTIPOREGISTRO IN 	CHAR,
			xZONA 	IN 	CHAR,
			xIDEXPE	IN	INTEGER,
			xNIF		IN	CHAR,
			xCIF		IN	CHAR,
			xNOMBRE	IN	CHAR,
			xVIA		IN	CHAR,
			xCALLE	IN	CHAR,
			xNUMERO	IN	CHAR,
			xESCALERA	IN	CHAR,
			xPLANTA	IN	CHAR,
			xPISO		IN	CHAR,
			xPOBLACION	IN	CHAR,
			xPROVINCIA	IN	CHAR,
			xCOD_POSTAL IN	CHAR)
AS
xCONTADOR 	  INTEGER;
xEsta_Embargo CHAR(1);
xNada 		  INTEGER;

BEGIN   
     

   IF xTIPOREGISTRO='1' THEN -- Vienen datos

   	-- comprobamos si el empresario existe como contribuyente; sino lo introducimos 
   	SELECT COUNT(*) INTO xCONTADOR FROM CONTRIBUYENTES
   	WHERE ltrim(rtrim(NIF))=ltrim(rtrim(xCIF));

   	IF xCONTADOR=0 THEN  -- no existe la empresa como contribuyente 
         INSERT INTO CONTRIBUYENTES
		(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,
		 PISO,POBLACION,PROVINCIA,CODIGO_POSTAL)
	   VALUES
		(xCIF,xNOMBRE,xVIA,xCALLE,xNUMERO,xESCALERA,xPLANTA,
		 xPISO,xPOBLACION,xPROVINCIA,xCOD_POSTAL);
   	END IF;

	-- comprobamos si el trabajador tiene el trabajo; sino lo introducimos	 
   	SELECT COUNT(*) INTO xCONTADOR FROM SALARIOS WHERE CIF_EMPRESA=xCIF AND NIF=xNIF;

	IF xCONTADOR=0 THEN -- No tiene el trabajo.Lo pone.
   	   INSERT INTO SALARIOS (IDEXPE,NIF,CIF_EMPRESA,SITUACION)
       VALUES (xIDEXPE,xNIF,xCIF,'ALTA');
	END IF;

	begin -- Puede que no este ya en un expediente. Hay que proteger el select.
   	   -- Al ponerle un trabajo, si esta pendiente en embargo de salarios 
	   -- lo paso a estado abierto.
   	   SELECT EMBARGO_3 INTO xEsta_Embargo 
	   FROM EXPEDIENTES WHERE ID=xIDEXPE;
	exception
		When no_data_found then 
			return;
	end;
  	
	-- Si llega aquí es porque tiene expediente.
	PKSeguimiento.NotaInformativa(xIDEXPE,'Recibida información positiva de la SS ');	

   	-- Indico en el expediente que tiene trabajo. (estado = 'R')
   	UPDATE EXPEDIENTES SET E_LOTE3='R' WHERE ID=xIDEXPE;  
 	
   	IF xEsta_Embargo='P' THEN
   		PUT_UnExpeEnLoteSalarios(xIDExpe,xNADA);
   	END IF;

   -- 0-> No viene informacion. 2-> Trabajador por cuenta propia. 
   -- Lo paso al pendiente de Inmuebles
   ELSIF (xTIPOREGISTRO='0') or (xTIPOREGISTRO='2') THEN  

	begin -- Puede que no este ya en un expediente. Hay que proteger el select.

	   -- Al no tener trabajo, si esta pendiente en embargo de salarios lo paso a inmuebles.
   	   SELECT EMBARGO_3 INTO xEsta_Embargo 
	   FROM EXPEDIENTES WHERE ID=xIDEXPE;
	exception
		When no_data_found then 
			return;
	end;

	-- Si llega aquí es porque tiene expediente.
	PKSeguimiento.NotaInformativa(xIDEXPE,'Recibida información negativa de la SS');	

   	IF xEsta_Embargo='P' THEN
		BORRAR_SIN_SALARIO(xIDEXPE,xZONA,'E',0);
   	END IF;

   END IF;
   
END;
/


/***************************************************************************************/
-- Procedimiento que rellena una tabla temporal para la impresión de notificaciones en el 
--   embargo de Salarios. Los informes se han hecho con Crystal Report 
-- Se utiliza para informes que se muestran en la aplicación tras ejecutar: 
-- 1. Diligencias masivas.
-- 2. Notificaciones a empresa masivas.
-- 3. Reiteracion a empresas masivas.
-- 4. Notificaciones a deudores masivas.
-- Se indica al procedimiento el tipo de operación realizada en xQUIEN, y esto se usa para
-- rellenar unos campos u otros en la tabla temporal para que el Crystal Report los muestre.
-- MODIFICACIÓN: 19/03/2002 M. Carmen Junco Gómez. Para poder mostrar más datos del 
--		     ayuntamiento en la cabecera de los documentos.
-- MODIFICACION: 03/110/2004 Gloria Maria Calle Hernandez. Separar en tres campos el codigo postal, 
--				 poblacion y provincia tanto para CIF como NIF.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE IMPRIME_NOTI_SALARIOS (
		xZONA		IN CHAR,
		xFECHA_DILI	IN DATE,
		xQUIEN	IN CHAR,
		xLOTE		IN CHAR,
		xLOTEENTERO IN CHAR)
AS
xAYUNTAMIENTO	VARCHAR2(50);
xNOMBRE			VARCHAR2(80);
xDIRECCION		VARCHAR2(100);
xPOBLACION		VARCHAR2(50);
xPROVINCIA		VARCHAR2(50);
xRESPONSABLE	VARCHAR2(50);
xID_CUENTA		INTEGER;
xCIF_AYTO		CHAR(10);
xTELEFONOS_AYTO VARCHAR2(100);
xENTIDAD		CHAR(4);
xSUCURSAL		CHAR(4);
xDC				CHAR(2);
xCUENTA			CHAR(10);
xBANCO			VARCHAR2(50);
xCPOSTAL_NIF	VARCHAR2(5);
xPOBLACION_NIF 	VARCHAR2(50);
xPROVINCIA_NIF 	VARCHAR2(30);
xCPOSTAL_CIF 	VARCHAR2(5);
xPOBLACION_CIF 	VARCHAR2(50);
xPROVINCIA_CIF 	VARCHAR2(30);
xDeuda_total	FLOAT;
xIntereses		FLOAT;

   CURSOR CDILI IS SELECT E.ID,E.IDEXPE,E.EXPEDIENTE,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,
			 rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 S.CIF_EMPRESA,rtrim(GETNOMBRE(S.CIF_EMPRESA)) AS NOMBRE_CIF,
			 rtrim(GETDOMICILIO(S.CIF_EMPRESA)) AS DOMI_CIF,
			 E.F_DILIGENCIA
		       FROM EMBARGOS_SALARIOS E,SALARIOS S, EXPEDIENTES P
		       WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=P.ID AND
                         S.NIF<>S.CIF_EMPRESA AND -- no autónomos 
			    -- F_DILIGENCIA IS NULL AND 
		             E.ZONA=xZONA AND P.LOTE_3=xLOTE;

   CURSOR CEMPRESA IS SELECT E.ID,E.IDEXPE,E.EXPEDIENTE,E.NIF,
			 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,
			 S.CIF_EMPRESA,rtrim(GETNOMBRE(S.CIF_EMPRESA)) AS NOMBRE_CIF,
			 rtrim(GETDOMICILIO(S.CIF_EMPRESA)) AS DOMI_CIF,
			 E.EMITIDA_EMPRESA
			 FROM EMBARGOS_SALARIOS E,SALARIOS S, EXPEDIENTES P
			 WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=P.ID AND
			       E.F_DILIGENCIA IS NOT NULL 
			    -- AND E.EMITIDA_EMPRESA='N'
				 AND E.ZONA=xZONA AND P.LOTE_3=xLOTE;

-- busca los salarios de un embargo que este activo y tenga todas las notificaciones a la 
-- empresa en estado notificado.
CURSOR CREITERA IS SELECT E.ID,E.IDEXPE,rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,
	rtrim(GETNOMBRE(S.CIF_EMPRESA)) AS NOMBRE_CIF,N.F_NOTIFICACION,
	E.EMITIDA_REITERA
	FROM EMBARGOS_SALARIOS E,SALARIOS S,NOTIFICACIONES N, EXPEDIENTES P
	WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=N.EXPEDIENTE AND E.IDEXPE=P.ID AND
			S.CIF_EMPRESA=N.NIF AND E.EMITIDA_EMPRESA='S' 
			-- AND E.EMITIDA_REITERA='N' 
			AND N.TIPO_NOTI='302'
			AND 'N' NOT IN (SELECT NOTIFICADO FROM NOTIFICACIONES
						WHERE EXPEDIENTE=E.IDEXPE AND 
						TIPO_NOTI='302' AND 
						ID_EMBARGOS IN
						   (SELECT ID FROM EMBARGOS_SALARIOS WHERE IDEXPE=E.IDEXPE)
						)
			and n.id_embargos in(SELECT id_embargos FROM NOTIFICACIONES
						WHERE EXPEDIENTE=E.IDEXPE AND 
						TIPO_NOTI='302' AND 
						ID_EMBARGOS IN
						   (SELECT ID FROM EMBARGOS_SALARIOS WHERE IDEXPE=E.IDEXPE)
				)
			AND E.ZONA=xZONA AND P.LOTE_3=xLOTE;		




   CURSOR CDEUDOR IS SELECT E.ID,E.IDEXPE,E.EXPEDIENTE,E.NIF,
			 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,
			 rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,S.CIF_EMPRESA,
			 rtrim(GETNOMBRE(S.CIF_EMPRESA)) AS NOMBRE_CIF, 
			 E.EMITIDA_DEUDOR
			 FROM EMBARGOS_SALARIOS E,SALARIOS S, EXPEDIENTES P
			 WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=P.ID AND
				 E.F_DILIGENCIA IS NOT NULL 
				-- AND E.EMITIDA_DEUDOR='N' 
				 AND E.ZONA=xZONA AND P.LOTE_3=xLOTE;
			

BEGIN

   DELETE FROM IMP_NOTI_SALARIOS WHERE USUARIO=(SELECT UID FROM DUAL);
 
   SELECT Z.AYUNTAMIENTO,Z.NOMBRE,Z.DIRECCION,Z.POBLACION,Z.PROVINCIA,Z.RESPONSABLE,
	    Z.ID_CUENTA,Z.CIF,'Tel.'||Z.TELEFONO1||'-'||Z.TELEFONO2||',Fax:'||Z.FAX AS TELEFONOS
   INTO xAYUNTAMIENTO,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xRESPONSABLE, 
	  xID_CUENTA,xCIF_AYTO,xTELEFONOS_AYTO
   FROM ZONAS Z, USUARIOS U 
   WHERE Z.ZONA=U.ZONA AND U.USUARIO=USER;   

   begin
   	SELECT ENTIDAD,OFICINA,DC,CUENTA INTO xENTIDAD,xSUCURSAL,xDC,xCUENTA
	FROM CUENTAS_SERVICIO
   	WHERE ID=xID_CUENTA;
   	
	SELECT NOMBRE INTO xBANCO
   	FROM BANCOS
   	WHERE ENTIDAD=xENTIDAD;

	EXCEPTION
	   WHEN NO_DATA_FOUND THEN
		xID_CUENTA:=null;	
   end;

  
   IF xQUIEN='F' THEN  /* diligencia */

      FOR v_dili IN CDILI 
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_dili.F_DILIGENCIA IS NULL) THEN
	   	xCPOSTAL_NIF:='';
   		xPOBLACION_NIF:='';
   		xPROVINCIA_NIF:='';
	   	xCPOSTAL_CIF:='';
   		xPOBLACION_CIF:='';
   		xPROVINCIA_CIF:='';

	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL)),ltrim(rtrim(POBLACION)),ltrim(rtrim(PROVINCIA)) 
	         into xCPOSTAL_NIF,xPOBLACION_NIF,xPROVINCIA_NIF	
		   from contribuyentes where nif=v_dili.NIF;

		   exception
		      when no_data_found then
			   null;
	   	end;

	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL)),ltrim(rtrim(POBLACION)),ltrim(rtrim(PROVINCIA)) 
	         into xCPOSTAL_CIF,xPOBLACION_CIF,xPROVINCIA_CIF	
		   from contribuyentes where nif=v_dili.CIF_EMPRESA;

		   exception
		   	when no_data_found then
			   null;
	   	end;

		
		IF v_DILI.F_DILIGENCIA IS NULL THEN
		   -- Lo calcula aquí para que muestre datos actuales en el informe. Esto es porque se imprime antes de 
		   -- generar la diligencia, por lo que en la impresión necesita datos correctos. Tras llamar a este 
		   -- procedimiento siempre se llama luego a DILIGENCIA_SALARIOS, que ya pone la diligencia al expediente.
	   	   CalcDemora_Expe(v_DILI.IDEXPE, xFECHA_DILI, 'S','E', xIntereses, xDeuda_Total);
	   	   UPDATE EMBARGOS_SALARIOS SET DEUDA_TOTAL=ROUND(xDeuda_Total,2)
	   	   WHERE ID=v_DILI.ID;
		ELSE -- Ya tiene fecha de diligencia puesta, no se recalculan los intereses
		   SELECT SUM(PENDIENTE) INTO xDeuda_Total FROM IMPORTE_VALORES 
			WHERE EXPEDIENTE=v_DILI.IDEXPE AND ID_SALARIOS=v_DILI.ID
			AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;
		   if xDeuda_Total is null then
			xDeuda_Total:=0;
		   end if;
		END IF;

         	INSERT INTO IMP_NOTI_SALARIOS(AYUNTAMIENTO,NOMBRE,DIRECCION,POBLACION,PROVINCIA,
		   CIF_AYTO,TELEFONOS_AYTO,IDEXPE,EXPEDIENTE,
		   NIF,NOMBRE_NIF,DOMI_NIF,CPOSTAL_NIF,POBLACION_NIF,PROVINCIA_NIF,
		   CIF,NOMBRE_CIF,DOMI_CIF,CPOSTAL_CIF,POBLACION_CIF,PROVINCIA_CIF,
		   DEUDA_TOTAL,FECHA,RESPONSABLE)
	   	VALUES (xAYUNTAMIENTO,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xCIF_AYTO,
		   xTELEFONOS_AYTO,v_dili.IDEXPE,v_dili.EXPEDIENTE,
		   v_dili.NIF,v_dili.NOMBRE_NIF,v_dili.DOMI_NIF,xCPOSTAL_NIF,xPOBLACION_NIF,xPROVINCIA_NIF,
		   v_dili.CIF_EMPRESA,v_dili.NOMBRE_CIF,v_dili.DOMI_CIF,xCPOSTAL_CIF,xPOBLACION_CIF,xPROVINCIA_CIF,
		   ROUND(xDeuda_Total,2),xFECHA_DILI,xRESPONSABLE);		
	   END IF;
	END LOOP; -- v_dili.Deuda_total

   ELSIF xQUIEN='E' THEN /*notificación a la Empresa */

      FOR v_empresa IN CEMPRESA
      LOOP
	 -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	 -- lo pendiente del lote, el expediente esta pendiente.
	 IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_empresa.EMITIDA_EMPRESA='N') THEN
	   xCPOSTAL_CIF:='';
	   xPOBLACION_CIF:='';
	   xPROVINCIA_CIF:='';

	   begin
         select ltrim(rtrim(CODIGO_POSTAL)),ltrim(rtrim(POBLACION)),ltrim(rtrim(PROVINCIA)) 
	       into xCPOSTAL_CIF,xPOBLACION_CIF,xPROVINCIA_CIF	
	 	   from contribuyentes where nif=v_empresa.CIF_EMPRESA;

		exception
		   when no_data_found then
			null;
	   end;

	   SELECT SUM(PENDIENTE) INTO xDeuda_Total FROM IMPORTE_VALORES 
		WHERE EXPEDIENTE=v_EMPRESA.IDEXPE AND ID_SALARIOS=v_EMPRESA.ID
		AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;
	   if xDeuda_Total is null then
		xDeuda_Total:=0;
	   end if;

         INSERT INTO IMP_NOTI_SALARIOS(AYUNTAMIENTO,NOMBRE,DIRECCION,POBLACION,PROVINCIA,
		CIF_AYTO,TELEFONOS_AYTO,BANCO,ENTIDAD,OFICINA,DC,CUENTA,IDEXPE,EXPEDIENTE,NIF,
		NOMBRE_NIF,CIF,NOMBRE_CIF,DOMI_CIF,CPOSTAL_CIF,POBLACION_CIF,PROVINCIA_CIF,DEUDA_TOTAL,FECHA,RESPONSABLE)
	   VALUES (xAYUNTAMIENTO,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xCIF_AYTO,
		xTELEFONOS_AYTO,xBANCO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,v_empresa.IDEXPE,
		v_empresa.EXPEDIENTE,v_empresa.NIF,
		v_empresa.NOMBRE_NIF,v_empresa.CIF_EMPRESA,
		v_empresa.NOMBRE_CIF,v_empresa.DOMI_CIF,xCPOSTAL_CIF,xPOBLACION_CIF,xPROVINCIA_CIF,xDeuda_Total,
		SYSDATE,xRESPONSABLE);

       END IF;

	END LOOP;

   ELSIF xQUIEN='R' THEN /* reiteración advertencia de sanción */

	FOR v_reitera IN CREITERA
	LOOP
	 -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	 -- lo pendiente del lote, el expediente esta pendiente.
	 IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_reitera.EMITIDA_REITERA='N') THEN

	   SELECT SUM(PENDIENTE) INTO xDeuda_Total FROM IMPORTE_VALORES 
		WHERE EXPEDIENTE=v_reitera.IDEXPE AND ID_SALARIOS=v_reitera.ID
		AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;
	   if xDeuda_Total is null then
		xDeuda_Total:=0;
	   end if;

         INSERT INTO IMP_NOTI_SALARIOS(AYUNTAMIENTO,NOMBRE,DIRECCION,POBLACION,PROVINCIA,
		CIF_AYTO,TELEFONOS_AYTO,NOMBRE_NIF,NOMBRE_CIF,FECHA,RESPONSABLE,DEUDA_TOTAL)
	   VALUES (xAYUNTAMIENTO,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xCIF_AYTO,
		xTELEFONOS_AYTO,v_reitera.NOMBRE_NIF,v_reitera.NOMBRE_CIF,v_reitera.F_NOTIFICACION,
		xRESPONSABLE,xDeuda_Total);
	 END IF;
	END LOOP;

   ELSIF xQUIEN='D' THEN

      FOR v_deudor IN CDEUDOR
	LOOP
	 -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	 -- lo pendiente del lote, el expediente esta pendiente.
	 IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_deudor.EMITIDA_DEUDOR='N') THEN
         xCPOSTAL_NIF:='';
		 xPOBLACION_NIF:='';
		 xPROVINCIA_NIF:='';

	   begin
         select ltrim(rtrim(CODIGO_POSTAL)),ltrim(rtrim(POBLACION)),ltrim(rtrim(PROVINCIA)) 
	         into xCPOSTAL_NIF,xPOBLACION_NIF,xPROVINCIA_NIF	
		from contribuyentes where nif=v_deudor.NIF;

		exception
		   when no_data_found then
			null;
	   end;

	   SELECT SUM(PENDIENTE) INTO xDeuda_Total FROM IMPORTE_VALORES 
		WHERE EXPEDIENTE=v_DEUDOR.IDEXPE AND ID_SALARIOS=v_DEUDOR.ID
		AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;
	   if xDeuda_Total is null then
		xDeuda_Total:=0;
	   end if;

	   INSERT INTO IMP_NOTI_SALARIOS (AYUNTAMIENTO,NOMBRE,DIRECCION,POBLACION,PROVINCIA,
		CIF_AYTO,TELEFONOS_AYTO,IDEXPE,EXPEDIENTE,NIF,NOMBRE_NIF,DOMI_NIF,CPOSTAL_NIF,
		POBLACION_NIF,PROVINCIA_NIF,CIF,NOMBRE_CIF,ENTIDAD,OFICINA,DC,CUENTA,BANCO,FECHA,
		RESPONSABLE,DEUDA_TOTAL)
	   VALUES (xAYUNTAMIENTO,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xCIF_AYTO,
		xTELEFONOS_AYTO,v_deudor.IDEXPE,v_deudor.EXPEDIENTE,v_deudor.NIF,
		v_deudor.NOMBRE_NIF,v_deudor.DOMI_NIF,xCPOSTAL_NIF,xPOBLACION_NIF,xPROVINCIA_NIF,
		v_deudor.CIF_EMPRESA,v_deudor.NOMBRE_CIF,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xBANCO,
		SYSDATE,xRESPONSABLE,xDeuda_Total);
	 END IF;
	END LOOP;

   END IF;   

END;
/

/***************************************************************************************/
-- 31-01-2002 Lucas Fernández Pérez.
-- Crea un lote de embargos, cuando se pide informacion a la SS 
-- Tambien se utiliza para el reintento de peticion de informacion a la SS
-- Genera una anotacion en el seguimiento para cada expediente tratado.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE CREA_LOTE_EMBARGOS(
		xNLote 		IN CHAR,
		xTipoEmbargo 	IN CHAR,
		xTipoInforme	IN CHAR,
		xZona			IN CHAR,
		xDesde		IN DATE,
		xHasta		IN DATE,
		xMenor		IN FLOAT,
		xMayor		IN FLOAT)
AS
CURSOR CEXPESALA IS SELECT ID FROM NEXT_RELA_SALARIOS
	WHERE LOTE_3=xNLote AND ZONA=xZONA;

CURSOR CEXPEINMU IS SELECT ID FROM NEXT_RELA_INMUEBLES
	WHERE LOTE_4=xNLote AND ZONA=xZONA;

CURSOR CEXPEAUTO IS SELECT ID FROM NEXT_RELA_AUTOS
	WHERE LOTE_8=xNLote AND ZONA=xZONA;

BEGIN

-- ************* PARA EMBARGO DE SALARIOS ***************

   IF xTipoEmbargo='3' AND xTipoInforme='P' THEN -- Creacion del lote en la peticion de informacion

	 -- Pongo el numero de lote y estado de lote a 'P' a los expedientes sin lote.
     UPDATE EXPEDIENTES SET LOTE_3= xNLote , E_LOTE3= 'P' 
	 WHERE ID IN (SELECT P.EXPEDIENTE FROM NEXT_RELA_SALARIOS N,PendiValoresExpe P 
             WHERE N.ID=P.EXPEDIENTE AND ZONA=xZONA 
             AND F_EMBARGO_SALARIOS BETWEEN xDesde AND xHasta 
             AND P.PENDIENTE BETWEEN xMenor and xMayor 
             AND N.LOTE_3 IS NULL);

	 -- Pongo el estado de lote a 'R' a los expedientes del lote que tienen trabajo.
	 UPDATE NEXT_RELA_SALARIOS SET E_LOTE3='R' WHERE 
		ID IN (SELECT IDEXPE FROM SALARIOS)
		AND LOTE_3=xNLote AND ZONA=xZONA;
         
   	 FOR v_EXPE IN CEXPESALA LOOP
	   PKSeguimiento.NotaInformativa(v_EXPE.ID,'Emitida la solicitud de información a '||
							'la SS. Numero de Lote: '||xNLote);	
   	 END LOOP;

   ELSIF xTipoEmbargo='3' AND xTipoInforme='R' THEN  -- Reiteracion de peticion de informacion
	 -- El lote ya existe
	 -- Pongo el numero estado de lote a 'P' a los expedientes sin trabajo
	 UPDATE NEXT_RELA_SALARIOS SET E_LOTE3='P' WHERE 
		ID NOT IN (SELECT IDEXPE FROM SALARIOS)
		AND LOTE_3=xNLote AND ZONA=xZONA;

	 -- Pongo el estado de lote a 'R' a los expedientes del lote que tienen trabajo.
	 UPDATE NEXT_RELA_SALARIOS SET E_LOTE3='R' WHERE 
		ID IN (SELECT IDEXPE FROM SALARIOS)
		AND LOTE_3=xNLote  AND ZONA=xZONA;

   	 FOR v_EXPE IN CEXPESALA LOOP
	    PKSeguimiento.NotaInformativa(v_EXPE.ID,'Se Reitera la emision de solicitud '||
					'de información a la SS. Numero de Lote: '||xNLote);	
   	 END LOOP;

   END IF;

-- ************* PARA EMBARGO DE INMUEBLES ***************
   IF xTipoEmbargo='4' AND xTipoInforme='P' THEN -- Creacion del lote 

	 -- Pongo el numero de lote a los expedientes sin lote.
     UPDATE EXPEDIENTES SET LOTE_4= xNLote 
	 WHERE ID IN (SELECT P.EXPEDIENTE FROM NEXT_RELA_INMUEBLES N,PendiValoresExpe P 
             WHERE N.ID=P.EXPEDIENTE AND ZONA=xZONA 
             AND F_EMBARGO_INMUEBLES BETWEEN xDesde AND xHasta 
             AND P.PENDIENTE BETWEEN xMenor and xMayor 
		     AND N.ID NOT IN (SELECT IDEXPE FROM NOTAS_SIMPLES)
             AND N.LOTE_4 IS NULL);

	 FOR v_EXPE IN CEXPEINMU LOOP		
	   PKSeguimiento.NotaInformativa(v_EXPE.ID,'Emision de Nota Simple por lotes. '||
		'Numero de Lote: '||xNLote);	
	 END LOOP;
   END IF;

-- ************* PARA EMBARGO DE VEHICULOS ***************
   IF xTipoEmbargo='8' THEN -- Creacion del lote 

	 -- Pongo el numero de lote a los expedientes sin lote.
     UPDATE EXPEDIENTES SET LOTE_8=xNLote 
     WHERE ID IN (SELECT ID FROM NEXT_RELA_AUTOS WHERE DEUDOR IN 
			  	 (SELECT NIF FROM VEHICULOSR)) AND
	              ZONA=xZONA AND LOTE_8 IS NULL;


     FOR v_EXPE IN CEXPEAUTO LOOP			
	   PKSeguimiento.NotaInformativa(v_EXPE.ID,'Inclusión del Expediente '||
		'en un Lote de Emb. de Vehículos. Numero de Lote: '||xNLote);	
	 END LOOP;
   END IF;

END;
/

/********************************************************************
Autor: 29/01/2002 Lucas Fernández Pérez
Acción: Notifica de forma masiva a las empresas.
********************************************************************/

CREATE OR REPLACE PROCEDURE NOTIFICA_SALARIOS_MASIVOS(
     xZONA   IN CHAR,
     xQUIEN  IN CHAR,
     xLOTE 	 IN CHAR)

AS

   CURSOR CSALARIOS IS SELECT E.ID,E.IDEXPE
				FROM EMBARGOS_SALARIOS E,SALARIOS S,EXPEDIENTES P
				WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=P.ID AND
					E.F_DILIGENCIA IS NOT NULL AND
					E.EMITIDA_EMPRESA='N' AND
					E.ZONA=xZONA AND P.LOTE_3=xLOTE;

   CURSOR CREITERA IS SELECT E.ID,E.IDEXPE
	      FROM EMBARGOS_SALARIOS E,SALARIOS S, EXPEDIENTES P
	      WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=P.ID AND
			E.EMITIDA_EMPRESA='S' AND
			E.EMITIDA_REITERA='N' AND
			'N' NOT IN (SELECT NOTIFICADO FROM NOTIFICACIONES
				      WHERE EXPEDIENTE=E.IDEXPE
					AND TIPO_NOTI='302'
					AND ID_EMBARGOS IN
						(SELECT ID FROM EMBARGOS_SALARIOS WHERE IDEXPE=E.IDEXPE)
					) AND
			E.ZONA=xZONA AND P.LOTE_3=xLOTE;

   CURSOR CDEUDOR IS SELECT E.ID,E.IDEXPE
				FROM EMBARGOS_SALARIOS E,SALARIOS S,EXPEDIENTES P
				WHERE E.NIF=S.NIF AND E.IDEXPE=S.IDEXPE AND E.IDEXPE=P.ID AND
					E.F_DILIGENCIA IS NOT NULL AND
					E.EMITIDA_DEUDOR='N' AND
					E.ZONA=xZONA AND P.LOTE_3=xLOTE;
BEGIN

   /* Notificación a la/s Empresas */
   IF xQUIEN='E' THEN
      FOR v_Sal IN CSALARIOS
      LOOP
         NOTIFICA_SALARIOS(v_Sal.IDEXPE,v_Sal.ID,'E');
      END LOOP;
   END IF;


   /* Reiteración advertencia de sanción a la/s Empresas */
   IF xQUIEN='R' THEN
      FOR v_Reitera IN CREITERA
      LOOP
	   NOTIFICA_SALARIOS(v_Reitera.IDEXPE,v_Reitera.ID,'R');
      END LOOP;
   END IF;


   IF xQUIEN='D' THEN  /* deudor */
      FOR v_Deudor in CDEUDOR
      LOOP
         NOTIFICA_SALARIOS(v_Deudor.IDEXPE,v_Deudor.ID,'D');
	END LOOP;
   END IF;

END;
/

/***************************************************************************************/
COMMIT;