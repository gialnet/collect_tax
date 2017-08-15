-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/*****************************************************************************************
Acción: Rellena dos tablas temporales, una de cobros y otra de remesas, para posteriormente
        generar archivos de datos para procesar los cobros realizados entre dos
        fechas determinadas. ATECO.
Autos: M.Carmen Junco Gómez.
Fecha: 10/10/2001

Modificación: 22/11/2001 Lucas Fernandez Perez. 
Euro: Los importes tienen nuevo formato, con igual longitud, pero con el simbolo ',' y
	dos decimales siempre.
Modificación: 06/09/2002 Lucas Fernandez Perez. Cuando los importes son negativos,
		la cadena tiene un caracter más. Se corrige para que la cadena tenga la misma
		longitud aunque haya un signo negativo en la misma.
Modificación: 12/04/2004. Lucas Fernández Pérez. 
   Nuevo parámetro xMODO: 
   0 -> las fechas son de ingreso en la aplicación (INGRESOS.FECHA)
   1 -> Las fechas son de ingreso en banco (INGRESOS.F_COBRO_BANCO) 
        Si no hay fecha de ingreso en banco,(por ser entregas en ventanilla, por ejemplo)
	    se busca si la fecha de ingreso en aplicación está dentro del intervalo y se añade.
*****************************************************************************************/

CREATE OR REPLACE PROCEDURE GENERA_ARCHIVOS(
		xMUNICIPIO		CHAR,
		xFECHAINICIO	DATE,
		xFECHAFIN		DATE,
		xMODO			INTEGER)
AS    
   xNIF      CHAR(10);
   xRECIBO   INTEGER;
   xIDCOBRO  INTEGER;
   xIDBANCO  CHAR(4);
   xIDREMESA CHAR(4);
   xFECHACOBRO DATE;
   xCUENTA	INTEGER;

   xPrincipal CHAR(12);
   xRecargo_10 CHAR(12);
   xRecargo_20 CHAR(12);
   xDemora CHAR(6);
   xCostas CHAR(6);
   xImporte CHAR(12);

   TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type
   vCURSOR    	 	tCURSOR;     -- declare cursor variable
   vSENTENCIA    VARCHAR2(500);   
   vValor        IMPORTE_INGRESOS.VALOR%TYPE;
   vEntidad      IMPORTE_INGRESOS.ENTIDAD_COBRO%TYPE;
   vParte        IMPORTE_INGRESOS.PARTE_DEL_DIA%TYPE;
   vFecha        IMPORTE_INGRESOS.FECHA%TYPE;
   vFCobroBanco  IMPORTE_INGRESOS.F_COBRO_BANCO%TYPE;
   vPrincipal    IMPORTE_INGRESOS.PRINCIPAL%TYPE;
   vRecargo10    IMPORTE_INGRESOS.RECARGO_10%TYPE;
   vRecargo20    IMPORTE_INGRESOS.RECARGO_20%TYPE;
   vDemora       IMPORTE_INGRESOS.DEMORA%TYPE;
   vCostas       IMPORTE_INGRESOS.COSTAS%TYPE;
   vImporte      IMPORTE_INGRESOS.IMPORTE%TYPE;

   CURSOR CREMESA IS SELECT M.ID,C.ENTIDAD,M.IMPORTE
			   FROM MOV_CUENTAS M,CUENTAS_SERVICIO C
			   WHERE M.CUENTA=C.ID AND 				    
				   M.ID IN (SELECT DISTINCT IDREMESA FROM COBROS);

