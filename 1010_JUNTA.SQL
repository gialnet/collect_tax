/******************************************************************************************
Autor: 12/09/2002 M. Carmen Junco Gómez.
Acción: Pasar las liquidaciones apremiadas de la Junta leidas del soporte subsistema 07
	  al Punteo de valores.
DELPHI

Modificado: 23/09/2002	Agustin Leon Robles
			Para recoger el codigo de la zona de las liquidaciones se busca en la tabla
			de municipios_junta.

Modificado: 07/11/2002 Lucas Fernández Pérez. Mete el recargo leido del disco en PUNTEO.
Modificado: 20/11/2002 Lucas Fernández Pérez. Mete en el campo CENTRO_GESTOR de la
	tabla PUNTEO el campo REFE_DIPU de la tabla tmp_detalle_tipo1. 
	Antes se metía en	CENTRO_GESTOR el campo ENVIO de la tabla tmp_detalle_tipo1, 
	y ahora se pone en el campo CERT_DESCUBIERTO de PUNTEO.
MODIFICACIÓN: 14/01/2003 Mª del Carmen Junco Gómez. Al principal no se le ha de restar
			  lo entregado fuera de plazo.
******************************************************************************************/

CREATE OR REPLACE PROCEDURE JUNTA_PASA_RECA(
	xN_CARGO 	IN	CHAR,
	xF_CARGO	IN	DATE,
	xERROR	OUT 	CHAR)
AS
   xAYTO   		  CHAR(3);
   xZONA		  CHAR(2);
   xPADRON          CHAR(6);
   xYEAR            CHAR(4);
   xCODPROVI        CHAR(2);
   xPROVINCIA       VARCHAR(35);
   xPOBLACION       VARCHAR(35);
   xCUOTA_INICIAL   FLOAT;
   xFueraPlazo	Float;
   xPRINCIPAL       FLOAT;
   xFIN_PE_VOL	  DATE;
   xTIPO_DE_TRIBUTO CHAR(2);	

   CURSOR CDETALLE IS SELECT * FROM TMP_DETALLE_TIPO1 WHERE PASA_A_PUNTEO='S' 
		ORDER BY N_ORDEN;

