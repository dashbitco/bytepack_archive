const textToClipboard = (textarea) => {
  if (!navigator.clipboard) {
    // Deprecated clipboard API
    textarea.value = textarea.value.trim()
    textarea.select()
    textarea.setSelectionRange(0, 99999)
    document.execCommand('copy')
  } else {
    // Modern Clipboard API
    const text = textarea.value.trim()
    navigator.clipboard.writeText(text)
  }
}

const CopyToClipboard = {
  mounted () {
    this.el.querySelector('.code-snippet__button').addEventListener('click', e => {
      const textarea = this.el.querySelector('.code-snippet__textarea')
      textToClipboard(textarea)
      const copyIndicator = this.el.querySelector('.code-snippet__copied')
      copyIndicator.setAttribute('data-show-message', 'false')
      // eslint-disable-next-line
      void copyIndicator.offsetWidth // Resets the animation to ensure it will be played again
      copyIndicator.setAttribute('data-show-message', 'true')
    })
  }
}

export default CopyToClipboard