BEGIN

   -- Se rellena antes la tabla de cobros que la de remesas para saber exactamente
   -- qué remesas se han de incluir

   -- Borrar tabla de COBROS
   DELETE FROM COBROS;
   
   -- Rellenar tabla de COBROS

   xIDCOBRO:=0;
   
   IF xModo=0 THEN
    vSENTENCIA:='SELECT VALOR,ENTIDAD_COBRO,PARTE_DEL_DIA,FECHA,F_COBRO_BANCO, '||
   				' PRINCIPAL,RECARGO_10,RECARGO_20,DEMORA,COSTAS,IMPORTE '||
   				' FROM IMPORTE_INGRESOS WHERE AYTO=:xMUNICIPIO AND '||
   				' TRUNC(FECHA,''DD'') BETWEEN TRUNC(TO_DATE('''||xFECHAINICIO||'''),''DD'') '||
   				' and TRUNC(TO_DATE('''||xFECHAFIN||'''),''DD'') ';
   ELSE
    vSENTENCIA:='SELECT VALOR,ENTIDAD_COBRO,PARTE_DEL_DIA,FECHA,F_COBRO_BANCO, '||
   				' PRINCIPAL,RECARGO_10,RECARGO_20,DEMORA,COSTAS,IMPORTE '||
   				' FROM IMPORTE_INGRESOS WHERE AYTO=:xMUNICIPIO AND '||
   				' ( ((F_COBRO_BANCO IS NULL) AND (TRUNC(FECHA,''DD'')) '||
   				'     BETWEEN TRUNC(TO_DATE('''||xFECHAINICIO||'''),''DD'') AND '||
   				'     TRUNC(TO_DATE('''||xFECHAFIN||'''),''DD'')) '||
   			    ' OR (TRUNC(F_COBRO_BANCO,''DD'') BETWEEN '||
   			    ' TRUNC(TO_DATE('''||xFECHAINICIO||'''),''DD'') AND '||
   			    'TRUNC(TO_DATE('''||xFECHAFIN||'''),''DD''))) ';
   END IF;   			  
   				
   OPEN vCURSOR FOR vSENTENCIA USING xMUNICIPIO;
   LOOP
     FETCH vCURSOR INTO vValor,vEntidad,vParte,vFecha,vFCobroBanco,vPrincipal,vRecargo10,
 			   			vRecargo20, vDemora, vCostas, vImporte;
     EXIT WHEN vCURSOR%NOTFOUND;

     SELECT RECIBO,NIF INTO xRECIBO,xNIF FROM VALORES WHERE ID=vVALOR;

     IF (vFCOBROBANCO IS NULL) THEN
       xIDBANCO:='0000';
	   xIDREMESA:='0000';
	   xFECHACOBRO:=vFECHA;
     ELSE	
	   xIDREMESA:=LPAD(vPARTE,4,'0');
	   xFECHACOBRO:=vFCOBROBANCO;
       xIDBANCO:=vENTIDAD;
	
	   IF xIDBANCO IS NULL THEN

		BEGIN
			SELECT CUENTA INTO xCUENTA FROM MOV_CUENTAS WHERE ID=vPARTE;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				xIDBANCO:='0000';	
		END;

		BEGIN
			SELECT ENTIDAD INTO xIDBANCO FROM CUENTAS_SERVICIO WHERE ID=xCUENTA;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				xIDBANCO:='0000';	
		END;

	 END IF;
	   
	END IF;

	xIDCOBRO:=xIDCOBRO+1;

	if vprincipal<0 then -- con un caracter menos porque pondrá el signo "-"
		xprincipal:=LTRIM(TO_CHAR(vPRINCIPAL*100, '09999999999'));
	else
		xprincipal:=LTRIM(TO_CHAR(vPRINCIPAL*100, '099999999999'));
	end if;

	if vrecargo10<0 then
		xRecargo_10:=LTRIM(TO_CHAR(vRECARGO10*100,'09999999999'));
	else
		xRecargo_10:=LTRIM(TO_CHAR(vRECARGO10*100,'099999999999'));
	end if;
		
	if vrecargo20<0 then
		xRecargo_20:=LTRIM(TO_CHAR(vRECARGO20*100,'09999999999'));
	else
		xRecargo_20:=LTRIM(TO_CHAR(vRECARGO20*100,'099999999999'));
	end if;

	if vdemora<0 then
		xDemora:=LTRIM(TO_CHAR(vDEMORA*100,'0999'));
	else
		xDemora:=LTRIM(TO_CHAR(vDEMORA*100,'09999'));
	end if;

	if vcostas<0 then
		xCostas:=LTRIM(TO_CHAR(vCOSTAS*100,'0999'));
	else
		xCostas:=LTRIM(TO_CHAR(vCOSTAS*100,'09999'));
	end if;

	if vimporte<0 then
		xImporte:=LTRIM(TO_CHAR(vIMPORTE*100,'09999999999'));
	else
		xImporte:=LTRIM(TO_CHAR(vIMPORTE*100,'099999999999'));
	end if;


	INSERT INTO COBROS (idCobro,ClaveLiq,Nif,idBanco,idRemesa,FechaCobro,
		Principal,Recargo10,Recargo20,Costas,Demora,Total)
	VALUES (LPAD(xIDCOBRO,8,'0'),LPAD(xRECIBO,8,'0'),SUBSTR(xNIF,1,9),xIDBANCO,
		xIDREMESA,xFECHACOBRO,xPrincipal,xRecargo_10,xRecargo_20,xCostas,xDemora,xImporte);

  END LOOP;
	
	CLOSE vCURSOR;

  -- Borrar tabla de REMESAS   
  DELETE FROM REMESAS;

  -- Rellenar tabla de REMESAS  
  FOR vremesa IN CREMESA
  LOOP	
	INSERT INTO REMESAS(idRemesa,idBanco,Importe)
	VALUES (LPAD(vremesa.ID,4,'0'),vremesa.ENTIDAD,
			LTRIM(TO_CHAR(vremesa.IMPORTE*100,'099999999999')));
  END LOOP;
   
END;
/

