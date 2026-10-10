.pragma library

var instance = null;
var listeners = [];

function setService(s) {
  instance = s;
  for (var i = 0; i < listeners.length; i++) {
    try {
      listeners[i](s);
    } catch (e) {}
  }
  listeners = [];
}

function getService() {
  return instance;
}

function onServiceAvailable(cb) {
  if (instance) {
    try {
      cb(instance);
    } catch (e) {}
  } else {
    listeners.push(cb);
  }
}
