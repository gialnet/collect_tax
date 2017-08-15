CREATE OR REPLACE TRIGGER T_IMPORTE_MULTAS
AFTER UPDATE ON MULTAS
FOR EACH ROW
DECLARE
   xPADRON CHAR(6);   
   xOLDPRINCIPAL FLOAT;
   xDIFERENCIA FLOAT;
BEGIN
    IF ((:OLD.IMP_CADENA<>:NEW.IMP_CADENA) AND (:NEW.IDVALOR IS NOT NULL)) THEN	
		SELECT PRINCIPAL INTO xOLDPRINCIPAL FROM VALORES
		WHERE ID=:NEW.IDVALOR;				
		SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='MULTAS';						
		xDIFERENCIA:=TO_NUMBER(:NEW.IMP_CADENA) - xOLDPRINCIPAL;		
		IF xDIFERENCIA > 0 THEN
			UPDATE VALORES SET PRINCIPAL=TO_NUMBER(:NEW.IMP_CADENA),
		                   	   F_ANULACION_BONI=SYSDATE
			WHERE ID=:NEW.IDVALOR;  
		ELSIF xDIFERENCIA<0 THEN
		   UPDATE VALORES SET PRINCIPAL=TO_NUMBER(:NEW.IMP_CADENA),
		   					  F_ANULACION_BONI=NULL
		   WHERE ID=:NEW.IDVALOR;
		END IF;		
	END IF;		
	IF (((:OLD.MATRICULA<>:NEW.MATRICULA) OR (:OLD.NUMERO<>:NEW.NUMERO) OR (:OLD.LETRA<>:NEW.LETRA)) AND (:NEW.IDVALOR IS NOT NULL)) THEN
		UPDATE VALORES SET CLAVE_CONCEPTO=rtrim(:NEW.MATRICULA)||rtrim(:NEW.NUMERO)||rtrim(:NEW.LETRA),
								 OBJETO_TRIBUTARIO=REPLACE(OBJETO_TRIBUTARIO,GETMATRICULA(:OLD.MATRICULA,:OLD.NUMERO,:OLD.LETRA),GETMATRICULA(:NEW.MATRICULA,:NEW.NUMERO,:NEW.LETRA))
		WHERE ID=:NEW.IDVALOR;
	END IF;
END;
/
CREATE OR REPLACE PROCEDURE IBI_REESTABLECE_INFO wrapped 
0
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
3
7
9000000
1
4
0 
4f
2 :e:
1IBI_REESTABLECE_INFO:
1XID:
1INTEGER:
1XANULADOMI:
1CHAR:
1XCHANGEREC:
1MNIF:
110:
1MNOMBRE:
160:
1MTIPO_VIA_FISCAL:
15:
1MNOMBRE_VIA_FISCAL:
125:
1MPRIMER_NUMERO_FISCAL:
14:
1MESCALERA_FISCAL:
12:
1MPLANTA_FISCAL:
13:
1MPUERTA_FISCAL:
1MCOD_POSTAL_FISCAL:
1MMUNICIPIO_FISCAL:
1MPROVINCIA:
1MPAIS:
1MTIPO_VIA:
1MNOMBRE_VIA:
1MPRIMER_NUMERO:
1MBLOQUE:
1MESCALERA:
1MPLANTA:
1MPUERTA:
1XIDIBI:
1XMUNICIPIO:
1XREF_CATASTRAL:
114:
1XNUMERO_SECUENCIAL:
1XPRIMER_CARACTER_CONTROL:
11:
1XSEGUN_CARACTER_CONTROL:
1XAVISO:
1IDIBI:
1NIF:
1NOMBRE:
1TIPO_VIA_FISCAL:
1NOMBRE_VIA_FISCAL:
1PRIMER_NUMERO_FISCAL:
1ESCALERA_FISCAL:
1PLANTA_FISCAL:
1PUERTA_FISCAL:
1COD_POSTAL_FISCAL:
1MUNICIPIO_FISCAL:
1PROVINCIA:
1PAIS:
1TIPO_VIA:
1NOMBRE_VIA:
1PRIMER_NUMERO:
1BLOQUE:
1ESCALERA:
1PLANTA:
1PUERTA:
1HIS_CARGOREAL_IBI:
1ID:
1=:
1IBI:
1QUIEN_MODIFICA:
1USER:
1DOMICILIADO:
1DECODE:
1S:
1N:
1MUNICIPIO:
1REF_CATASTRAL:
1NUMERO_SECUENCIAL:
1PRIMER_CARACTER_CONTROL:
1SEGUN_CARACTER_CONTROL:
1REFERENCIAS_BANCOS:
1||:
1RECIBOS_IBI_MODIFI:
0

