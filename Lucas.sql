-- ENERO
-- Baza: Para poner bastidor a vehículos que no tienen a partir de la matrícula que viene
	en trafico:	update vehiculos v set bastidor=(select MAX(bastidor) from trafico_new where
	replace(matricula,' ','')=trim(v.matricula)||trim(v.numero)||trim(v.letra))
	where bastidor is null and trim(v.matricula)||trim(v.numero)||trim(v.letra)
	in (select replace(matricula,' ','') from trafico_new)
-- Ateco: Digitalizaciones.
	select f_1acuse,acuse1,notificado,f_notificacion,last_acuse,f_last_acuse,count(*)  from notificaciones where n_relacion='2004/00036' and n_orden in (select n_orden from imagenes_noti where ayto='102' and n_relacion='2004/00036') group by f_1acuse,acuse1,notificado,f_notificacion,last_acuse,f_last_acuse
	select notificado,f_notificacion,f_ingreso,fecha_de_baja,f_suspension,count(*) from valores where ayto='102'  and orden_apremio in (select N_ORDEN from imagenes_noti where ayto='102'and n_relacion='2004/00036') and relacion_apremio='2004/00036' group by notificado,f_notificacion,f_ingreso,fecha_de_baja,f_suspension
	update valores set notificado='S',f_notificacion=to_date('03/01/2005','dd/mm/yyyy') where ayto='102' and relacion_apremio='2004/00036' and orden_apremio in (select codigo from TMP_IMAGENES)
	update notificaciones set f_1acuse=to_date('03/01/2005','dd/mm/yyyy'),f_notificacion=to_date('03/01/2005','dd/mm/yyyy'),f_last_acuse=to_date('03/01/2005','dd/mm/yyyy'),acuse1='0101',notificado='S',last_acuse='0101' where n_relacion='2004/00036' and n_orden in (select CODIGO FROM TMP_IMAGENES)
-- Motril: Borrar todas las cuentas de un lote
	create or replace procedure lucasp as cursor cCuentas is select * from cuentas_lotes where 
	lote in ('2003/00201');    begin for v_cuentas in cCuentas loop	
    Borra_cuenta(v_cuentas.ID);	end loop; end; /
-- Cuentas anuales revisión:
	ateco - armilla - albuñol - salobreña - chinchon - catoure 
	MOTRIL - REQUENA - BAZA - BURJASOT 
	**TORREJON**
    SELECT V.FECHA_DE_BAJA,B.FECHA,B.TIPO_BAJA,COUNT(*) 
    FROM BAJAS B, VALORES V WHERE V.ID=B.VALOR AND (B.FECHA<>V.FECHA_DE_BAJA OR V.FECHA_DE_BAJA IS NULL)
    AND B.TIPO_BAJA<>'BN'
    GROUP BY V.FECHA_DE_BAJA,B.FECHA,B.TIPO_BAJA
