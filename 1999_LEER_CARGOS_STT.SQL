/* estas tablas no hace falta lanzarlas porque se crean desde
                        Delphi en el Control TOraScript

CREATE TABLE TMP_CARGOS (

	PADRON			CHAR(6),
	YEAR			CHAR(4),
	RECIBO			CHAR(7),
	N_ORDEN_VALOR	CHAR(4),
	TIPO_DEL_VALOR	CHAR(1),
	DENO1			CHAR(30),
	DENO2			CHAR(30),
	DENO3			CHAR(30),
	TIPO_REGISTRO	CHAR(1),
	FECHA_CARGO		CHAR(8),
	PRINCIPAL		CHAR(12),
	FUERA_PLAZO		CHAR(12),
	DNI				CHAR(10),
	NOMBRE			CHAR(40),
	VIA				CHAR(2),
	CALLE			CHAR(30),
	NUMERO			CHAR(3),
	ESCALERA		CHAR(2),
	PLANTA			CHAR(3),
	PISO			CHAR(2),
    MUNICIPIO		CHAR(30),
	PROVINCIA		CHAR(30),
	COD_POSTAL		CHAR(5),
	FECHA_EMISION	CHAR(8),
	FECHA_NOTIFI	CHAR(8),
	FECHA_VENCIMI	CHAR(8),
	VOL_EJE			CHAR(1),
	CENTRO_GESTOR	CHAR(6),
	OFICINA_LIQUI	CHAR(2),
	N_CERTIFICACION	CHAR(8),
	CLAVE_CONCEPTO	CHAR(30),
	DOMI_TRIBUTARIO CHAR(60),
	PERIODO			CHAR(2)
);


CREATE TABLE TMP_DETALLE (

	RECIBO	CHAR(7) not null,
	ORDEN		CHAR(2) not null,
	YEAR		CHAR(4),
	TEXTO		CHAR(40),
    ES_DESGLOSE     CHAR(1) DEFAULT 'N'
);


*/


-- Modificado: 04/06/2003 Lucas Fernández Pérez. Inserta si existe el desglose del recibo.
-- Modificado: 26/04/2004 Gloria Maria Calle Hernandez. Cambiado el formato del domicilio (antes de un campo de 25 caracteres)

CREATE OR REPLACE PROCEDURE LEER_CARGOS_AS400 
		(xPaseEuros IN char, 
		xNumCargo IN char,
		xConcepto IN char,
		xVOL_EJE   IN CHAR)
AS

xRecibo 		char(12);
xYear			char(4);
xObjeto 		varchar(2048);
xTexto 		varchar(40);
xTipoTributo	char(2);

xNombre		char(40);

xImporte 		float;
xCuota_Inicial 	float;

xFechaCargo 	date;
xFinPeVol 		date;
xInicioPeVol 	date;
xFNotificacion	date;
xSALTO 		CHAR(2);

xReca1		VARCHAR2(30);
xReca2		VARCHAR2(30);
xReca3		VARCHAR2(30);
xReca4		VARCHAR2(30);
xReca5		VARCHAR2(30);
xReca6		VARCHAR2(30);
xReca7		VARCHAR2(30);
xTitulo1	VARCHAR2(30);
xTitulo2	VARCHAR2(30);
xTitulo3	VARCHAR2(30);
xTitulo4	VARCHAR2(30);
xTitulo5	VARCHAR2(30);
xTitulo6	VARCHAR2(30);
xTitulo7	VARCHAR2(30);
xImpo1		FLOAT DEFAULT 0;
xImpo2		FLOAT DEFAULT 0;
xImpo3		FLOAT DEFAULT 0;
xImpo4		FLOAT DEFAULT 0;
xImpo5		FLOAT DEFAULT 0;
xImpo6		FLOAT DEFAULT 0;
xImpo7		FLOAT DEFAULT 0;


Cursor cCargos is select * from tmp_cargos;

Cursor cDetalle is select texto from tmp_detalle 
		where Year=xYear and Recibo=xRecibo and es_desglose='N' order by orden;

Cursor cDesglose is select orden, texto from tmp_detalle 
		where Year=xYear and Recibo=xRecibo and es_desglose='S' order by orden;

