

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


--
--
--
create or replace procedure AgustinIngresaVCatoure
as
xCod	INT default 0;
cursor cValores is select * from valores where id between 90578 and 100826 and f_ingreso is not null;
begin


	for vValores in cValores loop
	
		CODIGO_OPERACION(xCod);
	
		PkIngresos.WRITE_INGRESO(vVALORES.ID,'INGRESADO EN EL NUEVO SISTEMA','VE',
        				      vValores.F_Ingreso,vValores.Principal,vValores.Recargo,0,0,xCod,'C');

	end loop;

end;
/

create or replace procedure AgustinAnulaVCatoure
as
xError INT default 0;
cursor cValores is select * from valores where id between 90578 and 100826 and fecha_de_baja is not null and f_ingreso is null;
begin


	for vValores in cValores loop

		MAKE_BAJA(vValores.ID,'BA',vValores.Fecha_De_Baja,vValores.Fecha_De_Baja,'APROBADA COMISON DE GOVERNO','APROBADA COMISON DE GOVERNO (AS/400)',xERROR);

	end loop;

end;
/

create or replace procedure AgustinSuspendeVCatoure
as
cursor cValores is select * from valores where id between 90578 and 100826 and f_suspension is not null and f_ingreso is null;
begin


	for vValores in cValores loop
	
	
			UPDATE VALORES SET IS_LIVE='X'	WHERE ID=vValores.ID;

			-- Los incorporamos a las deudas suspendidas
			INSERT INTO SUSPENSIONES_VALORES
         		(valor,ID_EXPE,F_ACUERDO,ORGANISMO,DESCRIPCION)
			VALUES (vValores.ID,null,vValores.F_Suspension,'PENDIENTE RESOLUCION BAIXA','PENDIENTE RESOLUCION BAIXA');	
	
	end loop;

end;
/


--
--
--
create or replace procedure BorraMultasMasiva
as

xERROR	INTEGER;

cursor cMultas is select ID from valores where n_cargo='2003/00019' and ayto='180';

begin


	for vMultas in cMultas loop
	
		MAKE_BAJA(vMultas.ID,'BP','31/07/2003','31/07/2003',
		'PROPUESTA GERENCIA','PRESCRIPCION PERIODO VOLUNTARIO FD.25/2003',xERROR);
			
	end loop;
	
end;
/