--
-- FEBRERO
--
-- CATOURE
  SELECT * FROM ZONAS WHERE ZONA IN ('06','17','63','68','78','79','83','33','L0','L1','L2','L3','L4','L5','L6','L7') ORDER BY NOMBRE
  SELECT * FROM MUNICIPIOS WHERE AYTO IN ('006','017','063','068','078','079','083','033','106','117','163','168','178','179','183','133') order by nombre
  update lucas set ayto='106' where zona='L0' --WHERE ZONA='06'
  update lucas set ayto='117' where zona='L1' --WHERE ZONA='17'
  update lucas set ayto='133' where zona='L2' --WHERE ZONA='33'
  update lucas set ayto='163' where zona='L3' --WHERE ZONA='63'
  update lucas set ayto='168' where zona='L4' --WHERE ZONA='68'
  update lucas set ayto='178' where zona='L5' --WHERE ZONA='78'
  Update lucas set ayto='179' where zona='L6' --WHERE ZONA='79'
  update lucas set ayto='183' where zona='L7' --WHERE ZONA='83'
  select distinct(expediente) FROM VALORES WHERE PADRON='000011' and year='2004'
  AND AYTO IN ('006','017','063','068','078','079','083','033') and expediente is not null
  valores
  ingresos
  bajas
  propuestas_baja
  cargos
  desglose_cargos
  incidencias_c60
  ingresos_indebidos
  liquidaciones¿?
  CREATE TABLE LUCAS AS SELECT ID FROM VALORES WHERE 
  AYTO IN ('006','017','063','068','078','079','083','033') 
  AND PADRON='000011' AND TIPO_DE_OBJETO='R' AND YEAR='2004'
  UPDATE VALORES V SET AYTO='1'||SUBSTR(AYTO,2,2) WHERE ID IN (SELECT ID FROM LUCAS WHERE ID=V.ID)
  -- AYTO IN ('006','017','063','068','078','079','083','033') AND PADRON='000011' AND TIPO_DE_OBJETO='R' AND YEAR='2004'
  UPDATE INGRESOS V SET AYTO='1'||SUBSTR(AYTO,2,2) WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID)
  -- AYTO IN ('006','017','063','068','078','079','083','033') AND PADRON='000011' AND TIPO_DE_OBJETO='R' AND YEAR='2004'
  UPDATE INGRESOS V SET ZONA='L0' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='06'
  UPDATE INGRESOS V SET ZONA='L1' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='17'
  UPDATE INGRESOS V SET ZONA='L2' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='33'
  UPDATE INGRESOS V SET ZONA='L3' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='63'
  UPDATE INGRESOS V SET ZONA='L4' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='68'
  UPDATE INGRESOS V SET ZONA='L5' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='78'
  UPDATE INGRESOS V SET ZONA='L6' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='79'
  UPDATE INGRESOS V SET ZONA='L7' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='83'
  SELECT DISTINCT(AYTO),COUNT(*) FROM INGRESOS GROUP BY AYTO,CODIGO_OPERACION HAVING COUNT(DISTINCT(AYTO))>1
  SELECT DISTINCT(ZONA),COUNT(*) FROM INGRESOS GROUP BY ZONA,CODIGO_OPERACION HAVING COUNT(DISTINCT(ZONA))>1
  UPDATE BAJAS V SET AYTO='1'||SUBSTR(AYTO,2,2) WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID)
  UPDATE BAJAS V SET ZONA='L0' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='06'
  UPDATE BAJAS V SET ZONA='L1' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='17'
  UPDATE BAJAS V SET ZONA='L2' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='33'
  UPDATE BAJAS V SET ZONA='L3' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='63'
  UPDATE BAJAS V SET ZONA='L4' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='68'
  UPDATE BAJAS V SET ZONA='L5' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='78'
  UPDATE BAJAS V SET ZONA='L6' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='79'
  UPDATE BAJAS V SET ZONA='L7' WHERE VALOR IN (SELECT ID FROM LUCAS WHERE ID=V.ID) AND ZONA='83'
  SELECT DISTINCT(AYTO),COUNT(*) FROM BAJAS GROUP BY AYTO,CODIGO_OPERACION HAVING COUNT(DISTINCT(AYTO))>1
  SELECT DISTINCT(ZONA),COUNT(*) FROM BAJAS GROUP BY ZONA,CODIGO_OPERACION HAVING COUNT(DISTINCT(ZONA))>1
  -- 
  insert into lucas(ayto,padron,year,periodo,recibo) values ('006',	'000011',	'1997',	0,	90175)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('006',	'000011',	'1997',	0,	90210)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000001',	'2001',	0,	450)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000001',	'2001',	0,	493)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000001',	'2002',	0,	450)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000001',	'2002',	0,	493)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000001',	'2004',	0,	10995)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000001',	'2004',	0,	10996)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000002',	'2001',	0,	3092)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000002',	'2002',	0,	3092)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000002',	'2004',	0,	73775)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000003',	'2003',	0,	936)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000003',	'2004',	0,	89134)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'1995',	0,	144)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'1995',	0,	1293)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'1997',	0,	611)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'2001',	0,	493)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'2002',	0,	493)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'2002',	0,	1277)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'2002',	0,	2193)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'2003',	0,	1277)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'2003',	0,	2264)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('017',	'000011',	'2003',	0,	2385)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('068',	'000001',	'2004',	0,	38810)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'2001',	0,	1681)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'2001',	0,	1135)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'1990',	0,	6512)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'1992',	0,	2645)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'1995',	0,	79302)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'1999',	0,	9664)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'2000',	0,	7924)
  insert into lucas(ayto,padron,year,periodo,recibo) values ('033',	'000001',	'2000',	0,	99079)
