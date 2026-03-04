module.exports = {
  webpack: {
    configure: webpackConfig => {
      webpackConfig.resolve.fallback = {
        ...webpackConfig.resolve.fallback,
        path: require.resolve('path-browserify'),
        http: require.resolve('stream-http'),
        https: require.resolve('https-browserify'),
        stream: require.resolve('stream-browserify'),
        buffer: require.resolve('buffer/'),
        querystring: require.resolve('querystring-es3'),
        url: require.resolve('url'),
      }
      return webpackConfig
    },
  },
}