0
0
19e
2
0 9a 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d b4 55
6a a3 a0 51 a5 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 51 a5 1c 81 b0 a3 a0
51 a5 1c 81 b0 a3 a0 51
a5 1c 81 b0 a3 a0 51 a5
1c 81 b0 a3 a0 51 a5 1c
81 b0 a3 a0 51 a5 1c 81
b0 a3 a0 51 a5 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 51 a5 1c 81 b0 a3 a0
51 a5 1c 81 b0 a3 a0 51
a5 1c 81 b0 a3 a0 51 a5
1c 81 b0 a3 a0 51 a5 1c
81 b0 a3 a0 51 a5 1c 81
b0 a3 a0 51 a5 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 51 a5 1c 81 b0 a3 a0
1c 81 b0 a3 a0 51 a5 1c
81 b0 a3 a0 51 a5 1c 81
b0 a3 a0 51 a5 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 51 a5 1c 81 b0 a3 a0
1c 81 b0 :14 a0 ac :15 a0 b2 ee
:2 a0 7e b4 2e ac e5 d0 b2
e9 :3 a0 e7 :2 a0 e7 :2 a0 e7 :2 a0
e7 :2 a0 e7 :2 a0 e7 :2 a0 e7 :2 a0
e7 :2 a0 e7 :2 a0 e7 :2 a0 e7 :2 a0
e7 :2 a0 e7 :2 a0 e7 :2 a0 e7 :2 a0
e7 :2 a0 e7 :2 a0 e7 :2 a0 e7 :2 a0
e7 :3 a0 :2 6e a0 a5 b e7 :2 a0
7e b4 2e ef f9 e9 :3 a0 7e
b4 2e cd e9 :5 a0 ac :6 a0 b2
ee :2 a0 7e b4 2e ac e5 d0
b2 e9 :3 a0 e7 :2 a0 7e b4 2e
:2 a0 :2 7e a0 b4 2e 7e a0 b4
2e 7e a0 b4 2e b4 2e a
10 ef f9 e9 a0 7e 6e b4
2e 5a :4 a0 a5 57 b7 19 3c
b7 a4 b1 11 68 4f 1d 17
b5 
19e
2
0 3 1f 1b 1a 27 34 30
17 3c 45 41 2f 4d 2c 52
56 73 5e 62 65 66 6e 5d
90 7e 5a 82 83 8b 7d ad
9b 7a 9f a0 a8 9a ca b8
97 bc bd c5 b7 e7 d5 b4
d9 da e2 d4 104 f2 d1 f6
f7 ff f1 121 10f ee 113 114
11c 10e 13e 12c 10b 130 131 139
12b 15b 149 128 14d 14e 156 148
178 166 145 16a 16b 173 165 195
183 162 187 188 190 182 1b2 1a0
17f 1a4 1a5 1ad 19f 1cf 1bd 19c
1c1 1c2 1ca 1bc 1ec 1da 1b9 1de
1df 1e7 1d9 209 1f7 1d6 1fb 1fc
204 1f6 226 214 1f3 218 219 221
213 243 231 210 235 236 23e 230
260 24e 22d 252 253 25b 24d 27d
26b 24a 26f 270 278 26a 299 288
28c 294 267 2b5 2a0 2a4 2a7 2a8
2b0 287 2d2 2c0 284 2c4 2c5 2cd
2bf 2ef 2dd 2bc 2e1 2e2 2ea 2dc
30c 2fa 2d9 2fe 2ff 307 2f9 329
317 2f6 31b 31c 324 316 345 334
338 340 313 330 34c 350 354 358
35c 360 364 368 36c 370 374 378
37c 380 384 388 38c 390 394 398
399 39d 3a1 3a5 3a9 3ad 3b1 3b5
3b9 3bd 3c1 3c5 3c9 3cd 3d1 3d5
3d9 3dd 3e1 3e5 3e9 3ed 3ee 3f5
3f9 3fd 400 401 406 407 40d 411
412 417 41b 41f 423 425 429 42d
42f 433 437 439 43d 441 443 447
44b 44d 451 455 457 45b 45f 461
465 469 46b 46f 473 475 479 47d
47f 483 487 489 48d 491 493 497
49b 49d 4a1 4a5 4a7 4ab 4af 4b1
4b5 4b9 4bb 4bf 4c3 4c5 4c9 4cd
4cf 4d3 4d7 4d9 4dd 4e1 4e3 4e7
4eb 4ef 4f4 4f9 4fd 4fe 500 502
506 50a 50d 50e 513 519 51a 51f
523 527 52b 52e 52f 534 539 53e
542 546 54a 54e 552 553 557 55b
55f 563 567 56b 56c 573 577 57b
57e 57f 584 585 58b 58f 590 595
599 59d 5a1 5a3 5a7 5ab 5ae 5af
5b4 5b8 5bc 5bf 5c2 5c6 5c7 5cc
5cf 5d3 5d4 5d9 5dc 5e0 5e1 5e6
5e7 1 5ec 5f1 5f7 5f8 5fd 601
604 609 60a 60f 612 616 61a 61e
622 623 628 62a 62e 631 633 637
639 645 649 64b 64c 655 
19e
2
0 b 5 14 :3 5 15 :3 5 15
:2 5 1f :2 1 2 d 12 11 :2 d
:2 2 10 15 14 :2 10 :2 2 15 1a
19 :2 15 :2 2 16 1b 1a :2 16 :2 2
18 1d 1c :2 18 :2 2 15 1a 19
:2 15 :2 2 14 19 18 :2 14 :2 2 14
19 18 :2 14 :2 2 16 1b 1a :2 16
:2 2 16 1b 1a :2 16 :2 2 11 16
15 :2 11 :2 2 e 13 12 :2 e :2 2
10 15 14 :2 10 :2 2 12 17 16
:2 12 :2 2 14 19 18 :2 14 :2 2 f
14 13 :2 f 2 4 12 17 16
:2 12 4 2 f 14 13 :2 f :2 2
f 14 13 :2 f :2 2 :3 e :2 2 15
1b 1a :2 15 :2 2 1c 22 21 :2 1c
:2 2 1c 22 21 :2 1c :2 2 1c 22
21 :2 1c :2 2 1c 22 21 :2 1c 2
4 :3 10 4 9 f 13 1a 2a
3c 51 61 6f 5 17 28 32
37 40 4b 59 60 69 70 9
7 e 13 1b 2c 3f 55 66
75 5 18 2a 35 3b 45 51
60 68 72 7a 7 2 7 8
b :3 a :5 2 9 11 15 11 13
1a :2 13 23 :2 13 25 :2 13 28 :2 13
23 :2 13 21 :2 13 21 :2 13 25 :2 13
24 :2 13 1d 13 9 e :2 9 12
:2 9 14 :2 9 17 :2 9 10 :2 9 12
9 a 11 a 9 10 9 13
22 13 9 15 1c 28 2d 32
:2 15 9 8 b :3 a :3 2 e 26
29 :3 28 :2 2 9 13 21 33 4b
9 7 12 21 34 4d 7 2
7 11 14 :3 13 :5 2 b 22 26
22 a 14 :3 13 23 31 30 3f
41 :2 31 53 55 :2 31 6d 6f :2 31
:2 30 :2 a :3 4 6 10 11 :2 10 :2 5
18 1f 2a :2 5 16 :2 2 :9 1 
19e
4
0 1 :4 2 :4 3
:4 4 :3 1 :7 6 :7 7
:7 8 :7 9 :7 a :7 b
:7 c :7 d :7 e :7 f
:7 10 :7 11 :7 12 :7 13
:7 14 :7 15 :7 16 :7 17
:7 18 :5 1a :7 1b :7 1c
:7 1d :7 1e :7 1f :5 20
:9 26 :b 27 26 :9 28
:b 29 :3 2a :5 2b 2a
:4 26 :4 30 :3 31 :3 32
:3 33 :3 34 :3 35 :3 36
:3 37 :3 38 :3 39 :3 3a
:3 3b :3 3c :3 3d :3 3e
:3 3f :3 40 :3 41 :3 42
:3 43 :9 44 :5 45 :3 30
:8 49 :6 4c :5 4d :9 4e
:4 4c :4 52 :18 53 :3 52
:6 56 :6 57 :3 56 :2 22
:7 1 
657
4
:3 0 1 :a 0 199
1 :7 0 5 2c
0 :2 3 :3 0 2
:7 0 4 3 :3 0
9 :2 0 7 5
:3 0 4 :7 0 8
7 :3 0 5 :3 0
6 :7 0 c b
:3 0 e :2 0 199
1 f :2 0 a
:2 0 f 5 :3 0
8 :2 0 d 12
14 :6 0 17 15
0 197 0 7
:6 0 c :2 0 13
5 :3 0 11 19
1b :6 0 1e 1c
0 197 0 9
:6 0 e :2 0 17
5 :3 0 15 20
22 :6 0 25 23
0 197 0 b
:6 0 10 :2 0 1b
5 :3 0 19 27
29 :6 0 2c 2a
0 197 0 d
:6 0 12 :2 0 1f
5 :3 0 1d 2e
30 :6 0 33 31
0 197 0 f
:6 0 14 :2 0 23
5 :3 0 21 35
37 :6 0 3a 38
0 197 0 11
:6 0 14 :2 0 27
5 :3 0 25 3c
3e :6 0 41 3f
0 197 0 13
:6 0 c :2 0 2b
5 :3 0 29 43
45 :6 0 48 46
0 197 0 15
:6 0 e :2 0 2f
5 :3 0 2d 4a
4c :6 0 4f 4d
0 197 0 16
:6 0 e :2 0 33
5 :3 0 31 51
53 :6 0 56 54
0 197 0 17
:6 0 e :2 0 37
5 :3 0 35 58
5a :6 0 5d 5b
0 197 0 18
:6 0 c :2 0 3b
5 :3 0 39 5f
61 :6 0 64 62
0 197 0 19
:6 0 e :2 0 3f
5 :3 0 3d 66
68 :6 0 6b 69
0 197 0 1a
:6 0 10 :2 0 43
5 :3 0 41 6d
6f :6 0 72 70
0 197 0 1b
:6 0 10 :2 0 47
5 :3 0 45 74
76 :6 0 79 77
0 197 0 1c
:6 0 12 :2 0 4b
5 :3 0 49 7b
7d :6 0 80 7e
0 197 0 1d
:6 0 14 :2 0 4f
5 :3 0 4d 82
84 :6 0 87 85
0 197 0 1e
:6 0 14 :2 0 53
5 :3 0 51 89
8b :6 0 8e 8c
0 197 0 1f
:6 0 59 284 0
57 5 :3 0 55
90 92 :6 0 95
93 0 197 0
20 :6 0 24 :2 0
5d 3 :3 0 97
:7 0 9a 98 0
197 0 21 :6 0
5 :3 0 14 :2 0
5b 9c 9e :6 0
a1 9f 0 197
0 22 :6 0 10
:2 0 61 5 :3 0
5f a3 a5 :6 0
a8 a6 0 197
0 23 :6 0 27
:2 0 65 5 :3 0
63 aa ac :6 0
af ad 0 197
0 25 :6 0 27
:2 0 69 5 :3 0
67 b1 b3 :6 0
b6 b4 0 197
0 26 :6 0 6f
330 0 6d 5
:3 0 6b b8 ba
:6 0 bd bb 0
197 0 28 :6 0
2a :3 0 3 :3 0
bf :7 0 c2 c0
0 197 0 29
:6 0 2b :3 0 2c
:3 0 2d :3 0 2e
:3 0 2f :3 0 30
:3 0 31 :3 0 32
:3 0 33 :3 0 34
:3 0 35 :3 0 36
:3 0 37 :3 0 38
:3 0 39 :3 0 3a
:3 0 3b :3 0 3c
:3 0 3d :3 0 71
21 :3 0 7 :3 0
9 :3 0 b :3 0
d :3 0 f :3 0
11 :3 0 13 :3 0
15 :3 0 16 :3 0
17 :3 0 18 :3 0
19 :3 0 1a :3 0
1b :3 0 1c :3 0
1d :3 0 1e :3 0
1f :3 0 20 :3 0
3e :3 0 86 ed
f3 0 f4 :3 0
3f :3 0 2 :3 0
40 :2 0 8a f1
f2 :4 0 f6 f7
:5 0 d7 ee 0
8d 0 f5 :2 0
195 41 :3 0 2b
:3 0 7 :3 0 fa
fb 2c :3 0 9
:3 0 fd fe 2d
:3 0 b :3 0 100
101 2e :3 0 d
:3 0 103 104 2f
:3 0 f :3 0 106
107 30 :3 0 11
:3 0 109 10a 31
:3 0 13 :3 0 10c
10d 32 :3 0 15
:3 0 10f 110 33
:3 0 16 :3 0 112
113 34 :3 0 17
:3 0 115 116 35
:3 0 18 :3 0 118
119 36 :3 0 19
:3 0 11b 11c 37
:3 0 1a :3 0 11e
11f 38 :3 0 1b
:3 0 121 122 39
:3 0 1c :3 0 124
125 3a :3 0 1d
:3 0 127 128 3b
:3 0 1e :3 0 12a
12b 3c :3 0 1f
:3 0 12d 12e 3d
:3 0 20 :3 0 130
131 42 :3 0 43
:3 0 133 134 44
:3 0 45 :3 0 4
:3 0 46 :4 0 47
:4 0 44 :3 0 a2
137 13c 136 13d
3f :3 0 21 :3 0
40 :2 0 a9 141
142 :3 0 f9 145
143 0 146 0
ac 0 144 :2 0
195 3e :3 0 3f
:3 0 2 :3 0 40
:2 0 c4 14a 14b
:3 0 147 14c 0
14e :2 0 14d :2 0
195 48 :3 0 49
:3 0 4a :3 0 4b
:3 0 4c :3 0 c7
22 :3 0 23 :3 0
25 :3 0 26 :3 0
28 :3 0 41 :3 0
cd 15b 161 0
162 :3 0 3f :3 0
21 :3 0 40 :2 0
d1 15f 160 :4 0
164 165 :5 0 154
15c 0 d4 0
163 :2 0 195 4d
:3 0 2b :3 0 7
:3 0 168 169 48
:3 0 22 :3 0 40
:2 0 dc 16d 16e
:3 0 49 :3 0 23
:3 0 40 :2 0 4e
:2 0 25 :3 0 df
173 175 :3 0 4e
:2 0 26 :3 0 e2
177 179 :3 0 4e
:2 0 28 :3 0 e5
17b 17d :3 0 ea
172 17f :3 0 16f
181 180 :2 0 167
184 182 0 185
0 ed 0 183
:2 0 195 6 :3 0
40 :2 0 46 :4 0
f1 187 189 :3 0
18a :2 0 4f :3 0
21 :3 0 4 :3 0
29 :3 0 f4 18c
190 :2 0 192 f8
193 18b 192 0
194 fa 0 195
fc 198 :3 0 198
103 198 197 195
196 :6 0 199 :2 0
1 f 198 19c
:3 0 19b 199 19d
:8 0 
11e
4
:3 0 1 2 1
6 1 a 3
5 9 d 1
13 1 11 1
1a 1 18 1
21 1 1f 1
28 1 26 1
2f 1 2d 1
36 1 34 1
3d 1 3b 1
44 1 42 1
4b 1 49 1
52 1 50 1
59 1 57 1
60 1 5e 1
67 1 65 1
6e 1 6c 1
75 1 73 1
7c 1 7a 1
83 1 81 1
8a 1 88 1
91 1 8f 1
96 1 9d 1
9b 1 a4 1
a2 1 ab 1
a9 1 b2 1
b0 1 b9 1
b7 1 be 14
c3 c4 c5 c6
c7 c8 c9 ca
cb cc cd ce
cf d0 d1 d2
d3 d4 d5 d6
1 ec 1 f0
2 ef f0 14
d8 d9 da db
dc dd de df
e0 e1 e2 e3
e4 e5 e6 e7
e8 e9 ea eb
4 138 139 13a
13b 1 140 2
13f 140 15 fc
ff 102 105 108
10b 10e 111 114
117 11a 11d 120
123 126 129 12c
12f 132 135 13e
1 149 2 148
149 5 14f 150
151 152 153 1
15a 1 15e 2
15d 15e 5 155
156 157 158 159
1 16c 2 16b
16c 2 171 174
2 176 178 2
17a 17c 1 17e
2 170 17e 1
16a 1 188 2
186 188 3 18d
18e 18f 1 191
1 193 6 f8
146 14e 166 185
194 1a 16 1d
24 2b 32 39
40 47 4e 55
5c 63 6a 71
78 7f 86 8d
94 99 a0 a7
ae b5 bc c1

1
4
0 
19c
0
1
14
1
1e
0 0 0 0 0 0 0 0
0 0 0 0 0 0 0 0
0 0 0 0 
18 1 0
a 1 0
73 1 0
34 1 0
2d 1 0
96 1 0
1f 1 0
6c 1 0
42 1 0
11 1 0
b7 1 0
49 1 0
a9 1 0
7a 1 0
81 1 0
3b 1 0
8f 1 0
5e 1 0
a2 1 0
2 1 0
88 1 0
65 1 0
9b 1 0
57 1 0
6 1 0
be 1 0
b0 1 0
50 1 0
26 1 0
1 0 1
0

