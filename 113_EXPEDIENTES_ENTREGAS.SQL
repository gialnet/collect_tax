-- ---------------------------------------------------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.ROUNDS y cambios en el tipo de parametros de entrada a los procedim.
-- ---------------------------------------------------------------------------------------------
-- BASE
-- en funcion de la entrega que se realice sobre el expediente, levantaremos las cuentas
--
CREATE OR REPLACE PROCEDURE Cuantas_Cuentas_Levantar(
	xIDEXPE     	IN	INTEGER,
	xEntrega		IN	float,
	xDeuda		IN	float)
AS

--retenciones que no estan vencidas
CURSOR cCuentasNoVencidas IS
	select * FROM CUENTAS_LOTES
		WHERE IdEXPE=xIDEXPE 
		AND FECHA_RETENCION is not null
		and FECHA_RETENCION + 19 >= sysdate
		AND HECHO='N';

xSumaReteVencidas	float default 0;

BEGIN

-- las retenciones que ya estan vencidas 
select sum(IMPORTE_RETENIDO) into xSumaReteVencidas
	FROM CUENTAS_LOTES
		WHERE IdEXPE=xIDEXPE 
		AND FECHA_RETENCION is not null
		and FECHA_RETENCION + 19 < sysdate
		AND HECHO='N';
if xSumaReteVencidas IS NULL then
   xSumaReteVencidas:=0;
end if;

--Si la entrega es igual a la diferencia entre la deuda del expediente y las sumas de 
--las retenciones vencidas entonces hay que levantar todas las cuentas no vencidas.
--Ejemplo: Deuda del Expediente: 15000 pts; Retencion 1: 3000 No vencida;
--							  Retencion 2: 5000 Vencida
-- Siempre que realice una entrega de 10000 pts hay que levantar todas las cuentas no vencidas

if xEntrega = (xDeuda-xSumaReteVencidas) then

	--   levantar todas las cuentas no vencidas
      FOR v_CuentasNoVencidas IN cCuentasNoVencidas 
      LOOP
		LEVANTA_UNA_CUENTA(xIDEXPE,v_CuentasNoVencidas.NIF,
				v_CuentasNoVencidas.Entidad,
				v_CuentasNoVencidas.Oficina,
				v_CuentasNoVencidas.DC,
				v_CuentasNoVencidas.Cuenta,
				v_CuentasNoVencidas.ZONA,
				v_CuentasNoVencidas.LOTE);
      END LOOP;

end if;

--Si la entrega es igual a lo que queda sin retener
--Segun el ejemplo anterior: Estaria entregando 7.000 pts, no hay que levantar nada
--Si la entrega fuera por ejemplo de 9000 no levantaria nada y el usuario tomaria la decision

END;
/


/* ************************************************************************** */
/*BASE*/
CREATE OR REPLACE PROCEDURE CuantoPrinReca(
	xDeuda 	IN	float,
      xRn 		IN	float,
      xEntrega 	IN	float,
      xPrincipal 	IN	float,
      xRecargo 	IN	float,
      pPrinVal 	OUT	float,
      pRecaVal 	OUT	float
)
AS

xParticipa   float DEFAULT 0;
xEntrPar     float DEFAULT 0;
mParReca     float DEFAULT 0;

BEGIN

  /** porcentaje de participación en la deuda **/
  xParticipa := xRn * 100 / xDeuda;

  /* Calcular el importe de la entrega correspondiente a este valor*/
  xEntrPar := xParticipa * xEntrega / 100;

  /*reparto proporcional entre el principal y el recargo*/
  IF (xPrincipal > 0) THEN
     mParReca := Round(xRecargo * 100 / xPrincipal,2);
     mParReca := (mParReca + 100) / 100;
     pPrinVal := Round(xEntrPar / mParReca,2);
     pRecaVal := xEntrPar - pPrinVal;
  ELSE
     pPrinVal := 0;
     pRecaVal := xEntrPar;
  END IF;

