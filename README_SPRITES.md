# Skap Key — Sprites e Puzzle do Piano

## Max
Coloque a sprite sheet em:
`art/characters/max/max_sheet.png`

Formato esperado: 4 colunas x 3 linhas
- Linha 1: Idle 1 2 3 4
- Linha 2: Andar 1 2 3 4
- Linha 3: Ataque 1 2 3 4

## Vilões
O sistema também aceita sprite sheets no mesmo formato:
- Lobos: `art/characters/enemies/wolf_sheet.png`
- Cultistas: `art/characters/enemies/cultist_sheet.png`
- Lucy: `art/characters/lucy/lucy_sheet.png`

Se o PNG ainda não existir, o jogo usa automaticamente o desenho de fallback, então o projeto continua abrindo.

## Sala do piano
A sala não possui inimigos. Existem quatro mesas espalhadas: 1 DÓ, 2 MI, 3 SOL, 4 LÁ.
O teclado tem uma oitava completa: DÓ, RÉ, MI, FÁ, SOL, LÁ, SI, DÓ.
A única sequência que abre a porta é DÓ -> MI -> SOL -> LÁ. Qualquer erro reinicia a sequência.

## Progressão
Na Floresta Encantada, o portal da direita só abre depois que todos os inimigos forem derrotados.
Na última sala, não existe uma barreira interna bloqueando o acesso à arena de Lucy.