/
CREATE OR REPLACE PROCEDURE MOD_GRAVAMEN wrapped 
0
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
3
7
9000000
1
4
0 
1a
2 :e:
1MOD_GRAVAMEN:
1XMODULO:
1CHAR:
1XMUNICIPIO:
1XYEAR:
1XGRAVAMEN:
1FLOAT:
1XMAXCUOTA:
1XINCREMENTO:
1XMAXVCATASTRAL:
1XCLAVE:
1=:
1IBI:
1GRAVAMEN_IBI_RUS:
1GRAVAMEN:
1MAX_CUOTA:
1INCREMENTO_VC:
1MAX_VCATASTRAL:
1DECODE:
10:
1USUARIO:
1USER:
1MUNICIPIO:
1YEAR:
1MODULO:
1CLAVE:
0

0
0
8f
2
0 9a 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d b4 55 6a a0 7e 6e
b4 2e 5a :3 a0 e7 :2 a0 e7 :2 a0
e7 :3 a0 4d 51 a0 a5 b e7
:2 a0 e7 :2 a0 7e b4 2e :2 a0 7e
b4 2e a 10 :2 a0 7e b4 2e
a 10 :2 a0 7e b4 2e a 10
ef f9 e9 b7 :3 a0 e7 :2 a0 e7
:2 a0 e7 :2 a0 e7 :2 a0 7e b4 2e
:2 a0 7e b4 2e a 10 :2 a0 7e
b4 2e a 10 ef f9 e9 b7
:2 19 3c b7 a4 b1 11 68 4f
1d 17 b5 
8f
2
0 3 1f 1b 1a 27 34 30
17 3c 45 41 2f 4d 5a 56
2c 62 6b 67 55 73 80 7c
52 88 91 8d 7b 99 a6 a2
78 ae a1 b3 b7 bb 9e bf
c4 c5 ca cd d1 d5 d9 db
df e3 e5 e9 ed ef f3 f7
fb fc ff 103 104 106 108 10c
110 112 116 11a 11d 11e 123 127
12b 12e 12f 1 134 139 13d 141
144 145 1 14a 14f 153 157 15a
15b 1 160 165 16b 16c 171 173
177 17b 17f 181 185 189 18b 18f
193 195 199 19d 19f 1a3 1a7 1aa
1ab 1b0 1b4 1b8 1bb 1bc 1 1c1
1c6 1ca 1ce 1d1 1d2 1 1d7 1dc
1e2 1e3 1e8 1ea 1ee 1f2 1f5 1f7
1fb 1fd 209 20d 20f 210 219 
8f
2
0 b 8 16 :3 8 18 :3 8 14
:3 8 17 :3 8 16 :3 8 19 :3 8 1a
:3 8 14 :2 8 18 :2 1 8 f 10
:2 f 7 :2 d 16 :2 d 17 :2 d 1b
:2 d 1c 23 2a 2f 31 :2 1c :2 d
15 d c 16 :3 15 25 2a :3 29
:2 c 34 3b :3 3a :2 c 47 4d :3 4c
:2 c :3 6 17 :2 d 16 :2 d 17 :2 d
1b :2 d 15 d c 16 :3 15 25
2a :3 29 :2 c 34 3b :3 3a :2 c :3 6
:4 4 :9 1 
8f
4
0 1 :4 2 :4 3
:4 4 :4 5 :4 6 :4 7
:4 8 :4 9 :3 1 :6 e
10 :3 11 :3 12 :3 13
:9 14 :3 15 :1a 16 :3 10
e 19 :3 1a :3 1b
:3 1c :3 1d :13 1e :3 19
17 :3 e :2 d :7 1

21b
4
:3 0 1 :a 0 8a
1 :7 0 5 2c
0 :2 3 :3 0 2
:7 0 4 3 :3 0
9 52 0 7
3 :3 0 4 :7 0
8 7 :3 0 3
:3 0 5 :7 0 c
b :3 0 d 78
0 b 7 :3 0
6 :7 0 10 f
:3 0 7 :3 0 8
:7 0 14 13 :3 0
11 9e 0 f
7 :3 0 9 :7 0
18 17 :3 0 7
:3 0 a :7 0 1c
1b :3 0 c :2 0
13 3 :3 0 b
:7 0 20 1f :3 0
22 :2 0 8a 1
23 :2 0 2 :3 0
d :4 0 1e 26
28 :3 0 29 :2 0
e :3 0 f :3 0
6 :3 0 2c 2d
10 :3 0 8 :3 0
2f 30 11 :3 0
9 :3 0 32 33
12 :3 0 13 :3 0
b :4 0 14 :2 0
a :3 0 21 36
3b 35 3c 15
:3 0 16 :3 0 3e
3f 17 :3 0 4
:3 0 c :2 0 28
43 44 :3 0 18
:3 0 5 :3 0 c
:2 0 2d 48 49
:3 0 45 4b 4a
:2 0 19 :3 0 2
:3 0 c :2 0 32
4f 50 :3 0 4c
52 51 :2 0 1a
:3 0 b :3 0 c
:2 0 37 56 57
:3 0 53 59 58
:2 0 2b 5c 5a
0 5d 0 3a
0 5b :2 0 5e
40 83 e :3 0
f :3 0 6 :3 0
60 61 10 :3 0
8 :3 0 63 64
11 :3 0 9 :3 0
66 67 15 :3 0
16 :3 0 69 6a
17 :3 0 4 :3 0
c :2 0 44 6e
6f :3 0 18 :3 0
5 :3 0 c :2 0
49 73 74 :3 0
70 76 75 :2 0
19 :3 0 2 :3 0
c :2 0 4e 7a
7b :3 0 77 7d
7c :2 0 5f 80
7e 0 81 0
51 0 7f :2 0
82 56 84 2a
5e 0 85 0
82 0 85 58
0 86 5b 89
:3 0 89 0 89
88 86 87 :6 0
8a :2 0 1 23
89 8d :3 0 8c
8a 8e :8 0 
5d
4
:3 0 1 2 1
6 1 a 1
e 1 12 1
16 1 1a 1
1e 8 5 9
d 11 15 19
1d 21 1 27
2 25 27 4
37 38 39 3a
1 42 2 41
42 1 47 2
46 47 1 4e
2 4d 4e 1
55 2 54 55
5 2e 31 34
3d 40 1 5d
1 6d 2 6c
6d 1 72 2
71 72 1 79
2 78 79 4
62 65 68 6b
1 81 2 83
84 1 85 
1
4
0 
8d
0
1
14
1
9
0 0 0 0 0 0 0 0
0 0 0 0 0 0 0 0
0 0 0 0 
a 1 0
1a 1 0
16 1 0
12 1 0
e 1 0
1 0 1
2 1 0
6 1 0
1e 1 0
0

/
CREATE OR REPLACE PROCEDURE Calculo_Cuota_Liqui_Agua wrapped 
0
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
3
7
9000000
1
4
0 
7c
2 :e:
1CALCULO_CUOTA_LIQUI_AGUA:
1XMUNICIPIO:
1CHAR:
1XCONCEPTO:
1XABONADO:
1INTEGER:
1XNIF:
1XDOM_SUMINISTRO:
1VARCHAR2:
1XEXPEDIENTE:
1XANTERIOR:
1XACTUAL:
1XDESDE:
1DATE:
1XHASTA:
1XIDLIQUI:
1OUT:
1XTIPO_IVA:
1FLOAT:
1XTIENEIVA:
11:
1XBASE:
1XIVA:
1XIMPORTE:
1XBLOQUE1:
1XBLOQUE2:
1XBLOQUE3:
1XBLOQUE4:
1XPRECIO1:
1XPRECIO2:
1XPRECIO3:
1XPRECIO4:
1XFIJO1:
1XFIJO2:
1XFIJO3:
1XFIJO4:
1XDESCRIPTARIFA:
135:
1XCONSUMO:
1XRANGO:
1XRECIBO:
17:
1XDIAS:
1XDIASPERIODO:
1XPERCOBRO:
1XMOTIVO:
11024:
1:
1XSUMA:
10:
1XSALTO:
12:
1XFINPEVOL:
1XDIASVENCI:
1CURSOR:
1C_SERVICIOS:
1SERVICIOS:
1ABONADO:
1=:
1AGUA_TIPO_PERIODO:
1DIAS_VENCIMIENTO:
1DATOSPER:
1MUNICIPIO:
1MIN:
1SALTO:
1B:
160:
1ELSIF:
1T:
190:
1C:
1120:
1S:
1180:
1365:
1<:
1AVERIGUA_PESO:
1-:
1Liquidación por baja en el suministro, fechas para el cálculo de la liquidaci+
1ón:: :
1||:
1 - :
1Lec. Anterior:: :
1 Lec. Actual:: :
1 Consumo:: :
1TRUNC:
1dd:
1V_TSERVICIOS:
1LOOP:
1IVA:
1TIPO_IVA:
1DESCRIPCION:
1TIPO_TARIFA:
1TIPO:
1BLOQUE1:
1BLOQUE2:
1BLOQUE3:
1BLOQUE4:
1PRECIO1:
1PRECIO2:
1PRECIO3:
1PRECIO4:
1FIJO1:
1FIJO2:
1FIJO3:
1FIJO4:
1TARIFAS_AGUA:
1TARIFA:
1ROUND:
1*:
1/:
1IMPORTES_CALCULO_AGUA:
1 :
1:: :
1>:
1100:
1 IVA:: :
1+:
1SYSDATE:
1TO_CHAR:
1d:
16:
1ADD_LIQUI:
1YYYY:
100:
0