end;
/

/****************************************************************************/
/*BASE*/
CREATE OR REPLACE PROCEDURE CuantoCostaDemora(
	xTotal 	IN	float,
      xTotalPa 	IN	float,
      xCostaspa 	IN	float,
      xDemorapa 	IN	float,
      xEntrega 	IN	float,
      pCOSTAS 	OUT	float,
      pDEMORA 	OUT	float
)
AS

ParaRepartir FLOAT;
PorParticipa FLOAT;

BEGIN

  pCOSTAS:=0;
  pDEMORA:=0;

  /*en que porcentaje participa este recibo*/
  PorParticipa:=xTotalpa*100/xTotal;

  /*cuanto hay para repartir entre los conceptos*/
  ParaRepartir:=PorParticipa*xEntrega/100;

  if xCostaspa > 0 then
     pCOSTAS:=xCostaspa*100/xTotalpa;
     pCOSTAS:=ParaRepartir*pCOSTAS/100;
  end IF;

  if xDemorapa > 0 then
     pDEMORA:=xDemorapa*100/xTotalpa;
     pDEMORA:=ParaRepartir*pDEMORA/100;
  end IF;

end;
/

/**************************************************************************************************************
xCodigoOperacion: Este parametro de salida nos sirve para realizar la carta de pago
Esta rutina primero agota proporcionalmente el principal y el recargo para luego terminar
con las costas y los intereses de demora proporcionalmente

Modificacion: 26-6-2002. Lucas Fernández Pérez. Si el expediente tiene recibos suspendidos 
 			  permite hacer la entrega del total pendiente (no es un ingreso
 			  total del expediente, éste debe quedarse abierto)
MODIFICACIÓN: 07/03/2003 Mª del Carmen Junco. En vez de usar el campo R_SUSPENDIDOS de la tabla
			  de expedientes, contamos si hay valores suspendidos o no directamente de la tabla
			  de VALORES. (Este cambio viene por un problema de Paco Bustos con la fiabilidad
			  del contenido de R_SUSPENDIDOS)
DELPHI
***************************************************************************************************************/
CREATE OR REPLACE PROCEDURE EXPE_ENTRE_PROPORCIONAL(
	xIDEXPE 		IN	INTEGER,
      xEntrega 		IN	FLOAT,
      xFECHA 		IN 	DATE,
	xFechaBanco		IN 	DATE,
      xID_CUENTA 		IN	INTEGER,
      xQuien 		IN	VARCHAR,
	xTipoIngreso	IN	CHAR,
      xCodigoOperacion 	IN 	INTEGER)

AS

SPRINCIPAL	FLOAT;
SRECARGO 	FLOAT;
SCOSTAS 	FLOAT;
SDEMORA 	FLOAT;

xPendiente 		float;
xCostas 		float;
xDemora 		float;
ParaPrin 		float;
ParaResto 		float;
xPrinPenRecaPen	float;
xTotalResto 	float;
xRecargo 		float;
xPrincipal 		float;
xTotalpa 		float;
pPrinVal 		float;
pRecaVal 		float;
xCostasPen 		float;
xDemoraPen 		float;
SumaPrinRecaPendi float;
xTOTALPENDIENTE 	FLOAT;
xEmbargo 		CHAR(1);
xFBanco		date;
xIngreso_Tramite	char(1);
xSUSPENDIDOS 	CHAR(1);

CURSOR cVALOR_EXPE IS
    SELECT ID
       FROM VALORES WHERE Expediente=xIDEXPE
            		  AND f_ingreso is null
		              AND fecha_de_baja is null
		              AND F_SUSPENSION IS NULL;

BEGIN

   --esto sucedera cuando se haga una entrega a cuenta desde ventanilla, como no podemos
   --enviar nulos en parametros de fecha, utilizamos este año
   if to_char(xFechaBanco,'yyyy')='1901' then
	xFBanco:=NULL;
   else
	xFBanco:=xFechaBanco;
   end if;

