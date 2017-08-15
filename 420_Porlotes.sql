-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/* para comenzar trabajos de la base de datos, no de usuario (no nos interesa que
   esté almacenado en la tabla TRABAJOS_USUARIOS
*/
CREATE OR REPLACE PROCEDURE SUBMITBEGINJOB(
	xProcTrabajo in Char)
as
   xTrabajo BINARY_INTEGER;
begin
   DBMS_JOB.submit(xTrabajo,xProcTrabajo+';',sysdate,sysdate+1);
end;
/


create OR REPLACE procedure SubmitBeginPrela(
	xFecha IN Date,
	xCargo IN Char,
	xAyto In Char)

as
xTrabajo BINARY_INTEGER;
begin

DBMS_JOB.submit(xTrabajo,'COMIENZA_PRELACION2(1);', xFecha, Null, False);

INSERT INTO TRABAJOS_USUARIOS( N_TRABAJO, TRABAJO, USUARIO, F_INICIO, 
			PARAM_CHAR1,PARAM_CHAR2,CICLICO)

	VALUES (xTrabajo,'COMIENZA_PRELACION2(1);',USER, xFecha,
			xCargo, xAyto,'NULL');

end;
/


create OR REPLACE procedure SubmitGrafiPendiente(xFecha IN Date)

as
xTrabajo BINARY_INTEGER;
begin


DBMS_JOB.submit(xTrabajo,'DATOS_ESTADISTICOS(1);', xFecha, Null, False);

INSERT INTO TRABAJOS_USUARIOS(N_TRABAJO,TRABAJO,USUARIO,F_INICIO,CICLICO)
	VALUES (xTrabajo,'DATOS_ESTADISTICOS(1);',USER, xFecha, 'NULL');

end;
/

/*BASE*/
CREATE OR REPLACE PROCEDURE COMIENZA_PRELACION2(xNada IN Int)
AS

xCargo		char(10);
xAyto			char(3);
xUsuario		char(30);
xN_Trabajo		TRABAJOS_USUARIOS.N_TRABAJO%TYPE;
xF_Inicio		TRABAJOS_USUARIOS.F_INICIO%TYPE;
xCiclico		TRABAJOS_USUARIOS.CICLICO%TYPE;

CURSOR VALOR_ID IS
    SELECT NIF FROM VALORES
    where N_CARGO=xCargo 
	AND AYTO=xAYTO 
	and Expediente is null
      and F_ingreso is null 
	and FECHA_DE_BAJA is null
      and F_SUSPENSION is null 
	and Notificado='S' 
	and vol_eje='E'
	GROUP BY NIF;


BEGIN


	/* Se busca la tarea a ejecutar en la tabla trabajos_usuarios */
	/* El orden de ejecucion de las tareas de la tabla es :
		1º: Nivel de Prioridad (0 máxima, 9 mínima)
		2º: Fecha de disparo de la tarea
		3º: Identificador de tarea (para casos de igual prioridad y fecha)

		Para esto se hacen dos joins entre la tabla de trabajos_usuarios y la de
	trabajos pendientes de la BD. 
		- El primero es para que salga una sola tupla mínima y no el minimo para cada 
			trabajo. 
		- El segundo es para que no devuelva como minima una tupla no real creada
			por el join.
	Este select devuelve una única tupla.
	*/
  SELECT T.N_TRABAJO, RTRIM(T.USUARIO), F_INICIO, RTRIM(T.PARAM_CHAR1),RTRIM(T.PARAM_CHAR2), T.CICLICO 
	INTO xN_Trabajo, xUsuario, xF_Inicio, xCargo, xAyto, xCiclico
	FROM TRABAJOS_USUARIOS T, USER_JOBS U
	WHERE T.N_TRABAJO=U.JOB AND 
		(T.PRIORIDAD||TO_CHAR(U.NEXT_DATE,'yyyy/mm/dd, hh24:mi:ss')||T.N_TRABAJO) 
	IN (SELECT 
		MIN(T2.PRIORIDAD||TO_CHAR(U2.NEXT_DATE,'yyyy/mm/dd, hh24:mi:ss')||T2.N_TRABAJO)
			FROM TRABAJOS_USUARIOS T2, USER_JOBS U2
			WHERE T2.N_TRABAJO=U2.JOB AND T2.TRABAJO='COMIENZA_PRELACION2(1);');


  COMIENZA_PRELACION(xCARGO,xAYTO,xUSUARIO);

  IF (xCiclico='NULL') THEN /* Si no cicla, se elimina la información de trabajos_usuarios */	
	DELETE FROM TRABAJOS_USUARIOS WHERE N_TRABAJO=xN_Trabajo;

  ELSE /* Si cicla, se rebaja la prioridad de la tarea en TRABAJOS_USUARIOS */
	UPDATE TRABAJOS_USUARIOS SET PRIORIDAD='9' WHERE N_TRABAJO=xN_Trabajo;
  END IF;

