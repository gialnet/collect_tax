create or replace procedure CambiarAnticipos
as
xID			integer;
xAyto 		char(3);
xDescrip 	varchar(50);

cursor cAytoDescrip is select ayto,descripcion from anticipos group by ayto,descripcion;

cursor cAnticipos is select * from anticipos where ayto=xAyto and descripcion=xDescrip
		order by id;

begin


	for vAytoDescrip in cAytoDescrip loop

		xAyto:=vAytoDescrip.Ayto;
		xDescrip:=vAytoDescrip.Descripcion;
		xID:=NULL;
		
		for vAnticipos in cAnticipos loop

			if (xID is null) then
				xID:=vAnticipos.ID;
			end if;
			
			insert into HISTORICO_ANTICIPOS(ANTICIPO,FECHA,IMPORTE)
		
			values (xID,vAnticipos.Fecha,vAnticipos.Importe);
	
		end loop;
		
	end loop;


end;
/