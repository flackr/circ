// Make included NodeJS export to window object.
window.exports = window;

var packages = {};

window.require = function(package) {
  return packages[package];
};