0
0
2cd
2
0 9a 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d 96 :2 a0 b0 54 b4 55
6a a3 a0 1c 81 b0 a3 a0
51 a5 1c 81 b0 a3 a0 1c
81 b0 a3 a0 1c 81 b0 a3
a0 1c 81 b0 a3 a0 1c 81
b0 a3 a0 1c 81 b0 a3 a0
1c 81 b0 a3 a0 1c 81 b0
a3 a0 1c 81 b0 a3 a0 1c
81 b0 a3 a0 1c 81 b0 a3
a0 1c 81 b0 a3 a0 1c 81
b0 a3 a0 1c 81 b0 a3 a0
1c 81 b0 a3 a0 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 1c 81 b0 a3 a0 1c 81
b0 a3 a0 51 a5 1c 81 b0
a3 a0 1c 81 b0 a3 a0 1c
81 b0 a3 a0 51 a5 1c 81
b0 a3 a0 51 a5 1c 6e 81
b0 a3 a0 1c 51 81 b0 a3
a0 51 a5 1c 81 b0 a3 a0
1c 81 b0 a3 a0 1c 81 b0
a0 f4 b4 bf c8 ac a0 b2
ee :2 a0 7e b4 2e ac d0 e5
e9 bd b7 11 a4 b1 :2 a0 ac
:3 a0 b2 ee :2 a0 7e b4 2e ac
e5 d0 b2 e9 a0 9f a0 d2
ac :2 a0 b2 ee ac e5 d0 b2
e9 a0 7e 6e b4 2e a0 51
d a0 b7 a0 7e 6e b4 2e
a0 51 d a0 b7 19 a0 7e
6e b4 2e a0 51 d a0 b7
19 a0 7e 6e b4 2e a0 51
d b7 19 a0 51 d b7 :2 19
3c :2 a0 7e b4 2e 5a :5 a0 a5
57 b7 :2 a0 7e a0 b4 2e d
b7 :2 19 3c a0 6e 7e a0 b4
2e 7e 6e b4 2e 7e a0 b4
2e 7e a0 b4 2e d :2 a0 7e
6e b4 2e 7e a0 b4 2e 7e
6e b4 2e 7e a0 b4 2e 7e
6e b4 2e 7e a0 b4 2e 7e
a0 b4 2e d :3 a0 6e a5 b
7e :2 a0 6e a5 b b4 2e d
91 :2 a0 37 :3 a0 ac :4 a0 b2 ee
:2 a0 7e b4 2e :2 a0 7e a0 6b
b4 2e a 10 ac e5 d0 b2
e9 :c a0 ac :d a0 b2 ee :2 a0 7e
b4 2e :2 a0 7e a0 6b b4 2e
a 10 ac e5 d0 b2 e9 a0
51 d a0 7e 51 b4 2e 5a
:3 a0 7e a0 b4 2e 5a 7e a0
b4 2e 51 a5 b d b7 :11 a0
a5 57 b7 :2 19 3c :2 a0 7e 6e
b4 2e 7e a0 b4 2e 7e 6e
b4 2e 7e a0 b4 2e d a0
7e 6e b4 2e a0 7e 51 b4
2e a 10 5a :2 a0 7e a0 b4
2e 7e 51 b4 2e d :2 a0 7e
6e b4 2e 7e :2 a0 51 a5 b
b4 2e d b7 19 3c :2 a0 7e
a0 b4 2e d :3 a0 7e a0 b4
2e 7e a0 b4 2e 51 a5 b
d b7 a0 47 a0 7e 51 b4
2e :2 a0 7e a0 b4 2e d :2 a0
6e a5 b 7e 51 b4 2e :2 a0
7e 51 b4 2e d a0 b7 :2 a0
6e a5 b 7e 51 b4 2e :2 a0
7e 51 b4 2e d b7 :2 19 3c
b7 a0 4d d b7 :2 19 3c :5 a0
6e a5 b 6e :2 a0 6e a5 b
a0 4d :5 a0 :4 6e a0 4d 51 :2 a0
a5 57 b7 a4 b1 11 68 4f
1d 17 b5 
2cd
2
0 3 1f 1b 1a 27 34 30
17 3c 45 41 2f 4d 5a 56
2c 62 6b 67 55 73 80 7c
52 88 91 8d 7b 99 a6 a2
78 ae b7 b3 a1 bf cc c8
9e d4 e1 d9 dd c7 e8 c4
ed f1 10a f9 fd 105 f8 127
115 f5 119 11a 122 114 143 132
136 13e 111 15b 14a 14e 156 131
177 166 16a 172 12e 18f 17e 182
18a 165 1ab 19a 19e 1a6 162 1c3
1b2 1b6 1be 199 1df 1ce 1d2 1da
196 1f7 1e6 1ea 1f2 1cd 213 202
206 20e 1ca 22b 21a 21e 226 201
247 236 23a 242 1fe 25f 24e 252
25a 235 27b 26a 26e 276 232 293
282 286 28e 269 2af 29e 2a2 2aa
266 2cb 2b6 2ba 2bd 2be 2c6 29d
2e7 2d6 2da 2e2 29a 2ff 2ee 2f2
2fa 2d5 31c 30a 2d2 30e 30f 317
309 338 327 32b 333 306 350 33f
343 34b 326 36d 35b 323 35f 360
368 35a 38f 378 357 37c 37d 385
38a 377 3ab 39a 39e 374 3a6 399
3c8 3b6 396 3ba 3bb 3c3 3b5 3e4
3d3 3d7 3df 3b2 3fc 3eb 3ef 3f7
3d2 403 407 3cf 418 41b 41f 420
424 425 42c 430 434 437 438 43d
43e 442 448 44d 452 454 460 464
466 46a 46e 46f 473 477 47b 47c
483 487 48b 48e 48f 494 495 49b
49f 4a0 4a5 4a9 4ac 4b0 4b4 4b5
4b9 4bd 4be 4c5 4c6 4cc 4d0 4d1
4d6 4da 4dd 4e2 4e3 4e8 4ec 4ef
4f3 4f7 4f9 4fd 500 505 506 50b
50f 512 516 51a 51c 520 524 527
52c 52d 532 536 539 53d 541 543
547 54b 54e 553 554 559 55d 560
564 566 56a 56e 571 575 577 57b
57f 582 586 58a 58d 58e 593 596
59a 59e 5a2 5a6 5aa 5ab 5b0 5b2
5b6 5ba 5bd 5c1 5c2 5c7 5cb 5cd
5d1 5d5 5d8 5dc 5e1 5e4 5e8 5e9
5ee 5f1 5f6 5f7 5fc 5ff 603 604
609 60c 610 611 616 61a 61e 622
625 62a 62b 630 633 637 638 63d
640 645 646 64b 64e 652 653 658
65b 660 661 666 669 66d 66e 673
676 67a 67b 680 684 688 68c 690
695 696 698 69b 69f 6a3 6a8 6a9
6ab 6ac 6b1 6b5 6b9 6bd 6c1 6c3
6c7 6cb 6cf 6d0 6d4 6d8 6dc 6e0
6e1 6e8 6ec 6f0 6f3 6f4 6f9 6fd
701 704 708 70b 70c 1 711 716
717 71d 721 722 727 72b 72f 733
737 73b 73f 743 747 74b 74f 753
757 758 75c 760 764 768 76c 770
774 778 77c 780 784 788 78c 78d
794 798 79c 79f 7a0 7a5 7a9 7ad
7b0 7b4 7b7 7b8 1 7bd 7c2 7c3
7c9 7cd 7ce 7d3 7d7 7da 7de 7e2
7e5 7e8 7e9 7ee 7f1 7f5 7f9 7fd
800 804 805 80a 80d 810 814 815
81a 81d 81e 820 824 826 82a 82e
832 836 83a 83e 842 846 84a 84e
852 856 85a 85e 862 866 86a 86b
870 872 876 87a 87d 881 885 888
88d 88e 893 896 89a 89b 8a0 8a3
8a8 8a9 8ae 8b1 8b5 8b6 8bb 8bf
8c3 8c6 8cb 8cc 8d1 8d5 8d8 8db
8dc 1 8e1 8e6 8e9 8ed 8f1 8f4
8f8 8f9 8fe 901 904 905 90a 90e
912 916 919 91e 91f 924 927 92b
92f 932 933 935 936 93b 93f 941
945 948 94c 950 953 957 958 95d
961 965 969 96d 970 974 975 97a
97d 981 982 987 98a 98b 98d 991
993 997 99e 9a2 9a5 9a8 9a9 9ae
9b2 9b6 9b9 9bd 9be 9c3 9c7 9cb
9cf 9d4 9d5 9d7 9da 9dd 9de 9e3
9e7 9eb 9ee 9f1 9f2 9f7 9fb 9ff
a01 a05 a09 a0e a0f a11 a14 a17
a18 a1d a21 a25 a28 a2b a2c a31
a35 a37 a3b a3f a42 a44 a48 a49
a4d a4f a53 a57 a5a a5e a62 a66
a6a a6e a73 a74 a76 a7b a7f a83
a88 a89 a8b a8f a90 a94 a98 a9c
aa0 aa4 aa9 aae ab3 ab8 abc abd
ac0 ac4 ac8 ac9 ace ad0 ad4 ad6
ae2 ae6 ae8 ae9 af2 
2cd
2
0 b 3 13 :3 3 12 :3 3 11
:3 3 f :3 3 17 :3 3 14 :3 3 13
:3 3 11 :3 3 10 :3 3 10 :3 3 d
12 :2 3 23 :2 1 2 :3 d :2 2 d
12 11 :2 d :2 2 :3 a :2 2 :3 a :2 2
:3 b :2 2 :3 c :2 2 :3 c :2 2 :3 b :2 2
:3 c :2 2 :3 b :2 2 :3 b :2 2 :3 b :2 2
:3 b :2 2 :3 a :2 2 :3 a :2 2 :3 a :2 2
:3 a :2 2 11 1a 19 :2 11 :2 2 :3 d
:2 2 :3 c :2 2 d 12 11 :2 d :2 2
:3 a :2 2 :3 f :2 2 d 12 11 :2 d
:2 2 c 15 14 c 23 c :2 2
:2 a 18 a :2 2 c 11 10 :2 c
:2 2 :3 d :2 2 :3 11 :2 2 9 0 :2 2
1f 26 21 26 36 3e :3 3d 21
:3 18 :5 2 9 1b 9 31 3b 4b
46 4b 5a 64 :3 63 46 :4 2 :2 9
d :2 9 19 25 20 25 20 :4 2
5 e f :2 e 3 11 3 2
13 8 11 12 :2 11 3 11 3
2 16 13 8 11 12 :2 11 3
11 3 2 16 13 8 11 12
:2 11 3 11 3 16 13 3 11
3 :4 2 6 10 :3 e 5 3 11
19 23 2c :2 3 1b 3 f 17
19 :2 f 3 :5 2 b 5e 61 :2 b
68 6a :2 b 6f 72 :2 b 79 7c
:2 b :2 2 b 13 16 :2 b 27 2a
:2 b 34 36 :2 b 46 49 :2 b 51
53 :2 b 5f 62 :2 b 6b 6e :2 b
:2 2 a 10 17 :2 a 1d 1f 25
2c :2 1f :2 a 2 6 16 22 2
a e 17 a 28 32 3c 8
3 8 9 13 :3 12 22 27 26
:2 34 :2 26 :2 9 :5 3 a 12 1a 22
2a 32 3a 42 5 b 11 17
a 8 11 1a 23 2c 35 3e
47 5 c 13 1a 9 3 :2 9
13 :3 12 22 29 28 :2 36 :2 28 :2 9
:6 3 9 3 7 f 10 :2 f 6
4 b 13 1a 1c :2 13 12 23
25 :2 12 34 :2 b 4 13 4 1a
24 2e 38 3f 49 52 8 12
1b 22 2c 35 3c 49 4f :2 4
:5 3 c 14 17 :2 c 1a 1c :2 c
2a 2c :2 c 30 32 :2 c 3 7
10 11 :2 10 19 1f 20 :2 1f :2 7
6 4 a 10 12 :2 a 1b 1c
:2 a :2 4 d 15 18 :2 d 20 22
28 2d :2 22 :2 d 4 23 :3 3 c
14 17 :2 c :2 3 a 10 15 16
:2 10 1b 1c :2 10 21 :2 a 3 22
6 2 5 10 12 :2 10 3 e
15 16 :2 e 3 6 e 18 :2 6
1c 1d :2 1c 4 f 18 19 :2 f
4 3 1f 9 11 1b :2 9 1f
20 :2 1f 4 f 18 19 :2 f 4
22 1f :2 3 14 3 e 3 :5 2
c 17 21 29 31 :2 21 39 3e
46 4e :2 3e 5 b 11 22 2b
5 c 14 17 1a 1d 20 2c
31 33 3b :2 2 :9 1 
2cd
4
0 1 :4 2 :4 3
:4 4 :4 5 :4 6 :4 7
:4 8 :4 9 :4 a :4 b
:5 c :3 1 :5 e :7 f
:5 10 :5 11 :5 12 :5 14
:5 15 :5 16 :5 17 :5 18
:5 19 :5 1a :5 1b :5 1c
:5 1d :5 1e :5 1f :7 21
:5 22 :5 23 :7 24 :5 25
:5 26 :7 27 :8 28 :6 29
:7 2a :5 2b :5 2c :2 2e
0 :14 2e :12 32 :e 34
:5 36 :3 37 38 36
:5 38 :3 39 3a 38
36 :5 3a :3 3b 3c
3a 36 :5 3c :3 3d
3c 36 :3 3f 3e
:3 36 :6 44 :7 45 44
:7 47 46 :3 44 :13 4a
:1f 4b :f 4e :4 52 :7 55
:3 56 :e 57 56 :4 55
:8 59 :4 5a 59 :8 5b
:4 5c :3 5d :e 5e 5d
:4 59 :3 60 :6 63 :10 65
63 :8 69 :9 6a :2 69
67 :3 63 :13 6e :d 71
:b 73 :f 75 :3 71 :7 7a
:f 7c 52 7e 52
:5 80 :7 81 :9 83 :7 84
86 83 :9 86 :7 87
86 :3 83 80 :3 8a
89 :3 80 :e 8e :5 8f
:b 90 :2 8e :2 30 :7 1

