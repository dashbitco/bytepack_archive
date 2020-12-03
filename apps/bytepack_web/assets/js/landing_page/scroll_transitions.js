import anime from 'animejs/lib/anime.es.js'

const appearAnimation = () => {
  const timeline = anime.timeline({
    loop: false
  })

  return timeline
    .add({
      targets: '.why-bytepack__image-bytepack-tile',
      easing: 'easeOutBack',
      keyframes: [
        {
          translateY: [50, 0],
          opacity: [0, 1],
          scale: [0.7, 1]
        }
      ],
      duration: 800,
      delay: 400
    })
    .add({
      targets: '.why-bytepack__image-bytepack-tile image',
      easing: 'easeOutBack',
      keyframes: [
        {
          opacity: [0, 1],
          scale: [0.7, 1]
        }
      ],
      duration: 500
    })
}

const intersectionCallback = (entries, observer) => {
  entries.forEach(entry => {
    if (entry.intersectionRatio > 0) {
      appearAnimation()
      observer.unobserve(entry.target)
    }
  })
}

const ScrollTransitions = {
  initialize () {
    const options = { root: null, rootMargin: '0px', threshold: 0.9 }
    const observer = new IntersectionObserver(intersectionCallback, options)

    const target = document.querySelector('.why-bytepack__image')

    if (target) {
      observer.observe(target)
    }
  }
}

export default ScrollTransitions