BEGIN

	SELECT SALTO INTO xSALTO FROM SALTO;

	for vCargos in cCargos loop

		xObjeto:='';
		xCuota_Inicial:=0;
		xImporte:=0;

		xRecibo:=vCargos.RECIBO;
		xYear:=vCargos.YEAR;

		-- TMP_DETALLE
		for vDetalle in cDetalle loop

			if vDetalle.TEXTO is null then
				xTexto:='';
			else
				xTexto:=vDetalle.TEXTO;
			end if;

			xObjeto := xObjeto || xTEXTO ||xSALTO;
		end loop;

		xTitulo1:='';
		xTitulo2:='';			
		xTitulo3:='';			
		xTitulo4:='';			
		xTitulo5:='';			
		xTitulo6:='';			
		xTitulo7:='';			
		xImpo1:=0;
		xImpo2:=0;			
		xImpo3:=0;			
		xImpo4:=0;			
		xImpo5:=0;			
		xImpo6:=0;			
		xImpo7:=0;			
			
		-- TMP_DETALLE - DESGLOSE
		for vDesglose in cDesglose loop
			
			select reca1, reca2, reca3, reca4, reca5, reca6, reca7
				 into xReca1, xReca2, xReca3, xReca4, xReca5, xReca6, xReca7
			from conceptos_titulos 
			where concepto=DECODE(xConcepto,'',vCargos.PADRON,xConcepto);

			if vDesglose.orden = '01' then
				xTitulo1:=xReca1;		
				xImpo1:=to_char(TO_NUMBER(vDesglose.Texto),'9999999990,99');			
			elsif vDesglose.orden = '02' then
				xTitulo2:=xReca2;		
				xImpo2:=to_char(TO_NUMBER(vDesglose.Texto),'9999999990,99');			
			elsif vDesglose.orden = '03' then
				xTitulo3:=xReca3;		
				xImpo3:=to_char(TO_NUMBER(vDesglose.Texto),'9999999990,99');			
			elsif vDesglose.orden = '04' then
				xTitulo4:=xReca4;		
				xImpo4:=to_char(TO_NUMBER(vDesglose.Texto),'9999999990,99');			
			elsif vDesglose.orden = '05' then
				xTitulo5:=xReca5;		
				xImpo5:=to_char(TO_NUMBER(vDesglose.Texto),'9999999990,99');			
			elsif vDesglose.orden = '06' then
				xTitulo6:=xReca6;		
				xImpo6:=to_char(TO_NUMBER(vDesglose.Texto),'9999999990,99');			
			elsif vDesglose.orden = '07' then
				xTitulo7:=xReca7;		
				xImpo7:=to_char(TO_NUMBER(vDesglose.Texto),'9999999990,99');			
			end if;

		end loop;

		xCuota_Inicial:=vCargos.PRINCIPAL;
		xImporte:=vCargos.PRINCIPAL;

		--hay que pasarlos a Euros
		if xPaseEuros='S' then
			xCuota_Inicial:=Round(xCuota_Inicial/166.386,2);
			xImporte:=Round(xImporte/166.386,2);
		else
			xCuota_Inicial:=to_char(xCuota_Inicial,'9999999990,99');
			xImporte:=to_char(xImporte,'9999999990,99');
		end if;

		xFechaCargo:=to_date(rtrim(vCargos.FECHA_CARGO),'yyyy-mm-dd');
		xFinPeVol:=to_date(rtrim(vCargos.FECHA_VENCIMI),'yyyy-mm-dd');
		xInicioPeVol:=to_date(rtrim(vCargos.FECHA_EMISION),'yyyy-mm-dd');

		if (vCargos.FECHA_NOTIFI<>'00000000') or (vCargos.FECHA_NOTIFI<>'        ') then 
			xFNotificacion:=to_date(rtrim(vCargos.FECHA_NOTIFI),'yyyy-mm-dd');
		else
			xFNotificacion:=null;
		end if;

		xTipoTributo:='IM';
		xNombre:=Replace(vCargos.NOMBRE,',' , ' ');
		xNombre:=Replace(xNOMBRE,',,' , ' ');
		xNombre:=Replace(xNOMBRE,'  ' , ' ');

		INSERT INTO Punteo
			(PADRON,YEAR,PERIODO,RECIBO,YEAR_CONTRAIDO,AYTO,TIPO_DE_OBJETO,
		      NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,

			CENTRO_GESTOR,OFICINA_LIQUI,N_ORDEN_VALOR,CERT_DESCUBIERTO,

		      N_CARGO,F_CARGO,VOL_EJE,
		      PRINCIPAL,CUOTA_INICIAL,
		      FIN_PE_VOL,INI_PE_VOL,
			CLAVE_CONCEPTO,DOM_TRIBUTARIO,
			OBJETO_TRIBUTARIO,TIPO_DE_TRIBUTO,F_NOTIFICACION,NOTIFICADO,
			TITULO1,TITULO2,TITULO3,TITULO4,TITULO5,TITULO6,TITULO7,
			IMPORTE1,IMPORTE2,IMPORTE3,IMPORTE4,IMPORTE5,IMPORTE6,IMPORTE7)
				
		VALUES(DECODE(xConcepto,'',vCargos.PADRON,xConcepto),vCargos.YEAR,vCargos.PERIODO,
			vCargos.RECIBO,TO_CHAR(xInicioPeVol,'YYYY'),'001',vCargos.TIPO_DEL_VALOR,
		      vCargos.DNI,xNOMBRE,vCargos.VIA,vCargos.CALLE,vCargos.NUMERO,vCargos.ESCALERA,vCargos.PLANTA,vCargos.PISO,
			vCargos.MUNICIPIO,vCargos.PROVINCIA,vCargos.COD_POSTAL,

			vCargos.CENTRO_GESTOR,vCargos.OFICINA_LIQUI,
			vCargos.N_ORDEN_VALOR,vCargos.N_CERTIFICACION,

		      xNumCargo,xFechaCargo,xVOL_EJE,
			xImporte,xCuota_Inicial,
			xFinPeVol,xInicioPeVol,
			RTRIM(vCargos.CLAVE_CONCEPTO),RTRIM(vCargos.Domi_Tributario),
			SUBSTR(RTRIM(xObjeto),1,1024),xTipoTributo,xFNotificacion,
			DECODE(xFNotificacion,NULL,'N','S'),
			xTitulo1,xTitulo2,xTitulo3,xTitulo4,xTitulo5,xTitulo6,xTitulo7,
			xImpo1,xImpo2,xImpo3,xImpo4,xImpo5,xImpo6,xImpo7);

	end loop;
		