--
-- MARZO
-- Burjasot - CUENTAS ANUALES
  select COUNT(*),SUM(PRINCIPAL) from IMPORTE_valores where vol_eje='E' and trunc(F_CARGO,'DD') <= TRUNC(TO_DATE('31/12/2004','DD/MM/YYYY'),'DD') and (F_INGRESO is null or trunc(F_INGRESO,'dd') >TRUNC(TO_DATE('31/12/2004','DD/MM/YYYY'),'DD')) and (FECHA_DE_BAJA is null or trunc(FECHA_DE_BAJA,'dd') > TRUNC(TO_DATE('31/12/2004','DD/MM/YYYY'),'DD')) 
  select sum(I.principal) as sumprin from ingresos I, VALORES V where I.valor=V.ID AND  I.PARCIAL_O_COBRO='P' AND V.vol_eje='E'  and I.year_ingre<= '2004'  and trunc(V.F_CARGO,'DD') <= TRUNC(TO_DATE('31/12/2004','DD/MM/YYYY'),'DD') and (V.F_INGRESO is null or trunc(V.F_INGRESO,'dd') >TRUNC(TO_DATE('31/12/2004','DD/MM/YYYY'),'DD')) and (V.FECHA_DE_BAJA is null or trunc(V.FECHA_DE_BAJA,'dd') > TRUNC(TO_DATE('31/12/2004','DD/MM/YYYY'),'DD'))
  SELECT V.ID,V.F_INGRESO FROM VALORES V WHERE F_INGRESO IS NOT NULL AND TRUNC(F_INGRESO,'DD')<>(SELECT TRUNC(FECHA,'DD') FROM INGRESOS WHERE PARCIAL_O_COBRO='C' AND VALOR=V.ID)
  uPDATE VALORES V SET F_INGRESO=(SELECT MAX(FECHA) FROM INGRESOS WHERE VALOR=V.ID) WHERE ID IN (SELECT V.ID FROM VALORES V WHERE F_INGRESO IS NOT NULL AND TRUNC(F_INGRESO,'DD')<> (SELECT TRUNC(FECHA,'DD') FROM INGRESOS WHERE PARCIAL_O_COBRO='C' AND VALOR=V.ID))
  Para cuadrar estas cuentas anuales, el pdf de pendiente a 31/12/2003 lo pasé a txt, lo dejé plano desde el 
  crimson quitando las cabeceras, y lo metí en la base de datos con un procedimiento almacenado que insertaba 
  en la tabla lucasold.Luego cree la tabla lucasnew con los valores que me daba a día de hoy la aplicacion de 
  pendiente a 31/12/2003. Tuve que reajustar algunos valores que tienen la clave valor repetida (porque en el pdf
  no hay id de valor, sólo la clave valor), y comparé las dos tablas, obteniendo valores que había de más en
  el listado a día de hoy. El motivo es que valores ingresados por fraccionamiento tenían una fecha de ingreso
  distinta en valores y en ingresos (en valores de 2004 ó 2005, y en ingresos de 2003 ó 2004, respectivamente).
  Al cambiar internamente esas fechas de valores, los importes ya cuadran perfectamente con las cuentas anuales. HECHO.

-- WEB DE INCIDENTES --
-- Resumen: Incidencias por clientes
select c.nombre,count(*) as cuantos from tincidentes i , tclientes c where i.cliente=c.id group by c.nombre order by cuantos desc
-- Resumen: Seguimiento de incidencias por clientes
select c.nombre,count(*) as cuantos from tseguimiento_incidentes s, tincidentes i, tclientes c where s.idincidente=i.id and c.id=i.cliente group by c.nombre order by cuantos desc, c.nombre 
-- Resumen : Tipos de incidencias 
select T.DESCRIPCION,count(*) as cuantos from tincidentes i , TTIPOS_INCIDENCIAS T where T.ID=I.TIPO group by T.DESCRIPCION ORDER BY cuantos desc ,T.DESCRIPCION
-- Resumen: Estado de las incidencias
select DECODE(ESTADO,'FI','FINALIZADO','LE','LEIDO','PF','REALIZADO','CO','CONTESTADO','PENDIENTE') AS ESTADO ,count(*) as cuantos from tincidentes i group by ESTADO ORDER BY cuantos desc ,ESTADO
-- Detalle : Tipo de incidencia por clientes
select c.nombre,T.DESCRIPCION,count(*) as cuantos from tincidentes i , tclientes c, TTIPOS_INCIDENCIAS T where i.cliente=c.id AND T.ID=I.TIPO group by c.nombre,T.DESCRIPCION ORDER BY C.NOMBRE,cuantos desc ,T.DESCRIPCION
-- Consulta de los que se han conectado hoy
select t.fecha,t.id,c.nombre from tcontrol_accesos t, tpersonas_contactos c
where c.id=t.idcontacto and t.idcliente<>242 and trunc(fecha,'dd')=trunc(sysdate,'dd') 
order by fecha desc
-- FIN DE WEB DE INCIDENTES --

--
-- ABRIL
--
-- Motril. Permitir al igual que en inmuebles, pasar de vehículos a cuentas temporalmente
	sin perder la información del embargo de vehículos.Poder tener un expediente cancelado de un embargo temporalmente
	para hacer cosas en otro embargo. Pedido en la web de Incidentes. Consultar ahí. HECHO.
-- Motril. En embargos poder decir si un documento genera control de notificaciones.
    Pedido en la web de Incidentes. Consultar ahí. HECHO.
-- Motril. Paco. Cambiar el texto de los informes para que en vez de decir ingreso en embargo de ... diga 
	ingreso por ventanilla o el número de cuenta y más pequeño lo del embargo. HECHO.
-- Salobreña. Andrés. Ingreso por antiguedad de los recibos cuando se trata de un fracc.
	La ley general tributaria va a cambiar. Pedido en la web de incidentes. Consultar ahí. HECHO.
