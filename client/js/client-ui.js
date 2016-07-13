'use strict';

window.client = null;
// TODO(flackr): Support multiple connected hosts.
window.hostId = 0;
window.serverName = 'irc';

function transitionToMainUI() {
  document.querySelector('.settings').classList.add('settings_hidden');
  document.querySelector('.main_container').querySelector('.main_input_text').focus();
  for (var server in client.state[hostId]) {
    console.log(server);
    new RoomList(document.querySelector('.rooms'), client.state[hostId]);
    
  }
}

class SlideNav {
  constructor() {
    this.nav_panel = document.querySelector('.nav_panel');
 
    this.show_nav = document.querySelector('.show_nav');
    this.show_nav.addEventListener('click', this.showSideNav.bind(this));
  }
  
  showSideNav () {
    console.log("HEY LISTEN");
    this.nav_panel.classList.add('nav_panel_visible'); 
  }
}

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
    for (var server in client.state[hostId]) {
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
  constructor(room_el, initial_rooms) {
    this.room_el = room_el;
    this.list = document.createElement('ul');
    this.insertRooms(initial_rooms);
    this.room_el.appendChild(this.list);
  }

  // TODO call this on each update to server/channels  
  insertRooms(room_list) {
    for(var key in room_list) {
       console.log(key); 
      var item = document.createElement('li');
      item.appendChild(document.createTextNode(key));//room_list[key]));
      item.classList.add('room_item');
      
      var channel_list = document.createElement('ul');
     // channel_list.classList.add('channel_list');
      for (var channel in room_list[key]) {
        var channel_item = document.createElement('li');
        channel_item.appendChild(document.createTextNode(channel));
        channel_list.appendChild(channel_item);
      }
      item.appendChild(channel_list);
      
      // TODO add click handlers
      this.list.appendChild(item);
    }
  }
  
}

new HostConnection(document.querySelector('.host_connection'));

var serverData = { "hostId" : "id", 
                   "servers" : { "server_name 1" : { "chanel_name_1": "channel 1",
                                                   "chanel_name_2": "channel 2" },
                                 "server_name 2" : { "channel_name_3": "channel 3"}                   
                               }
                 };

