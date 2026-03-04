const path = require('path')
const webpack = require('webpack')

const NODE_MODULES = path.join(__dirname, 'node_modules')

/**
 * Резолвит модуль только из node_modules (для пакетов, совпадающих с встроенными в Node).
 * @param {string} id - имя пакета (например 'assert')
 * @returns {string | false} - абсолютный путь или false, если не найден
 */
function resolveFromNodeModules(id) {
  try {
    return require.resolve(id, { paths: [NODE_MODULES] })
  } catch {
    return false
  }
}

/**
 * Резолвит модуль; при ошибке возвращает false (опциональный полифилл).
 */
function safeResolve(id) {
  try {
    return require.resolve(id)
  } catch {
    return false
  }
}

module.exports = {
  webpack: {
    configure: webpackConfig => {
      // --- Node.js polyfills для webpack 5 (CRA 5) ---
      // Используются: parse-torrent (path, buffer), simple-get (http, https, url, querystring),
      // simple-sha1 (process), bencode (buffer), stream-http (stream, url).
      const fallbacks = {
        path: safeResolve('path-browserify'),
        http: safeResolve('stream-http'),
        https: safeResolve('https-browserify'),
        stream: safeResolve('stream-browserify'),
        buffer: safeResolve('buffer/'),
        querystring: safeResolve('querystring-es3'),
        url: safeResolve('url'),
        process: safeResolve('process/browser.js'),
        assert: resolveFromNodeModules('assert'),
      }

      webpackConfig.resolve.fallback = {
        ...webpackConfig.resolve.fallback,
        ...Object.fromEntries(
          Object.entries(fallbacks).filter(([, v]) => v !== false),
        ),
      }

      // Глобальные инъекции: абсолютные пути для стабильного резолва (избегаем fullySpecified в ESM-контексте)
      const processPath = safeResolve('process/browser.js')
      const bufferPath = safeResolve('buffer/')

      webpackConfig.plugins = webpackConfig.plugins || []
      webpackConfig.plugins.push(
        new webpack.ProvidePlugin({
          Buffer: [bufferPath || 'buffer', 'Buffer'],
          process: processPath || 'process/browser.js',
        }),
      )

      return webpackConfig
    },
  },
}