-- Salobreña.Raul.Representante en la consulta de contribuyentes como en IBI. HECHO.

-- ---------------------------------------------------------------------------
-- Error del 10% en recargos 
-- ---------------------------------------------------------------------------
  create table lucas as select id from valores where expediente is not null and abs(recargo-round(principal*0.2,2))>0.01
  delete from lucas l where id in (select id from valores where id=l.id and principal=0)
  delete from lucas l where id in (select id from valores where id=l.id and abs(recargo-round(cuota_inicial*0.2,2))<0.02)
  select v.id,v.cuota_inicial,v.principal,round(v.principal*0.2,2),v.recargo,v.f_ingreso,v.fecha_de_baja,v.f_suspension from valores v, lucas l where l.id=v.id and f_suspension is null and f_ingreso is null and fecha_de_baja is null

  SELECT V.ID,V.PRINCIPAL,V.RECARGO,V.F_INGRESO,V.COD_INGRESO FROM LUCAS L, VALORES V, INGRESOS I WHERE L.ID=V.ID AND V.ID=I.VALOR AND I.PARCIAL_O_COBRO='C' AND I.NUMERO_DE_DATA IS NULL AND V.F_INGRESO IS NOT  NULL ORDER BY V.F_INGRESO DESC
--  
  update valores set recargo=round(principal*0.2,2) where expediente is not null and f_ingreso is null and f_suspension is null and fecha_de_baja is null and recargo=round(principal*0.1,2) and id in (select id from lucas)
  update lucas l set pasado='S' where id in (select id from valores where id=l.id and  recargo=round(principal*0.2,2) )
--
  select n_cargo,count(*) from valores where fin_pe_vol>to_date('30/06/2004','dd/mm/yyyy') and notificado='S' group by n_cargo

  select count(*) from valores where expediente is not null and abs(recargo-round(principal*0.2,2))>0.01 and principal>0 group by abs(recargo-round(principal*0.2,2))  

  -- cullar,pulianas, maracena, albuñol : no

  -- DURCAL  .ACTUALIZADO 2. no tiene errrores.
  -- MISLATA .ACTUALIZADO 2. no tiene errrores.
  -- REQUENA .ACTUALIZADO 2. no tiene errrores.
  -- MOTRIL  .ACTUALIZADO 2. TENÍA ERRORES, CORREGIDOS
  -- BAZA     .ACTUALIZADO 2. TIENE ERRORES. CORREGIDOS.
   create table lucas as select id from valores where expediente is not null and abs(recargo-round(principal*0.2,2))>0.01
   delete from lucas l where id in (select id from valores where id=l.id and principal=0)
   delete from lucas l where id in (select id from valores where id=l.id and abs(recargo-round(cuota_inicial*0.2,2))<0.02)
   update valores set recargo=round(principal*0.2,2) where expediente is not null and f_ingreso is null and f_suspension is null and fecha_de_baja is null and recargo=round(principal*0.1,2) and id in (select id from lucas)
   update lucas l set pasado='S' where id in (select id from valores where id=l.id and  recargo=round(principal*0.2,2) )
   
    975 mal: 399 ingresados (56 no datados le hago consulta en excel)
             2 anulados
             10 suspendidos
             564 pendientes, de los que a 554 le pongo el recargo al 20%

  -- ATECO   .ACTUALIZADO 2. TIENE ERRORES. Son de haber grabado masivamente el acuse. de 2611, se ponen 1408 pendientes
	correctamente, pero faltan 1192 ingresados y 11 anulados. Hay 1171 ingresados hace 10 días, ¿reponer y volver
	a ingresar? La tabla lucasrecargo tiene los 2611 valores
	Los ingresos del 25/04/2005 y 26/04/2005 son todos por embargo de cuentas, y tienen el 10%. suman 1171 ingresos.
	se descarta reponer ingresos,porque los ingresos parciales ponen cuentas_lotes.hecho='N', pero como ya se ha
	emitido una nueva diligencia, importe_retenido=0, por lo que se perderían esos importes. Por eso se busca cómo
	modificar los datos. PERO ESTA EN BORRA_CUENTAS_LOTES, DEBERÍA PONERSE EN CUENTAS_LOTES¡¡¡

	pdate ingresos set tipo_ingreso='EP',PARCIAL_O_COBRO='P', RECARGO=ROUND( ((PRINCIPAL+RECARGO)*20)/120,2),
    PRINCIPAL=PRINCIPAL+RECARGO- ROUND( ((PRINCIPAL+RECARGO)*20)/120,2)
     where parte_del_dia in (111468, 111469, 111470, 111471, 111476, 111477, 111478, 111482,111507)
   and valor in (select id from lucas3)
   EN VALORES: F_INGRESO, RECARGO, COD_INGRESO
   EN EXPEDIENTES: f_INGRESO, COD_INGRESO=NULL 

  -- SALOBREÑA.ACTUALIZADO 2. TIENE ERRORES.
    1823 mal: 1112 ingresados (10 sin datar)
             53 anulados
             57 suspendidos
             601 pendientes, de los que 148 tienen el 10% (se pasan al 20%), 10 el 5% (se pasan al 20%), 
             					2 desconocidos, y 441 tienen recargo 0
   
  -- BURJASOT .ACTUALIZADO 2. TIENE ERRORES.
    269 mal: 214 ingresados (3 sin datar)
             6 anulados
             52 suspendidos (6 anulados, 2 ingresados)
             5 pendientes, de los que 1 tiene el 10% ('RM') y 4 tienen recargo 0

  -- CHINCHON .ACTUALIZADO 2. TIENE ERRORES.
    326 mal: 316 ingresados (2 sin datar)
             10 pendientes, de los que 6 tiene el 10% (pasados al 20%) y 4 tienen recargo 0
             					
  -- CATOURE  .ACTUALIZADO 2. TIENE ERRORES.
    550 mal: 513 ingresados (TODOS SIN DATAR)
             1 anulados
             4 suspendidos (1 INGRESADO) 
             33 pendientes, de los que 10 tiene el 10% (todos 'RM') y 23 tienen recargo 0
   Tiene valores sin final de periodo voluntario

  -- ARMILLA  .ACTUALIZADO 2. TIENE ERRORES. Hay 1014. 908 ingresados, 53 pendientes y 53 anulados.
	Se pasan 38 valors, el resto está a 'RM'

  -- TORREJON .ACTUALIZADO 2. TIENE ERRORES. hAY 4826. 2016 ingresados, 75 pendientes (71 con 'RM')
		, 71 anulados Y 2695 SUSPENDIDOS.
   ID		PRINCIPAL	RECARGO	FIN_PE_VOL
   345725	75066,41	7506,64	20/01/2001 13:08:21
   435056	69			6,9	
   435076	69			6,9	
   435108	69			6,9	
   Tiene valores sin fin de periodo voluntario.
   
  -- VALDEAVERUELO
  

