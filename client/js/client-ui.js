'use strict';

window.client = null;
// TODO(flackr): Support multiple connected hosts.
window.hostId = 0;
window.serverName = 'irc';

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
  }
  
  applyConnection() {
    client = new circ.CircClient(
        window.location.origin.replace(/^http/, 'ws'),
        this.elem.querySelector('input').value);
    new BaseUI(document.querySelector('.main_container'), client);
    client.addEventListener('connection', this.onConnection.bind(this));
  }
  
  onConnection(hostId) {
    this.elem.classList.add('host_connection_hidden');
    this.server_dialog = document.querySelector('.server_connection');
    this.server_dialog.classList.add('server_connection_visible');
    window.hostId = hostId;
  }
}

class ServerConnection {
  constructor(elem) {
    this.elem = elem;
    this.connect = this.elem.querySelector('.connect');
    this.connect.addEventListener('click', this.applyConnection.bind(this));
  }
  
  applyConnection() {
    var server_address = this.elem.querySelector('.server_address').value;
    var server_port = this.elem.querySelector('.server_port').value;
    var server_nick = this.elem.querySelector('.server_nick').value;
    var server_name = 'irc';
    client.connect(hostId, server_address, server_port, {'name': server_name, 'nick': server_nick})
        .then(function() {
          // Show main UI.
          this.elem.classList.remove('server_connection_visible');
          document.querySelector('.settings').classList.add('settings_hidden');
          // TODO update side panel       
        }.bind(this));
  }
}

class BaseUI {
  constructor(elem, client) {
    this.elem = elem;
    this.client = client;
    this.client.addEventListener('message', this.onMessage.bind(this));
    this.elem.querySelector('.input_text').addEventListener('keypress', this.onKeyPress.bind(this));
  }
  
  onMessage(host, server, data) {
    // |host| may not be user visible.
    this.elem.querySelector('.main_panel').textContent += server + " " + data + '\n';
    this.elem.querySelector('.main_panel').scrollTop = this.elem.querySelector('.main_panel').scrollHeight;
  }
  
  onKeyPress(evt) {
    if (evt.keyCode == 13) {
      var elem = this.elem.querySelector('.input_text')
      this.client.send(hostId, serverName, elem.value);
      elem.value = '';
    }
  }
}

new HostConnection(document.querySelector('.host_connection'));
new ServerConnection(document.querySelector('.server_connection'));
//new SlideNav();