-- Ver el trámite donde está
SELECT EMBARGO_1 INTO xEMBARGO FROM EXPEDIENTES WHERE ID=xIDEXPE;

SELECT decode(count(*),0,'N','S') INTO xSUSPENDIDOS FROM VALORES WHERE EXPEDIENTE=xIDEXPE
AND F_SUSPENSION IS NOT NULL;

-- averiguar el total de la deuda en este instante 
-- Hay que mirar si se puede recalcular demora. Lo hace dentro del procedimiento Pendiente__expe.
    PkIngresos.PENDIENTE_EXPE(xIDEXPE,'S',xFECHA,
	sPRINCIPAL,sRECARGO,sCOSTAS,sDEMORA,xPENDIENTE);

-- Pendiente por principal mas recargo de todos los recibos pendientes 

SumaPrinRecaPendi:= sPRINCIPAL + sRECARGO;

-- Lo pendiente descontado el principal mas el recargo
xTotalResto := xPendiente - SumaPrinRecaPendi;

-- comprobar que no se esta intentando ingresar el total pendiente o mas 
-- si tiene recibos suspendidos permite hacer la entrega del total pendiente (no es un ingreso
-- total del expediente, éste debe quedarse abierto)
IF (xEntrega > xPendiente) OR (xEntrega=xPendiente and xSuspendidos='N') THEN
   raise_application_error(-20002,'El importe que está intentando retener es superior' ||
						' a la deuda del expediente.ID del expediente: '||xIDExpe);
END IF;

if (SumaPrinRecaPendi <= 0) then
      -- se ha cobrado todo el principal, se ingresa solo costas y demora 
      ParaPrin:=0;
      ParaResto:=xEntrega;
else
      -- aun queda principal y recargo 
	-- la entrega supera el principal + recargo
      if (SumaPrinRecaPendi-xEntrega) < 0 then
          --Se van a ingresar principal, recargo, costas y demora
          ParaResto := xEntrega - SumaPrinRecaPendi;
          ParaPrin := SumaPrinRecaPendi;
      else
          --Solo se van a cobrar principal y recargo
          ParaPrin:=xEntrega;
          ParaResto:=0;
      end IF;
4end IF;

-- detalle de cada valor del Expediente 

-- se hará un apunte a todos los valores pendientes del expediente en función
-- de la cuantia de su pendiente

FOR vVALOR_EXPE IN cVALOR_EXPE LOOP
  
     pPrinVal:=0;
     pRecaVal:=0;
     xCostasPen:=0;
     xDemoraPen:=0;

     PkIngresos.GET_PENDIENTE(vVALOR_EXPE.ID, xPrincipal, xRecargo,
                    xCostas, xDemora, xTotalPendiente);

     xTotalpa:=xCostas+xDemora;

     -- ********* parte del principal mas recargo ************* 

     xPrinPenRecaPen:=xPrincipal+xRecargo;

     -- siempre que quede principal o recargo aun pendiente

     if (xPrinPenRecaPen > 0) then
        CuantoPrinReca(SumaPrinRecaPendi,
                          xPrinPenRecaPen,ParaPrin,xPrincipal,xRecargo,
                          pPrinVal, pRecaVal);
     end if;

     -- ********* parte de las costas,demora *********** 

     if (ParaResto > 0) then
           -- si hay algo para entrar en el reparto
           if (xTotalpa > 0) then
              CuantoCostaDemora(xTotalResto, xTotalPa, xCostas, 
                                 xDemora, ParaResto, xCostasPen, 
                                 xDemoraPen);
           end IF;
     end IF; /* del ParaResto > 0 */

     -- ************ realizar el ingreso ************** 

     IF xFBanco IS NULL THEN
     	   PkIngresos.WRITE_INGRESO(vVALOR_EXPE.ID, xQuien, xTipoIngreso,
                   xFecha, pPrinVal, pRecaVal,
                   xCostasPen, xDemoraPen, xCodigoOperacion,'P');
     ELSE

	   --si el ingreso es de un embargo parcial de cuentas se pone el valor a 1 y sino a nulo
	   if xTipoIngreso='EP' then
		xIngreso_Tramite:='1';
	   else
		xIngreso_Tramite:='0';
	   end if;

	   PkIngresos.WRITE_INGRESO(vVALOR_EXPE.ID, xQuien, xTipoIngreso,
                   xFecha, pPrinVal, pRecaVal,
                   xCostasPen, xDemoraPen, xCodigoOperacion,'P',xFechaBanco,NULL,NULL,
			 null,xIngreso_Tramite);

     END IF;