***************************************************************************************
********** PENDIENTE ******************************************************************
***************************************************************************************
----------------------------------------------------------------------------------------
-- DATOS_CUADERNO60 tiene campos TOTAL y TOTAL_EUROS. Genera un fichero de notificaciones
		Se accede a la tabla tmp_municipios que no existe en los informes.DatosPadron.pas
-- listados_registro: mal acceso a TABLA_AUX_LISTADOS_REGISTRO
	REGISTRO_genera_estadisticas -> registroGrafico en GT
--*****************************************************************************************
--*****************************************************************************************
-- **********************************************************************************
-- PENDIENTE DE RESPUESTA:
-- **********************************************************************************
-- **********************************************************************************
-- Armilla. Emasagra. Leer los discos para pasarlos al punteo.
	El disco de agua se pasa a punteo correctamente, salvo el NIF, que 
	viene con 7 caracteres en el fichero.
	El disco de basura, además de tener 7 caracteres para el NIF, tiene el recibo numero
	39 repetido dos veces, y el recibo numero 0, 30 veces, por lo que el detalle se
	vuelve inútil. Se envía e-mail 9-4-03.A espera de contestación.
	-- Ya ha llegado el disco de Emasagra. Está en Armilla. Buscarlo y mirar si es todo
	correcto. Hay algunas incidencias, que se le envían por correo. Se corrigen, por lo 
	que solo falta poner un número de cargo y ya estará preparado para pasar a valores.
	Queda nuevamente pendiente de contestación.
-- Chinchon. Recibos ingresados que tienen datos de las notificaciones inconsistentes
	con la información de la tabla de valores: 1412 recibos:
	select v.id,v.f_notificacion,n.f_notificacion,n.acuse1,v.f_ingreso,v.fecha_de_baja 
	from valores v, notificaciones n where v.id=n.valor and v.notificado<>n.notificado
	y 64 recibos con la consulta select id,relacion_apremio,orden_apremio,notificado,f_notificacion,f_ingreso,fecha_de_baja
	from valores where notificado='S' and id not in (select valor from notificaciones).
	Se le envía el listado para que conteste que hacer con estos datos (01/08/03).
-- Pulianas.Jose María. Da error al imprimir plusvalias -> listados generales -> notario
	al elegir un notario de la lista. Se modifica en Delphi y ya funciona.
	Además tiene 4 notarios con el mismo nombre	para borrar los 3 que sobran. Pendiente
	de conexión (Antonio de vacaciones hasta el 19/09/2003, hoy es 27/08/2003).	
-- Salobreña. Fraccionamientos en Voluntaria. Qué hacer cuando vence un plazo, y cuando 
	se incumple	el fraccionamiento.
