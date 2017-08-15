create or replace procedure Actu_Cuaderno60(xAyto in char)
as
	cursor cCuaderno60 is select recibo,NUM_CERTIFICADO,nif
		from datos_cuaderno60
			where ayto=xAyto;
begin

	for vCuaderno60 IN cCuaderno60 loop
	
			update valores set clave_concepto=vCuaderno60.NUM_CERTIFICADO,
					cert_descubierto=substr(vCuaderno60.recibo,3,8)
				where ayto=xAyto 
				and NIF=vCuaderno60.NIF;
	
	end loop;

end;
execute Actu_Cuaderno60('001');
execute Actu_Cuaderno60('002');
drop procedure Actu_Cuaderno60;

CREATE PUBLIC SYNONYM Ateco_Write_Acuse FOR GIALNET.Ateco_Write_Acuse;
--
--
--
CREATE OR REPLACE PROCEDURE Ateco_Write_Acuse
	(xRelacion			IN CHAR,
	 xNumeroCertificado	IN CHAR,
	 xFRecibi     		IN DATE,
       xAcuse       		IN CHAR,
       xTercero     		IN VARCHAR,
       xTipo        		IN CHAR,
	 xReferencia  		IN VARCHAR)

AS
	xPrimeraVez	integer default 0;
	xNoti 	char(1);
	xZona		char(2);
	CURSOR cValores is select id,nif,ayto
		from valores 
		where RELACION_APREMIO=xRelacion and Clave_Concepto=xNumeroCertificado;
BEGIN

      
	--xNoti: si esta notificado o no
	Select notificado into xNoti from tipo_acuses where Tipo=xTipo;

	UPDATE VALORES SET NOTIFICADO=xNOTI,F_NOTIFICACION=xFRECIBI
	WHERE RELACION_APREMIO=xRelacion and Clave_Concepto=xNumeroCertificado;


	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	FOR vValores IN cValores LOOP

		--siempre creara un expediente para hacer el embargo de cuentas, 
		--solo la primera vez
		IF xPrimeraVez=0 then
			APREMIADOS_A_EXPEDIENTE(vValores.NIF, vValores.AYTO, xZONA);
			xPrimeraVez:=1;
		end if;

		UPDATE notificaciones Set
			F_1ACUSE=xFRecibi, ACUSE1=xAcuse, TERCERO_1NOTIFI=xTercero, 
			NOTIFICADO=xNoti, F_NOTIFICACION=xFRecibi, F_LAST_ACUSE=xFRecibi,
			LAST_ACUSE=xAcuse, Referencia=xReferencia
	      WHERE valor=vValores.ID;
	END LOOP;
   
END;
/




CREATE PUBLIC SYNONYM Ateco_Anula_Acuse FOR GIALNET.Ateco_Anula_Acuse;

CREATE OR REPLACE PROCEDURE Ateco_Anula_Acuse
	(xRelacion			IN CHAR,
	 xNumeroCertificado	IN CHAR)
AS
	xRecibos	integer;
	xID		integer;
	CURSOR cValores is select id,expediente 
		from valores 
		where RELACION_APREMIO=xRelacion and Clave_Concepto=xNumeroCertificado
	for update of notificado,F_NOTIFICACION,Expediente,f_in_expediente;
BEGIN


	FOR vValores IN cValores LOOP

		update expedientes set recibos=recibos-1 where id=vValores.Expediente
		return recibos,ID into xRecibos,xID;

		UPDATE notificaciones Set 
			F_1ACUSE= NULL, ACUSE1= NULL, TERCERO_1NOTIFI = NULL, 
			NOTIFICADO = 'N',	F_NOTIFICACION = NULL, 
			F_LAST_ACUSE = NULL, LAST_ACUSE  = NULL,
			REFERENCIA = NULL, FICHERO_IMAGEN = NULL,	IMAGEN = NULL

	      WHERE valor=vValores.ID;

		UPDATE VALORES SET NOTIFICADO='N',F_NOTIFICACION=NULL,
			Expediente=null,f_in_expediente=null 
		where current of cValores;

	END LOOP;

	--si no quedan mas recibos borrar el expediente
	if xRecibos=0 then
		delete from seguimiento where id_expe=xID;
		delete from expedientes where id=xID;
	end if;
	
END;
/