END LOOP;

--si esta en el embargo de cuentas, realizar el levantamiento si se procediera
--Tambien se pone xID_CUENTA=0 porque desde las aplicaciones de embargos de cuentas parciales
--no haga nada aqui ya que se hace en los procedimientos de APLICAR_IMPORTE_RETENIDOS
if xEMBARGO='O' and xID_CUENTA=0 then
	Cuantas_Cuentas_Levantar(xIDEXPE,xENTREGA,xPENDIENTE);
end if;


   -- Anotarlo en el seguimiento del expediente
   if (xID_CUENTA<>0) then

   	PkSeguimiento.AnotaIngreso(xIDEXPE, xCodigoOperacion, xEntrega, xQuien, xID_CUENTA);

   else

  	PkSeguimiento.AnotaIngreso(xIDEXPE, xCodigoOperacion, xEntrega, xQuien);

   end if;

END;
/

/* ************************************************** */
--
-- Aplicar las entregas a las deudas por orden de antiguedad
--
/*BASE*/
CREATE OR REPLACE PROCEDURE APLICA_ENTREGA_ANTIGUEDAD
	(
	xIDEXPE 		IN	INTEGER,
      iEntrega 		IN	FLOAT,
      xFECHA 		IN 	DATE,
	xFechaBanco		IN 	DATE,
      xCodigoOperacion 	IN	INTEGER,
	xTipoIngreso	IN	CHAR,
      xQuien 		IN	VARCHAR)

AS

xEntrega 		float;
xIDValor 		integer default 0;
xIDPaga 		integer default 0;
xPAGO 		FLOAT DEFAULT 0;
xError		INTEGER;
xIngreso_Tramite	char(1);

-- Valores vivos del expediente

CURSOR cVALORES IS
   select ID,PENDIENTE
   from ValoresExpe
   where Expediente=xIDEXPE
         AND f_ingreso is null
         AND fecha_de_baja is null
         AND F_SUSPENSION IS NULL
   ORDER BY FIN_PE_VOL,ID;

BEGIN


xEntrega:=iEntrega;

-- Recorrer los valores desde el más antiguo hasta el más nuevo

FOR vVALORES IN cVALORES LOOP 

    -- Salirnos cuando hallamos agotado las entregas

    EXIT WHEN xENTREGA <= 0;

    -- Que el pendiente del recibo sea mayor de cero, osea que deba algo
    If vVALORES.Pendiente > 0 Then

       if (vVALORES.Pendiente > xEntrega) then
		-- Si la deuda es mayor que la entrega, nos quedamos con todo lo entregado
		-- para este recibo
          xPago:=xEntrega;
          xEntrega:=0;
          xIDValor:=vVALORES.ID;

       else

          xEntrega:=xEntrega - vVALORES.Pendiente;

          xIDPaga:=xCodigoOperacion;

		-- Marcamos las deudas que se van a dar por ingresadas
          UPDATE VALORES SET CODIGO_OPERACION=xCodigoOperacion
          WHERE ID=vVALORES.ID;

       end IF;
    end IF;

