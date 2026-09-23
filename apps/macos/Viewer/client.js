import RFB from '@novnc/novnc';

const screen = document.getElementById('screen');
let current = null;
let releasing = false;
const buttons = new Set();
let lastPoint = { clientX: 0, clientY: 0 };
const post = (event, extra = {}) => window.webkit.messageHandlers.session.postMessage({ event, ...extra });

// noVNC already releases keyboard state on blur. Explicitly synthesize mouse
// releases as well when the app loses focus or the user ends the session.
function releaseInput() {
  if (!current || releasing) return;
  releasing = true;
  try {
    const canvas = screen.querySelector('canvas');
    if (canvas) {
      for (const button of [...buttons]) {
        canvas.dispatchEvent(new MouseEvent('mouseup', {
          bubbles: true, button, buttons: 0, ...lastPoint,
        }));
      }
    }
    buttons.clear();
    // Dispatch before changing viewOnly: sendKey ignores releases in viewOnly.
    // The reentrancy guard skips our own listener; noVNC handles its key state.
    window.dispatchEvent(new Event('blur'));
    current.rfb.blur();
  } finally {
    releasing = false;
  }
}

document.addEventListener('mousedown', event => {
  if (screen.contains(event.target)) buttons.add(event.button);
}, true);
document.addEventListener('mouseup', event => buttons.delete(event.button), true);
document.addEventListener('mousemove', event => {
  lastPoint = { clientX: event.clientX, clientY: event.clientY };
}, true);
window.addEventListener('blur', releaseInput);
document.addEventListener('visibilitychange', () => { if (document.hidden) releaseInput(); });

function disconnect() {
  if (!current) return;
  releaseInput();
  const old = current;
  current = null;
  old.observer.disconnect();
  old.rfb.disconnect();
  screen.replaceChildren();
}

function connect(config) {
  disconnect();
  const id = config.id;
  let rfb;
  try {
    rfb = new RFB(screen, config.url, {
      shared: true,
      credentials: { password: config.password },
    });
  } catch {
    post('connectionError', { id });
    return;
  }
  config.password = '';
  rfb.scaleViewport = true;
  rfb.background = '#000';
  rfb.resizeSession = false;
  rfb.showDotCursor = true;
  let dimensions = '';
  const observer = new MutationObserver(() => {
    if (current?.id !== id) return;
    const canvas = screen.querySelector('canvas');
    if (!canvas || canvas.width === 0 || canvas.height === 0) return;
    const next = `${canvas.width}×${canvas.height}`;
    if (next !== dimensions) {
      dimensions = next;
      post('dimensions', { id, width: canvas.width, height: canvas.height });
    }
  });
  observer.observe(screen, { subtree: true, childList: true, attributes: true, attributeFilter: ['width', 'height'] });
  current = { id, rfb, observer };
  const emit = (event, extra = {}) => {
    if (current?.id === id) post(event, { id, ...extra });
  };
  rfb.addEventListener('connect', () => {
    emit('connected');
    rfb.focus();
  });
  rfb.addEventListener('disconnect', event => {
    emit('disconnected', { clean: event.detail.clean });
    if (current?.id === id) disconnect();
  });
  rfb.addEventListener('credentialsrequired', () => {
    emit('credentialsRequired');
    if (current?.id === id) disconnect();
  });
  rfb.addEventListener('securityfailure', () => {
    emit('authenticationFailed');
    if (current?.id === id) disconnect();
  });
  rfb.addEventListener('serververification', () => {
    // Do not silently approve server identity for authentication modes that
    // this first client does not yet expose for verification.
    emit('verificationRequired');
    if (current?.id === id) disconnect();
  });
}

window.openVNC = {
  connect, disconnect, releaseInput,
  setViewOnly(value) { releaseInput(); if (current) current.rfb.viewOnly = value; },
  sendCtrlAltDel() { if (current) current.rfb.sendCtrlAltDel(); },
};
post('ready');
