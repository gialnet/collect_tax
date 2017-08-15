-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

/******************************************************************************************/
/*INTERNO*/
CREATE OR REPLACE PROCEDURE INT_VARIABLE_LIQ(
		xVALOR     IN INTEGER,
		xIDINGRE   IN INTEGER,		
		mFechaPago IN DATE,
		mFinPeVol  IN DATE,
		mTT 	     IN CHAR,
		mPrincipal IN Float)

AS
	YearFin integer;
	YearPago integer;
	Y integer;
	mYears integer;
	FinFor integer;
	mTemp float;
	mDemora float;
	mIntereses float;
	InteIni float;
	InteFinal float;
	mSe float;
	mIm float;
	MaxServ float;
	MaxImp float;
	NumeroDias integer;
	xYear INT;
	xExiste integer;

BEGIN   

   mINTERESES := 0;  
   YearPAGO:=F_Year(mFECHAPAGO);

   IF (mPrincipal<=0) THEN
      mIntereses:=0;
   ELSE

   	begin 
         select SERVICIOS,IMPUESTOS INTO MaxServ,MaxImp 
	   from IntDemoraY where ANNO=YearPAGO;

	   Exception
	   	When no_data_found then
		  	SELECT SERVICIOS,IMPUESTOS Into MaxServ,MaxImp from IntDemoraY       
      	  	WHERE ANNO=(select max(anno) from IntDemoraY);	
   	end;

	YearFin:=F_Year(mFinPeVol);
	YearPago:=F_Year(mFechaPago);
	NumeroDias:=YearPago-YearFin;

	IF (NumeroDias < 1) THEN   /* mismo año el fin del p.voluntario y el año de pago */
         NumeroDias:=DayOfYear(mFechaPago) - DAYOFYEAR(mFINPEVOL);
         if (mTT<>'NO') then
            mIntereses:=NumeroDias * (MaxImp * mPrincipal /100 ) / 365;
		insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
		values (xIDINGRE,xVALOR,YearPago,MaxImp,ROUND(mIntereses,2),NumeroDias);
	   else         
            mIntereses:=NumeroDias * (MaxServ * mPrincipal /100 ) / 365;
		insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
		values (xIDINGRE,xVALOR,YearPago,MaxServ,ROUND(mIntereses,2),NumeroDias);
         end if;
      ELSE  /* Intereses fracción año inicial */
         NumeroDias:=DayOfYear(mFechaPago);
         if (mTT<>'NO') then
            InteFinal:=NumeroDias * (MaxImp * mPrincipal /100 ) / 365;	  
		insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
		values (xIDINGRE,xVALOR,YearPago,MaxImp,ROUND(InteFinal,2),NumeroDias);
         else
            InteFinal:=NumeroDias * (MaxServ * mPrincipal /100 ) / 365;
		insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
		values (xIDINGRE,xVALOR,YearPago,MaxServ,ROUND(InteFinal,2),NumeroDias);
         end if;

         /* INTERESES DEL PRIMER AÑO */
	   begin 
            SELECT SERVICIOS,IMPUESTOS INTO mSe,mIm FROM INTDEMORAY
            WHERE ANNO=YEARFIN;

	      Exception
	   	   When no_data_found then
		  	SELECT SERVICIOS,IMPUESTOS Into mSe,mIm from IntDemoraY       
      	  	WHERE ANNO=(select max(anno) from IntDemoraY);	
   	   end;

         NUMERODIAS:= 365 - DAYOFYEAR(MFINPEVOL);
         IF (mTT<>'NO') THEN
            mINTERESES:=NUMERODIAS * (mIm * MPRINCIPAL /100 ) / 365;
		INSERT INTO INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
		VALUES (xIDINGRE,xVALOR,YearFin,mIm,ROUND(mINTERESES,2),NUMERODIAS);
         ELSE
            mINTERESES:=NUMERODIAS * (mSe * MPRINCIPAL /100 ) / 365;
		INSERT INTO INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
		VALUES (xIDINGRE,xVALOR,YearFin,mSe,ROUND(mINTERESES,2),NUMERODIAS);
         END IF;

         mYears:=YearPago-YearFin;
         mDemora:=0;
         mDemora:=mIntereses+InteFinal;
         FinFor:=mYears-1;
         Y:=1;
         IF (mYears >= 2) THEN
            WHILE  (y <= FinFor) LOOP

	   	   begin 
                  select SERVICIOS,IMPUESTOS Into mSe,mIm from IntDemoraY
                  where ANNO=(YearFin+y);

	         Exception
	   	   	When no_data_found then
			  	SELECT SERVICIOS,IMPUESTOS Into mSe,mIm from IntDemoraY       
      		  	WHERE ANNO=(select max(anno) from IntDemoraY);	
   	   	   end;

               if (mIm=0) then
                  mSe:=MaxServ;
                  mIm:=MaxImp;
               end if;
               if (mTT<>'NO') then
                  mTemp:= mPrincipal * mIm / 100;
		      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
   		      values (xIDINGRE,xVALOR,YearFin+y,mIm,ROUND(mTemp,2),365);			
               else
                  mTemp:= mPrincipal * mSe / 100;
		      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
   		      values (xIDINGRE,xVALOR,YearFin+y,mSe,ROUND(mTemp,2),365);			
               end if;
               y:=y+1;
            END LOOP;
	   END IF;  	   
      END IF;
   END IF;
