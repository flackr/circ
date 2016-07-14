'use strict';

window.client = null;
// TODO(flackr): Support multiple connected hosts.
window.hostId = 0;
window.serverName = 'irc';

function transitionToMainUI() {
  document.querySelector('.settings').classList.add('settings_hidden');
  document.querySelector('.main_container').querySelector('.main_input_text').focus();
  new RoomList(document.querySelector('.rooms'));
}

class SideNav {
constructor () {
    this.showButtonEl = document.querySelector('.js-menu-show');
    this.hideButtonEl = document.querySelector('.js-menu-hide');
    this.sideNavEl = document.querySelector('.js-side-nav');
    this.sideNavContainerEl = document.querySelector('.js-side-nav-container');
    // Control whether the container's children can be focused
    // Set initial state to inert since the drawer is offscreen
    this.detabinator = new Detabinator(this.sideNavContainerEl);
    this.detabinator.inert = true;

    this.showSideNav = this.showSideNav.bind(this);
    this.hideSideNav = this.hideSideNav.bind(this);
    this.blockClicks = this.blockClicks.bind(this);
    this.onTouchStart = this.onTouchStart.bind(this);
    this.onTouchMove = this.onTouchMove.bind(this);
    this.onTouchEnd = this.onTouchEnd.bind(this);
    this.onTransitionEnd = this.onTransitionEnd.bind(this);
    this.update = this.update.bind(this);

    this.startX = 0;
    this.currentX = 0;
    this.touchingSideNav = false;

    this.supportsPassive = undefined;
    this.addEventListeners();
  }

  // apply passive event listening if it's supported
  applyPassive () {
    if (this.supportsPassive !== undefined) {
      return this.supportsPassive ? {passive: true} : false;
    }
    // feature detect
    let isSupported = false;
    try {
      document.addEventListener('test', null, {get passive () {c 
        isSupported = true;
      }});
    } catch (e) { }
    this.supportsPassive = isSupported;
    return this.applyPassive();
  }

  addEventListeners () {
    this.showButtonEl.addEventListener('click', this.showSideNav);
    this.hideButtonEl.addEventListener('click', this.hideSideNav);
    this.sideNavEl.addEventListener('click', this.hideSideNav);
    this.sideNavContainerEl.addEventListener('click', this.blockClicks);

    this.sideNavEl.addEventListener('touchstart', this.onTouchStart, this.applyPassive());
    this.sideNavEl.addEventListener('touchmove', this.onTouchMove, this.applyPassive());
    this.sideNavEl.addEventListener('touchend', this.onTouchEnd);
  }

  onTouchStart (evt) {
    if (!this.sideNavEl.classList.contains('side-nav--visible'))
      return;

    this.startX = evt.touches[0].pageX;
    this.currentX = this.startX;

    this.touchingSideNav = true;
    requestAnimationFrame(this.update);
  }

  onTouchMove (evt) {
    if (!this.touchingSideNav)
      return;

    this.currentX = evt.touches[0].pageX;
    const translateX = Math.min(0, this.currentX - this.startX);

    if (translateX < 0) {
      evt.preventDefault();
    }
  }

  onTouchEnd (evt) {
    if (!this.touchingSideNav)
      return;

    this.touchingSideNav = false;

    const translateX = Math.min(0, this.currentX - this.startX);
    this.sideNavContainerEl.style.transform = '';

    if (translateX < 0) {
      this.hideSideNav();
    }
  }

  update () {
    if (!this.touchingSideNav)
      return;

    requestAnimationFrame(this.update);

    const translateX = Math.min(0, this.currentX - this.startX);
    this.sideNavContainerEl.style.transform = `translateX(${translateX}px)`;
  }

  blockClicks (evt) {
    evt.stopPropagation();
  }

  onTransitionEnd (evt) {
    this.sideNavEl.classList.remove('side-nav--animatable');
    this.sideNavEl.removeEventListener('transitionend', this.onTransitionEnd);
  }

  showSideNav () {
    this.sideNavEl.classList.add('side-nav--animatable');
    this.sideNavEl.classList.add('side-nav--visible');
    this.detabinator.inert = false;
    this.sideNavEl.addEventListener('transitionend', this.onTransitionEnd);
  }

  hideSideNav () {
    this.sideNavEl.classList.add('side-nav--animatable');
    this.sideNavEl.classList.remove('side-nav--visible');
    this.detabinator.inert = true;
    this.sideNavEl.addEventListener('transitionend', this.onTransitionEnd);
  }
}


var side_nav = new SideNav();

class HostConnection {
  constructor(elem) {
    this.elem = elem;
    this.connect = this.elem.querySelector('.connect');
    this.connect.addEventListener('click', this.applyConnection.bind(this));
    var input_text = this.elem.querySelector('.input_text');
    input_text.addEventListener('keypress', this.onKeyPress.bind(this));
    input_text.focus();
  }
  
  onKeyPress(evt) {
    if (evt.keyCode == 13) {
      this.applyConnection();
    }
  }
  
  applyConnection() {
    this.connect.disabled = true;
    client = new circ.CircClient(
        window.location.origin.replace(/^http/, 'ws'),
        this.elem.querySelector('input').value);
    new BaseUI(document.querySelector('.main_container'), client);
    client.addEventListener('connection', this.onConnection.bind(this));
  }
  
