-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez
-- No se han realizado cambios.
-- -----------------------------------------------------
CREATE OR REPLACE TRIGGER T_REGISTRO_PROPIEDAD
BEFORE INSERT ON REGISTROS_PROPIEDAD
FOR EACH ROW
BEGIN
   SELECT GEN_REGIS_PROPIEDAD.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_DESGLOCARGOS
BEFORE INSERT ON DESGLOSE_CARGOS
FOR EACH ROW
BEGIN
   SELECT GDESGLOSECARGOS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_FINCA
BEFORE INSERT ON FINCAS
FOR EACH ROW

BEGIN
   SELECT GENEFINCA.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_SUCURSALES
BEFORE INSERT ON SUCURSALES
FOR EACH ROW

BEGIN
   SELECT GENCUENT_SUCUR.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID
   WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_CUENTAS_SERVICIO
BEFORE INSERT ON CUENTAS_SERVICIO
FOR EACH ROW

BEGIN
   SELECT GENCUENT_C_SERVI.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID
   WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_MOD_CUENTAS_SERVICIO
AFTER UPDATE OF SALDO ON CUENTAS_SERVICIO
FOR EACH ROW

BEGIN
   UPDATE USUARIOS SET IMPORTE=:NEW.SALDO
   WHERE USUARIO=USER;
END;
/

/********************************************************************************************/


CREATE OR REPLACE TRIGGER T_INS_SALARIOS
BEFORE INSERT ON SALARIOS
FOR EACH ROW

BEGIN
   SELECT GENESALARI.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_SALARIOS;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_SEGUIMIENTO
BEFORE INSERT ON SEGUIMIENTO
FOR EACH ROW

BEGIN
   SELECT GENERSEGUI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_VEHI
BEFORE INSERT ON VEHICULOSR
FOR EACH ROW

BEGIN
   SELECT GENERVEHI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/


/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_INVITADO
BEFORE INSERT ON GUEST_EXPE
FOR EACH ROW

BEGIN
   SELECT GENEAUXEXP.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_BAJAS
BEFORE INSERT ON BAJAS
FOR EACH ROW

BEGIN
   SELECT GENERBAJAS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_MOD_ZONAS
AFTER UPDATE ON ZONAS
FOR EACH ROW

BEGIN
   -- si se trata de una data de ingresos
   IF :OLD.NUMERO_DATA<:NEW.NUMERO_DATA THEN
      UPDATE USUARIOS SET LAST_TAREA=:NEW.NUMERO_DATA,
                          YYEAR=:NEW.YEAR
      WHERE USUARIO=USER;
   END IF;

   -- si se trata de una data de bajas
   IF :OLD.NUMERO_DATA_BAJA<:NEW.NUMERO_DATA_BAJA THEN
	UPDATE USUARIOS SET LAST_TAREA=:NEW.NUMERO_DATA_BAJA,
				  YYEAR=:NEW.YEAR
	WHERE USUARIO=USER;
   END IF;

END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_PUNTEO
BEFORE INSERT ON PUNTEO
FOR EACH ROW

BEGIN
   SELECT GENPUNTEO.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_COSTASVAL
BEFORE INSERT ON COSTAS_VALORES
FOR EACH ROW

BEGIN
   SELECT GENERCOSTAS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

-- Este disparador está relacionado con write_ingresos para entidades
-- financieras en caso de modificarse ojo con las posibles repercusiones
-- se le pasan los valores a través de last_numero

CREATE OR REPLACE TRIGGER T_INS_MOV_CUENTAS
BEFORE INSERT ON MOV_CUENTAS
FOR EACH ROW

BEGIN
	SELECT GENCUENT_MOV_CUENT.NEXTVAL INTO :NEW.ID FROM DUAL;

	--sirve para el recalculo de saldos en los apuntes manuales en las cuentas.
	:NEW.COD_MOVIMIENTO:=:NEW.ID;

	UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID, LAST_BAJA=:NEW.CUENTA
	WHERE USUARIO=USER;

END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_ACUMULAR
BEFORE INSERT ON ACUMULAR
FOR EACH ROW

BEGIN
   SELECT GENACUMEXP.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_EMB_INMU
BEFORE INSERT ON EMBARGOS_INMUEBLES
FOR EACH ROW

BEGIN
   SELECT GENEINMU.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID
   WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_DATASINGRE
BEFORE INSERT ON DATAS_INGRESOS
FOR EACH ROW

BEGIN
   SELECT GENERDATAI.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_TERCEROS
