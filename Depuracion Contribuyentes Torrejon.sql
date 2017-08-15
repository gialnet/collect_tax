Función que devuelve el dni que se pasa como parámetro junto a la letra correspondiente para componer el nif

create or replace function CalNif (xNIF IN  CHAR)
RETURN CHAR
AS
   xLETRA CHAR(1);
   xSEGUIR BOOLEAN;
   xVALORNUMERICO INTEGER;
   xCODE INTEGER;
   xRESULTADO CHAR(10);
BEGIN
   xVALORNUMERICO:=0;
   xRESULTADO:=xNIF;   
   xSEGUIR:=TRUE;
   
   IF LENGTH(TRIM(xNIF))>8 THEN
      xSEGUIR:=FALSE;
   END IF;
   
   IF SUBSTR(xNIF,1,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
      xSEGUIR:=FALSE;
   END IF;   
   
   begin
      xVALORNUMERICO:=TO_NUMBER(SUBSTR(xNIF,1,8));
      Exception   
         When value_error then
            xSEGUIR:=FALSE;
   end;   
   
   IF xSEGUIR THEN
   
      xCODE:=xVALORNUMERICO - (TRUNC(xVALORNUMERICO/23)*23);
      
      IF xCODE='0' THEN
         xLETRA:='T';
      ELSIF xCODE='1' THEN
         xLETRA:='R';
      ELSIF xCODE='2' THEN
         xLETRA:='W';
      ELSIF xCODE='3' THEN
         xLETRA:='A';
      ELSIF xCODE='4' THEN
         xLETRA:='G';
      ELSIF xCODE='5' THEN
         xLETRA:='M';
      ELSIF xCODE='6' THEN
         xLETRA:='Y';
      ELSIF xCODE='7' THEN
         xLETRA:='F';
      ELSIF xCODE='8' THEN
         xLETRA:='P';
      ELSIF xCODE='9' THEN
         xLETRA:='D';
      ELSIF xCODE='10' THEN
         xLETRA:='X';
      ELSIF xCODE='11' THEN
         xLETRA:='B';
      ELSIF xCODE='12' THEN
         xLETRA:='N';
      ELSIF xCODE='13' THEN
         xLETRA:='J';
      ELSIF xCODE='14' THEN
         xLETRA:='Z';
      ELSIF xCODE='15' THEN
         xLETRA:='S';
      ELSIF xCODE='16' THEN
         xLETRA:='Q';
      ELSIF xCODE='17' THEN
         xLETRA:='V';
      ELSIF xCODE='18' THEN
         xLETRA:='H';
      ELSIF xCODE='19' THEN
         xLETRA:='L';
      ELSIF xCODE='20' THEN
         xLETRA:='C';
      ELSIF xCODE='21' THEN
         xLETRA:='K';
      ELSIF xCODE='22' THEN
         xLETRA:='E';
      ELSIF xCODE='23' THEN
         xLETRA:='I';
      ELSE
         xLETRA:=' ';
      END IF;   
      
      xRESULTADO:=TRIM(xNIF)||xLETRA;
   END IF;  
   
   
   RETURN xRESULTADO;
   
END;
/


/*
1º.- Localizar nifs sin letra cuyo nif con letra ya exista     
     Convertir los nifs sin letra en motes de los con letra -> se corrigen los datos de gestión para futuros padrones
     Modificar en la tabla de valores los nifs sin letra por los con letra
     Comprobar si existen expedientes creados a los de sin letra. Si es así, comprobar posibles embargos antes de 
     realizar el ambio
*/

-- NIF: con letra; DNI: sin letra; ESMOTE: dni de nif; NIFDEMOTE: Nif del que es mote el DNI (no tiene por qué coincidir con NIF);
-- ENBD: existe el nif en la base de datos de contribuyentes
-- COINCIDEN: Coincide el dni con el nif que hemos calculado a través de la anterior función;
-- LETRACORRECTA: La letra asociada al nif que existe en la base de datos es la correcta
Create table NIFs (
	NIF	CHAR(10),
	DNI	CHAR(10),
	ESMOTE CHAR(1) DEFAULT 'N',
	NIFDEMOTE CHAR(10),
	ENBD	CHAR(1) DEFAULT 'N',
	COINCIDEN CHAR(1) DEFAULT 'N',
	DNIBORRADO CHAR(1) DEFAULT 'N')
	
	
update contribuyentes set buenodemote='N' where buenodemote is null;
	
declare
   xNIF CHAR(10);
   cursor c1 is select nif from contribuyentes where SUBSTR(NIF,1,1) IN ('0','1','2','3','4','5','6','7','8','9') AND LENGTH(TRIM(NIF))=8;
begin
   for v1 in c1
   loop
      xNIF:=CalNif(v1.NIF);
      insert into NIFs (NIF,DNI) values (xNIF,v1.NIF);
   end loop;
   update nifs set coinciden='S' where dni=nif;
end;

declare
   xContador integer;
   cursor c1 is select nif from nifs where coinciden='N' for update of enbd;
begin
   for v1 in c1
   loop
      select count(*) into xContador from contribuyentes where nif=v1.nif;
      if xContador>0 then
         update nifs set enbd='S' where current of c1;
      end if;
   end loop;
end;

declare
   xContador integer;
   xNifbueno char(10);
   cursor c1 is select dni,nif from nifs where coinciden='N' and enbd='S' for update of esmote;
begin
   for v1 in c1
   loop
      begin
         xContador:=1;
         select nifbueno into xNifBueno from aliasdni where aliasnif=v1.dni;
         Exception 
            When no_data_found then
               xContador:=0;
      end;
      
      if xcontador>0 then         
         update nifs set esmote='S',nifdemote=xNifBueno where current of c1;
      end if;
   end loop;
end;

-- una vez la tabla rellena creamos motes 

-- motes antes de ejecutar el proceso: (select count(*) from aliasdni) 23

declare
   cursor c1 is select nif,dni from nifs where coinciden='N' and enbd='S' and esmote='N';
begin
	for v1 in c1
	loop
		ADDMOTES(v1.dni||'/',v1.nif);
	end loop;
end;

-- motes después de ejecutar el proceso: 1581

-- volvemos a lanzar el siguiente código para actualizar los dnis que son motes y de quien lo son
declare
   xContador integer;
   xNifbueno char(10);
   cursor c1 is select dni,nif from nifs where coinciden='N' and enbd='S' for update of esmote;
begin
   for v1 in c1
   loop
      begin
         xContador:=1;
         select nifbueno into xNifBueno from aliasdni where aliasnif=v1.dni;
         Exception 
            When no_data_found then
               xContador:=0;
      end;
      
      if xcontador>0 then         
         update nifs set esmote='S',nifdemote=xNifBueno where current of c1;
      end if;
   end loop;
end;

-- modificamos la tabla de valores, cambiando los nifs=dni por el nif del cual es mote, basándonos en la tabla que se ha rellenado (tabla nifs);

-- SELECT COUNT(*) FROM VALORES WHERE NIF IN (SELECT DNI FROM NIFS WHERE ENBD='S' AND COINCIDEN='N' AND ESMOTE='S'); 367

declare
   xDNI char(10);
   xNombre varchar2(40);
   cursor c1 is select dni,nifdemote from nifs where esmote='S';
   cursor c2 is select id from valores where nif=xDNI for update of nif,nombre;
begin
   for v1 in c1 
   loop
   
      xDNI:=v1.DNI;
      
      for v2 in c2
      loop
      	select nombre into xNombre from contribuyentes where nif=v1.nifdemote;
      	update valores set nif=v1.nifdemote,nombre=xNombre where current of c2;
      end loop;
      
   
   end loop;   
end;

-- modificamos el deudor en la tabla de expedientes, cambiando el deudor=dni por el nif del cual es mote
-- primero comprobaremos los expedientes abiertos y sin trámites

declare
	xNIF char(10);
	cursor c1 is select id,deudor from expedientes where embargo='0' and deudor in (select dni from nifs
			where esmote='S') for update of deudor;
begin
	begin
	   for v1 in c1
	   loop
	      select nifdemote into xNIF from nifs where dni=v1.deudor;
	      update expedientes set deudor=xNIF where current of c1;	
	   end loop;		
	end;
end;


/******************************************************************************************************************************************/
/*  AHORA CREAREMOS LOS NIFS CON LETRA DE LOS DNIS SIN LETRA EN LA BASE DE DATOS Y LOS ASIGNAREMOS COMO MOTES DE LOS NUEVOS NIFS CREADOS  */
/******************************************************************************************************************************************/

-- contamos cuantos contribuyentes hay antes del proceso: 134657
-- contamos el número de dnis en la tabla NIFS que cumplen la condición: 457

-- damos de alta los nifs creados en la tabla NIFS que no están en la base de datos y no coinciden con el DNI
declare
   cursor c1 is select nif,dni from nifs where coinciden='N' and enbd='N';
begin
   for v1 in c1
   loop
   	INSERT INTO CONTRIBUYENTES 
   		(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   		PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE) 
   	SELECT v1.NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   		PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,'N' FROM CONTRIBUYENTES WHERE NIF=v1.DNI; 
   end loop;
end;

-- nuevo número de contribuyentes: 135114

declare
   xContador integer;
   xNifbueno char(10);
   cursor c1 is select dni,nif from nifs where coinciden='N' and enbd='N' for update of esmote;
begin
   for v1 in c1
   loop
      begin
         xContador:=1;
         select nifbueno into xNifBueno from aliasdni where aliasnif=v1.dni;
         Exception 
            When no_data_found then
               xContador:=0;
      end;
      
      if xcontador>0 then         
         update nifs set esmote='S',nifdemote=xNifBueno where current of c1;
      end if;
   end loop;
end;


-- motes antes de ejecutar el proceso: (select count(*) from aliasdni) 1581

declare
   cursor c1 is select nif,dni from nifs where coinciden='N' and enbd='N' and esmote='N';
begin
	for v1 in c1
	loop
		ADDMOTES(v1.dni||'/',v1.nif);
	end loop;
end;

-- motes después de ejecutar el proceso: 1916 

-- volvemos a lanzar el siguiente código para actualizar los dnis que son motes y de quien lo son
declare
   xContador integer;
   xNifbueno char(10);
   cursor c1 is select dni,nif from nifs where coinciden='N' and enbd='N' for update of esmote;
begin
   for v1 in c1
   loop
      begin
         xContador:=1;
         select nifbueno into xNifBueno from aliasdni where aliasnif=v1.dni;
         Exception 
            When no_data_found then
               xContador:=0;
      end;
      
      if xcontador>0 then         
         update nifs set esmote='S',nifdemote=xNifBueno where current of c1;
      end if;
   end loop;
end;


-- modificamos la tabla de valores, cambiando los nifs=dni por el nif del cual es mote, basándonos en la tabla que se ha rellenado (tabla nifs);

-- select count(*) from valores where nif in (select dni from nifs where esmote='S' and enbd='N' and coinciden='N'): 308

declare
   xDNI char(10);
   xNombre varchar2(40);
   cursor c1 is select dni,nifdemote from nifs where esmote='S' and enbd='N';
   cursor c2 is select id from valores where nif=xDNI for update of nif,nombre;
begin
   for v1 in c1 
   loop
   
      xDNI:=v1.DNI;
      
      for v2 in c2
      loop
      	select nombre into xNombre from contribuyentes where nif=v1.nifdemote;
      	update valores set nif=v1.nifdemote,nombre=xNombre where current of c2;
      end loop;
      
   
   end loop;   
end;

-- select count(*) from valores where nif in (select dni from nifs where esmote='S' and enbd='N' and coinciden='N'): 0
-- select count(*) from valores where nif in (select nif from nifs where esmote='S' and enbd='N' and coinciden='N'): 318

-- modificamos el deudor en la tabla de expedientes, cambiando el deudor=dni por el nif del cual es mote
-- primero comprobaremos los expedientes abiertos y sin trámites

declare
	xNIF char(10);
	cursor c1 is select id,deudor from expedientes where embargo='0' and deudor in (select dni from nifs
			where esmote='S' and enbd='N' and coinciden='N') for update of deudor;
begin
	begin
	   for v1 in c1
	   loop
	      select nifdemote into xNIF from nifs where dni=v1.deudor;
	      update expedientes set deudor=xNIF where current of c1;	
	   end loop;		
	end;
end;

-- indicamos en la TABLA NIFS que los nif nuevos están ya en la base de datos
update nifs set enbd='S' where enbd='N' and coinciden='N';

/****************************************************************************************************************/
/* SE INTENTAN BORRAR LOS DNIS QUE SON MOTES Y NO TIENEN NADA ASOCIADO EN LA BASE DE DATOS 							 */
/****************************************************************************************************************/

-- select count(*) from contribuyentes: 137086
-- select count(*) from nifs where esmote='S' and nifdemote=nif: 1905 

-- ¡¡ deshabilitar la constraint ALIASNIF de la tabla ALIASDNI !!

--declare
--   xBorrado char(1);
--   cursor c1 is select dni from nifs where esmote='S' and nifdemote=nif for update of dniborrado;
--begin
--   for v1 in c1 
--   loop
--      xBorrado:='S';
--   	begin
--   		delete from contribuyentes where nif=v1.dni;
--   		Exception
--   			When others then
--   				xBorrado:='N';
--  	end;
--   	if xBorrado='S' then
--   	   update nifs set dniborrado='S' where current of c1;
--   	end if;
--   end loop;
--end;

-- ¡¡ volver a habilitar la constraint ALIASNIF sobre la tabla ALIASDNI !!

/*******************************************************************************************************************/
/*******************************************************************************************************************/

/*
2º.- Modificamos el nif en la tabla de notificaciones
*/

update notificaciones set nif=(select nif from valores where id=notificaciones.valor)

/*******************************************************************************************************************/
/*******************************************************************************************************************/

/*******************************************************************************************************************/
/*******************************************************************************************************************/

SELECT TABLE_NAME,COLUMN_NAME FROM USER_TAB_COLUMNS WHERE COLUMN_NAME LIKE '%NIF%'
AND TABLE_NAME IN (SELECT OBJECT_NAME FROM USER_OBJECTS WHERE OBJECT_TYPE ='TABLE')

-- quitando tablas temporales y sin datos:

ALIASDNI							ALIASNIF
ALIASDNI							NIFBUENO
ASISTENCIA						NIF
BORRA_CUENTAS_LOTES			NIF
BORRA_EMBARGOS_CUENTAS		NIF
CUENTAS_CORRIENTES			NIF
CUENTAS_LOTES					NIF
DISCOSS							NIF
DISCOSS							NIFCORRECTO
DOMICILIOS_ALTERNATIVOS		NIF
EMBARGOS_CUENTAS				NIF
EMBARGOS_INMUEBLES			NIF
EMBARGOS_SALARIOS				NIF
FINCAS							NIF
FRACCIONAMIENTO				NIF
FRACCIONAMIENTO_VOL			NIF
HISTORIA_VALORES				NIF
LIQUIDACIONES					NIF
LIQUIDACIONES					NIFREP
NEXT_LEVANTA_CUENTAS			NIF
NOTAS_SIMPLES					NIF
NOTIFICACIONES					NIF
PUNTEO							NIF
REFERENCIAS_BANCOS			NIF
RETENCIONES_INDEBIDAS		NIF
SALARIOS							NIF
TERCEROS							NIF
VALORES							NIF
VEHICULOSR						NIF

SELECT TABLE_NAME,COLUMN_NAME FROM USER_TAB_COLUMNS WHERE COLUMN_NAME LIKE '%DEUDOR%'
AND TABLE_NAME IN (SELECT OBJECT_NAME FROM USER_OBJECTS WHERE OBJECT_TYPE ='TABLE')

EXPEDIENTES						DEUDOR
REQUERIR_PLUSVA				DEUDOR
TABLA_REQUE_PLUSVA			DEUDOR

/*******************************************************************************************************************/
/*******************************************************************************************************************/
-- 3º.-  Nifs distintos en la tabla liquidaciones y valores
create table NIFs2(
	idliqui	integer,
	idvalor	integer,
	nifLIQUI char(10),
	nifVAL char(10),
	esmote	char(1) default 'N',
	nifdemote char(10),
	validadoLIQUI char(1));
	
declare
	cursor c1 is select l.id as idliqui,v.ID as idvalor,l.nif as nifliqui,v.nif as nifvalor from liquidaciones l,valores v 
				    where l.idvalor=v.id and l.nif<>v.nif; 
begin
	for v1 in c1
	loop
		insert into NIFs2(idliqui,idvalor,nifLIQUI,nifVAL)
		values (v1.idliqui,v1.idvalor,v1.nifliqui,v1.nifvalor);
	end loop;
end;
	

declare
   xContador integer;
   xNifbueno char(10);
   cursor c1 is select nifLIQUI,nifVAL from nifs2 for update of esmote;
begin
   for v1 in c1
   loop
      begin
         xContador:=1;
         select nifbueno into xNifBueno from aliasdni where aliasnif=v1.nifLIQUI;
         Exception 
            When no_data_found then
               xContador:=0;
      end;
      
      if xcontador>0 then         
         update nifs2 set esmote='S',nifdemote=xNifBueno where current of c1;
      end if;
   end loop;
end;

declare
	xvalidado char(1);
	cursor c1 is select nifliqui from nifs2 for update of validadoLIQUI;
begin
	for v1 in c1
	loop
		select validado into xvalidado from contribuyentes where nif=v1.nifliqui;
		update nifs2 set validadoLIQUI=xvalidado
		where current of c1;
	end loop;
end;

/*******************************************************************************************************************/
/*******************************************************************************************************************/

/* 
5º.- Cargar una tabla pasada por el con comparación de nifs en el ibi con su padrón de habitantes. 
La tabla se ha llamado ricardo.
ENCONTRI indica si el nif del padrón está en nuestra base de datos
VALIDADO indica tipo de validación para este nif (si existe en nuestra b.d.)
CUANTOSIBI indica cuantos nifs iguales hay de IBI asociados a distintos NIFPADRON
SECREAMOTE indica que se ha añadido nifibi como mote de nifpadron
*/

declare
   xEnContri char(1);
   xValidado char(1);
   cursor c1 is select NIFPADRON from ricardo for update of encontri,validado;
begin
   for v1 in c1
   loop
   	begin
   	   xEncontri:='S';
   	   xValidado:=NULL;
   	   select validado into xValidado from contribuyentes where trim(nif)=trim(v1.NIFPADRON);
   	   Exception
   	   	When no_data_found then
   	   		xEnContri:='N';   	  
   	end;
   	update ricardo set encontri=xEncontri,validado=xValidado where current of c1;
   end loop;
end;


-- dar de alta los nifs que le corresponden a los nombre y no aparecen o aparecen mal en la cinta del IBI
declare
   xNIF CHAR(10);
	cursor c1 is select distinct nif,nombre,TRIM(tipo_via_fiscal) as tipo_via_fiscal,nombre_via_fiscal,primer_numero_fiscal,escalera_fiscal,
										  planta_fiscal,TRIM(puerta_fiscal) as puerta_fiscal,
										  cod_postal_fiscal,municipio_fiscal,provincia,pais,personalidad
					 from ibi where year='2004' and nombre in (select nombre from ricardo where falso=0 and encontri='N');
begin
	for v1 in c1 
   loop
      SELECT NIFPADRON INTO xNIF FROM RICARDO WHERE TRIM(NIFIBI)=TRIM(v1.NIF);
   	INSERT INTO CONTRIBUYENTES 
   		(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS,PERSONALIDAD,BUENODEMOTE) 
   	VALUES (v1.NIF,SUBSTR(v1.NOMBRE,1,40),v1.tipo_via_fiscal,v1.NOMBRE_VIA_FISCAL,V1.PRIMER_NUMERO_FISCAL,V1.ESCALERA_FISCAL,
   		V1.PLANTA_FISCAL,V1.PUERTA_FISCAL,V1.MUNICIPIO_FISCAL,V1.PROVINCIA,V1.COD_POSTAL_FISCAL,V1.PAIS,V1.PERSONALIDAD,'N');
   end loop;	
end;

declare
	cursor c1 is select nifibi,count(*) as cuantos from ricardo group by nifibi;
begin
   for v1 in c1 loop
   	update ricardo set cuantosibi=v1.cuantos where nifibi=v1.nifibi;
   end loop;   
end;

-- se crean motes masivos para los que no coinciden (nifpadron y nifibi), el nifpadron está no validado o validado por la agencia y 
-- el nifibi asociado sólo lo está a este nifpadron.

-- nº de motes antes: 1918

declare
	cursor c1 is select nifpadron,nifibi from ricardo where nifpadron<>nifibi and encontri='S' and (validado='N' or validado='A') and cuantosibi=1;
begin
	for v1 in c1
	loop
		ADDMOTES(v1.nifibi||'/',v1.nifpadron);
		update ricardo set secreamote='S' where nifpadron=v1.nifpadron;
	end loop;
end;

-- nº de motes después: 2055

-- select count(*) from valores where trim(nif) in (select trim(nifibi) from ricardo where secreamote='S'): 448
-- select count(*) from valores where trim(nif) in (select trim(nifpadron) from ricardo where secreamote='S'): 577

declare
   xDNI char(10);
   xNombre varchar2(40);
   cursor c1 is select NIFPADRON,NIFIBI from RICARDO where SECREAMOTE='S';
   cursor c2 is select id from valores where trim(nif)=xDNI for update of nif,nombre;
begin
   for v1 in c1 
   loop
   
      xDNI:=trim(v1.NIFIBI);
      
      for v2 in c2
      loop
      	select nombre into xNombre from contribuyentes where trim(nif)=trim(v1.NIFPADRON);
      	update valores set nif=v1.NIFPADRON,nombre=xNombre where current of c2;
      end loop;      
   
   end loop;   
end;

-- select count(*) from valores where trim(nif) in (select trim(nifibi) from ricardo where secreamote='S'): 429
-- select count(*) from valores where trim(nif) in (select trim(nifpadron) from ricardo where secreamote='S'): 596

-- modificamos el deudor en la tabla de expedientes, cambiando el deudor=nifibi por el nifpadron del cual es mote
-- primero comprobaremos los expedientes abiertos y sin trámites

-- select id,deudor from expedientes where embargo='0' and deudor in (select nifibi from ricardo where secreamote='S'): 1, id 23523

declare
	xNIF char(10);
	cursor c1 is select id,deudor from expedientes where embargo='0' and deudor in (select nifibi from ricardo
			where secreamote='S') for update of deudor;
begin
	begin
	   for v1 in c1
	   loop
	      select nifpadron into xNIF from ricardo where nifibi=v1.deudor;
	      update expedientes set deudor=xNIF where current of c1;	
	   end loop;		
	end;
end;

-- una vez modificado se añade el primer nif del deudor a los motes

/*******************************************************************************************************************/
--NIFs Falsos asociados a valores de IBI
CREATE TABLE NIFSFIBI ( 
  NIF           CHAR (10), 
  NOMBRE        VARCHAR2 (60), 
  CALLE         VARCHAR2 (35), 
  NIFPADRON     CHAR (10), 
  NOMBREPADRON  VARCHAR2 (60), 
  CALLEPADRON   VARCHAR2 (35) ) ; 
insert into nifsFIBI select nif,nombre,nombre_via_fiscal from ibi where year='2004' and nif in 
(select nif from contribuyentes where validado='F');

declare
       xnif char(10);
	   xnombre varchar2(60);
	   xcalle varchar2(35);
	   cursor c1 is select * from nifsFIBI for update of nifpadron,nombrepadron,callepadron;
begin
	 for v1 in c1
	 loop
	 	 begin
		 	  select nifpadron,nombre,calle into xnif,xnombre,xcalle from ricardo
			  where nombre=v1.nombre;
			  Exception 
			  			When no_data_found then
							 xnombre:=null;
		 end;
		 if xnombre is not null then
		 	update nifsFIBI set nifpadron=xnif,nombrepadron=xnombre,callepadron=xCalle 
			where current of c1;
		 end if;
	 end loop;
end;

-- algunos de los nifs que me ha enviado Ricardo considerados como buenos están marcados como falsos en nuestra base de 
-- datos, con lo cual he de revisar manualmente los cinco registros que se han rellenado con el sql anterior.

-- select count(*) from valores where nif in (select nif from nifsFIBI where nifpadron is not null): 34

declare
   xDNI char(10);
   xNombre varchar2(40);
   cursor c1 is select NIFPADRON,NIF from nifsFIBI where nifpadron is not null;
   cursor c2 is select id from valores where trim(nif)=xDNI for update of nif,nombre;
begin
   for v1 in c1 
   loop
   
      xDNI:=trim(v1.NIF);
      
      for v2 in c2
      loop
      	select nombre into xNombre from contribuyentes where trim(nif)=trim(v1.NIFPADRON);
      	update valores set nif=v1.NIFPADRON,nombre=xNombre where current of c2;
      end loop;      
   
   end loop;   
end;

-- expedientes

select * from expedientes where deudor in (select nifpadron from nifsFIBI where nifpadron is not null): 1 en el abierto de cuentas





/*******************************************************************************************************************/
create table TodosNifs(
	nombre varchar2(40),
	nif1   char(10),
	nif2   char(10),
	nif3   char(10),
	nif4   char(10),
	nif5   char(10),
	nif6   char(10),
	nif7   char(10),	
	calle1 varchar2(30),
	calle2 varchar2(30),
	calle3 varchar2(30),
	calle4 varchar2(30),
	calle5 varchar2(30),
	calle6 varchar2(30),
	calle7 varchar2(30),	
	inicalle varchar2(10));

declare
	xNombre varchar2(40);
	xCalle varchar2(10);
	i integer;
	cursor c1 is select nombre,trim(substr(calle,1,10)) as indicalle,count(*) from contribuyentes where validado in ('N','A')
	group by nombre,trim(substr(calle,1,10))
	having count(*)=1 order by nombre;
	cursor c2 is select nif,calle from contribuyentes where nombre=xNombre and trim(substr(calle,1,10))=xCalle and validado in ('N','A');
	cursor c3 is select nif,calle from contribuyentes where nombre=xNombre and trim(substr(calle,1,10)) is null and validado in ('N','A');
begin
	for v1 in c1
	loop
	   i:=1;
	   xNombre:=v1.nombre;
	   xCalle:=trim(v1.indicalle);
	   
	   if xCalle is null then 
	   	for v3 in c3
	   	loop
	   		if (i=1) then
	   	   	insert into TodosNifs(nombre,nif1,calle1,inicalle)
	   	   	values (xNombre,v3.nif,v3.calle,xCalle);
	   		elsif (i=2) then
	   			update TodosNifs set nif2=v3.nif,calle2=v3.calle
	   			where nombre=xNombre and inicalle is null;
	   		elsif (i=3) then
	   			update TodosNifs set nif3=v3.nif,calle3=v3.calle
	   			where nombre=xNombre and inicalle is null;
	   		elsif (i=4) then
	   			update TodosNifs set nif4=v3.nif,calle4=v3.calle
	   			where nombre=xNombre and inicalle is null;
	   		elsif (i=5) then
	   			update TodosNifs set nif5=v3.nif,calle5=v3.calle
	   			where nombre=xNombre and inicalle is null;
	   		elsif (i=6) then
	   			update TodosNifs set nif6=v3.nif,calle6=v3.calle
	   			where nombre=xNombre and inicalle is null;
	   		elsif (i=7) then
	   			update TodosNifs set nif7=v3.nif,calle7=v3.calle
	   			where nombre=xNombre and inicalle is null;
	   		end if;
	   		i:=i+1;
	   	end loop;
	   else
	   	for v2 in c2
	   	loop
	   		if (i=1) then
	   	   	insert into TodosNifs(nombre,nif1,calle1,inicalle)
	   	   	values (xNombre,v2.nif,v2.calle,xCalle);
	   		elsif (i=2) then
	   			update TodosNifs set nif2=v2.nif,calle2=v2.calle
	   			where nombre=xNombre and inicalle=xCalle;
	   		elsif (i=3) then
	   			update TodosNifs set nif3=v2.nif,calle3=v2.calle
	   			where nombre=xNombre and inicalle=xCalle;
	   		elsif (i=4) then
	   			update TodosNifs set nif4=v2.nif,calle4=v2.calle
	   			where nombre=xNombre and inicalle=xCalle;
	   		elsif (i=5) then
	   			update TodosNifs set nif5=v2.nif,calle5=v2.calle
	   			where nombre=xNombre and inicalle=xCalle;
	   		elsif (i=6) then
	   			update TodosNifs set nif6=v2.nif,calle6=v2.calle
	   			where nombre=xNombre and inicalle=xCalle;
	   		elsif (i=7) then
	   			update TodosNifs set nif7=v2.nif,calle7=v2.calle
	   			where nombre=xNombre and inicalle=xCalle;
	   		end if;
	   		i:=i+1;
	   	end loop;
	   end if;
	end loop;
end;
	
/*******************************************************************************************************************/
/*******************************************************************************************************************/
/*	               									EXPEDIENTES 																			 */
/*******************************************************************************************************************/
/*******************************************************************************************************************/

CREATE TABLE EXPE0C(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));
	