af4
4
:3 0 1 :a 0 2c8
1 :7 0 5 2c
0 :2 3 :3 0 2
:7 0 4 3 :3 0
9 52 0 7
3 :3 0 4 :7 0
8 7 :3 0 6
:3 0 5 :7 0 c
b :3 0 d 78
0 b 3 :3 0
7 :7 0 10 f
:3 0 9 :3 0 8
:7 0 14 13 :3 0
11 9e 0 f
3 :3 0 a :7 0
18 17 :3 0 6
:3 0 b :7 0 1c
1b :3 0 15 c4
0 13 6 :3 0
c :7 0 20 1f
:3 0 e :3 0 d
:7 0 24 23 :3 0
19 :2 0 17 e
:3 0 f :7 0 28
27 :3 0 11 :3 0
6 :3 0 10 :6 0
2d 2c :3 0 2f
:2 0 2c8 1 30
:2 0 15 :2 0 25
13 :3 0 33 :7 0
36 34 0 2c6
0 12 :6 0 2b
12e 0 29 3
:3 0 27 38 3a
:6 0 3d 3b 0
2c6 0 14 :6 0
2f 162 0 2d
13 :3 0 3f :7 0
42 40 0 2c6
0 16 :6 0 13
:3 0 44 :7 0 47
45 0 2c6 0
17 :6 0 33 196
0 31 13 :3 0
49 :7 0 4c 4a
0 2c6 0 18
:6 0 6 :3 0 4e
:7 0 51 4f 0
2c6 0 19 :6 0
37 1ca 0 35
6 :3 0 53 :7 0
56 54 0 2c6
0 1a :6 0 6
:3 0 58 :7 0 5b
59 0 2c6 0
1b :6 0 3b 1fe
0 39 6 :3 0
5d :7 0 60 5e
0 2c6 0 1c
:6 0 13 :3 0 62
:7 0 65 63 0
2c6 0 1d :6 0
3f 232 0 3d
13 :3 0 67 :7 0
6a 68 0 2c6
0 1e :6 0 13
:3 0 6c :7 0 6f
6d 0 2c6 0
1f :6 0 43 266
0 41 13 :3 0
71 :7 0 74 72
0 2c6 0 20
:6 0 13 :3 0 76
:7 0 79 77 0
2c6 0 21 :6 0
47 29a 0 45
13 :3 0 7b :7 0
7e 7c 0 2c6
0 22 :6 0 13
:3 0 80 :7 0 83
81 0 2c6 0
23 :6 0 4d 2d2
0 4b 13 :3 0
85 :7 0 88 86
0 2c6 0 24
:6 0 9 :3 0 26
:2 0 49 8a 8c
:6 0 8f 8d 0
2c6 0 25 :6 0
2a :2 0 4f 6
:3 0 91 :7 0 94
92 0 2c6 0
27 :6 0 6 :3 0
96 :7 0 99 97
0 2c6 0 28
:6 0 55 323 0
53 3 :3 0 51
9b 9d :6 0 a0
9e 0 2c6 0
29 :6 0 15 :2 0
57 6 :3 0 a2
:7 0 a5 a3 0
2c6 0 2b :6 0
6 :3 0 a7 :7 0
aa a8 0 2c6
0 2c :6 0 2f
:2 0 5b 3 :3 0
59 ac ae :6 0
b1 af 0 2c6
0 2d :6 0 32
:2 0 5f 9 :3 0
5d b3 b5 :6 0
30 :4 0 b9 b6
b7 2c6 0 2e
:6 0 34 :2 0 61
13 :3 0 bb :7 0
bf bc bd 2c6
0 31 :6 0 67
3cf 0 65 3
:3 0 63 c1 c3
:6 0 c6 c4 0
2c6 0 33 :9 0
69 e :3 0 c8
:7 0 cb c9 0
2c6 0 35 :6 0
6 :3 0 cd :7 0
d0 ce 0 2c6
0 36 :6 0 37
:3 0 38 :a 0 2
e3 :4 0 d2 d5
0 d3 :4 0 39
:3 0 6b d8 de
0 df :3 0 3a
:3 0 5 :3 0 3b
:2 0 6f dc dd
:5 0 d6 d9 0
e0 :6 0 e1 :2 0
e4 d2 d5 e5
0 2c6 72 e5
e7 e4 e6 :6 0
e3 :7 0 e5 3c
:3 0 3d :3 0 74
2d :3 0 36 :3 0
3e :3 0 77 ee
f4 0 f5 :3 0
3f :3 0 2 :3 0
3b :2 0 7b f2
f3 :4 0 f7 f8
:5 0 ea ef 0
7e 0 f6 :2 0
2c4 40 :3 0 40
:2 0 41 :3 0 fb
0 fc 0 81
33 :3 0 41 :3 0
83 101 :2 0 103
:4 0 105 106 :5 0
fe 102 0 85
0 104 :2 0 2c4
2d :3 0 3b :2 0
42 :4 0 89 109
10b :3 0 2c :3 0
43 :2 0 10d 10e
0 111 44 :3 0
8c 136 2d :3 0
3b :2 0 45 :4 0
90 113 115 :3 0
2c :3 0 46 :2 0
117 118 0 11b
44 :3 0 93 11c
116 11b 0 138
2d :3 0 3b :2 0
47 :4 0 97 11e
120 :3 0 2c :3 0
48 :2 0 122 123
0 126 44 :3 0
9a 127 121 126
0 138 2d :3 0
3b :2 0 49 :4 0
9e 129 12b :3 0
2c :3 0 4a :2 0
12d 12e 0 130
a1 131 12c 130
0 138 2c :3 0
4b :2 0 132 133
0 135 a3 137
10c 111 0 138
0 135 0 138
a5 0 2c4 c
:3 0 b :3 0 4c
:2 0 ad 13b 13c
:3 0 13d :2 0 4d
:3 0 c :3 0 b
:3 0 27 :3 0 28
:3 0 b0 13f 144
:2 0 146 b5 14f
27 :3 0 c :3 0
4e :2 0 b :3 0
b7 149 14b :3 0
147 14c 0 14e
ba 150 13e 146
0 151 0 14e
0 151 bc 0
2c4 2e :3 0 4f
:4 0 50 :2 0 d
:3 0 bf 154 156
:3 0 50 :2 0 51
:4 0 c2 158 15a
:3 0 50 :2 0 f
:3 0 c5 15c 15e
:3 0 50 :2 0 33
:3 0 c8 160 162
:3 0 152 163 0
2c4 2e :3 0 2e
:3 0 50 :2 0 52
:4 0 cb 167 169
:3 0 50 :2 0 b
:3 0 ce 16b 16d
:3 0 50 :2 0 53
:4 0 d1 16f 171
:3 0 50 :2 0 c
:3 0 d4 173 175
:3 0 50 :2 0 54
:4 0 d7 177 179
:3 0 50 :2 0 27
:3 0 da 17b 17d
:3 0 50 :2 0 33
:3 0 dd 17f 181
:3 0 165 182 0
2c4 2b :3 0 55
:3 0 f :3 0 56
:4 0 e0 185 188
4e :2 0 55 :3 0
d :3 0 56 :4 0
e3 18b 18e e6
18a 190 :3 0 184
191 0 2c4 57
:3 0 38 :3 0 58
:3 0 193 194 59
:3 0 5a :3 0 5b
:3 0 e9 14 :3 0
12 :3 0 25 :3 0
5c :3 0 ed 19f
1ae 0 1af :3 0
3f :3 0 2 :3 0
3b :2 0 f1 1a3
1a4 :3 0 5d :3 0
57 :3 0 3b :2 0
5c :3 0 1a7 1a9
0 f6 1a8 1ab
:3 0 1a5 1ad 1ac
:3 0 1b1 1b2 :5 0
19a 1a0 0 f9
0 1b0 :2 0 267
5e :3 0 5f :3 0
60 :3 0 61 :3 0
62 :3 0 63 :3 0
64 :3 0 65 :3 0
66 :3 0 67 :3 0
68 :3 0 69 :3 0
fd 19 :3 0 1a
:3 0 1b :3 0 1c
:3 0 1d :3 0 1e
:3 0 1f :3 0 20
:3 0 21 :3 0 22
:3 0 23 :3 0 24
:3 0 6a :3 0 10a
1ce 1dd 0 1de
:3 0 3f :3 0 2
:3 0 3b :2 0 10e
1d2 1d3 :3 0 6b
:3 0 57 :3 0 3b
:2 0 6b :3 0 1d6
1d8 0 113 1d7
1da :3 0 1d4 1dc
1db :3 0 1e0 1e1
:5 0 1c0 1cf 0
116 0 1df :2 0
267 17 :3 0 32
:2 0 1e3 1e4 0
267 19 :3 0 3b
:2 0 32 :2 0 125
1e7 1e9 :3 0 1ea
:2 0 16 :3 0 6c
:3 0 21 :3 0 6d
:2 0 2b :3 0 128
1ef 1f1 :3 0 1f2
:2 0 6e :2 0 2c
:3 0 12b 1f4 1f6
:3 0 34 :2 0 12e
1ed 1f9 1ec 1fa
0 1fc 131 211
6f :3 0 27 :3 0
1d :3 0 19 :3 0
21 :3 0 1e :3 0
1a :3 0 22 :3 0
1f :3 0 1b :3 0
23 :3 0 20 :3 0
1c :3 0 24 :3 0
2c :3 0 2b :3 0
16 :3 0 133 1fd
20e :2 0 210 144
212 1eb 1fc 0
213 0 210 0
213 146 0 267
2e :3 0 2e :3 0
50 :2 0 70 :4 0
149 216 218 :3 0
50 :2 0 25 :3 0
14c 21a 21c :3 0
50 :2 0 71 :4 0
14f 21e 220 :3 0
50 :2 0 16 :3 0
152 222 224 :3 0
214 225 0 267
14 :3 0 3b :2 0
49 :4 0 157 228
22a :3 0 16 :3 0
72 :2 0 32 :2 0
15c 22d 22f :3 0
22b 231 230 :2 0
232 :2 0 17 :3 0
16 :3 0 6d :2 0
12 :3 0 15f 236
238 :3 0 6e :2 0
73 :2 0 162 23a
23c :3 0 234 23d
0 24e 2e :3 0
2e :3 0 50 :2 0
74 :4 0 165 241
243 :3 0 50 :2 0
6c :3 0 17 :3 0
34 :2 0 168 246
249 16b 245 24b
:3 0 23f 24c 0
24e 16e 24f 233
24e 0 250 171
0 267 2e :3 0
2e :3 0 50 :2 0
33 :3 0 173 253
255 :3 0 251 256
0 267 31 :3 0
6c :3 0 31 :3 0
75 :2 0 16 :3 0
176 25b 25d :3 0
75 :2 0 17 :3 0
179 25f 261 :3 0
34 :2 0 17c 259
264 258 265 0
267 17f 269 58
:3 0 196 267 :4 0
2c4 36 :3 0 72
:2 0 32 :2 0 18a
26b 26d :3 0 35
:3 0 76 :3 0 75
:2 0 36 :3 0 18d
271 273 :3 0 26f
274 0 29c 77
:3 0 35 :3 0 78
:4 0 190 276 279
3b :2 0 79 :2 0
195 27b 27d :3 0
35 :3 0 35 :3 0
75 :2 0 34 :2 0
198 281 283 :3 0
27f 284 0 287
44 :3 0 19b 29a
77 :3 0 35 :3 0
78 :4 0 19d 288
28b 3b :2 0 2a
:2 0 1a2 28d 28f
:3 0 35 :3 0 35
:3 0 75 :2 0 15
:2 0 1a5 293 295
:3 0 291 296 0
298 1a8 299 290
298 0 29b 27e
287 0 29b 1aa
0 29c 1ad 2a1
35 :4 0 29d 29e
0 2a0 1b0 2a2
26e 29c 0 2a3
0 2a0 0 2a3
1b2 0 2c4 7a
:3 0 2 :3 0 4
:3 0 77 :3 0 76
:3 0 7b :4 0 1b5
2a7 2aa 7c :4 0
77 :3 0 76 :3 0
7b :4 0 1b8 2ad
2b0 7 :4 0 8
:3 0 76 :3 0 35
:3 0 31 :3 0 2e
:3 0 30 :4 0 30
:4 0 30 :4 0 30
:4 0 a :4 0 32
:2 0 29 :3 0 10
:3 0 1bb 2a4 2c2
:2 0 2c4 1d1 2c7
:3 0 2c7 1dc 2c7
2c6 2c4 2c5 :6 0
2c8 :2 0 1 30
2c7 2cb :3 0 2ca
2c8 2cc :8 0 
1fb
4
:3 0 1 2 1
6 1 a 1
e 1 12 1
16 1 1a 1
1e 1 22 1
26 1 2a b
5 9 d 11
15 19 1d 21
25 29 2e 1
32 1 39 1
37 1 3e 1
43 1 48 1
4d 1 52 1
57 1 5c 1
61 1 66 1
6b 1 70 1
75 1 7a 1
7f 1 84 1
8b 1 89 1
90 1 95 1
9c 1 9a 1
a1 1 a6 1
ad 1 ab 1
b4 1 b2 1
ba 1 c2 1
c0 1 c7 1
cc 1 d7 1
db 2 da db
1 e2 2 e8
e9 1 ed 1
f1 2 f0 f1
2 eb ec 1
fd 1 100 1
ff 1 10a 2
108 10a 1 10f
1 114 2 112
114 1 119 1
11f 2 11d 11f
1 124 1 12a
2 128 12a 1
12f 1 134 5
136 11c 127 131
137 1 13a 2
139 13a 4 140
141 142 143 1
145 2 148 14a
1 14d 2 14f
150 2 153 155
2 157 159 2
15b 15d 2 15f
161 2 166 168
2 16a 16c 2
16e 170 2 172
174 2 176 178
2 17a 17c 2
17e 180 2 186
187 2 18c 18d
2 189 18f 3
197 198 199 1
19e 1 1a2 2
1a1 1a2 1 1aa
2 1a6 1aa 3
19b 19c 19d c
1b4 1b5 1b6 1b7
1b8 1b9 1ba 1bb
1bc 1bd 1be 1bf
1 1cd 1 1d1
2 1d0 1d1 1
1d9 2 1d5 1d9
c 1c1 1c2 1c3
1c4 1c5 1c6 1c7
1c8 1c9 1ca 1cb
1cc 1 1e8 2
1e6 1e8 2 1ee
1f0 2 1f3 1f5
2 1f7 1f8 1
1fb 10 1fe 1ff
200 201 202 203
204 205 206 207
208 209 20a 20b
20c 20d 1 20f
2 211 212 2
215 217 2 219
21b 2 21d 21f
2 221 223 1
229 2 227 229
1 22e 2 22c
22e 2 235 237
2 239 23b 2
240 242 2 247
248 2 244 24a
2 23e 24d 1
24f 2 252 254
2 25a 25c 2
25e 260 2 262
263 8 1b3 1e2
1e5 213 226 250
257 266 1 26c
2 26a 26c 2
270 272 2 277
278 1 27c 2
27a 27c 2 280
282 1 285 2
289 28a 1 28e
2 28c 28e 2
292 294 1 297
2 29a 299 2
275 29b 1 29f
2 2a1 2a2 2
2a8 2a9 2 2ae
2af 15 2a5 2a6
2ab 2ac 2b1 2b2
2b3 2b4 2b5 2b6
2b7 2b8 2b9 2ba
2bb 2bc 2bd 2be
2bf 2c0 2c1 a
f9 107 138 151
164 183 192 269
2a3 2c3 1e 35
3c 41 46 4b
50 55 5a 5f
64 69 6e 73
78 7d 82 87
8e 93 98 9f
a4 a9 b0 b8
be c5 ca cf
e3 
1
4
0 
2cb
0
1
14
3
2b
0 1 1 0 0 0 0 0
0 0 0 0 0 0 0 0
0 0 0 0 
1e 1 0
1 0 1
c0 1 0
ab 1 0
1a 1 0
75 1 0
7a 1 0
7f 1 0
84 1 0
ba 1 0
3e 1 0
e 1 0
193 3 0
43 1 0
61 1 0
6 1 0
66 1 0
6b 1 0
70 1 0
a6 1 0
26 1 0
a1 1 0
4d 1 0
52 1 0
57 1 0
5c 1 0
d2 1 2
90 1 0
32 1 0
c7 1 0
89 1 0
16 1 0
cc 1 0
b2 1 0
48 1 0
2 1 0
2a 1 0
95 1 0
37 1 0
22 1 0
9a 1 0
12 1 0
a 1 0
0

