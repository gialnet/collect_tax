-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

--
-- Para encapsular los calculos de los intereses de demora
--
--
--
CREATE OR REPLACE PACKAGE PkDemora
AS

-- Calcula el interes de demora sobre una cantidad desde la fecha de fin de Voluntaria (+1995)
-- hasta la fecha de pago.
PROCEDURE INT_VARIABLE(
		mFechaPagoC IN DATE,
		mFinPeVolC  IN DATE,
		mTT 	      IN CHAR,
		mPrincipal  IN Float,
		Intereses   OUT float);

-- Calcula el interes sobre un importe del año en el que esta la fecha de pago
PROCEDURE InteresesYearIngreso(
	mFechaPago IN Date, 
	mImporte   IN Float,
	mTT	     IN Char,
	xINTERESES  OUT Float);

-- Calcula el interes del año en el que esta la fecha de fin del periodo voluntario
PROCEDURE InteresesPrimerTramo(
	mFinPeVol IN Date, 
	mImporte   IN Float,
	mTT	     IN Char,
	xINTERESES  OUT Float);

-- Calcula el interes de demora sobre una cantidad de un conjunto de años completos.
PROCEDURE InteresYearsCompletos(
	YDesde 	In Int,
	YHasta 	In Int,
	mImporte 	In Float,
	mTT	     	IN Char,
	xDemora	OUT Float);

-- Calcula el interes de demora sobre una cantidad cuando el FinPeVoluntario es anterior a 1995.
-- Los calcula siempre hasta el año 1995, que se incluye completo en el calculo de la demora.
PROCEDURE FIJO95(
		mFinPeVolC IN DATE,
		mTT        IN CHAR,
		mPrincipal IN Float,
		Intereses  OUT float);

-- Calcula el interes de demora sobre una cantidad desde 1996 hasta la fecha de pago.
PROCEDURE VARIABLE95(
		 mFechaPago IN DATE,
		 mFinPeVol  IN DATE,
		 mTT         IN CHAR,
		 mPrincipal  IN float,
		 Intereses   OUT float);

-- Calcula el interes diario de un importe en el año actual
PROCEDURE INTERES_DIARIO_VALOR(
	mPrincipal 	IN	float,
      Tipo_Valor 	IN	char,
      intereses 	OUT	float);

END;
/


CREATE OR REPLACE PACKAGE BODY PkDemora
AS

/*****************************************************************************************/
-- Se utiliza para todos aquellos valores que su final del periodo voluntario fuera
-- superior al año 1995 en que la formula del calculo de interesers de demora
-- paso de ser el tipo al que correspondiera en el final del periodo voluntario
-- para pasar a ser el que corresponda a cada periodo a calcular tramo del 96 al tipo
-- del 96 para el 97 igualmente y así sucesivamente
/*BASE*/
PROCEDURE INT_VARIABLE(
		mFechaPagoC IN DATE,
		mFinPeVolC  IN DATE,
		mTT 	      IN CHAR,
		mPrincipal  IN Float,
		Intereses   OUT float)

AS

mFECHAPAGO	 	DATE;
mFINPEVOL 		DATE;
YearFin 		integer;
YearPago 		integer;
mDemora 		float;
MaxServ 		float;
MaxImp 		float;
xIntePrimerTramo 	float;
xInteYearIngre 	float;
NumeroDeYears 	int;
NumeroDias 		integer;

BEGIN


-- Si no hay principal no hay nada que calcular
	IF (mPrincipal<=0) THEN
         Intereses:=0;
	   return;
	end if;

	INTERESES := 0;
	mFECHAPAGO := mFECHAPAGOC;
	mFINPEVOL := mFINPEVOLC;
	YearPAGO:=F_Year(mFECHAPAGO);

	-- proteger el codigo de tal forma que si no hay tuplas
	-- no aborte el procedimiento
	begin
        SELECT SERVICIOS,IMPUESTOS Into MaxServ,MaxImp from IntDemoraY       
        WHERE ANNO=YearPAGO;

	EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	  	SELECT SERVICIOS,IMPUESTOS Into MaxServ,MaxImp from IntDemoraY       
        	WHERE ANNO=(select max(anno) from IntDemoraY);	
	end;

	-- calcular el número de años
	YearFin:=F_Year(mFinPeVol);
	YearPago:=F_Year(mFechaPago);
	NumeroDeYears:=YearPago-YearFin;

	-- si es solo para días
	IF (NumeroDeYears < 1) THEN
         NumeroDias:=DayOfYear(mFechaPago) - DAYOFYEAR(mFinPeVol);
         if (mTT<>'NO') then
            Intereses:=NumeroDias * (MaxImp * mPrincipal /100 ) / 365;
         else
            Intereses:=NumeroDias * (MaxServ * mPrincipal /100 ) / 365;
         end if;

         return;
	end if;

	-- número de días desde el final del periodo voluntario hasta final del mimo año
	InteresesPrimerTramo(mFinPeVol, mPrincipal, mTT, xIntePrimerTramo);

	-- número de días transcurridos del año de ingreso
	InteresesYearIngreso(mFechaPago, mPrincipal, mTT, xInteYearIngre);

      mDemora:=0;

      IF ((YearPago-YearFin) >= 2) THEN
   		InteresYearsCompletos(YearFin+1, YearPago, mPrincipal, mTT, mDemora);
      END IF;

      Intereses:= mDemora + xIntePrimerTramo + xInteYearIngre;