END LOOP;


  -- Nos indica si hay que pagar ALGUN valor 
  IF xIDPaga > 0 THEN    

	DAR_PAGADO_RECIBOS(xIDPaga, xFecha, xFechaBanco, xTipoIngreso, xQuien);

  END IF;


  IF xIDValor > 0 then

	--si el ingreso es de un embargo parcial de cuentas se pone el valor a 1 y sino a nulo
	if xTipoIngreso='EP' then
		xIngreso_Tramite:='1';
	else
		xIngreso_Tramite:=null;
	end if;

	ENTREGA_VALOR(xIDValor, xPago, xFECHA, xFechaBanco, xQUIEN, 
		xTipoIngreso, xCodigoOperacion, NULL,xIngreso_Tramite,xError);

  END IF;

END;
/

/*************************************************************************************************************
Entregas a cuenta de un expediente y que los importes obtenidos los aplique a los recibos por orden de 
antiguedad, en función se su vencimiento de periodo voluntario, más antiguo.

Modificacion: 26-6-2002. Lucas Fernández Pérez. Si el expediente tiene recibos suspendidos 
 			  permite hacer la entrega del total pendiente (no es un ingreso
 			  total del expediente, éste debe quedarse abierto)
MODIFICACIÓN: 07/03/2003 Mª del Carmen Junco. En vez de usar el campo R_SUSPENDIDOS de la tabla
			  de expedientes, contamos si hay valores suspendidos o no directamente de la tabla
			  de VALORES. (Este cambio viene por un problema de Paco Bustos con la fiabilidad
			  del contenido de R_SUSPENDIDOS)

DELPHI
**************************************************************************************************************/
CREATE OR REPLACE PROCEDURE EXPE_ENTRE_ANTIGUEDAD(
	xIDEXPE     	IN	INTEGER,
      xEntrega    	IN	FLOAT,
      xID_CUENTA  	IN	INTEGER,
      xFECHA      	IN 	DATE,
	xFechaBanco		IN 	DATE,
      xQuien      	IN	VARCHAR,
	xTipoIngreso	IN	CHAR,
      xCodigoOperacion 	IN	INTEGER)
AS
SPRINCIPAL	FLOAT;
SRECARGO 	FLOAT;
SCOSTAS 	FLOAT;
SDEMORA 	FLOAT;
xPendiente  FLOAT;
xEmbargo 	CHAR(1);
xSuspendidos CHAR(1);

BEGIN

-- Ver el trámite donde está
SELECT EMBARGO_1 INTO xEMBARGO FROM EXPEDIENTES WHERE ID=xIDEXPE;

SELECT decode(count(*),0,'N','S') INTO xSUSPENDIDOS FROM VALORES WHERE EXPEDIENTE=xIDEXPE
AND F_SUSPENSION IS NOT NULL;

-- averiguar el total de la deuda en este instante 
-- Hay que mirar si se puede recalcular demora. Lo hace dentro del procedimiento Pendiente__expe.
    PkIngresos.PENDIENTE_EXPE(xIDEXPE,'S',xFECHA,
	sPRINCIPAL,sRECARGO,sCOSTAS,sDEMORA,xPENDIENTE);


-- comprobar que no se esta  intentando ingresar el total pendiente o mas 
-- si tiene recibos suspendidos permite hacer la entrega del total pendiente (no es un ingreso
-- total del expediente, éste debe quedarse abierto)
IF (xEntrega > xPendiente) OR (xEntrega=xPendiente and xSuspendidos='N') THEN
   raise_application_error(-20002,'El importe que está intentando retener es superior' ||
						' a la deuda del expediente.ID del expediente: '||xIDExpe);
end if;
   
APLICA_ENTREGA_ANTIGUEDAD(xIDEXPE,xENTREGA,xFECHA, xFechaBanco,
                               xCodigoOperacion,xTipoIngreso,xQuien);

--si esta en el embargo de cuentas, realizar el levantamiento si se procediera
--Tambien se pone xID_CUENTA=0 porque desde las aplicaciones de embargos de cuentas parciales
--no haga nada aqui ya que se hace en los procedimientos de APLICAR_IMPORTE_RETENIDOS

