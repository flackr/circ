exports = window.mocks ?= {}

class DOM

  generateHTML: ->
    @html = $ """
  <div id='templates'>

    <div class='server-channels'>
      <div class='server room'>
        <div class='content-item'></div>
      </div>
      <ul class='channels'></ul>
    </div>

    <li class='channel room'>
      <div class='content-item'></div>
    </li>

    <ul class='nicks'></ul>

    <li class='nick'>
      <div class='content-item'></div>
    </li>

    <ul class='messages'></ul>

    <li class='message'>
      <div class='source'></div>
      <div class='content'></div>
    </li>

  </div>

  <!-- main -->
  <div id='main'>
    <div id='rooms-and-nicks' class='no-nicks'>
      <div id='rooms-container'>
        <h1>rooms</h1>
        <div class='rooms'></div>
      </div>
      <div id='nicks-container'>
        <h1>members</h1>
      </div>
    </div>

    <div id='messages-and-input'>
      <div id='notice'>
        <div class='content'></div>
        <button class='close'>X</button>
        <button class='option2 hidden'></button>
        <button class='option1 hidden'></button>
      </div>
      <div id='messages-container'></div>
      <div id='status-and-input'>
        <div id='status' class='content-item'></div>
        <input id='input'></div>
      </div>
    </div>
  </div>
"""

  setUp: ->
    @generateHTML()
    @html.css 'display', 'none'
    $('body').append @html

  tearDown: ->
    @html.remove()

exports.dom = new DOM