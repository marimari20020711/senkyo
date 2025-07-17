// app/javascript/controllers/autocomplete_controller.js
import { Controller } from "@hotwired/stimulus"
import Autocomplete from "stimulus-autocomplete"

export default class extends Controller {
  static values = { url: String }
  connect() { 
    
    console.log("📌 this.element:", this.element);
    console.log("this.urlValue:", this.urlValue)
    console.log("🎯 custom_autocomplete_controller connected!")

    if (!this.urlValue) return
    

    new Autocomplete(this.element, {
      fetch: (text) => {
        if (text.length < 2) return Promise.resolve([])

        console.log(`🔍 入力されたテキスト: ${text}`)

        return fetch(`${this.urlValue}?query=${encodeURIComponent(text)}`)
          .then(response => response.json())
          .then(data => {
            // stimulus-autocomplete は配列の要素を { name: ..., id: ... } 形式で期待している想定
            // JSONが配列の場合そのまま返す
            return data
          })
      },
      onSelect: (item) => {
        console.log("✅ 選択された項目: ", item)
        this.element.value = item.name // 候補選択時にinputへ反映
      }
    })
  }
}