BEFORE INSERT ON TERCEROS
FOR EACH ROW

BEGIN
   SELECT GENERTERCE.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_DATASBAJAS
BEFORE INSERT ON DATAS_BAJAS
FOR EACH ROW

BEGIN
   SELECT GENERDATAI.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_FRACCIONAMIENTO
BEFORE INSERT ON FRACCIONAMIENTO
FOR EACH ROW

BEGIN
   SELECT GENERFRAC.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID
   WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_PLAZOS_FRAC
BEFORE INSERT ON PLAZOS_FRAC
FOR EACH ROW

BEGIN
   SELECT GENERPFRAC.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID
   WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_EMBSAL
BEFORE INSERT ON EMBARGOS_SALARIOS
FOR EACH ROW

BEGIN
   SELECT GENEEMBSAL.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_EMB_AUTOS
BEFORE INSERT ON EMBARGOS_AUTOS
FOR EACH ROW
BEGIN
	SELECT EMB_AUTOS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_OTROS
BEFORE INSERT ON OTROS_TRAMITES
FOR EACH ROW

BEGIN
   SELECT GENEROTROS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_HSALDOCAJA
BEFORE INSERT ON HSALDOCAJA
FOR EACH ROW

BEGIN
   SELECT GENHSALCAJ.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER THSALDOCAJ
AFTER UPDATE ON SALDOCAJA
FOR EACH ROW

DECLARE

   xCOD	INTEGER;
   xTIPO	CHAR(1);

BEGIN

   SELECT CODIGO_OPERACION,EMBARGO
   INTO xCod,xTipo
   FROM USUARIOS WHERE USUARIO=USER;

   INSERT INTO HSALDOCAJA
      (ZONA,FECHA,CODOPE,TIPO_MOV,
       B500E,B200E,B100E,B50E,B20E,B10E,B5E,
       M2E,M1E,M50CENT,M20CENT,M5CENT,M2CENT,M1CENT,
       B10000P,B5000P,B2000P,B1000P,
       M500P,M200P,M100P,M50P,M25P,M10P,M5P,M1P)
   VALUES
      (:old.ZONA,:old.FECHA,xCOD,xTIPO,
       :old.B500E,:old.B200E,:old.B100E,:old.B50E,:old.B20E,:old.B10E,:old.B5E,
       :old.M2E,:old.M1E,:old.M50CENT,:old.M20CENT,:old.M5CENT,:old.M2CENT,:old.M1CENT,
       :old.B10000P,:old.B5000P,:old.B2000P,:old.B1000P,
       :old.M500P,:old.M200P,:old.M100P,:old.M50P,:old.M25P,:old.M10P,:old.M5P,:old.M1P);

END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_CAJAMOV
BEFORE INSERT ON CAJAMOV
FOR EACH ROW

BEGIN
   SELECT GENCAJAMOV.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_INDEBIDOS
BEFORE INSERT ON INGRESOS_INDEBIDOS
FOR EACH ROW

BEGIN

   SELECT INDEBIDOS.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/


/********************************************************************************************/

/* Trigger para crear una nueva tupla en la tabla historico_comision
	en el caso de que al modificar un municipio se cambie alguna comisión o
	en el caso de que se cambie la fecha de inicio de vigencia de las mismas.
*/
CREATE OR REPLACE TRIGGER T_INS_HISTORICO_COMISION
BEFORE UPDATE ON MUNICIPIOS
FOR EACH ROW
WHEN ( (OLD.TPC_VOL<>NEW.TPC_VOL) OR (OLD.TPC_EJE<>NEW.TPC_EJE) OR
   (OLD.TPC_RECARGO<>NEW.TPC_RECARGO) OR (OLD.TPC_DEMORA<>NEW.TPC_DEMORA)	OR
   (OLD.TPC_COSTAS<>NEW.TPC_COSTAS) OR (OLD.TPC_BAJAS_VOL<>NEW.TPC_BAJAS_VOL) OR
   (OLD.TPC_BAJAS_EJE<>NEW.TPC_BAJAS_EJE) OR (OLD.TPC_BAJAS_EJE_BR<>NEW.TPC_BAJAS_EJE_BR) OR
   (OLD.TPC_BAJAS_EJE_BI<>NEW.TPC_BAJAS_EJE_BI) OR (OLD.TPC_BAJAS_EJE_BP<>NEW.TPC_BAJAS_EJE_BP)
   OR (OLD.TPC_BAJAS_EJE_BO<>NEW.TPC_BAJAS_EJE_BO) OR (OLD.FECHA<>NEW.FECHA) )