END;
/


--
-- 26/02/2002 Antonio Pérez Caballero
--
-- Agente que controla los expedientes que están en otros trámites sin hacer nada
-- con ellos
--
CREATE OR REPLACE PROCEDURE AgenteExpeOtrosSinMov
AS

xFMAX DATE;
xMESES INTEGER;
xUMBRAL INTEGER;
xPROPUESTA CHAR(1);
-- Expedientes en otros trámites en el pendiente o en activo

CURSOR cOTROS IS
SELECT ID,F_EMBARGO,NOCUENTAS,NOSALARIOS,NOINMUEBLES,NOAUTOS FROM EXPEDIENTES 
	WHERE EMBARGO='X'
	AND f_ingreso is null 
	AND f_anulacion is null 
	AND f_suspension is null;

BEGIN

-- Leer el umbral de meses sin actividad
-- Leer el si las propuestas de crecitos incobrables son automáticas
SELECT UMBRAL_OTROS_TRAMITES,PROPUESTA_INSOLVENCIA INTO xUMBRAL,xPROPUESTA
	FROM CONFIGURACION WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

FOR v_cOTROS IN cOTROS LOOP

    SELECT MAX(F_ACTUACION) INTO xFMAX FROM SEGUIMIENTO 
	WHERE ID_EXPE=v_cOTROS.ID;

    -- Número de meses desde el último apunte en el seguimiento y hoy
    xMESES:=TRUNC(MONTHS_BETWEEN(SYSDATE, xFMAX));

    IF  xMESES > xUMBRAL THEN

        PkSeguimiento.AnotaTramiteNegativo(v_cOTROS.ID,'Sin datos de otros trámites, apunte automático del agente','X',sysdate);

	  -- Si la propuesta es automática la realizamos
	  IF xPROPUESTA='S' THEN

		-- Si el resto de los trámites fueron negativos
		IF v_cOTROS.NOCUENTAS='S' AND v_cOTROS.NOSALARIOS='S'
			AND v_cOTROS.NOINMUEBLES='S' AND v_cOTROS.NOAUTOS='S' THEN

               BajasExpedienteIncoUno(v_cOTROS.ID, 'BI');

		END IF;

	  END IF;
    END IF;

END LOOP;

END;
/

--
-- 26/02/2002 Antonio Pérez Caballero
--
-- Agente que controla los expedientes que están en Salarios y no han pagado
--
CREATE OR REPLACE PROCEDURE AgenteExpeSalarioNoPaga
AS


xFecha DATE;
xDia   INTEGER;
xZona  Char(2);

CURSOR cSALA IS
SELECT IDEXPE AS ID, EXPEDIENTE, S.NIF, NOMBRE, LAST_RETENCION
FROM EMBARGOS_SALARIOS S,CONTRIBUYENTES C 
WHERE S.NIF=C.NIF
AND ZONA=xZona
AND (LAST_RETENCION<=xFecha OR LAST_RETENCION IS NULL);

CURSOR cZONAS IS 
SELECT ZONA FROM ZONAS;

BEGIN

-- Los días cinco del mes preguntaremos por los vencimientos del día 20 del anterior
-- Los días 20 del corriente preguntaremos por los del día 5 del corriente

xDia:=to_char(sysdate, 'dd');

IF xDia=5 THEN
	
   xFecha:=TO_DATE('20/'||TO_CHAR(SYSDATE,'MM')||'/'||TO_CHAR(SYSDATE,'YYYY'),'DD/MM/YYYY');
   xFecha:=add_months(xFecha,-1);

END IF;

IF xDia=20 THEN
	
   xFecha:=TO_DATE('05/'||TO_CHAR(SYSDATE,'MM')||'/'||TO_CHAR(SYSDATE,'YYYY'),'DD/MM/YYYY');

END IF;


IF xDia=5 or xDia=20 THEN

   FOR v_cZONAS IN cZONAS LOOP

	xZona:=v_cZONAS.ZONA;

	FOR v_cSALA IN cSALA LOOP

	  -- LLenar una variable con los datos
	  INSERT INTO tmpSalariosNoPagados (ZONA,ID,EXPEDIENTE,NIF,NOMBRE)
		VALUES (xZONA, v_cSALA.ID,v_cSALA.EXPEDIENTE,v_cSALA.NIF,v_cSALA.NOMBRE);
	
	END LOOP;

	-- Si hubo datos
	-- enviar el correo eléctronico

   END LOOP;

END IF;

END;
/