END;
/

/*****************************************************************************************/
/*INTERNO*/
CREATE OR REPLACE PROCEDURE FIJO95_LIQ(
		xVALOR     IN INTEGER,
		xIDINGRE   IN INTEGER,		
		mFinPeVol  IN DATE,
		mTT        IN CHAR,
		mPrincipal IN Float)

AS

   mTemp 	  float;
   mDemora 	  float DEFAULT 0;
   IntIni 	  float DEFAULT 0;
   INTFIJO95  float DEFAULT 0;
   INTVARI95  FLOAT DEFAULT 0;
   MaxServ 	  float;
   MaxImp     float;
   NumeroDias integer;
   YEARFIN 	  INTEGER;

BEGIN   

   YearFin:=F_Year(mFinPeVol);

   begin
      select SERVICIOS,IMPUESTOS INTO MaxServ,MaxImp from IntDemoraY
      where ANNO=YearFIN;
	
	Exception
	   When no_data_found then
	  	SELECT SERVICIOS,IMPUESTOS Into MaxServ,MaxImp from IntDemoraY       
     	  	WHERE ANNO=(select max(anno) from IntDemoraY);	
   end;

   NUMERODIAS:= 365 - DAYOFYEAR(mFINPEVOL);
   IF (mTT<>'NO') THEN
      IntIni:=NUMERODIAS * (MaxImp * MPRINCIPAL /100 ) / 365;
      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
      values (xIDINGRE,xVALOR,YearFin,MaxImp,ROUND(IntIni,2),NumeroDias);			
   ELSE
      IntIni:=NUMERODIAS * (MaxServ * MPRINCIPAL /100 ) / 365;
      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
      values (xIDINGRE,xVALOR,YearFin,MaxServ,ROUND(IntIni,2),NumeroDias);		
   END IF;


   /* CALCULOS DEL AÑO 1995 */

   IF (mTT<>'NO') THEN
      INTFIJO95:=203 * (MaxImp * mPRINCIPAL / 100) / 365;
      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,FECHA,TPORC,INTERESES,DIAS)
      values (xIDINGRE,xVALOR,'1995','21-07-1995',MaxImp,ROUND(IntFijo95,2),203);		
   ELSE
      INTFIJO95:=203 * (MaxServ * mPRINCIPAL / 100) / 365;
      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,FECHA,TPORC,INTERESES,DIAS)
      values (xIDINGRE,xVALOR,YearFin,'21-07-1995',MaxServ,ROUND(IntFijo95,2),203);
   END IF;


   /* PARTE AL TIPO DEL AÑO 95 11% */
   INTVARI95:=162 * (11 * mPRINCIPAL / 100) / 365;
   insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,FECHA,TPORC,INTERESES,DIAS)
   values (xIDINGRE,xVALOR,'1995','22-07-1995',11,ROUND(IntVari95,2),162);

   YEARFIN:=YEARFIN+1;
   WHILE (YEARFIN < 1995) LOOP
      IF (mTT<>'NO') THEN	   
         mTemp:= mPrincipal * MaxImp / 100;
	   insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
	   values (xIDINGRE,xVALOR,YearFin,MaxImp,ROUND(mTemp,2),365);
      ELSE
         mTemp:= mPrincipal * MaxServ / 100;
	   insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
	   values (xIDINGRE,xVALOR,YearFin,MaxServ,ROUND(mTemp,2),365);
      END IF;
      YEARFIN:=YEARFIN+1;
   END LOOP;
 END;
/

/*****************************************************************************************/
/*INTERNO*/
CREATE OR REPLACE PROCEDURE VARIABLE95_LIQ(
		 xVALOR	IN INTEGER,
  	  	 xIDINGRE   IN INTEGER,		
		 mFechaPago IN DATE,
		 mTT        IN CHAR,
		 mPrincipal IN float)