END;
/

-- *************************************************************************************
-- Modificado: 14/02/2003. Lucas Fernández Pérez. Cambia el formato. 
-- Este proceso es sólo usado en burjassot. Pone la fecha de baja desde la aplicacion, y la que 
-- viene en el disco se guarda como fecha de resolución.

CREATE OR REPLACE PROCEDURE GRABAR_COBROS_BAJAS(
      xORGANISMO 		IN 	VARCHAR2,
      xDESCRIPCION 	IN 	VARCHAR2,
      xFechaBajaIngre	IN DATE
)
AS

   xCodOpe 	INTEGER;
   xError 	INTEGER;

   -- Recorre todos los recibos que se van a ingresar 
   -- (aquellos que coincide el nif y no estan ingresados ni dados de baja ya)
   CURSOR CTMP_COBROS IS SELECT IDVALOR,FECHA_COBRO FROM TMP_COBROS_BAJAS WHERE 
	NIF_OK='S' AND EXPE_OK='S' AND F_INGRESO_BD IS NULL AND F_BAJA_BD IS NULL AND ESTADO='C';
  
   -- Recorre todos los recibos que se van a dar de baja.
   -- (aquellos que coincide el nif y no estan ingresados ni dados de baja ya)
   CURSOR CTMP_BAJAS IS SELECT * FROM TMP_COBROS_BAJAS WHERE 
	NIF_OK='S' AND EXPE_OK='S' AND F_INGRESO_BD IS NULL AND F_BAJA_BD IS NULL AND ESTADO='A';

BEGIN


   -- Se ingresan los cobros
   FOR VCOBROS IN CTMP_COBROS LOOP

   	-- Genero un codigo de operacion.
   	CODIGO_OPERACION(xCodOpe);

	UPDATE VALORES SET CODIGO_OPERACION=xCodOpe
