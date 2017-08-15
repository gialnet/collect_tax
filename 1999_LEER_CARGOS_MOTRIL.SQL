
CREATE OR REPLACE PROCEDURE LEER_CARGOS_AS400 
		(xPaseEuros IN char, 
		xNumCargo IN char,
		xConcepto IN char,
		xVol_Eje  IN char)
AS

xRecibo 		char(7);
xN_ORDEN_VALOR	char(4);
xObjeto 		varchar(2048);
xTexto 		varchar(40);
xTipoTributo	char(2);

/*tabla de tmp_observa*/
xObjeto_Tri 	char(70);
xDomicilio 		char(50);
xMatricula 		char(20);

/*tabla de tmp_cabecera*/
xMatriCabecera 	char(20);
xDomiCabecera 	char(40);
xNombre		char(30);
xPostalCabecera	char(5);
xPoblacionCabe	char(30);

xImporte 		float;
xCuota_Inicial 	float;

xFechaCargo 	date;
xFinPeVol 		date;
xInicioPeVol 	date;
xSALTO 		CHAR(2);

Cursor cCargos is select * from tmp_cargos;

Cursor cDetalle is select texto from tmp_detalle 
	where recibo=xRecibo and N_ORDEN_VALOR=xN_ORDEN_VALOR;

Cursor cObserva is select OBJETO_TRIBUTARIO,DOMICILIO,MATRICULA
	from tmp_observa where recibo=xRecibo and N_ORDEN_VALOR=xN_ORDEN_VALOR;