/
CREATE OR REPLACE PROCEDURE AGUA_BAJA_RESTAURA wrapped 
0
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
3
7
9000000
1
4
0 
63
2 :e:
1AGUA_BAJA_RESTAURA:
1XID:
1INTEGER:
1XFECHA:
1DATE:
1XMOTIVOBAJA:
1CHAR:
1XSIGENERALIQUI:
1XDESDE:
1XHASTA:
1XFECHA_BAJA:
1XMUNICIPIO:
13:
1XCONCEPTO:
16:
1XNIF:
110:
1XCODIGO_CALLE:
14:
1XCALLE_SUMINISTRO:
1VARCHAR:
125:
1XDOM_SUMINISTRO:
1VARCHAR2:
160:
1XFIANZA:
1FLOAT:
1XCONTADOR:
1XEXPEDIENTE:
1XIDLIQUI:
1XRECIBO:
17:
1XMOTIVO:
11024:
1XNUMERO:
1XBLOQUE:
11:
1XESCALERA:
1XPLANTA:
12:
1XPISO:
1XLETRA:
1XANTERIOR:
1XACTUAL:
1XLIQUIBAJACONSUMO:
1XFINPEVOL:
1XDIAS:
1FECHA_BAJA:
1MUNICIPIO:
1NIF:
1CODIGO_CALLE:
1FIANZA:
1CONTADOR:
1EXPEDIENTE:
1NUMERO:
1BLOQUE:
1ESCALERA:
1PLANTA:
1PISO:
1LETRA:
1ANTERIOR:
1ACTUAL:
1AGUA:
1ID:
1=:
1IS NULL:
1S:
1CALLE:
1CALLES:
1RTRIM:
1||:
1 :
1>:
10:
1CODIGO:
1AGUACOD_TARIFA:
1DESCRIPCION:
1LIQ. POR FIANZA EN BAJAS:
1DIAS_VENCIMIENTO:
1DATOSPER:
1SYSDATE:
1+:
1TO_CHAR:
1d:
1ELSIF:
1BAJA DE SUMINISTRO DE AGUA :
1N.CONTADOR:: :
1 EXPEDIENTE:: :
1ADD_LIQUI:
1YYYY:
100:
1*:
1-:
1:
1LIQ. POR BAJA EN EL CONSUMO:
1CALCULO_CUOTA_LIQUI_AGUA:
1MOTIVO_BAJA:
1LIQUIBAJAFIANZA:
1LIQUIBAJACONSUMO:
0