--	,VOL_EJE='V',RECARGO=0,F_APREMIO=NULL
	WHERE ID= VCobros.IDVALOR;

	-- Ingreso todos esos recibos
	MAKE_PAGO(xCodOpe,TO_DATE(VCobros.FECHA_COBRO,'YYYY/MM/DD'),xFechaBajaIngre,'N','N','VE');

   END LOOP;


   -- Se dan de baja los recibos
   FOR VBAJAS IN CTMP_BAJAS LOOP

	-- doy de baja el recibo, poniendo como fecha de resolucion la fecha del disco, y como fecha de baja la que
	-- ponga el usuario en la aplicación.
	MAKE_BAJA(VBajas.IDVALOR,'BA',xFechaBajaIngre,TO_DATE(VBajas.FECHA_BAJA,'YYYY/MM/DD'),
			xOrganismo,xDescripcion,xError);

   END LOOP;


END;
/

-- *************************************************************************************
-- Modificado: 14/02/2003. Lucas Fernández Pérez. Cambia el formato. 
-- Este proceso es sólo usado en burjassot donde el recibo identifica unívocamente al valor,
-- por lo que cambia el paso de parámetros del procedimiento, que antes consultaba por 
-- municipio,recibo,concepto,año y periodo.
--
CREATE OR REPLACE PROCEDURE FORMATO_TMP_COBROS_BAJAS
AS
   xNombreBD 	CHAR(40);
   xNIF_BD 		CHAR(10);
   xNIF_OK 		CHAR(1);
   xNIF_FORMAT 	CHAR(10);	
   xF_INGRESO	DATE;
   xFECHA_DE_BAJA	DATE;
   xIDValor		INTEGER;
   xIDExpe		INTEGER;
   xEstado		CHAR(7);
   xF_Diligencia DATE;
   xExpe_OK		char(1);

   CURSOR CTMP_COBROS_BAJAS IS SELECT NIF,RECIBO FROM TMP_COBROS_BAJAS 
	for update of NIF_FORMAT, NIF_BD, NOMBRE_BD, NIF_OK, EXPE_OK,F_INGRESO_BD, F_BAJA_BD, IDVALOR;

BEGIN

   FOR CTMP IN CTMP_COBROS_BAJAS LOOP
	
    xExpe_OK:='S';

    -- Busco en valores el recibo a cobrar o dar de baja
	begin
	   SELECT NOMBRE,NIF,F_INGRESO,FECHA_DE_BAJA,ID,EXPEDIENTE
		 INTO xNOMBREBD,xNIF_BD,xF_INGRESO, xFECHA_DE_BAJA,xIDValor,xIDExpe
		 FROM VALORES 
			WHERE RECIBO=CTMP.RECIBO;
		
	   EXCEPTION 	   -- El recibo no existe
		WHEN NO_DATA_FOUND THEN 
		 xNIF_BD:='';
		 xNombreBD:='';
		 xF_INGRESO:=NULL;
		 xFECHA_DE_BAJA:=NULL;
		 xExpe_OK:='N';
	end;

	IF xExpe_OK='S' THEN -- Existe el recibo en la aplicación, reviso si está fraccionado o en un expediente abierto.
		xExpe_OK:='N';
		begin
		   SELECT FECHA_DILIGENCIA,Estado INTO xF_Diligencia,xEstado
			 FROM Expedientes WHERE ID=xIDExpe;
	 	   -- El expediente no existe
			EXCEPTION
			WHEN NO_DATA_FOUND THEN 
		 	xExpe_OK:='S';
		end;
	
		IF ( (xExpe_OK='N') AND (xEstado<>'FRACCIO') AND (xF_DILIGENCIA IS NULL) ) THEN
			xExpe_OK:='S';
		END IF;
	END IF;
			
	-- Doy formato al NIF (quitandole el cero inicial que tienen muchos nifs)
	IF SUBSTR(CTMP.NIF,1,1)='0' THEN
		xNIF_FORMAT:=rtrim(SUBSTR(CTMP.NIF,2,10));
	ELSE 
		xNIF_FORMAT:=rtrim(SUBSTR(CTMP.NIF,1,10));
	END IF;

	
	-- Indico si hay coincidencia del NIF de la tabla temporal con el de la tabla VALORES
	IF trim(xNIF_BD)=trim(xNIF_FORMAT) THEN
		xNIF_OK:='S';
	ELSE
		xNIF_OK:='N';
	END IF;

	UPDATE TMP_COBROS_BAJAS SET 
		NIF_FORMAT=xNIF_FORMAT, NIF_BD=xNIF_BD, NOMBRE_BD=xNOMBREBD, NIF_OK=xNIF_OK, EXPE_OK=xExpe_OK,
		F_INGRESO_BD=xF_INGRESO, F_BAJA_BD=xFECHA_DE_BAJA, IDVALOR=xIDValor
	WHERE CURRENT OF CTMP_COBROS_BAJAS;

   END LOOP;