END;


-- Calcula los intereses de los días transcurridos del año de ingreso
/*INTERNO*/
PROCEDURE InteresesYearIngreso(
	mFechaPago 	IN Date, 
	mImporte   	IN Float,
	mTT	     	IN Char,
	xINTERESES  OUT Float)
as

mSer 		float;
mImp 		float;
YearPago 	integer;
NumeroDias 	integer;

begin

	xINTERESES:=0;
	YearPago:=F_Year(mFechaPago);

	-- proteger el codigo de tal forma que si no hay tuplas
	-- no aborte el procedimiento
	begin
        SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY       
        WHERE ANNO=YearPAGO;

	EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	  	SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY       
        	WHERE ANNO=(select max(anno) from IntDemoraY);	
	end;


	-- Número de días que han transcurrido del año hasta la fecha de ingreso
     NUMERODIAS:=DAYOFYEAR(mFechaPago);

     IF (mTT<>'NO') THEN
        xINTERESES:= NUMERODIAS * (mImp * mImporte /100 ) / 365;
     ELSE
        xINTERESES:= NUMERODIAS * (mSer * mImporte /100 ) / 365;
     END IF;


end;

-- Calcula los intereses de los días transcurridos desde el final del periodo voluntario
-- hasta final de año primer tramo
/*INTERNO*/
PROCEDURE InteresesPrimerTramo(
	mFinPeVol 	IN Date, 
	mImporte   	IN Float,
	mTT	     	IN Char,
	xINTERESES  OUT Float)
as

mSer 			float;
mImp 			float;
YearFinPeVol 	integer;
NumeroDias 		integer;

begin

	xINTERESES:=0;
	YearFinPeVol:=F_Year(mFinPeVol);

	-- proteger el codigo de tal forma que si no hay tuplas
	-- no aborte el procedimiento
	begin
        SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY       
        WHERE ANNO=YearFinPeVol;

	EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	 	SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY       
        	WHERE ANNO=(select max(anno) from IntDemoraY);	
	end;

	-- Número de días que han transcurrido desde el final del periodo voluntario
     NUMERODIAS:= 365 - DAYOFYEAR(mFinPeVol);

     IF (mTT<>'NO') THEN
        xINTERESES:= NUMERODIAS * (mImp * mImporte /100 ) / 365;
     ELSE
        xINTERESES:= NUMERODIAS * (mSer * mImporte /100 ) / 365;
     END IF;


end;

-- Bloque de años completos entre dos fechas para calcular intereses de demora
/*INTERNO*/
PROCEDURE InteresYearsCompletos(
	YDesde 	In Int,
	YHasta 	In Int,
	mImporte 	In Float,
	mTT	     	IN Char,
	xDemora	OUT Float)
as

mPasar 	int;
mSer 		float;
mImp 		float;
mTemp 	float;
YDesdeLocal int;

begin

  mPasar:=0;
  xDemora:=0;
  YDesdeLocal:=YDesde;

  WHILE (YDesdeLocal < YHasta) LOOP

	-- proteger el codigo de tal forma que si no hay tuplas
	-- no aborte el procedimiento
	if mPasar=0 then

	   begin
           SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY       
           WHERE ANNO=YDesdeLocal;

	    exception
		  WHEN NO_DATA_FOUND THEN
	  		SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY
        		WHERE ANNO=(select max(anno) from IntDemoraY);
	  		mPasar:=1;
	    end;

	end if;

      if (mTT<>'NO') then
         mTemp:= mImporte * mImp / 100;
      else
         mTemp:= mImporte * mSer / 100;
      end if;

      xDemora := xDemora + mTemp;
      YDesdeLocal:=YDesdeLocal+1;

  END LOOP;

end;

/*****************************************************************************************/
-- calula el tramo de los años anteiores al 1995
-- Nos calcula los dos tramos del año 1995 el primero correspondiente a los 203 días 
-- iniciales del año y los 162 días restantes al 11 porciento que le correspondio
/*BASE*/
PROCEDURE FIJO95(
		mFinPeVolC IN DATE,
		mTT        IN CHAR,
		mPrincipal IN Float,
		intereses  OUT float)

