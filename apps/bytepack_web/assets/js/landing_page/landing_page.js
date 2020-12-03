import { explanationDevelopAnimation, explanationInstallAnimation, heroImageAnimation } from './animations'
import ScrollTransitions from './scroll_transitions'

const addClickScrollLink = function (element) {
  element.addEventListener('click', (e) => {
    e.preventDefault()
    const target = document.querySelector(element.getAttribute('href'))
    target.scrollIntoView({ behavior: 'smooth' })
  })
}

const runAnimations = function () {
  heroImageAnimation()
  explanationDevelopAnimation()
  explanationInstallAnimation()
}

const setupClickScrollLinks = function () {
  const links = document.querySelectorAll('[data-click-scroll]')

  links.forEach(function (element) {
    addClickScrollLink(element)
  })
}

const LandingPage = {
  initialize () {
    setupClickScrollLinks()
    runAnimations()
    ScrollTransitions.initialize()
  }
}

export default LandingPage