DECLARE
	xTexto HISTORICO_COMISIONES.MOTIVO%TYPE;

BEGIN

	/* Se ha cambiado alguna comisión en el municipio. Se deben
	guardar los valores antiguos en el historico de comisiones */

	SELECT SUBSTR(TEXTO,1,100) INTO xTexto FROM USUARIOS WHERE USUARIO=USER;

	INSERT INTO HISTORICO_COMISIONES(AYTO,FECHA_INICIO,FECHA_FIN,
	TPC_VOL, TPC_EJE, TPC_RECARGO, TPC_DEMORA, TPC_COSTAS,
	TPC_BAJAS_VOL, TPC_BAJAS_EJE,
	TPC_BAJAS_EJE_BR, TPC_BAJAS_EJE_BI, TPC_BAJAS_EJE_BP, TPC_BAJAS_EJE_BO, MOTIVO)

	VALUES( :OLD.AYTO, :OLD.FECHA, :NEW.FECHA,
	:OLD.TPC_VOL, :OLD.TPC_EJE, :OLD.TPC_RECARGO, :OLD.TPC_DEMORA, :OLD.TPC_COSTAS,
	:OLD.TPC_BAJAS_VOL, :OLD.TPC_BAJAS_EJE, :OLD.TPC_BAJAS_EJE_BR,
	:OLD.TPC_BAJAS_EJE_BI, :OLD.TPC_BAJAS_EJE_BP, :OLD.TPC_BAJAS_EJE_BO,  xTexto);

END;
/

/********************************************************************/
CREATE OR REPLACE TRIGGER T_ADD_DOMIALTER
BEFORE INSERT ON DOMICILIOS_ALTERNATIVOS
FOR EACH ROW

BEGIN

	SELECT GENERDOMIALTER.NEXTVAL INTO :NEW.ID FROM DUAL;


END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_USUARIOS
BEFORE INSERT ON USUARIOS
FOR EACH ROW

BEGIN
  SELECT GEN_ID_USUARIOS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

--
-- Añadir un documento al seguimiento del expediente
--
CREATE OR REPLACE TRIGGER T_DOCSEGUI
BEFORE INSERT ON DOCS_SEGUIMIENTO
FOR EACH ROW

BEGIN
  SELECT GENDOCSSEGUI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_DILIGENCIAS_CUENTAS
BEFORE INSERT ON DILIGENCIAS_CUENTAS
FOR EACH ROW
BEGIN
   SELECT GENDiliCuentas.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_CONFIGURACION
BEFORE INSERT ON CONFIGURACION
FOR EACH ROW
BEGIN
   SELECT GENCONFIGURACION.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_RELA_BANCOS
BEFORE INSERT ON RELA_APLI_BANCOS
FOR EACH ROW
BEGIN
   SELECT GEN_RELA_BANCOS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_HISTO_SOPORTES
BEFORE INSERT ON HISTO_SOPORTES
FOR EACH ROW
BEGIN
   SELECT GHISTO_SOPORTES.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_INCIDENCIAS_C60
BEFORE INSERT ON INCIDENCIAS_C60
FOR EACH ROW
BEGIN
   SELECT GINCIDENCIAS_C60.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/
-- Trigger para crear una nueva tupla en la tabla historico_comision
--	en el caso de que se modifique alguna comisión de algún padron del municipio
--
CREATE OR REPLACE TRIGGER T_UPD_HISTO_COMISION_PADRON
BEFORE UPDATE ON COMISIONES_AYTO_PADRON
FOR EACH ROW
WHEN ( (OLD.TPC_VOL<>NEW.TPC_VOL) OR (OLD.TPC_EJE<>NEW.TPC_EJE) OR
   (OLD.TPC_RECARGO<>NEW.TPC_RECARGO) OR (OLD.TPC_DEMORA<>NEW.TPC_DEMORA)	OR
   (OLD.TPC_COSTAS<>NEW.TPC_COSTAS) OR (OLD.TPC_BAJAS_VOL<>NEW.TPC_BAJAS_VOL) OR
   (OLD.TPC_BAJAS_EJE<>NEW.TPC_BAJAS_EJE) OR (OLD.TPC_BAJAS_EJE_BR<>NEW.TPC_BAJAS_EJE_BR) OR
   (OLD.TPC_BAJAS_EJE_BI<>NEW.TPC_BAJAS_EJE_BI) OR (OLD.TPC_BAJAS_EJE_BP<>NEW.TPC_BAJAS_EJE_BP)
   OR (OLD.TPC_BAJAS_EJE_BO<>NEW.TPC_BAJAS_EJE_BO) OR (OLD.FECHA_INICIO<>NEW.FECHA_INICIO) )
