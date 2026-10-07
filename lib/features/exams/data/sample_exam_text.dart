/// Texto anonimizado no formato Unilab (baseado em laudo real de hemograma completo).
/// Usado pelo botão "Carregar exame de exemplo" — sem dados pessoais.
const sampleExamPdfText = '''
Hemograma Completo
Material: Sangue total (EDTA) 	Coleta: 03/08/2026 - 08:18
Método: Sistema automatizado
Eritrograma 	Valores de referência
Hemácias: 	5,36 milhões/mm³ 	4,5 a 6,0 milhões/mm³
Hemoglobina: 	16,1 g/dL 	13,0 a 17,0 g/dL
Hematócrito: 	47,8 % 	38 a 52 %
V.C.M: 	89,1 fL 	82 a 98 fL
H.C.M: 	30,0 pg 	27 a 32 pg
C.H.C.M: 	33,6 g/dL 	32 a 36 g/dL
R.D.W: 	12,9 % 	Até 14,5 %
Leucograma 	Valores de referência
Leucócitos: 	4.970 /mm³ 	4.500 a 11.000 /mm³
Segmentados: 	55 % 	2.733 /mm³ 	50 a 67 %
Eosinófilos: 	2 % 	99 /mm³ 	1 a 4 %
Basófilos: 	1 % 	49 /mm³ 	0 a 1 %
Linfócitos: 	34 % 	1.689 /mm³ 	20 a 40 %
Monócitos: 	7 % 	347 /mm³ 	4 a 10 %
Plaquetas 	Valores de referência
Contagem de plaquetas: 	161.000 /mm³ 	150.000 a 450.000 /mm3
Resultados anteriores:
Hemoglobina: 10/01/2026 - 16,0
Hematocrito: 10/01/2026 - 47,2
Leucócitos: 10/01/2026 - 4.510
Plaquetas: 10/01/2026 - 176.000
Nome 	: PACIENTE EXEMPLO
Unidade 	: Unilab

Tempo de Atividade de Protrombina (TAP)
Material: Plasma (citrato) 	Coleta: 03/08/2026 - 08:18
Tempo de Protrombina: 	32,5 segundos
Valor de Referência: 10 a 15 segundos
Resultados anteriores: 10/01/2026 - 34,8
Atividade: 	21,5 %
Valor de Referência: 70 a 100%
Resultados anteriores: 10/01/2026 - 21,0
INR: 	3,10
Valor de Referência: 1,00 a 1,25
Resultados anteriores: 10/01/2026 - 3,26

Tempo de tromboplastina parcial ativada (TTPA)
Tempo de Tromboplastina: 	35,1 segundos
Valor de Referência: 22 a 31 segundos
Resultados anteriores: 10/01/2026 - 35,7
Ratio: 	1,54
Resultados anteriores: 10/01/2026 - 1,57

Glicose
Material: Soro 	Coleta: 03/08/2026 - 08:18
Resultado: 	92 mg/dL
Valor de Referência: 70 a 99 mg/dL
Resultados anteriores: 10/01/2026 - 98

Hemoglobina glicada (HBA1C)
Glicemia média estimada: 	102,5 mg/dL
Resultado: 	5,2 %
Valor de Referência: Inferior a 5,7%
Resultados anteriores: 10/01/2026 - 5,1

Colesterol Total e Frações
Colesterol Total: 	143 mg/dL 	Maiores de 20 anos: Desejável inferior a 190 mg/dL
Resultados anteriores: 10/01/2026 - 131
Colesterol HDL: 	44 mg/dL 	Desejável superior a 40 mg/dL
Resultados anteriores: 10/01/2026 - 39
Colesterol LDL: 	84 mg/dL 	Ótimo:menor que 100 mg/dL
Resultados anteriores: 10/01/2026 - 78
Colesterol VLDL: 	14 mg/dL
Colesterol não HDL: 	98 mg/dL
Índice de Castelli: 	3,26 	< 3,4

Triglicerídeos
Resultado: 	72 mg/dL
Valor de Referência: Desejável inferior a 150 mg/dL
Resultados anteriores: 10/01/2026 - 69

Creatinina
Resultado: 	1,13 mg/dL
Resultados anteriores: 10/01/2026 - 1,00

Ácido úrico
Resultado: 	2,9 mg/dL
Homens: 3,4 a 7,0 mg/dL
Resultados anteriores: 10/01/2026 - 3,0

Potássio
Resultado: 	5,0 mmol/L
Valor de Referência: 3,5 a 5,1 mmol/L
Resultados anteriores: 10/01/2026 - 4,1

Transaminase glutâmico oxalacética (AST/TGO)
Resultado: 	20 U/L
Homens: Até 40 U/L
Resultados anteriores: 30/03/2026 - 21 | 10/01/2026 - 17

Transaminase glutâmico pirúvica (ALT/TGP)
Resultado: 	30 U/L
Homens: Até 41 U/L
Resultados anteriores: 30/03/2026 - 28 | 10/01/2026 - 25

Ferritina
Resultado: 	151 ng/mL
Homens: 30 a 400 ng/mL
Resultados anteriores: 10/01/2026 - 142

TSH - Hormônio tireoestimulante
Resultado: 	0,91 microUI/mL
Adultos: 0,35 a 4,94 microUI/mL
Resultados anteriores: 10/01/2026 - 0,96

Proteína C Reativa Quantitativa Alta Sensibilidade
Resultado: 	0,40 mg/L
Para risco cardiovascular: Inferior a 2,00 mg/L

Lipoproteína A
Resultado: 	8 nmol/L
Valor de Referência: Inferior a 75 nmol/L
''';