if xEMBARGO='O' and xID_CUENTA=0 then
   Cuantas_Cuentas_Levantar(xIDEXPE,xENTREGA,xPENDIENTE);
end if;

-- Anotarlo en el seguimiento del expediente
if xID_CUENTA > 0 then

   PkSeguimiento.AnotaIngreso(xIDEXPE, xCodigoOperacion, xEntrega, xQuien, xID_CUENTA);

else

  PkSeguimiento.AnotaIngreso(xIDEXPE, xCodigoOperacion, xEntrega, xQuien);

end if;


END;
/

-- ****************************************************************************************
-- 
-- Acción: Esta rutina primero agota las costas del expediente, para luego ir ingresando por
-- 	 antiguedad sobre el principal,recargo y demora de los valores del expediente
-- 
-- Modificacion: 26-6-2002. Lucas Fernández Pérez. Si el expediente tiene recibos suspendidos 
--  		permite hacer la entrega del total pendiente (no es un ingreso
--  		total del expediente, éste debe quedarse abierto)
-- MODIFICACIÓN: 07/03/2003 Mª del Carmen Junco Gómez. En vez de usar el campo R_SUSPENDIDOS 
--			de la tabla	de expedientes, contamos si hay valores suspendidos o no directamente 
--			de la tabla	de VALORES. (Este cambio viene por un problema de Paco Bustos 
--			con la fiabilidad del contenido de R_SUSPENDIDOS)
-- MODIFICACIÓN: 10/03/2003 Mª del Carmen Junco Gómez. No se estaba realizando un reparto 
--			proporcional entre el principal y el recargo que se ingresaba para cada valor.
-- Modificado: 21/07/2003. Lucas Fernández Pérez. Se corrige una situación en la que una 
--			entrega	a un valor con importe menor que el pendiente, y con demora pendiente 0,
--			la reconocía como entrega total.
-- DELPHI
-- ****************************************************************************************************
CREATE OR REPLACE PROCEDURE EXPE_ENTRE_PRIMEROCOSTAS(
	xIDEXPE 		 IN	INTEGER,
    xEntrega 		 IN	FLOAT,
    xFECHA 			 IN	DATE,
	xFechaBanco		 IN	DATE,
    xID_CUENTA 		 IN	INTEGER,
    xQuien 			 IN	VARCHAR,
	xTipoIngreso	 IN	CHAR,
    xCodigoOperacion IN	INTEGER)

AS

SPRINCIPAL	FLOAT;
SRECARGO 	FLOAT;
SCOSTAS 	FLOAT;
SDEMORA 	FLOAT;

xPendiente 		float;
xTODOSCOSTAS	boolean;
xINGRESAR		boolean;
xCOBRO_TOTAL	boolean;
xImpEntrega		float;

xPrincipal 		float;
xRecargo 		float;
xCostas 		float;
xDemora 		float;
xTOTALPENDIENTE 	FLOAT;

xPrinVal 		float;
xRecaVal 		float;
xCostasVal 		float;
xDemoraVal 		float;
mParReca 		float default 0;

xEmbargo 		CHAR(1);
xFBanco		date;
xIngreso_Tramite	char(1);
xSuspendidos 	char(1);

CURSOR cVALOR_EXPE IS
    SELECT ID
       FROM VALORES WHERE Expediente=xIDEXPE
            		  AND f_ingreso is null
		              AND fecha_de_baja is null
		              AND F_SUSPENSION IS NULL
	ORDER BY FIN_PE_VOL,ID;

