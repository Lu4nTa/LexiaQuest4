# LexiaQuest — Migração para Godot 4.7

Este pacote contém o projeto (3 níveis + 7 tipos de quiz) com o código e as cenas
convertidos manualmente para a sintaxe e API do Godot 4. **Não foi possível
compilar/correr este projeto neste ambiente** (sem o editor Godot instalado) — por
isso, antes de dares o projeto por "pronto", segue o checklist da secção 2 no teu
próprio computador, com o editor aberto.

## 1. O que foi convertido (feito, com confiança)

**Todos os 35 scripts GDScript**, incluindo:
- `export(...)` → `@export` / `@export_range(...)` / `@export_multiline` (~30 variáveis)
- `onready var` → `@onready var`
- `setget` → sintaxe `: set = _funcao` (7 ocorrências)
- `.connect(sinal, self, "_metodo", [args])` → `.connect(sinal, Callable(self, "_metodo").bind(args))` (12 ocorrências)
- `yield(x, "sinal")` → `await x.sinal` (4 ocorrências)
- `.instance()` → `.instantiate()`, `.empty()` → `.is_empty()`, `char(n)` → `String.chr(n)`
- `KinematicBody2D` → `CharacterBody2D`, e `move_and_slide(velocity, up)` → `move_and_slide()` (a
  velocidade agora é a propriedade nativa `velocity` do próprio nó — a variável duplicada foi removida)
- `BUTTON_LEFT` → `MOUSE_BUTTON_LEFT` (3 ocorrências)
- **`RectangleShape2D.extents` (meia-largura) → `.size` (largura total)** — esta é a
  alteração mais fácil de esconder um bug: se só mudares o nome da propriedade sem
  ajustar a matemática, todas as hitboxes ficam com metade do tamanho. Foi corrigido
  em `Player.gd`, `Sign.gd` e `Level.gd`, com comentário no código a explicar a conta.

**Todas as 24 cenas `.tscn`**:
- `format=2` → `format=3`
- `type="KinematicBody2D"` → `type="CharacterBody2D"` (Player)
- `type="Sprite"` → `type="Sprite2D"` (Present, DustCloud, fundos parallax)
- `type="AnimatedSprite"` → `type="AnimatedSprite2D"` (Player, StartScreen)

**`project.godot`**:
- `config_version` 4 → 5
- Classe base do `Player` no registo de classes globais
- `PoolStringArray` → `PackedStringArray`
- **Todo o mapa de teclas (`[input]`)** — reescrito propriedade a propriedade
  (`scancode`→`keycode`, `alt`→`alt_pressed`, etc.) **e com os valores numéricos das
  teclas especiais recalculados** (ex: Enter era `16777221` no Godot 3 e passa a
  `4194309` no Godot 4 — a base numérica das teclas especiais mudou de `2^24` para
  `2^22`; as teclas normais como letras e números não mudam de valor).

## 2. O que precisa do editor Godot 4.7 (não convertido à mão — risco de erro alto demais)

Estas são áreas onde o formato interno dos recursos mudou de forma tão profunda que
edita-las à cegas, sem poder abrir o resultado, arriscava introduzir bugs piores do
que os que resolvia. Todas têm conversão automática no editor:

1. **TileSets** (`assets/TileSets/*.tres`, 5 ficheiros) — o recurso `TileSet` do
   Godot 4 é uma reestruturação completa (sistema de atlas), não uma simples
   renomeação. Abre o projeto no editor → ele vai perguntar se queres converter →
   aceita, e depois confirma visualmente que os tiles de colisão dos 3 níveis ainda
   batem certo (o Godot 4 às vezes desloca a física dos tiles na conversão automática).
2. **Fontes** (9 ficheiros `.tres`, ex.: `Signs-Font.tres`, `Quiz-Styles.tres`) — o
   recurso `DynamicFont` do Godot 3 não existe no Godot 4 (agora é `FontFile`
   referenciado diretamente pelo `Theme`). O conversor do editor trata disto.
3. **`default_env.tres`** — usa `ProceduralSky`, que foi removido no Godot 4
   (substituído por `Sky` + `ProceduralSkyMaterial`). Vais ter de recriar este
   recurso no editor (é rápido: `WorldEnvironment` → novo `Environment` → novo `Sky`).
4. **`PlayerAnimations.tres`** (SpriteFrames do jogador) — verifica que as texturas
   carregam bem; o tipo de recurso `Texture` genérico do Godot 3 tornou-se
   `Texture2D` no Godot 4.
5. Em `project.godot`, a linha `environment/default_environment=...` em
   `[rendering]` pode precisar de ser recriada nas Project Settings do editor (o
   caminho da definição mudou de secção no Godot 4).

## 3. Como validar

1. Abre a pasta do projeto no Godot **4.7**. Aceita a conversão automática quando
   for pedida.
2. Corrige os 5 pontos da secção 2 acima.
3. Corre a cena `levels/StartScreen/StartScreen.tscn` e testa: mover, saltar, wall
   jump, abrir uma prenda de cada um dos 7 tipos de quiz, e navegar num quiz só com
   teclado (setas + Enter) para confirmares que o `QuizKeyboardNav` sobreviveu à
   migração.
4. Se algo não abrir, a mensagem de erro do próprio editor Godot vai dizer
   exatamente a linha/recurso problemático — nessa altura volta a mostrar-me o erro
   e resolvemos esse ponto específico.