-- Agustin. La bonificacion en rustica está mal. En la Caixa, Cajamadrid, Cuaderno19 y 
	pase a recaudacion pone %bonificacion y formatea a 900. Se cambia el texto y el formato.
	Falta saber que hacer con el botón de bonificación de delphi y con la tabla 
	boni_exen_rus.
-- Salobreña.Susana. Le devuelven por segunda vez una fase1 de Unicaja. Le digo que me 
	envíe un correo con el motivo y el fichero.Jorge. Le han devuelto un disco de fase 1 
	de Unicaja.Me lo enviará por correo.2/12/03
-- Salobreña. Raul. No le imprimen los recibos de rustica. Llamará para decir el 
	error que le pone (12/02/2004).

-- **********************************************************************************
-- ---------------------------------------------------------------------------------------
-- -----------   MOTRIL ------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------
-- Motril. EIS En la comparativa de ingresos de un solo año no lo hace partiendo 
	del pendiente de ese año, sino del pendiente total, y lo quiere de la otra forma.
-- Motril.Bajas por referencia es distinto de bajas por insolvencia. Cuando das de baja un 
	expediente por incobrable, los recibos se proponen por insolvencia, para luego pasar a
	ser bajas por insolvencia. Cuando llega un recibo nuevo, se propone por referencia, 
	y debería generar baja por referencia. En el caso de dar como insolvente a un NIF
	los recibos que tuvieran se propondrian de baja por insolvencia. Habría que separar
	ambos casos, que ahora están entremezclados.
-- ---------------------------------------------------------------------------------------
-- Baja por principal (Descripcion_Baja).Al borrar o consultar una baja de un recibo
	que tenga más de una, el borrado y la consulta la realiza mal. Postpuesto.
-- ---------------------------------------------------------------------------------
-- Ateco. Paco Mingorance. Listado de expedientes sin cuentas y con pendiente mayor de 300
	euros, para enviarles una carta. Crea la vista VWINFORMEEXPE_CC en la base de datos.
	Esta vista deberá eliminarse y prohibir modificar el esquema.
-- ------------------------------------------------------------------------------
-- **********************************************************************************
-- Baza. Esteban. Pide poder asociar una cuenta al contribuyente para las domiciliaciones,
	de tal modo que al marcar domiciliado aparezca automáticamente esa domiciliación que 
	tenga grabada.(07/2003)
-- Preguntas a clientes para servicio tecnico. Que modo de comunicacion considera mas efectivo
-- ----------------------------------------------------
-- Salobreña.Andrés. En la providencia de apremio, pone como fecha de apremio la de 
	generación de la providencia, y quiere que sea la del campo f_apremio de los valores,
	porque hay cargos que tienen valores (liquidaciones) con distintas fechas y quiere
	que cada una salga con esa misma fecha en la providencia. 
	Compruebo que al pasar a ejecutiva se cambia la f_apremio de todos los recibos
	del cargo. Debería pasar en su fecha cada tipo de liquidaciones. 

-- Armilla. Errores al poder modificar manualmente el estado de los recibos.
	IBI.VEHICULOS.RUSTICA.EXACCIONES.IAE.
	Hacen update en recibos_... del campo estado_banco.

-- *************************************************************************************
http://www.dipgra.es/BOP/bop.asp

-- --------------------------------------
-- Burjasot.María. Ha hecho ingresos con sólo principal, y en recargo_20 pone 0 porque
	ingresa 0, y luego no le cuadran las cuentas porque le falta ese principal.

-- Burjasot. Al terminar un embargo de cuentas, no se elimina la marca de fecha_diligencia
	del expediente, y no deja imprimir relaciones de notificaciones, debiendo dejar hacerlas.
	No encuentro la situación que deja la fecha_diligencia en el expediente, la pone a null
	desde sin cuenta, desde todo aplicado, al eliminarlos, al aplicar negativos, al aplicar retenciones y al 
	grabar o ingresar desde fuera, puesto que llaman a cuentas_control_estados. Pero se detecta un problema
	con cuentas_control_estados, y es que pone fecha_diligencia=null si no hay cuentas_lotes con D='S' y H='N'
	e importe_retenido=0. Pero si importe_retenido>0 pone fecha_diligencia=null, con lo que se da error.
	Tambien hay inconsistencia con lo que se hace si en_inmuebles='S'.

-- PortalWeb. Avisos: en la domiciliacion de tributos, generación de informes, modificacion de contribuyentes 
	y alta de vehículos. son los 4 unicos casos en los que se modifica la base de datos.

http://p2p.wrox.com/archive/servlets/2001-05/11.asp

http://www.oracle.com/technology/products/designer/demos.htm

-- 	
lucasfpibm
ev1289

foro.evidalia.com -> webmasters -> webmasters www.configuraequipos.com
codeguru.com -> Java Programming (21/10)
--

