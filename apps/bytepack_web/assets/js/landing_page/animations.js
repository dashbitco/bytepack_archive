import anime from 'animejs/lib/anime.es.js'

const explanationDevelopAnimation = function () {
  const timeline = anime.timeline({
    loop: true
  })

  return timeline
  // Show languages

    .add({
      targets: '.explanation-image1__elixir',
      easing: 'easeOutBack',
      keyframes: [
        {
          translateY: [400, 140],
          translateX: [450, 190],
          opacity: [0, 1],
          scale: [0, 1]
        }
      ],
      duration: 700
    })
    .add({
      targets: '.explanation-image1__ruby',
      easing: 'easeOutBack',
      keyframes: [
        {
          translateY: [400, 100],
          translateX: [450, 390],
          opacity: [0, 1],
          scale: [0, 1]
        }
      ],
      duration: 700
    }, '-=500')
    .add({
      targets: '.explanation-image1__js',
      easing: 'easeOutBack',
      keyframes: [
        {
          translateY: [400, 320],
          translateX: [450, 130],
          opacity: [0, 1],
          scale: [0, 1]
        }
      ],
      duration: 700
    }, '-=400')

  // Move programmer

    .add({
      targets: '.explanation-image1__programmer',
      easing: 'easeOutExpo',
      keyframes: [
        { translateY: [-180, -180], scale: [0.70, 0.35], translateX: [-50, -10] }
      ],
      duration: 1400
    }, '+=400')

  // Show browser window

    .add({
      targets: '.explanation-image1__bytepack-window',
      easing: 'easeOutExpo',
      keyframes: [
        {
          translateX: [50, 50],
          rotate: [10, 0],
          translateY: [-60, 50],
          scaleY: [0, 1],
          scaleX: [0.5, 1]
        }
      ],
      duration: 800
    }, '-=500')

  // Show page boxes

    .add({
      targets: '.explanation-image1__package-box',
      easing: 'easeOutBack',
      keyframes: [
        {
          translateY: [-50, 0],
          opacity: [0, 1]
        }
      ],
      delay: anime.stagger(100),
      duration: 300
    })

  // Move languages to final positions

    .add({
      targets: '.explanation-image1__js',
      easing: 'easeOutSine',
      translateY: 275,
      translateX: 206,
      scale: 0.75,
      duration: 300
    })
    .add({
      targets: '.explanation-image1__elixir',
      easing: 'easeOutSine',
      keyframes: [
        {
          translateY: [130, 271],
          translateX: [225, 386],
          scale: [1, 0.75]
        }
      ],
      duration: 300
    }, '-=250')
    .add({
      targets: '.explanation-image1__ruby',
      easing: 'easeOutSine',
      translateY: 279,
      translateX: 580,
      scale: 0.7,
      duration: 300
    }, '-=400')
    .add({
      targets: '.explanation-image1__bytepack-logo',
      easing: 'easeOutSine',
      opacity: [0, 0.65],
      translateX: [-200, 0],
      duration: 300
    }, '-=200')
    .add({
      targets: '.explanation-image1__text-placeholder',
      easing: 'easeOutSine',
      opacity: [0, 0.75],
      delay: anime.stagger(30),
      duration: 200
    }, '-=100')

  // Rewind languages back

    .add({
      targets: '.explanation-image1__ruby',
      easing: 'easeInBack',
      duration: 250,
      delay: 4000,
      opacity: 0
    })
    .add({
      targets: '.explanation-image1__elixir',
      easing: 'easeInBack',
      opacity: 0,
      duration: 250
    }, '-=70')
    .add({
      targets: '#explanation-step1 .explanation-image1__js',
      easing: 'easeInBack',
      opacity: 0,
      duration: 250
    }, '-=70')

  // Hide browser window

    .add({
      targets: '.explanation-image1__bytepack-window',
      easing: 'easeInBack',
      keyframes: [
        {
          translateX: [50, 50],
          rotate: [0, 4],
          translateY: [50, 20],
          scaleY: [1, 0.85],
          scaleX: [1, 0.85],
          opacity: [1, 0]
        }
      ],
      duration: 500
    })

  // Bring programmer back

    .add({
      targets: '.explanation-image1__programmer',
      easing: 'easeOutSine',
      scale: 0.7,
      translateY: -180,
      translateX: -50,
      duration: 500
    })
}

