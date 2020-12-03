import * as Sentry from '@sentry/browser'

const dsn = 'https://c4b92d7a4a6a482ba7aee186b1dbf888@o404993.ingest.sentry.io/5278843'

const SentryInitializer = {
  init () {
    const initParams = {
      dsn: dsn,
      environment: this.environmentName()
    }

    const sourceVersion = this.sourceVersion()

    if (sourceVersion) {
      initParams.release = sourceVersion
    }

    Sentry.init(initParams)
  },

  putUserContext (userId) {
    if (userId) {
      Sentry.setUser({
        id: userId
      })
    }
  },

  putRequestContext (requestId) {
    Sentry.setTag('request_id', requestId)
  },

  environmentName () {
    return process.env.NODE_ENV === 'production' ? 'prod' : 'dev'
  },

  sourceVersion () {
    return process.env.SOURCE_VERSION
  }
}

export default SentryInitializer
