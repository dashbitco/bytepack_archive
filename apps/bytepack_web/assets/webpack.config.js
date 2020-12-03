const path = require('path')
const glob = require('glob')
const webpack = require('webpack')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const TerserPlugin = require('terser-webpack-plugin')
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin')
const CopyWebpackPlugin = require('copy-webpack-plugin')

const devMode = process.env.NODE_ENV !== 'production'

module.exports = (env, options) => ({
  optimization: {
    minimize: true,
    minimizer: [
      new TerserPlugin({ cache: true, parallel: true, sourceMap: devMode }),
      new OptimizeCSSAssetsPlugin({})
    ]
  },
  entry: {
    app: glob.sync('./vendor/**/*.js').concat(['./js/app.js'])
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, '../priv/static/js'),
    publicPath: '/js/'
  },
  devtool: devMode ? 'source-map' : undefined,
  module: {
    rules: [
      {
        test: /bootstrap\.native/,
        use: {
          loader: 'bootstrap.native-loader',
          options: {
            only: ['collapse', 'dropdown', 'tooltip', 'modal']
          }
        }
      },
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.scss$/,
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: 'css-loader'
          }, {
            loader: 'postcss-loader',
            options: {
              plugins: function () {
                return [
                  require('precss'),
                  require('autoprefixer')
                ]
              }
            }
          }, {
            loader: 'sass-loader'
          }
        ]
      },
      {
        test: /\.woff(2)?$/,
        use: [
          {
            loader: 'url-loader',
            options: {
              limit: 100000
            }
          }
        ]
      },
      {
        test: /\.(svg|png|jpg)$/,
        loader: 'url-loader'
      }
    ]
  },
  plugins: [
    new MiniCssExtractPlugin({ filename: '../css/app.css' }),
    new CopyWebpackPlugin({ patterns: [{ from: 'static/', to: '../' }] }),
    // this will cause `process.env.NODE_ENV`/`process.env.SOURCE_VERSION` to be replaced with the current NODE_ENV/NODE_VERSION at compile time
    new webpack.EnvironmentPlugin(['NODE_ENV', 'SOURCE_VERSION'])
  ],
  resolve: {
    alias: {
      assets: path.join(__dirname, '../assets')
    }
  }
})