DECLARE
	xTexto HISTORICO_COMISIONES.MOTIVO%TYPE;

BEGIN

	-- Se ha cambiado alguna comisión en el municipio-padron. Se deben
	-- guardar los valores antiguos en el historico de comisiones

	SELECT SUBSTR(TEXTO,1,100) INTO xTexto FROM USUARIOS WHERE USUARIO=USER;

	INSERT INTO HISTORICO_COMISIONES(AYTO,PADRON,FECHA_INICIO,FECHA_FIN,
	TPC_VOL, TPC_EJE, TPC_RECARGO, TPC_DEMORA, TPC_COSTAS,
	TPC_BAJAS_VOL, TPC_BAJAS_EJE,
	TPC_BAJAS_EJE_BR, TPC_BAJAS_EJE_BI, TPC_BAJAS_EJE_BP, TPC_BAJAS_EJE_BO, MOTIVO)

	VALUES( :OLD.AYTO, :OLD.PADRON, :OLD.FECHA_INICIO, :NEW.FECHA_INICIO,
	:OLD.TPC_VOL, :OLD.TPC_EJE, :OLD.TPC_RECARGO, :OLD.TPC_DEMORA, :OLD.TPC_COSTAS,
	:OLD.TPC_BAJAS_VOL, :OLD.TPC_BAJAS_EJE, :OLD.TPC_BAJAS_EJE_BR,
	:OLD.TPC_BAJAS_EJE_BI, :OLD.TPC_BAJAS_EJE_BP, :OLD.TPC_BAJAS_EJE_BO,  xTexto);
END;
/
/********************************************************************************************/
-- Trigger para crear una nueva tupla en la tabla historico_comision
--	en el caso de que se borre la comisión.
--
CREATE OR REPLACE TRIGGER T_DEL_HISTO_COMISION_PADRON
BEFORE DELETE ON COMISIONES_AYTO_PADRON
FOR EACH ROW
DECLARE
	xTexto HISTORICO_COMISIONES.MOTIVO%TYPE;

BEGIN

	-- Se ha cambiado alguna comisión en el municipio-padron. Se deben
	-- guardar los valores antiguos en el historico de comisiones

	SELECT SUBSTR(TEXTO,1,100) INTO xTexto FROM USUARIOS WHERE USUARIO=USER;

	INSERT INTO HISTORICO_COMISIONES(AYTO,PADRON,FECHA_INICIO,FECHA_FIN,
	TPC_VOL, TPC_EJE, TPC_RECARGO, TPC_DEMORA, TPC_COSTAS,
	TPC_BAJAS_VOL, TPC_BAJAS_EJE,
	TPC_BAJAS_EJE_BR, TPC_BAJAS_EJE_BI, TPC_BAJAS_EJE_BP, TPC_BAJAS_EJE_BO, MOTIVO)

	VALUES( :OLD.AYTO, :OLD.PADRON, :OLD.FECHA_INICIO, SYSDATE,
	:OLD.TPC_VOL, :OLD.TPC_EJE, :OLD.TPC_RECARGO, :OLD.TPC_DEMORA, :OLD.TPC_COSTAS,
	:OLD.TPC_BAJAS_VOL, :OLD.TPC_BAJAS_EJE, :OLD.TPC_BAJAS_EJE_BR,
	:OLD.TPC_BAJAS_EJE_BI, :OLD.TPC_BAJAS_EJE_BP, :OLD.TPC_BAJAS_EJE_BO,  xTexto);

END;
/

/********************************************************************/
CREATE OR REPLACE TRIGGER T_INS_SALARIOS_RETENCIONES
BEFORE INSERT ON SALARIOS_RETENCIONES
FOR EACH ROW
BEGIN
   SELECT GEN_SALARIOS_RETENCIONES.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************/
CREATE OR REPLACE TRIGGER T_INS_IMAGENES_NOTI
BEFORE INSERT ON IMAGENES_NOTI
FOR EACH ROW
BEGIN
   SELECT GEN_ID_IMAGENES_NOTI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************/
CREATE OR REPLACE TRIGGER T_INS_VEHICULOSR_IMG
BEFORE INSERT ON VEHICULOSR_IMG
FOR EACH ROW
BEGIN
   SELECT GENVEHIMG.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