0
0
237
2
0 9a 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d 8f a0 b0 3d 8f a0
b0 3d b4 55 6a a3 a0 1c
81 b0 a3 a0 51 a5 1c 81
b0 a3 a0 51 a5 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 51 a5 1c 81 b0 a3 a0
51 a5 1c 81 b0 a3 a0 51
a5 1c 81 b0 a3 a0 1c 81
b0 a3 a0 51 a5 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 1c 81 b0 a3 a0 51 a5
1c 81 b0 a3 a0 51 a5 1c
81 b0 a3 a0 51 a5 1c 81
b0 a3 a0 51 a5 1c 81 b0
a3 a0 51 a5 1c 81 b0 a3
a0 51 a5 1c 81 b0 a3 a0
51 a5 1c 81 b0 a3 a0 51
a5 1c 81 b0 a3 a0 1c 81
b0 a3 a0 1c 81 b0 a3 a0
1c 81 b0 a3 a0 1c 81 b0
a3 a0 1c 81 b0 :f a0 ac :10 a0
b2 ee :2 a0 7e b4 2e ac e5
d0 b2 e9 a0 7e b4 2e a0
4d d a0 7e 6e b4 2e a0
ac :2 a0 b2 ee :2 a0 7e b4 2e
:2 a0 7e b4 2e a 10 ac e5
d0 b2 e9 :3 a0 a5 b 7e 6e
b4 2e 7e a0 b4 2e 7e 6e
b4 2e 7e a0 b4 2e 7e 6e
b4 2e 7e a0 b4 2e 7e 6e
b4 2e 7e a0 b4 2e 7e 6e
b4 2e 7e a0 b4 2e 7e 6e
b4 2e 7e a0 b4 2e d a0
7e 51 b4 2e a0 ac :2 a0 b2
ee :2 a0 7e b4 2e a0 7e 6e
b4 2e a 10 ac e5 d0 b2
e9 a0 ac :2 a0 b2 ee :2 a0 7e
b4 2e ac e5 d0 b2 e9 a0
7e 51 b4 2e :2 a0 7e a0 b4
2e d :2 a0 6e a5 b 7e 51
b4 2e :2 a0 7e 51 b4 2e d
a0 b7 :2 a0 6e a5 b 7e 51
b4 2e :2 a0 7e 51 b4 2e d
b7 :2 19 3c b7 a0 4d d b7
:2 19 3c a0 6e 7e 6e b4 2e
7e a0 b4 2e 7e 6e b4 2e
7e a0 b4 2e d :5 a0 6e a5
b 6e :2 a0 6e a5 b a0 4d
:4 a0 :2 7e 51 b4 2e b4 2e a0
:4 6e a0 4d 51 :2 a0 a5 57 b7
19 3c a0 ac :2 a0 b2 ee :2 a0
7e b4 2e a0 7e 6e b4 2e
a 10 ac e5 d0 b2 e9 :c a0
a5 57 b7 19 3c :3 a0 e7 :2 a0
e7 :2 a0 e7 :2 a0 e7 :2 a0 7e b4
2e ef f9 e9 b7 :2 a0 4d e7
a0 4d e7 :2 a0 7e b4 2e ef
f9 e9 b7 :2 19 3c b7 a4 b1
11 68 4f 1d 17 b5 
237
2
0 3 1f 1b 1a 27 34 30
17 3c 45 41 2f 4d 5a 56
2c 62 6b 67 55 73 80 7c
52 88 7b 8d 91 aa 99 9d
a5 78 c6 b1 b5 b8 b9 c1
98 e3 d1 95 d5 d6 de d0
100 ee cd f2 f3 fb ed 11d
10b ea 10f 110 118 10a 13a 128
107 12c 12d 135 127 157 145 124
149 14a 152 144 173 162 166 16e
141 18f 17a 17e 181 182 18a 161
1ac 19a 15e 19e 19f 1a7 199 1c8
1b7 1bb 1c3 196 1e4 1cf 1d3 1d6
1d7 1df 1b6 201 1ef 1b3 1f3 1f4
1fc 1ee 21e 20c 1eb 210 211 219
20b 23b 229 208 22d 22e 236 228
258 246 225 24a 24b 253 245 275
263 242 267 268 270 262 292 280
25f 284 285 28d 27f 2af 29d 27c
2a1 2a2 2aa 29c 2cb 2ba 2be 2c6
299 2e3 2d2 2d6 2de 2b9 2ff 2ee
2f2 2fa 2b6 317 306 30a 312 2ed
333 322 326 32e 2ea 31e 33a 33e
342 346 34a 34e 352 356 35a 35e
362 366 36a 36e 372 373 377 37b
37f 383 387 38b 38f 393 397 39b
39f 3a3 3a7 3ab 3af 3b3 3b4 3bb
3bf 3c3 3c6 3c7 3cc 3cd 3d3 3d7
3d8 3dd 3e1 3e4 3e5 3ea 3ee 3ef
3f3 3f7 3fa 3ff 400 405 409 40a
40e 412 413 41a 41e 422 425 426
42b 42f 433 436 437 1 43c 441
442 448 44c 44d 452 456 45a 45e
45f 461 464 469 46a 46f 472 476
477 47c 47f 484 485 48a 48d 491
492 497 49a 49f 4a0 4a5 4a8 4ac
4ad 4b2 4b5 4ba 4bb 4c0 4c3 4c7
4c8 4cd 4d0 4d5 4d6 4db 4de 4e2
4e3 4e8 4eb 4f0 4f1 4f6 4f9 4fd
4fe 503 507 50b 50e 511 512 517
51b 51c 520 524 525 52c 530 534
537 538 53d 541 544 549 54a 1
54f 554 555 55b 55f 560 565 569
56a 56e 572 573 57a 57e 582 585
586 58b 58c 592 596 597 59c 5a0
5a3 5a6 5a7 5ac 5b0 5b4 5b7 5bb
5bc 5c1 5c5 5c9 5cd 5d2 5d3 5d5
5d8 5db 5dc 5e1 5e5 5e9 5ec 5ef
5f0 5f5 5f9 5fd 5ff 603 607 60c
60d 60f 612 615 616 61b 61f 623
626 629 62a 62f 633 635 639 63d
640 642 646 647 64b 64d 651 655
658 65c 661 664 669 66a 66f 672
676 677 67c 67f 684 685 68a 68d
691 692 697 69b 69f 6a3 6a7 6ab
6af 6b4 6b5 6b7 6bc 6c0 6c4 6c9
6ca 6cc 6d0 6d1 6d5 6d9 6dd 6e1
6e4 6e7 6ea 6eb 6f0 6f1 6f6 6fa
6ff 704 709 70e 712 713 716 71a
71e 71f 724 726 72a 72d 731 732
736 73a 73b 742 746 74a 74d 74e
753 757 75a 75f 760 1 765 76a
76b 771 775 776 77b 77f 783 787
78b 78f 793 797 79b 79f 7a3 7a7
7ab 7ac 7b1 7b3 7b7 7ba 7be 7c2
7c6 7c8 7cc 7d0 7d2 7d6 7da 7dc
7e0 7e4 7e6 7ea 7ee 7f1 7f2 7f7
7fd 7fe 803 805 809 80d 80e 810
814 815 817 81b 81f 822 823 828
82e 82f 834 836 83a 83e 841 843
847 849 855 859 85b 85c 865 
237
2
0 b 4 10 :3 4 13 :3 4 16
:3 4 17 :3 4 11 :3 4 11 :2 4 1d
:2 1 2 :3 10 :2 2 f 14 13 :2 f
:2 2 e 13 12 :2 e :2 2 a f
e :2 a :2 2 11 16 15 :2 11 :2 2
14 1c 1b :2 14 :2 2 13 1c 1b
:2 13 2 5 :3 10 :2 5 11 16 15
:2 11 :2 5 13 18 17 :2 13 5 2
:3 d :2 2 e 13 12 :2 e :2 2 13
1c 1b :2 13 :2 2 d 12 11 :2 d
2 5 10 15 14 :2 10 :2 5 12
17 16 :2 12 :2 5 10 15 14 :2 10
:2 5 f 14 13 :2 f :2 5 10 15
14 :2 10 :2 5 :3 11 :2 5 :3 10 :2 5 :3 17
:2 5 :3 19 :2 5 :3 19 5 9 14 1e
22 2f 36 3f 4 b 12 1b
22 27 2d 36 9 7 13 1e
23 31 39 43 4 c 14 1e
26 2c 33 3d 7 2 7 12
15 :3 14 :5 2 :4 5 3 d 3 6
14 15 :2 14 :2 b 16 2d 28 2d
a 17 :3 16 29 33 :3 32 :2 a 28
:5 4 15 1b :2 15 2d 2f :2 15 32
34 :2 15 3b 3d :2 15 40 42 :2 15
49 4b :2 15 4e 6 :2 15 f 11
:2 15 14 16 :2 15 1d 1f :2 15 22
24 :2 15 29 2b :2 15 2e 30 :2 15
4 7 f 11 :2 f :2 c 18 27
22 27 b 15 :3 14 24 2f 30
:2 2f :2 b 22 :4 5 :2 18 2e 39 34
39 48 52 :3 51 34 :5 11 17 19
:2 17 d 18 1f 20 :2 18 d 10
18 22 :2 10 26 27 :2 26 c 17
20 21 :2 17 c d 29 13 1b
25 :2 13 29 2a :2 29 c 17 20
21 :2 17 c 2c 29 :2 d 1b d
18 d :4 e 5 e 2b 2d :2 e
3b 3e :2 e 48 4b :2 e 5a 5d
:2 e :2 5 f 1a 24 2c 34 :2 24
3c 41 49 51 :2 41 6 c 12
23 2c 6 d e f :2 e :2 6
12 1a 1d 20 23 26 32 37
39 41 :2 5 13 :2 4 :2 b 17 26
21 26 a 14 :3 13 23 2e 2f
:2 2e :2 a 21 :5 4 1d 28 32 36
3b 4b 6 11 19 20 27 :2 4
19 :2 3 a 13 1e 13 7 13
:2 7 17 :2 7 18 7 9 c :3 b
:3 3 19 a 13 1e 13 24 30
24 3b 3e :3 3d :3 3 :4 2 :9 1 
237
4
0 1 :4 2 :4 3
:4 4 :4 5 :4 6 :4 7
:3 1 :5 a :7 b :7 c
:7 d :7 e :7 f :7 10
:5 11 :7 12 :7 13 :5 14
:7 15 :7 16 :7 18 :7 19
:7 1a :7 1b :7 1c :7 1d
:5 1e :5 1f :5 20 :5 21
:5 22 :7 26 :8 27 26
:7 28 :8 29 :9 2a :4 26
:4 2d :3 2f :5 31 :6 35
:c 36 :5 35 :1a 38 39
:2 38 :2 39 :2 38 :2 39
:2 38 :2 39 :2 38 :2 39
:2 38 :2 39 :2 38 :2 39
:3 38 :5 3b :6 3d :c 3e
:5 3d :10 40 :5 42 :7 43
:9 45 :7 46 48 45
:9 48 :7 49 48 :3 45
42 :3 4c 4b :3 42
:13 4f :e 51 :5 52 :12 53
:2 51 :3 3b :6 56 :c 57
:5 56 :7 5a :5 5b :2 5a
:3 31 :4 5f :3 60 :3 61
:3 62 :5 63 :3 5f 2d
:f 67 65 :3 2d :2 24
:7 1 
867
4
:3 0 1 :a 0 232
1 :7 0 5 2c
0 :2 3 :3 0 2
:7 0 4 3 :3 0
9 52 0 7
5 :3 0 4 :7 0
8 7 :3 0 7
:3 0 6 :7 0 c
b :3 0 d 78
0 b 7 :3 0
8 :7 0 10 f
:3 0 5 :3 0 9
:7 0 14 13 :3 0
16 95 0 f
5 :3 0 a :7 0
18 17 :3 0 1a
:2 0 232 1 1b
:2 0 f :2 0 1a
5 :3 0 1e :7 0
21 1f 0 230
0 b :6 0 7
:3 0 d :2 0 18
23 25 :6 0 28
26 0 230 0
c :6 0 11 :2 0
1e 7 :3 0 1c
2a 2c :6 0 2f
2d 0 230 0
e :6 0 13 :2 0
22 7 :3 0 20
31 33 :6 0 36
34 0 230 0
10 :6 0 16 :2 0
26 7 :3 0 24
38 3a :6 0 3d
3b 0 230 0
12 :6 0 19 :2 0
2a 15 :3 0 28
3f 41 :6 0 44
42 0 230 0
14 :6 0 30 15e
0 2e 18 :3 0
2c 46 48 :6 0
4b 49 0 230
0 17 :6 0 11
:2 0 34 1b :3 0
4d :7 0 50 4e
0 230 0 1a
:6 0 7 :3 0 11
:2 0 32 52 54
:6 0 57 55 0
230 0 1c :6 0
3a 1b3 0 38
7 :3 0 36 59
5b :6 0 5e 5c
0 230 0 1d
:6 0 22 :2 0 3e
3 :3 0 60 :7 0
63 61 0 230
0 1e :6 0 7
:3 0 20 :2 0 3c
65 67 :6 0 6a
68 0 230 0
1f :6 0 d :2 0
42 18 :3 0 40
6c 6e :6 0 71
6f 0 230 0
21 :6 0 25 :2 0
46 7 :3 0 44
73 75 :6 0 78
76 0 230 0
23 :6 0 25 :2 0
4a 7 :3 0 48
7a 7c :6 0 7f
7d 0 230 0
24 :6 0 28 :2 0
4e 7 :3 0 4c
81 83 :6 0 86
84 0 230 0
26 :6 0 28 :2 0
52 7 :3 0 50
88 8a :6 0 8d
8b 0 230 0
27 :6 0 28 :2 0
56 7 :3 0 54
8f 91 :6 0 94
92 0 230 0
29 :6 0 5c 2b6
0 5a 7 :3 0
58 96 98 :6 0
9b 99 0 230
0 2a :6 0 60
2ea 0 5e 3
:3 0 9d :7 0 a0
9e 0 230 0
2b :6 0 3 :3 0
a2 :7 0 a5 a3
0 230 0 2c
:6 0 64 31e 0
62 3 :3 0 a7
:7 0 aa a8 0
230 0 2d :6 0
5 :3 0 ac :7 0
af ad 0 230
0 2e :6 0 30
:3 0 3 :3 0 b1
:7 0 b4 b2 0
230 0 2f :6 0
31 :3 0 32 :3 0
33 :3 0 34 :3 0
35 :3 0 36 :3 0
37 :3 0 38 :3 0
39 :3 0 3a :3 0
3b :3 0 3c :3 0
3d :3 0 3e :3 0
66 b :3 0 c
:3 0 10 :3 0 12
:3 0 1a :3 0 1c
:3 0 1d :3 0 23
:3 0 24 :3 0 26
:3 0 27 :3 0 29
:3 0 2a :3 0 2b
:3 0 2c :3 0 3f
:3 0 76 d5 db
0 dc :3 0 40
:3 0 2 :3 0 41
:2 0 7a d9 da
:4 0 de df :5 0
c4 d6 0 7d
0 dd :2 0 22e
b :3 0 42 :2 0
8d e2 e3 :3 0
1e :4 0 e5 e6
0 21a 8 :3 0
41 :2 0 43 :4 0
91 e9 eb :3 0
44 :3 0 94 14
:3 0 45 :3 0 96
f1 fe 0 ff
:3 0 33 :3 0 12
:3 0 41 :2 0 9a
f5 f6 :3 0 31
:3 0 c :3 0 41
:2 0 9f fa fb
:3 0 f7 fd fc
:3 0 101 102 :5 0
ee f2 0 a2
0 100 :2 0 202
17 :3 0 46 :3 0
14 :3 0 a4 105
107 47 :2 0 48
:4 0 a6 109 10b
:3 0 47 :2 0 23
:3 0 a9 10d 10f
:3 0 47 :2 0 48
:4 0 ac 111 113
:3 0 47 :2 0 24
:3 0 af 115 117
:3 0 47 :2 0 48
:4 0 b2 119 11b
:3 0 47 :2 0 26
:3 0 b5 11d 11f
:3 0 47 :2 0 48
:4 0 b8 121 123
:3 0 47 :2 0 27
:3 0 bb 125 127
:3 0 47 :2 0 48
:4 0 be 129 12b
:3 0 47 :2 0 29
:3 0 c1 12d 12f
:3 0 47 :2 0 48
:4 0 c4 131 133
:3 0 47 :2 0 2a
:3 0 c7 135 137
:3 0 104 138 0
202 1a :3 0 49
:2 0 4a :2 0 cc
13b 13d :3 0 4b
:3 0 cf e :3 0
4c :3 0 d1 143
150 0 151 :3 0
31 :3 0 c :3 0
41 :2 0 d5 147
148 :3 0 4d :3 0
41 :2 0 4e :4 0
da 14b 14d :3 0
149 14f 14e :3 0
153 154 :5 0 140
144 0 dd 0
152 :2 0 1da 4f
:3 0 df 2f :3 0
50 :3 0 e1 15a
160 0 161 :3 0
31 :3 0 c :3 0
41 :2 0 e5 15e
15f :4 0 163 164
:5 0 157 15b 0
e8 0 162 :2 0
1da 2f :3 0 49
:2 0 4a :2 0 ec
167 169 :3 0 2e
:3 0 51 :3 0 52
:2 0 2f :3 0 ef
16d 16f :3 0 16b
170 0 198 53
:3 0 2e :3 0 54
:4 0 f2 172 175
41 :2 0 f :2 0
f7 177 179 :3 0
2e :3 0 2e :3 0
52 :2 0 28 :2 0
fa 17d 17f :3 0
17b 180 0 183
55 :3 0 fd 196
53 :3 0 2e :3 0
54 :4 0 ff 184
187 41 :2 0 20
:2 0 104 189 18b
:3 0 2e :3 0 2e
:3 0 52 :2 0 25
:2 0 107 18f 191
:3 0 18d 192 0
194 10a 195 18c
194 0 197 17a
183 0 197 10c
0 198 10f 19d
2e :4 0 199 19a
0 19c 112 19e
16a 198 0 19f
0 19c 0 19f
114 0 1da 21
:3 0 56 :4 0 47
:2 0 57 :4 0 117
1a2 1a4 :3 0 47
:2 0 1c :3 0 11a
1a6 1a8 :3 0 47
:2 0 58 :4 0 11d
1aa 1ac :3 0 47
:2 0 1d :3 0 120
1ae 1b0 :3 0 1a0
1b1 0 1da 59
:3 0 c :3 0 e
:3 0 53 :3 0 51
:3 0 5a :4 0 123
1b6 1b9 5b :4 0
53 :3 0 51 :3 0
5a :4 0 126 1bc
1bf 10 :4 0 17
:3 0 51 :3 0 2e
:3 0 1a :3 0 5c
:2 0 5d :2 0 25
:2 0 129 1c8 1ca
:3 0 12b 1c7 1cc
:3 0 21 :3 0 5e
:4 0 5e :4 0 5e
:4 0 5e :4 0 1d
:4 0 4a :2 0 1f
:3 0 1e :3 0 12e
1b3 1d8 :2 0 1da
144 1db 13e 1da
0 1dc 14a 0
202 4b :3 0 14c
e :3 0 4c :3 0
14e 1e1 1ee 0
1ef :3 0 31 :3 0
c :3 0 41 :2 0
152 1e5 1e6 :3 0
4d :3 0 41 :2 0
5f :4 0 157 1e9
1eb :3 0 1e7 1ed
1ec :3 0 1f1 1f2
:5 0 1de 1e2 0
15a 0 1f0 :2 0
202 60 :3 0 c
:3 0 e :3 0 2
:3 0 10 :3 0 17
:3 0 1d :3 0 2b
:3 0 2c :3 0 9
:3 0 a :3 0 2d
:3 0 15c 1f4 200
:2 0 202 168 203
ec 202 0 204
16e 0 21a 3f
:3 0 30 :3 0 4
:3 0 206 207 61
:3 0 6 :3 0 209
20a 62 :3 0 1e
:3 0 20c 20d 63
:3 0 2d :3 0 20f
210 40 :3 0 2
:3 0 41 :2 0 172
214 215 :3 0 205
218 216 0 219
0 175 0 217
:2 0 21a 17a 22b
3f :3 0 30 :4 0
21c 21d 61 :4 0
21f 220 40 :3 0
2 :3 0 41 :2 0
180 224 225 :3 0
21b 228 226 0
229 0 183 0
227 :2 0 22a 186
22c e4 21a 0
22d 0 22a 0
22d 188 0 22e
18b 231 :3 0 231
18e 231 230 22e
22f :6 0 232 :2 0
1 1b 231 235
:3 0 234 232 236
:8 0 
1a7
4
:3 0 1 2 1
6 1 a 1
e 1 12 1
16 6 5 9
d 11 15 19
1 1d 1 24
1 22 1 2b
1 29 1 32
1 30 1 39
1 37 1 40
1 3e 1 47
1 45 1 4c
1 53 1 51
1 5a 1 58
1 5f 1 66
1 64 1 6d
1 6b 1 74
1 72 1 7b
1 79 1 82
1 80 1 89
1 87 1 90
1 8e 1 97
1 95 1 9c
1 a1 1 a6
1 ab 1 b0
f b5 b6 b7
b8 b9 ba bb
bc bd be bf
c0 c1 c2 c3
1 d4 1 d8
2 d7 d8 f
c5 c6 c7 c8
c9 ca cb cc
cd ce cf d0
d1 d2 d3 1
e1 1 ea 2
e8 ea 1 ed
1 f0 1 f4
2 f3 f4 1
f9 2 f8 f9
1 ef 1 106
2 108 10a 2
10c 10e 2 110
112 2 114 116
2 118 11a 2
11c 11e 2 120
122 2 124 126
2 128 12a 2
12c 12e 2 130
132 2 134 136
1 13c 2 13a
13c 1 13f 1
142 1 146 2
145 146 1 14c
2 14a 14c 1
141 1 156 1
159 1 15d 2
15c 15d 1 158
1 168 2 166
168 2 16c 16e
2 173 174 1
178 2 176 178
2 17c 17e 1
181 2 185 186
1 18a 2 188
18a 2 18e 190
1 193 2 196
195 2 171 197
1 19b 2 19d
19e 2 1a1 1a3
2 1a5 1a7 2
1a9 1ab 2 1ad
1af 2 1b7 1b8
2 1bd 1be 1
1c9 2 1c6 1cb
15 1b4 1b5 1ba
1bb 1c0 1c1 1c2
1c3 1c4 1c5 1cd
1ce 1cf 1d0 1d1
1d2 1d3 1d4 1d5
1d6 1d7 5 155
165 19f 1b2 1d9
1 1db 1 1dd
1 1e0 1 1e4
2 1e3 1e4 1
1ea 2 1e8 1ea
1 1df b 1f5
1f6 1f7 1f8 1f9
1fa 1fb 1fc 1fd
1fe 1ff 5 103
139 1dc 1f3 201
1 203 1 213
2 212 213 4
208 20b 20e 211
3 e7 204 219
1 223 2 222
223 2 21e 221
1 229 2 22b
22c 2 e0 22d
18 20 27 2e
35 3c 43 4a
4f 56 5d 62
69 70 77 7e
85 8c 93 9a
9f a4 a9 ae
b3 
1
4
0 
235
0
1
14
1
1f
0 0 0 0 0 0 0 0
0 0 0 0 0 0 0 0
0 0 0 0 
1d 1 0
a 1 0
a1 1 0
a6 1 0
4c 1 0
9c 1 0
72 1 0
51 1 0
30 1 0
29 1 0
95 1 0
1 0 1
16 1 0
79 1 0
3e 1 0
b0 1 0
37 1 0
6 1 0
ab 1 0
2 1 0
80 1 0
58 1 0
87 1 0
6b 1 0
22 1 0
5f 1 0
8e 1 0
12 1 0
e 1 0
64 1 0
45 1 0
0

/