AS

   YearPago   integer;
   Y 		  integer;
   mTemp 	  float;
   mDemora 	  float DEFAULT 0;
   mIntereses float DEFAULT 0;
   mSer 	  float;
   mImp 	  float;
   NumeroDias integer;

BEGIN
   
   YearPAGO:=F_Year(mFECHAPAGO);

   begin 
      SELECT SERVICIOS,IMPUESTOS INTO mSer,mImp from IntDemoraY
      where ANNO=YearPAGO;

	Exception
	   When no_data_found then
	  	SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY       
     	  	WHERE ANNO=(select max(anno) from IntDemoraY);	
   end;

   /* FRACCION DEL AÑO DE INGRESO */
   NumeroDias:=DayOfYear(mFechaPago);
   IF (mTT<>'NO') THEN	
      mDEMORA:=NumeroDias * (mImp * mPrincipal /100 ) / 365;
      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
      values (xIDINGRE,xVALOR,YearPago,mImp,ROUND(mDemora,2),NumeroDias);
   ELSE
      mDEMORA:=NumeroDias * (mSer * mPrincipal /100 ) / 365;
      insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
      values (xIDINGRE,xVALOR,YearPago,mSer,ROUND(mDemora,2),NumeroDias);
   END IF;

   Y:=1996;
   WHILE (Y < YEARPAGO) LOOP
      begin 
         SELECT SERVICIOS,IMPUESTOS INTO mSer,mImp from IntDemoraY
         where ANNO=Y;

	   Exception
	      When no_data_found then
		  	SELECT SERVICIOS,IMPUESTOS Into mSer,mImp from IntDemoraY       
     		  	WHERE ANNO=(select max(anno) from IntDemoraY);	
      end;

      if (mTT<>'NO') then
         mTemp:= mPrincipal * mImp / 100;
         insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
         values (xIDINGRE,xVALOR,Y,mImp,ROUND(mTemp,2),365);
      else
         mTemp:= mPrincipal * mSer / 100;
         insert into INTERESES_TEMP(IDINGRE,VALOR,YEAR,TPORC,INTERESES,DIAS)
         values (xIDINGRE,xVALOR,Y,mSer,ROUND(mTemp,2),365);
      end if;
      Y:=Y+1;
   END LOOP;

END;
/

/******************************************************************************************/
-- Modificado: 22/06/2004. Agustín León Robles. Cambios de la Nueva Ley General Tributaria
--					Se añade un nuevo parametro que es el Final del Periodo voluntario
/*DELPHI*/
CREATE OR REPLACE PROCEDURE GRABAR_INTERESES_TEMP(
		xCOD_OPERACION	IN	INTEGER)
AS 
   mValor	 integer;
   mTTributo char(2);
   mFinPeVol date;
   YearFin   integer;
   mFNoti	 date;
   xPuedo    integer default 0;
   
   CURSOR CINGRESOS IS SELECT VALOR
	                 FROM INGRESOS
			     WHERE CODIGO_OPERACION=xCOD_OPERACION;

   CURSOR CINGRE IS SELECT ID,PRINCIPAL,FECHA
			     FROM INGRESOS
			     WHERE VALOR=mValor;

BEGIN

   delete from intereses_temp where usuario=UID;

   FOR v_INGRESOS IN CINGRESOS LOOP

      SELECT FIN_PE_VOL,TIPO_DE_TRIBUTO,F_NOTIFICACION 
      INTO mFinPeVol,mTTributo,mFNoti
	FROM VALORES
	WHERE ID=v_INGRESOS.VALOR;

 	mValor:=v_INGRESOS.VALOR;
      FOR v_INGRE IN CINGRE LOOP

         xPuedo:=Plazo_Apremio(v_INGRE.FECHA,mFNoti,mFinPeVol);
         IF xPuedo=1 THEN

            IF (mFinPeVol is not null) then
     	         YearFin:=F_Year(mFinPeVol);
	         if (YearFin>1994) then
	            INT_VARIABLE_LIQ(v_INGRESOS.VALOR,v_INGRE.ID,v_INGRE.FECHA,mFinPeVol,
		  	  	           mTTributo,v_INGRE.PRINCIPAL);
	         else
 		      FIJO95_LIQ(v_INGRESOS.VALOR,v_INGRE.ID,mFinPeVol,mTTributo,v_INGRE.PRINCIPAL);
		      VARIABLE95_LIQ(v_INGRESOS.VALOR,v_INGRE.ID,v_INGRE.FECHA,mTTributo,v_INGRE.PRINCIPAL);
	         end if;
	      END IF;	
	   END IF;

	END LOOP;

   END LOOP;

END;
/

/******************************************************************************************/