BEGIN

   xERROR:=0;

   -- recogemos el código provincia de la Diputación desde el registro de cabecera
   begin
	SELECT COD_PROVINCIA_DELEG INTO xCODPROVI FROM TMP_CABECERA_SUR_07;
   exception
	when no_data_found then
	   xERROR:=1;
	   return;
   end;

   FOR v_Detalle IN CDETALLE
   LOOP


	-- para recoger el concepto de la liquidacion hacemos uso de la tabla
	-- conceptos_relacion, que relaciona los conceptos de la junta con los propios
	-- dados de alta en nuestra BD.
	begin
		SELECT CONCEPNEW INTO xPADRON FROM CONCEPTOS_RELACION 
		WHERE CONCEPTO=v_Detalle.COD_CONCEPTO;
   	exception
	   when no_data_found then
	   	xERROR:=3;
	   	return;
   	end;

	-- recogemos el año de dos dígitos y lo convertimos a un año de cuatro dígitos
	IF v_Detalle.YEAR_LIQUI>80 THEN
	   xYEAR:='19'||v_Detalle.YEAR_LIQUI;
	ELSE
	   xYEAR:='20'||v_Detalle.YEAR_LIQUI;
	END IF;

	-- recogemos la provincia del domicilio fiscal a partir del código de ésta y
      -- utilizando la tabla COD_PROVINCIAS
	begin
	   SELECT PROVINCIA INTO xPROVINCIA FROM COD_PROVINCIAS 
	   WHERE CODPROV=v_Detalle.COD_PROVINCIA;
   	exception
	   when no_data_found then
	   	xERROR:=4;
	   	return;
   	end;


	-- para saber que municipio de la junta le pertenece a la liquidación 
	-- utilizamos el código de localidad. Comprobamos a que zona corresponde
	-- y le asignamos el municipio de la Junta asociado a esa zona

	-- recogemos la localidad del domicilio fiscal a partir del código de ésta y
      -- utilizando la tabla MUNICIPIOS_JUNTA
	begin
		SELECT ZONA,LOCALIDAD INTO xZONA,xPOBLACION FROM MUNICIPIOS_JUNTA
		WHERE CODPROV=v_Detalle.COD_PROVINCIA AND CODLOCA=v_Detalle.COD_LOCALIDAD;
		
		if xZONA is null then
			xERROR:=2;
		   	return;
		else
			xAYTO:='J'||xZONA;
		end if;
   	exception
	   when no_data_found then
	   	xERROR:=5;
	   	return;
   	end;

	xCUOTA_INICIAL:=TO_NUMBER(v_Detalle.PRINCIPAL)/100;
	xPRINCIPAL:=xCUOTA_INICIAL;
	xFueraPlazo:=TO_NUMBER(v_Detalle.INGRESADO_FUERA_PLAZO)/100;	

	-- la fecha de final de periodo voluntario viene en el formato 'AAAAMMDD'
	-- se ha de pasar a un tipo date

	xFIN_PE_VOL:=TO_DATE(SUBSTR(v_Detalle.F_FIN_PE_VOL,7,2)||'/'||
				   SUBSTR(v_Detalle.F_FIN_PE_VOL,5,2)||'/'||
				   SUBSTR(v_Detalle.F_FIN_PE_VOL,1,4),'DD/MM/YYYY');	

	-- el tipo de tributo dependerá de la información del tipo de deuda
	-- si es 'T' tributaria el tipo de tributo será 'IM'
	-- si es 'N' No tributaria el tipo de tributo será 'NO'
	IF v_Detalle.TIPO_DEUDA='N' THEN
		xTIPO_DE_TRIBUTO:='NO';
	ELSE
		xTIPO_DE_TRIBUTO:='IM';
	END IF; 

	INSERT INTO PUNTEO
	   (PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,AYTO,
	    CLAVE_CONCEPTO,CERT_DESCUBIERTO,CENTRO_GESTOR,OFICINA_LIQUI,YEAR_CONTRAIDO,
	    NIF,NOMBRE,VIA,CALLE,
	    NUMERO,ESCALERA,PLANTA,
	    PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,CLAVE_EXTERNA,
	    CUOTA_INICIAL,ENTREGAS_A_CUENTA,PRINCIPAL,RECARGO,VOL_EJE,F_CARGO,N_CARGO,
	    FIN_PE_VOL,DOM_TRIBUTARIO,OBJETO_TRIBUTARIO,TIPO_DE_TRIBUTO)
	VALUES
	   (xPADRON,xYEAR,'00',TO_NUMBER(v_Detalle.N_ORDEN),'L',xAYTO,
	    v_Detalle.N_LIQUI_SUR,v_Detalle.ENVIO,substr(v_Detalle.REFE_DIPU,1,6),xCODPROVI,xYEAR,
	    v_Detalle.NIF_DEUDOR,v_Detalle.NOMBRE,v_Detalle.VIA,v_Detalle.CALLE,
	    SUBSTR(v_Detalle.NUMERO,1,3),v_Detalle.ESCALERA,v_Detalle.PISO,
	    v_Detalle.PUERTA,xPOBLACION,xPROVINCIA,v_Detalle.COD_POSTAL_DOMI,v_Detalle.CLAVE,
	    xCUOTA_INICIAL, xFueraPlazo, xPRINCIPAL,TO_NUMBER(v_Detalle.RECARGO)/100,
	    'E',xF_CARGO,xN_CARGO,xFIN_PE_VOL,v_Detalle.DOMICILIO_TRIBUTARIO,
	    v_Detalle.OBJETO_TRIBUTARIO,xTIPO_DE_TRIBUTO); 

   END LOOP;
END;
/

--
-- Creación: 09/10/2002 Antonio Pérez Caballero
--
--
CREATE OR REPLACE PROCEDURE JuntaResultadosGestion(
		xFECHA1 IN DATE,
		xFECHA2 IN DATE)
AS
BEGIN


PkJuntaResult.MAIN(xFECHA1, xFECHA2);

END;
/


--
-- Creación: 09/10/2002 Antonio Pérez Caballero
-- Datos de entregas a cuenta no incluidas en esta liquidación
-- también el importe neto ya transferido por datas no aceptadas
--
CREATE OR REPLACE PROCEDURE JuntaResultadosPendiente(
		xDelegacion IN Char,
		xNoIncluido IN FLOAT,
		xNoAceptado IN FLOAT)
AS
BEGIN


INSERT INTO JUNTA_NOACEPTADO(DELEGACION, ACUENTA_NOENSOPORTE, TRANSFE_NOACEPTADO)
VALUES
	(xDelegacion, Round(xNoIncluido, 2), Round(xNoAceptado, 2) );


END;
/

--
-- Limpiar los datos de las tablas temporales para iniciar una nueva liquidación
--
CREATE OR REPLACE PROCEDURE JuntaResultadosLimpiar(xAceptado IN Char)
AS
BEGIN

IF xAceptado='S' THEN
   DELETE FROM JUNTA_NOACEPTADO;
END IF;

DELETE FROM JUNTA_RESULT_T0;

DELETE FROM JUNTA_RESULT_T1;

DELETE FROM JUNTA_RESULT_T2;

DELETE FROM JUNTA_RESULT_T3;

DELETE FROM JUNTA_RESULT_T7;

DELETE FROM JUNTA_ANEXO1;

END;
/


--
-- Borrar los datos referentes a una delegación en concreto
--
CREATE OR REPLACE PROCEDURE JuntaResultadosBorra(xDelegacion IN Char)
AS
BEGIN


DELETE FROM JUNTA_NOACEPTADO Where Delegacion=xDelegacion;


END;
/

