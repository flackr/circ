'use strict';

var MAX_INPUT_HISTORY = 100;

window.client = null;
// TODO(flackr): Support multiple connected hosts.
window.hostId = 0;
window.serverName = 'irc';
window.pushNotificationEndpoint = '';

if ('serviceWorker' in navigator) {
 console.log('Service Worker is supported');
 navigator.serviceWorker.register('sw.js').then(function(reg) {
    console.log(':^)', reg);
    reg.pushManager.subscribe({
      userVisibleOnly: true
    }).then(function(sub) {
      // TODO(flackr): If already connected, notify the server.
      window.pushNotificationEndpoint = sub.endpoint;
      console.log('endpoint:', sub.endpoint);
    });
 }).catch(function(err) {
   console.log(':^(', err);
 });
}

function transitionToMainUI() {
  document.querySelector('.settings_container').style.display = "none";
  document.querySelector('.main_container').querySelector('.main_input_text').focus();
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

    document.querySelector('.settings_launcher').addEventListener('click', this.launchSettings.bind(this));
    document.querySelector('.join_server').addEventListener('click', this.joinServer.bind(this));
  }

  launchSettings() {
    this.hideSideNav();
    document.querySelector('.settings_container').style.display = "block";
    document.querySelector('.settings_main').style.display = "block";
  }

  joinServer() {
    this.hideSideNav();
    server_connection_screen.show();
  }

  // apply passive event listening if it's supported
  applyPassive () {
    if (this.supportsPassive !== undefined) {
      return this.supportsPassive ? {passive: true} : false;
    }
    // feature detect
    let isSupported = false;
    try {
      document.addEventListener('test', null, {get passive () {
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
    this.connect.classList.add('md-inactive');
    client = new circ.CircClient(
        window.location.origin.replace(/^http/, 'ws'),
        this.elem.querySelector('input').value);
    if (window.pushNotificationEndpoint)
      client.subscribeForNotifications(window.pushNotificationEndpoint);
    new BaseUI(document.querySelector('.main_container'), client);
    client.addEventListener('connection', this.onConnection.bind(this));
  }

  onConnection(hostId) {
    this.elem.style.display = "none";
    window.hostId = hostId;
    var isConnectedToServer = false;
    for (var server in client.state_[hostId]) {
      isConnectedToServer = true;
      break;
    }
    if (isConnectedToServer) {
      room_list.initUI();
      transitionToMainUI();
    } else {
      server_connection_screen.show();
    }
    new RoomList(document.querySelector('.rooms'));
  }
}

class ServerConnection {
  constructor(elem) {
    this.elem = elem;
    this.connect = this.elem.querySelector('.connect');
    this.connect.addEventListener('click', this.applyConnection.bind(this));

    this.server_address_el = this.elem.querySelector('.server_address');
    this.server_address_el.addEventListener('keypress', this.onKeyPress.bind(this));

    this.server_port_el = this.elem.querySelector('.server_port');
    this.server_port_el.addEventListener('keypress', this.onKeyPress.bind(this));

    this.server_nick_el = this.elem.querySelector('.server_nick');
    this.server_nick_el.addEventListener('keypress', this.onKeyPress.bind(this));

    this.elem.querySelector('.header__menu-toggle').addEventListener('click',this.close.bind(this));
  }

  show() {
    document.querySelector('.settings_container').style.display = "block";
    this.elem.style.display = "block";
    this.connect.classList.remove('md-inactive');
    this.server_address_el.focus();
  }

  close() {
    room_list.initUI();
    this.elem.style.display = "none";
    transitionToMainUI();
  }

  onKeyPress(evt) {
    if (evt.keyCode == 13) {
      this.applyConnection();
    }
  }

  applyConnection() {
    this.connect.disabled = true;
    this.connect.classList.add('md-inactive');
    var server_address = this.server_address_el.value;
    var server_port = this.server_port_el.value;
    var server_nick = this.server_nick_el.value;
    var server_name = 'irc';
    client.connect(hostId, server_address, server_port, {'name': server_name, 'nick': server_nick})
        .then(function() {
          // Show main UI.
          this.close();
        }.bind(this));
  }
}

class BaseUI {
  constructor(elem, client) {
    this.commandHandler = new circ.UserCommandHandler(client);
    this.elem = elem;
    this.client = client;
    this.elem.querySelector('.main_input_text').addEventListener('keydown', this.onKeyDown.bind(this));
    this.elem.querySelector('.main_input_text').addEventListener('keypress', this.onKeyPress.bind(this));
    this.input_history = [];
    this.input_index = 0;
  }

  onKeyDown(evt) {
    if (this.input_history.length == 0) {
      return;
    }
    if (evt.keyCode == 38) {
      // Up arrow
      if (this.input_index > 0) {
        this.input_index--;
        this.elem.querySelector('.main_input_text').value = this.input_history[this.input_index];
      }
    } else if (evt.keyCode == 40) {
      // Down arrow
      this.input_index++;
      if (this.input_index >= this.input_history.length) {
        this.input_index = this.input_history.length;
        this.elem.querySelector('.main_input_text').value = "";
      } else {
        this.elem.querySelector('.main_input_text').value = this.input_history[this.input_index];
      }
    }
  }

  onKeyPress(evt) {
    if (evt.keyCode == 13) {
      var elem = this.elem.querySelector('.main_input_text')
      var text = elem.value;
      if (this.input_index == this.input_history.length) {
        this.input_history.push(text);
        this.input_index++;
        if (this.input_history.length > MAX_INPUT_HISTORY) {
           this.input_history.shift();
           this.input_index = this.input_history.length;
        }
      } else {
        this.input_index = this.input_history.length;
      }
      //TODO parse irc commands here
      this.client.send(hostId, serverName, text);
      elem.value = '';
      // TODO(flackr): Only call this when we switch channels.
      this.commandHandler.setActiveChannel(hostId, serverName, room_list.current_channel);
      this.commandHandler.runCommand(text);
    }
  }
}

class RoomList {
  constructor(room_el) {
    this.room_el = room_el;
    this.current_channel = '';
    this.servers_loaded = false;
  }

  initUI() {
    if (this.servers_loaded) {
      return;
    }
    this.list = document.createElement('ul');
    this.insertRooms();
    if (this.servers_loaded) {
      this.room_el.appendChild(this.list);
    }
  }

  parseEvent(event) {
    var main_panel = document.querySelector('.main_panel');
    var timestamp = new Date(event.time);

    var event_message = document.createElement('div');
    event_message.classList.add('horizontal_row');
    var event_header = document.createElement('div');
    event_header.textContent = timestamp.toLocaleDateString() + " "
                            + timestamp.toLocaleTimeString() + " "
                            + event.from + ": ";
    event_header.classList.add('event_header');
    var event_content = document.createElement('div');
    event_content.textContent = event.data + '\n';
    event_content.classList.add('event_content');

    event_message.appendChild(event_header);
    event_message.appendChild(event_content);
    main_panel.appendChild(event_message);

    // TODO don't scroll if the user has manually scrolled
    main_panel.scrollTop = main_panel.scrollHeight;
  }

  switchChannel(server, channel) {
    //TODO update scroll region with history for channel
    document.querySelector('.channel_name').textContent = channel;
    this.current_channel = channel;
    side_nav.hideSideNav();
    var main_panel = document.querySelector('.main_panel').textContent='';
    while (main_panel.firstChild) {
      main_panel.removeChild(main_panel.firstChild);
    }

    for (var channels in client.state_[hostId][server].state.channels) {
      if (channels === this.current_channel) {
        var events = client.state_[hostId][server].state.channels[channels].events;
        for (var i=0; i < events.length; ++i) {
          this.parseEvent(events[i]);
        }
      }

    }
  }

  insertChannel(server, channel_list, channel) {
    var channel_item = document.createElement('li');
    channel_item.appendChild(document.createTextNode(channel));
    channel_item.addEventListener('click', this.switchChannel.bind(this, server, channel));
    channel_list.insertBefore(channel_item, channel_list.lastChild);
  }

  insertRooms() {
    for (var server in client.state_[hostId]) {
      this.servers_loaded = true;
      var item = document.createElement('li');
      var server_node = document.createElement('div');
      server_node.textContent = server;
      server_node.classList.add('server_name');
      item.appendChild(server_node);
      item.classList.add('room_item');

      var channel_list = document.createElement('ul');
      channel_list.classList.add('side-nav__content');
      for (var channel in client.state_[hostId][server].state.channels) {
        var channel_item = document.createElement('li');
        channel_item.appendChild(document.createTextNode(channel));
        channel_item.addEventListener('click', this.switchChannel.bind(this, server, channel));
        channel_list.appendChild(channel_item);
      }
      var join_button = document.createElement('li');
      join_button.classList.add('horizontal_row');
      var join_icon = document.createElement('div');
      join_icon.textContent = "add";
      join_icon.classList.add('material-icons');
      join_icon.classList.add('room-list-icons');
      var join_text = document.createElement('div');
      join_text.classList.add('side-nav-labels')
      join_text.textContent = "Join Channel";
      join_button.appendChild(join_icon);
      join_button.appendChild(join_text);
      channel_list.appendChild(join_button);

      item.appendChild(channel_list);
      this.list.appendChild(item);

      // Listen for new channels
      client.state_[hostId][server].onjoin = function(channel_list, channel_joined) {
        this.insertChannel(server, channel_list, channel_joined)
      }.bind(this, channel_list);

      client.state_[hostId][server].onevent = function(channel_target, event) {
        if (channel_target === this.current_channel) {
          this.parseEvent(event);
        }
      }.bind(this);
    }
  }
}

class SettingsScreen {
  constructor() {
    this.elem = document.querySelector('.settings_main');
    this.elem.querySelector('.header__menu-toggle').addEventListener('click',this.close.bind(this));
  }

  close() {
    this.elem.display = "none";
    transitionToMainUI();
  }
}

new SettingsScreen();

var server_connection_screen = new ServerConnection(document.querySelector('.server_connection'));
var room_list = new RoomList(document.querySelector('.rooms'));

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