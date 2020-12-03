/* global BSN */
// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import '../css/app.scss'
import 'bootstrap.native'

import 'phoenix_html'
import { Socket, LongPoll } from 'phoenix'
import LiveSocket from 'phoenix_live_view'
import CopyToClipboard from './liveview_hooks/copy_to_clipboard'
import ReloadLink from './liveview_hooks/reload_link'
import SentryInitializer from './extensions/sentry/initializer'
import LandingPage from './landing_page/landing_page'

// Show progress bar on live navigation and form submits
import topbar from 'topbar'

const userId = document.querySelector("meta[name='x-user-id']").getAttribute('content')
const requestId = document.querySelector("meta[name='x-request-id']").getAttribute('content')
const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')

if (SentryInitializer.environmentName() === 'prod') {
  SentryInitializer.init()
  SentryInitializer.putRequestContext(requestId)
  SentryInitializer.putUserContext(userId)
}

const hooks = {
  ReloadLink: ReloadLink,
  CopyToClipboard: CopyToClipboard
}

const liveSocket = new LiveSocket('/live', Socket, {
  hooks: hooks,
  params: {
    _csrf_token: csrfToken,
    _request_id: requestId
  }
})

topbar.config({
  barThickness: 3,
  barColors: { '1.0': '#727cf5' },
  shadowBlur: 0
})

window.addEventListener('phx:page-loading-start', info => {
  topbar.show()
})

window.addEventListener('phx:page-loading-stop', info => {
  BSN.initCallback(document.body)
  topbar.hide()
})

const socket = liveSocket.socket
const originalOnConnError = socket.onConnError
let fallbackToLongPoll = true

socket.onOpen(() => {
  fallbackToLongPoll = false
})

socket.onConnError = (...args) => {
  if (fallbackToLongPoll) {
    // No longer fallback to longpoll
    fallbackToLongPoll = false
    // close the socket with an error code
    socket.disconnect(null, 3000)
    // fall back to long poll
    socket.transport = LongPoll
    // reopen
    socket.connect()
  } else {
    originalOnConnError.apply(socket, args)
  }
}

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket

if (document.querySelector('#landing-page')) {
  LandingPage.initialize()
}
