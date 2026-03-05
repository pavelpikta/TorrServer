# Зависимости и обновления

## MUI v6 (миграция с v5)

- **@mui/material** и **@mui/icons-material** обновлены до **^6.0.0**.
- **@mui/styles** удалён: стили переведены на **styled()** и **sx** из `@mui/material/styles` / `@mui/material`.
- **ListItem с prop `button`** заменён на **ListItemButton** (FilterByCategory, RemoveAll, Sidebar, Search, TorznabSearch, SearchDialog, CustomMaterialUiStyles).
- **DialogHeader**: вместо makeStyles используется **sx**.
- **VideoPlayer**: вместо makeStyles/withStyles — **styled()** и **sx**; для Dialog используется **slotProps.paper.sx**.
- **Grid** (SliderInput): оставлен старый API (`item xs`), в v6 он по-прежнему поддерживается; при желании можно перейти на Grid2 и `size={{ xs: ... }}`.

## Текущие изменения (устранение предупреждений)

- **react-swipeable-views** удалён. Вместо него для свайпа между вкладками в диалоге настроек используется **react-swipeable** (FormidableLabs): хук `useSwipeable` с `onSwipedLeft` / `onSwipedRight`, поддержка React 18/19, без устаревших зависимостей. Переключение вкладок — по клику (MUI Tabs) и по свайпу (react-swipeable на контенте). Учтён RTL (`direction`): в RTL-режиме направление свайпа инвертируется.
- Добавлены **resolutions** в `package.json` для фиксации React 18 в дереве зависимостей.
- Добавлены недостающие peer-зависимости: **react-is**, **@types/react** (dev), **eslint-plugin-import**, **eslint-plugin-jsx-a11y**, **eslint-plugin-react**, **eslint-plugin-react-hooks** — чтобы убрать предупреждения от styled-components, MUI и eslint-config-airbnb.

### Обновление ESLint и peer-зависимостей (2025)

- **ESLint** обновлён до **^8.57.0** (eslint-config-react-app@7 ожидает eslint@^8).
- **eslint-config-airbnb** обновлён до **^19.0.4** (совместимость с ESLint 8).
- **eslint-config-prettier** → **^9.1.0**, **eslint-plugin-prettier** → **^5.1.0**.
- **Prettier** обновлён до **^3.4.0** (требуется для eslint-plugin-prettier@5, peer `prettier@>=3.0.0`). Конфиг в `.eslintrc` совместим с Prettier 3.
- Добавлены явные peer-зависимости для устранения предупреждений:
  - **postcss@^8.4.0** — для @craco/craco → autoprefixer;
  - **typescript@^5.0.0** — для react-scripts (fork-ts-checker-webpack-plugin, tsutils), @craco/craco (cosmiconfig-typescript-loader, ts-node);
  - **@types/node@^20.0.0** — для cosmiconfig-typescript-loader и ts-node;
  - **@babel/plugin-syntax-flow@^7.14.5** — для eslint-config-react-app → eslint-plugin-flowtype.

## Предупреждение `url.parse()` (Node.js)

При запуске `yarn` может выводиться:

```
DeprecationWarning: `url.parse()` behavior is not standardized...
```

Источник — код внутри зависимостей (в т.ч. полифилл `url`), который вызывает устаревший Node.js API. На сборку и работу приложения это не влияет. При желании можно подавить предупреждение:

```bash
export NODE_OPTIONS="${NODE_OPTIONS:-} --no-deprecation"
yarn install
```

Или в `package.json` в скриптах: `"install": "NODE_OPTIONS=--no-deprecation node ..."` не требуется — обычно оставляют как есть.

## Upstream / downstream и возможные обновления

| Пакет / тема | Влияние на код | Рекомендация |
|--------------|----------------|---------------|
| **ESLint 8** | eslint-config-react-app@7 ожидает eslint@^8. | Обновлено: ESLint 8.57, eslint-config-airbnb 19, eslint-config-prettier 9, eslint-plugin-prettier 5. После `yarn install` проверить `yarn lint`. |
| **react-scripts 6** | Нет в CRA: проект на 5.x. Переход на Vite/другой бандлер — крупный рефакторинг. | Не менять без необходимости. |
| **MUI v6** | Смена импортов и, возможно, темы/стилей. | Оставить MUI v5; при обновлении — следовать гайду миграции MUI. |
| **react-query v4/v5** | Меняется API (useQuery и др.). | Оставить v3; при обновлении — заменить вызовы по changelog. |
| **Полифиллы Node (buffer, process, url…)** | Нужны из-за webpack 5 и пакетов вроде parse-torrent. Удаление возможно только при отказе от этих зависимостей или смене бандлера. | Не удалять; при смене стека — пересмотреть. |
| **babel-minify / babel-preset-minify** | Используются в `.babelrc` (preset `minify` в `env.production`). CRA уже минифицирует сборку через Terser — возможное дублирование. | Оставлено для совместимости; при желании можно убрать preset и проверить размер бандла. |

## Проверка после обновлений

После любых изменений в зависимостях:

```bash
yarn install
yarn build
yarn lint
```

При добавлении новых пакетов проверять предупреждения peer dependency и при необходимости дополнять `resolutions` или явные зависимости.