<script>
  try { 
    netscape.security.PrivilegeManager.enablePrivilege("UniversalXPConnect");
    var pDirProperties=
Components.classes["@mozilla.org/file/directory_service;1"].getService(Components.interfaces.nsIProperties);
    var strUserDir =
pDirProperties.get("ProfD",Components.interfaces.nsIFile);
    alert('My dir: ' + strUserDir.path);
  }catch (e) { alert ("Exception: " + e);
  }
</script>

javac AppletPrueba3.java
jar cf applet.jar AppletPrueba3.class org
jarsigner -keystore miKeystore -storepass prueba -keypass prueba applet.jar prueba
jarsigner -verify applet.jar


http://www.recaudacion.org/citaprevia/login.jsp para los clientes, 
http://www.recaudacion.org/citaprevia/loginPersonal.jsp para el personal
ejemplo de claves para cliente: NIF: 44288025F , poliza: 1111222233334444 y clave a1
ejemplo de clave para medico: digitos:1234567890ABCDEF ,login: alvarez sant (con espacio entre los apellidos) y clave: 1

-- SPEAKWORDS
-- www.sepln.org

 
 
 Prescripción de valores
 PROCEDURE NotiSetLastValid
 PROCEDURE PON_FECHA_BOP_EXPE

 
create or replace procedure PrescripcionValores(xZona in char, xFecha in date, xAyto in char)
as

TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type
vCURSOR    	 	tCURSOR;     -- declare cursor variable
vSQL			varchar2(2000);
xCodigo			varchar2(3);

xInserta 		boolean default False;

begin

	delete from TmpDeudasVivas where usuario=uid;

	vSQL:='SELECT id,ayto,padron,year,periodo,recibo,nif,nombre,principal,expediente,fin_pe_vol,f_notificacion,f_last_noti,clave_concepto '||
			'FROM VALORES ' ||
			'WHERE PROPU_INSOLVENTE=''N'' ' ||
			'AND FIN_PE_VOL <=xFECHA' ||
			'AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL';

			
	if xAyto='000' then
		vSQL:=VSQL||'AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=xZONA)';
		xCodigo:=xZona;
	else
		vSQL:=VSQL||'AND AYTO=xAYTO';
		xCodigo:=xAyto;
	end if;
		
	
	for vValores in vSQL using xFecha,xCodigo loop
	
		xInserta:=False;
	
		--Si no tiene expediente para la prescripcion o no tiene fecha de notificacion o la fecha de notificacion es anterior a la fecha
		--indicada por pantalla
		if (vValores.EXPEDIENTE IS NULL) and ((vValores.F_Notificacion is null) or (vValores.F_Notificacion<=xFecha)) then
		
			xInserta:=True;

		else
		
			--Si tiene expediente
			if vValores.EXPEDIENTE IS NOT NULL then
				
				--quiere decir que no se ha realizado ningun tramite con este valor, se toma la fecha de notificacion de apremio, 
				--si es anterior a la fecha indicada por pantalla está prescrito
				if (vValores.F_LAST_NOTI is null and vValores.F_Notificacion<=xFecha) then
				
					xInserta:=True;
					
				end if;
				
				--quiere decir que se ha realizado algun tramite pero la fecha de la ultima notificacion es anterior a la fecha
				--indicada por pantalla esta prescrito
				if (vValores.F_LAST_NOTI is not null and vValores.F_LAST_NOTI<=xFecha) then
					
					xInserta:=True;
					
				end if;
				
			end if; --final del vValores.EXPEDIENTE IS NOT NULL 
			
		end if; --final del (vValores.EXPEDIENTE IS NULL) and ((vValores.F_Notificacion is null) or (vValores.F_Notificacion<=xFecha)) 

		
		if xInserta then
			--En el campo f_apremio se graba la fecha de la ultima notificacon
			insert into TmpDeudasVivas(xID,DNI_DEUDOR,NOMBRE,AYTO,ZONA,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
	 			IDEXPE,PRINCIPAL,FIN_PE_VOL,F_APREMIO,F_NOTIFICACION)
	 		values (vValores.ID,vValores.NIF,vValores.Nombre,vValores.Ayto,xZona,vValores.Padron,vValores.Year,vValores.Periodo,vValores.Recibo,
	 			vValores.Clave_Concepto,vValores.Expediente,vValores.Principal,vValores.Fin_Pe_Vol,vValores.F_Last_Noti,vValores.F_Notificacion);
	 	end if;
			
	
	end loop; --final del cursor



end;

select t.fecha,t.id,c.nombre from tcontrol_accesos t, tpersonas_contactos c
where c.id=t.idcontacto and t.idcliente<>242 and trunc(fecha,'dd')=trunc(sysdate,'dd') 
order by fecha desc


Vamos a realizar una pequena aplicacion .NET, con office 2003. 

