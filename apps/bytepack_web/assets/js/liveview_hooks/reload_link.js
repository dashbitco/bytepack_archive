const ReloadLink = {
  mounted () {
    this.el.addEventListener('click', e => (window.location.reload()))
  }
}

export default ReloadLink