const explanationInstallAnimation = function () {
  const timeline = anime.timeline({
    loop: true
  })

  return timeline

  // Show first language

    .add({
      targets: '.explanation-image2__customer--customer1',
      easing: 'easeOutBack',
      opacity: [0, 1],
      scale: [0.5, 0.65],
      translateY: [50, 0],
      translateX: [-150, -310],
      rotate: [0, -5],
      duration: 600
    })

  // Show npm text

    .add({
      targets: '.explanation-image2__console-text-npm tspan',
      opacity: [0, 1],
      'fill-opacity': [0, 1],
      duration: 100,
      delay: anime.stagger(100)
    })
    .add({
      targets: '.explanation-image2__console-text-npm-finished > tspan',
      easing: 'easeOutBack',
      opacity: [0, 1],
      'fill-opacity': [0, 1],
      duration: 100,
      delay: anime.stagger(200)
    })

  // Remove npm text

    .add({
      targets: '.explanation-image2__group-npm',
      easing: 'easeInBack',
      opacity: 0,
      delay: 800,
      duration: 300,
      translateY: [0, -50]
    })

  // Remove first language

    .add({
      targets: '.explanation-image2__customer--customer1',
      easing: 'easeOutBack',
      opacity: 0,
      scale: 0.5,
      translateY: '+=50',
      duration: 500
    })

  // Show second language

    .add({
      targets: '.explanation-image2__customer--customer2',
      easing: 'easeOutBack',
      opacity: [0, 1],
      scale: [0.5, 0.6],
      translateY: [0, -50],
      translateX: [190, 265],
      duration: 500,
      delay: 400
    }, '-=200')

  // Show hex text

    .add({
      targets: '.explanation-image2__console-text-hex tspan',
      opacity: [0, 1],
      'fill-opacity': [0, 1],
      duration: 100,
      delay: anime.stagger(100)
    })
    .add({
      targets: '.explanation-image2__console-text-hex-finished > tspan',
      opacity: [0, 1],
      'fill-opacity': [0, 1],
      duration: 100,
      delay: anime.stagger(200)
    })

  // Remove hex text

    .add({
      targets: '.explanation-image2__group-hex',
      easing: 'easeInBack',
      opacity: 0,
      delay: 800,
      duration: 300,
      translateY: [0, -50]
    })

  // Remove second language

    .add({
      targets: '.explanation-image2__customer--customer2',
      easing: 'easeOutBack',
      opacity: 0,
      scale: 0.5,
      translateY: '+=50',
      duration: 500
    })

  // Show third language

    .add({
      targets: '.explanation-image2__customer--customer3',
      easing: 'easeOutBack',
      opacity: [0, 1],
      scale: [0.5, 0.65],
      translateY: [50, 0],
      translateX: [-80, -120],
      duration: 500
    })

  // Show bundler text

    .add({
      targets: '.explanation-image2__console-text-bundler tspan',
      opacity: [0, 1],
      'fill-opacity': [0, 1],
      duration: 100,
      delay: anime.stagger(100)
    })
    .add({
      targets: '.explanation-image2__console-text-bundler-finished > tspan',
      opacity: [0, 1],
      'fill-opacity': [0, 1],
      duration: 100,
      delay: anime.stagger(200)
    })

  // Hide bundler text

    .add({
      targets: '.explanation-image2__group-bundler',
      easing: 'easeInBack',
      opacity: 0,
      delay: 800,
      duration: 300,
      translateY: [0, -50]
    })

  // Remove third customer

    .add({
      targets: '.explanation-image2__customer--customer3',
      easing: 'easeOutBack',
      opacity: 0,
      scale: 0.5,
      translateY: '+=50',
      duration: 500
    })
}

function heroImageAnimation () {
  anime({
    targets: '.hero-image__right-content-box',
    easing: 'easeInOutSine',
    loop: true,
    direction: 'alternate',
    translateY: '+=15',
    duration: 2400,
    delay: anime.random(300, 1000)
  })

  anime({
    targets: '.hero-image__left-content-box',
    easing: 'easeInOutSine',
    loop: true,
    direction: 'alternate',
    translateY: '+=15',
    duration: anime.random(2600, 3200),
    delay: anime.random(3000, 5000)
  })
}

export { explanationDevelopAnimation, explanationInstallAnimation, heroImageAnimation }