AS

   MFINPEVOL	DATE;
   mTemp 		float;
   mDemora 		float DEFAULT 0;
   IntIni 		float DEFAULT 0;
   INTFIJO95 	float DEFAULT 0;
   INTVARI95 	FLOAT DEFAULT 0;
   MaxServ 		float;
   MaxImp 		float;
   NumeroDias 	integer;
   YEARFIN 		INTEGER;

BEGIN

   IF (mPrincipal<=0) THEN
      Intereses:=0;
	return;
   end if;
   
   INTERESES := 0;
   MFINPEVOL := MFINPEVOLC;

   YearFin:=F_Year(mFinPeVol);

   -- Tipo de interes que había en el momento del final del periodo voluntario
   -- este se aplicará a los 203 días iniciales del año 1995 que es cuando se
   -- deroga la ley y entra en vigor la nueva de tipo variable

   begin 
   	select SERVICIOS,IMPUESTOS INTO MaxServ,MaxImp from IntDemoraY
   	where ANNO=YearFIN;

	exception -- Protegemos la consulta
	   WHEN NO_DATA_FOUND THEN
   		select SERVICIOS,IMPUESTOS INTO MaxServ,MaxImp from IntDemoraY
        	WHERE ANNO=(select max(anno) from IntDemoraY);
   end;

   NUMERODIAS:= 365 - DAYOFYEAR(MFINPEVOL);
   IF (mTT<>'NO') THEN
      INTINI:=NUMERODIAS * (MaxImp * MPRINCIPAL /100 ) / 365;
   ELSE
      INTINI:=NUMERODIAS * (MaxServ * MPRINCIPAL /100 ) / 365;
   END IF;

   /* CALCULOS DEL AÑO 1995 */
   IF (mTT<>'NO') THEN
      INTFIJO95:=203 * (MaxImp * mPRINCIPAL / 100) / 365;
   ELSE 	 	
      INTFIJO95:=203 * (MaxServ * mPRINCIPAL / 100) / 365;
   END IF;

   /* PARTE AL TIPO DEL A¥O 95 11% */
   IF (mTT<>'NO') THEN
      INTVARI95:=162 * (11 * mPRINCIPAL / 100) / 365;
   ELSE
      INTVARI95:=162 * (11 * mPRINCIPAL / 100) / 365;
   END IF;

-- Tramo de los años anteriores al 1995

   YEARFIN:=YEARFIN+1;
   WHILE (YEARFIN < 1995) LOOP
      IF (mTT<>'NO') THEN
         mTemp:= mPrincipal * MaxImp / 100;
      ELSE
         mTemp:= mPrincipal * MaxServ / 100;
      END IF;
      mDemora := mDemora + mTemp;
      YEARFIN:=YEARFIN+1;
   END LOOP;

   Intereses:=mDemora+INTINI+INTFIJO95+INTVARI95;

 END;

/*****************************************************************************************/
-- sirve para calcular el tramo variable a partir del año 1996, su nombre más correcto
-- hubiera sido variable96
--
/*BASE*/
PROCEDURE VARIABLE95(
		 mFechaPago IN  DATE,
		 mFinPeVol  IN  DATE,
		 mTT        IN  CHAR,
		 mPrincipal IN  float,
		 Intereses  OUT float)
AS

YearFin 		integer;
YearPago 		integer;
mDemora 		float;
xInteYearIngre 	float;

BEGIN


-- Si no hay principal no hay nada que calcular
	IF (mPrincipal<=0) THEN
      	Intereses:=0;
		return;
   	end if;

	INTERESES := 0;

	-- calcular el número de años
	YearFin:=1995;
	YearPago:=F_Year(mFechaPago);

	-- número de días transcurridos del año de ingreso
	InteresesYearIngreso(mFechaPago, mPrincipal, mTT, xInteYearIngre);

      mDemora:=0;

      IF ((YearPago-YearFin) >= 2) THEN
   		InteresYearsCompletos(YearFin+1, YearPago, mPrincipal, mTT, mDemora);
      END IF;

      Intereses:= mDemora + xInteYearIngre;

END;

/*****************************************************************************************/
-- Calculo del interes diario de un importe en el año actual
/*BASE*/
PROCEDURE INTERES_DIARIO_VALOR(
	mPrincipal 	IN	float,
      Tipo_Valor 	IN	char,
      intereses 	OUT	float
)
AS

YearNow integer default 0;
mSer    float default 0;
mImp    float default 0;

BEGIN

   YearNow:=F_Year(SYSDATE);

   select SERVICIOS,IMPUESTOS into mSer,mImp
   from IntDemoraY where anno=YearNow;


   /*para comprobar que tenemos el año definido*/
   if mImp is not null then

      /* CALCULO DEL INTERES DIARIO */
      if Tipo_Valor<>'NO' then
         Intereses:=(mImp * mPrincipal /100 ) / 365;
      else
         Intereses:=(mSer * mPrincipal /100 ) / 365;
      end if;
   end if;

END;



/* ************************************************************ */
/* INICIALIZACION DEL PAQUETE. 
BEGIN*/



END;
/
