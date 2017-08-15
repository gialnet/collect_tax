CREATE OR REPLACE PROCEDURE DelDiligencias
AS

CURSOR cEmbargo_Borra IS
SELECT * FROM EMBARGOS_CUENTAS
WHERE LOTE='2002/00101' 
AND IDEXPE IN (SELECT ID FROM EXPEDIENTES WHERE F_INGRESO IS NULL)
and idexpe in (SELECT IDEXPE FROM CUENTAS_LOTES where entidad='0030' and diligencia='S');
		 
BEGIN

	delete from seguimiento 
	where id_retenido_cuenta in (SELECT ID FROM CUENTAS_LOTES where entidad='0030' and diligencia='S');

   FOR v_EMB IN cEmbargo_Borra LOOP

      update Expedientes set FECHA_DILIGENCIA=NULL
      where ID=v_EMB.IDExpe
	      AND EN_OTROTRAMITE='N';

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

	delete from diligencias_cuentas where zona='00' 
				and lote='2002/00101' 
				and entidad='0030' 
				and fecha_envio=to_date('09/06/2003','dd/mm/yyyy');

END;
/