END;
/
-- *************************************************************************************
-- 10-03-2003. Lucas Fernández Pérez. Creado para ATECO
-- Inserta en IMAGENES_NOTI las imagenes que se indican en la tabla TMP_IMAGENES
-- correspondientes a Acuses de recibo de Relaciones de Notificaciones.
--	Necesita previamente la existencia de un directorio ORACLE que se llame IMAGENES
-- 	y que apunte a un único directorio donde se encuentren todas las imágenes.
-- 	Ejemplo de forma de crear el directorio : create directory imagenes as 'f:\fotos\'
-- 	El directorio ha de ser del servidor. Desde delphi se crea.Por lo tanto se debe ejecutar
--	desde el servidor.
-- Modificación: 25-01-2005. Lucas Fernández Pérez. Ahora es en NOTIFICACIONES donde se apunta 
--  a la imagen, antes era en IMAGENES_NOTI donde se apuntaba a un id de notificaciones de la relacion 
--  y orden determinados.
--
CREATE OR REPLACE PROCEDURE ProcImagenesNoti(
		xAYTO 		IN CHAR, 
		xN_RELACION IN CHAR,
		xGRABAACUSES IN CHAR,
		xFecha 		IN DATE,
		xAcuse 		IN CHAR,
		xTipo		IN CHAR)
AS
   F BFILE;
   xLOB BLOB;
   xID_IMAGEN INTEGER;

--   xCont INTEGER;
   xValor     INTEGER;
   
   cursor cIMAGENES IS SELECT * FROM TMP_IMAGENES WHERE ENTRA='S';
 
BEGIN
--	xCont:=0;
	FOR v_IMA IN cIMAGENES LOOP

		-- comprueba si la notificación tiene ya imagen asociada
		SELECT MAX(ID_IMAGEN_ACUSE1) into xID_IMAGEN FROM NOTIFICACIONES WHERE ID=v_IMA.ID_NOTI;
		
		-- Ninguno de los recibos de esa relacion y orden ha insertado en la tabla, por lo
		-- que se inserta. Esa tupla representa todos los recibos de esa relacion y orden
		if xID_IMAGEN IS NULL then
			
		    INSERT INTO IMAGENES_NOTI(AYTO,FICHERO_IMAGEN,IMAGEN)
			VALUES(xAYTO,v_IMA.ARCHIVO,Empty_Blob()) RETURNING ID INTO xID_IMAGEN;
		    
			UPDATE NOTIFICACIONES SET ID_IMAGEN_ACUSE1=xID_IMAGEN 
		    WHERE N_RELACION=xN_RELACION AND N_ORDEN=v_IMA.CODIGO AND TIPO_NOTI<>'VOL' ;
		    
		end if;
		commit;
		-- Obtengo la imagen para modificarla (for update). ID_NOTI debe ser el de la tupla
		-- que representa a todos los valores de esa relacion y orden.	
		SELECT IMAGEN INTO xLOB FROM IMAGENES_NOTI WHERE ID=xID_IMAGEN FOR UPDATE;

		F:=BFILENAME('IMAGENES',v_IMA.ARCHIVO);
		DBMS_LOB.FILEOPEN(F,DBMS_LOB.FILE_READONLY);
		DBMS_LOB.LOADFROMFILE(xLOB ,F,DBMS_LOB.GETLENGTH(F));
		DBMS_LOB.FILECLOSE(F);
		
		if xGRABAACUSES='S' then
			-- Se graba el acuse de la notificación.
			SELECT VALOR INTO xValor from notificaciones where id=v_IMA.ID_NOTI;
			WRITEACUSE(v_IMA.ID_NOTI,xValor,xFecha,xAcuse,'',xTipo,'V','');
		end if;
		
		-- Si saltan muchos errores, puede hacerse commit cada 100 inserciones
		-- xCont:=xCont+1; 
		--if xCont=100 then
		--	xCont:=0;
		--	commit;
		--end if;
	
	END LOOP;
	
END;
/

-- *************************************************************************************