BEGIN

	SELECT SALTO INTO xSALTO FROM SALTO;

	for vCargos in cCargos loop

		xObjeto:='';
		xObjeto_Tri:='';
		xDomicilio:='';
		xMatricula:='';
		xMatriCabecera:='';
		xDomiCabecera:='';

		xCuota_Inicial:=0;
		xImporte:=0;


		/*TMP_OBSERVA*/
		xRecibo:=vCargos.RECIBO;
		xN_ORDEN_VALOR:=vCargos.N_ORDEN_VALOR;

		for vObserva IN cObserva loop

			if RTRIM(vObserva.OBJETO_TRIBUTARIO) is null then
				xObjeto_Tri:='';
			else
				xObjeto_Tri:=vObserva.OBJETO_TRIBUTARIO;
			end if;

			xDomicilio:=vObserva.DOMICILIO;
			xMatricula:=vObserva.MATRICULA;
			xObjeto:=xObjeto || xObjeto_Tri ||xSALTO;

		end loop;

		/*TMP_DETALLE*/
		for vDetalle in cDetalle loop

			if RTRIM(vDetalle.TEXTO) is null then
				xTexto:='';
			else
				xTexto:=vDetalle.TEXTO;
			end if;

			xObjeto := xObjeto || xTEXTO ||xSALTO;
		end loop;


		/*TMP_CABECERA*/
		begin
			select MATRICULA,DOMICILIO,POBLACION,COD_POSTAL 
			into xMatriCabecera,xDomiCabecera,xPoblacionCabe,xPostalCabecera
			from tmp_cabecera	
			where recibo=vCargos.RECIBO and N_ORDEN_VALOR=vCargos.N_ORDEN_VALOR;
		exception
			when no_data_found then
				null;
		end;

		if (xDomicilio='' or xDomicilio is null) then
			xDomicilio:=xDomiCabecera;			
		end if;

		if (xMatricula='' or xMatricula is null) then
			xMatricula:=xMatriCabecera;
		end if;

		if (vCargos.FUERA_PLAZO > 0) then
			xCuota_Inicial:=vCargos.PRINCIPAL;
			xImporte:=vCargos.PRINCIPAL - vCargos.FUERA_PLAZO;
		else
			xCuota_Inicial:=vCargos.PRINCIPAL;
			xImporte:=vCargos.PRINCIPAL;
		end if;


		--hay que pasarlos a Euros
		if xPaseEuros='S' then
			xCuota_Inicial:=Round(xCuota_Inicial/166.386,2);
			xImporte:=Round(xImporte/166.386,2);
		else
			xCuota_Inicial:=to_char(xCuota_Inicial,'9999999990,99');
			xImporte:=to_char(xImporte,'9999999990,99');
		end if;


		xFechaCargo:=to_date(vCargos.FECHA_CARGO,'yyyy-mm-dd');
		xFinPeVol:=to_date(vCargos.FECHA_VENCIMI,'yyyy-mm-dd');
		xInicioPeVol:=to_date(vCargos.FECHA_EMISION,'yyyy-mm-dd');

		begin
			select tipo_tributo into xTipoTributo from contador_conceptos
			where municipio='180' and concepto=vCargos.PADRON;
		exception
			when no_data_found then
				xTipoTributo:='IM';
		end;

		xNombre:=Replace(LTRIM(RTRIM(vCargos.NOMBRE)),',' , ' ');
		xNombre:=Replace(xNOMBRE,',,' , ' ');
		xNombre:=Replace(xNOMBRE,'  ' , ' ');

		--solo si el cargo no es de multas se coge el codigo postal 
		--de la tabla de Cargos en vez de la Tabla de Cabecera
		if vCargos.PADRON<>'039100' then

			--Modificacion: 27/02/2004. Agustín León Robles. Según la nueva estructura de los ficheros enviados,
			--cuando sea el concepto de Urbana se tiene que quedar con el codigo postal del fichero de cabecera
			if vCargos.PADRON<>'011201' then
				xPostalCabecera:=LTRIM(RTRIM(vCargos.COD_POSTAL));
			end if;
			
			xDomiCabecera:=LTRIM(RTRIM(vCargos.DOMICILIO));
			xPoblacionCabe:=LTRIM(RTRIM(vCargos.MUNICIPIO));

		end if;
		
		

		INSERT INTO Punteo
			(PADRON,YEAR,PERIODO,RECIBO,YEAR_CONTRAIDO,AYTO,TIPO_DE_OBJETO,
		      NIF,NOMBRE,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,
			CENTRO_GESTOR,OFICINA_LIQUI,N_ORDEN_VALOR,CERT_DESCUBIERTO,

		      N_CARGO,F_CARGO,VOL_EJE,
		      PRINCIPAL,CUOTA_INICIAL,
		      FIN_PE_VOL,INI_PE_VOL,
			CLAVE_CONCEPTO,DOM_TRIBUTARIO,
			OBJETO_TRIBUTARIO,TIPO_DE_TRIBUTO)
		
		VALUES(DECODE(xConcepto,'',vCargos.PADRON,xConcepto),vCargos.YEAR,'00',
			vCargos.RECIBO,TO_CHAR(xInicioPeVol,'YYYY'),'180',vCargos.TIPO_DEL_VALOR,
		    LTRIM(RTRIM(vCargos.DNI)),xNOMBRE,
		    substr(xDomiCabecera,1,30),
		    LTRIM(RTRIM(substr(xDomiCabecera,32,3))),
		    LTRIM(RTRIM(substr(xDomiCabecera,36,2))),
		    LTRIM(RTRIM(substr(xDomiCabecera,39,3))),
		    LTRIM(RTRIM(substr(xDomiCabecera,43,2))),
		    
			xPoblacionCabe,LTRIM(RTRIM(vCargos.PROVINCIA)),xPostalCabecera,

			vCargos.CENTRO_GESTOR,vCargos.OFICINA_LIQUI,
			vCargos.N_ORDEN_VALOR,vCargos.N_CERTIFICACION,

		      xNumCargo,xFechaCargo,xVol_Eje,
			xImporte,xCuota_Inicial,
			xFinPeVol,xInicioPeVol,
			xMatricula,xDomicilio,
			TRIM(xObjeto),xTipoTributo);

	end loop;
		
END;
/
