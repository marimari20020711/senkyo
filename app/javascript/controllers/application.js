import { Application } from "@hotwired/stimulus"

const application = Application.start()
application.debug = true
window.Stimulus   = application

export { application }


// import { Application } from '@hotwired/stimulus'
// import { Autocomplete } from 'stimulus-autocomplete'

// const application = Application.start()
// application.register('autocomplete', Autocomplete)