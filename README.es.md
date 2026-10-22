# Horizon Mods Nautas

[ENGLISH](README.md) | **ESPAÑOL**

Mantenido por Criptonautas. Sin afiliación ni respaldo de Discourse (Civilized Discourse Construction Kit, Inc.).

Componente de tema para **comunidad.criptonautas.co**. Hijo del tema
[Horizon](https://meta.discourse.org/t/horizon-theme/360486): todo lo que hay aquí
sobrescribe o extiende Horizon, nada funciona por sí solo.

## Qué hace

Los resúmenes de IA en las tarjetas de Horizon viven en el componente independiente
[Horizon AI Gists](https://github.com/somos-criptonautas/discourse-horizon-ai-gists);
instálalo junto a este.

### Estilos (`scss/`, cargados desde `common/common.scss`)

| Archivo | Alcance |
|---|---|
| `main.scss` | Escala de fuentes base, sobrescrituras `--d-*`, diseño de cuadrícula/barra lateral, reinicio de colores de categoría, listas de temas, categorías de documentación, búsqueda, ranking, banners, tarjetas de reto y su marca de obtenido, página 404, el embed del blog, correcciones del rediseño del editor |
| `fonts.scss` | Tipografía de marca: Inter Tight desde `assets/` para titulares (el texto sigue el ajuste `base_font`, Lato), titulares en 800 con interletra -0,02em |
| `header.scss` | Diseño de la cabecera con navegación personalizada, visibilidad de logo/avatar en móvil |
| `topic.scss` | Anchos máximos del tema y ancho del cuerpo |
| `_topic-list.scss` | Densidad de la lista de temas, marcador de última visita en docs, etiquetas ocultas en listas |
| `categories-view.scss` | Cajas de categorías y cabeceras de título |
| `nav-scroller.scss` | Franja de navegación de temas desplazable y sus flechas; mantiene los ítems glosario/wiki fuera de las listas de categorías y etiquetas |
| `mermaid.scss` | Los diagramas Mermaid se ajustan al ancho del post en lugar de su tamaño intrínseco |
| `ai-bot.scss` | Pulgar arriba/abajo en lugar de me gusta/reportar dentro de las conversaciones con el bot de IA, sin selector de reacciones ni contadores |
| `mobile-stuff.scss` | Tamaños de fuente adaptables, fondos de la barra lateral, categorías de docs en móvil |
| `user.scss`, `new-user.scss` | Páginas de perfil y de mensajes, y el orden del panel lateral de usuario del núcleo |
| `custom-user-menu.scss`, `d-combo-button.scss`, `groups.scss` | Menú de usuario, desplegables, páginas de grupos |
| `ghost-cards.scss` | Tarjetas de marcador (bookmark) de Ghost dentro de temas de blog incrustados |
| `form-templates.scss` | Títulos de checklist y checklist conmutado por desplegable en plantillas de formulario |
| `avatars.scss` | Anillo fino (1px `--primary-low`) en todos los avatares, como los bordes de las tarjetas de Horizon |
| `compatibility.scss` | Sobrescrituras que deben aplicarse después de todo lo demás |

Los puntos de corte usan la librería de viewport del núcleo (`@include viewport.from/until(sm|md|lg)`),
importada una vez en `common/common.scss`. El `@media` directo solo se mantiene para anchos fuera de la cuadrícula
(400px, 470px, 925px, 1200px, 1400px) y `prefers-reduced-motion`.

Ambas funciones de Ghost (las tarjetas de arriba y los avisos de abajo) necesitan que las clases `kg-*` se añadan al ajuste del sitio
`allowed embed classnames` (por defecto es `emoji`: añade, no reemplaces). Discourse elimina las
clases no listadas al extraer el post del blog, y lo hace en el momento de la importación, así que el ajuste y cualquier
cambio en él solo afectan a los temas importados después:

```
kg-card kg-bookmark-card kg-bookmark-container kg-bookmark-content kg-bookmark-title kg-bookmark-description kg-bookmark-metadata kg-bookmark-icon kg-bookmark-author kg-bookmark-publisher kg-bookmark-thumbnail kg-callout-card kg-callout-emoji kg-callout-text kg-callout-card-grey kg-callout-card-white kg-callout-card-blue kg-callout-card-green kg-callout-card-yellow kg-callout-card-red kg-callout-card-pink kg-callout-card-purple kg-callout-card-accent
```

### Plantillas de formulario (`scss/form-templates.scss`)

Agrega dos cosas que las plantillas de formulario no pueden hacer solas: un título sobre
un grupo de casillas, y un checklist que cambia según un desplegable — el campo `metodo`
elige las casillas `inversion-*` o las `trading-*`, y el otro grupo desaparece. Solo CSS,
sin JS: todos los campos son hermanos dentro de `.form-template-form__wrapper` y los
desplegables siguen siendo `<select>` nativos, así que `:has()` + `option:checked` lee la
elección en vivo. El `id` del YAML de un campo llega como el `name` del input — no existe
un atributo `data-field-id`, `name` es el único punto de anclaje, por lo que los
selectores quedan atados a los ids de las plantillas de este foro.

Dos reglas al editarlo: nunca `required: true` en un campo que este CSS pueda ocultar (un
campo oculto e inválido hace que el editor se niegue a publicar, sin mensaje y sin nada
que enfocar), y el cuerpo del post se arma con `FormData`, que ignora el CSS — una casilla
marcada y después oculta igual aparece en el post.

### Comportamiento (`javascripts/`)

- **`init.gjs`**
  - Carga todas las páginas de una categoría de documentación (`.topic-list.doc-simple-mode`) y la ordena
    de la A a la Z usando el `<html lang>` de la página. Reordena tras cualquier adición posterior (ver
    *Límites conocidos*).
  - Abre la barra lateral de docs una vez por categoría y sesión en móvil.
  - Reemplaza el icono de discobot, oculta los botones de pertenencia a grupos "cerrados", desactiva el
    desplegable de navegación en móvil y añade la clase de body `leaderboard-page`.
- **`block-sidebar.gjs`**: restringe los enlaces de la barra lateral por grupo mediante el ajuste `blocked_sections`:
  atenúa u oculta el enlace y explica el requisito en un modal con un llamado a la acción.
  Los textos viven en `locales/*.yml`, identificados por la `key` de cada nivel.
- **`checklist-strike.js`**: tacha la etiqueta de un `[x]` marcado en línea (plugin de listas de verificación del núcleo)
  envolviéndola en el propio `span.chcklst-stroked` del núcleo. El CSS solo no puede: la etiqueta
  es un nodo de texto suelto y las líneas van separadas por `<br>` dentro de un mismo párrafo.
- **`nav-scroller.js`**: envuelve `#navigation-bar` en un scroller horizontal con flechas
  en los bordes (navegación de temas estilo YouTube), integrado desde el componente independiente "youtube style menu
  scrollable" para que ambos dejen de pelear por `.navigation-container` y por el
  transformer `navigation-bar-dropdown-mode`. **Desinstala ese componente** después de
  desplegar este. Estilos en `scss/nav-scroller.scss`.
- **`profile-drafts-link.js`**: copia la entrada "borradores" desde la sección de
  actividad a la de perfil del panel lateral de usuario, que es lo primero que se ve. Es
  una copia, no un traslado, para no tocar la lista que renderiza Glimmer; el original se
  oculta en `scss/user.scss` y la copia se rehace en cada cambio de página para que el
  contador de borradores no quede viejo.
- **`category-back.js`**: antepone un enlace "volver" en `.list-controls
  .navigation-container` en las páginas de categoría (categoría padre, o `/categories` desde una
  de primer nivel), de modo que viaja en la barra fija de Horizon antes de las migas de pan. El destino
  sale de la ruta de la URL, no del modelo de la ruta; no existe outlet dentro de esa barra, así que
  la inserción es en el DOM al cambiar de página y se omite cuando la barra no está.
- **`ai-thumbs-down.gjs`**: en las conversaciones con bots de IA, reemplaza el botón de
  denuncia por un pulgar abajo que alterna la reacción `-1` (discourse-reactions) en vez
  de abrir el modal de denuncia. `-1` debe estar en `discourse_reactions_enabled_reactions`; el componente lo oculta del selector.
- **`bot-display-name.js`**: muestra las cuentas de bot `anonist_*` bajo una sola etiqueta
  (`anonist`) y oculta sus botones `.compose-pm`. Solo el texto visible: los href, las atribuciones
  de citas, las menciones en markdown, la búsqueda y los correos conservan el nombre de usuario real. Cubre
  enlaces más los spans planos `.username` / `.name` que usa el núcleo en búsqueda, menús,
  elementos a revisar, el mapa de MP y perfiles; se ejecuta al cambiar de página y en el frame posterior a un
  clic, ya que las tarjetas y ventanas emergentes se abren sin cambio de ruta. Los bots nuevos necesitan una línea en
  `BOT_LABELS`.
- **`translated-texts.gjs`**: añade la nota traducida bajo el podio del ranking.
- **`category-intro.gjs`**: sobrescribe los títulos y descripciones de los banners de categoría
  renderizados desde `after_header.html` con los textos adecuados al idioma de
  `locales/*.yml` mediante `i18n(themePrefix(…))`.
- **`connectors/custom-homepage`**: outlet de reserva para la página de inicio personalizada.
- **`ghost-callouts.js`**: convierte las tarjetas de aviso (callout) de Ghost de los temas
  incrustados en citas `[!tipo]`, para que el componente Quote Callouts las renderice igual
  que cualquier otro aviso del foro. Actúa en el getter `cooked`, antes de cualquier
  decorador de contenido, así que no depende de qué componente se cargue primero. La
  correspondencia color → tipo está al principio del archivo: un color sin asignar cae en
  `note`, y un tipo que este foro ya no defina cae en el `callout_fallback_type` del propio
  Quote Callouts. El emoji de Ghost se descarta en favor del icono del aviso.
- **`embed-comments.gjs`**: cuando el foro funciona como iframe de comentarios del blog
  (`body.embed-mode`), deja en el menú del post solo responder, denunciar y (con sesión
  iniciada) me gusta. Avisos, saltos de tiempo, botones del pie y temas sugeridos se ocultan
  en `main.scss`, y el editor de respuesta se abre a todo el ancho y más alto.
- **`sidebar-chat-toggle.gjs`**: un botón de chat con indicador de no leídos junto al
  selector claro/oscuro en el pie de la barra lateral, en lugar del botón que cambia al
  panel de chat. Abre el cajón o la página completa según la preferencia del usuario; una
  segunda pulsación lo cierra.
- **`user-menu-karma.js`**: muestra el karma mensual del usuario (de `/leaderboard`,
  periodo mensual) como chip en el menú de usuario. Una petición por carga de página.

### Marcado y recursos

- `common/after_header.html`: banners de categoría personalizados (ghettos, retos, karma, costumbres).
- `common/header.html`: analítica Plausible.
- `common/head_tag.html`: dentro del iframe de comentarios del blog, sigue el tema
  claro/oscuro del blog e informa la altura del hilo. La otra mitad está en
  `assets/js/discourse-embed.js` de ghost-headline-theme-nautas.
- `common/color_definitions.scss`: `--cn-btn`, el violeta de los botones primarios: el tertiary de la paleta en modo claro, `#8E4CFF` en oscuro (4,54:1 con texto blanco), aplicado en `main.scss`.
- `about.json`: lista permitida de iconos Phosphor duotone, modificadores `custom_homepage` y
  `serialize_topic_is_hot`, assets de la fuente Inter Tight y las paletas Claro/Oscuro del
  kit de marca. Discourse ignora `color_schemes` en el `about.json` de un componente
  (`RemoteTheme` solo las importa en temas completos), así que esas paletas son una copia de
  referencia: créalas una vez en Admin → Apariencia → Paletas de colores.
- `assets/`: fuente variable Inter Tight (normal e itálica) con su licencia OFL.

## Límites conocidos

- **`blocked_sections` es UX de navegación, no autorización.** Atenúa u oculta los enlaces de la barra lateral
  e intercepta los clics en ellos, todo del lado del cliente. Las URLs directas, los enlaces de
  cualquier otro lugar y los endpoints JSON (`/c/<id>/latest.json`) lo eluden por completo, y
  no concede ningún acceso que pudiera filtrar. El control de acceso real para las categorías configuradas tiene
  que venir del servidor: los grupos de seguridad de categoría de Discourse o el plugin
  `discourse-category-lockdown`. Verifica una categoría restringida como no miembro
  pidiendo `/c/<id>/latest.json` directamente.
- **El estado de bloqueo se lee una sola vez al arrancar.** `block-sidebar.gjs` calcula los niveles bloqueados
  cuando se ejecuta el inicializador, así que un visitante que inicia sesión sin recargar la página conserva la
  restricción anónima hasta que refresque.
- **Selectores que dependen del marcado del núcleo/Horizon.** No existe outlet para estos, así que una
  actualización de Discourse u Horizon puede desactivarlos en silencio: la cadena del interruptor de la barra lateral y
  la coincidencia del texto de botón `"closed"`/`"cerrado"` (`init.gjs`), el reordenamiento de la
  lista de temas de docs (`init.gjs`) y la línea de karma del menú de usuario (`user-menu-karma.js`). Cada uno
  degrada a un no-op, así que prueba los cuatro tras cada actualización.

- **El orden A–Z de docs es del lado del cliente.** Discourse no puede ordenar una lista de temas por título en el servidor
  (`TopicQuery::SORTABLE_MAPPING` no tiene `title`), así que `init.gjs` agota la lista
  paginada (`loadMore()`, limitado por `MAX_DOC_PAGES`) y luego ordena. Dos consecuencias: entrar
  a una categoría de docs cuesta una petición por cada 30 temas, y el bucle lee
  el controlador de descubrimiento más reciente (`controller:discovery/latest`; el antiguo comodín `controller:discovery/topics` está obsoleto), una API semiprivada. Si se rompe o se alcanza el límite,
  degrada a ordenar las filas ya cargadas. Elimina el bucle si el núcleo llega a ofrecer
  ordenación por título en el servidor.
- `compatibility.scss` y `main.scss` establecen ambos `max-width` en
  `div[class*="category-title-header"]`; `compatibility.scss` gana por `!important`.

## Desarrollo

Las ediciones son locales. Despliega mediante **Admin → Apariencia → Temas → Instalar → Desde tu dispositivo**,
o importa desde el remoto git.

## Licencia

MIT. Consulta [LICENSE](LICENSE).

Texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