CREATE TABLE EXPE1L(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));
	
CREATE TABLE EXPE1O(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));

CREATE TABLE EXPE1P(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35),
	corregido char(1) default 'N');

CREATE TABLE EXPE3O(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));

CREATE TABLE EXPE3P(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35),
	corregido char(1) default 'N');

CREATE TABLE EXPE4O(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));

CREATE TABLE EXPE4P(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));

CREATE TABLE EXPE8P(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));

CREATE TABLE EXPEXP(
	IdExpe	integer,
	estado	char(7),
	nif	char(10),
	validado char(1),
	buenodemote char(1),
	nombre	varchar2(60),
	calle		varchar2(35),
	posible_nif char(10),
	posible_nombre varchar2(60),
	posible_calle varchar2(35));
	
insert into expe0C (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='0' and esta_embargo='C';
insert into expe1L (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='1' and esta_embargo='L';
insert into expe1O (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='1' and esta_embargo='O';
insert into expe1P (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='1' and esta_embargo='P';
insert into expe3O (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='3' and esta_embargo='O';
insert into expe3P (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='3' and esta_embargo='P';
insert into expe4O (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='4' and esta_embargo='O';
insert into expe4P (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='4' and esta_embargo='P';
insert into expe8P (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='8' and esta_embargo='P';
insert into expeXP (IDEXPE,ESTADO,NIF) select ID,ESTADO,DEUDOR from expedientes where embargo='X' and esta_embargo='P';

declare
	xvalidado char(1);
	xbuenodemote char(1);
	xnombre varchar2(60);
	xcalle varchar2(35);
	cursor c1 is select nif from expe0C for update of validado,buenodemote,nombre,calle;
begin
	for v1 in c1
	loop
		select validado,buenodemote,nombre,calle into xvalidado,xbuenodemote,xnombre,xcalle from contribuyentes where nif=v1.nif;
		update expe0C set validado=xvalidado,buenodemote=xbuenodemote,nombre=xnombre,calle=xcalle where current of c1;
	end loop;
end;

DECLARE
	   XFECHA DATE;
	   XCUANTOS INTEGER;
	   XNIF CHAR(10);
	   XNOMBRE VARCHAR2(60);
	   XCALLE VARCHAR2(35);
	   XMAXFECHA DATE;
	   CURSOR C1 IS SELECT * FROM EXPE0C WHERE VALIDADO='F' AND ESTADO='ABIERTO' FOR UPDATE OF POSIBLE_NIF,POSIBLE_NOMBRE,POSIBLE_CALLE; 
BEGIN
	 FOR V1 IN C1
	 LOOP
	 
	 	 SELECT COUNT(*) INTO XCUANTOS FROM CONTRIBUYENTES WHERE NOMBRE LIKE V1.NOMBRE||'%' AND SUBSTR(CALLE,1,10)=SUBSTR(V1.CALLE,1,10)
		 AND NIF<>v1.NIF AND VALIDADO IN ('N','A');
		 
		 IF XCUANTOS>0 THEN
		 	SELECT MAX(F_ALTA) INTO XMAXFECHA FROM CONTRIBUYENTES WHERE NOMBRE LIKE V1.NOMBRE||'%' AND 
			SUBSTR(CALLE,1,10)=SUBSTR(V1.CALLE,1,10) AND NIF<>v1.NIF AND VALIDADO IN ('N','A');
			
			IF XMAXFECHA IS NULL THEN
			   SELECT NIF,NOMBRE,CALLE INTO XNIF,XNOMBRE,XCALLE FROM CONTRIBUYENTES WHERE NOMBRE LIKE V1.NOMBRE||'%' AND 
			   SUBSTR(CALLE,1,10)=SUBSTR(V1.CALLE,1,10) AND NIF<>v1.NIF AND VALIDADO IN ('N','A') AND F_ALTA IS NULL;
			ELSE   
			   SELECT NIF,NOMBRE,CALLE INTO XNIF,XNOMBRE,XCALLE FROM CONTRIBUYENTES WHERE NOMBRE LIKE V1.NOMBRE||'%' AND 
			   SUBSTR(CALLE,1,10)=SUBSTR(V1.CALLE,1,10) AND NIF<>v1.NIF AND VALIDADO IN ('N','A') AND F_ALTA=XMAXFECHA;
			END IF;		 
		 	
	 		UPDATE EXPE0C SET POSIBLE_NIF=XNIF,POSIBLE_NOMBRE=XNOMBRE,POSIBLE_CALLE=XCALLE
			WHERE CURRENT OF C1;   
		 END IF;
		 
	 END LOOP;
END;

DECLARE
	   XIDEXPE INTEGER;
	   CURSOR C1 IS SELECT POSIBLE_NIF FROM EXPE1P WHERE posible_nif<>'00397705N ' and VALIDADO='F' AND ESTADO='ABIERTO' AND POSIBLE_NIF IS NOT NULL
	   GROUP BY POSIBLE_NIF;
BEGIN
	 FOR V1 IN C1
	 LOOP	 	 
	 	 SELECT IDEXPE INTO XIDEXPE FROM EXPE1P WHERE VALIDADO='F' AND ESTADO='ABIERTO' AND POSIBLE_NIF=V1.POSIBLE_NIF;
		 UPDATE EXPEDIENTES SET DEUDOR=V1.POSIBLE_NIF WHERE ID=xIDEXPE;
		 UPDATE EXPE1P SET CORREGIDO='S' WHERE VALIDADO='F' AND ESTADO='ABIERTO' AND POSIBLE_NIF=V1.POSIBLE_NIF;
	 END LOOP;
END;

update notificaciones set nif=(select deudor from expedientes where id=notificaciones.expediente)
where expediente in (select idexpe from expe1p where corregido='S');

update cuentas_corrientes set nif=(select posible_nif from expe1p where nif=cuentas_corrientes.nif)
where nif in (select nif from expe1p where corregido='S');	 

update vehiculosr set nif=(select posible_nif from expe1p where nif=vehiculosr.nif)
where nif in (select nif from expe1p where corregido='S');		

/**********************************************************************************************************************************************/
-- Expedientes diferentes para la misma persona (mismo nombre pero diferente dni (quizás solo por un 0 delante)

Create table MAMEN_EXPE(
	ID1 INTEGER,
	ID2 INTEGER,
	NIF1 CHAR(10),
	NIF2 CHAR(10),
	NOMBRE1 VARCHAR2(40),
	NOMBRE2 VARCHAR2(40),
	F_APERTURA1 DATE,
	F_APERTURA2 DATE,
	ESTADO1 CHAR(10),
	ESTADO2 CHAR(10));
	
INSERT INTO MAMEN_EXPE(ID1,ID2,NIF1,NIF2,F_APERTURA1,F_APERTURA2,ESTADO1,ESTADO2)
SELECT E1.ID,E2.ID,E1.DEUDOR,E2.DEUDOR,E1.F_APERTURA,E2.F_APERTURA,E1.ESTADO,E2.ESTADO
FROM EXPEDIENTES E1,EXPEDIENTES E2 WHERE TRIM(E1.DEUDOR)=TRIM(SUBSTR(E2.DEUDOR,2,LENGTH(E2.DEUDOR)));

DECLARE
	   XNOMBRE1 VARCHAR2(40);
	   XNOMBRE2 VARCHAR2(40);
	   CURSOR C1 IS SELECT NIF1,NIF2 FROM MAMEN_EXPE FOR UPDATE OF NOMBRE1,NOMBRE2; 
BEGIN
	 FOR v1 IN C1
	 LOOP
	 	 SELECT NOMBRE INTO xNOMBRE1 FROM CONTRIBUYENTES WHERE NIF=v1.NIF1;
		 SELECT NOMBRE INTO xNOMBRE2 FROM CONTRIBUYENTES WHERE NIF=v1.NIF2;
		 UPDATE MAMEN_EXPE SET NOMBRE1=xNOMBRE1,NOMBRE2=xNOMBRE2 WHERE CURRENT OF C1;
	 END LOOP;
END;


/********************************************************************************************************************************************/
-- Le han rechazado algunos expedientes por tener menos de 9 caracteres (el NIF). Se van a completar con 0 a la izquierda aquellos cuya 
-- longitud sea menor a 9
/********************************************************************************************************************************************/

CREATE TABLE MAMEN_NIFS_9(
	NIFCONTRI	CHAR(10),
	NOMBRE		VARCHAR2(40),
	VALIDADO    CHAR(1),
	NIFNEW		CHAR(10),
	NOMBRENEW	VARCHAR2(40),
	EXISTENIFNEW CHAR(1) DEFAULT 'N',
	VALIDADONEW CHAR(1)
)

INSERT INTO MAMEN_NIFS_9 (NIFCONTRI,NOMBRE,VALIDADO) SELECT NIF,NOMBRE,VALIDADO FROM CONTRIBUYENTES WHERE LENGTH(TRIM(NIF))<9;

SELECT VALIDADO,COUNT(*) FROM MAMEN_NIFS_9
GROUP BY VALIDADO;

SELECT DISTINCT SUBSTR(NIFCONTRI,1,1) FROM MAMEN_NIFS_9
ORDER BY SUBSTR(NIFCONTRI,1,1);

(' ','A','B','C','D','d','E','F','G','H','I','J','K','L','M','N','Ñ','O','P','Q','R','S','T','V','X','Y','Z','0','1','2','3',
'4','5','6','7','8','9');

-- empezamos a trabajar con las personas físicas

UPDATE MAMEN_NIFS_9 SET NIFNEW=LPAD(TRIM(CALNIF(NIFCONTRI)),9,'0') WHERE SUBSTR(NIFCONTRI,1,1) IN 
(' ','0','1','2','3','4','5','6','7','8','9');

UPDATE MAMEN_NIFS_9 SET NIFNEW=LPAD(TRIM(NIFCONTRI),9,'0') WHERE SUBSTR(NIFCONTRI,1,1) IN 
(' ','0','1','2','3','4','5','6','7','8','9');

DECLARE
   xCONTADOR INTEGER;
   CURSOR C1 IS SELECT NIFNEW FROM MAMEN_NIFS_9 WHERE NIFNEW IS NOT NULL FOR UPDATE OF EXISTENIFNEW;
BEGIN
   FOR v1 IN C1
   LOOP
      SELECT COUNT(*) INTO xCONTADOR FROM CONTRIBUYENTES WHERE NIF=v1.NIFNEW;
      IF xCONTADOR>0 THEN
         UPDATE MAMEN_NIFS_9 SET EXISTENIFNEW='S' WHERE CURRENT OF C1;
      END IF;
   END LOOP;
END;

UPDATE MAMEN_NIFS_9 SET VALIDADONEW=(SELECT VALIDADO FROM CONTRIBUYENTES WHERE NIF=NIFNEW)
WHERE EXISTENIFNEW='S';
UPDATE MAMEN_NIFS_9 SET NOMBRENEW=(SELECT NOMBRE FROM CONTRIBUYENTES WHERE NIF=NIFNEW)
WHERE EXISTENIFNEW IS NOT NULL;

-- consulta para Ricardo
SELECT NIFCONTRI,NOMBRE,DECODE(VALIDADO,'F','FALSO','M','MOTE','A','AGENCIA','S','VERDADERO','N','SIN VALIDAR') AS VALIDACION,
NIFNEW AS NUEVONIF,NOMBRENEW AS NUEVONOMBRE,EXISTENIFNEW AS YAEXISTE,
DECODE(VALIDADONEW,'F','FALSO','M','MOTE','A','AGENCIA','S','VERDADERO','N','SIN VALIDAR') AS VALIDACIONNUEVO 
FROM MAMEN_NIFS_9 WHERE NIFNEW IS NOT NULL ORDER BY NIFCONTRI



alter table mamen_nifs_9 add considerar char(1) default 'N';
select distinct validado from mamen_nifs_9;
update mamen_nifs_9 set considerar='S' where validado in ('A','N');

-- para trabajar sólo con las personas físicas: 
UPDATE MAMEN_NIFS_9 SET CONSIDERAR='N' WHERE CONSIDERAR='S' AND SUBSTR(NIFCONTRI,1,1) NOT IN 
(' ','0','1','2','3','4','5','6','7','8','9');

ALTER TABLE MAMEN_NIFS_9 ADD CARGADO CHAR(1) DEFAULT 'N';

-- select count(*) from aliasdni: 2141

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 WHERE CONSIDERAR='S' AND EXISTENIFNEW='S' AND VALIDADONEW='A'
   FOR UPDATE OF CARGADO;
BEGIN
   FOR v1 IN C1
   LOOP
   	   ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
	   UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

--  select count(*) from aliasdni : 2165

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 WHERE CONSIDERAR'=S' AND VALIDADONEW='N' AND CARGADO='N'
   FOR UPDATE OF CARGADO;
BEGIN
   FOR v1 IN C1
   LOOP
      ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
      UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;


DECLARE
	CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 WHERE CONSIDERAR='S' AND CARGADO='N' AND VALIDADONEW='N'
					 AND SUBSTR(NOMBRE,1,10)=SUBSTR(NOMBRENEW,1,10) 
   				FOR UPDATE OF CARGADO;
BEGIN
   FOR v1 IN C1
   LOOP
   	ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
   	UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

-- select count(*) from aliasdni: 2585

DECLARE
	CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 WHERE CONSIDERAR='S' AND CARGADO='N' AND VALIDADONEW='N'
					 AND SUBSTR(NOMBRE,1,10)<>SUBSTR(NOMBRENEW,1,10) 
   				FOR UPDATE OF CARGADO;
BEGIN
   FOR v1 IN C1
   LOOP
   	ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
   	UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

-- select count(*) from aliasdni: 2629

-- calculamos el NIF y rellenamos a ceros

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 
                WHERE NOMBRE=NOMBRENEW AND CONSIDERAR='S' AND CARGADO='N' AND EXISTENIFNEW='S' AND VALIDADONEW IN ('A','N') 
				FOR UPDATE OF CARGADO; 
BEGIN
   FOR v1 IN C1
   LOOP
   	   ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
	   UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

-- select count(*) from aliasdni: 2905

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 
                WHERE substr(NOMBRE,1,20)=substr(NOMBRENEW,1,20) AND 
				      CONSIDERAR='S' AND CARGADO='N' AND EXISTENIFNEW='S' AND VALIDADONEW IN ('A','N') 
				FOR UPDATE OF CARGADO; 
BEGIN
   FOR v1 IN C1
   LOOP
   	   ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
	   UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

-- select count(*) from aliasdni: 2926

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 
                WHERE substr(NOMBRE,1,15)=substr(NOMBRENEW,1,15) AND 
				      CONSIDERAR='S' AND CARGADO='N' AND EXISTENIFNEW='S' AND VALIDADONEW IN ('A','N') 
				FOR UPDATE OF CARGADO; 
BEGIN
   FOR v1 IN C1
   LOOP
   	   ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
	   UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

-- select count(*) from aliasdni: 2949

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 
                WHERE substr(NOMBRE,1,10)=substr(NOMBRENEW,1,10) AND 
				      CONSIDERAR='S' AND CARGADO='N' AND EXISTENIFNEW='S' AND VALIDADONEW IN ('A','N') 
				FOR UPDATE OF CARGADO; 
BEGIN
   FOR v1 IN C1
   LOOP
   	   ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
	   UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

-- select count(*) from aliasdni: 2982

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 
                WHERE substr(NOMBRE,1,5)=substr(NOMBRENEW,1,5) AND 
				      CONSIDERAR='S' AND CARGADO='N' AND EXISTENIFNEW='S' AND VALIDADONEW IN ('A','N') 
				FOR UPDATE OF CARGADO; 
BEGIN
   FOR v1 IN C1
   LOOP
   	   ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
	   UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;

-- select count(*) from aliasdni: 3017

DECLARE
   CURSOR C1 IS SELECT NIFCONTRI,NIFNEW FROM MAMEN_NIFS_9 
                WHERE substr(NOMBRE,1,5)<>substr(NOMBRENEW,1,5) AND 
				      CONSIDERAR='S' AND CARGADO='N' AND EXISTENIFNEW='S' AND VALIDADONEW IN ('A','N') 
				FOR UPDATE OF CARGADO; 
BEGIN
   FOR v1 IN C1
   LOOP
   	   ADDMOTES(v1.NIFCONTRI||'/',v1.NIFNEW);
	   UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;
   END LOOP;
END;


-- select count(*) from aliasdni: 3050
-- select count(*) from contribuyentes: 135566

DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT a.nifcontri,a.nifnew,a.nombre,c.via,c.calle,c.numero,c.escalera,c.planta,
   						  c.piso,c.codigo_postal,c.poblacion,c.provincia,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
					 FROM MAMEN_NIFS_9 A,CONTRIBUYENTES C
    				 WHERE A.NIFCONTRI=C.NIF AND A.CONSIDERAR='S' AND A.CARGADO='N' AND A.EXISTENIFNEW='N' FOR UPDATE OF A.CARGADO;
			
BEGIN

	FOR v1 IN C1
	LOOP  		
	   
		INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFNEW,v1.NOMBRE,v1.VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PLANTA,v1.PISO,v1.POBLACION,
   			v1.PROVINCIA,v1.CODIGO_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','N');        	
   	
   
   END LOOP;
END;


DECLARE       
   CURSOR C1 IS SELECT a.nifcontri,a.nifnew,a.nombre,c.via,c.calle,c.numero,c.escalera,c.planta,
   						  c.piso,c.codigo_postal,c.poblacion,c.provincia,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
					 FROM MAMEN_NIFS_9 A,CONTRIBUYENTES C
    				 WHERE A.NIFCONTRI=C.NIF AND A.CONSIDERAR='S' AND A.CARGADO='N' AND A.EXISTENIFNEW='N' FOR UPDATE OF A.CARGADO;
			
BEGIN

	FOR v1 IN C1
	LOOP   
	   
	     	 
   	      ADDMOTES(v1.nifcontri||'/',v1.NIFNEW);
   	
   	      UPDATE MAMEN_NIFS_9 SET CARGADO='S' WHERE CURRENT OF C1;		  
	   
   
   END LOOP;
END;

ORA-02291: restricción de integridad (TORREJON.ALIASNIF) violada - clave principal no encontrada
ORA-06512: en "TORREJON.ADDMOTESWRITE", línea 64
ORA-01403: no se han encontrado datos
ORA-06512: en "TORREJON.ADDMOTES", línea 7
ORA-06512: en línea 19


-- select count(*) from contribuyentes: 136431