Se trata de crear una agenda de contactos en Exchange y poder relacionarlos ejemplo 
Ernesto Garcia-Herrera con sus datos de contacto, movil, e-mail, etc, tipo de contacto primer nivel o 
relacion directa o inducida a traves de un tercero. 

Tambien tiene que haber una relacion con los proyectos en los que estamos trabajando y estan abiertos, 
donde se relacionen los eventos que se van produciendo en un proyecto, ejemplo visita al cliente tal el dia tal 
y se pueda adjuntar un documento. 

Todo esto desde el punto de vista de smart client es decir sin salir de office, word, excell o outlook. 

Que descanseis, nos espera un trimestre fuerte fuerte. 
Antonio Pérez Caballero 

jdbc:oracle:thin:@SERVER2003:1521:CRMWEB

create public database link PASE.US.ORACLE.COM using 'PASETORREJON'
-- ------------------------------------------
I want to talk with Peter


Establish communication

Playing football

Go on holidays to St.Peter

-- ------------------------------------------

Estamos estudiando nuevos ajustes de nuestra aplicación relativas al funcionamiento de los expedientes ejecutivos.

Para conseguir una nueva versión lo más útil posible, nos gustaría contar con tu opinión acerca de algunos temas:

1. Acumulaciones/Aminoraciones. ¿Una entrega parcial a un valor debe desembocar en una diligencia de aminoración?

2. Entregas al expediente. Si llega un traspaso, a un expediente con fraccionamientos, embargos y registros libres,
	¿que hacer con ese ingreso, a qué valores aplicarlo?

3. Fraccionamientos. ¿Aplicación por antiguedad de los recibos del fraccionamiento? 

4. Pase temporal a otros embargos. ¿De que embargo a que embargo?

5. Entregas proporcionales. ¿son inútiles?

6. Expedientes como varios bloques por separado. ¿Como conjugar con los ingresos?

7. ¿Que saldría en el informe de deudas del expediente?


CREATE TABLE VALORES_EMBARGOS(
  VALOR      INTEGER NOT NULL, -- Id del valor
  IDEXPE     INTEGER NOT NULL, -- Id del expediente
  TRAMITE    CHAR(1) NOT NULL, -- Trámite de embargo
  IDEMBARGO  INTEGER,              -- Id del trámite de embargo
  FECHA      DATE DEFAULT SYSDATE, -- Fecha en la que entra el registro en la tabla
  CONSTRAINT VE_VALOR
  FOREIGN KEY(VALOR)
  REFERENCES VALORES(ID),
  CONSTRAINT VE_IDEXPE
  FOREIGN KEY(IDEXPE)
  REFERENCES EXPEDIENTES(ID)
)

ALTER TABLE BITACORAS ADD EMBARGO CHAR(1) CHECK(EMBARGO IN ('1','3','4','8','X'))
ALTER TABLE BITACORAS ADD IDEMBARGO INTEGER;
-- DROP CONSTRAINT DE BITACORAS PARA EL MOTIVO
ALTER TABLE BITACORAS ADD CONSTRAINT BITAMOTIVO CHECK(MOTIVO IN('IN','BA','AC','DE','SU','EM'))

INSERT INTO VALORES_EMBARGOS(VALOR,IDEXPE,TRAMITE,IDEMBARGO) 
  SELECT V.ID, E.ID AS IDEXPE, '1', V.ID_INMUEBLES
	FROM EXPEDIENTES E, VALORES V WHERE V.EXPEDIENTE=E.ID AND E.EMBARGO='1'
	AND V.ID_DILIG_ECC IS NOT NULL

INSERT INTO VALORES_EMBARGOS(VALOR,IDEXPE,TRAMITE,IDEMBARGO) 
  SELECT V.ID, E.ID AS IDEXPE, '3', V.ID_INMUEBLES
	FROM EXPEDIENTES E, VALORES V WHERE V.EXPEDIENTE=E.ID AND E.EMBARGO='3'
	AND V.ID_INMUEBLES IS NOT NULL;
    
INSERT INTO VALORES_EMBARGOS(VALOR,IDEXPE,TRAMITE,IDEMBARGO) 
  SELECT V.ID, E.ID AS IDEXPE, '4', V.ID_INMUEBLES
	FROM EXPEDIENTES E, VALORES V WHERE V.EXPEDIENTE=E.ID AND E.EMBARGO='4'
	AND V.ID_INMUEBLES IS NOT NULL;

INSERT INTO VALORES_EMBARGOS(VALOR,IDEXPE,TRAMITE,IDEMBARGO) 
  SELECT V.ID, E.ID AS IDEXPE, '8', V.ID_INMUEBLES
	FROM EXPEDIENTES E, VALORES V WHERE V.EXPEDIENTE=E.ID AND E.EMBARGO='8'
	AND V.ID_INMUEBLES IS NOT NULL;

	


