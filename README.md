# SKAP KEY — A Chave do Conhecimento

Projeto Godot 4.7.2 Standard, sem plugins ou dependências externas.

## Abrir
1. Extraia o ZIP.
2. Abra o Godot 4.7.2 Standard.
3. Clique em Importar.
4. Selecione `project.godot`.
5. Pressione F6/F5.

## Controles
- WASD / Setas = mover
- Botão esquerdo do mouse = atacar na direção do cursor
- J ou Espaço = atacar
- Shift = dash / esquiva
- E = interagir
- Enter = iniciar/reiniciar

## Progressão
Floresta Encantada → Sala do Piano → Ruínas do Culto → Corredor dos Dardos → Santuário de Lucy.

## Sala do Piano
Depois da Floresta Encantada, Max entra em uma sala sem inimigos.
Há quatro mesas numeradas:

1. DÓ
2. MI
3. SOL
4. LÁ

Ao chegar perto do piano, aparece o teclado na tela. Clique na sequência correta:

DÓ → MI → SOL → LÁ

Se errar, a sequência reinicia. Ao acertar as quatro notas, a porta da direita é aberta e o jogador pode entrar nas Ruínas do Culto.

## Sprite sheet do Max
Coloque a imagem em:

`res://art/characters/max/max_sheet.png`

A imagem deve ser uma grade 4x3:

- Linha 1: Idle 1, 2, 3, 4
- Linha 2: Andar 1, 2, 3, 4
- Linha 3: Ataque 1, 2, 3, 4

O projeto divide os 12 frames automaticamente.


## Corredor dos Dardos
Depois das Ruínas do Culto, o portal do corredor já fica aberto. Dardos atravessam a sala da direita para a esquerda em várias alturas, inclusive no centro. Use WASD para mudar de faixa e Shift para o dash. Não é necessário esperar os dardos terminarem: basta atravessar vivo e entrar no portal do Santuário.

## Exportação Web / GitHub Pages
O projeto usa Godot 4.7.2 com Compatibility renderer (GL Compatibility), não usa plugins/GDExtension e inclui um preset Web em `export_presets.cfg`. O preset Web usa suporte a threads desativado, para não exigir isolamento cross-origin no GitHub Pages.

Para publicar: instale as export templates do Godot 4.7.2, abra Project → Export, selecione Web e exporte como `index.html`. Envie `index.html`, `.wasm`, `.pck` e os demais arquivos gerados para o repositório. O GitHub Pages deve servir o `index.html` na raiz.