BEGIN

   --esto sucedera cuando se haga una entrega a cuenta desde ventanilla, como no podemos
   --enviar nulos en parametros de fecha, utilizamos este año
   if to_char(xFechaBanco,'yyyy')='1901' then
	xFBanco:=NULL;
   else
	xFBanco:=xFechaBanco;
   end if;

   -- Ver el trámite donde está
   SELECT EMBARGO_1 INTO xEMBARGO FROM EXPEDIENTES WHERE ID=xIDEXPE;
   
   SELECT DECODE(COUNT(*),0,'N','S') INTO xSUSPENDIDOS FROM VALORES WHERE EXPEDIENTE=xIDEXPE
   AND F_SUSPENSION IS NOT NULL;

   -- averiguar el total de la deuda en este instante 
   -- Hay que mirar si se puede recalcular demora. Lo hace dentro del procedimiento Pendiente__expe.
   PkIngresos.PENDIENTE_EXPE(xIDEXPE,'S',xFECHA,
   sPRINCIPAL,sRECARGO,sCOSTAS,sDEMORA,xPENDIENTE);

   -- comprobar que no se esta intentando ingresar el total pendiente o mas 
   -- si tiene recibos suspendidos permite hacer la entrega del total pendiente 
   -- (no es un ingreso total del expediente, éste debe quedarse abierto)
   IF (xEntrega > xPendiente) OR (xEntrega=xPendiente and xSuspendidos='N') THEN
   	raise_application_error(-20002,'El importe que está intentando retener es superior' ||
						' a la deuda del expediente.ID del expediente: '||xIDExpe);
   END IF;

   -- IMPORTANTE: Si la entrega supera la suma de las costas, lo indico con una variable.
   -- xImpEntrega: Si se cubren todas las costas, indica el resto que queda por entregar.
   xTODOSCOSTAS:=False;
   xImpEntrega:=xEntrega; -- Al principio el importe a entregar es el que se pasa como parametro
   IF xEntrega >= sCOSTAS THEN
	xTODOSCOSTAS:=True;
	xImpEntrega:=xImpEntrega-sCOSTAS; -- Y se descuentan las costas si se cubren todas
   END IF;


   -- se hará un apunte a todos los valores pendientes del expediente 
   FOR vVALOR_EXPE IN cVALOR_EXPE LOOP
  
     	xPrinVal:=0;
     	xRecaVal:=0;
     	xCostasVal:=0;
     	xDemoraVal:=0;
		xINGRESAR:=True;
		xCOBRO_TOTAL:=False;

     	PkIngresos.GET_PENDIENTE(vVALOR_EXPE.ID, xPrincipal, xRecargo,
                    xCostas, xDemora, xTotalPendiente);

     	IF xTODOSCOSTAS THEN -- Hay importe suficiente para pagar todas las costas 
	
	       xCostasVal:=xCostas;
	   	
	       -- El ingreso por costas es seguro,miro si tengo que ingresar algo mas  	       
  	       -- xImpEntrega indica el importe a ingresar por principal,recargo y demora.
	       if (xTotalPendiente-xCostas)<=xImpEntrega then -- Se puede pagar el valor entero.
	   
	          xImpEntrega:=xImpEntrega-(xTotalPendiente-xCostas);
	  	      xCOBRO_TOTAL:=True; 		   		 	

	       elsif xImpEntrega>0 then -- Es un cobro parcial
		      -- El principal+recargo del valor es mayor que la entrega
		      IF xImpEntrega >= (xPrincipal +xRecargo) THEN
		         xPrinVal:=xPrincipal;
		         xRecaVal:=xRecargo;
		         xImpEntrega:=xImpEntrega-xPrincipal-xRecargo;
		      ELSE 
		         if (xPrincipal > 0) then
		            --para obtener el grado de proporción
		            mParReca := xRecargo * 100 / xPrincipal;
		            mParReca := (mParReca + 100) / 100;
		            xPrinVal := Round ((xImpEntrega / mParReca),2);
		            xRecaVal := xImpEntrega - xPrinVal;
		         else
		            xPrinVal := 0;
		            xRecaVal := xImpEntrega;
		         end if;
		   
		         xImpEntrega:=0;
		      END IF;
		  
		      -- El resto del cobro (que puede ser 0 si no queda nada) va a la demora 
	   	      xDemoraVal:=xImpEntrega; 
		      xImpEntrega:=0;

	       elsif xImpEntrega=0 and xCostas=0 then -- No queda nada por ingresar
		      xINGRESAR:=false;

	       end if;

	    ELSE -- Si no hay importe en la entrega suficiente para cubrir todas las costas.
	    -- En este caso los ingresos a los valores serán sólo por costas.
	   	
	   		if xImpEntrega=0 or xCostas=0 then -- No queda nada por ingresar
				xINGRESAR:=false;

	   		elsif xImpEntrega>xCostas then -- Hay suficiente para pagar la costa completa.
				xCostasVal:=xCostas;
				xImpEntrega:=xImpEntrega-xCostas;

	   		else -- No hay suficiente para pagar la costa, ingreso la entrega completa.
				xCostasVal:=xImpEntrega;
				xImpEntrega:=0;
	   		end if;

		END IF;

    -- ************ realizar el ingreso ************** 
	-- Se tiene en cuenta si es por banco o no, si se tiene que ingresar y si es 
	-- un ingreso Parcial o Total del valor.

     	IF xFBanco IS NULL and xINGRESAR=True THEN
	   	  IF xCOBRO_TOTAL=True THEN
     	   	PkIngresos.WRITE_INGRESO(vVALOR_EXPE.ID, xQuien, xTipoIngreso,
                   xFecha, xPrincipal, xRecargo,
                   xCostas, xDemora, xCodigoOperacion,'C');
	   	  ELSE 
     	   	PkIngresos.WRITE_INGRESO(vVALOR_EXPE.ID, xQuien, xTipoIngreso,
                   xFecha, xPrinVal, xRecaVal,
                   xCostasVal, xDemoraVal, xCodigoOperacion,'P');
	   	  END IF;

     	ELSIF xINGRESAR=True THEN

	   	  --si el ingreso es de un embargo parcial de cuentas se pone el valor a 1 y sino a nulo
	   	  if xTipoIngreso='EP' then
			xIngreso_Tramite:='1';
	   	  else
			xIngreso_Tramite:='0';
	   	  end if;

	   	  IF xCOBRO_TOTAL=True THEN
			PkIngresos.WRITE_INGRESO(vVALOR_EXPE.ID, xQuien, xTipoIngreso,
              xFecha, xPrincipal, xRecargo,
              xCostas, xDemora, xCodigoOperacion,'C',xFechaBanco,NULL,NULL,
		  	  null,xIngreso_Tramite);
	   	  ELSE
			PkIngresos.WRITE_INGRESO(vVALOR_EXPE.ID, xQuien, xTipoIngreso,
              xFecha, xPrinVal, xRecaVal,
              xCostasVal, xDemoraVal, xCodigoOperacion,'P',xFechaBanco,NULL,NULL,
		  	  null,xIngreso_Tramite);
	   	  END IF;

     	END IF;

   END LOOP;

   --si esta en el embargo de cuentas, realizar el levantamiento si se procediera
   --Tambien se pone xID_CUENTA=0 porque desde las aplicaciones de embargos de cuentas parciales
   --no haga nada aqui ya que se hace en los procedimientos de APLICAR_IMPORTE_RETENIDOS
   if xEMBARGO='O' and xID_CUENTA=0 then
	Cuantas_Cuentas_Levantar(xIDEXPE,xENTREGA,xPENDIENTE);
   end if;

   -- Anotarlo en el seguimiento del expediente
   if (xID_CUENTA<>0) then

   	PkSeguimiento.AnotaIngreso(xIDEXPE, xCodigoOperacion, xEntrega, xQuien, xID_CUENTA);

   else

  	PkSeguimiento.AnotaIngreso(xIDEXPE, xCodigoOperacion, xEntrega, xQuien);

   end if;

END;
/
