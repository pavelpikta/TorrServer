# Зависимости и обновления

## Текущие изменения (устранение предупреждений)

- **react-swipeable-views** заменён на **react-swipeable-views-react-18-fix** — форк с поддержкой React 18, API совместим (один импорт в `SettingsDialog.jsx`).
- Добавлены **resolutions** в `package.json` для фиксации React 18 в дереве зависимостей.
- Добавлены недостающие peer-зависимости: **react-is**, **@types/react** (dev), **eslint-plugin-import**, **eslint-plugin-jsx-a11y**, **eslint-plugin-react**, **eslint-plugin-react-hooks** — чтобы убрать предупреждения от styled-components, MUI и eslint-config-airbnb.

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
| **ESLint 8** | eslint-config-react-app@7 ожидает eslint@^8. При переходе на ESLint 8 возможны изменения в правилах и конфиге (.eslintrc). | Пока оставить ESLint 7; при переходе — проверить `yarn lint` и правила. |
| **react-scripts 6** | Нет в CRA: проект на 5.x. Переход на Vite/другой бандлер — крупный рефакторинг. | Не менять без необходимости. |
| **MUI v6** | Смена импортов и, возможно, темы/стилей. | Оставить MUI v5; при обновлении — следовать гайду миграции MUI. |
| **react-query v4/v5** | Меняется API (useQuery и др.). | Оставить v3; при обновлении — заменить вызовы по changelog. |
| **Полифиллы Node (buffer, process, url…)** | Нужны из-за webpack 5 и пакетов вроде parse-torrent. Удаление возможно только при отказе от этих зависимостей или смене бандлера. | Не удалять; при смене стека — пересмотреть. |

## Проверка после обновлений

После любых изменений в зависимостях:

```bash
yarn install
yarn build
yarn lint
```

При добавлении новых пакетов проверять предупреждения peer dependency и при необходимости дополнять `resolutions` или явные зависимости.