  onConnection(hostId) {
    this.elem.classList.add('host_connection_hidden');
    window.hostId = hostId;
    var isConnectedToServer = false;
    for (var server in client.state_[hostId]) {
      isConnectedToServer = true;
      break;
    }
    if (isConnectedToServer) {
      transitionToMainUI();
    } else {
      this.server_dialog = document.querySelector('.server_connection');
      this.server_dialog.classList.add('server_connection_visible');
      new ServerConnection(document.querySelector('.server_connection'));
    }
  }
}

class ServerConnection {
  constructor(elem) {
    this.elem = elem;
    this.connect = this.elem.querySelector('.connect');
    this.connect.addEventListener('click', this.applyConnection.bind(this));
    
    this.server_address_el = this.elem.querySelector('.server_address');
    this.server_address_el.addEventListener('keypress', this.onKeyPress.bind(this));
    this.server_address_el.focus();
  
    this.server_port_el = this.elem.querySelector('.server_port');
    this.server_port_el.addEventListener('keypress', this.onKeyPress.bind(this));
    
    this.server_nick_el = this.elem.querySelector('.server_nick');
    this.server_nick_el.addEventListener('keypress', this.onKeyPress.bind(this));
  }
  
  onKeyPress(evt) {
    if (evt.keyCode == 13) {
      this.applyConnection(); 
    }
  }
  
  applyConnection() {
    this.connect.disabled = true;
    var server_address = this.server_address_el.value;
    var server_port = this.server_port_el.value;
    var server_nick = this.server_nick_el.value;
    var server_name = 'irc';
    client.connect(hostId, server_address, server_port, {'name': server_name, 'nick': server_nick})
        .then(function() {
          // Show main UI.
          this.elem.classList.remove('server_connection_visible');
          transitionToMainUI();
          // TODO update side panel       
        }.bind(this));
  }
}

class BaseUI {
  constructor(elem, client) {
    this.elem = elem;
    this.client = client;
    this.client.addEventListener('message', this.onMessage.bind(this));
    this.elem.querySelector('.main_input_text').addEventListener('keypress', this.onKeyPress.bind(this));
  }
  
  onMessage(host, server, data) {
    // |host| may not be user visible.
    this.elem.querySelector('.main_panel').textContent += server + " " + data + '\n';
    this.elem.querySelector('.main_panel').scrollTop = this.elem.querySelector('.main_panel').scrollHeight;
  }
  
  onKeyPress(evt) {
    //TODO parse irc commands here
    if (evt.keyCode == 13) {
      var elem = this.elem.querySelector('.main_input_text')
      this.client.send(hostId, serverName, elem.value);
      elem.value = '';
    }
  }
}

class RoomList {
  constructor(room_el) {
    this.room_el = room_el;
    this.list = document.createElement('ul');
    this.insertRooms();
    this.room_el.appendChild(this.list);
  }

  switchChannel(channel) {
    //TODO update scroll region with history for channel
    document.querySelector('.channel_name').textContent = channel;
    side_nav.hideSideNav();
  }

  insertChannel(channel_list, channel) {
    var channel_item = document.createElement('li');
    channel_item.appendChild(document.createTextNode(channel));
    channel_item.addEventListener('click', this.switchChannel.bind(this, channel));
    channel_list.appendChild(channel_item);
  }

  // TODO call this on each update to server/channels  
  // TODO add click handlers
  insertRooms() {
    for (var server in client.state_[hostId]) {
      var item = document.createElement('li');
      item.appendChild(document.createTextNode(server));
      item.classList.add('room_item');
      
      var channel_list = document.createElement('ul');
      channel_list.classList.add('side-nav__content');
      for (var channel in client.state_[hostId][server].state.channels) {
        this.insertChannel(channel_list, channel);
      }
      item.appendChild(channel_list);
      this.list.appendChild(item);

      // Listen for new channels
      client.state_[hostId][server].onjoin = function(channel_list, channel_joined) {
        this.insertChannel(channel_list, channel_joined)
      }.bind(this, channel_list);
      
      client.state_[hostId][server].onevent = function(channel_target, event) {
        console.log("JR EVENT!");
        var main_panel = document.querySelector('.main_panel');
/*        
data : "llo"
from : "jonross"
time : 1468516760742
type : "PRIVMSG"*/
        var timestamp = new Date(event.time);
        main_panel.textContent += timestamp.toLocaleDateString() + " "
                                + timestamp.toLocaleTimeString() + " " 
                                + event.from + ": " 
                                + event.data + '\n';
        main_panel.scrollTop = main_panel.scrollHeight;
      }.bind(this);
      
    }
  }
}

new HostConnection(document.querySelector('.host_connection'));

function onSignIn(googleUser) {
  var profile = googleUser.getBasicProfile();
  console.log('ID: ' + profile.getId()); // Do not send to your backend! Use an ID token instead.
  console.log('Name: ' + profile.getName());
  console.log('Image URL: ' + profile.getImageUrl());
  console.log('Email: ' + profile.getEmail());
  var id_token = googleUser.getAuthResponse().id_token
  document.querySelector('.host_connection .input_text').value = id_token;
}